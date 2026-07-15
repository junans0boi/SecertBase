import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const runMigrationCli = (environment, command, extraArgs = [], extraEnv = {}) =>
  spawnSync(process.execPath, ['scripts/migrate.js', command, '--json', ...extraArgs], {
    cwd: new URL('..', import.meta.url),
    encoding: 'utf8',
    env: { ...process.env, ...environment.environmentVariables, ...extraEnv },
  });

test(
  'migration CLI applies ordered migrations once and reports current status',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });

    try {
      const dryRun = runMigrationCli(environment, 'up', ['--dry-run']);
      assert.equal(dryRun.status, 0, dryRun.stderr);
      assert.deepEqual(JSON.parse(dryRun.stdout), {
        applied: [],
        pending: [
          '0001_initial_schema.sql',
          '0002_runtime_schema_repairs.sql',
          '0003_pairing_requests.sql',
        ],
      });

      const beforeConnection = await mysql.createConnection(environment.databaseUrl);
      const [beforeTables] = await beforeConnection.query("SHOW TABLES LIKE 'Users'");
      assert.equal(beforeTables.length, 0);
      await beforeConnection.end();

      const firstRun = runMigrationCli(environment, 'up');
      assert.equal(firstRun.status, 0, firstRun.stderr);
      const firstResult = JSON.parse(firstRun.stdout);
      assert.deepEqual(firstResult.applied, [
        '0001_initial_schema.sql',
        '0002_runtime_schema_repairs.sql',
        '0003_pairing_requests.sql',
      ]);

      const connection = await mysql.createConnection(environment.databaseUrl);
      const [tables] = await connection.query("SHOW TABLES LIKE 'Users'");
      assert.equal(tables.length, 1);
      await connection.end();

      const status = runMigrationCli(environment, 'status');
      assert.equal(status.status, 0, status.stderr);
      assert.deepEqual(JSON.parse(status.stdout), {
        applied: [
          '0001_initial_schema.sql',
          '0002_runtime_schema_repairs.sql',
          '0003_pairing_requests.sql',
        ],
        pending: [],
      });

      const secondRun = runMigrationCli(environment, 'up');
      assert.equal(secondRun.status, 0, secondRun.stderr);
      assert.deepEqual(JSON.parse(secondRun.stdout).applied, []);
    } finally {
      await environment.cleanup();
    }
  },
);

test(
  'failed migration remains pending and can be retried safely',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });
    const migrationsDir = await mkdtemp(
      path.join(os.tmpdir(), 'secretbase-migrations-'),
    );
    const migrationPath = path.join(migrationsDir, '0001_retry_safe.sql');
    const extraEnv = { TEST_MIGRATIONS_DIR: migrationsDir };

    try {
      await writeFile(
        migrationPath,
        'CREATE TABLE IF NOT EXISTS retry_marker (id INT PRIMARY KEY); INVALID SQL;',
      );
      const failedRun = runMigrationCli(environment, 'up', [], extraEnv);
      assert.notEqual(failedRun.status, 0);

      const pendingStatus = runMigrationCli(environment, 'status', [], extraEnv);
      assert.equal(pendingStatus.status, 0, pendingStatus.stderr);
      assert.deepEqual(JSON.parse(pendingStatus.stdout), {
        applied: [],
        pending: ['0001_retry_safe.sql'],
      });

      await writeFile(
        migrationPath,
        'CREATE TABLE IF NOT EXISTS retry_marker (id INT PRIMARY KEY);',
      );
      const retry = runMigrationCli(environment, 'up', [], extraEnv);
      assert.equal(retry.status, 0, retry.stderr);
      assert.deepEqual(JSON.parse(retry.stdout).applied, ['0001_retry_safe.sql']);
    } finally {
      await rm(migrationsDir, { recursive: true, force: true });
      await environment.cleanup();
    }
  },
);
