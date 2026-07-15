import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';

dotenv.config({ quiet: true });

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const migrationsDir =
  process.env.NODE_ENV === 'test' && process.env.TEST_MIGRATIONS_DIR
    ? path.resolve(process.env.TEST_MIGRATIONS_DIR)
    : path.join(rootDir, 'migrations');
const command = process.argv[2] ?? 'status';
const jsonOutput = process.argv.includes('--json');
const dryRun = process.argv.includes('--dry-run');
const backupRefIndex = process.argv.indexOf('--backup-ref');
const backupReference = backupRefIndex >= 0
  ? process.argv[backupRefIndex + 1]
  : process.env.MIGRATION_BACKUP_REFERENCE;

const checksum = (sql) => createHash('sha256').update(sql).digest('hex');

const loadMigrations = async () => {
  const names = (await readdir(migrationsDir))
    .filter((name) => /^\d{4}_[a-z0-9_]+\.sql$/.test(name))
    .sort();

  return Promise.all(
    names.map(async (name) => {
      const sql = await readFile(path.join(migrationsDir, name), 'utf8');
      return { name, sql, checksum: checksum(sql) };
    }),
  );
};

const createConnection = async (databaseUrl) => {
  const url = new URL(databaseUrl);
  url.searchParams.set('multipleStatements', 'true');
  return mysql.createConnection(url.href);
};

const ensureMigrationTable = (connection) =>
  connection.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name VARCHAR(255) PRIMARY KEY,
      checksum CHAR(64) NOT NULL,
      applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `);

const readApplied = async (connection) => {
  try {
    const [rows] = await connection.query(
      'SELECT name, checksum FROM schema_migrations ORDER BY name',
    );
    return new Map(rows.map((row) => [row.name, row.checksum]));
  } catch (error) {
    if (error.code === 'ER_NO_SUCH_TABLE') return new Map();
    throw error;
  }
};

const migrationStatus = async (connection, migrations) => {
  const applied = await readApplied(connection);

  for (const migration of migrations) {
    const recordedChecksum = applied.get(migration.name);
    if (recordedChecksum && recordedChecksum !== migration.checksum) {
      throw new Error(`Applied migration checksum changed: ${migration.name}`);
    }
  }

  return {
    applied: migrations.filter(({ name }) => applied.has(name)).map(({ name }) => name),
    pending: migrations.filter(({ name }) => !applied.has(name)).map(({ name }) => name),
  };
};

const migrateUp = async (connection, migrations) => {
  const lockName = 'secretbase_schema_migrations';
  const [[lock]] = await connection.query('SELECT GET_LOCK(?, 10) AS acquired', [lockName]);
  if (lock.acquired !== 1) throw new Error('Could not acquire migration lock');

  try {
    await ensureMigrationTable(connection);
    const before = await migrationStatus(connection, migrations);
    const applied = [];

    for (const name of before.pending) {
      const migration = migrations.find((item) => item.name === name);
      await connection.query(migration.sql);
      await connection.query(
        'INSERT INTO schema_migrations (name, checksum) VALUES (?, ?)',
        [migration.name, migration.checksum],
      );
      applied.push(migration.name);
    }

    return { applied };
  } finally {
    await connection.query('SELECT RELEASE_LOCK(?)', [lockName]);
  }
};

const print = (result) => {
  if (jsonOutput) {
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }

  if ('pending' in result) {
    process.stdout.write(`Applied: ${result.applied.length}\nPending: ${result.pending.length}\n`);
  } else {
    process.stdout.write(`Applied ${result.applied.length} migration(s)\n`);
  }
};

const main = async () => {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  if (!['status', 'up'].includes(command)) throw new Error(`Unknown migration command: ${command}`);
  if (dryRun && command !== 'up') throw new Error('--dry-run is supported only with up');
  if (
    command === 'up' &&
    !dryRun &&
    process.env.NODE_ENV === 'production' &&
    !backupReference?.trim()
  ) {
    throw new Error(
      'Production migration up requires a backup reference via --backup-ref or MIGRATION_BACKUP_REFERENCE',
    );
  }

  const migrations = await loadMigrations();
  const connection = await createConnection(process.env.DATABASE_URL);

  try {
    const result = command === 'up' && !dryRun
      ? await migrateUp(connection, migrations)
      : await migrationStatus(connection, migrations);
    print(result);
  } finally {
    await connection.end();
  }
};

main().catch((error) => {
  process.stderr.write(`Migration failed: ${error.message}\n`);
  process.exitCode = 1;
});
