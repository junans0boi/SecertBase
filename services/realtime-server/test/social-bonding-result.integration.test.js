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

const registerAndLogin = async (server) => {
  const email = `social-bonding-${Date.now()}@example.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: 'Social Bonding',
      nickname: 'Social Bonding',
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
  'social bonding personal assessment uses its own deterministic dimensions',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const token = await registerAndLogin(server);
      const started = await server.request('/relationship/assessments/social_bonding/attempt', {
        token,
        method: 'POST',
      });
      const startedBody = await started.json();
      assert.equal(started.status, 201, JSON.stringify(startedBody));

      for (const questionKey of activeQuestionKeys) {
        const saved = await server.request(
          `/relationship/assessment-attempts/${startedBody.attempt.id}/answers/${questionKey}`,
          { token, method: 'PATCH', body: { value: 4 } },
        );
        assert.equal(saved.status, 200, await saved.text());
      }

      const submitted = await server.request(
        `/relationship/assessment-attempts/${startedBody.attempt.id}/submit`,
        { token, method: 'POST' },
      );
      const body = await submitted.json();
      assert.equal(submitted.status, 201, JSON.stringify(body));
      assert.equal(body.result.assessmentCode, 'social_bonding');
      assert.deepEqual(
        body.result.dimensions.map((dimension) => dimension.key),
        ['depth', 'dependence', 'isolation'],
      );
      assert.equal(body.result.overallTendencyKey, 'developing_connections');
      assert.match(body.result.disclaimer, /자기이해/);
    } finally {
      await server.close();
    }
  },
);
