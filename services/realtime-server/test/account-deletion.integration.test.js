import assert from 'node:assert/strict';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createUser = async (server, name) => {
  const email = `${name}@deletion.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST',
    body: { email, password: 'password123', full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  assert.equal(registered.status < 300, true, await registered.text());
  const userCode = (await registered.json()).userCode;
  const loggedIn = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const login = await loggedIn.json();
  return { token: login.token, userCode, userId: login.user.UserId };
};

const pair = async (server, sender, recipient) => {
  const created = await server.request('/pairing/requests', {
    token: sender.token, method: 'POST', body: { recipientCode: recipient.userCode },
  });
  const requestId = (await created.json()).requestId;
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token, method: 'POST',
  });
  assert.equal(accepted.status, 200, await accepted.text());
};

const count = async (db, sql, params) => {
  const [rows] = await db.query(sql, params);
  return Number(rows[0].n);
};

test(
  'account deletion succeeds, tombstones the user and erases personal rows',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    const db = await mysql.createConnection(server.environment.databaseUrl);
    try {
      const leaving = await createUser(server, 'leaving');
      const staying = await createUser(server, 'staying');
      await pair(server, leaving, staying);
      const id = leaving.userId;

      await db.query(
        "UPDATE Users SET BirthPlace = '서울 비밀동', BirthTime = '09:30:00' WHERE UserId = ?",
        [id],
      );
      await db.query(
        "INSERT INTO device_tokens (user_id, platform, token) VALUES (?, 'android', 'tok-leaving'), (?, 'android', 'tok-staying')",
        [id, staying.userId],
      );
      await db.query('INSERT INTO notification_prefs (user_id) VALUES (?)', [id]);
      await db.query("INSERT INTO private_reflections (user_id, content) VALUES (?, '비밀 일기')", [id]);
      await db.query(
        `INSERT INTO relationship_mindcare_sessions
           (owner_user_id, content_version, current_state, state_json)
         VALUES (?, 'v1', 'start', '{}')`,
        [id],
      );

      const deleted = await server.request('/user', {
        token: leaving.token, method: 'DELETE', body: { password: 'password123' },
      });
      assert.equal(deleted.status, 200, await deleted.text());

      const [[user]] = await db.query(
        'SELECT Email, Nickname, IsDeleted, BirthDate, BirthPlace, BirthTime, PasswordHash FROM Users WHERE UserId = ?',
        [id],
      );
      assert.equal(user.IsDeleted, 1);
      assert.equal(user.Email, `deleted_${id}@__tombstone__`);
      assert.equal(user.Nickname, '');
      assert.equal(user.BirthPlace, null);
      assert.equal(user.BirthTime, null);
      assert.equal(user.PasswordHash, null);

      for (const [table, column] of [
        ['device_tokens', 'user_id'],
        ['notification_prefs', 'user_id'],
        ['private_reflections', 'user_id'],
        ['relationship_mindcare_sessions', 'owner_user_id'],
      ]) {
        assert.equal(
          await count(db, `SELECT COUNT(*) AS n FROM ${table} WHERE ${column} = ?`, [id]),
          0,
          `${table} still holds rows of the deleted user`,
        );
      }
      assert.equal(
        await count(db, 'SELECT COUNT(*) AS n FROM device_tokens WHERE user_id = ?', [staying.userId]),
        1,
        "the partner's device token must survive",
      );

      const [[couple]] = await db.query(
        'SELECT Status FROM Couples WHERE User1Id IN (?, ?) AND User2Id IN (?, ?)',
        [id, staying.userId, id, staying.userId],
      );
      assert.equal(couple.Status, 'inactive');

      const relogin = await server.request('/auth/login', {
        method: 'POST', body: { email: 'leaving@deletion.test', password: 'password123' },
      });
      assert.equal(relogin.status, 401);

      const pairDeleted = await server.request('/pairing/requests', {
        token: staying.token, method: 'POST', body: { recipientCode: leaving.userCode },
      });
      assert.equal(pairDeleted.status, 404, 'deleted accounts cannot be paired with');
    } finally {
      await db.end();
      await server.close();
    }
  },
);
