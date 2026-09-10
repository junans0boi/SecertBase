import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

test(
  'authenticated assessment comparison reports insufficient data before a retake',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const email = `comparison-${Date.now()}@relationship.test`;
      await server.request('/auth/register', {
        method: 'POST',
        body: {
          email,
          password: 'password123',
          full_name: 'comparison-user',
          nickname: 'comparison-user',
          birth_date: '1995-03-14',
        },
      });
      const login = await server.request('/auth/login', {
        method: 'POST',
        body: { email, password: 'password123' },
      });
      const loginBody = await login.json();
      assert.equal(login.status, 200, JSON.stringify(loginBody));
      const comparison = await server.request(
        '/relationship/assessment-results/attachment/comparison',
        { token: loginBody.token },
      );
      const body = await comparison.json();
      assert.equal(comparison.status, 200, JSON.stringify(body));
      assert.equal(body.status, 'insufficient_data');
      assert.equal(body.available, false);
      assert.match(body.message, /한 번 더/);
    } finally {
      await server.close();
    }
  },
);
