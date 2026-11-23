import assert from 'node:assert/strict';
import test from 'node:test';
import { NotesService } from '../src/modules/notes/application.js';
import { NotesError, NOTE_PUSH_BODY } from '../src/modules/notes/domain.js';
import { createFakeNotesRepository } from './support/notes-fake-repository.js';

const T0 = new Date('2026-11-23T03:00:00Z');
const hours = (n) => new Date(T0.getTime() + n * 3600_000).toISOString();

function setup(extra = {}) {
  let nowMs = T0.getTime();
  const clock = () => new Date(nowMs);
  const couples = [
    { CoupleId: 1, User1Id: 1, User2Id: 2, Status: 'active' },
    { CoupleId: 2, User1Id: 3, User2Id: 4, Status: 'active' },
  ];
  const repository = createFakeNotesRepository({
    couples, clock,
    pins: [{ id: 10, couple_id: 1 }, { id: 20, couple_id: 2 }],
    posts: [{ id: 100, couple_id: 1 }, { id: 200, couple_id: 2 }],
  });
  const published = [];
  const pushes = [];
  const removed = [];
  const service = NotesService({
    repository,
    now: clock,
    publish: (userId, event, payload) => published.push({ userId, event, payload }),
    notifier: { notifyUser: async (userId, type, data) => { pushes.push({ userId, type, data }); return { sent: 1 }; } },
    media: {
      prepare: async (file) => ({ file, mediaType: 'image', mediaUrl: `/uploads/${file.filename}` }),
      remove: async (file) => removed.push(file.filename),
      removeByUrl: async (url) => removed.push(url),
    },
    ...extra,
  });
  return {
    service, repository, couples, published, pushes, removed,
    advance: (ms) => { nowMs += ms; },
  };
}
const actor = (userId) => ({ userId });
const rejects = (promise, status, reason) => assert.rejects(promise, (e) =>
  e instanceof NotesError && e.status === status && e.reason === reason);

test('send delivers to the partner only, pushes a fixed body, and the partner reads it', async () => {
  const s = setup();
  const { note, created } = await s.service.send(actor(1), { body: '  안녕  ', client_request_id: 'a1' });
  assert.equal(created, true);
  assert.equal(note.body, '안녕');
  assert.equal(note.mine, true);
  assert.deepEqual(s.published.map((p) => [p.userId, p.event]), [[2, 'note:new']]);
  assert.equal(s.published[0].payload.note.mine, false);
  assert.deepEqual(s.pushes, [{ userId: 2, type: 'partner_note', data: {} }]);
  const list = await s.service.list(actor(2), {});
  assert.equal(list.notes[0].body, '안녕');
  assert.equal(list.unread_count, 1);
});

test('send validates body, length and empties', async () => {
  const s = setup();
  await rejects(s.service.send(actor(1), { body: 'x'.repeat(1001) }), 400, 'note_too_long');
  await s.service.send(actor(1), { body: '가'.repeat(1000) });
  await rejects(s.service.send(actor(1), { body: '   ' }), 400, 'empty_note');
  await rejects(s.service.send(actor(1), { body: 5 }), 400, 'invalid_body');
});

test('client_request_id makes send idempotent: no second note, push or event', async () => {
  const s = setup();
  const first = await s.service.send(actor(1), { body: 'once', client_request_id: 'req-1' });
  const second = await s.service.send(actor(1), { body: 'once', client_request_id: 'req-1' });
  assert.equal(second.created, false);
  assert.equal(second.note.id, first.note.id);
  assert.equal(s.repository.notes.length, 1);
  assert.equal(s.pushes.length, 1);
  assert.equal(s.published.length, 1);
});

test('a duplicate key race resolves to the stored note', async () => {
  const s = setup();
  const first = await s.service.send(actor(1), { body: 'a', client_request_id: 'r' });
  const original = s.repository.findByClientRequest;
  let calls = 0;
  s.repository.findByClientRequest = async (args) => (calls++ === 0 ? null : original(args));
  const again = await s.service.send(actor(1), { body: 'a', client_request_id: 'r' });
  assert.equal(again.note.id, first.note.id);
  assert.equal(again.created, false);
});

test('references must belong to the same Couple', async () => {
  const s = setup();
  const ok = await s.service.send(actor(1), { body: 'see', map_pin_id: '10', setlog_post_id: 100 });
  assert.equal(ok.note.map_pin_id, 10);
  assert.equal(ok.note.setlog_post_id, 100);
  await rejects(s.service.send(actor(1), { body: 'x', map_pin_id: 20 }), 404, 'reference_not_found');
  await rejects(s.service.send(actor(1), { body: 'x', setlog_post_id: 200 }), 404, 'reference_not_found');
  await rejects(s.service.send(actor(1), { body: 'x', map_pin_id: 999 }), 404, 'reference_not_found');
  await rejects(s.service.send(actor(1), { body: 'x', map_pin_id: 'abc' }), 400, 'invalid_map_pin_id');
  assert.equal(s.repository.notes.length, 1);
});

test('photo attachment accepts images only and cleans the upload on failure', async () => {
  const s = setup();
  const file = { filename: 'media-1.jpg', mimetype: 'image/jpeg', size: 1000 };
  const ok = await s.service.send(actor(1), { body: '' }, file);
  assert.equal(ok.note.media_url, '/uploads/media-1.jpg');
  const video = { filename: 'v.mp4', mimetype: 'video/mp4', size: 10 };
  await rejects(s.service.send(actor(1), { body: 'x' }, video), 400, 'invalid_media');
  const big = { filename: 'big.jpg', mimetype: 'image/jpeg', size: 11 * 1024 * 1024 };
  await rejects(s.service.send(actor(1), { body: 'x' }, big), 400, 'invalid_media');
  await rejects(s.service.send(actor(1), { body: 'x', map_pin_id: 20 }, { filename: 'c.jpg', mimetype: 'image/png', size: 1 }), 404, 'reference_not_found');
  assert.deepEqual(s.removed, ['v.mp4', 'big.jpg', 'c.jpg']);
});

test('scheduled note stays hidden from the recipient in list, get, event and push until it opens', async () => {
  const s = setup();
  const file = { filename: 'secret.jpg', mimetype: 'image/jpeg', size: 10 };
  const sent = await s.service.send(actor(1), {
    body: '비밀 본문', open_at: hours(2), map_pin_id: 10, client_request_id: 'sch',
  }, file);
  assert.equal(sent.note.body, '비밀 본문', 'the author still sees their own note');
  assert.equal(sent.note.mine, true);
  assert.deepEqual(s.published, []);
  assert.deepEqual(s.pushes, []);

  const locked = (await s.service.list(actor(2), {})).notes[0];
  assert.equal(locked.status, 'locked');
  assert.equal(locked.body, null);
  assert.equal(locked.media_url, null);
  assert.equal(locked.map_pin_id, null);
  assert.equal(typeof locked.open_at, 'string');
  assert.doesNotMatch(JSON.stringify(locked), /비밀|secret/);
  assert.equal((await s.service.list(actor(2), {})).unread_count, 0);
  await rejects(s.service.react(actor(2), sent.note.id, { emoji: '❤️' }), 409, 'note_not_open');

  s.advance(3 * 3600_000);
  const delivered = await s.service.deliverDue();
  assert.equal(delivered, 1);
  assert.deepEqual(s.published.map((p) => [p.userId, p.event]), [[2, 'note:new']]);
  assert.equal(s.published[0].payload.note.body, '비밀 본문');
  assert.equal(s.published[0].payload.note.status, 'visible');
  assert.deepEqual(s.pushes, [{ userId: 2, type: 'partner_note', data: {} }]);
  assert.equal(await s.service.deliverDue(), 0, 'delivery is claimed once');
  assert.equal((await s.service.list(actor(2), {})).notes[0].body, '비밀 본문');
});

test('open_at must be a future time within a year', async () => {
  const s = setup();
  await rejects(s.service.send(actor(1), { body: 'x', open_at: 'nope' }), 400, 'invalid_open_at');
  await rejects(s.service.send(actor(1), { body: 'x', open_at: hours(-1) }), 400, 'open_at_not_future');
  await rejects(s.service.send(actor(1), { body: 'x', open_at: hours(24 * 400) }), 400, 'open_at_too_far');
});

test('the service masks locked rows even if the repository returns raw content', async () => {
  const s = setup();
  s.repository.listNotes = async () => [{
    id: 5, sender_id: 1, body: 'leak', media_url: '/uploads/leak.jpg', is_open: 0,
    open_at_ts: 4_000_000_000, created_at_ts: 1, deleted_at: null, map_pin_id: 10,
  }];
  const locked = (await s.service.list(actor(2), {})).notes[0];
  assert.equal(locked.body, null);
  assert.equal(locked.media_url, null);
});

test('Couples are isolated: no cross-Couple list, read, delete or reaction', async () => {
  const s = setup();
  const { note } = await s.service.send(actor(1), { body: 'ours' });
  assert.deepEqual((await s.service.list(actor(3), {})).notes, []);
  await rejects(s.service.remove(actor(3), note.id), 404, 'note_not_found');
  await rejects(s.service.react(actor(3), note.id, { emoji: '❤️' }), 404, 'note_not_found');
  assert.equal((await s.service.markRead(actor(3), { last_read_id: note.id })).unread_count, 0);
  assert.equal(s.repository.notes[0].read_at, null);
});

test('an actor without an active Couple is refused, and access returns after reunion', async () => {
  const s = setup();
  const { note } = await s.service.send(actor(1), { body: 'before' });
  s.couples[0].Status = 'inactive';
  await rejects(s.service.send(actor(1), { body: 'x' }), 409, 'active_couple_required');
  await rejects(s.service.list(actor(2), {}), 409, 'active_couple_required');
  await rejects(s.service.markRead(actor(2), { last_read_id: note.id }), 409, 'active_couple_required');
  await rejects(s.service.remove(actor(1), note.id), 409, 'active_couple_required');
  await rejects(s.service.unread(actor(2)), 409, 'active_couple_required');
  s.advance(1000);
  s.couples[0].Status = 'active';
  assert.equal((await s.service.list(actor(2), {})).notes[0].body, 'before');
});

test('a scheduled note is not delivered while its Couple is inactive', async () => {
  const s = setup();
  await s.service.send(actor(1), { body: 'later', open_at: hours(1) });
  s.couples[0].Status = 'inactive';
  s.advance(2 * 3600_000);
  assert.equal(await s.service.deliverDue(), 0);
  assert.deepEqual(s.published, []);
  s.couples[0].Status = 'active';
  assert.equal(await s.service.deliverDue(), 1);
});

test('reading marks only opened partner notes and tells the author', async () => {
  const s = setup();
  const a = await s.service.send(actor(1), { body: 'one' });
  const b = await s.service.send(actor(1), { body: 'two' });
  const later = await s.service.send(actor(1), { body: 'three', open_at: hours(1) });
  s.published.length = 0;
  const res = await s.service.markRead(actor(2), { last_read_id: later.note.id });
  assert.equal(res.unread_count, 0);
  assert.deepEqual(s.published.map((p) => [p.userId, p.event]), [[1, 'note:read']]);
  assert.equal(s.published[0].payload.up_to_id, later.note.id);
  assert.notEqual(s.repository.notes[0].read_at, null);
  assert.equal(s.repository.notes[2].read_at, null, 'a locked note is not read yet');
  const mine = (await s.service.list(actor(1), {})).notes.find((n) => n.id === a.note.id);
  assert.equal(typeof mine.read_at, 'string');
  s.advance(2 * 3600_000);
  assert.equal((await s.service.unread(actor(2))).unread_count, 1, 'the opened note is unread');
  await rejects(s.service.markRead(actor(2), { last_read_id: 'x' }), 400, 'invalid_last_read_id');
  assert.ok(b);
});

test('only the author deletes; the partner then sees a deleted marker and the media is removed', async () => {
  const s = setup();
  const file = { filename: 'p.jpg', mimetype: 'image/jpeg', size: 5 };
  const { note } = await s.service.send(actor(1), { body: 'oops' }, file);
  s.published.length = 0;
  await rejects(s.service.remove(actor(2), note.id), 403, 'not_author');
  await s.service.remove(actor(1), note.id);
  assert.deepEqual(s.published.map((p) => [p.userId, p.event]), [[2, 'note:deleted']]);
  assert.deepEqual(s.removed, ['/uploads/p.jpg']);
  const seen = (await s.service.list(actor(2), {})).notes[0];
  assert.equal(seen.status, 'deleted');
  assert.equal(seen.body, null);
  assert.equal(seen.media_url, null);
  assert.equal((await s.service.list(actor(2), {})).unread_count, 0);
  await s.service.remove(actor(1), note.id);
  await rejects(s.service.remove(actor(1), 999), 404, 'note_not_found');
});

test('the partner reacts with one allowed emoji; the author cannot, and null clears it', async () => {
  const s = setup();
  const { note } = await s.service.send(actor(1), { body: 'hi' });
  s.published.length = 0;
  await rejects(s.service.react(actor(1), note.id, { emoji: '❤️' }), 403, 'cannot_react_to_own_note');
  await rejects(s.service.react(actor(2), note.id, { emoji: '💀' }), 400, 'invalid_reaction');
  const res = await s.service.react(actor(2), note.id, { emoji: '😊' });
  assert.equal(res.note.reaction, '😊');
  assert.deepEqual(s.published.map((p) => [p.userId, p.event]), [[1, 'note:reaction']]);
  const swapped = await s.service.react(actor(2), note.id, { emoji: '🔥' });
  assert.equal(swapped.note.reaction, '🔥');
  const cleared = await s.service.react(actor(2), note.id, { emoji: null });
  assert.equal(cleared.note.reaction, null);
});

test('list paginates by cursor newest first', async () => {
  const s = setup();
  for (let i = 1; i <= 5; i += 1) await s.service.send(actor(1), { body: `n${i}` });
  const page1 = await s.service.list(actor(2), { limit: '2' });
  assert.deepEqual(page1.notes.map((n) => n.body), ['n5', 'n4']);
  assert.equal(page1.next_before, 4);
  const page2 = await s.service.list(actor(2), { limit: '2', before: String(page1.next_before) });
  assert.deepEqual(page2.notes.map((n) => n.body), ['n3', 'n2']);
  const page3 = await s.service.list(actor(2), { limit: '2', before: '2' });
  assert.deepEqual(page3.notes.map((n) => n.body), ['n1']);
  assert.equal(page3.next_before, null);
  await rejects(s.service.list(actor(2), { limit: '0' }), 400, 'invalid_limit');
  await rejects(s.service.list(actor(2), { before: '-1' }), 400, 'invalid_before');
});

test('push copy is fixed and carries no note content', () => {
  assert.equal(NOTE_PUSH_BODY, '쪽지가 도착했어요');
});
