import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import jwt from 'jsonwebtoken';
import test from 'node:test';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';
import { installSocketAuthentication } from '../src/backend-access.js';
import { NotesService } from '../src/modules/notes/application.js';
import { attachNotesRealtime, createNotesPublisher } from '../src/modules/notes/realtime.js';
import { createFakeNotesRepository } from './support/notes-fake-repository.js';

const secret = 'notes-socket-secret-at-least-32-characters';
const settle = async () => { for (let i = 0; i < 10; i += 1) await new Promise(setImmediate); };

async function fixture(t) {
  let nowMs = new Date('2026-11-23T03:00:00Z').getTime();
  const clock = () => new Date(nowMs);
  const couples = [
    { CoupleId: 1, User1Id: 1, User2Id: 2, Status: 'active' },
    { CoupleId: 2, User1Id: 3, User2Id: 4, Status: 'active' },
  ];
  const repository = createFakeNotesRepository({ couples, clock });
  const httpServer = createServer();
  const io = new Server(httpServer, { transports: ['websocket'] });
  installSocketAuthentication(io, secret, async (userId) => {
    const couple = couples.find((c) => c.Status === 'active' && [c.User1Id, c.User2Id].includes(userId));
    return couple ? { userId: `code-${userId}`, numericUserId: userId, roomCode: `room-${couple.CoupleId}` } : null;
  });
  attachNotesRealtime(io);
  const service = NotesService({
    repository, now: clock, publish: createNotesPublisher(() => io),
    notifier: { notifyUser: async () => ({ sent: 1 }) },
  });
  await new Promise((r) => httpServer.listen(0, '127.0.0.1', r));
  const received = new Map();
  const clients = new Map();
  for (const userId of [1, 2, 3, 4]) {
    const client = createClient(`http://127.0.0.1:${httpServer.address().port}`, {
      transports: ['websocket'], reconnection: false, auth: { token: jwt.sign({ userId }, secret) },
    });
    received.set(userId, []);
    for (const event of ['note:new', 'note:read', 'note:deleted', 'note:reaction']) {
      client.on(event, (payload) => received.get(userId).push({ event, payload }));
    }
    clients.set(userId, client);
    await new Promise((resolve, reject) => { client.once('connect', resolve); client.once('connect_error', reject); });
  }
  t.after(async () => {
    clients.forEach((c) => c.disconnect());
    await new Promise((r) => io.close(r));
  });
  return { service, received, couples, advance: (ms) => { nowMs += ms; }, clients };
}

test('a new note reaches only the partner, never the sender or another Couple', async (t) => {
  const f = await fixture(t);
  await f.service.send({ userId: 1 }, { body: '둘만의 이야기' });
  await settle();
  assert.deepEqual(f.received.get(2).map((e) => e.event), ['note:new']);
  assert.equal(f.received.get(2)[0].payload.note.body, '둘만의 이야기');
  assert.deepEqual(f.received.get(1), []);
  assert.deepEqual(f.received.get(3), []);
  assert.deepEqual(f.received.get(4), []);
});

test('read, reaction and delete events go to the other side of the same Couple only', async (t) => {
  const f = await fixture(t);
  const { note } = await f.service.send({ userId: 3 }, { body: 'c2' });
  await f.service.markRead({ userId: 4 }, { last_read_id: note.id });
  await f.service.react({ userId: 4 }, note.id, { emoji: '😊' });
  await f.service.remove({ userId: 3 }, note.id);
  await settle();
  assert.deepEqual(f.received.get(4).map((e) => e.event), ['note:new', 'note:deleted']);
  assert.deepEqual(f.received.get(3).map((e) => e.event), ['note:read', 'note:reaction']);
  assert.deepEqual(f.received.get(1), []);
  assert.deepEqual(f.received.get(2), []);
});

test('a scheduled note sends no socket event with content before it opens', async (t) => {
  const f = await fixture(t);
  await f.service.send({ userId: 1 }, { body: '열리기 전 비밀', open_at: '2026-11-23T05:00:00Z' });
  await settle();
  assert.deepEqual(f.received.get(2), []);
  f.advance(3 * 3600_000);
  await f.service.deliverDue();
  await settle();
  assert.equal(f.received.get(2).length, 1);
  assert.equal(f.received.get(2)[0].payload.note.body, '열리기 전 비밀');
  assert.deepEqual(f.received.get(1), []);
  assert.deepEqual(f.received.get(3), []);
});

test('an unauthenticated socket does not join and a user without an active Couple cannot connect', async (t) => {
  const f = await fixture(t);
  f.couples[0].Status = 'inactive';
  const httpServer = f.clients.get(1).io.uri;
  const outsider = createClient(httpServer, {
    transports: ['websocket'], reconnection: false, auth: { token: jwt.sign({ userId: 1 }, secret) },
  });
  const error = await new Promise((resolve) => { outsider.once('connect_error', resolve); outsider.once('connect', () => resolve(null)); });
  assert.equal(error?.message, 'ACTIVE_COUPLE_REQUIRED');
  outsider.disconnect();
});
