import assert from 'node:assert/strict';
import test from 'node:test';
import { createNotifier, notifyRevealedTodayLoops } from '../src/modules/notifications/notifier.js';

const silent = { log() {}, error() {} };
function memoryRedis() {
  const values = new Map();
  return {
    async get(key) { return values.get(key) ?? null; },
    async set(key, value, ...options) {
      if (options.includes('NX') && values.has(key)) return null;
      values.set(key, value);
      return 'OK';
    },
    async del(key) { return Number(values.delete(key)); },
    async smembers(key) { return [...(values.get(key) ?? [])]; },
    async sadd(key, ...members) {
      const set = values.get(key) ?? new Set();
      members.forEach((member) => set.add(member));
      values.set(key, set);
      return members.length;
    },
    async expire() { return 1; },
    async eval(_script, _count, key, owner) {
      return values.get(key) === owner ? Number(values.delete(key)) : 0;
    },
  };
}

function scenario({ rows, prefs = {}, tokens = { 1: ['alice'], 2: ['bob'] }, send } = {}) {
  let time = new Date('2026-10-12T12:00:00Z');
  const messages = [];
  const queryFn = async (sql, params) => {
    if (sql.includes('FROM today_moments')) return { rows: (rows ?? [
      { couple_id: 7, user_id: 1, business_date: '2026-10-12' },
      { couple_id: 7, user_id: 2, business_date: '2026-10-12' },
    ]).map((row) => ({ ...row, reveal_hour: prefs[row.user_id]?.reveal_hour ?? 21 })) };
    if (sql.includes('FROM notification_prefs')) return { rows: prefs[params[0]] ? [prefs[params[0]]] : [] };
    if (sql.includes('FROM device_tokens')) return { rows: (tokens[params[0]] ?? []).map((token) => ({ token })) };
    return { rows: [] };
  };
  const notifier = createNotifier({ queryFn, log: silent, now: () => time, sender: {
    async send(message) {
      messages.push(message);
      return send ? send(message) : message.tokens.map((token) => ({ token, errorCode: null }));
    },
  } });
  const redis = memoryRedis();
  return {
    messages,
    setTime(iso) { time = new Date(iso); },
    tick(date = '2026-10-12') { return notifyRevealedTodayLoops({ queryFn, redis, notifier, date, now: () => time }); },
  };
}

test('scheduler waits for each recipient reveal hour in KST and does not send successful recipients twice', async () => {
  const s = scenario({ prefs: { 1: { reveal_hour: 20 } } });
  s.setTime('2026-10-12T10:59:00Z');
  assert.equal(await s.tick(), 0);
  s.setTime('2026-10-12T11:00:00Z');
  assert.equal(await s.tick(), 1);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice']]);
  s.setTime('2026-10-12T12:00:00Z');
  assert.equal(await s.tick(), 1);
  assert.equal(await s.tick(), 0);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice'], ['bob']]);
  assert.equal(s.messages[0].data.business_date, '2026-10-12');
});

test('temporary recipient failure retries while the already successful partner is not duplicated', async () => {
  let failBob = true;
  const s = scenario({ send: ({ tokens }) => tokens.map((token) => ({ token,
    errorCode: token === 'bob' && failBob ? 'messaging/server-unavailable' : null,
  })) });
  assert.equal(await s.tick(), 1);
  failBob = false;
  assert.equal(await s.tick(), 1);
  assert.equal(await s.tick(), 0);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice'], ['bob'], ['bob']]);
});

test('partial multi-device failures retry only the failed device', async () => {
  let failSecond = true;
  const s = scenario({ tokens: { 1: ['alice-phone', 'alice-web'], 2: ['bob'] },
    send: ({ tokens }) => tokens.map((token) => ({ token,
      errorCode: token === 'alice-web' && failSecond ? 'messaging/server-unavailable' : null,
    })),
  });
  assert.equal(await s.tick(), 1);
  failSecond = false;
  assert.equal(await s.tick(), 1);
  assert.equal(await s.tick(), 0);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice-phone', 'alice-web'], ['bob'], ['alice-web']]);
});

test('quiet-hour skips release locks and late reveals can deliver next morning', async () => {
  const s = scenario({ prefs: { 1: { reveal_hour: 23 }, 2: { reveal_hour: 23 } } });
  s.setTime('2026-10-12T14:00:00Z');
  assert.equal(await s.tick(), 0);
  s.setTime('2026-10-12T22:59:00Z');
  assert.equal(await s.tick('2026-10-13'), 0);
  s.setTime('2026-10-12T23:00:00Z');
  assert.equal(await s.tick('2026-10-13'), 1);
  assert.equal(await s.tick('2026-10-13'), 0);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice'], ['bob']]);
});

test('preference and no-token skips can recover on a later tick without duplicating the partner', async () => {
  const prefs = { 1: { today_loop: false } };
  const tokens = { 1: ['alice'], 2: [] };
  const s = scenario({ prefs, tokens });
  assert.equal(await s.tick(), 0);
  prefs[1].today_loop = true;
  assert.equal(await s.tick(), 1);
  tokens[2] = ['bob'];
  assert.equal(await s.tick(), 1);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice'], ['bob']]);
});

test('sender exceptions release recipient locks and concurrent ticks do not duplicate', async () => {
  let fail = true;
  const s = scenario({ send: async ({ tokens }) => {
    if (fail) throw new Error('temporary outage');
    await new Promise((resolve) => setImmediate(resolve));
    return tokens.map((token) => ({ token, errorCode: null }));
  } });
  assert.equal(await s.tick(), 0);
  fail = false;
  await Promise.all([s.tick(), s.tick()]);
  assert.deepEqual(s.messages.map((m) => m.tokens), [['alice'], ['bob'], ['alice'], ['bob']]);
  assert.equal(await s.tick(), 0);
});
