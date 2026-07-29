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

const createMoment = async (server, user, caption, todayMoment = false) => {
  const response = await server.request('/setlog', {
    token: user.token,
    method: 'POST',
    body: {
      caption,
      media_type: 'text',
      taken_at: businessDate(),
      ...(todayMoment ? { today_moment: true } : {}),
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

    const third = await createMoment(server, alice, 'third');
    await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: third.body.post.id },
    });

    const crossCouple = await server.request('/retention/today/moment', {
      token: carol.token, method: 'PUT', body: { post_id: third.body.post.id },
    });
    assert.equal(crossCouple.status, 404);

    const partnerToday = await createMoment(server, bob, 'partner', true);
    assert.equal(partnerToday.response.status, 201);

    const locked = await server.request('/retention/today/moment', {
      token: alice.token, method: 'PUT', body: { post_id: first.body.post.id },
    });
    assert.equal(locked.status, 409);
    assert.equal((await locked.json()).reason, 'today_loop_locked');
  } finally {
    await server.close();
  }
});
