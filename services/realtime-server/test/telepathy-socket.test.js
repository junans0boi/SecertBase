// 텔레파시 2.0 소켓 회귀: 서버가 로비 시작 때 판을 만들고, 동시 선택·15초 마감·연속 시간 초과
// 종료·재접속 sync·재대결(지난 판 답이 섞이지 않음)·방 시리즈를 확인한다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import { TELEPATHY_BAG_TTL_SEC, TELEPATHY_REVEAL_MS, TELEPATHY_TURN_MS } from '../src/games/telepathy.js';

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
  await start(t, f, { rounds: 5, spicy: 'on' });
  const s = states[1].at(-1);
  assert.equal(s.status, 'playing');
  assert.equal(s.gameType, 'telepathy');
  assert.equal(s.round, 1);
  assert.equal(s.rounds, 5);
  assert.equal(s.spicy, true);
  assert.deepEqual(s.players, [A, B]);
  assert.ok(s.gameId);
  assert.ok(s.question.a && s.question.b && s.question.emojiA && s.question.id);
  assert.deepEqual(s.picked, { [A]: false, [B]: false });
  assert.equal(s.score, 0);
  assert.equal(s.turnMs, TELEPATHY_TURN_MS);
  assert.equal(typeof s.serverNow, 'number');
  assert.ok(s.turnDeadline >= NOW + 5300 + TELEPATHY_TURN_MS, 'the first deadline counts after the lobby countdown');
  assert.equal(s.series.games, 0);
  assert.equal('questions' in s, false, 'future questions stay on the server');
  assert.equal('picks' in s, false);

  const bag = f.redis.values.get(`telepathy:${f.roomCode}:bag`);
  assert.ok(bag, 'the room bag is stored');
  assert.ok(bag.expiresAt - Date.now() >= (TELEPATHY_BAG_TTL_SEC - 1) * 1000, 'the bag is kept for a year');
  assert.equal(JSON.parse(bag.value).order.length, 315);
});

test('telepathy: defaults are 10 questions without spicy ones and bad picks are rejected', async (t) => {
  const f = await fixture(t);
  const states = collect(f);
  await start(t, f);
  assert.equal(states[0].at(-1).rounds, 10);
  assert.equal(states[0].at(-1).spicy, false);
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
  await start(t, f, { rounds: 5, spicy: 'on' });
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
  assert.equal(fresh.spicy, true);
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
