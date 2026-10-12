import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createFcmSender,
  createNotifier,
  notifyRevealedTodayLoops,
} from '../src/modules/notifications/notifier.js';

const silent = { log() {}, error() {} };

// Minimal fake DB keyed on SQL shape. No MariaDB needed.
function fakeDb({ partnerId = 2, prefs = null, tokens = ['tok-a', 'tok-b'] } = {}) {
  const calls = [];
  const queryFn = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('FROM Couples')) return { rows: partnerId ? [{ partner_id: partnerId }] : [] };
    if (sql.includes('FROM notification_prefs')) return { rows: prefs ? [prefs] : [] };
    if (sql.includes('FROM device_tokens')) return { rows: tokens.map((token) => ({ token })) };
    return { rows: [] };
  };
  return { queryFn, calls };
}

const fakeSender = (errorByToken = {}) => {
  const sent = [];
  return {
    sent,
    async send(message) {
      sent.push(message);
      return message.tokens.map((token) => ({ token, errorCode: errorByToken[token] ?? null }));
    },
  };
};

test('partner moment goes to every partner token with a generic body and screen payload', async () => {
  const { queryFn } = fakeDb();
  const sender = fakeSender();
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment');
  assert.equal(result.sent, 2);
  assert.deepEqual(sender.sent[0].tokens, ['tok-a', 'tok-b']);
  assert.equal(sender.sent[0].data.screen, 'moment_detail');
  assert.doesNotMatch(sender.sent[0].notification.body, /caption|장소|place/i);
});

test('recipient pref OFF skips sending', async () => {
  const { queryFn } = fakeDb({ prefs: { enabled: 0 } });
  const sender = fakeSender();
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'game_invite');
  assert.equal(result.skipped, 'pref_off');
  assert.equal(sender.sent.length, 0);
});

test('no active partner or no tokens sends nothing', async () => {
  const sender = fakeSender();
  assert.equal(
    (await createNotifier({ queryFn: fakeDb({ partnerId: null }).queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment')).skipped,
    'no_partner',
  );
  assert.equal(
    (await createNotifier({ queryFn: fakeDb({ tokens: [] }).queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment')).skipped,
    'no_tokens',
  );
  assert.equal(sender.sent.length, 0);
});

test('not-registered / invalid-argument tokens are revoked', async () => {
  const { queryFn, calls } = fakeDb();
  const sender = fakeSender({
    'tok-a': 'messaging/registration-token-not-registered',
    'tok-b': 'messaging/invalid-argument',
  });
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment');
  assert.equal(result.revoked, 2);
  const revokes = calls.filter((c) => c.sql.startsWith('UPDATE device_tokens SET revoked_at'));
  assert.deepEqual(revokes.map((c) => c.params[0]), ['tok-a', 'tok-b']);
});

test('without a sender the notifier no-ops and logs; sender errors never throw', async () => {
  const logs = [];
  const { queryFn } = fakeDb();
  const noop = createNotifier({ queryFn, sender: null, log: { log: (m) => logs.push(m), error() {} } });
  assert.equal((await noop.notifyPartner(1, 'partner_moment')).skipped, 'no_sender');
  assert.equal(logs.length, 1);

  const boom = createNotifier({
    queryFn,
    sender: { send: async () => { throw new Error('fcm down'); } },
    log: silent,
  });
  assert.equal((await boom.notifyPartner(1, 'partner_moment')).skipped, 'error');
});

test('createFcmSender returns null without credentials', () => {
  assert.equal(createFcmSender({ env: {}, log: silent }), null);
});

test('today loop reveal notifies both users once per couple/date (Redis NX lock)', async () => {
  const seen = new Set();
  const redis = { set: async (key) => (seen.has(key) ? null : (seen.add(key), 'OK')) };
  const queryFn = async () => ({ rows: [{ couple_id: 7, user_id: 1 }, { couple_id: 7, user_id: 2 }] });
  const notified = [];
  const notifier = { notifyUser: async (id, type) => notified.push([id, type]) };

  assert.equal(await notifyRevealedTodayLoops({ queryFn, redis, notifier, date: '2026-10-12' }), 1);
  assert.equal(await notifyRevealedTodayLoops({ queryFn, redis, notifier, date: '2026-10-12' }), 0);
  assert.deepEqual(notified, [[1, 'today_loop'], [2, 'today_loop']]);
});
