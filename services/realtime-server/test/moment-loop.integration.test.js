import assert from 'node:assert/strict';
import { readdir } from 'node:fs/promises';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const register = async (server, name) => {
  const email = `${name}@example.test`;
  const response = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '2000-01-01',
    },
  });
  const registered = await response.json();
  assert.equal(response.status, 200);
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const session = await login.json();
  return { token: session.token, userCode: registered.userCode };
};

const pair = async (server, sender, recipient) => {
  const request = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const { requestId } = await request.json();
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token,
    method: 'POST',
  });
  assert.equal(accepted.status, 200);
};

const textMoment = (caption) => ({
  caption,
  media_type: 'text',
  taken_at: '2026-07-15',
});

test(
  'MomentLoop is active-Couple readable and author-owned for mutations',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await register(server, 'moment-alice');
      const bob = await register(server, 'moment-bob');
      const carol = await register(server, 'moment-carol');
      const dave = await register(server, 'moment-dave');
      await pair(server, alice, bob);
      await pair(server, carol, dave);

      const createdResponse = await server.request('/setlog', {
        token: alice.token,
        method: 'POST',
        body: textMoment('our first moment'),
      });
      const created = await createdResponse.json();
      assert.equal(createdResponse.status, 201);

      const partnerFeed = await server.request('/setlog', { token: bob.token });
      assert.equal((await partnerFeed.json()).posts[0].caption, 'our first moment');

      const otherFeed = await server.request('/setlog?user_id=1', { token: carol.token });
      assert.deepEqual((await otherFeed.json()).posts, []);

      const partnerEdit = await server.request(`/setlog/${created.post.id}`, {
        token: bob.token,
        method: 'PATCH',
        body: { caption: 'tampered' },
      });
      assert.equal(partnerEdit.status, 403);

      const edited = await server.request(`/setlog/${created.post.id}`, {
        token: alice.token,
        method: 'PATCH',
        body: { caption: 'edited by author' },
      });
      assert.equal(edited.status, 200);
      assert.equal((await edited.json()).post.caption, 'edited by author');

      const partnerDelete = await server.request(`/setlog/${created.post.id}`, {
        token: bob.token,
        method: 'DELETE',
      });
      assert.equal(partnerDelete.status, 403);

      const photo = new FormData();
      photo.set('caption', 'photo moment');
      photo.set('taken_at', '2026-07-15');
      photo.set('media', new Blob(['fake-png'], { type: 'image/png' }), 'moment.png');
      const photoResponse = await server.request('/setlog', {
        token: alice.token,
        method: 'POST',
        body: photo,
      });
      const photoCreated = await photoResponse.json();
      assert.equal(photoResponse.status, 201);
      assert.equal((await readdir(server.environment.uploadsRoot)).length, 1);

      const rejected = new FormData();
      rejected.set('caption', 'orphan candidate');
      rejected.set('taken_at', '2026-07-15');
      rejected.set('map_pin_id', '999999');
      rejected.set('media', new Blob(['fake-png'], { type: 'image/png' }), 'rejected.png');
      const rejectedResponse = await server.request('/setlog', {
        token: alice.token,
        method: 'POST',
        body: rejected,
      });
      assert.equal(rejectedResponse.status, 400);
      assert.equal((await readdir(server.environment.uploadsRoot)).length, 1);

      const deleted = await server.request(`/setlog/${photoCreated.post.id}`, {
        token: alice.token,
        method: 'DELETE',
      });
      assert.equal(deleted.status, 200);
      assert.deepEqual(await readdir(server.environment.uploadsRoot), []);
    } finally {
      await server.close();
    }
  },
);
