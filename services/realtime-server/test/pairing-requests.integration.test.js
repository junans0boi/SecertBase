import assert from 'node:assert/strict';
import test from 'node:test';
import mysql from 'mysql2/promise';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const registerAndLogin = async (server, name) => {
  const email = `${name}@example.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '2000-01-01',
    },
  });
  const registrationText = await registration.text();
  assert.equal(registration.status, 200, registrationText);
  const userCode = JSON.parse(registrationText).userCode;
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const loginText = await login.text();
  assert.equal(login.status, 200, loginText);
  const data = JSON.parse(loginText);
  return { token: data.token, userCode };
};

test(
  'pairing requests require recipient consent and enforce one active Couple',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await registerAndLogin(server, 'alice');
      const bob = await registerAndLogin(server, 'bob');
      const carol = await registerAndLogin(server, 'carol');

      const cancelledRequest = await server.request('/pairing/requests', {
        token: alice.token,
        method: 'POST',
        body: { recipientCode: bob.userCode },
      });
      const cancelledId = (await cancelledRequest.json()).requestId;
      const cancelled = await server.request(`/pairing/requests/${cancelledId}/cancel`, {
        token: alice.token,
        method: 'POST',
      });
      assert.equal(cancelled.status, 200);

      const rejectedRequest = await server.request('/pairing/requests', {
        token: alice.token,
        method: 'POST',
        body: { recipientCode: bob.userCode },
      });
      const rejectedId = (await rejectedRequest.json()).requestId;
      const rejected = await server.request(`/pairing/requests/${rejectedId}/reject`, {
        token: bob.token,
        method: 'POST',
      });
      assert.equal(rejected.status, 200);

      const created = await server.request('/pairing/requests', {
        token: alice.token,
        method: 'POST',
        body: { recipientCode: bob.userCode },
      });
      const createdText = await created.text();
      assert.equal(created.status, 201, createdText);
      const requestId = JSON.parse(createdText).requestId;

      const inbox = await server.request('/pairing/requests', { token: bob.token });
      const inboxData = await inbox.json();
      assert.equal(inboxData.received[0].senderCode, alice.userCode);

      const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
        token: bob.token,
        method: 'POST',
      });
      assert.equal(accepted.status, 200, await accepted.text());

      const blocked = await server.request('/pairing/requests', {
        token: carol.token,
        method: 'POST',
        body: { recipientCode: alice.userCode },
      });
      assert.equal(blocked.status, 409);
      assert.equal((await blocked.json()).reason, 'active_couple_exists');

      const dave = await registerAndLogin(server, 'dave');
      const expiredRequest = await server.request('/pairing/requests', {
        token: carol.token,
        method: 'POST',
        body: { recipientCode: dave.userCode },
      });
      const expiredId = (await expiredRequest.json()).requestId;
      const database = await mysql.createConnection(server.environment.databaseUrl);
      await database.execute(
        'UPDATE PairingRequests SET ExpiresAt = DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 SECOND) WHERE PairingRequestId = ?',
        [expiredId],
      );
      await database.end();
      const expired = await server.request(`/pairing/requests/${expiredId}/accept`, {
        token: dave.token,
        method: 'POST',
      });
      assert.equal(expired.status, 410);

      const eve = await registerAndLogin(server, 'eve');
      const frank = await registerAndLogin(server, 'frank');
      const gina = await registerAndLogin(server, 'gina');
      const eveRequest = await server.request('/pairing/requests', {
        token: eve.token,
        method: 'POST',
        body: { recipientCode: gina.userCode },
      });
      const frankRequest = await server.request('/pairing/requests', {
        token: frank.token,
        method: 'POST',
        body: { recipientCode: gina.userCode },
      });
      const eveId = (await eveRequest.json()).requestId;
      const frankId = (await frankRequest.json()).requestId;
      const race = await Promise.all([
        server.request(`/pairing/requests/${eveId}/accept`, {
          token: gina.token,
          method: 'POST',
        }),
        server.request(`/pairing/requests/${frankId}/accept`, {
          token: gina.token,
          method: 'POST',
        }),
      ]);
      const raceStatuses = race.map((response) => response.status).sort();
      assert.equal(raceStatuses[0], 200);
      assert.ok([404, 409].includes(raceStatuses[1]));
    } finally {
      await server.close();
    }
  },
);
