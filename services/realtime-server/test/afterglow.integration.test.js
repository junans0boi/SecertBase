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
  } finally {
    await server.close();
  }
});
