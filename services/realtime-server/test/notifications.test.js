import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createFcmSender,
  createNotifier as productionNotifier,
} from '../src/modules/notifications/notifier.js';

const silent = { log() {}, error() {} };
const createNotifier = (options) => productionNotifier({ now: () => new Date('2026-10-12T12:00:00Z'), ...options });

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

test('partner moment goes to every partner token with safe deep-link IDs and a generic body', async () => {
  const { queryFn } = fakeDb();
  const sender = fakeSender();
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment', {
    post_id: 42, session_id: 'session-7', caption: 'private caption', place_name: 'private place',
    screen: 'evil', type: 'evil',
  });
  assert.equal(result.sent, 2);
  assert.deepEqual(sender.sent[0].tokens, ['tok-a', 'tok-b']);
  assert.deepEqual(sender.sent[0].data, { screen: 'moment_detail', type: 'partner_moment', post_id: '42', session_id: 'session-7' });
  assert.doesNotMatch(sender.sent[0].notification.body, /caption|장소|place/i);
});

test('game notification includes invite context and rejects non-numeric user IDs', async () => {
  const sender = fakeSender();
  const { queryFn, calls } = fakeDb();
  const notifier = createNotifier({ queryFn, sender, log: silent });
  assert.equal((await notifier.notifyUser(2, 'game_invite', { game_type: 'yut', room_code: 'room_1_2', caption: 'private' })).sent, 2);
  assert.deepEqual(sender.sent[0].data, { screen: 'game_invite', type: 'game_invite', game_type: 'yut', room_code: 'room_1_2' });
  calls.length = 0;
  assert.equal((await notifier.notifyPartner('ABC123', 'game_invite')).skipped, 'invalid_user');
  assert.equal((await notifier.notifyUser(0, 'game_invite')).skipped, 'invalid_user');
  assert.equal(calls.length, 0);
});

test('recipient pref OFF skips sending', async () => {
  const { queryFn } = fakeDb({ prefs: { game_invite: 0 } });
  const sender = fakeSender();
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'game_invite');
  assert.equal(result.skipped, 'pref_off');
  assert.equal(sender.sent.length, 0);
});

test('quiet hours use KST, inclusive start and exclusive end, and can be disabled', async () => {
  for (const [iso, prefs, skipped] of [
    ['2026-10-12T12:59:00Z', null, false], // 21:59 KST
    ['2026-10-12T13:00:00Z', null, true], // 22:00 KST
    ['2026-10-12T23:00:00Z', null, false], // 08:00 KST next day
    ['2026-10-12T22:59:00Z', null, true], // 07:59 KST next day
    ['2026-10-12T13:00:00Z', { quiet_hours_enabled: 0 }, false],
    ['2026-10-12T02:00:00Z', { quiet_start: '10:00', quiet_end: '12:00' }, true],
    ['2026-10-12T03:00:00Z', { quiet_start: '10:00', quiet_end: '12:00' }, false],
    ['2026-10-12T13:00:00Z', { quiet_start: '22:00', quiet_end: '22:00' }, false],
  ]) {
    const sender = fakeSender();
    const result = await createNotifier({ queryFn: fakeDb({ prefs }).queryFn, sender, log: silent, now: () => new Date(iso) })
      .notifyPartner(1, 'partner_moment');
    assert.equal(result.skipped === 'quiet_hours', skipped, iso);
    assert.equal(sender.sent.length, skipped ? 0 : 1, iso);
  }
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

test('per-token invalid registration responses revoke dead tokens, temporary failures keep tokens active', async () => {
  const { queryFn, calls } = fakeDb();
  const sender = fakeSender({
    'tok-a': 'messaging/registration-token-not-registered',
    'tok-b': 'messaging/invalid-argument',
  });
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyPartner(1, 'partner_moment');
  assert.equal(result.revoked, 2);
  const revokes = calls.filter((c) => c.sql.startsWith('UPDATE device_tokens SET revoked_at'));
  assert.deepEqual(revokes.map((c) => c.params[0]), ['tok-a', 'tok-b']);
  const temporary = fakeSender({ 'tok-a': 'messaging/server-unavailable' });
  calls.length = 0;
  const retry = await createNotifier({ queryFn, sender: temporary, log: silent }).notifyUser(2, 'today_loop');
  assert.equal(retry.failed, 1);
  assert.deepEqual(retry.deliveredTokens, ['tok-b']);
  assert.equal(calls.filter((c) => c.sql.startsWith('UPDATE')).length, 0);
});

test('request-wide invalid-argument is not evidence of an invalid token', async () => {
  const { queryFn, calls } = fakeDb();
  const notifier = createNotifier({ queryFn, sender: { send: async () => {
    throw Object.assign(new Error('bad payload'), { code: 'messaging/invalid-argument' });
  } }, log: silent });
  assert.equal((await notifier.notifyUser(2, 'today_loop')).skipped, 'error');
  assert.equal(calls.filter((c) => c.sql.startsWith('UPDATE')).length, 0);
});

test('a revocation DB failure preserves successful deliveries for scheduler retries', async () => {
  const db = fakeDb();
  const result = await createNotifier({ queryFn: async (sql, params) => {
    if (sql.startsWith('UPDATE')) throw new Error('temporary DB outage');
    return db.queryFn(sql, params);
  }, sender: fakeSender({ 'tok-a': 'messaging/invalid-registration-token' }), log: silent }).notifyUser(2, 'today_loop');
  assert.equal(result.sent, 1);
  assert.deepEqual(result.deliveredTokens, ['tok-b']);
  assert.equal(result.failed, 1);
});

test('unknown types do not reach sender or DB', async () => {
  const notifier = createNotifier({ queryFn: async () => assert.fail('unknown type reached DB'), sender: fakeSender(), log: silent });
  for (const type of ['unknown', 'toString', '__proto__']) {
    assert.equal((await notifier.notifyUser(2, type)).skipped, 'unknown_type');
  }
});

test('without a sender the notifier no-ops and logs; sender errors never throw', async () => {
  const logs = [];
  const { queryFn } = fakeDb();
  const noop = createNotifier({ queryFn, sender: null, log: { log: (m) => logs.push(m), error() {} } });
  assert.equal((await noop.notifyPartner(1, 'partner_moment')).skipped, 'no_sender');
  assert.equal(logs.length, 1);

  const errors = [];
  const boom = createNotifier({
    queryFn,
    sender: { send: async () => { throw new Error('credential-fixture-private-data'); } },
    log: { ...silent, error: (...args) => errors.push(args) },
  });
  assert.equal((await boom.notifyPartner(1, 'partner_moment')).skipped, 'error');
  assert.doesNotMatch(JSON.stringify(errors), /credential-fixture-private-data/);
});

test('createFcmSender returns null without credentials', () => {
  assert.equal(createFcmSender({ env: {}, log: silent }), null);
});

test('FCM sender uses installed modular Admin APIs and maps token-specific responses', async () => {
  const messages = [];
  const sender = createFcmSender({ env: { GOOGLE_APPLICATION_CREDENTIALS: '/test-fixture/account.json' }, log: silent,
    importAdmin: async () => ({
      applicationDefault: () => 'test-credential',
      getApps: () => [],
      initializeApp: (options) => { assert.equal(options.credential, 'test-credential'); return 'test-app'; },
      getMessaging: (app) => {
        assert.equal(app, 'test-app');
        return { async sendEachForMulticast(message) {
          messages.push(message);
          return { responses: [{ success: true }, { success: false, error: { code: 'messaging/registration-token-not-registered' } }] };
        } };
      },
    }),
  });
  const results = await sender.send({ tokens: ['valid', 'dead'], notification: { body: 'generic' }, data: { screen: 'today_loop' } });
  assert.deepEqual(results, [{ token: 'valid', errorCode: null }, { token: 'dead', errorCode: 'messaging/registration-token-not-registered' }]);
  assert.equal(messages.length, 1);
});

test('FCM SDK initialization can recover after a temporary failure', async () => {
  let attempts = 0;
  const sender = createFcmSender({ env: { GOOGLE_APPLICATION_CREDENTIALS: '/test-fixture/account.json' }, log: silent,
    importAdmin: async () => {
      if (++attempts === 1) throw new Error('temporary initialization failure');
      return { applicationDefault: () => 'fixture', getApps: () => [], initializeApp: () => 'app',
        getMessaging: () => ({ sendEachForMulticast: async () => ({ responses: [{ success: true }] }) }) };
    },
  });
  const message = { tokens: ['valid'], data: { screen: 'today_loop' } };
  await assert.rejects(sender.send(message), /temporary initialization/);
  assert.deepEqual(await sender.send(message), [{ token: 'valid', errorCode: null }]);
});

test('FCM sender splits the 500-token limit and preserves successes when a later batch fails', async () => {
  let batches = 0;
  const sender = createFcmSender({ env: { FIREBASE_SERVICE_ACCOUNT_JSON: '{"project_id":"fixture"}' }, log: silent,
    importAdmin: async () => ({ cert: (json) => { assert.equal(json.project_id, 'fixture'); return 'fixture'; },
      getApps: () => [], initializeApp: () => 'app', getMessaging: () => ({
        sendEachForMulticast: async ({ tokens }) => {
          assert.ok(tokens.length <= 500);
          if (++batches === 2) throw Object.assign(new Error('temporary FCM batch failure'), { code: 'messaging/server-unavailable' });
          return { responses: tokens.map(() => ({ success: true })) };
        },
      }),
    }),
  });
  const results = await sender.send({ tokens: Array.from({ length: 501 }, (_, i) => `token-${i}`), data: { screen: 'today_loop' } });
  assert.equal(results.filter((result) => !result.errorCode).length, 500);
  assert.deepEqual(results[500], { token: 'token-500', errorCode: 'messaging/server-unavailable' });
});

test('an SDK-wide invalid payload response keeps valid device registrations available for retry', async () => {
  const sender = createFcmSender({ env: { GOOGLE_APPLICATION_CREDENTIALS: '/test-fixture/account.json' }, log: silent,
    importAdmin: async () => ({ applicationDefault: () => 'fixture', getApps: () => [], initializeApp: () => 'app',
      getMessaging: () => ({ sendEachForMulticast: async () => {
        throw Object.assign(new Error('invalid payload'), { code: 'messaging/invalid-argument' });
      } }),
    }),
  });
  const { queryFn, calls } = fakeDb({ tokens: ['valid'] });
  const result = await createNotifier({ queryFn, sender, log: silent }).notifyUser(2, 'today_loop');
  assert.equal(result.sent, 0);
  assert.equal(result.failed, 1);
  assert.equal(result.revoked, 0);
  assert.equal(calls.filter((call) => call.sql.startsWith('UPDATE')).length, 0);
});
