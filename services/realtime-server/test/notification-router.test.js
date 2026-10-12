import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';
import express from 'express';
import { createNotificationRouter } from '../src/modules/notifications/http-router.js';

async function withServer(queryFn, run, userId = 5, log = console) {
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.auth = userId === null ? undefined : { userId }; next(); });
  app.use(createNotificationRouter({ queryFn, log }));
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
    assert.deepEqual(got.prefs, {
      partner_moment: true, today_loop: true, game_invite: true,
      quiet_hours_enabled: true, quiet_start: '22:00', quiet_end: '08:00', reveal_hour: 21,
    });
    assert.equal((await call(base, 'PUT', '/notification-prefs', { today_loop: false })).status, 200);
    assert.deepEqual(calls.at(-1).params, [5, 0]);
    assert.equal((await call(base, 'PUT', '/notification-prefs', { today_loop: 'no' })).status, 400);
    assert.equal((await call(base, 'PUT', '/notification-prefs', { evil: true })).status, 400);
  });
});

test('partial preference updates round trip clock settings and preserve other fields', async () => {
  const row = { partner_moment: 0, today_loop: 1, game_invite: 1 };
  await withServer(async (sql, params) => {
    if (sql.startsWith('SELECT')) return { rows: [row] };
    const columns = sql.match(/notification_prefs \(user_id, ([^)]+)\)/)[1].split(', ');
    columns.forEach((column, i) => { row[column] = params[i + 1]; });
    return { rows: [] };
  }, async (base) => {
    assert.equal((await call(base, 'PUT', '/notification-prefs', {
      quiet_hours_enabled: false, quiet_start: '23:30', quiet_end: '07:15', reveal_hour: 20,
    })).status, 200);
    assert.equal((await call(base, 'PUT', '/notification-prefs', { game_invite: false })).status, 200);
    assert.deepEqual((await (await fetch(`${base}/notification-prefs`)).json()).prefs, {
      partner_moment: false, today_loop: true, game_invite: false,
      quiet_hours_enabled: false, quiet_start: '23:30', quiet_end: '07:15', reveal_hour: 20,
    });
    for (const patch of [{ quiet_start: '24:00' }, { quiet_end: '8:00' }, { reveal_hour: 24 },
      { reveal_hour: '21' }, { reveal_hour: 2.5 }, { quiet_hours_enabled: 1 }, { today_loop: true, unknown: true }]) {
      assert.equal((await call(base, 'PUT', '/notification-prefs', patch)).status, 400);
    }
  });
});

test('token and preference routes reject missing or non-numeric authenticated identity before DB access', async () => {
  for (const userId of [null, 'USERCODE', 0]) {
    await withServer(async () => { assert.fail('unauthenticated DB access'); }, async (base) => {
      for (const [method, path, body] of [
        ['POST', '/device-token', { token: 't1', platform: 'web', user_id: 5 }],
        ['DELETE', '/device-token', { token: 't1' }],
        ['GET', '/notification-prefs', undefined],
        ['PUT', '/notification-prefs', { today_loop: false }],
      ]) {
        const response = await call(base, method, path, body);
        assert.equal(response.status, 401);
        assert.equal((await response.json()).reason, 'auth_required');
      }
    }, userId);
  }
});

test('token routes reject structured and oversized tokens', async () => {
  await withServer(async () => { assert.fail('invalid input reached DB'); }, async (base) => {
    for (const token of [{ secret: 'x' }, 'x'.repeat(513), ['t1']]) {
      for (const method of ['POST', 'DELETE']) {
        assert.equal((await call(base, method, '/device-token', { token, platform: 'android' })).status, 400);
      }
    }
  });
});

test('DB failure returns a generic REST error without logging raw token-bearing exceptions', async () => {
  const errors = [];
  await withServer(async () => { throw new Error('token-fixture-private-data'); }, async (base) => {
    const response = await call(base, 'POST', '/device-token', { token: 'fixture', platform: 'web' });
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), { ok: false, reason: 'internal_error' });
    assert.equal(errors.length, 1);
    assert.doesNotMatch(JSON.stringify(errors), /token-fixture-private-data/);
  }, 5, { error: (...args) => errors.push(args) });
});
