import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createUser = async (server, name) => {
  const email = `${name}@notes.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST',
    body: { email, password: 'password123', full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  const userCode = (await registered.json()).userCode;
  const login = await (await server.request('/auth/login', {
    method: 'POST', body: { email, password: 'password123' },
  })).json();
  return { token: login.token, userCode, userId: login.user.UserId };
};

const pair = async (server, sender, recipient) => {
  const { requestId } = await (await server.request('/pairing/requests', {
    token: sender.token, method: 'POST', body: { recipientCode: recipient.userCode },
  })).json();
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token, method: 'POST',
  });
  assert.equal(accepted.status, 200);
};

const api = (server, user) => (path, method = 'GET', body) =>
  server.request(path, { token: user.token, method, body });

const addPin = async (call, name) => {
  const res = await call('/map', 'POST', { place_name: name, latitude: 37.5, longitude: 127 });
  assert.equal(res.status, 200, await res.text());
  return (await res.json()).id;
};

test('Notes: Couple isolation, scheduled opening, idempotency, references, delete, read, reaction, separation',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const [a, b, c, d] = await Promise.all(['na', 'nb', 'nc', 'nd'].map((n) => createUser(server, n)));
      await pair(server, a, b);
      await pair(server, c, d);
      const A = api(server, a); const B = api(server, b); const C = api(server, c); const D = api(server, d);

      // 전송 + 멱등 + 목록
      const first = await A('/notes', 'POST', { body: '안녕', client_request_id: 'req-1' });
      assert.equal(first.status, 201);
      const note = (await first.json()).note;
      const replay = await A('/notes', 'POST', { body: '안녕', client_request_id: 'req-1' });
      assert.equal(replay.status, 200);
      assert.equal((await replay.json()).note.id, note.id);
      const listB = await (await B('/notes')).json();
      assert.equal(listB.notes.length, 1);
      assert.equal(listB.unread_count, 1);

      // Couple 격리
      assert.deepEqual((await (await C('/notes')).json()).notes, []);
      assert.equal((await D(`/notes/${note.id}`, 'DELETE')).status, 404);
      assert.equal((await D(`/notes/${note.id}/reaction`, 'POST', { emoji: '❤️' })).status, 404);

      // 예약 열람: 열리기 전 REST에 본문이 없다. (open_at는 서버 시각 기준 미래)
      const openAt = new Date(Date.now() + 3600_000).toISOString();
      const sched = await A('/notes', 'POST', { body: '열리기 전 비밀', open_at: openAt });
      assert.equal(sched.status, 201);
      const lockedList = await (await B('/notes')).json();
      const locked = lockedList.notes.find((n) => n.status === 'locked');
      assert.ok(locked);
      assert.equal(locked.body, null);
      assert.equal(locked.media_url, null);
      assert.doesNotMatch(JSON.stringify(lockedList), /열리기 전 비밀/);
      assert.equal(lockedList.unread_count, 1, 'a locked note is not unread');
      assert.equal((await B(`/notes/${locked.id}/reaction`, 'POST', { emoji: '👍' })).status, 409);
      assert.equal((await A('/notes', 'POST', { body: 'x', open_at: '2020-01-01T00:00:00Z' })).status, 400);

      // 참조 소유권
      const ownPin = await addPin(A, '우리 장소');
      const otherPin = await addPin(C, '남의 장소');
      assert.equal((await A('/notes', 'POST', { body: 'p', map_pin_id: ownPin })).status, 201);
      assert.equal((await A('/notes', 'POST', { body: 'p', map_pin_id: otherPin })).status, 404);

      // 읽음·반응·삭제
      assert.equal((await (await B('/notes/read', 'POST', { last_read_id: locked.id })).json()).unread_count, 0);
      const mine = (await (await A('/notes')).json()).notes.find((n) => n.id === note.id);
      assert.ok(mine.read_at);
      assert.equal((await B(`/notes/${note.id}/reaction`, 'POST', { emoji: '😊' })).status, 200);
      assert.equal((await B(`/notes/${note.id}`, 'DELETE')).status, 403);
      assert.equal((await A(`/notes/${note.id}`, 'DELETE')).status, 200);
      const afterDelete = (await (await B('/notes')).json()).notes.find((n) => n.id === note.id);
      assert.equal(afterDelete.status, 'deleted');
      assert.equal(afterDelete.body, null);

      // 연결 해제: 비활성 Couple은 접근 불가, 재결합 시 복원
      assert.equal((await A('/user/partner', 'DELETE')).status, 200);
      assert.equal((await A('/notes')).status, 409);
      assert.equal((await B('/notes', 'POST', { body: 'x' })).status, 409);
      await pair(server, a, b);
      const restored = await (await B('/notes')).json();
      assert.ok(restored.notes.some((n) => n.id === note.id));
    } finally {
      await server.close();
    }
  });
