import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createIntegrationEnvironment } from '../src/integration-environment.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

test('position migration backfills each author group once and makes request ids unique', {
  skip: !adminUrl || !redisUrl,
}, async () => {
  const environment = await createIntegrationEnvironment({ adminUrl, redisUrl });
  const url = new URL(environment.databaseUrl);
  url.searchParams.set('multipleStatements', 'true');
  const db = await mysql.createConnection(url.href);
  try {
    await db.query(`CREATE TABLE setlog_posts (
      id INT PRIMARY KEY, user_id INT NOT NULL, couple_id INT NOT NULL, session_id VARCHAR(64) NULL
    ) CHARACTER SET utf8mb4`);
    await db.query(`INSERT INTO setlog_posts VALUES
      (9,1,7,'album'),(3,1,7,'album'),(8,2,7,'album'),(4,1,7,NULL)`);
    const sql = await readFile(new URL('../migrations/0044_moment_loop_order_and_requests.sql', import.meta.url), 'utf8');
    await db.query(sql);
    const [posts] = await db.query('SELECT id, position, session_id FROM setlog_posts ORDER BY id');
    assert.deepEqual(posts.map(p => [p.id, p.position]), [[3,0],[4,0],[8,0],[9,1]]);
    assert.equal(posts.find(p => p.id === 4).session_id, 'legacy-post-4');
    await db.query('UPDATE setlog_posts SET position = 7 WHERE id = 9');
    await db.query(sql);
    const [[reordered]] = await db.query('SELECT position FROM setlog_posts WHERE id = 9');
    assert.equal(reordered.position, 7);
    await db.query("UPDATE setlog_posts SET client_request_id = 'request' WHERE id = 3");
    await assert.rejects(db.query("UPDATE setlog_posts SET client_request_id = 'request' WHERE id = 9"),
      error => error.code === 'ER_DUP_ENTRY');
    await db.query("UPDATE setlog_posts SET client_request_id = 'REQUEST' WHERE id = 9");
  } finally {
    await db.end();
    await environment.cleanup();
  }
});
