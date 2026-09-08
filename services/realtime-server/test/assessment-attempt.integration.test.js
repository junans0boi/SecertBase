import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const registerAndLogin = async (server, name) => {
  const email = `${name}-${Date.now()}@example.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '2000-01-01',
    },
  });
  assert.equal(registration.status, 200, await registration.text());

  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return body.token;
};

test(
  'personal assessment attempts can start, resume, save answers, and stay private',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const aliceToken = await registerAndLogin(server, 'attempt-alice');
      const bobToken = await registerAndLogin(server, 'attempt-bob');

      const started = await server.request('/relationship/assessments/attachment/attempt', {
        token: aliceToken,
        method: 'POST',
      });
      const startedBody = await started.json();
      assert.equal(started.status, 201, JSON.stringify(startedBody));
      assert.equal(startedBody.resumed, false);
      assert.equal(startedBody.attempt.progress.totalCount, 12);
      assert.equal(startedBody.attempt.progress.answeredCount, 0);
      const attemptId = startedBody.attempt.id;

      const resumed = await server.request('/relationship/assessments/attachment/attempt', {
        token: aliceToken,
        method: 'POST',
      });
      const resumedBody = await resumed.json();
      assert.equal(resumed.status, 200, JSON.stringify(resumedBody));
      assert.equal(resumedBody.resumed, true);
      assert.equal(resumedBody.attempt.id, attemptId);

      const saved = await server.request(
        `/relationship/assessment-attempts/${attemptId}/answers/q01`,
        { token: aliceToken, method: 'PATCH', body: { value: 5 } },
      );
      const savedBody = await saved.json();
      assert.equal(saved.status, 200, JSON.stringify(savedBody));
      assert.equal(savedBody.attempt.progress.answeredCount, 1);
      assert.deepEqual(savedBody.attempt.answers[0], {
        questionKey: 'q01',
        value: 5,
        savedAt: savedBody.attempt.answers[0].savedAt,
      });

      const current = await server.request('/relationship/assessments/attachment/attempt', {
        token: aliceToken,
      });
      const currentBody = await current.json();
      assert.equal(current.status, 200, JSON.stringify(currentBody));
      assert.equal(currentBody.attempt.id, attemptId);
      assert.equal(currentBody.attempt.answers[0].value, 5);

      const invalidValue = await server.request(
        `/relationship/assessment-attempts/${attemptId}/answers/q02`,
        { token: aliceToken, method: 'PATCH', body: { value: 6 } },
      );
      assert.equal(invalidValue.status, 400);
      assert.equal((await invalidValue.json()).reason, 'invalid_answer_value');

      const missingQuestion = await server.request(
        `/relationship/assessment-attempts/${attemptId}/answers/q99`,
        { token: aliceToken, method: 'PATCH', body: { value: 3 } },
      );
      assert.equal(missingQuestion.status, 404);
      assert.equal((await missingQuestion.json()).reason, 'question_not_found');

      const partnerRead = await server.request('/relationship/assessments/attachment/attempt', {
        token: bobToken,
      });
      assert.equal((await partnerRead.json()).attempt, null);

      const partnerWrite = await server.request(
        `/relationship/assessment-attempts/${attemptId}/answers/q02`,
        { token: bobToken, method: 'PATCH', body: { value: 4 } },
      );
      assert.equal(partnerWrite.status, 404);
      assert.equal((await partnerWrite.json()).reason, 'attempt_not_found');
    } finally {
      await server.close();
    }
  },
);
