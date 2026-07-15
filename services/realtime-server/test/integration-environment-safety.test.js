import assert from 'node:assert/strict';
import test from 'node:test';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

const safeRedisUrl = 'redis://127.0.0.1:6379';

test('integration harness rejects a production-like database admin target', async () => {
  await assert.rejects(
    createIntegrationEnvironment({
      adminUrl: 'mysql://production:secret@127.0.0.1:3307/secretbase',
      redisUrl: safeRedisUrl,
    }),
    /test database/i,
  );
});

test('integration harness rejects known production servers', async () => {
  await assert.rejects(
    createIntegrationEnvironment({
      adminUrl:
        'mysql://secretbase_test_runner:secret@127.0.0.1:3306/mysql',
      redisUrl: safeRedisUrl,
      productionDatabaseUrl:
        'mysql://production:secret@localhost:3306/secretbase',
    }),
    /known production database/i,
  );

  await assert.rejects(
    createIntegrationEnvironment({
      adminUrl:
        'mysql://secretbase_test_runner:secret@127.0.0.1:3306/mysql',
      redisUrl: safeRedisUrl,
      productionRedisUrl: 'redis://localhost:6379',
    }),
    /known production redis/i,
  );
});
