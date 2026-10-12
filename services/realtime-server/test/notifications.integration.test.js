import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import express from 'express';
import jwt from 'jsonwebtoken';
import mysql from 'mysql2/promise';
import Redis from 'ioredis';
import { requireAuth } from '../src/backend-access.js';
import { createNotificationRouter } from '../src/modules/notifications/http-router.js';
import { createNotifier, notifyRevealedTodayLoops } from '../src/modules/notifications/notifier.js';

// Dedicated disposable services only; never share a normal dev/production port.
const adminUrl = process.env.NOTIFICATION_TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.NOTIFICATION_TEST_REDIS_URL;
const secret = 'notification-integration-fixture-at-least-32-characters';
const silent = { log() {}, error() {} };

async function harness() {
  const adminTarget = new URL(adminUrl);
  const redisTarget = new URL(redisUrl);
  assert.equal(adminTarget.protocol, 'mysql:');
  assert.equal(adminTarget.hostname, '127.0.0.1');
  assert.equal(adminTarget.port, '33399');
  assert.equal(adminTarget.pathname, '/mysql');
  assert.match(adminTarget.username, /test/);
  assert.equal(redisTarget.protocol, 'redis:');
  assert.equal(redisTarget.hostname, '127.0.0.1');
  assert.equal(redisTarget.port, '63399');
  const id = randomUUID().replaceAll('-', '_');
  const databaseName = `secretbase_test_${id}`;
  const namespace = `secretbase:notification:test:${id}:`;
  const admin = await mysql.createConnection(adminUrl);
  let database;
  let httpServer;
  const redis = new Redis(redisUrl, { keyPrefix: namespace });
  const cleanup = async () => {
    if (httpServer) await new Promise((resolve) => httpServer.close(resolve));
    if (database) await database.end();
    const keys = await redis.keys(`${namespace}*`);
    // Returned keys already include the prefix; remove it before ioredis adds it.
    if (keys.length) await redis.del(...keys.map((key) => key.slice(namespace.length)));
    await redis.quit();
    try { await admin.query(`DROP DATABASE IF EXISTS \`${databaseName}\``); }
    finally { await admin.end(); }
  };
  try {
    await admin.query(`CREATE DATABASE \`${databaseName}\` CHARACTER SET utf8mb4`);
    const target = new URL(adminUrl);
    target.pathname = `/${databaseName}`;
    const migration = spawnSync(process.execPath, ['scripts/migrate.js', 'up'], {
      cwd: new URL('..', import.meta.url), encoding: 'utf8',
      env: { ...process.env, NODE_ENV: 'test', DATABASE_URL: target.href },
    });
    assert.equal(migration.status, 0, migration.stderr);
    database = await mysql.createConnection(target.href);
    const queryFn = async (sql, params = []) => {
      const [rows] = await database.execute(sql, params);
      return { rows };
    };
    for (const [userId, code] of [[1, 'ALICE'], [2, 'BOB']]) {
      await queryFn(`INSERT INTO Users (UserId, Email, UserName, FullName, Nickname, BirthDate, UserCode)
        VALUES (?, ?, ?, ?, ?, '2000-01-01', ?)`, [userId, `${code}@example.test`, code, code, code, code]);
    }
    await queryFn(`INSERT INTO Couples (CoupleId, RoomCode, RoomSecret, User1Id, User2Id, Status, PairKey)
      VALUES (7, 'room_1_2', 'fixture', 1, 2, 'active', '1:2')`);
    const app = express();
    app.use(express.json());
    app.use('/api', requireAuth(secret), createNotificationRouter({ queryFn }));
    httpServer = createServer(app);
    await new Promise((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
    const base = `http://127.0.0.1:${httpServer.address().port}/api`;
    const request = (userId, method, path, body, tokenOverride) => fetch(base + path, {
      method, headers: { 'content-type': 'application/json', ...(userId ? {
        authorization: `Bearer ${tokenOverride ?? jwt.sign({ userId, userCode: userId === 1 ? 'ALICE' : 'BOB' }, secret)}`,
      } : {}) },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { queryFn, redis, request, cleanup };
  } catch (error) {
    await cleanup();
    throw error;
  }
}

test('JWT token registration/reassignment/revocation, preferences, and partner FCM delivery integrate through REST',
  { skip: !adminUrl || !redisUrl }, async () => {
    const h = await harness();
    try {
      const messages = [];
      let dead = false;
      const notifier = createNotifier({ queryFn: h.queryFn, log: silent,
        now: () => new Date('2026-10-12T12:00:00Z'), sender: {
          async send(message) {
            messages.push(message);
            return message.tokens.map((token) => ({ token, errorCode: dead ? 'messaging/registration-token-not-registered' : null }));
          },
        },
      });
      assert.equal((await h.request(null, 'POST', '/device-token', { token: 'shared', platform: 'web' })).status, 401);
      assert.equal((await h.request(1, 'POST', '/device-token', { token: 'shared', platform: 'web' }, 'invalid-jwt')).status, 401);
      assert.equal((await h.request(1, 'POST', '/device-token', { token: 'shared', platform: 'android', user_id: 2 })).status, 403);
      assert.equal((await h.request(1, 'POST', '/device-token', { token: 'shared', platform: 'android' })).status, 200);
      assert.equal((await notifier.notifyUser(2, 'game_invite')).skipped, 'no_tokens');
      assert.equal((await h.request(2, 'POST', '/device-token', { token: 'shared', platform: 'web' })).status, 200);
      assert.equal((await h.request(1, 'DELETE', '/device-token', { token: 'shared' })).status, 200);
      assert.equal((await notifier.notifyPartner(1, 'partner_moment', { post_id: 42, session_id: 'session-42', caption: 'private' })).sent, 1);
      assert.deepEqual(messages.at(-1).data, { screen: 'moment_detail', type: 'partner_moment', post_id: '42', session_id: 'session-42' });
      assert.equal((await h.request(2, 'DELETE', '/device-token', { token: 'shared' })).status, 200);
      assert.equal((await notifier.notifyPartner(1, 'partner_moment')).skipped, 'no_tokens');
      await h.request(2, 'POST', '/device-token', { token: 'shared', platform: 'web' });
      dead = true;
      assert.equal((await notifier.notifyPartner(1, 'partner_moment')).revoked, 1);
      assert.equal((await notifier.notifyPartner(1, 'partner_moment')).skipped, 'no_tokens');
      dead = false;
      await h.request(2, 'POST', '/device-token', { token: 'shared', platform: 'web' });
      assert.equal((await h.request(2, 'PUT', '/notification-prefs', {
        partner_moment: false, quiet_hours_enabled: false, quiet_start: '23:30', quiet_end: '07:15', reveal_hour: 20,
      })).status, 200);
      await h.request(2, 'PUT', '/notification-prefs', { game_invite: false });
      assert.deepEqual((await (await h.request(2, 'GET', '/notification-prefs')).json()).prefs, {
        partner_moment: false, today_loop: true, game_invite: false,
        quiet_hours_enabled: false, quiet_start: '23:30', quiet_end: '07:15', reveal_hour: 20,
      });
      assert.equal((await notifier.notifyPartner(1, 'partner_moment')).skipped, 'pref_off');
      assert.equal((await (await h.request(1, 'GET', '/notification-prefs')).json()).prefs.reveal_hour, 21);
    } finally { await h.cleanup(); }
  });

test('real Redis recipient locks retry partial FCM failures without resending successes and exclude inactive couples',
  { skip: !adminUrl || !redisUrl }, async () => {
    const h = await harness();
    try {
      for (const [userId, token] of [[1, 'alice'], [2, 'bob-phone'], [2, 'bob-web']]) {
        await h.request(userId, 'POST', '/device-token', { token, platform: 'web' });
      }
      for (const userId of [1, 2]) {
        await h.queryFn(`INSERT INTO today_moments (couple_id, user_id, business_date, setlog_post_id, revealed_at)
          VALUES (7, ?, '2026-10-12', NULL, NOW())`, [userId]);
      }
      let time = new Date('2026-10-12T11:59:00Z');
      let failWeb = true;
      const messages = [];
      const notifier = createNotifier({ queryFn: h.queryFn, now: () => time, log: silent, sender: {
        async send(message) {
          messages.push(message);
          return message.tokens.map((token) => ({ token, errorCode: token === 'bob-web' && failWeb ? 'messaging/server-unavailable' : null }));
        },
      } });
      const tick = () => notifyRevealedTodayLoops({ queryFn: h.queryFn, redis: h.redis, notifier, date: '2026-10-12', now: () => time });
      assert.equal(await tick(), 0);
      time = new Date('2026-10-12T12:00:00Z');
      await Promise.all([tick(), tick()]);
      const attempted = messages.flatMap((message) => message.tokens);
      assert.equal(attempted.filter((token) => token === 'alice').length, 1);
      assert.equal(attempted.filter((token) => token === 'bob-phone').length, 1);
      assert.ok(attempted.includes('bob-web'));
      failWeb = false;
      assert.equal(await tick(), 1);
      assert.deepEqual(messages.at(-1).tokens, ['bob-web']);
      assert.equal(await tick(), 0);
      await h.queryFn(`UPDATE Couples SET Status = 'inactive' WHERE CoupleId = 7`);
      await h.queryFn(`UPDATE today_moments SET business_date = '2026-10-13' WHERE couple_id = 7`);
      assert.equal(await notifyRevealedTodayLoops({ queryFn: h.queryFn, redis: h.redis, notifier,
        date: '2026-10-13', now: () => new Date('2026-10-13T12:00:00Z') }), 0);
    } finally { await h.cleanup(); }
  });
