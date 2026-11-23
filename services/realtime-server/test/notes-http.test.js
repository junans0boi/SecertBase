import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import express from 'express';
import test from 'node:test';
import { NotesService } from '../src/modules/notes/application.js';
import { createNotesRouter } from '../src/modules/notes/http-router.js';
import { createRateLimiter } from '../src/shared/rate-limit.js';
import { createFakeNotesRepository } from './support/notes-fake-repository.js';

async function withServer(run, { limit = 1000, userId = 1 } = {}) {
  const now = new Date('2026-11-23T03:00:00Z');
  const repository = createFakeNotesRepository({
    clock: () => now,
    couples: [{ CoupleId: 1, User1Id: 1, User2Id: 2, Status: 'active' }],
  });
  const service = NotesService({ repository, now: () => now, notifier: null });
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.auth = { userId: Number(req.get('x-user') ?? userId) }; next(); });
  app.use('/api', createNotesRouter({
    service,
    uploadStore: { middleware: { single: () => (_req, _res, next) => next() }, remove: async () => {} },
    sendLimiter: createRateLimiter({
      windowMs: 60_000, max: limit, keyFn: (req) => `notes:${req.auth.userId}`,
    }),
  }));
  const server = createServer(app).listen(0);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}/api`;
  const call = (method, path, body, user = 1) => fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json', 'x-user': String(user) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  try { await run(call); } finally { await new Promise((r) => server.close(r)); }
}

test('REST flow: send, list, read, react, delete with proper statuses', async () => {
  await withServer(async (call) => {
    const sent = await call('POST', '/notes', { body: 'hi', client_request_id: 'c1' });
    assert.equal(sent.status, 201);
    const id = (await sent.json()).note.id;
    assert.equal((await call('POST', '/notes', { body: 'hi', client_request_id: 'c1' })).status, 200);
    const list = await (await call('GET', '/notes?limit=10', null, 2)).json();
    assert.equal(list.ok, true);
    assert.equal(list.notes.length, 1);
    assert.equal(list.unread_count, 1);
    assert.equal((await (await call('GET', '/notes/unread', null, 2)).json()).unread_count, 1);
    assert.equal((await (await call('POST', '/notes/read', { last_read_id: id }, 2)).json()).unread_count, 0);
    assert.equal((await call('POST', `/notes/${id}/reaction`, { emoji: '❤️' }, 2)).status, 200);
    assert.equal((await call('POST', `/notes/${id}/reaction`, { emoji: '💀' }, 2)).status, 400);
    assert.equal((await call('DELETE', `/notes/${id}`, null, 2)).status, 403);
    assert.equal((await call('DELETE', `/notes/${id}`)).status, 200);
    assert.equal((await call('GET', '/notes', null, 7)).status, 409);
    assert.equal((await call('POST', '/notes', { body: 'x', user_id: 99 })).status, 403);
  });
});

test('send is rate limited per minute and returns 429 with Retry-After', async () => {
  await withServer(async (call) => {
    for (let i = 0; i < 3; i += 1) assert.equal((await call('POST', '/notes', { body: `n${i}` })).status, 201);
    const limited = await call('POST', '/notes', { body: 'too many' });
    assert.equal(limited.status, 429);
    assert.ok(limited.headers.get('retry-after'));
    assert.equal((await call('POST', '/notes', { body: 'other user' }, 2)).status, 201);
    assert.equal((await call('GET', '/notes')).status, 200, 'reads are not limited');
  }, { limit: 3 });
});
