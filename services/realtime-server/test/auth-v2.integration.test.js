import assert from 'node:assert/strict';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const consents = { terms: true, privacy: true, age14: true, marketing: true };
const signup = (email, extra = {}) => ({
  email,
  password: 'password123',
  full_name: '김민지',
  nickname: '민지',
  birth_date: '2000-03-14',
  consents,
  ...extra,
});

test(
  '2.0 signup records consent history and password reset replaces the password',
  { skip: !adminUrl || !redisUrl },
  async () => {
    process.env.MAIL_TRANSPORT = 'log';
    const mails = [];
    const originalInfo = console.info;
    console.info = (message, ...rest) => {
      if (String(message).startsWith('[Mail:log]')) mails.push(String(message));
      else originalInfo(message, ...rest);
    };
    const server = await createApiTestServer({ adminUrl, redisUrl });
    const connection = await mysql.createConnection(server.environment.databaseUrl);
    try {
      const weak = await server.request('/auth/register', {
        method: 'POST', body: signup('weak@example.test', { password: 'abcdefgh' }),
      });
      assert.equal((await weak.json()).reason, 'weak_password');
      const young = await server.request('/auth/register', {
        method: 'POST', body: signup('young@example.test', { birth_date: '2020-01-01' }),
      });
      assert.equal((await young.json()).reason, 'under_age');
      const missing = await server.request('/auth/register', {
        method: 'POST', body: signup('missing@example.test', { consents: { terms: true } }),
      });
      assert.equal((await missing.json()).reason, 'consent_required');

      const created = await server.request('/auth/register', {
        method: 'POST', body: signup('minji@example.test'),
      });
      assert.equal(created.status, 200, await created.text());
      const [rows] = await connection.query(
        `SELECT c.consent_type, c.agreed, c.source FROM user_consents c
         JOIN Users u ON u.UserId = c.user_id WHERE u.Email = ? ORDER BY c.consent_type`,
        ['minji@example.test'],
      );
      assert.deepEqual(rows.map((r) => [r.consent_type, Number(r.agreed), r.source]), [
        ['age14', 1, 'signup'], ['marketing', 1, 'signup'], ['privacy', 1, 'signup'], ['terms', 1, 'signup'],
      ]);

      const login = await server.request('/auth/login', {
        method: 'POST', body: { email: 'minji@example.test', password: 'password123' },
      });
      const session = await login.json();
      assert.equal(session.user.SignupRequired, false);
      const history = await server.request('/user/consents', { token: session.token });
      assert.equal((await history.json()).consents.marketing.agreed, true);

      const requested = await server.request('/auth/password-reset/request', {
        method: 'POST', body: { email: 'minji@example.test' },
      });
      assert.equal(requested.status, 200, await requested.text());
      const code = mails.at(-1).match(/\b(\d{6})\b/)[1];
      const confirmed = await server.request('/auth/password-reset/confirm', {
        method: 'POST', body: { email: 'minji@example.test', code, password: 'newpass123' },
      });
      assert.equal(confirmed.status, 200, await confirmed.text());
      const relogin = await server.request('/auth/login', {
        method: 'POST', body: { email: 'minji@example.test', password: 'newpass123' },
      });
      assert.equal(relogin.status, 200);
    } finally {
      console.info = originalInfo;
      await connection.end();
      await server.close();
    }
  },
);
