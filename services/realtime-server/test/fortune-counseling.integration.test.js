import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createAndLogin = async (server, name) => {
  const email = `${name}-${Date.now()}@relationship.test`;
  const registration = await server.request('/auth/register', {
    method: 'POST',
    body: {
      email,
      password: 'password123',
      full_name: name,
      nickname: name,
      birth_date: '1995-03-14',
    },
  });
  assert.equal(registration.status, 200, await registration.text());
  const registered = await registration.json();
  const login = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await login.json();
  assert.equal(login.status, 200, JSON.stringify(body));
  return { token: body.token, userCode: registered.userCode, userId: body.user.UserId };
};

const pair = async (server, first, second) => {
  const request = await server.request('/pairing/requests', {
    token: first.token,
    method: 'POST',
    body: { recipientCode: second.userCode },
  });
  const requestBody = await request.json();
  assert.equal(request.status, 201, JSON.stringify(requestBody));
  const accepted = await server.request(`/pairing/requests/${requestBody.requestId}/accept`, {
    token: second.token,
    method: 'POST',
  });
  const acceptedBody = await accepted.json();
  assert.equal(accepted.status, 200, JSON.stringify(acceptedBody));
  return acceptedBody;
};

test(
  'fortune is persisted per scope and explicit regeneration keeps a shared couple result identical',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const first = await createAndLogin(server, 'fortune-first');
      const second = await createAndLogin(server, 'fortune-second');
      const initial = await server.request('/relationship/fortune/today', { token: first.token });
      const initialBody = await initial.json();
      assert.equal(initial.status, 200, JSON.stringify(initialBody));
      assert.equal(initialBody.fortunes.personal.type, 'personal');
      assert.equal(initialBody.fortunes.emotional_flow.type, 'emotional_flow');
      assert.equal(initialBody.fortunes.relationship, undefined);

      await pair(server, first, second);
      const firstToday = await server.request('/relationship/fortune/today', { token: first.token });
      const secondToday = await server.request('/relationship/fortune/today', { token: second.token });
      const firstBody = await firstToday.json();
      const secondBody = await secondToday.json();
      assert.equal(firstToday.status, 200, JSON.stringify(firstBody));
      assert.equal(secondToday.status, 200, JSON.stringify(secondBody));
      assert.deepEqual(firstBody.fortunes.relationship.result, secondBody.fortunes.relationship.result);
      assert.equal(firstBody.fortunes.relationship.status, 'fallback');

      const regenerated = await server.request('/relationship/fortune/today/regenerate', {
        token: first.token,
        method: 'POST',
        body: { type: 'relationship' },
      });
      const regeneratedBody = await regenerated.json();
      assert.equal(regenerated.status, 201, JSON.stringify(regeneratedBody));
      const afterRegeneration = await server.request('/relationship/fortune/today', { token: second.token });
      const afterBody = await afterRegeneration.json();
      assert.deepEqual(
        regeneratedBody.fortunes.relationship.result,
        afterBody.fortunes.relationship.result,
      );
    } finally {
      await server.close();
    }
  },
);

test(
  'private counseling is owner-only while shared counseling and approved insights are couple-scoped',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const first = await createAndLogin(server, 'counsel-first');
      const second = await createAndLogin(server, 'counsel-second');
      await pair(server, first, second);

      const privateCreated = await server.request('/relationship/counseling/private/sessions', {
        token: first.token,
        method: 'POST',
        body: { title: '혼자 살펴볼 마음' },
      });
      const privateBody = await privateCreated.json();
      assert.equal(privateCreated.status, 201, JSON.stringify(privateBody));
      const privateId = privateBody.session.id;
      const privateMessage = await server.request(
        `/relationship/counseling/private/sessions/${privateId}/messages`,
        {
          token: first.token,
          method: 'POST',
          body: { content: '오늘은 혼자 남겨진 느낌이 크게 들었어.' },
        },
      );
      const privateMessageBody = await privateMessage.json();
      assert.equal(privateMessage.status, 201, JSON.stringify(privateMessageBody));
      assert.equal(privateMessageBody.messages.length, 2);
      assert.equal(privateMessageBody.messages[1].generationStatus, 'fallback');

      const partnerPrivateRead = await server.request(
        `/relationship/counseling/private/sessions/${privateId}`,
        { token: second.token },
      );
      assert.equal(partnerPrivateRead.status, 404);

      const insight = await server.request(
        `/relationship/counseling/private/sessions/${privateId}/insights`,
        {
          token: first.token,
          method: 'POST',
          body: { text: '혼자 있는 시간을 버려짐으로 해석하지 않도록 천천히 연습해보고 싶다.' },
        },
      );
      assert.equal(insight.status, 201, await insight.text());

      const sharedCreated = await server.request('/relationship/counseling/shared/sessions', {
        token: first.token,
        method: 'POST',
        body: { title: '우리의 대화' },
      });
      const sharedBody = await sharedCreated.json();
      assert.equal(sharedCreated.status, 201, JSON.stringify(sharedBody));
      const sharedId = sharedBody.session.id;
      const sharedMessage = await server.request(
        `/relationship/counseling/shared/sessions/${sharedId}/messages`,
        {
          token: second.token,
          method: 'POST',
          body: { content: '이번 주에 서로 편안하게 지내려면 무엇이 필요할까?' },
        },
      );
      assert.equal(sharedMessage.status, 201, await sharedMessage.text());
      const partnerSharedRead = await server.request(
        `/relationship/counseling/shared/sessions/${sharedId}`,
        { token: second.token },
      );
      const partnerSharedBody = await partnerSharedRead.json();
      assert.equal(partnerSharedRead.status, 200, JSON.stringify(partnerSharedBody));
      assert.equal(partnerSharedBody.messages[0].content, '이번 주에 서로 편안하게 지내려면 무엇이 필요할까?');
      assert.equal(partnerSharedBody.messages.some((message) => message.content.includes('버려짐')), false);

      const separated = await server.request('/user/partner', {
        token: first.token,
        method: 'DELETE',
      });
      assert.equal(separated.status, 200, await separated.text());
      const sharedAfterSeparation = await server.request(
        `/relationship/counseling/shared/sessions/${sharedId}`,
        { token: second.token },
      );
      assert.equal(sharedAfterSeparation.status, 404);
      const privateAfterSeparation = await server.request(
        `/relationship/counseling/private/sessions/${privateId}`,
        { token: first.token },
      );
      assert.equal(privateAfterSeparation.status, 200);
    } finally {
      await server.close();
    }
  },
);
