import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

test('production migration up requires a backup reference', () => {
  const result = spawnSync(
    process.execPath,
    ['scripts/migrate.js', 'up', '--json'],
    {
      cwd: new URL('..', import.meta.url),
      encoding: 'utf8',
      env: {
        ...process.env,
        NODE_ENV: 'production',
        DATABASE_URL: 'mysql://unused:unused@127.0.0.1:1/unused',
      },
    },
  );

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /backup reference/i);
});
