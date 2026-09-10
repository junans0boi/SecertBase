import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createAndLogin = async (server, name) => {
  const email = `${name}-${Date.now()}@relationship.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '1995-03-14',
    },
  });
  assert.equal(registration.status, 200, await registration.text());
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return { token: body.token };
};

test(
  'mindcare resumes one private session, keeps choices deterministic, and stays owner-only',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const owner = await createAndLogin(server, 'mindcare-owner');
      const other = await createAndLogin(server, 'mindcare-other');
      const created = await server.request('/relationship/mindcare/sessions', {
        token: owner.token,
        method: 'POST',
      });
      const createdBody = await created.json();
      assert.equal(created.status, 201, JSON.stringify(createdBody));
      assert.equal(createdBody.session.currentState, 'emotion');
      assert.equal(createdBody.choices.length, 8);

      const resumed = await server.request('/relationship/mindcare/sessions', {
        token: owner.token,
        method: 'POST',
      });
      const resumedBody = await resumed.json();
      assert.equal(resumed.status, 200, JSON.stringify(resumedBody));
      assert.equal(resumedBody.session.id, createdBody.session.id);

      const message = await server.request(
        `/relationship/mindcare/sessions/${createdBody.session.id}/messages`,
        {
          token: owner.token,
          method: 'POST',
          body: { choiceKey: 'anxious' },
        },
      );
      const messageBody = await message.json();
      assert.equal(message.status, 201, JSON.stringify(messageBody));
      assert.equal(messageBody.session.currentState, 'emotion_detail');
      assert.equal(messageBody.messages.filter((item) => item.role === 'user').length, 1);

      const risk = await server.request(
        `/relationship/mindcare/sessions/${createdBody.session.id}/messages`,
        {
          token: owner.token,
          method: 'POST',
          body: { text: '죽고 싶다는 생각이 들어요.' },
        },
      );
      const riskBody = await risk.json();
      assert.equal(risk.status, 201, JSON.stringify(riskBody));
      assert.equal(riskBody.session.status, 'safety_pending');
      assert.equal(riskBody.session.currentState, 'safety');

      const partnerRead = await server.request(
        `/relationship/mindcare/sessions/${createdBody.session.id}`,
        { token: other.token },
      );
      assert.equal(partnerRead.status, 404);

      const safety = await server.request(
        `/relationship/mindcare/sessions/${createdBody.session.id}/safety`,
        {
          token: owner.token,
          method: 'POST',
          body: { safeNow: true },
        },
      );
      const safetyBody = await safety.json();
      assert.equal(safety.status, 200, JSON.stringify(safetyBody));
      assert.equal(safetyBody.session.status, 'active');
      assert.equal(safetyBody.safety.status, 'confirmed_safe');
    } finally {
      await server.close();
    }
  },
);
