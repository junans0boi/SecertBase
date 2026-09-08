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
  const email = `${name}-${Date.now()}@compatibility.test`;
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

const completePersonalAttachment = async (server, token, value) => {
  const started = await server.request('/relationship/assessments/attachment/attempt', {
    token,
    method: 'POST',
  });
  const startedBody = await started.json();
  assert.equal(started.status, 201, JSON.stringify(startedBody));
  await answerAll(server, token, startedBody.attempt.id, value);
  const submitted = await server.request(
    `/relationship/assessment-attempts/${startedBody.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

const startCouple = async (server, token) => {
  const started = await server.request(
    '/relationship/couple-assessments/conflict_repair/attempt',
    { token, method: 'POST' },
  );
  const body = await started.json();
  assert.equal(started.status, 201, JSON.stringify(body));
  return body.attempt.id;
};

const completeCouple = async (server, token, attemptId, value) => {
  await answerAll(server, token, attemptId, value);
  const submitted = await server.request(
    `/relationship/couple-assessment-attempts/${attemptId}/submit`,
    { token, method: 'POST' },
  );
  return submitted.json();
};

test(
  'attachment and conflict summaries gate a shared deterministic compatibility card',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'compatibility-alice');
      const bob = await createUser(server, 'compatibility-bob');
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

      await completePersonalAttachment(server, alice.token, 5);
      await completePersonalAttachment(server, bob.token, 2);
      const aliceConflictAttempt = await startCouple(server, alice.token);
      const bobConflictAttempt = await startCouple(server, bob.token);

      const alicePendingSubmit = await completeCouple(
        server,
        alice.token,
        aliceConflictAttempt,
        5,
      );
      assert.equal(alicePendingSubmit.status, 'pending');
      const pending = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: alice.token },
      );
      const pendingBody = await pending.json();
      assert.equal(pending.status, 200, JSON.stringify(pendingBody));
      assert.equal(pendingBody.status, 'pending');
      assert.equal(pendingBody.result, null);

      const readySubmit = await completeCouple(
        server,
        bob.token,
        bobConflictAttempt,
        2,
      );
      assert.equal(readySubmit.status, 'ready');

      const aliceReady = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: alice.token },
      );
      const bobReady = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: bob.token },
      );
      const aliceBody = await aliceReady.json();
      const bobBody = await bobReady.json();
      assert.equal(aliceReady.status, 200, JSON.stringify(aliceBody));
      assert.equal(bobReady.status, 200, JSON.stringify(bobBody));
      assert.deepEqual(aliceBody, bobBody);
      assert.equal(aliceBody.status, 'ready');
      assert.equal(aliceBody.result.analysisCode, 'attachment_conflict');
      assert.equal(aliceBody.result.dimensions.length, 3);
      assert.equal('answers' in aliceBody.result, false);
      assert.equal('user1Score' in aliceBody.result, false);
      assert.equal('user2Score' in aliceBody.result, false);
      assert.equal(aliceBody.result.conversationPrompts.length, 3);

      const repeated = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: alice.token },
      );
      assert.deepEqual(await repeated.json(), aliceBody);

      await server.request('/user/partner', {
        token: alice.token,
        method: 'DELETE',
      });
      const afterSeparation = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: bob.token },
      );
      assert.equal(afterSeparation.status, 409);
    } finally {
      await server.close();
    }
  },
);
