import assert from 'node:assert/strict';
import mysql from 'mysql2/promise';
import test from 'node:test';
import { businessDate } from '../src/business-date.js';
import { addDays } from '../src/modules/two-answers/domain.js';
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
  const login = await server.request('/auth/login', { method: 'POST', body: { email, password: 'password123' } });
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

const call = (server, user, path, method = 'GET', body) => server.request(path, { token: user.token, method, body });

test('데이트 계획: CRUD, Couple 격리, 핀 소유권, 삭제 정책', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  const db = await mysql.createConnection(server.environment.databaseUrl);
  try {
    const alice = await register(server, 'dp-alice');
    const bob = await register(server, 'dp-bob');
    const carol = await register(server, 'dp-carol');
    const dave = await register(server, 'dp-dave');
    const loner = await register(server, 'dp-loner');
    await pair(server, alice, bob);
    await pair(server, carol, dave);

    const today = businessDate();
    const tomorrow = addDays(today, 1);
    const pinResponse = await server.request('/map', {
      token: alice.token, method: 'POST', body: { place_name: 'Plan Cafe', status: 'wishlist', latitude: 37.123456, longitude: 127.654321 },
    });
    const pinBody = await pinResponse.json();
    const pinId = pinBody.id ?? pinBody.pin?.id;
    assert.ok(pinId, JSON.stringify(pinBody));
    const carolPinBody = await (await server.request('/map', {
      token: carol.token, method: 'POST', body: { place_name: 'Carol Cafe', status: 'wishlist' },
    })).json();
    const carolPinId = carolPinBody.id ?? carolPinBody.pin?.id;

    // 활성 Couple 없음 → 거부. client user_id 불일치 → 거부.
    assert.equal((await call(server, loner, '/date-plans')).status, 403);
    assert.equal((await call(server, alice, '/date-plans', 'POST', { plan_date: tomorrow, title: 'x', user_id: 99999 })).status, 403);
    assert.equal((await server.request('/date-plans')).status, 401);

    // 생성: 필수값·과거 날짜·남의 Couple 핀 거부.
    assert.equal((await call(server, alice, '/date-plans', 'POST', { plan_date: tomorrow })).status, 400);
    assert.equal((await call(server, alice, '/date-plans', 'POST', { plan_date: addDays(today, -1), title: '어제' })).status, 400);
    const foreign = await call(server, alice, '/date-plans', 'POST', { plan_date: tomorrow, title: '남의 핀', map_pin_id: carolPinId });
    assert.equal(foreign.status, 404);
    assert.equal((await foreign.json()).reason, 'map_pin_not_found');

    const created = await call(server, alice, '/date-plans', 'POST', {
      plan_date: tomorrow, plan_time: '18:30', title: '카페 가요', memo: '비 오면 실내', map_pin_id: pinId,
    });
    assert.equal(created.status, 201);
    const createdText = await created.text();
    const plan = JSON.parse(createdText).plan;
    assert.equal(plan.pin.title, 'Plan Cafe');
    assert.equal(plan.plan_time, '18:30');
    assert.equal(plan.mine, true);
    assert.ok(!/37\.1234|127\.6543|latitude|longitude/.test(createdText), 'coordinates leaked');

    // 파트너도 보고 수정할 수 있다(mine=false). 다른 Couple은 404.
    const bobView = await (await call(server, bob, `/date-plans/${plan.id}`)).json();
    assert.equal(bobView.plan.mine, false);
    assert.equal((await call(server, carol, `/date-plans/${plan.id}`)).status, 404);
    assert.equal((await call(server, carol, `/date-plans/${plan.id}`, 'PATCH', { title: 'hack' })).status, 404);
    assert.equal((await call(server, carol, `/date-plans/${plan.id}`, 'DELETE')).status, 404);
    assert.equal((await call(server, carol, `/date-plans/${plan.id}/complete`, 'POST')).status, 404);
    assert.deepEqual((await (await call(server, carol, '/date-plans')).json()).plans, []);

    const patched = await call(server, bob, `/date-plans/${plan.id}`, 'PATCH', { title: '카페 + 산책', plan_time: null });
    assert.equal(patched.status, 200);
    const patchedPlan = (await patched.json()).plan;
    assert.equal(patchedPlan.title, '카페 + 산책');
    assert.equal(patchedPlan.plan_time, null);
    assert.equal((await call(server, bob, `/date-plans/${plan.id}`, 'PATCH', { map_pin_id: carolPinId })).status, 404);
    assert.equal((await call(server, bob, `/date-plans/${plan.id}`, 'PATCH', {})).status, 400);

    // 삭제는 작성자만.
    const denied = await call(server, bob, `/date-plans/${plan.id}`, 'DELETE');
    assert.equal(denied.status, 403);
    assert.equal((await denied.json()).reason, 'plan_author_required');

    // 목록: 다가오는 것(시각 순) + 지난 것, 커서 페이지.
    const second = (await (await call(server, alice, '/date-plans', 'POST', { plan_date: tomorrow, plan_time: '09:00', title: '아침' })).json()).plan;
    const third = (await (await call(server, alice, '/date-plans', 'POST', { plan_date: addDays(today, 5), title: '나중' })).json()).plan;
    await db.query(
      'INSERT INTO date_plans (couple_id, created_by, plan_date, title) SELECT couple_id, created_by, ?, ? FROM date_plans WHERE id = ?',
      [addDays(today, -3), '지난 계획', plan.id],
    );
    const page1 = await (await call(server, alice, '/date-plans?scope=upcoming&limit=2')).json();
    assert.deepEqual(page1.plans.map((p) => p.id), [plan.id, second.id]);
    assert.ok(page1.next_cursor);
    const page2 = await (await call(server, alice, `/date-plans?scope=upcoming&limit=2&cursor=${encodeURIComponent(page1.next_cursor)}`)).json();
    assert.deepEqual(page2.plans.map((p) => p.id), [third.id]);
    assert.equal(page2.next_cursor, null);
    const past = await (await call(server, alice, '/date-plans?scope=past')).json();
    assert.deepEqual(past.plans.map((p) => p.title), ['지난 계획']);
    assert.equal((await call(server, alice, '/date-plans?scope=bogus')).status, 400);
    assert.equal((await call(server, alice, '/date-plans?cursor=zzz')).status, 400);

    // 미래 계획은 완료 불가.
    assert.equal((await call(server, alice, `/date-plans/${third.id}/complete`, 'POST')).status, 409);

    // 작성자 삭제.
    assert.equal((await call(server, alice, `/date-plans/${third.id}`, 'DELETE')).status, 200);
    assert.equal((await call(server, alice, `/date-plans/${third.id}`)).status, 404);

    // 비활성 Couple 거부.
    await db.query("UPDATE Couples SET Status = 'inactive' WHERE CoupleId = (SELECT CoupleId FROM (SELECT c.CoupleId FROM Couples c JOIN Users u ON u.UserId IN (c.User1Id, c.User2Id) WHERE u.UserCode = ?) t)", [dave.userCode]);
    assert.equal((await call(server, carol, '/date-plans')).status, 403);
    assert.equal((await call(server, dave, '/date-plans', 'POST', { plan_date: tomorrow, title: 'x' })).status, 403);
  } finally {
    await db.end();
    await server.close();
  }
});

test('데이트 계획: 다녀왔어요 → 기존 애프터글로우 방문으로 이어진다', { skip: !adminUrl || !redisUrl }, async () => {
  const server = await createApiTestServer({ adminUrl, redisUrl });
  const db = await mysql.createConnection(server.environment.databaseUrl);
  try {
    const alice = await register(server, 'dpc-alice');
    const bob = await register(server, 'dpc-bob');
    await pair(server, alice, bob);
    const today = businessDate();
    const pinBody = await (await server.request('/map', {
      token: alice.token, method: 'POST', body: { place_name: 'Glow Cafe', status: 'wishlist' },
    })).json();
    const pinId = pinBody.id ?? pinBody.pin?.id;

    const plan = (await (await call(server, alice, '/date-plans', 'POST', {
      plan_date: today, title: '오늘 가요', map_pin_id: pinId,
    })).json()).plan;
    assert.equal(plan.completed, false);
    assert.equal(plan.afterglow, null);

    const done = await call(server, bob, `/date-plans/${plan.id}/complete`, 'POST');
    assert.equal(done.status, 200);
    const doneBody = await done.json();
    assert.equal(doneBody.plan.completed, true);
    assert.deepEqual(doneBody.afterglow, { map_pin_id: pinId, state: 'needs_visit' });

    // 완료한 계획은 수정할 수 없고, 멱등하게 다시 완료할 수 있다.
    assert.equal((await call(server, alice, `/date-plans/${plan.id}`, 'PATCH', { title: 'x' })).status, 409);
    assert.equal((await call(server, alice, `/date-plans/${plan.id}/complete`, 'POST')).status, 200);

    // 기존 애프터글로우 API로 이어 붙인다(중복 구현 없음).
    const visit = await call(server, bob, `/retention/afterglow/${pinId}/visit`, 'POST');
    assert.equal(visit.status, 201);
    const view = await (await call(server, alice, `/retention/afterglow/pin/${pinId}`)).json();
    assert.ok(view.visit);
    const after = await (await call(server, alice, `/date-plans/${plan.id}`)).json();
    assert.deepEqual(after.plan.afterglow, { map_pin_id: pinId, state: 'recorded' });

    // 지난 계획 목록에 완료된 계획이 들어간다.
    const past = await (await call(server, alice, '/date-plans?scope=past')).json();
    assert.deepEqual(past.plans.map((p) => p.id), [plan.id]);
    assert.deepEqual((await (await call(server, alice, '/date-plans?scope=upcoming')).json()).plans, []);

    // 핀 없는 계획은 애프터글로우 없이 완료된다.
    const plain = (await (await call(server, alice, '/date-plans', 'POST', { plan_date: today, title: '산책' })).json()).plan;
    const plainDone = await (await call(server, alice, `/date-plans/${plain.id}/complete`, 'POST')).json();
    assert.equal(plainDone.afterglow, null);
  } finally {
    await db.end();
    await server.close();
  }
});
