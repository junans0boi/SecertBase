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
  'Tarot REST lets the user choose one daily card and then keeps it stable',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const user = await registerAndLogin(server, 'tarot-personal');
      const waiting = await server.request('/relationship/tarot/today', { token: user.token });
      const waitingBody = await waiting.json();
      assert.equal(waiting.status, 200, JSON.stringify(waitingBody));
      assert.equal(waitingBody.personal.drawn, false);
      assert.equal(waitingBody.personal.drawRequired, true);
      assert.equal(waitingBody.personal.cards.length, 22);

      const draw = await server.request('/relationship/tarot/today/draw', {
        token: user.token,
        method: 'POST',
        body: { scope: 'user', cardKey: 'the_star' },
      });
      const drawBody = await draw.json();
      assert.equal(draw.status, 200, JSON.stringify(drawBody));
      assert.equal(drawBody.personal.drawn, true);
      assert.equal(drawBody.personal.card.key, 'the_star');
      assert.equal(drawBody.redrawAvailable, false);

      const second = await server.request('/relationship/tarot/today', { token: user.token });
      const secondBody = await second.json();
      assert.deepEqual(secondBody.personal.card, drawBody.personal.card);
      assert.equal(secondBody.personal.drawRequired, false);

      const secondDraw = await server.request('/relationship/tarot/today/draw', {
        token: user.token,
        method: 'POST',
        body: { scope: 'user', cardKey: 'the_sun' },
      });
      assert.equal(secondDraw.status, 409);
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
