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
  const email = `${name}-${Date.now()}@couple-result.test`;
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
  const createdBody = await created.json();
  assert.equal(created.status, 201, JSON.stringify(createdBody));
  const accepted = await server.request(
    `/pairing/requests/${createdBody.requestId}/accept`,
    { token: recipient.token, method: 'POST' },
  );
  assert.equal(accepted.status, 200, await accepted.text());
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
  'couple result stays pending until both members complete and is shared without personal scores',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'couple-result-alice');
      const bob = await createUser(server, 'couple-result-bob');
      await pair(server, alice, bob);

      const aliceStarted = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: alice.token, method: 'POST' },
      );
      const aliceStartedBody = await aliceStarted.json();
      assert.equal(aliceStarted.status, 201, JSON.stringify(aliceStartedBody));
      await answerAll(server, alice.token, aliceStartedBody.attempt.id, 5);

      const aliceSubmitted = await server.request(
        `/relationship/couple-assessment-attempts/${aliceStartedBody.attempt.id}/submit`,
        { token: alice.token, method: 'POST' },
      );
      const aliceSubmittedBody = await aliceSubmitted.json();
      assert.equal(aliceSubmitted.status, 201, JSON.stringify(aliceSubmittedBody));
      assert.equal(aliceSubmittedBody.status, 'pending');
      assert.equal(aliceSubmittedBody.completedMemberCount, 1);
      assert.equal(aliceSubmittedBody.result, null);

      const pending = await server.request(
        '/relationship/couple-assessment-results/conflict_repair/current',
        { token: bob.token },
      );
      const pendingBody = await pending.json();
      assert.equal(pending.status, 200, JSON.stringify(pendingBody));
      assert.equal(pendingBody.status, 'pending');
      assert.equal(pendingBody.completedMemberCount, 1);
      assert.equal(pendingBody.result, null);

      const bobStarted = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: bob.token, method: 'POST' },
      );
      const bobStartedBody = await bobStarted.json();
      assert.equal(bobStarted.status, 201, JSON.stringify(bobStartedBody));
      await answerAll(server, bob.token, bobStartedBody.attempt.id, 2);

      const aliceAttemptAsBob = await server.request(
        `/relationship/assessment-attempts/${aliceStartedBody.attempt.id}/submit`,
        { token: bob.token, method: 'POST' },
      );
      assert.equal(aliceAttemptAsBob.status, 404);

      const bobSubmitted = await server.request(
        `/relationship/couple-assessment-attempts/${bobStartedBody.attempt.id}/submit`,
        { token: bob.token, method: 'POST' },
      );
      const bobSubmittedBody = await bobSubmitted.json();
      assert.equal(bobSubmitted.status, 201, JSON.stringify(bobSubmittedBody));
      assert.equal(bobSubmittedBody.status, 'ready');
      assert.equal(bobSubmittedBody.result.dimensions.length, 3);
      assert.equal('answers' in bobSubmittedBody.result, false);
      assert.equal('user1Score' in bobSubmittedBody.result, false);
      assert.equal('user2Score' in bobSubmittedBody.result, false);

      const aliceReady = await server.request(
        '/relationship/couple-assessment-results/conflict_repair/current',
        { token: alice.token },
      );
      const bobReady = await server.request(
        '/relationship/couple-assessment-results/conflict_repair/current',
        { token: bob.token },
      );
      const aliceReadyBody = await aliceReady.json();
      const bobReadyBody = await bobReady.json();
      assert.equal(aliceReady.status, 200, JSON.stringify(aliceReadyBody));
      assert.equal(bobReady.status, 200, JSON.stringify(bobReadyBody));
      assert.deepEqual(aliceReadyBody, bobReadyBody);

      const personalRoute = await server.request(
        '/relationship/assessment-results/conflict_repair/current',
        { token: alice.token },
      );
      assert.equal(personalRoute.status, 400);

      const separated = await server.request('/user/partner', {
        token: alice.token,
        method: 'DELETE',
      });
      assert.equal(separated.status, 200, await separated.text());
      const afterSeparation = await server.request(
        '/relationship/couple-assessment-results/conflict_repair/current',
        { token: bob.token },
      );
      assert.equal(afterSeparation.status, 409);
      assert.equal((await afterSeparation.json()).reason, 'active_couple_required');
    } finally {
      await server.close();
    }
  },
);
