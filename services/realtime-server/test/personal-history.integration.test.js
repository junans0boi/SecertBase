import assert from 'node:assert/strict';
import { readdir, rm } from 'node:fs/promises';
import test from 'node:test';
import AdmZip from 'adm-zip';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

async function user(server, name) {
  const email = `${name}@history.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST', body: { email, password: 'password123', full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  const { userCode } = await registered.json();
  const loggedIn = await server.request('/auth/login', {
    method: 'POST', body: { email, password: 'password123' },
  });
  const login = await loggedIn.json();
  return { token: login.token, userCode, userId: login.user.UserId };
}

async function pair(server, one, two) {
  const created = await server.request('/pairing/requests', {
    token: one.token, method: 'POST', body: { recipientCode: two.userCode },
  });
  const { requestId } = await created.json();
  await server.request(`/pairing/requests/${requestId}/accept`, { token: two.token, method: 'POST' });
}

test('personal history is author-only across separation, export, and a new Couple', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  try {
    const one = await user(server, 'history-one');
    const two = await user(server, 'history-two');
    await pair(server, one, two);

    const mine = await server.request('/setlog', {
      token: one.token, method: 'POST', body: { caption: 'mine only', media_type: 'text', taken_at: '2026-07-15' },
    });
    const mineId = (await mine.json()).post.id;
    const partner = await server.request('/setlog', {
      token: two.token, method: 'POST', body: { caption: 'partner secret', media_type: 'text', taken_at: '2026-07-15' },
    });
    const partnerId = (await partner.json()).post.id;
    const photo = new FormData();
    photo.set('caption', 'my media');
    photo.set('taken_at', '2026-07-15');
    photo.set('media', new Blob(['photo-bytes'], { type: 'image/png' }), 'mine.png');
    await server.request('/setlog', { token: one.token, method: 'POST', body: photo });
    const pinResponse = await server.request('/map', {
      token: one.token, method: 'POST', body: { place_name: 'My pin' },
    });
    const pinId = (await pinResponse.json()).id;
    const retainedPinResponse = await server.request('/map', {
      token: one.token, method: 'POST', body: { place_name: 'Old retained pin' },
    });
    const retainedPinId = (await retainedPinResponse.json()).id;
    await server.request('/map', { token: two.token, method: 'POST', body: { place_name: 'Partner pin' } });
    await server.request('/user/partner', { token: one.token, method: 'DELETE' });

    const history = await (await server.request('/history', { token: one.token })).json();
    assert.deepEqual(history.moments.map((item) => item.caption).sort(), ['mine only', 'my media']);
    assert.deepEqual(history.pins.map((item) => item.place_name).sort(), [
      'My pin',
      'Old retained pin',
    ]);
    assert.equal((await server.request(`/history/moments/${partnerId}`, { token: one.token, method: 'DELETE' })).status, 404);
    assert.equal((await server.request(`/history/moments/${mineId}`, { token: one.token, method: 'DELETE' })).status, 200);
    assert.equal((await server.request(`/history/pins/${pinId}`, { token: one.token, method: 'DELETE' })).status, 200);

    const exported = await server.request('/history/export', { token: one.token });
    const zip = new AdmZip(Buffer.from(await exported.arrayBuffer()));
    assert.ok(JSON.parse(zip.readAsText('momentloop.json')).every((item) => Number(item.user_id) === one.userId));
    assert.ok(JSON.parse(zip.readAsText('map-pins.json')).every((item) => Number(item.user_id) === one.userId));
    assert.equal(zip.getEntries().filter((entry) => entry.entryName.startsWith('media/')).length, 1);
    for (const file of await readdir(server.environment.uploadsRoot)) {
      await rm(`${server.environment.uploadsRoot}/${file}`, { force: true });
    }
    assert.equal((await server.request('/history/export', { token: one.token })).status, 200);

    const three = await user(server, 'history-three');
    await pair(server, one, three);
    assert.deepEqual((await (await server.request('/setlog', { token: one.token })).json()).posts, []);
    assert.equal((await server.request(`/map/${retainedPinId}`, {
      token: one.token, method: 'DELETE',
    })).status, 403);
    assert.equal((await server.request('/history', { token: one.token })).status, 409);
  } finally {
    await server.close();
  }
});
