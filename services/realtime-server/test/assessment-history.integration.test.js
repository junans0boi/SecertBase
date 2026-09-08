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

const completeAttempt = async (server, token, value) => {
  const started = await server.request('/relationship/assessments/attachment/attempt', {
    token,
    method: 'POST',
  });
  const startedBody = await started.json();
  for (const questionKey of activeQuestionKeys) {
    const saved = await server.request(
      `/relationship/assessment-attempts/${startedBody.attempt.id}/answers/${questionKey}`,
      { token, method: 'PATCH', body: { value } },
    );
    assert.equal(saved.status, 200, await saved.text());
  }
  const submitted = await server.request(
    `/relationship/assessment-attempts/${startedBody.attempt.id}/submit`,
    { token, method: 'POST' },
  );
  const submittedBody = await submitted.json();
  assert.equal(submitted.status, 201, JSON.stringify(submittedBody));
  return { attemptId: startedBody.attempt.id, result: submittedBody.result };
};

test(
  'retake creates a new attempt while current and history remain user-scoped',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const aliceToken = await registerAndLogin(server, 'history-alice');
      const bobToken = await registerAndLogin(server, 'history-bob');
      const first = await completeAttempt(server, aliceToken, 3);

      const catalogAfterFirst = await server.request('/relationship/assessments', {
        token: aliceToken,
      });
      const catalogBody = await catalogAfterFirst.json();
      const attachment = catalogBody.assessments.find((item) => item.code === 'attachment');
      assert.equal(attachment.completionStatus, 'completed');

      const secondStart = await server.request('/relationship/assessments/attachment/attempt', {
        token: aliceToken,
        method: 'POST',
      });
      const secondBody = await secondStart.json();
      assert.equal(secondStart.status, 201, JSON.stringify(secondBody));
      assert.notEqual(secondBody.attempt.id, first.attemptId);

      const current = await server.request('/relationship/assessment-results/attachment/current', {
        token: aliceToken,
      });
      const currentBody = await current.json();
      assert.deepEqual(currentBody.result, first.result);

      const history = await server.request('/relationship/assessment-results/attachment/history', {
        token: aliceToken,
      });
      const historyBody = await history.json();
      assert.equal(historyBody.history.length, 1);
      assert.equal(historyBody.history[0].id > 0, true);
      assert.equal('answers' in historyBody.history[0].result, false);

      const partnerHistory = await server.request(
        '/relationship/assessment-results/attachment/history',
        { token: bobToken },
      );
      assert.deepEqual((await partnerHistory.json()).history, []);
    } finally {
      await server.close();
    }
  },
);
