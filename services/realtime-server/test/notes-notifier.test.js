import assert from 'node:assert/strict';
import test from 'node:test';
import { MESSAGES, NOTIFICATION_TYPES, createNotifier } from '../src/modules/notifications/notifier.js';
import { notificationPrefs, validPreferencePatch } from '../src/modules/notifications/preferences.js';
import { REQUIRED_SCHEMA } from '../src/schema-readiness.js';

const silent = { log() {}, error() {} };

test('partner_note is a registered type with a fixed body and no content fields', async () => {
  assert.ok(NOTIFICATION_TYPES.includes('partner_note'));
  assert.equal(MESSAGES.partner_note.body, '쪽지가 도착했어요');
  const sent = [];
  const queryFn = async (sql) => {
    if (sql.includes('FROM notification_prefs')) return { rows: [] };
    if (sql.includes('FROM device_tokens')) return { rows: [{ token: 't1' }] };
    return { rows: [] };
  };
  const notifier = createNotifier({
    queryFn, log: silent, now: () => new Date('2026-11-23T03:00:00Z'),
    sender: { send: async (m) => { sent.push(m); return m.tokens.map((token) => ({ token, errorCode: null })); } },
  });
  const result = await notifier.notifyUser(2, 'partner_note', { body: '비밀 본문', media_url: '/uploads/x.jpg', note_id: 5 });
  assert.equal(result.sent, 1);
  assert.deepEqual(sent[0].notification, { title: 'Secret Base', body: '쪽지가 도착했어요' });
  assert.deepEqual(sent[0].data, { screen: 'notes', type: 'partner_note' });
});

test('partner_note preference defaults on, can be turned off, and is required by the schema check', async () => {
  assert.equal(notificationPrefs({}).partner_note, true);
  assert.equal(validPreferencePatch({ partner_note: false }), true);
  assert.equal(validPreferencePatch({ partner_note: 'no' }), false);
  assert.ok(REQUIRED_SCHEMA.notification_prefs.includes('partner_note'));
  assert.ok(REQUIRED_SCHEMA.couple_notes.includes('open_at'));
  const queryFn = async (sql) => {
    if (sql.includes('FROM notification_prefs')) return { rows: [{ partner_note: 0 }] };
    return { rows: [{ token: 't' }] };
  };
  const notifier = createNotifier({ queryFn, log: silent, sender: { send: async () => [] }, now: () => new Date('2026-11-23T03:00:00Z') });
  assert.equal((await notifier.notifyUser(2, 'partner_note')).skipped, 'pref_off');
});
