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
  const email = `${name}-${Date.now()}@relationship-lifecycle.test`;
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
  const { userCode } = await registered.json();
  const loggedIn = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const login = await loggedIn.json();
  assert.equal(loggedIn.status, 200, JSON.stringify(login));
  return { token: login.token, userCode };
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
  const acceptedBody = await accepted.json();
  assert.equal(accepted.status, 200, JSON.stringify(acceptedBody));
  return acceptedBody;
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

const completeCoupleConflict = async (server, token, value) => {
  const started = await server.request(
    '/relationship/couple-assessments/conflict_repair/attempt',
    { token, method: 'POST' },
  );
  const startedBody = await started.json();
  assert.equal(started.status, 201, JSON.stringify(startedBody));
  await answerAll(server, token, startedBody.attempt.id, value);
  const submitted = await server.request(
    `/relationship/couple-assessment-attempts/${startedBody.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  assert.equal(submitted.status, 201, await submitted.text());
};

test(
  'relationship data follows active Couple boundaries across separation, reunion, and a new partner',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const one = await createUser(server, 'lifecycle-one');
      const two = await createUser(server, 'lifecycle-two');
      const three = await createUser(server, 'lifecycle-three');
      const firstPairing = await pair(server, one, two);

      await completePersonalAttachment(server, one.token, 5);
      await completePersonalAttachment(server, two.token, 2);
      await completeCoupleConflict(server, one.token, 5);
      await completeCoupleConflict(server, two.token, 2);

      const beforeSeparation = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: one.token },
      );
      const beforeSeparationBody = await beforeSeparation.json();
      assert.equal(beforeSeparation.status, 200, JSON.stringify(beforeSeparationBody));
      assert.equal(beforeSeparationBody.status, 'ready');

      const staleAttemptResponse = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: one.token, method: 'POST' },
      );
      const staleAttemptBody = await staleAttemptResponse.json();
      assert.equal(staleAttemptResponse.status, 201, JSON.stringify(staleAttemptBody));

      const separated = await server.request('/user/partner', {
        token: one.token,
        method: 'DELETE',
      });
      assert.equal(separated.status, 200, await separated.text());

      const personalAfterSeparation = await server.request(
        '/relationship/assessment-results/attachment/current',
        { token: one.token },
      );
      assert.equal(personalAfterSeparation.status, 200);
      assert.ok((await personalAfterSeparation.json()).result);

      const staleAnswer = await server.request(
        `/relationship/assessment-attempts/${staleAttemptBody.attempt.id}/answers/q01`,
        { token: one.token, method: 'PATCH', body: { value: 4 } },
      );
      assert.equal(staleAnswer.status, 409, await staleAnswer.text());
      assert.equal((await staleAnswer.json()).reason, 'active_couple_required');

      for (const path of [
        '/relationship/couple-assessment-results/conflict_repair/current',
        '/relationship/compatibility/attachment-conflict/current',
        '/relationship/explanations/compatibility/attachment-conflict/current',
      ]) {
        const blocked = await server.request(path, { token: one.token });
        const blockedBody = await blocked.json();
        assert.equal(blocked.status, 409, `${path}: ${JSON.stringify(blockedBody)}`);
        assert.equal(blockedBody.reason, 'active_couple_required');
      }

      const reunited = await pair(server, one, two);
      assert.equal(reunited.coupleId, firstPairing.coupleId);
      assert.equal(reunited.reunited, true);
      const afterReunion = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: two.token },
      );
      const afterReunionBody = await afterReunion.json();
      assert.equal(afterReunion.status, 200, JSON.stringify(afterReunionBody));
      assert.equal(afterReunionBody.status, 'ready');
      assert.deepEqual(afterReunionBody.result, beforeSeparationBody.result);

      await server.request('/user/partner', {
        token: one.token,
        method: 'DELETE',
      });
      const newPairing = await pair(server, one, three);
      assert.notEqual(newPairing.coupleId, firstPairing.coupleId);

      const newCoupleResult = await server.request(
        '/relationship/couple-assessment-results/conflict_repair/current',
        { token: one.token },
      );
      const newCoupleResultBody = await newCoupleResult.json();
      assert.equal(newCoupleResult.status, 200, JSON.stringify(newCoupleResultBody));
      assert.equal(newCoupleResultBody.status, 'pending');
      assert.equal(newCoupleResultBody.result, null);

      const newCompatibility = await server.request(
        '/relationship/compatibility/attachment-conflict/current',
        { token: one.token },
      );
      const newCompatibilityBody = await newCompatibility.json();
      assert.equal(newCompatibility.status, 200, JSON.stringify(newCompatibilityBody));
      assert.equal(newCompatibilityBody.status, 'pending');
      assert.equal(newCompatibilityBody.result, null);
    } finally {
      await server.close();
    }
  },
);
