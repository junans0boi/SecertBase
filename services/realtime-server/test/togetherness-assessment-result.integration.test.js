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
  const email = `${name}-${Date.now()}@togetherness.test`;
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

const pair = async (server, sender, recipient) => {
  const created = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const requestId = (await created.json()).requestId;
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token,
    method: 'POST',
  });
  assert.equal(accepted.status, 200, await accepted.text());
};

const start = async (server, token) => {
  const response = await server.request(
    '/relationship/couple-assessments/togetherness_personal_time/attempt',
    { token, method: 'POST' },
  );
  const body = await response.json();
  assert.equal(response.status, 201, JSON.stringify(body));
  return body.attempt.id;
};

const answerAll = async (server, token, attemptId, value) => {
  for (const questionKey of activeQuestionKeys) {
    const response = await server.request(
      `/relationship/assessment-attempts/${attemptId}/answers/${questionKey}`,
      { token, method: 'PATCH', body: { value } },
    );
    assert.equal(response.status, 200, await response.text());
  }
};

test(
  'togetherness assessment produces a pending then balanced shared result',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'togetherness-alice');
      const bob = await createUser(server, 'togetherness-bob');
      await pair(server, alice, bob);
      const aliceAttemptId = await start(server, alice.token);
      const bobAttemptId = await start(server, bob.token);
      await answerAll(server, alice.token, aliceAttemptId, 5);
      await answerAll(server, bob.token, bobAttemptId, 2);

      const aliceSubmit = await server.request(
        `/relationship/couple-assessment-attempts/${aliceAttemptId}/submit`,
        { token: alice.token, method: 'POST' },
      );
      const aliceSubmitBody = await aliceSubmit.json();
      assert.equal(aliceSubmit.status, 201, JSON.stringify(aliceSubmitBody));
      assert.equal(aliceSubmitBody.status, 'pending');

      const bobSubmit = await server.request(
        `/relationship/couple-assessment-attempts/${bobAttemptId}/submit`,
        { token: bob.token, method: 'POST' },
      );
      const bobSubmitBody = await bobSubmit.json();
      assert.equal(bobSubmit.status, 201, JSON.stringify(bobSubmitBody));
      assert.equal(bobSubmitBody.status, 'ready');
      assert.deepEqual(
        bobSubmitBody.result.dimensions.map((dimension) => dimension.key),
        ['togetherness', 'personal_time', 'coordination'],
      );
      assert.equal(bobSubmitBody.result.conversationPrompts.length, 3);
      assert.equal('user1Score' in bobSubmitBody.result, false);
      assert.equal('user2Score' in bobSubmitBody.result, false);
    } finally {
      await server.close();
    }
  },
);
