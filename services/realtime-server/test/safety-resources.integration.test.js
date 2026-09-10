import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

test(
  'authenticated safety resource endpoint uses only permission, country, and admin area',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const email = `safety-${Date.now()}@relationship.test`;
      await server.request('/auth/register', {
        method: 'POST',
        body: {
          email,
          password: 'password123',
          full_name: 'safety-user',
          nickname: 'safety-user',
          birth_date: '1995-03-14',
        },
      });
      const login = await server.request('/auth/login', {
        method: 'POST',
        body: { email, password: 'password123' },
      });
      const loginBody = await login.json();
      assert.equal(login.status, 200, JSON.stringify(loginBody));

      const resources = await server.request(
        '/relationship/mindcare/safety-resources?permission=granted&country=KR&adminArea=%EC%84%9C%EC%9A%B8%ED%8A%B9%EB%B3%84%EC%8B%9C',
        { token: loginBody.token },
      );
      const resourcesBody = await resources.json();
      assert.equal(resources.status, 200, JSON.stringify(resourcesBody));
      assert.equal(resourcesBody.locationMode, 'region');
      assert.equal(resourcesBody.countryCode, 'KR');
      assert.equal(resourcesBody.resources[0].region, '서울특별시');

      const coordinates = await server.request(
        '/relationship/mindcare/safety-resources?permission=granted&country=KR&latitude=37.5&longitude=127',
        { token: loginBody.token },
      );
      assert.equal(coordinates.status, 400);
    } finally {
      await server.close();
    }
  },
);
