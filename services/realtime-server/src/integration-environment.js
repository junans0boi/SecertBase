import { randomUUID } from 'node:crypto';
import { mkdir, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import Redis from 'ioredis';
import mysql from 'mysql2/promise';
import { assertSafeTestEnvironment } from './target-safety.js';

const deleteRedisNamespace = async (redisUrl, namespace) => {
  const redis = new Redis(redisUrl);
  let cursor = '0';

  try {
    do {
      const [nextCursor, keys] = await redis.scan(
        cursor,
        'MATCH',
        `${namespace}*`,
        'COUNT',
        100,
      );
      cursor = nextCursor;
      if (keys.length > 0) await redis.del(...keys);
    } while (cursor !== '0');
  } finally {
    await redis.quit();
  }
};

const dropTestDatabase = async (adminUrl, databaseName) => {
  const admin = await mysql.createConnection(adminUrl);
  try {
    await admin.query(`DROP DATABASE IF EXISTS \`${databaseName}\``);
  } finally {
    await admin.end();
  }
};

export async function createIntegrationEnvironment({
  adminUrl,
  redisUrl,
  productionDatabaseUrl = process.env.PRODUCTION_DATABASE_URL,
  productionRedisUrl = process.env.PRODUCTION_REDIS_URL,
}) {
  const runId = `${process.pid}-${randomUUID()}`;
  const databaseName = `secretbase_test_${runId.replaceAll('-', '_')}`;
  const redisNamespace = `secretbase:test:${runId}:`;
  const tempRoot = path.join(os.tmpdir(), `secretbase-test-${runId}`);
  const uploadsRoot = path.join(tempRoot, 'uploads');

  assertSafeTestEnvironment({
    databaseAdminUrl: adminUrl,
    redisUrl,
    redisNamespace,
    uploadsRoot,
    productionDatabaseUrl,
    productionRedisUrl,
  });

  const databaseUrl = new URL(adminUrl);
  databaseUrl.pathname = `/${databaseName}`;
  const admin = await mysql.createConnection(adminUrl);
  const redis = new Redis(redisUrl, { keyPrefix: redisNamespace });
  let cleaned = false;

  try {
    await admin.query(
      `CREATE DATABASE \`${databaseName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    );
    await redis.ping();
    await mkdir(uploadsRoot, { recursive: true });
  } catch (error) {
    redis.disconnect();
    await admin.query(`DROP DATABASE IF EXISTS \`${databaseName}\``);
    await admin.end();
    await rm(tempRoot, { recursive: true, force: true });
    throw error;
  }
  await admin.end();

  return {
    databaseName,
    databaseUrl: databaseUrl.href,
    redis,
    redisNamespace,
    uploadsRoot,
    environmentVariables: {
      NODE_ENV: 'test',
      DATABASE_URL: databaseUrl.href,
      REDIS_URL: redisUrl,
      REDIS_KEY_PREFIX: redisNamespace,
      UPLOADS_ROOT: uploadsRoot,
      ...(productionDatabaseUrl
        ? { PRODUCTION_DATABASE_URL: productionDatabaseUrl }
        : {}),
      ...(productionRedisUrl
        ? { PRODUCTION_REDIS_URL: productionRedisUrl }
        : {}),
    },
    async cleanup() {
      if (cleaned) return;
      redis.disconnect();
      const results = await Promise.allSettled([
        deleteRedisNamespace(redisUrl, redisNamespace),
        dropTestDatabase(adminUrl, databaseName),
        rm(tempRoot, { recursive: true, force: true }),
      ]);
      const failures = results
        .filter((result) => result.status === 'rejected')
        .map((result) => result.reason);

      if (failures.length > 0) {
        throw new AggregateError(failures, 'Integration environment cleanup failed');
      }
      cleaned = true;
    },
  };
}
