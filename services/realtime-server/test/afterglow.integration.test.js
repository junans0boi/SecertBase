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

const createPin = async (server, user, status = 'wishlist') => {
  const response = await server.request('/map', {
    token: user.token,
    method: 'POST',
    body: { place_name: 'Afterglow Cafe', status },
  });
  assert.equal(response.status, 200);
  return response.json();
};

const createMoment = async (server, user, pinId, caption = 'moment') => {
  const response = await server.request('/setlog', {
    token: user.token,
    method: 'POST',
    body: {
      caption,
      media_type: 'text',
      taken_at: businessDate(),
      map_pin_id: pinId,
    },
  });
  assert.equal(response.status, 201);
  return (await response.json()).post;
};

test('a wishlist pin becomes one Couple-scoped Afterglow visit', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  try {
    const alice = await register(server, 'afterglow-alice');
    const bob = await register(server, 'afterglow-bob');
    const carol = await register(server, 'afterglow-carol');
    const dave = await register(server, 'afterglow-dave');
    await pair(server, alice, bob);
    await pair(server, carol, dave);

    const pin = await createPin(server, alice);
    const crossCouple = await server.request(`/retention/afterglow/${pin.id}/visit`, {
      token: carol.token, method: 'POST',
    });
    assert.equal(crossCouple.status, 404);

    const created = await server.request(`/retention/afterglow/${pin.id}/visit`, {
      token: bob.token, method: 'POST',
    });
    assert.equal(created.status, 201);
    const visit = (await created.json()).visit;
    assert.equal(visit.mapPinId, pin.id);
    assert.equal(visit.visitDate, businessDate());

    const retried = await server.request(`/retention/afterglow/${pin.id}/visit`, {
      token: alice.token, method: 'POST',
    });
    assert.equal(retried.status, 200);
    assert.equal((await retried.json()).visit.id, visit.id);

    const dateMutation = await server.request(`/map/${pin.id}`, {
      token: alice.token,
      method: 'PATCH',
      body: { visit_date: '2026-01-01', status: 'visited' },
    });
    assert.equal(dateMutation.status, 409);
    assert.equal((await dateMutation.json()).reason, 'afterglow_visit_managed');

    const zeroDetail = await server.request(`/retention/afterglow/pin/${pin.id}`, {
      token: alice.token,
    });
    assert.equal((await zeroDetail.json()).contributions.filter((slot) => slot.contributed).length, 0);

    const map = await server.request('/map', { token: alice.token });
    const updatedPin = (await map.json()).pins.find((candidate) => candidate.id === pin.id);
    assert.equal(updatedPin.status, 'visited');
    assert.equal(String(updatedPin.visit_date).slice(0, 10), businessDate());

    const legacyVisited = await createPin(server, alice, 'visited');
    const invalid = await server.request(`/retention/afterglow/${legacyVisited.id}/visit`, {
      token: alice.token, method: 'POST',
    });
    assert.equal(invalid.status, 409);
    assert.equal((await invalid.json()).reason, 'afterglow_requires_wishlist');

    const visitOnlyPin = await createPin(server, alice);
    await server.request(`/retention/afterglow/${visitOnlyPin.id}/visit`, {
      token: alice.token, method: 'POST',
    });
    const archivedVisitOnly = await server.request(`/map/${visitOnlyPin.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(archivedVisitOnly.status, 200);
    assert.equal((await archivedVisitOnly.json()).archived, true);

    const aliceMoment = await createMoment(server, alice, pin.id, 'Alice glow');
    const contributed = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: alice.token,
      method: 'PUT',
      body: { post_id: aliceMoment.id, caption: '또 걷고 싶어', emotion_tag: '포근함' },
    });
    assert.equal(contributed.status, 200);
    const aliceContribution = (await contributed.json()).contribution;
    assert.equal(aliceContribution.postId, aliceMoment.id);
    assert.equal(aliceContribution.caption, '또 걷고 싶어');
    assert.equal(aliceContribution.emotionTag, '포근함');

    const oneSidedDetail = await server.request(`/retention/afterglow/pin/${pin.id}`, {
      token: bob.token,
    });
    assert.equal(oneSidedDetail.status, 200);
    const oneSided = await oneSidedDetail.json();
    assert.equal(oneSided.contributions.length, 2);
    assert.equal(oneSided.contributions.filter((slot) => slot.contributed).length, 1);
    assert.equal(oneSided.contributions.find((slot) => slot.contributed).caption, '또 걷고 싶어');

    const bobMoment = await createMoment(server, bob, pin.id, 'Bob glow');
    const bobContributed = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: bob.token,
      method: 'PUT',
      body: { post_id: bobMoment.id, caption: '다음에도 같이', emotion_tag: '설렘' },
    });
    assert.equal(bobContributed.status, 200);
    const twoSidedDetail = await server.request(`/retention/afterglow/pin/${pin.id}`, {
      token: alice.token,
    });
    assert.equal((await twoSidedDetail.json()).contributions.filter((slot) => slot.contributed).length, 2);

    const crossDetail = await server.request(`/retention/afterglow/pin/${pin.id}`, {
      token: carol.token,
    });
    assert.equal(crossDetail.status, 404);

    const partnerPostRejected = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: bob.token, method: 'PUT', body: { post_id: aliceMoment.id },
    });
    assert.equal(partnerPostRejected.status, 404);

    const otherPin = await createPin(server, alice);
    const wrongPinMoment = await createMoment(server, alice, otherPin.id, 'wrong pin');
    const wrongPinRejected = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: alice.token, method: 'PUT', body: { post_id: wrongPinMoment.id },
    });
    assert.equal(wrongPinRejected.status, 404);

    const crossVisit = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: carol.token, method: 'PUT', body: { post_id: wrongPinMoment.id },
    });
    assert.equal(crossVisit.status, 404);

    const tooLong = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: alice.token,
      method: 'PUT',
      body: { post_id: aliceMoment.id, caption: 'x'.repeat(121) },
    });
    assert.equal(tooLong.status, 400);
    assert.equal((await tooLong.json()).reason, 'afterglow_caption_too_long');

    const replacement = await createMoment(server, alice, pin.id, 'replacement');
    const replaced = await server.request(`/retention/afterglow/${visit.id}/contribution`, {
      token: alice.token,
      method: 'PUT',
      body: { post_id: replacement.id, emotion_tag: '설렘' },
    });
    assert.equal(replaced.status, 200);
    assert.equal((await replaced.json()).contribution.postId, replacement.id);
    const deleted = await server.request(`/setlog/${replacement.id}`, {
      token: alice.token, method: 'DELETE',
    });
    assert.equal(deleted.status, 200);
    const tombstoneDetail = await server.request(`/retention/afterglow/pin/${pin.id}`, {
      token: alice.token,
    });
    const tombstone = (await tombstoneDetail.json()).contributions.find(
      (slot) => slot.userId === aliceContribution.userId,
    );
    assert.equal(tombstone.deleted, true);
    assert.equal(tombstone.caption, null);
    assert.equal(tombstone.mediaUrl, null);

    const summaryResponse = await server.request('/retention/afterglow/beta/summary?days=7', {
      token: alice.token,
    });
    assert.equal(summaryResponse.status, 200);
    const summary = await summaryResponse.json();
    assert.equal(summary.visits, 2);
    assert.equal(summary.visitsWithContribution, 1);
    assert.equal(summary.contributions, 1);
    assert.equal(summary.visitContributionRate, 0.5);
    assert.equal(summary.contributionRate, 0.25);
  } finally {
    await server.close();
  }
});
