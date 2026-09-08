import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const registerAndLogin = async (server) => {
  const email = `assessment-catalog-${Date.now()}@example.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: 'Assessment Catalog',
      nickname: 'Assessment Catalog',
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
  'assessment catalog exposes seven versioned tests and only active questions',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const token = await registerAndLogin(server);
      const response = await server.request('/relationship/assessments', { token });
      const body = await response.json();

      assert.equal(response.status, 200, JSON.stringify(body));
      assert.equal(body.assessments.length, 7);
      assert.equal(
        body.assessments.filter((assessment) => assessment.audience === 'individual').length,
        4,
      );
      assert.equal(
        body.assessments.filter((assessment) => assessment.audience === 'couple').length,
        3,
      );
      assert.deepEqual(body.likertScale.map((option) => option.value), [1, 2, 3, 4, 5]);

      for (const assessment of body.assessments) {
        assert.equal(assessment.version, 'v1');
        assert.equal(assessment.candidateQuestionCount, 24);
        assert.equal(assessment.activeQuestionCount, 12);
        assert.equal(assessment.completionStatus, 'not_started');
        assert.equal(assessment.dimensions.length, 3);
        assert.equal(assessment.questions.length, 12);
        assert.deepEqual(
          assessment.questions.map((question) => question.order),
          [...assessment.questions].sort((left, right) => left.order - right.order)
            .map((question) => question.order),
        );
        for (const question of assessment.questions) {
          assert.equal(typeof question.reverseScored, 'boolean');
          assert.equal(question.likertScale.length, 5);
        }
      }
    } finally {
      await server.close();
    }
  },
);
