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
  const email = `${name}-${Date.now()}@personal-compatibility.test`;
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

const complete = async (server, token, code, value) => {
  const started = await server.request(`/relationship/assessments/${code}/attempt`, {
    token,
    method: 'POST',
  });
  const body = await started.json();
  assert.equal(started.status, 201, JSON.stringify(body));
  await answerAll(server, token, body.attempt.id, value);
  const submitted = await server.request(
    `/relationship/assessment-attempts/${body.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

test(
  'personal compatibility cards become ready independently by assessment',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'personal-compatibility-alice');
      const bob = await createUser(server, 'personal-compatibility-bob');
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

      await complete(server, alice.token, 'emotional_regulation', 5);
      await complete(server, bob.token, 'emotional_regulation', 2);

      const socialPending = await server.request(
        '/relationship/compatibility/social-bonding/current',
        { token: alice.token },
      );
      const socialPendingBody = await socialPending.json();
      assert.equal(socialPending.status, 200, JSON.stringify(socialPendingBody));
      assert.equal(socialPendingBody.status, 'pending');

      const emotionalReady = await server.request(
        '/relationship/compatibility/emotional-regulation/current',
        { token: alice.token },
      );
      const emotionalReadyBody = await emotionalReady.json();
      assert.equal(emotionalReady.status, 200, JSON.stringify(emotionalReadyBody));
      assert.equal(emotionalReadyBody.status, 'ready');
      assert.equal(
        emotionalReadyBody.result.analysisCode,
        'emotional-regulation_compatibility',
      );
      assert.deepEqual(
        emotionalReadyBody.result.dimensions.map((dimension) => dimension.key),
        ['internal_gap', 'stimulation_gap', 'dialogue_gap'],
      );
      assert.equal('answers' in emotionalReadyBody.result, false);
      assert.equal('user1Score' in emotionalReadyBody.result, false);

      const deficiencyPending = await server.request(
        '/relationship/compatibility/relationship-deficiency/current',
        { token: bob.token },
      );
      assert.equal(deficiencyPending.status, 200);
      assert.equal((await deficiencyPending.json()).status, 'pending');
    } finally {
      await server.close();
    }
  },
);
