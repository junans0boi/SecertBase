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
  'attachment result requires complete answers and remains private to the user',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const aliceToken = await registerAndLogin(server, 'result-alice');
      const bobToken = await registerAndLogin(server, 'result-bob');
      const started = await server.request('/relationship/assessments/attachment/attempt', {
        token: aliceToken,
        method: 'POST',
      });
      const startedBody = await started.json();
      const attemptId = startedBody.attempt.id;

      const incomplete = await server.request(
        `/relationship/assessment-attempts/${attemptId}/submit`,
        { token: aliceToken, method: 'POST' },
      );
      const incompleteBody = await incomplete.json();
      assert.equal(incomplete.status, 400, JSON.stringify(incompleteBody));
      assert.equal(incompleteBody.reason, 'incomplete_attempt');
      assert.equal(incompleteBody.progress.totalCount, 12);

      const activeQuestionKeys = [
        'q01', 'q02', 'q03', 'q04',
        'q09', 'q10', 'q11', 'q12',
        'q17', 'q18', 'q19', 'q20',
      ];
      for (const questionKey of activeQuestionKeys) {
        const saved = await server.request(
          `/relationship/assessment-attempts/${attemptId}/answers/${questionKey}`,
          { token: aliceToken, method: 'PATCH', body: { value: 4 } },
        );
        assert.equal(saved.status, 200, await saved.text());
      }

      const submitted = await server.request(
        `/relationship/assessment-attempts/${attemptId}/submit`,
        { token: aliceToken, method: 'POST' },
      );
      const submittedBody = await submitted.json();
      assert.equal(submitted.status, 201, JSON.stringify(submittedBody));
      assert.equal(submittedBody.result.assessmentCode, 'attachment');
      assert.equal(submittedBody.result.version, 'v1');
      assert.equal(submittedBody.result.dimensions.length, 3);
      assert.equal(typeof submittedBody.result.overallScore, 'number');
      assert.match(submittedBody.result.disclaimer, /의료적 진단/);
      assert.equal('answers' in submittedBody.result, false);

      const current = await server.request('/relationship/assessment-results/attachment/current', {
        token: aliceToken,
      });
      const currentBody = await current.json();
      assert.equal(current.status, 200, JSON.stringify(currentBody));
      assert.deepEqual(currentBody.result, submittedBody.result);

      const partnerResult = await server.request(
        '/relationship/assessment-results/attachment/current',
        { token: bobToken },
      );
      assert.equal((await partnerResult.json()).result, null);

      const partnerSubmit = await server.request(
        `/relationship/assessment-attempts/${attemptId}/submit`,
        { token: bobToken, method: 'POST' },
      );
      assert.equal(partnerSubmit.status, 404);
      assert.equal((await partnerSubmit.json()).reason, 'attempt_not_found');
    } finally {
      await server.close();
    }
  },
);
