import assert from 'node:assert/strict';
import test from 'node:test';
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
  assert.equal(registration.status, 200, await registration.text());

  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return { token: body.token };
};

test(
  'authenticated user can read and update only their own birth profile',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await registerAndLogin(server, 'birth-alice');
      const bob = await registerAndLogin(server, 'birth-bob');

      const initial = await server.request('/relationship/birth-profile', {
        token: alice.token,
      });
      const initialBody = await initial.json();
      assert.equal(initial.status, 200, JSON.stringify(initialBody));
      assert.deepEqual(initialBody.birthProfile, {
        calendarType: 'solar',
        birthDate: '2000-01-01',
        birthTime: null,
        timezone: 'Asia/Seoul',
        birthPlace: null,
      });

      const updated = await server.request('/relationship/birth-profile', {
        token: alice.token,
        method: 'PATCH',
        body: {
          calendarType: 'lunar',
          birthDate: '1999-12-31',
          birthTime: '23:05',
          timezone: 'Asia/Tokyo',
          birthPlace: '서울특별시',
          userId: 999999,
        },
      });
      const updatedBody = await updated.json();
      assert.equal(updated.status, 200, JSON.stringify(updatedBody));
      assert.deepEqual(updatedBody.birthProfile, {
        calendarType: 'lunar',
        birthDate: '1999-12-31',
        birthTime: '23:05:00',
        timezone: 'Asia/Tokyo',
        birthPlace: '서울특별시',
      });

      const aliceAgain = await server.request('/relationship/birth-profile', {
        token: alice.token,
      });
      assert.equal((await aliceAgain.json()).birthProfile.birthPlace, '서울특별시');

      const bobProfile = await server.request('/relationship/birth-profile', {
        token: bob.token,
      });
      assert.deepEqual((await bobProfile.json()).birthProfile, {
        calendarType: 'solar',
        birthDate: '2000-01-01',
        birthTime: null,
        timezone: 'Asia/Seoul',
        birthPlace: null,
      });
    } finally {
      await server.close();
    }
  },
);

test(
  'birth profile rejects invalid calendar, date, time, timezone, and future date',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const user = await registerAndLogin(server, 'birth-validation');
      const cases = [
        ['calendarType', 'martian', 'invalid_calendar_type'],
        ['birthDate', '2001-02-29', 'invalid_birth_date'],
        ['birthDate', '2999-01-01', 'future_birth_date'],
        ['birthTime', '25:00', 'invalid_birth_time'],
        ['timezone', 'not/a-timezone', 'invalid_timezone'],
      ];

      for (const [field, value, reason] of cases) {
        const body = {
          calendarType: 'solar',
          birthDate: '2000-01-01',
          birthTime: null,
          timezone: 'Asia/Seoul',
          birthPlace: null,
        };
        body[field] = value;
        const response = await server.request('/relationship/birth-profile', {
          token: user.token,
          method: 'PATCH',
          body,
        });
        const responseBody = await response.json();
        assert.equal(response.status, 400, `${field}: ${JSON.stringify(responseBody)}`);
        assert.equal(responseBody.reason, reason);
      }
    } finally {
      await server.close();
    }
  },
);
