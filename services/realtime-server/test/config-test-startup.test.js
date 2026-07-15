import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

const cleanProcessEnv = { ...process.env };
delete cleanProcessEnv.PRODUCTION_DATABASE_URL;
delete cleanProcessEnv.PRODUCTION_REDIS_URL;

const safeRuntime = {
  NODE_ENV: 'test',
  CORS_ORIGIN: 'http://localhost:4100',
  DATABASE_URL:
    'mysql://secretbase_test_runner:secret@127.0.0.1:3306/secretbase_test_run_123',
  REDIS_URL: 'redis://127.0.0.1:6379',
  REDIS_KEY_PREFIX: 'secretbase:test:guard:',
  UPLOADS_ROOT: path.join(os.tmpdir(), 'secretbase-test-guard', 'uploads'),
  JWT_SECRET: 'test-secret-that-is-at-least-32-characters',
  ROOM_SECRET: 'test-room',
  ALLOWED_USERS: 'test-one,test-two',
};

const runConfig = (overrides = {}) =>
  spawnSync(
    process.execPath,
    ['--input-type=module', '--eval', "await import('./src/config.js')"],
    {
      cwd: new URL('..', import.meta.url),
      encoding: 'utf8',
      env: { ...cleanProcessEnv, ...safeRuntime, ...overrides },
    },
  );

test('server config exits before connecting to a production-like target in test mode', () => {
  const result = runConfig({
    DATABASE_URL:
      'mysql://secretbase_user:secret@127.0.0.1:3307/secretbase',
    REDIS_URL: 'redis://127.0.0.1:6380',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /test database/i);
});

test('server config rejects a known production database endpoint', () => {
  const result = runConfig({
    PRODUCTION_DATABASE_URL:
      'mysql://production:secret@localhost:3306/secretbase',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /known production database/i);
});

test('server config rejects a known production Redis endpoint', () => {
  const result = runConfig({ PRODUCTION_REDIS_URL: 'redis://localhost:6379' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /known production redis/i);
});

test('server config requires an isolated Redis namespace and temporary uploads', () => {
  const namespaceResult = runConfig({ REDIS_KEY_PREFIX: '' });
  assert.notEqual(namespaceResult.status, 0);
  assert.match(namespaceResult.stderr, /namespace/i);

  const uploadsResult = runConfig({ UPLOADS_ROOT: '/srv/secretbase/uploads' });
  assert.notEqual(uploadsResult.status, 0);
  assert.match(uploadsResult.stderr, /uploads/i);
});

test('server config accepts isolated test runtime targets', () => {
  const result = runConfig();
  assert.equal(result.status, 0, result.stderr);
});
