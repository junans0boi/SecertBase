import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import jwt from 'jsonwebtoken';
import test from 'node:test';
import { Server } from 'socket.io';
import { io as createClient } from 'socket.io-client';
import { installSocketAuthentication } from '../src/backend-access.js';
import { TwoAnswersService } from '../src/modules/two-answers/application.js';
import { attachNotesRealtime, createNotesPublisher } from '../src/modules/notes/realtime.js';

const secret = 'two-answers-socket-secret-at-least-32-chars';
const settle = async () => { for (let i = 0; i < 10; i += 1) await new Promise(setImmediate); };
const SECRET_A = '비밀답변-A';
const SECRET_B = '비밀답변-B';

const couples = [
  { CoupleId: 1, User1Id: 1, User2Id: 2, Status: 'active' },
  { CoupleId: 2, User1Id: 3, User2Id: 4, Status: 'active' },
];

function fakeDb() {
  const responses = []; // { couple_id, user_id, body }
  const question = (coupleId) => ({
    id: coupleId * 10, business_date: '2026-11-23', question_id: 'q', category: 'c', question_text: '질문',
  });
  const queryFn = async (sql, params = []) => {
    if (sql.includes('FROM Couples')) {
      const uid = params[0];
      const c = couples.find((x) => x.User1Id === uid || x.User2Id === uid);
      return { rows: c ? [c] : [] };
    }
    if (sql.includes('business_date = ? LIMIT 1')) return { rows: [question(params[0])] };
    if (sql.includes('FROM two_answer_responses WHERE two_answer_id')) {
      return { rows: responses.filter((r) => r.couple_id === params[1]).map((r) => ({ ...r, is_late: 0, updated_at: 1 })) };
    }
    if (sql.includes('SELECT DATE_FORMAT')) return { rows: [] };
    throw new Error(`unexpected sql: ${sql}`);
  };
  const transactionFn = async (fn) => fn({
    execute: async (sql, params) => {
      if (sql.includes('FOR UPDATE')) return [[{ id: params[0] }]];
      if (sql.includes('INSERT INTO two_answer_responses')) {
        const [, couple_id, user_id, body] = params;
        const existing = responses.find((r) => r.couple_id === couple_id && r.user_id === user_id);
        if (existing) existing.body = body; else responses.push({ couple_id, user_id, body });
        return [{}];
      }
      if (sql.includes('COUNT(*)')) {
        return [[{ total: responses.filter((r) => r.couple_id * 10 === params[0]).length }]];
      }
      throw new Error(`unexpected tx sql: ${sql}`);
    },
  });
  return { queryFn, transactionFn };
}

async function fixture(t) {
  const db = fakeDb();
  const httpServer = createServer();
  const io = new Server(httpServer, { transports: ['websocket'] });
  installSocketAuthentication(io, secret, async (userId) => {
    const couple = couples.find((c) => [c.User1Id, c.User2Id].includes(userId));
    return couple ? { userId: `code-${userId}`, numericUserId: userId, roomCode: `room-${couple.CoupleId}` } : null;
  });
  attachNotesRealtime(io);
  const service = TwoAnswersService({
    ...db, now: () => new Date('2026-11-23T03:00:00Z'), publish: createNotesPublisher(() => io),
  });
  await new Promise((r) => httpServer.listen(0, '127.0.0.1', r));
  const received = new Map();
  const clients = [];
  for (const userId of [1, 2, 3, 4]) {
    const client = createClient(`http://127.0.0.1:${httpServer.address().port}`, {
      transports: ['websocket'], reconnection: false, auth: { token: jwt.sign({ userId }, secret) },
    });
    received.set(userId, []);
    client.onAny((event, payload) => received.get(userId).push({ event, payload }));
    clients.push(client);
    await new Promise((resolve, reject) => { client.once('connect', resolve); client.once('connect_error', reject); });
  }
  t.after(async () => {
    clients.forEach((c) => c.disconnect());
    await new Promise((r) => io.close(r));
  });
  return { service, received };
}

test('partner is told about an answer and about the reveal, with no body, and no other Couple hears', async (t) => {
  const f = await fixture(t);
  await f.service.answerToday({ userId: 1 }, SECRET_A);
  await settle();
  assert.deepEqual(f.received.get(2).map((e) => [e.event, e.payload.state]), [['two-answers:updated', 'partner_answered']]);
  assert.deepEqual(f.received.get(1), []);

  await f.service.answerToday({ userId: 2 }, SECRET_B);
  await settle();
  assert.deepEqual(
    f.received.get(1).map((e) => [e.event, e.payload.state]),
    [['two-answers:updated', 'open']],
  );

  const wire = JSON.stringify([...f.received.values()]);
  assert.ok(!wire.includes(SECRET_A) && !wire.includes(SECRET_B), 'no answer body on the wire');
  assert.deepEqual(f.received.get(3), []);
  assert.deepEqual(f.received.get(4), []);
});
