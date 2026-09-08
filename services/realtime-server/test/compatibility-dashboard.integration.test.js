import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;
const activeQuestionKeys = [
  'q01', 'q02', 'q03', 'q04',
  'q09', 'q10', 'q11', 'q12',
  'q17', 'q18', 'q19', 'q20',
];

const createUser = async (server, name) => {
  const email = `${name}-${Date.now()}@compatibility-dashboard.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '2000-01-01',
    },
  });
  assert.equal(registered.status, 200, await registered.text());
  const userCode = (await registered.json()).userCode;
  const loggedIn = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await loggedIn.json();
  assert.equal(loggedIn.status, 200, JSON.stringify(body));
  return { token: body.token, userCode };
};

const answerAll = async (server, token, attemptId) => {
  for (const questionKey of activeQuestionKeys) {
    const response = await server.request(
      `/relationship/assessment-attempts/${attemptId}/answers/${questionKey}`,
      { token, method: 'PATCH', body: { value: 3 } },
    );
    assert.equal(response.status, 200, await response.text());
  }
};

const completeTogetherness = async (server, token) => {
  const started = await server.request(
    '/relationship/couple-assessments/togetherness_personal_time/attempt',
    { token, method: 'POST' },
  );
  const body = await started.json();
  assert.equal(started.status, 201, JSON.stringify(body));
  await answerAll(server, token, body.attempt.id);
  const submitted = await server.request(
    `/relationship/couple-assessment-attempts/${body.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

test(
  'compatibility dashboard aggregates independent card states for an active couple',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'dashboard-alice');
      const bob = await createUser(server, 'dashboard-bob');
      const pairing = await server.request('/pairing/requests', {
        token: alice.token,
        method: 'POST',
        body: { recipientCode: bob.userCode },
      });
      const pairingBody = await pairing.json();
      assert.equal(pairing.status, 201, JSON.stringify(pairingBody));
      const accepted = await server.request(
        `/pairing/requests/${pairingBody.requestId}/accept`,
        { token: bob.token, method: 'POST' },
      );
      assert.equal(accepted.status, 200, await accepted.text());

      await completeTogetherness(server, alice.token);
      await completeTogetherness(server, bob.token);

      const dashboard = await server.request('/relationship/compatibility/current', {
        token: alice.token,
      });
      const dashboardBody = await dashboard.json();
      assert.equal(dashboard.status, 200, JSON.stringify(dashboardBody));
      assert.equal(dashboardBody.cards.length, 7);
      const byCode = new Map(dashboardBody.cards.map((card) => [card.code, card]));
      assert.equal(byCode.get('togetherness-personal-time').status, 'ready');
      assert.equal(byCode.get('affection-alignment').status, 'pending');
      assert.equal(byCode.get('social-bonding').status, 'pending');
      assert.equal(byCode.get('togetherness-personal-time').result.answers, undefined);

      await server.request('/user/partner', { token: alice.token, method: 'DELETE' });
      const blocked = await server.request('/relationship/compatibility/current', {
        token: bob.token,
      });
      assert.equal(blocked.status, 409);
    } finally {
      await server.close();
    }
  },
);
