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
  const email = `${name}-${Date.now()}@conflict-compatibility.test`;
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

const completePersonal = async (server, token) => {
  const started = await server.request('/relationship/assessments/attachment/attempt', {
    token,
    method: 'POST',
  });
  const body = await started.json();
  assert.equal(started.status, 201, JSON.stringify(body));
  await answerAll(server, token, body.attempt.id, 4);
  const submitted = await server.request(
    `/relationship/assessment-attempts/${body.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

const completeConflict = async (server, token, value) => {
  const started = await server.request(
    '/relationship/couple-assessments/conflict_repair/attempt',
    { token, method: 'POST' },
  );
  const body = await started.json();
  assert.equal(started.status, 201, JSON.stringify(body));
  await answerAll(server, token, body.attempt.id, value);
  const submitted = await server.request(
    `/relationship/couple-assessment-attempts/${body.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

test(
  'conflict repair compatibility exposes trigger, repair, and dialogue start without personal scores',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'conflict-compatibility-alice');
      const bob = await createUser(server, 'conflict-compatibility-bob');
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

      await completePersonal(server, alice.token);
      await completePersonal(server, bob.token);
      await completeConflict(server, alice.token, 5);
      await completeConflict(server, bob.token, 2);

      const aliceResponse = await server.request(
        '/relationship/compatibility/conflict-repair/current',
        { token: alice.token },
      );
      const bobResponse = await server.request(
        '/relationship/compatibility/conflict-repair/current',
        { token: bob.token },
      );
      const aliceBody = await aliceResponse.json();
      const bobBody = await bobResponse.json();
      assert.equal(aliceResponse.status, 200, JSON.stringify(aliceBody));
      assert.equal(bobResponse.status, 200, JSON.stringify(bobBody));
      assert.deepEqual(aliceBody, bobBody);
      assert.equal(aliceBody.result.analysisCode, 'conflict_repair');
      assert.deepEqual(
        aliceBody.result.dimensions.map((dimension) => dimension.key),
        ['conflict_trigger', 'repair_approach', 'dialogue_start'],
      );
      assert.equal(typeof aliceBody.result.conflictTrigger, 'string');
      assert.equal(typeof aliceBody.result.repairApproach, 'string');
      assert.equal(aliceBody.result.conversationPrompts.length, 3);
      assert.equal('answers' in aliceBody.result, false);
      assert.equal('user1Score' in aliceBody.result, false);
    } finally {
      await server.close();
    }
  },
);
