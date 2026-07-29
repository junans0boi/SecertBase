import assert from 'node:assert/strict';
import test from 'node:test';
import { businessDate } from '../src/business-date.js';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const register = async (server, name) => {
  const email = `${name}@example.test`;
  const response = await server.request('/auth/register', {
    method: 'POST',
    body: { email, password: 'password123', full_name: name, nickname: name, birth_date: '2000-01-01' },
  });
  const registered = await response.json();
  const login = await server.request('/auth/login', {
    method: 'POST', body: { email, password: 'password123' },
  });
  return { token: (await login.json()).token, userCode: registered.userCode };
};

const pair = async (server, sender, recipient) => {
  const request = await server.request('/pairing/requests', {
    token: sender.token, method: 'POST', body: { recipientCode: recipient.userCode },
  });
  const { requestId } = await request.json();
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token, method: 'POST',
  });
  assert.equal(accepted.status, 200);
};

const createMoment = async (server, user, caption, todayMoment = false, fields = {}) => {
  const response = await server.request('/setlog', {
    token: user.token,
    method: 'POST',
    body: {
      caption,
      media_type: 'text',
      taken_at: businessDate(),
      ...(todayMoment ? { today_moment: true } : {}),
      ...fields,
    },
  });
  return { response, body: await response.json() };
};

test('an author selects one Today Moment and cannot replace it after reveal', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  try {
    const alice = await register(server, 'today-alice');
    const bob = await register(server, 'today-bob');
    const carol = await register(server, 'today-carol');
    const dave = await register(server, 'today-dave');
    await pair(server, alice, bob);
    await pair(server, carol, dave);

    const first = await createMoment(server, alice, 'first');
    assert.equal(first.response.status, 201);
    const selected = await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: first.body.post.id },
    });
    assert.equal(selected.status, 200);

    const second = await createMoment(server, alice, 'second');
    const replaced = await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: second.body.post.id },
    });
    assert.equal(replaced.status, 200);

    const removed = await server.request('/retention/today/moment', {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(removed.status, 200);
    assert.equal((await removed.json()).removed, true);

    await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: second.body.post.id },
    });
    const deletedSelectedPost = await server.request(`/setlog/${second.body.post.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(deletedSelectedPost.status, 200);
    const emptyState = await server.request('/retention/today', { token: alice.token });
    assert.equal((await emptyState.json()).status, 'empty');

    const placeResponse = await server.request('/map', {
      token: alice.token,
      method: 'POST',
      body: { place_name: 'locked place' },
    });
    const place = await placeResponse.json();
    const third = await createMoment(server, alice, 'third', false, {
      map_pin_id: place.id,
    });
    await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: third.body.post.id },
    });

    const waitingFeed = await server.request('/setlog', { token: bob.token });
    const lockedPost = (await waitingFeed.json()).posts.find(
      (post) => post.id === third.body.post.id,
    );
    assert.equal(lockedPost.today_locked, true);
    assert.equal(lockedPost.caption, null);
    assert.equal(lockedPost.media_url, null);
    assert.equal(lockedPost.map_pin_id, null);
    assert.equal(lockedPost.linked_place_name, null);
    assert.equal(lockedPost.captured_at, null);

    const waitingState = await server.request('/retention/today', { token: bob.token });
    const waitingToday = await waitingState.json();
    assert.equal(waitingToday.status, 'partner_waiting');
    assert.equal(waitingToday.hasPartnerMoment, true);
    assert.equal(waitingToday.partnerMoment, null);

    const isolatedToday = await server.request('/retention/today', { token: carol.token });
    assert.equal((await isolatedToday.json()).status, 'empty');
    const isolatedFeed = await server.request('/setlog', { token: carol.token });
    assert.deepEqual((await isolatedFeed.json()).posts, []);
    const isolatedMap = await server.request('/map', { token: carol.token });
    assert.deepEqual((await isolatedMap.json()).pins, []);

    const crossCouple = await server.request('/retention/today/moment', {
      token: carol.token, method: 'PUT', body: { post_id: third.body.post.id },
    });
    assert.equal(crossCouple.status, 404);

    const partnerToday = await createMoment(server, bob, 'partner', true);
    assert.equal(partnerToday.response.status, 201);

    const revealedFeed = await server.request('/setlog', { token: bob.token });
    const revealedPost = (await revealedFeed.json()).posts.find(
      (post) => post.id === third.body.post.id,
    );
    assert.equal(revealedPost.today_locked, false);
    assert.equal(revealedPost.caption, 'third');

    const completeState = await server.request('/retention/today', { token: alice.token });
    const completeToday = await completeState.json();
    assert.equal(completeToday.status, 'complete');
    assert.equal(completeToday.partnerMoment.caption, 'partner');

    const locked = await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: first.body.post.id },
    });
    assert.equal(locked.status, 409);
    assert.equal((await locked.json()).reason, 'today_loop_locked');

    const deletedRevealedPost = await server.request(`/setlog/${third.body.post.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(deletedRevealedPost.status, 200);
    const tombstoneState = await server.request('/retention/today', { token: bob.token });
    const tombstoneToday = await tombstoneState.json();
    assert.equal(tombstoneToday.status, 'complete');
    assert.equal(tombstoneToday.partnerMoment.deleted, true);
    assert.equal(tombstoneToday.partnerMoment.caption, undefined);

    const [carolCreated, daveCreated] = await Promise.all([
      createMoment(server, carol, 'carol simultaneous', true),
      createMoment(server, dave, 'dave simultaneous', true),
    ]);
    assert.equal(carolCreated.response.status, 201);
    assert.equal(daveCreated.response.status, 201);

    const [carolState, daveState] = await Promise.all([
      server.request('/retention/today', { token: carol.token }),
      server.request('/retention/today', { token: dave.token }),
    ]);
    const [carolToday, daveToday] = await Promise.all([
      carolState.json(),
      daveState.json(),
    ]);
    assert.equal(carolToday.status, 'complete');
    assert.equal(carolToday.partnerMoment.caption, 'dave simultaneous');
    assert.equal(daveToday.status, 'complete');
    assert.equal(daveToday.partnerMoment.caption, 'carol simultaneous');
  } finally {
    await server.close();
  }
});
