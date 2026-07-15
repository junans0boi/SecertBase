import assert from 'node:assert/strict';
import { access } from 'node:fs/promises';
import test from 'node:test';
import mysql from 'mysql2/promise';
import Redis from 'ioredis';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

test(
  'integration environment creates and cleans isolated database, Redis, and uploads resources',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });
    const database = await mysql.createConnection(environment.databaseUrl);
    const rawRedis = new Redis(redisUrl);

    await database.query('CREATE TABLE harness_marker (id INT PRIMARY KEY)');
    await environment.redis.set('marker', 'present');
    await access(environment.uploadsRoot);

    await environment.cleanup();
    await database.end();

    const [schemas] = await mysql
      .createConnection(adminUrl)
      .then(async (connection) => {
        try {
          return await connection.query(
            'SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?',
            [environment.databaseName],
          );
        } finally {
          await connection.end();
        }
      });
    assert.equal(schemas.length, 0);
    assert.equal(await rawRedis.get(`${environment.redisNamespace}marker`), null);
    await assert.rejects(access(environment.uploadsRoot));
    await environment.cleanup();

    await rawRedis.quit();
  },
);
