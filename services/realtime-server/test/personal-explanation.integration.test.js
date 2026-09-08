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

test(
  'personal explanation is explicit, fallback-safe, and separate from the core result',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const email = `personal-explanation-${Date.now()}@example.test`;
      const registered = await server.request('/auth/register', {
        method: 'POST',
        body: {
          email,
          password: 'password123',
          full_name: '설명 사용자',
          nickname: '설명 사용자',
          birth_date: '2000-01-01',
        },
      });
      assert.equal(registered.status, 200, await registered.text());
      const login = await server.request('/auth/login', {
        method: 'POST',
        body: { email, password: 'password123' },
      });
      const token = (await login.json()).token;

      const started = await server.request('/relationship/assessments/attachment/attempt', {
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
      assert.equal(submitted.status, 201, await submitted.text());
      const before = await server.request(
        '/relationship/assessment-results/attachment/current',
        { token },
      );
      const beforeBody = await before.json();

      const idle = await server.request(
        '/relationship/explanations/personal/attachment/current',
        { token },
      );
      const idleBody = await idle.json();
      assert.equal(idle.status, 200, JSON.stringify(idleBody));
      assert.equal(idleBody.status, 'idle');

      const requested = await server.request(
        '/relationship/explanations/personal/attachment',
        { token, method: 'POST' },
      );
      const requestedBody = await requested.json();
      assert.equal(requested.status, 201, JSON.stringify(requestedBody));
      assert.equal(requestedBody.status, 'fallback');
      assert.equal(requestedBody.generation.provider, 'disabled');
      assert.equal('input' in requestedBody.generation, false);
      assert.equal('answers' in requestedBody.generation, false);

      const after = await server.request(
        '/relationship/assessment-results/attachment/current',
        { token },
      );
      const afterBody = await after.json();
      assert.deepEqual(afterBody.result, beforeBody.result);

      const current = await server.request(
        '/relationship/explanations/personal/attachment/current',
        { token },
      );
      const currentBody = await current.json();
      assert.equal(currentBody.status, 'fallback');
      assert.match(currentBody.generation.explanation, /점수와 경향/);
    } finally {
      await server.close();
    }
  },
);
