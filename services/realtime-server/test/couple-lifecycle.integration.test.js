import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createUser = async (server, name) => {
  const email = `${name}@lifecycle.test`;
  const registered = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '2000-01-01',
    },
  });
  const userCode = (await registered.json()).userCode;
  const loggedIn = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const login = await loggedIn.json();
  return { token: login.token, userCode, userId: login.user.UserId };
};

const pair = async (server, sender, recipient) => {
  const created = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const requestId = (await created.json()).requestId;
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token,
    method: 'POST',
  });
  const acceptedText = await accepted.text();
  assert.equal(accepted.status, 200, acceptedText);
  return JSON.parse(acceptedText);
};

test(
  'Separation preserves and Reunion restores the same Couple and D-day',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const one = await createUser(server, 'one');
      const two = await createUser(server, 'two');
      const firstPairing = await pair(server, one, two);

      const dday = await server.request('/couple/info', {
        token: one.token,
        method: 'PATCH',
        body: { start_date: '2025-01-02' },
      });
      assert.equal(dday.status, 200);

      const separated = await server.request('/user/partner', {
        token: one.token,
        method: 'DELETE',
      });
      assert.equal(separated.status, 200);
      const closedProfile = await server.request(`/user/profile/${two.userId}`, {
        token: two.token,
      });
      assert.equal((await closedProfile.json()).user.PartnerCode, null);

      const reunion = await pair(server, one, two);
      assert.equal(reunion.coupleId, firstPairing.coupleId);
      assert.equal(reunion.reunited, true);

      const restored = await server.request('/couple/info', { token: two.token });
      const restoredData = await restored.json();
      assert.equal(restoredData.startDate, '2025-01-02');

      const oneProfile = await server.request(`/user/profile/${one.userId}`, {
        token: one.token,
      });
      const twoProfile = await server.request(`/user/profile/${two.userId}`, {
        token: two.token,
      });
      assert.equal((await oneProfile.json()).user.ReunionNoticePending, true);
      assert.equal((await twoProfile.json()).user.ReunionNoticePending, true);

      await server.request('/couple/reunion-notice/seen', {
        token: one.token,
        method: 'POST',
      });
      const seenProfile = await server.request(`/user/profile/${one.userId}`, {
        token: one.token,
      });
      assert.equal((await seenProfile.json()).user.ReunionNoticePending, false);
    } finally {
      await server.close();
    }
  },
);
