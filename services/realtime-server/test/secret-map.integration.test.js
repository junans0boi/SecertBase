import assert from 'node:assert/strict';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

async function register(server, name) {
  const email = `${name}@example.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST',
    body: { email, password: 'password123', full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  const { userCode } = await registered.json();
  const login = await server.request('/auth/login', {
    method: 'POST', body: { email, password: 'password123' },
  });
  return { token: (await login.json()).token, userCode };
}

async function pair(server, sender, recipient) {
  const created = await server.request('/pairing/requests', {
    token: sender.token, method: 'POST', body: { recipientCode: recipient.userCode },
  });
  const { requestId } = await created.json();
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token, method: 'POST',
  });
  assert.equal(accepted.status, 200);
}

test('Secret Map is Couple-scoped, jointly editable, and creator-deletable', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  try {
    const alice = await register(server, 'map-alice');
    const bob = await register(server, 'map-bob');
    const carol = await register(server, 'map-carol');
    const dave = await register(server, 'map-dave');
    await pair(server, alice, bob);
    await pair(server, carol, dave);

    const createdResponse = await server.request('/map', {
      token: alice.token,
      method: 'POST',
      body: {
        place_name: 'Our place', latitude: 37.5, longitude: 127,
        created_by: carol.userCode, user_id: 999, status: 'wishlist',
      },
    });
    const created = await createdResponse.json();
    assert.equal(createdResponse.status, 200);

    const partnerEdit = await server.request(`/map/${created.id}`, {
      token: bob.token, method: 'PATCH',
      body: { status: 'visited', visit_date: '2026-07-15', memo: 'together', rating: 5, emotion_tags: ['또 가자'] },
    });
    assert.equal(partnerEdit.status, 200);

    const otherFeed = await server.request('/map?user_id=1', { token: carol.token });
    assert.deepEqual((await otherFeed.json()).pins, []);
    const otherEdit = await server.request(`/map/${created.id}`, {
      token: carol.token, method: 'PATCH', body: { memo: 'tampered' },
    });
    assert.equal(otherEdit.status, 403);

    const partnerDelete = await server.request(`/map/${created.id}`, {
      token: bob.token, method: 'DELETE',
    });
    assert.equal(partnerDelete.status, 403);

    const linkedMoment = await server.request('/setlog', {
      token: alice.token, method: 'POST',
      body: { caption: 'remember this place', media_type: 'text', taken_at: '2026-07-15', map_pin_id: created.id },
    });
    assert.equal(linkedMoment.status, 201);
    const creatorDelete = await server.request(`/map/${created.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(creatorDelete.status, 200);
    assert.equal((await creatorDelete.json()).archived, true);
    const activeMap = await server.request('/map', { token: alice.token });
    assert.deepEqual((await activeMap.json()).pins, []);
    const moments = await server.request('/setlog', { token: alice.token });
    assert.equal((await moments.json()).posts[0].linked_place_name, 'Our place');

    const unlinkedResponse = await server.request('/map', {
      token: alice.token, method: 'POST', body: { place_name: 'Temporary pin' },
    });
    const unlinked = await unlinkedResponse.json();
    const hardDelete = await server.request(`/map/${unlinked.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal((await hardDelete.json()).archived, false);

    const database = await mysql.createConnection(server.environment.databaseUrl);
    const [rows] = await database.execute(
      'SELECT id, archived_at FROM map_pins WHERE id IN (?, ?) ORDER BY id',
      [created.id, unlinked.id],
    );
    await database.end();
    assert.equal(rows.length, 1);
    assert.ok(rows[0].archived_at);
  } finally {
    await server.close();
  }
});
