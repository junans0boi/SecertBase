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
  const email = `${name}-${Date.now()}@affection-alignment.test`;
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
  'affection alignment shared result exposes expression and expectation dimensions only',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'affection-alice');
      const bob = await createUser(server, 'affection-bob');
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
      const acceptedBody = await accepted.json();
      assert.equal(accepted.status, 200, JSON.stringify(acceptedBody));

      const start = async (token) => {
        const response = await server.request(
          '/relationship/couple-assessments/affection_alignment/attempt',
          { token, method: 'POST' },
        );
        const body = await response.json();
        assert.equal(response.status, 201, JSON.stringify(body));
        assert.equal(body.attempt.coupleId, acceptedBody.coupleId);
        return body.attempt.id;
      };
      const aliceAttemptId = await start(alice.token);
      const bobAttemptId = await start(bob.token);
      await answerAll(server, alice.token, aliceAttemptId, 4);
      await answerAll(server, bob.token, bobAttemptId, 3);

      const firstSubmit = await server.request(
        `/relationship/couple-assessment-attempts/${aliceAttemptId}/submit`,
        { token: alice.token, method: 'POST' },
      );
      assert.equal((await firstSubmit.json()).status, 'pending');
      const secondSubmit = await server.request(
        `/relationship/couple-assessment-attempts/${bobAttemptId}/submit`,
        { token: bob.token, method: 'POST' },
      );
      const resultBody = await secondSubmit.json();
      assert.equal(secondSubmit.status, 201, JSON.stringify(resultBody));
      assert.equal(resultBody.status, 'ready');
      assert.deepEqual(
        resultBody.result.dimensions.map((dimension) => dimension.key),
        ['expression', 'expectation', 'alignment'],
      );
      assert.equal(resultBody.result.conversationPrompts.length, 3);
      assert.equal('answers' in resultBody.result, false);
      assert.equal('user1Score' in resultBody.result, false);
    } finally {
      await server.close();
    }
  },
);
