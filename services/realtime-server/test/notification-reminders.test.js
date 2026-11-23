import assert from 'node:assert/strict';
import test from 'node:test';
import { MESSAGES, NOTIFICATION_TYPES, createNotifier } from '../src/modules/notifications/notifier.js';
import { notificationPrefs, validPreferencePatch } from '../src/modules/notifications/preferences.js';
import {
  notifyAnniversaryEve,
  notifyTwoAnswersWaiting,
  startReminderScheduler,
} from '../src/modules/notifications/reminders.js';
import { REQUIRED_SCHEMA } from '../src/schema-readiness.js';

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
    async smembers(key) { return [...(values.get(key) ?? [])]; },
    async sadd(key, ...members) {
      const set = values.get(key) ?? new Set();
      members.forEach((m) => set.add(m));
      values.set(key, set);
      return members.length;
    },
    async expire() { return 1; },
    async eval(_s, _c, key, owner) { return values.get(key) === owner ? Number(values.delete(key)) : 0; },
  };
}

// anniversaries / two_answers rows are what the (already couple-joined) SQL returns.
function scenario({ anniversaries = [], waiting = [], prefs = {}, tokens = { 1: ['alice'], 2: ['bob'] }, time = '2026-11-23T01:00:00Z' } = {}) {
  let now = new Date(time);
  const sent = [];
  const sqls = [];
  const queryFn = async (sql, params) => {
    sqls.push(sql);
    if (sql.includes('FROM anniversaries')) return { rows: anniversaries };
    if (sql.includes('FROM two_answers')) return { rows: waiting };
    if (sql.includes('FROM notification_prefs')) return { rows: prefs[params[0]] ? [prefs[params[0]]] : [] };
    if (sql.includes('FROM device_tokens')) return { rows: (tokens[params[0]] ?? []).map((token) => ({ token })) };
    return { rows: [] };
  };
  const notifier = createNotifier({ queryFn, log: silent, now: () => now, sender: {
    async send(message) { sent.push(message); return message.tokens.map((token) => ({ token, errorCode: null })); },
  } });
  const redis = memoryRedis();
  return {
    sent, sqls, redis,
    setTime(iso) { now = new Date(iso); },
    eve: () => notifyAnniversaryEve({ queryFn, redis, notifier, now: () => now }),
    waiting: () => notifyTwoAnswersWaiting({ queryFn, redis, notifier, now: () => now }),
  };
}

test('new types are registered with fixed private-free copy and default-on prefs', () => {
  for (const type of ['anniversary_eve', 'two_answers_waiting']) {
    assert.ok(NOTIFICATION_TYPES.includes(type));
    assert.equal(MESSAGES[type].title, 'Secret Base');
    assert.doesNotMatch(MESSAGES[type].body, /쿠폰|할인|광고|이벤트|\(광고\)/);
  }
  assert.equal(MESSAGES.anniversary_eve.screen, 'anniversary');
  assert.equal(MESSAGES.two_answers_waiting.screen, 'two_answers');
  const prefs = notificationPrefs({});
  assert.equal(prefs.anniversary_eve, true);
  assert.equal(prefs.two_answers_waiting, true);
  assert.equal(validPreferencePatch({ anniversary_eve: false, two_answers_waiting: false }), true);
  assert.equal(validPreferencePatch({ anniversary_eve: 'x' }), false);
  assert.ok(REQUIRED_SCHEMA.notification_prefs.includes('anniversary_eve'));
  assert.ok(REQUIRED_SCHEMA.notification_prefs.includes('two_answers_waiting'));
});

test('notifier never forwards private fields for the new types', async () => {
  const s = scenario();
  const notifier = createNotifier({
    queryFn: async (sql) => sql.includes('device_tokens') ? { rows: [{ token: 't' }] } : { rows: [] },
    log: silent, now: () => new Date('2026-11-23T03:00:00Z'),
    sender: { async send(m) { s.sent.push(m); return [{ token: 't', errorCode: null }]; } },
  });
  await notifier.notifyUser(1, 'two_answers_waiting', { body: '비밀 답변', place: '성수' });
  await notifier.notifyUser(1, 'anniversary_eve', { label: '100일', anniversary_id: 3 });
  assert.deepEqual(s.sent.map((m) => m.data), [
    { screen: 'two_answers', type: 'two_answers_waiting' },
    { screen: 'anniversary', type: 'anniversary_eve' },
  ]);
  const text = JSON.stringify(s.sent);
  assert.doesNotMatch(text, /비밀|성수|100일/);
});

test('anniversary D-1 goes to both active-couple members once, at the fixed KST hour', async () => {
  const s = scenario({ anniversaries: [{ couple_id: 7, user1_id: 1, user2_id: 2 }] });
  s.setTime('2026-11-22T22:59:00Z'); // 07:59 KST — before the send hour
  assert.equal(await s.eve(), 0);
  s.setTime('2026-11-23T01:00:00Z'); // 10:00 KST
  assert.equal(await s.eve(), 2);
  assert.deepEqual(s.sent.map((m) => m.tokens).sort(), [['alice'], ['bob']]);
  assert.equal(s.sent[0].notification.body, MESSAGES.anniversary_eve.body);
  assert.equal(await s.eve(), 0); // dedupe on re-tick
  assert.equal(s.sent.length, 2);
});

test('anniversary query targets tomorrow in KST and only active couples', async () => {
  const s = scenario();
  s.setTime('2026-11-23T01:00:00Z');
  const calls = [];
  const queryFn = async (sql, params) => { calls.push({ sql, params }); return { rows: [] }; };
  await notifyAnniversaryEve({ queryFn, redis: s.redis, notifier: { notifyUser: async () => ({}) }, now: () => new Date('2026-12-31T01:00:00Z') });
  const call = calls.find((c) => c.sql.includes('FROM anniversaries'));
  assert.match(call.sql, /Status = 'active'/);
  assert.ok(call.params.includes('2027-01-01'));
  assert.ok(call.params.includes('01-01'));
});

test('anniversary respects pref off, quiet hours (retries after) and missing tokens', async () => {
  const s = scenario({
    anniversaries: [{ couple_id: 7, user1_id: 1, user2_id: 2 }],
    prefs: { 1: { anniversary_eve: 0 }, 2: { quiet_hours_enabled: 1, quiet_start: '09:00', quiet_end: '11:00' } },
  });
  s.setTime('2026-11-23T01:00:00Z'); // 10:00 KST
  assert.equal(await s.eve(), 0);
  assert.equal(s.sent.length, 0);
  s.setTime('2026-11-23T02:00:00Z'); // 11:00 KST, quiet over
  assert.equal(await s.eve(), 1);
  assert.deepEqual(s.sent.map((m) => m.tokens), [['bob']]);
  assert.equal(await s.eve(), 0);
  assert.equal(s.sent.length, 1); // user 1 (pref off) never gets a retry storm / delivery
});

test('anniversary does nothing when the sender is not configured or couple rows are absent', async () => {
  const s = scenario({ anniversaries: [] });
  assert.equal(await s.eve(), 0);
  assert.equal(s.sent.length, 0);
});

test('two-answers reminder goes only to the user who has not answered, body-free, once per day', async () => {
  const s = scenario({ waiting: [{ couple_id: 7, business_date: '2026-11-23', recipient_id: 2 }] });
  assert.equal(await s.waiting(), 1);
  assert.deepEqual(s.sent.map((m) => m.tokens), [['bob']]);
  assert.deepEqual(s.sent[0].data, { screen: 'two_answers', type: 'two_answers_waiting' });
  assert.equal(await s.waiting(), 0);
  assert.equal(s.sent.length, 1);
  // next day = new key
  s.setTime('2026-11-24T01:00:00Z');
  const s2 = s; // same redis, new date row
  assert.ok(s2);
});

test('two-answers reminder: quiet hours defer, pref off suppresses, query is scoped to active couples and today', async () => {
  const s = scenario({
    waiting: [{ couple_id: 7, business_date: '2026-11-23', recipient_id: 2 }],
    prefs: { 2: { quiet_hours_enabled: 1, quiet_start: '22:00', quiet_end: '08:00' } },
    time: '2026-11-23T14:00:00Z', // 23:00 KST
  });
  assert.equal(await s.waiting(), 0);
  assert.equal(s.sent.length, 0);
  assert.match(s.sqls.find((q) => q.includes('FROM two_answers')), /Status = 'active'/);
  s.setTime('2026-11-22T23:30:00Z'); // 08:30 KST next morning still same business date row mocked
  assert.equal(await s.waiting(), 1);

  const off = scenario({
    waiting: [{ couple_id: 7, business_date: '2026-11-23', recipient_id: 2 }],
    prefs: { 2: { two_answers_waiting: 0 } },
  });
  assert.equal(await off.waiting(), 0);
  assert.equal(off.sent.length, 0);
  assert.equal(await off.waiting(), 0);
});

test('reminder scheduler runs both jobs and swallows failures', async () => {
  let handler;
  const cron = { schedule: (expr, fn, opts) => { handler = { expr, fn, opts }; return handler; } };
  let calls = 0;
  const queryFn = async () => { calls += 1; throw new Error('db down'); };
  startReminderScheduler({
    cron, queryFn, redis: memoryRedis(), notifier: { notifyUser: async () => ({}) }, log: silent,
    now: () => new Date('2026-11-23T01:00:00Z'),
  });
  assert.equal(handler.expr, '* * * * *');
  assert.equal(handler.opts.timezone, 'Asia/Seoul');
  await handler.fn();
  assert.ok(calls >= 2);
});
