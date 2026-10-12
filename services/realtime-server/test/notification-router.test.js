import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { createNotificationRouter } from '../src/modules/notifications/http-router.js';

async function withServer(queryFn, run) {
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.auth = { userId: 5 }; next(); });
  app.use(createNotificationRouter({ queryFn }));
  const server = createServer(app).listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

const call = (base, method, path, body) =>
  fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

test('POST /device-token upserts for the authenticated user and rejects bad input', async () => {
  const calls = [];
  await withServer(async (sql, params) => { calls.push({ sql, params }); return { rows: [] }; }, async (base) => {
    assert.equal((await call(base, 'POST', '/device-token', { token: 't1', platform: 'android', user_id: 99 })).status, 200);
    assert.equal(calls[0].params[0], 5);
    assert.match(calls[0].sql, /ON DUPLICATE KEY UPDATE/);
    assert.equal((await call(base, 'POST', '/device-token', { token: '', platform: 'android' })).status, 400);
    assert.equal((await call(base, 'POST', '/device-token', { token: 'x', platform: 'toaster' })).status, 400);
  });
});

test('DELETE /device-token revokes only the caller token', async () => {
  const calls = [];
  await withServer(async (sql, params) => { calls.push({ sql, params }); return { rows: [] }; }, async (base) => {
    assert.equal((await call(base, 'DELETE', '/device-token', { token: 't1' })).status, 200);
    assert.deepEqual(calls[0].params, ['t1', 5]);
  });
});

test('prefs default to all on, and PUT validates booleans', async () => {
  const calls = [];
  await withServer(async (sql, params) => {
    calls.push({ sql, params });
    return { rows: sql.startsWith('SELECT') ? [] : [] };
  }, async (base) => {
    const got = await (await fetch(`${base}/notification-prefs`)).json();
    assert.deepEqual(got.prefs, { partner_moment: true, today_loop: true, game_invite: true });
    assert.equal((await call(base, 'PUT', '/notification-prefs', { today_loop: false })).status, 200);
    assert.deepEqual(calls.at(-1).params, [5, 0]);
    assert.equal((await call(base, 'PUT', '/notification-prefs', { today_loop: 'no' })).status, 400);
    assert.equal((await call(base, 'PUT', '/notification-prefs', { evil: true })).status, 400);
  });
});
