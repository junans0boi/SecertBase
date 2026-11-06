// 텔레파시 2.0 소켓 회귀: 서버가 로비 시작 때 판을 만들고, 동시 선택·15초 마감·연속 시간 초과
// 종료·재접속 sync·재대결(지난 판 답이 섞이지 않음)·방 시리즈를 확인한다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { boundary, fixture, flush } from './support/socket-harness.js';
import { TELEPATHY_BANK } from '../src/telepathy-engine.js';
import {
  TELEPATHY_BAG_TTL_SEC,
  TELEPATHY_FIRST_EXTRA_MS,
  TELEPATHY_REVEAL_MS,
  TELEPATHY_TURN_MS,
} from '../src/games/telepathy.js';

const A = 'ALPHA-code';
const B = 'BETA-code';
const NOW = 1_000_000;

function collect(f) {
  const states = [[], []];
  f.clients.forEach((c, i) => c.on('game:telepathy:state', (s) => states[i].push(s)));
  return states;
}

async function start(t, f, options = {}) {
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'telepathy' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'telepathy' })).ok, true);
  for (const [key, value] of Object.entries(options)) {
    const set = await f.call(0, 'game:lobby:set_option', { gameType: 'telepathy', key, value });
    assert.equal(set.ok, true, `option ${key} rejected: ${set.reason}`);
  }
  const started = await f.call(0, 'game:lobby:start', { gameType: 'telepathy' });
  assert.equal(started.ok, true, `start rejected: ${started.reason}`);
  await flush();
}

async function both(f, a, b) {
  const ra = await f.call(0, 'game:telepathy:pick', { choice: a });
  assert.equal(ra.ok, true, `A pick rejected: ${ra.reason}`);
  const rb = await f.call(1, 'game:telepathy:pick', { choice: b });
  assert.equal(rb.ok, true, `B pick rejected: ${rb.reason}`);
  await flush();
}

test('telepathy: the lobby start builds the game from server options without a start button', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5, heat: 'spicy' });
  const s = states[1].at(-1);
  assert.equal(s.status, 'playing');
  assert.equal(s.gameType, 'telepathy');
  assert.equal(s.round, 1);
  assert.equal(s.rounds, 5);
  assert.equal(s.heat, 'spicy');
  assert.deepEqual(s.players, [A, B]);
  assert.ok(s.gameId);
  assert.ok(s.question.a && s.question.b && s.question.emojiA && s.question.id);
  assert.deepEqual(s.picked, { [A]: false, [B]: false });
  assert.equal(s.score, 0);
  assert.equal(s.turnMs, TELEPATHY_TURN_MS + TELEPATHY_FIRST_EXTRA_MS, 'first question window');
  assert.equal(typeof s.serverNow, 'number');
  assert.ok(s.turnDeadline >= NOW + 5300 + TELEPATHY_TURN_MS, 'the first deadline counts after the lobby countdown');
  assert.equal(s.series.games, 0);
  assert.equal('questions' in s, false, 'future questions stay on the server');
  assert.equal('picks' in s, false);

  const bag = f.redis.values.get(`telepathy:${f.roomCode}:bag`);
  assert.ok(bag, 'the room bag is stored');
  assert.ok(bag.expiresAt - Date.now() >= (TELEPATHY_BAG_TTL_SEC - 1) * 1000, 'the bag is kept for a year');
  assert.equal(JSON.parse(bag.value).order.length, TELEPATHY_BANK.length - 5);
});

test('telepathy: defaults are 10 questions without spicy ones and bad picks are rejected', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  assert.equal(states[0].at(-1).rounds, 10);
  assert.equal(states[0].at(-1).heat, 'mild');
  assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'telepathy', key: 'rounds', value: 7 })).reason, 'lobby_not_found');
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'C' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'A', round: '1' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'A', round: 3 })).reason, 'stale_round');
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'A', round: 1 })).ok, true);
  const again = await f.call(0, 'game:telepathy:pick', { choice: 'B', round: 1 });
  assert.deepEqual(again, { ok: true, already: true, round: 1, choice: 'A' }, 'a second pick never overwrites');
});

test('telepathy: picks stay secret until both chose, then both are revealed together', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  const q1 = states[0].at(-1).question;
  assert.deepEqual(await f.call(0, 'game:telepathy:pick', { choice: 'B', round: 1 }), { ok: true, round: 1, choice: 'B' });
  await flush();
  const mid = states[1].at(-1);
  assert.deepEqual(mid.picked, { [A]: true, [B]: false }, 'the partner sees "골랐어요" only');
  assert.equal(mid.myPick, undefined);
  assert.equal(mid.history.length, 0);
  assert.equal((await f.call(0, 'game:telepathy:sync', {})).state.myPick, 'B');
  assert.equal((await f.call(1, 'game:telepathy:sync', {})).state.myPick, undefined);

  assert.equal((await f.call(1, 'game:telepathy:pick', { choice: 'B', round: 1 })).ok, true);
  await flush();
  const after = states[0].at(-1);
  assert.equal(after.round, 2);
  assert.equal(after.score, 1);
  assert.equal(after.streak, 1);
  assert.deepEqual(after.lastRound.picks, { [A]: 'B', [B]: 'B' });
  assert.equal(after.lastRound.matched, true);
  assert.equal(after.lastRound.outcome, 'match');
  assert.deepEqual(after.lastRound.question, q1);
  assert.notEqual(after.question.id, q1.id);
  assert.equal(after.revealUntil - after.serverNow, TELEPATHY_REVEAL_MS);
  assert.equal(after.turnDeadline, after.revealUntil + TELEPATHY_TURN_MS, 'the reveal does not eat the next question');
});

test('telepathy: simultaneous picks resolve the question exactly once', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  const [a, b] = await Promise.all([
    f.call(0, 'game:telepathy:pick', { choice: 'A', round: 1 }),
    f.call(1, 'game:telepathy:pick', { choice: 'B', round: 1 }),
  ]);
  assert.equal(a.ok && b.ok, true);
  await flush();
  const s = states[0].at(-1);
  assert.equal(s.history.length, 1);
  assert.equal(s.round, 2);
  assert.equal(s.lastRound.outcome, 'miss');
  assert.equal(s.score, 0);
  assert.equal(states[0].filter((x) => x.history.length === 1 && x.round === 2).length >= 1, true);
  assert.equal(new Set(states[0].map((x) => x.history.length)).size, 2, 'never two resolutions');
});

test('telepathy: at 15 seconds a missing pick is a timeout miss and the next question starts', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  const first = states[0].at(-1);
  await f.call(0, 'game:telepathy:pick', { choice: 'A', round: 1 });
  f.tick(first.turnDeadline - Date.now() - 1);
  await flush();
  assert.equal(states[0].at(-1).round, 1, 'not yet');
  f.tick(1);
  await flush();
  const s = states[0].at(-1);
  assert.equal(s.round, 2);
  assert.deepEqual(s.lastRound.picks, { [A]: 'A', [B]: null });
  assert.equal(s.lastRound.outcome, 'timeout');
  assert.equal(s.lastRound.matched, false);
  assert.deepEqual(s.timeouts, { [A]: 0, [B]: 1 });
  assert.equal(s.turnDeadline, Date.now() + TELEPATHY_REVEAL_MS + TELEPATHY_TURN_MS);
});

test('telepathy: three questions in a row with nobody choosing end the game', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  for (let i = 0; i < 3; i++) {
    f.tick(states[0].at(-1).turnDeadline - Date.now());
    await flush();
  }
  const s = states[1].at(-1);
  assert.equal(s.status, 'finished');
  assert.equal(s.result.reason, 'both_away');
  assert.equal(s.result.played, 3);
  assert.equal(s.question, null);
  assert.equal(s.turnDeadline, null);
  assert.equal(s.series.games, 0, 'an abandoned game is not added to the series');
  assert.equal(f.results.length, 0, 'telepathy records no win, loss or draw');
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'A' })).reason, 'game_over');
});

test('telepathy: one player missing three in a row ends the game as away', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  for (let i = 0; i < 3; i++) {
    await f.call(0, 'game:telepathy:pick', { choice: 'A' });
    f.tick(states[0].at(-1).turnDeadline - Date.now());
    await flush();
  }
  const s = states[0].at(-1);
  assert.equal(s.status, 'finished');
  assert.equal(s.result.reason, 'away');
  assert.equal(s.result.awayPlayer, B);
});

test('telepathy: a full game ends with the score, best streak, tier and the room series', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5 });
  const plan = [['A', 'A'], ['B', 'B'], ['A', 'B'], ['B', 'B'], ['A', 'A']];
  for (const [a, b] of plan) await both(f, a, b);
  const s = states[1].at(-1);
  assert.equal(s.status, 'finished');
  assert.deepEqual(s.result, {
    reason: 'complete', awayPlayer: null, matches: 4, total: 5, played: 5, bestStreak: 2,
    tier: { id: 'eyes', label: '눈빛만 봐도' },
  });
  assert.equal(s.history.length, 5);
  assert.ok(s.history.every((h) => h.question?.a && h.picks[A] && h.picks[B]), 'recap has both picks per question');
  assert.equal(s.series.games, 1);
  assert.equal(s.series.ratio, 80);
  assert.equal(s.series.bestStreak, 2);
  assert.equal(f.results.length, 0, 'no game outcome is recorded');
});

test('telepathy: a rematch keeps the settings and series, draws new questions and ignores old picks', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5, heat: 'spicy' });
  const firstId = states[0].at(-1).gameId;
  for (let i = 0; i < 5; i++) await both(f, 'A', 'A');
  const firstQuestions = states[0].at(-1).history.map((h) => h.question.id);

  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'telepathy' })).ok, true);
  const accepted = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'telepathy' });
  assert.equal(accepted.ok, true, `rematch rejected: ${accepted.reason}`);
  await flush();
  const fresh = states[1].at(-1);
  assert.equal(fresh.status, 'playing');
  assert.notEqual(fresh.gameId, firstId);
  assert.equal(fresh.rounds, 5);
  assert.equal(fresh.heat, 'spicy');
  assert.equal(fresh.round, 1);
  assert.equal(fresh.score, 0);
  assert.equal(fresh.history.length, 0);
  assert.equal(fresh.series.games, 1);
  assert.equal(fresh.series.bestStreak, 5);
  assert.ok(!firstQuestions.includes(fresh.question.id), 'the bag never repeats the last game');

  const stale = await f.call(0, 'game:telepathy:pick', { choice: 'A', round: 1, gameId: firstId });
  assert.deepEqual(stale, { ok: false, reason: 'stale_game', gameId: fresh.gameId });
  assert.deepEqual(states[1].at(-1).picked, { [A]: false, [B]: false }, 'a pick from the last game never leaks in');
});

test('telepathy: reconnect sync and session restore resend the running game with my own pick', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  await both(f, 'A', 'B');
  await f.call(1, 'game:telepathy:pick', { choice: 'B', round: 2 });
  const restored = await f.call(1, 'session:restore', {});
  assert.equal(restored.ok, true);
  assert.ok(restored.restored.includes('telepathy'));
  await flush();
  const view = states[1].at(-1);
  assert.equal(view.round, 2);
  assert.equal(view.myPick, 'B');
  assert.equal(view.history.length, 1);
  assert.deepEqual(view.picked, { [A]: false, [B]: true });
  const sync = await f.call(1, 'game:telepathy:sync', {});
  assert.equal(sync.state.myPick, 'B');
  assert.equal(sync.state.question.id, view.question.id);
});

test('telepathy: the old select event is gone', async (t) => {
  const f = await fixture(t);
  await start(t, f);
  await assert.rejects(
    f.clients[0].timeout(300).emitWithAck('game:telepathy:select', { choice: 'tea', options: ['tea', 'coffee'] }),
  );
});

test('telepathy: the first question gets extra time so a new player can read the rules, and the ring says so', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  const first = states[0].at(-1);
  const total = TELEPATHY_TURN_MS + TELEPATHY_FIRST_EXTRA_MS;
  assert.equal(first.turnMs, total, 'turnMs matches the real window so the ring starts full');
  assert.equal(first.turnDeadline, NOW + 5300 + total);
  assert.equal(first.turnDeadline - first.serverNow, 5300 + total);
  // 15초가 지나도 1번 문제는 그대로, 규칙을 읽고 나서 고를 수 있다.
  f.tick(5300 + TELEPATHY_TURN_MS + 1000);
  await flush();
  assert.equal(states[0].at(-1).round, 1);
  assert.equal((await f.call(0, 'game:telepathy:pick', { choice: 'A', round: 1 })).ok, true);
  // 늦게라도 안 고르면 마감에 넘어간다.
  f.tick(first.turnDeadline - Date.now());
  await flush();
  const s = states[1].at(-1);
  assert.equal(s.round, 2);
  assert.equal(s.lastRound.outcome, 'timeout');
  assert.equal(s.turnMs, TELEPATHY_TURN_MS, 'later questions are back to 15 seconds');
  assert.equal(s.turnDeadline - s.revealUntil, TELEPATHY_TURN_MS);
});

test('telepathy: a rematch does not get the extra first-question time', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5 });
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'telepathy' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { accept: true, gameType: 'telepathy' })).ok, true);
  await flush();
  const fresh = states[0].at(-1);
  assert.equal(fresh.turnMs, TELEPATHY_TURN_MS);
});

test('telepathy: both pressing the rematch button at once starts one new game for both', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5 });
  const firstId = states[0].at(-1).gameId;
  const started = [[], []];
  const requested = [[], []];
  f.clients.forEach((c, i) => {
    c.on('game:restart:started', (e) => started[i].push(e));
    c.on('game:restart:requested', (e) => requested[i].push(e));
  });
  const [a, b] = await Promise.all([
    f.call(0, 'game:restart:request', { gameType: 'telepathy' }),
    f.call(1, 'game:restart:request', { gameType: 'telepathy' }),
  ]);
  await flush();
  assert.equal(a.ok && b.ok, true);
  assert.equal([a, b].filter((r) => r.started).length, 1, 'the second request completes the agreement');
  const fresh = states[0].at(-1);
  assert.notEqual(fresh.gameId, firstId);
  assert.equal(states[1].at(-1).gameId, fresh.gameId);
  assert.deepEqual(started[0], [{ gameType: 'telepathy' }]);
  assert.deepEqual(started[1], [{ gameType: 'telepathy' }]);
  // 먼저 처리된 요청의 알림은 갔을 수 있지만, 판이 시작된 뒤에는 수락할 요청이 남지 않는다.
  const stale = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'telepathy' });
  assert.equal(stale.reason, 'no_restart_request');
  assert.equal(states[0].filter((x) => x.gameId === fresh.gameId && x.round === 1).length, 1, 'only one new game');
});

test('telepathy: a request and the partner request later still counts as agreement', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f, { rounds: 5 });
  const firstId = states[0].at(-1).gameId;
  assert.deepEqual(await f.call(0, 'game:restart:request', { gameType: 'telepathy' }), { ok: true });
  const second = await f.call(1, 'game:restart:request', { gameType: 'telepathy' });
  assert.deepEqual(second, { ok: true, started: true });
  await flush();
  assert.notEqual(states[0].at(-1).gameId, firstId);
  // 같은 사람이 두 번 눌러도 합의가 되지는 않는다.
  assert.deepEqual(await f.call(0, 'game:restart:request', { gameType: 'telepathy' }), { ok: true });
  assert.deepEqual(await f.call(0, 'game:restart:request', { gameType: 'telepathy' }), { ok: true });
});

async function lobby(t, f, ages) {
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  boundary.ages = ages;
  t.after(() => { boundary.ages = undefined; });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'telepathy' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'telepathy' })).ok, true);
}

const setHeat = (f, value) => f.call(0, 'game:lobby:set_option', { gameType: 'telepathy', key: 'heat', value });

test('telepathy 19+: the guest must accept before the host can start, then the game uses only 19+ and spicy questions', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await lobby(t, f);
  assert.equal((await setHeat(f, 'nuclear')).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'telepathy' })).reason, 'partner_not_ready');
  assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'telepathy', ready: true })).ok, true);
  // 방장이 수위를 다른 값으로 바꿨다가 되돌리면 동의가 풀린다.
  assert.equal((await setHeat(f, 'spicy')).ok, true);
  assert.equal((await setHeat(f, 'nuclear')).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'telepathy' })).reason, 'partner_not_ready');
  assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'telepathy', ready: true })).ok, true);
  const started = await f.call(0, 'game:lobby:start', { gameType: 'telepathy' });
  assert.equal(started.ok, true, `start rejected: ${started.reason}`);
  await flush();
  const s = states[1].at(-1);
  assert.equal(s.heat, 'nuclear');
  assert.equal(s.question.heat, 'nuclear', 'a 19+ game is all hard questions');
  assert.equal('tone' in s.question, false, 'the tone is data for grouping, never sent to the players');
  assert.ok(f.redis.values.get(`telepathy:${f.roomCode}:bag:nuclear`), 'the 19+ pool has its own bag');
  assert.equal(f.redis.values.get(`telepathy:${f.roomCode}:bag`), undefined, 'the mild bag is untouched');
});

test('telepathy 19+: mild and spicy never need the guest to accept', async (t) => {
  const f = await fixture(t);
  await lobby(t, f);
  for (const heat of ['spicy', 'mild']) {
    assert.equal((await setHeat(f, heat)).ok, true);
  }
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'telepathy' })).ok, true);
});

for (const ages of [{ [B]: 17 }, { [A]: 18 }, { [B]: null }]) {
  test(`telepathy 19+: someone under 19, or with no birth year, blocks the level on the server ${JSON.stringify(ages)}`, async (t) => {
    const f = await fixture(t);
    await lobby(t, f, ages);
    const set = await setHeat(f, 'nuclear');
    assert.deepEqual(set, { ok: false, reason: 'adult_only' }, JSON.stringify(ages));
    // 19세(연 나이)는 통과.
    boundary.ages = { [A]: 19, [B]: 19 };
    assert.equal((await setHeat(f, 'nuclear')).ok, true);
    assert.equal((await f.call(1, 'game:lobby:ready', { gameType: 'telepathy', ready: true })).ok, true);
    boundary.ages = ages;
    assert.deepEqual(await f.call(0, 'game:lobby:start', { gameType: 'telepathy' }), { ok: false, reason: 'adult_only' });
    assert.equal(f.redis.values.get(`game:${f.roomCode}:telepathy`), undefined, 'no game was created');
  });
}

test('telepathy 19+: a rematch keeps the level and checks the ages again', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await lobby(t, f);
  await setHeat(f, 'nuclear');
  await f.call(1, 'game:lobby:ready', { gameType: 'telepathy', ready: true });
  await f.call(0, 'game:lobby:start', { gameType: 'telepathy' });
  await flush();
  const firstId = states[0].at(-1).gameId;
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'telepathy' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { accept: true, gameType: 'telepathy' })).ok, true);
  await flush();
  const fresh = states[0].at(-1);
  assert.notEqual(fresh.gameId, firstId);
  assert.equal(fresh.heat, 'nuclear');
  boundary.ages = { [B]: 16 };
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'telepathy' })).ok, true);
  const refused = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'telepathy' });
  assert.equal(refused.reason, 'adult_only');
  assert.equal(states[0].at(-1).gameId, fresh.gameId, 'the old game stays');
});
