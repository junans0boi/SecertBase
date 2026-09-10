import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const registerAndLogin = async (server, name) => {
  const email = `${name}-${Date.now()}@saju.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '1995-03-16',
    },
  });
  const registrationBody = await registration.json();
  assert.equal(registration.status, 200, JSON.stringify(registrationBody));
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return { token: body.token, userCode: registrationBody.userCode };
};

const pair = async (server, sender, recipient) => {
  const created = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const createdBody = await created.json();
  assert.equal(created.status, 201, JSON.stringify(createdBody));
  const accepted = await server.request(`/pairing/requests/${createdBody.requestId}/accept`, {
    token: recipient.token,
    method: 'POST',
  });
  assert.equal(accepted.status, 200, await accepted.text());
};

test(
  'authenticated Saju REST returns profile readiness and both reading layers',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const user = await registerAndLogin(server, 'saju-ready');
      const profile = await server.request('/relationship/birth-profile', {
        token: user.token,
        method: 'PATCH',
        body: {
          calendarType: 'solar',
          birthDate: '1995-03-16',
          lunarLeapMonth: false,
          birthTime: '07:30',
          timezone: 'Asia/Seoul',
          birthPlace: '서울특별시',
        },
      });
      assert.equal(profile.status, 200, await profile.text());

      const response = await server.request('/relationship/saju', { token: user.token });
      const body = await response.json();
      assert.equal(response.status, 200, JSON.stringify(body));
      assert.equal(body.status, 'ready');
      assert.equal(body.personal.mode, 'complete');
      assert.ok(body.personal.plain);
      assert.ok(body.personal.technical);
      assert.equal(body.relationship, null);
    } finally {
      await server.close();
    }
  },
);

test(
  'Saju REST requires an explicit limited-mode choice when time or place is missing',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const user = await registerAndLogin(server, 'saju-limited');
      await server.request('/relationship/birth-profile', {
        token: user.token,
        method: 'PATCH',
        body: {
          calendarType: 'solar',
          birthDate: '1995-03-16',
          lunarLeapMonth: false,
          birthTime: null,
          timezone: 'Asia/Seoul',
          birthPlace: null,
        },
      });

      const blocked = await server.request('/relationship/saju', { token: user.token });
      const blockedBody = await blocked.json();
      assert.equal(blocked.status, 409, JSON.stringify(blockedBody));
      assert.equal(blockedBody.status, 'limited');
      assert.equal(blockedBody.reason, 'saju_limited_confirmation_required');

      const limited = await server.request('/relationship/saju', {
        token: user.token,
        method: 'POST',
        body: { mode: 'limited' },
      });
      const limitedBody = await limited.json();
      assert.equal(limited.status, 200, JSON.stringify(limitedBody));
      assert.equal(limitedBody.status, 'limited');
      assert.equal(limitedBody.status, 'limited');
      assert.deepEqual(limitedBody.personal.limitations, [
        'birthTimeMissing',
        'birthPlaceMissing',
      ]);
    } finally {
      await server.close();
    }
  },
);

test(
  'Saju REST returns a Couple pattern summary without scores or partner charts',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await registerAndLogin(server, 'saju-couple-alice');
      const bob = await registerAndLogin(server, 'saju-couple-bob');
      await pair(server, alice, bob);
      for (const [user, birthDate, birthTime, birthPlace] of [
        [alice, '1995-03-16', '07:30', '서울특별시'],
        [bob, '1990-08-12', '18:20', '부산광역시'],
      ]) {
        const profile = await server.request('/relationship/birth-profile', {
          token: user.token,
          method: 'PATCH',
          body: {
            calendarType: 'solar',
            birthDate,
            lunarLeapMonth: false,
            birthTime,
            timezone: 'Asia/Seoul',
            birthPlace,
          },
        });
        assert.equal(profile.status, 200, await profile.text());
      }

      const response = await server.request('/relationship/saju', { token: alice.token });
      const body = await response.json();
      assert.equal(response.status, 200, JSON.stringify(body));
      assert.equal(body.relationship.scope, 'couple');
      assert.equal(body.relationship.status, 'ready');
      assert.ok(body.relationship.patterns.length >= 2);
      assert.ok(body.relationship.conversationQuestions.length >= 2);
      assert.equal('score' in body.relationship, false);
      assert.equal('technical' in body.relationship, false);
      assert.equal('partnerChart' in body.relationship, false);
    } finally {
      await server.close();
    }
  },
);
