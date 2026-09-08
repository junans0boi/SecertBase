import assert from 'node:assert/strict';
import test from 'node:test';
import { createApiTestServer } from './api-test-server.js';

const adminUrl = process.env.TEST_DATABASE_ADMIN_URL;
const redisUrl = process.env.TEST_REDIS_URL;

const createUser = async (server, name) => {
  const email = `${name}-${Date.now()}@couple-assessment.test`;
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
  assert.equal(registered.status, 200, await registered.text());
  const userCode = (await registered.json()).userCode;
  const loggedIn = await server.request('/auth/login', {
    method: 'POST',
    body: { email, password: 'password123' },
  });
  const body = await loggedIn.json();
  assert.equal(loggedIn.status, 200, JSON.stringify(body));
  return { token: body.token, userCode };
};

const pair = async (server, sender, recipient) => {
  const created = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const createdBody = await created.json();
  assert.equal(created.status, 201, JSON.stringify(createdBody));
  const accepted = await server.request(
    `/pairing/requests/${createdBody.requestId}/accept`,
    { token: recipient.token, method: 'POST' },
  );
  const acceptedBody = await accepted.json();
  assert.equal(accepted.status, 200, JSON.stringify(acceptedBody));
  return acceptedBody;
};

test(
  'couple assessment attempts share couple scope but keep answers author-only',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    try {
      const alice = await createUser(server, 'couple-attempt-alice');
      const bob = await createUser(server, 'couple-attempt-bob');
      const pairing = await pair(server, alice, bob);

      const aliceStart = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: alice.token, method: 'POST' },
      );
      const aliceBody = await aliceStart.json();
      assert.equal(aliceStart.status, 201, JSON.stringify(aliceBody));
      assert.equal(aliceBody.attempt.audience, 'couple');
      assert.equal(aliceBody.attempt.coupleId, pairing.coupleId);
      assert.deepEqual(aliceBody.attempt.answers, []);

      const bobStart = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: bob.token, method: 'POST' },
      );
      const bobBody = await bobStart.json();
      assert.equal(bobStart.status, 201, JSON.stringify(bobBody));
      assert.equal(bobBody.attempt.coupleId, aliceBody.attempt.coupleId);
      assert.notEqual(bobBody.attempt.id, aliceBody.attempt.id);

      const resumed = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: alice.token, method: 'POST' },
      );
      const resumedBody = await resumed.json();
      assert.equal(resumed.status, 200, JSON.stringify(resumedBody));
      assert.equal(resumedBody.attempt.id, aliceBody.attempt.id);

      const aliceSaved = await server.request(
        `/relationship/assessment-attempts/${aliceBody.attempt.id}/answers/q01`,
        { token: alice.token, method: 'PATCH', body: { value: 5 } },
      );
      assert.equal(aliceSaved.status, 200, await aliceSaved.text());

      const bobSaved = await server.request(
        `/relationship/assessment-attempts/${bobBody.attempt.id}/answers/q01`,
        { token: bob.token, method: 'PATCH', body: { value: 2 } },
      );
      assert.equal(bobSaved.status, 200, await bobSaved.text());

      const aliceCurrent = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: alice.token },
      );
      const aliceCurrentBody = await aliceCurrent.json();
      assert.equal(aliceCurrentBody.attempt.answers[0].value, 5);

      const bobCurrent = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: bob.token },
      );
      const bobCurrentBody = await bobCurrent.json();
      assert.equal(bobCurrentBody.attempt.answers[0].value, 2);

      const partnerWrite = await server.request(
        `/relationship/assessment-attempts/${aliceBody.attempt.id}/answers/q02`,
        { token: bob.token, method: 'PATCH', body: { value: 4 } },
      );
      assert.equal(partnerWrite.status, 404);
      assert.equal((await partnerWrite.json()).reason, 'attempt_not_found');

      const personalPath = await server.request(
        '/relationship/assessments/conflict_repair/attempt',
        { token: alice.token, method: 'POST' },
      );
      assert.equal(personalPath.status, 400);
      assert.equal((await personalPath.json()).reason, 'assessment_not_personal');

      const separated = await server.request('/user/partner', {
        token: alice.token,
        method: 'DELETE',
      });
      assert.equal(separated.status, 200, await separated.text());

      const blocked = await server.request(
        '/relationship/couple-assessments/conflict_repair/attempt',
        { token: alice.token, method: 'POST' },
      );
      assert.equal(blocked.status, 409);
      assert.equal((await blocked.json()).reason, 'active_couple_required');
    } finally {
      await server.close();
    }
  },
);
