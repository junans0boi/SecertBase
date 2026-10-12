import assert from 'node:assert/strict';
import test from 'node:test';
import { readdir } from 'node:fs/promises';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;
const options = { skip: !adminUrl || !redisUrl };

async function register(server, name) {
  const response = await server.request('/auth/register', {
    method: 'POST',
    body: { email: `${name}@example.test`, password: 'test-password123',
      full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  assert.equal(response.status, 200);
  const { userCode } = await response.json();
  const login = await server.request('/auth/login', {
    method: 'POST', body: { email: `${name}@example.test`, password: 'test-password123' },
  });
  return { token: (await login.json()).token, userCode };
}

async function pairedServer() {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  try {
    const author = await register(server, 'editing-alice');
    const partner = await register(server, 'editing-bob');
    const requested = await server.request('/pairing/requests', {
      token: author.token, method: 'POST', body: { recipientCode: partner.userCode },
    });
    const { requestId } = await requested.json();
    const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
      token: partner.token, method: 'POST',
    });
    assert.equal(accepted.status, 200);
    return { server, author, partner };
  } catch (error) {
    await server.close();
    throw error;
  }
}

const moment = (extra = {}) => ({
  caption: 'original caption', media_type: 'text', taken_at: '2026-07-15',
  session_id: 'editing-session', ...extra,
});

test('retrying a stable upload request returns the same ordered MomentLoop once', options, async () => {
  const { server, author } = await pairedServer();
  try {
    const body = moment({ client_request_id: 'stable-file-request', position: 2 });
    const first = await server.request('/setlog', { token: author.token, method: 'POST', body });
    const created = await first.json();
    assert.equal(first.status, 201);
    const retry = await server.request('/setlog', { token: author.token, method: 'POST', body });
    const replayed = await retry.json();
    assert.equal(retry.status, 200);
    assert.equal(replayed.post.id, created.post.id);
    const feed = await server.request('/setlog', { token: author.token });
    const { posts } = await feed.json();
    assert.equal(posts.length, 1);
    assert.equal(posts[0].position, 2);
  } finally {
    await server.close();
  }
});

test('concurrent retries create one record and request keys are author-scoped', options, async () => {
  const { server, author, partner } = await pairedServer();
  try {
    const body = moment({ client_request_id: 'same-key', position: 0 });
    const results = await Promise.all([1, 2].map(() => server.request('/setlog', {
      token: author.token, method: 'POST', body,
    })));
    assert.deepEqual(results.map(r => r.status).sort(), [200, 201]);
    const posts = await Promise.all(results.map(r => r.json()));
    assert.equal(posts[0].post.id, posts[1].post.id);
    const other = await server.request('/setlog', {
      token: partner.token, method: 'POST', body: { ...body, session_id: 'partner-session' },
    });
    assert.equal(other.status, 201);
    assert.notEqual((await other.json()).post.id, posts[0].post.id);
    const feed = await server.request('/setlog', { token: author.token });
    assert.equal((await feed.json()).posts.length, 2);
  } finally { await server.close(); }
});

test('replayed photo upload removes the new file and preserves the original', options, async () => {
  const { server, author } = await pairedServer();
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jJ1sAAAAASUVORK5CYII=', 'base64');
  const form = () => {
    const body = new FormData();
    body.set('taken_at', '2026-07-15');
    body.set('session_id', 'photo-session');
    body.set('position', '0');
    body.set('client_request_id', 'photo-request');
    body.set('media', new Blob([png], { type: 'image/png' }), 'original.png');
    return body;
  };
  try {
    const first = await server.request('/setlog', { token: author.token, method: 'POST', body: form() });
    const original = (await first.json()).post;
    assert.equal(first.status, 201);
    const second = await server.request('/setlog', { token: author.token, method: 'POST', body: form() });
    assert.equal(second.status, 200);
    assert.deepEqual((await second.json()).post, original);
    assert.deepEqual(await readdir(server.environment.uploadsRoot), [original.media_url.split('/').at(-1)]);
  } finally { await server.close(); }
});

test('invalid order, request id and calendar date never create a record', options, async () => {
  const { server, author } = await pairedServer();
  try {
    for (const extra of [
      { position: -1 }, { position: '1.5' }, { position: 32768 },
      { client_request_id: '' }, { client_request_id: 'x'.repeat(65) },
      { taken_at: '2026-02-30' },
    ]) {
      const response = await server.request('/setlog', {
        token: author.token, method: 'POST', body: moment(extra),
      });
      assert.equal(response.status, 400, JSON.stringify(extra));
    }
    const feed = await server.request('/setlog', { token: author.token });
    assert.deepEqual((await feed.json()).posts, []);
  } finally { await server.close(); }
});

test('an author updates the whole session while a partner cannot change it', options, async () => {
  const { server, author, partner } = await pairedServer();
  try {
    for (const position of [0, 1]) {
      const response = await server.request('/setlog', {
        token: author.token, method: 'POST', body: moment({ position }),
      });
      assert.equal(response.status, 201);
    }
    const forbidden = await server.request('/setlog/session/editing-session', {
      token: partner.token, method: 'PATCH', body: { caption: 'tampered' },
    });
    assert.equal(forbidden.status, 403);
    const pinResponse = await server.request('/map', {
      token: author.token, method: 'POST', body: { place_name: 'our updated place' },
    });
    const pin = await pinResponse.json();
    const response = await server.request('/setlog/session/editing-session', {
      token: author.token, method: 'PATCH',
      body: { caption: 'whole edit', taken_at: '2026-07-14', tags: ['date'], map_pin_id: pin.id },
    });
    assert.equal(response.status, 200, await response.text());
    const feed = await server.request('/setlog', { token: author.token });
    const { posts } = await feed.json();
    assert.equal(posts.length, 2);
    for (const post of posts) {
      assert.equal(post.caption, 'whole edit');
      assert.equal(post.taken_at, '2026-07-14');
      assert.equal(post.map_pin_id, pin.id);
      assert.equal(post.session_id, 'editing-session');
      assert.deepEqual(typeof post.tags === 'string' ? JSON.parse(post.tags) : post.tags, ['date']);
    }
    const immutable = await server.request('/setlog/session/editing-session', {
      token: author.token, method: 'PATCH', body: { session_id: 'changed', caption: 'wrong' },
    });
    assert.equal(immutable.status, 400);
  } finally { await server.close(); }
});

test('session ordering requires every owned post exactly once and returns the new order', options, async () => {
  const { server, author, partner } = await pairedServer();
  try {
    const ids = [];
    for (const position of [0, 1, 2]) {
      const response = await server.request('/setlog', {
        token: author.token, method: 'POST', body: moment({ position }),
      });
      ids.push((await response.json()).post.id);
    }
    const ordered = await server.request('/setlog/session/editing-session/order', {
      token: author.token, method: 'PATCH', body: { order: [ids[2], ids[0], ids[1]] },
    });
    assert.equal(ordered.status, 200, await ordered.text());
    assert.deepEqual((await ordered.json()).posts.map((post) => post.id), [ids[2], ids[0], ids[1]]);
    const incomplete = await server.request('/setlog/session/editing-session/order', {
      token: author.token, method: 'PATCH', body: { order: [ids[0]] },
    });
    assert.equal(incomplete.status, 400);
    const forbidden = await server.request('/setlog/session/editing-session/order', {
      token: partner.token, method: 'PATCH', body: { order: ids },
    });
    assert.equal(forbidden.status, 403);
  } finally { await server.close(); }
});

test('a revealed Today Moment locks media changes and date changes but keeps metadata editable', options, async () => {
  const { server, author, partner } = await pairedServer();
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Seoul' });
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jJ1sAAAAASUVORK5CYII=', 'base64');
  const photoBody = () => {
    const body = new FormData();
    body.set('taken_at', today);
    body.set('session_id', 'revealed-author-session');
    body.set('today_moment', 'true');
    body.set('media', new Blob([png], { type: 'image/png' }), 'today.png');
    return body;
  };
  try {
    const photoResponse = await server.request('/setlog', {
      token: author.token, method: 'POST', body: photoBody(),
    });
    assert.equal(photoResponse.status, 201);
    const photo = (await photoResponse.json()).post;
    const partnerResponse = await server.request('/setlog', {
      token: partner.token,
      method: 'POST',
      body: moment({ taken_at: today, session_id: 'revealed-partner-session', today_moment: true }),
    });
    assert.equal(partnerResponse.status, 201);

    const feed = await server.request('/setlog', { token: author.token });
    const authored = (await feed.json()).posts.find((post) => post.id === photo.id);
    assert.equal(authored.today_moment, true);
    assert.equal(authored.media_edit_locked, true);

    const addMedia = await server.request('/setlog', {
      token: author.token, method: 'POST', body: photoBody(),
    });
    assert.equal(addMedia.status, 409);
    assert.equal((await addMedia.json()).reason, 'today_loop_media_locked');
    const deleteMedia = await server.request(`/setlog/${photo.id}`, {
      token: author.token, method: 'DELETE',
    });
    assert.equal(deleteMedia.status, 409);

    const changeDate = await server.request('/setlog/session/revealed-author-session', {
      token: author.token, method: 'PATCH', body: { taken_at: '2026-10-11' },
    });
    assert.equal(changeDate.status, 409);
    const changeCaption = await server.request('/setlog/session/revealed-author-session', {
      token: author.token, method: 'PATCH', body: { caption: 'still editable' },
    });
    assert.equal(changeCaption.status, 200);
  } finally { await server.close(); }
});
