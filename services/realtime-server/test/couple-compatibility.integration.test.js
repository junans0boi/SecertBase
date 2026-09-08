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
  const email = `${name}-${Date.now()}@couple-compatibility.test`;
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

const completeCouple = async (server, token, code, value) => {
  const started = await server.request(
    `/relationship/couple-assessments/${code}/attempt`,
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
  'couple compatibility cards are independent by source assessment',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'couple-compatibility-alice');
      const bob = await createUser(server, 'couple-compatibility-bob');
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

      await completeCouple(server, alice.token, 'togetherness_personal_time', 5);
      await completeCouple(server, bob.token, 'togetherness_personal_time', 2);

      const togetherness = await server.request(
        '/relationship/compatibility/togetherness-personal-time/current',
        { token: alice.token },
      );
      const togethernessBody = await togetherness.json();
      assert.equal(togetherness.status, 200, JSON.stringify(togethernessBody));
      assert.equal(togethernessBody.status, 'ready');
      assert.equal(
        togethernessBody.result.analysisCode,
        'togetherness-personal-time_compatibility',
      );
      assert.equal(togethernessBody.result.conversationPrompts.length, 3);
      assert.equal('answers' in togethernessBody.result, false);

      const affection = await server.request(
        '/relationship/compatibility/affection-alignment/current',
        { token: bob.token },
      );
      const affectionBody = await affection.json();
      assert.equal(affection.status, 200, JSON.stringify(affectionBody));
      assert.equal(affectionBody.status, 'pending');
      assert.equal(affectionBody.result, null);
    } finally {
      await server.close();
    }
  },
);
