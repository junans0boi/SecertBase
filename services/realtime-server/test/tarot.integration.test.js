import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const registerAndLogin = async (server, name) => {
  const email = `${name}-${Date.now()}@tarot.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '1995-03-16',
    },
  });
  const registeredBody = await registration.json();
  assert.equal(registration.status, 200, JSON.stringify(registeredBody));
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return { token: body.token, userCode: registeredBody.userCode };
};

test(
  'Tarot REST keeps the personal card stable and does not expose redraw',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const user = await registerAndLogin(server, 'tarot-personal');
      const first = await server.request('/relationship/tarot/today', { token: user.token });
      const firstBody = await first.json();
      assert.equal(first.status, 200, JSON.stringify(firstBody));
      assert.equal(firstBody.personal.scope, 'user');
      assert.equal(firstBody.personal.card.orientation, 'upright');
      assert.equal(firstBody.redrawAvailable, false);
      const second = await server.request('/relationship/tarot/today', { token: user.token });
      const secondBody = await second.json();
      assert.deepEqual(secondBody.personal.card, firstBody.personal.card);
      const redraw = await server.request('/relationship/tarot/today/redraw', {
        token: user.token,
        method: 'POST',
      });
      assert.equal(redraw.status, 404);
    } finally {
      await server.close();
    }
  },
);
