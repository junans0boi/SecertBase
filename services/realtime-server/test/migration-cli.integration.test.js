import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;
const canonicalMigrations = [
  '0001_initial_schema.sql',
  '0002_runtime_schema_repairs.sql',
  '0003_pairing_requests.sql',
  '0004_couple_lifecycle.sql',
  '0005_map_pin_archival.sql',
  '0006_wallet_system.sql',
  '0007_game_results.sql',
  '0008_shop.sql',
  '0009_repair_shop_catalog_encoding.sql',
  '0010_today_moments.sql',
  '0011_today_loop_views.sql',
  '0012_afterglow.sql',
  '0013_map_pin_reviews.sql',
  '0014_shop_v2.sql',
  '0015_level_missions.sql',
  '0016_milestone_rewards.sql',
  '0017_shop_v3.sql',
  '0018_item_catalog_v2.sql',
  '0019_backdo_bonus.sql',
  '0020_activate_all_items.sql',
  '0021_marble_characters.sql',
  '0022_wallet_transaction_idempotency.sql',
  '0023_user_birth_profile.sql',
  '0024_relationship_assessment_catalog.sql',
  '0025_relationship_assessment_attempts.sql',
  '0026_relationship_assessment_results.sql',
  '0027_relationship_couple_attempt_scope.sql',
  '0028_relationship_couple_assessment_results.sql',
  '0029_relationship_compatibility_analyses.sql',
  '0030_relationship_personal_compatibility_analyses.sql',
  '0031_relationship_couple_compatibility_analyses.sql',
  '0032_relationship_explanation_generations.sql',
  '0033_relationship_fortunes.sql',
  '0034_relationship_counseling.sql',
  '0035_relationship_saju.sql',
  '0036_relationship_saju_couple_results.sql',
  '0037_relationship_tarot_contents.sql',
  '0038_relationship_mindcare.sql',
  '0039_relationship_tarot_user_selection.sql',
  '0040_moment_loop_reactions.sql',
  '0041_user_deletion_tombstones.sql',
  '0042_map_pin_media_url.sql',
];

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
        pending: canonicalMigrations,
      });

      const beforeConnection = await mysql.createConnection(environment.databaseUrl);
      const [beforeTables] = await beforeConnection.query("SHOW TABLES LIKE 'Users'");
      assert.equal(beforeTables.length, 0);
      await beforeConnection.end();

      const firstRun = runMigrationCli(environment, 'up');
      assert.equal(firstRun.status, 0, firstRun.stderr);
      const firstResult = JSON.parse(firstRun.stdout);
      assert.deepEqual(firstResult.applied, canonicalMigrations);

      const connection = await mysql.createConnection(environment.databaseUrl);
      const [tables] = await connection.query("SHOW TABLES LIKE 'Users'");
      assert.equal(tables.length, 1);
      await connection.end();

      const status = runMigrationCli(environment, 'status');
      assert.equal(status.status, 0, status.stderr);
      assert.deepEqual(JSON.parse(status.stdout), {
        applied: canonicalMigrations,
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

test(
  'shop repair migration fixes mojibake without changing business state',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });
    const migrationsDir = await mkdtemp(
      path.join(os.tmpdir(), 'secretbase-shop-repair-'),
    );
    const extraEnv = { TEST_MIGRATIONS_DIR: migrationsDir };

    try {
      await writeFile(
        path.join(migrationsDir, '0001_mojibake_shop.sql'),
        `
          CREATE TABLE shop_items (
            id INT PRIMARY KEY,
            category VARCHAR(20) NOT NULL,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            price INT NOT NULL,
            icon VARCHAR(50),
            active TINYINT(1) NOT NULL
          );
          INSERT INTO shop_items
            (id, category, name, description, price, icon, active)
          VALUES
            (1, 'coupon',
             CONVERT(CAST('데이트 쿠폰' AS BINARY) USING latin1),
             CONVERT(CAST('상대방에게 주는 특별한 약속 쿠폰' AS BINARY) USING latin1),
             777,
             CONVERT(CAST('🎟️' AS BINARY) USING latin1),
             0);
        `,
      );
      const repairSql = await readFile(
        new URL('../migrations/0009_repair_shop_catalog_encoding.sql', import.meta.url),
        'utf8',
      );
      await writeFile(
        path.join(migrationsDir, '0002_repair_shop.sql'),
        repairSql,
      );

      const applied = runMigrationCli(environment, 'up', [], extraEnv);
      assert.equal(applied.status, 0, applied.stderr);

      const connection = await mysql.createConnection(environment.databaseUrl);
      const [rows] = await connection.query(
        'SELECT name, description, price, icon, HEX(icon) AS icon_hex, active FROM shop_items WHERE id = 1',
      );
      assert.deepEqual(rows[0], {
        name: '데이트 쿠폰',
        description: '상대방에게 주는 특별한 약속 쿠폰',
        price: 777,
        icon: '🎟️',
        icon_hex: Buffer.from('🎟️').toString('hex').toUpperCase(),
        active: 0,
      });
      await connection.end();

      const secondRun = runMigrationCli(environment, 'up', [], extraEnv);
      assert.equal(secondRun.status, 0, secondRun.stderr);
      assert.deepEqual(JSON.parse(secondRun.stdout).applied, []);
    } finally {
      await rm(migrationsDir, { recursive: true, force: true });
      await environment.cleanup();
    }
  },
);
