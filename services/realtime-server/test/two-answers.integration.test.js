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
  assert.equal(response.status, 200);
  const login = await server.request('/auth/login', { method: 'POST', body: { email, password: 'password123' } });
  const session = await login.json();
  return { token: session.token, userCode: registered.userCode };
};

const pair = async (server, sender, recipient) => {
  const request = await server.request('/pairing/requests', {
    token: sender.token,
    method: 'POST',
    body: { recipientCode: recipient.userCode },
  });
  const { requestId } = await request.json();
  const accepted = await server.request(`/pairing/requests/${requestId}/accept`, {
    token: recipient.token,
    method: 'POST',
  });
  assert.equal(accepted.status, 200);
};

const answer = (server, who, body, extra = {}) => server.request('/two-answers/today/answer', {
  token: who.token,
  method: 'PUT',
  body: { body, ...extra },
});

test(
  '마주 열기 hides the partner answer until both answer and isolates couples',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    const db = await mysql.createConnection(server.environment.databaseUrl);
    try {
      const alice = await register(server, 'ta-alice');
      const bob = await register(server, 'ta-bob');
      const carol = await register(server, 'ta-carol');
      const dave = await register(server, 'ta-dave');
      await pair(server, alice, bob);
      await pair(server, carol, dave);

      // 같은 날 두 사람은 같은 질문을 본다.
      const aToday = (await (await server.request('/two-answers/today', { token: alice.token })).json()).today;
      const bToday = (await (await server.request('/two-answers/today', { token: bob.token })).json()).today;
      assert.equal(aToday.id, bToday.id);
      assert.equal(aToday.question, bToday.question);
      assert.equal(aToday.business_date, businessDate());
      assert.equal(aToday.status, 'my_turn');
      assert.equal(aToday.partner_answered, false);
      assert.equal(aToday.streak, 0);

      // 질문은 하루에 한 행만 존재한다(중복 질문 방지).
      await Promise.all([
        server.request('/two-answers/today', { token: alice.token }),
        server.request('/two-answers/today', { token: bob.token }),
      ]);
      const [rows] = await db.query('SELECT COUNT(*) AS n FROM two_answers WHERE business_date = ?', [businessDate()]);
      assert.equal(rows[0].n, 1); // Alice·Bob이 각각 두 번 조회해도 Couple당 하루 1행

      // 한쪽만 답하면 상대 본문은 어떤 응답에도 나오지 않는다.
      const secret = '비밀스러운-앨리스-답변-ZXQ';
      const first = await answer(server, alice, secret);
      const firstText = await first.text();
      assert.equal(first.status, 200);
      assert.equal(JSON.parse(firstText).today.partner_answer, null);

      const bobView = await server.request('/two-answers/today', { token: bob.token });
      const bobText = await bobView.text();
      assert.ok(!bobText.includes(secret), 'partner body leaked before both answered');
      const bobBody = JSON.parse(bobText).today;
      assert.equal(bobBody.status, 'my_turn');
      assert.equal(bobBody.partner_answered, true);
      assert.equal(bobBody.partner_answer, null);

      const aliceView = await (await server.request('/two-answers/today', { token: alice.token })).json();
      assert.equal(aliceView.today.status, 'waiting');
      assert.equal(aliceView.today.my_answer.body, secret);

      // 공개 전에는 수정할 수 있다.
      const edited = await answer(server, alice, `${secret}-수정`);
      assert.equal((await edited.json()).today.my_answer.body, `${secret}-수정`);

      // 히스토리에도 아직 나오지 않는다.
      const earlyHistory = await (await server.request('/two-answers/history', { token: bob.token })).text();
      assert.ok(!earlyHistory.includes('ZXQ'));

      // 길이 상한 500자.
      const tooLong = await answer(server, bob, '가'.repeat(501));
      assert.equal(tooLong.status, 400);
      assert.equal((await tooLong.json()).reason, 'answer_too_long');

      // 둘 다 답하면 공개된다.
      const second = await answer(server, bob, '밥의 답변');
      const opened = (await second.json()).today;
      assert.equal(opened.status, 'open');
      assert.equal(opened.partner_answer.body, `${secret}-수정`);
      assert.equal(opened.streak, 1);
      const aliceOpen = (await (await server.request('/two-answers/today', { token: alice.token })).json()).today;
      assert.equal(aliceOpen.status, 'open');
      assert.equal(aliceOpen.partner_answer.body, '밥의 답변');

      // 공개 후 수정은 거부된다.
      const locked = await answer(server, alice, '바꾸기');
      assert.equal(locked.status, 409);

      // 히스토리에는 둘 다 답한 카드만 나온다.
      const history = await (await server.request('/two-answers/history', { token: alice.token })).json();
      assert.equal(history.items.length, 1);
      assert.equal(history.items[0].partner_answer.body, '밥의 답변');
      assert.equal(history.next_cursor, null);

      // 다른 Couple은 접근할 수 없고 자신의 질문만 본다.
      const carolHistory = await (await server.request('/two-answers/history', { token: carol.token })).json();
      assert.deepEqual(carolHistory.items, []);
      const carolLate = await server.request(`/two-answers/${aToday.id}/answer-late`, {
        token: carol.token,
        method: 'POST',
        body: { body: '침입' },
      });
      assert.equal(carolLate.status, 404);
      const carolToday = (await (await server.request('/two-answers/today', { token: carol.token })).json()).today;
      assert.notEqual(carolToday.id, aToday.id);
      assert.equal(carolToday.partner_answered, false);

      // 인증 없음 → 401, 클라이언트 user_id 불일치 → 거부.
      assert.equal((await server.request('/two-answers/today')).status, 401);
      const spoofQuery = await server.request('/two-answers/today?user_id=99999', { token: alice.token });
      assert.equal(spoofQuery.status, 403);
      assert.equal((await spoofQuery.json()).error.code, 'CLIENT_SCOPE_OVERRIDE');
      const spoofBody = await answer(server, alice, 'x', { user_id: 99999 });
      assert.equal(spoofBody.status, 403);

      // 늦게 답하기: 과거 질문에 벌점 없이 답한다.
      const past = addDays(businessDate(), -3);
      const [[aliceCouple]] = await db.query(
        `SELECT c.CoupleId FROM Couples c JOIN Users u ON u.UserId IN (c.User1Id, c.User2Id)
         WHERE u.UserCode = ?`,
        [alice.userCode],
      );
      const [inserted] = await db.query(
        `INSERT INTO two_answers (couple_id, business_date, question_id, category, question_text)
         VALUES (?, ?, 'daily-01', 'daily', '놓친 질문')`,
        [aliceCouple.CoupleId, past],
      );
      const pastId = inserted.insertId;
      const missed = await (await server.request('/two-answers/missed', { token: alice.token })).json();
      assert.deepEqual(missed.items.map((item) => item.id), [pastId]);
      const lateA = await server.request(`/two-answers/${pastId}/answer-late`, {
        token: alice.token, method: 'POST', body: { body: '늦은 앨리스' },
      });
      assert.equal(lateA.status, 200);
      const lateBobPeek = await (await server.request('/two-answers/missed', { token: bob.token })).text();
      assert.ok(!lateBobPeek.includes('늦은 앨리스'));
      const lateB = await server.request(`/two-answers/${pastId}/answer-late`, {
        token: bob.token, method: 'POST', body: { body: '늦은 밥' },
      });
      const lateBody = (await lateB.json()).question;
      assert.equal(lateBody.status, 'open');
      assert.equal(lateBody.partner_answer.body, '늦은 앨리스');
      // 오늘 질문은 늦게 답하기로 열 수 없다.
      const lateToday = await server.request(`/two-answers/${aToday.id}/answer-late`, {
        token: carol.token, method: 'POST', body: { body: 'x' },
      });
      assert.equal(lateToday.status, 404);

      // 스트릭은 오늘 연속만 센다(3일 전 완료는 끊긴 상태).
      const streak = (await (await server.request('/two-answers/today', { token: alice.token })).json()).today.streak;
      assert.equal(streak, 1);
    } finally {
      await db.end();
      await server.close();
    }
  },
);

test(
  '마주 열기 rejects an inactive Couple and references pins by title only',
  { skip: !adminUrl || !redisUrl },
  async () => {
    const server = await createApiTestServer({ adminUrl, redisUrl });
    const db = await mysql.createConnection(server.environment.databaseUrl);
    try {
      const erin = await register(server, 'ta-erin');
      const finn = await register(server, 'ta-finn');
      await pair(server, erin, finn);
      const [[couple]] = await db.query('SELECT CoupleId FROM Couples LIMIT 1');

      // 핀 제목만 질문에 들어가고 좌표는 들어가지 않는다.
      await db.query(
        `INSERT INTO map_pins (couple_id, place_name, latitude, longitude, created_by)
         VALUES (?, '골목 책방', 37.12345678, 127.87654321, 'ta-erin')`,
        [couple.CoupleId],
      );
      let sawPin = false;
      for (let offset = 0; offset < 40 && !sawPin; offset += 1) {
        const date = addDays(businessDate(), -offset - 1);
        // 과거 날짜별 질문을 서비스 선택 규칙으로 직접 채워 넣는다.
        const { selectQuestion } = await import('../src/modules/two-answers/domain.js');
        const picked = selectQuestion({ coupleId: couple.CoupleId, date, pinTitles: ['골목 책방'] });
        assert.doesNotMatch(picked.text, /37\.1|127\.8/);
        if (picked.text.includes('골목 책방')) sawPin = true;
      }
      assert.ok(sawPin);
      const today = (await (await server.request('/two-answers/today', { token: erin.token })).json()).today;
      assert.doesNotMatch(today.question, /37\.1|127\.8|latitude/);

      // 비활성 Couple은 접근할 수 없다.
      await db.query("UPDATE Couples SET Status = 'inactive' WHERE CoupleId = ?", [couple.CoupleId]);
      for (const [path, method, body] of [
        ['/two-answers/today', 'GET'],
        ['/two-answers/today/answer', 'PUT', { body: 'x' }],
        ['/two-answers/history', 'GET'],
        ['/two-answers/missed', 'GET'],
      ]) {
        const response = await server.request(path, { token: erin.token, method, body });
        assert.equal(response.status, 403, path);
        assert.equal((await response.json()).reason, 'active_couple_required');
      }
    } finally {
      await db.end();
      await server.close();
    }
  },
);
