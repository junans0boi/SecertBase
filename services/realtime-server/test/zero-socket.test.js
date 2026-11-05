// 제로 2.0 소켓 회귀: 로비 시작 → 제출 → 공개 → 5라운드 합산 → 서든데스 → 재대결 → 복원,
// 범위 밖 예측 거부, 라운드 시간 초과 자동 선택과 연속 3회 기권.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import { ZERO_REVEAL_MS, ZERO_TURN_MS, setZeroRandom } from '../src/games/zero.js';

const A = 'ALPHA-code';
const B = 'BETA-code';

function collect(f) {
  const states = [[], []];
  const reveals = [[], []];
  f.clients.forEach((c, i) => {
    c.on('game:zero:state', (s) => states[i].push(s));
    c.on('game:zero:round_result', (r) => reveals[i].push(r));
  });
  return { states, reveals };
}

async function startZero(t, f) {
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'zero' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'zero' })).ok, true);
  const started = await f.call(0, 'game:lobby:start', { gameType: 'zero' });
  assert.equal(started.ok, true, `start rejected: ${started.reason}`);
  await flush();
}

async function playRound(f, pickA, pickB) {
  const a = await f.call(0, 'game:zero:pick', pickA);
  assert.equal(a.ok, true, `A pick rejected: ${a.reason}`);
  const b = await f.call(1, 'game:zero:pick', pickB);
  assert.equal(b.ok, true, `B pick rejected: ${b.reason}`);
  await flush();
}

test('zero: the lobby start creates the game and sync returns the masked state', async (t) => {
  const f = await fixture(t);
  const { states } = collect(f);
  await startZero(t, f);
  const first = states[1].at(-1);
  assert.equal(first.status, 'playing');
  assert.equal(first.round, 1);
  assert.equal(first.maxRounds, 5);
  assert.equal(first.suddenDeath, false);
  assert.deepEqual(first.players, [A, B]);
  assert.deepEqual(first.scores, { [A]: 0, [B]: 0 });
  assert.ok(first.gameId, 'gameId comes from the lobby');
  assert.equal(typeof first.serverNow, 'number');
  assert.ok(first.turnDeadline >= 1_000_000 + 5300 + ZERO_TURN_MS, 'first deadline counts after the lobby countdown');
  assert.deepEqual(first.series.wins, { [A]: 0, [B]: 0 });

  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 3, guess: 5, round: 1 })).ok, true);
  await flush();
  const seen = states[1].at(-1);
  assert.deepEqual(seen.submitted, { [A]: true, [B]: false });
  assert.equal(seen.myPick, undefined, 'the opponent never sees the pick');
  assert.equal(JSON.stringify(seen).includes('"guess":5'), false);

  const sync = await f.call(0, 'game:zero:sync', {});
  assert.equal(sync.ok, true);
  assert.deepEqual(sync.state.myPick, { fingers: 3, guess: 5 });
  const other = await f.call(1, 'game:zero:sync', {});
  assert.equal(other.state.myPick, undefined);
});

test('zero: guesses outside [fingers, fingers+5] are rejected with invalid_guess', async (t) => {
  const f = await fixture(t);
  await startZero(t, f);
  const low = await f.call(0, 'game:zero:pick', { fingers: 3, guess: 2 });
  assert.deepEqual(low, { ok: false, reason: 'invalid_guess', range: { min: 3, max: 8 } });
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 3, guess: 9 })).reason, 'invalid_guess');
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 6, guess: 6 })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 2, guess: 4, round: 3 })).reason, 'stale_round');
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 3, guess: 8 })).ok, true);
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 0, guess: 0 })).already, true, 'a second pick does not overwrite');
});

test('zero: reveal shows the sum and points, five rounds are summed and the result is recorded', async (t) => {
  const f = await fixture(t);
  const { states, reveals } = collect(f);
  await startZero(t, f);
  const gameId = states[0].at(-1).gameId;

  await playRound(f, { fingers: 3, guess: 5 }, { fingers: 2, guess: 6 });
  const r1 = reveals[1].at(-1);
  assert.equal(r1.round, 1);
  assert.equal(r1.total, 5);
  assert.deepEqual(r1.fingers, { [A]: 3, [B]: 2 });
  assert.deepEqual(r1.guesses, { [A]: 5, [B]: 6 });
  assert.deepEqual(r1.points, { [A]: 2, [B]: 0 });
  assert.deepEqual(r1.exact, { [A]: true, [B]: false });
  assert.deepEqual(r1.distance, { [A]: 0, [B]: 1 });
  assert.equal(r1.roundWinner, A);
  assert.equal(r1.maxRounds, 5);
  assert.equal(r1.suddenDeath, false);
  assert.equal(r1.gameWinner, null);
  assert.equal(r1.gameId, gameId);
  const after1 = states[0].at(-1);
  assert.equal(after1.round, 2);
  assert.deepEqual(after1.scores, { [A]: 2, [B]: 0 });
  assert.equal(after1.lastRound.total, 5);
  assert.equal(after1.turnDeadline, after1.revealUntil + ZERO_TURN_MS, 'the reveal does not eat the next round');
  assert.equal(after1.revealUntil - r1.serverNow, ZERO_REVEAL_MS);

  await playRound(f, { fingers: 1, guess: 3 }, { fingers: 4, guess: 9 }); // A closer +1
  await playRound(f, { fingers: 2, guess: 3 }, { fingers: 2, guess: 5 }); // same distance
  await playRound(f, { fingers: 1, guess: 4 }, { fingers: 3, guess: 4 }); // both exact
  assert.equal(f.results.length, 0);
  await playRound(f, { fingers: 0, guess: 5 }, { fingers: 4, guess: 4 }); // B exact
  const last = reveals[0].at(-1);
  assert.equal(last.round, 5);
  assert.deepEqual(last.scores, { [A]: 5, [B]: 4 });
  assert.equal(last.gameWinner, A);
  assert.equal(last.result.reason, 'score');
  assert.deepEqual(last.series.wins, { [A]: 1, [B]: 0 });
  const final = states[1].at(-1);
  assert.equal(final.status, 'finished');
  assert.equal(final.result.winner, A);
  assert.equal(final.history.length, 5);
  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 1, guess: 1 })).reason, 'game_over');

  await flush();
  assert.equal(f.results.length, 1, 'outcome recorded once');
  assert.equal(f.results[0][1], 'zero');
  assert.equal(f.results[0][2], A);
  assert.equal(f.results[0].at(-1), gameId, 'recorded with the lobby gameId');
});

test('zero: a tie after five rounds plays sudden death until a round is decided', async (t) => {
  const f = await fixture(t);
  const { states, reveals } = collect(f);
  await startZero(t, f);
  for (let i = 0; i < 5; i++) await playRound(f, { fingers: 2, guess: 3 }, { fingers: 2, guess: 5 });
  const tied = states[0].at(-1);
  assert.equal(tied.status, 'playing');
  assert.equal(tied.suddenDeath, true);
  assert.equal(tied.round, 6);
  assert.equal(reveals[0].at(-1).nextSuddenDeath, true);

  await playRound(f, { fingers: 1, guess: 4 }, { fingers: 3, guess: 4 }); // both exact: still tied
  assert.equal(states[0].at(-1).status, 'playing');
  assert.equal(states[0].at(-1).suddenDeathRounds, 1);
  await playRound(f, { fingers: 1, guess: 3 }, { fingers: 1, guess: 2 }); // B exact
  const end = reveals[1].at(-1);
  assert.equal(end.suddenDeath, true);
  assert.equal(end.gameWinner, B);
  assert.equal(end.result.reason, 'sudden_death');
  assert.equal(states[1].at(-1).status, 'finished');
});

test('zero: a round timeout auto-picks and three auto-picks in a row forfeit', async (t) => {
  const f = await fixture(t);
  const { states, reveals } = collect(f);
  setZeroRandom(() => 0.5);
  t.after(() => setZeroRandom());
  await startZero(t, f);
  const s0 = states[0].at(-1);

  assert.equal((await f.call(0, 'game:zero:pick', { fingers: 2, guess: 4 })).ok, true);
  f.tick(s0.turnDeadline - Date.now() - 1);
  await flush();
  assert.equal(reveals[0].length, 0, 'not before the deadline');
  f.tick(1);
  await flush();
  const r1 = reveals[0].at(-1);
  assert.equal(r1.round, 1);
  assert.deepEqual(r1.auto, { [A]: false, [B]: true });
  assert.deepEqual(r1.fingers, { [A]: 2, [B]: 3 }, 'auto pick uses the injected random');
  assert.equal(states[0].at(-1).autoPicks[B], 1);

  for (let round = 2; round <= 3; round++) {
    assert.equal((await f.call(0, 'game:zero:pick', { fingers: 2, guess: 4 })).ok, true);
    f.tick(states[0].at(-1).turnDeadline - Date.now());
    await flush();
  }
  const end = states[0].at(-1);
  assert.equal(end.status, 'finished');
  assert.equal(end.result.winner, A);
  assert.equal(end.result.loser, B);
  assert.equal(end.result.reason, 'forfeit');
  await flush();
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][2], A);
});

test('zero: a consented rematch starts a fresh game and keeps the series', async (t) => {
  const f = await fixture(t);
  const { states } = collect(f);
  await startZero(t, f);
  const firstId = states[0].at(-1).gameId;
  for (let i = 0; i < 5; i++) await playRound(f, { fingers: 1, guess: 3 }, { fingers: 2, guess: 6 });
  assert.equal(states[0].at(-1).result.winner, A);

  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'zero' })).ok, true);
  const accepted = await f.call(0, 'game:restart:respond', { accept: true, gameType: 'zero' });
  assert.equal(accepted.ok, true, `rematch rejected: ${accepted.reason}`);
  await flush();
  const fresh = states[1].at(-1);
  assert.equal(fresh.status, 'playing');
  assert.equal(fresh.round, 1);
  assert.notEqual(fresh.gameId, firstId);
  assert.deepEqual(fresh.scores, { [A]: 0, [B]: 0 });
  assert.deepEqual(fresh.series.wins, { [A]: 1, [B]: 0 }, 'series carries over');
  assert.equal(fresh.history.length, 0);
});

test('zero: session restore resends the running game with the viewer\'s own pick', async (t) => {
  const f = await fixture(t);
  const { states } = collect(f);
  await startZero(t, f);
  await playRound(f, { fingers: 3, guess: 5 }, { fingers: 2, guess: 6 });
  await f.call(1, 'game:zero:pick', { fingers: 4, guess: 7 });
  const before = states[1].length;
  const restored = await f.call(1, 'session:restore', {});
  assert.equal(restored.ok, true);
  assert.ok(restored.restored.includes('zero'));
  await flush();
  const view = states[1].at(-1);
  assert.ok(states[1].length > before);
  assert.equal(view.round, 2);
  assert.deepEqual(view.scores, { [A]: 2, [B]: 0 });
  assert.deepEqual(view.myPick, { fingers: 4, guess: 7 });
  assert.equal(view.history.length, 1);
  assert.equal(view.suddenDeath, false);
});

test('classic rps no longer accepts the old hanabagi mode', async (t) => {
  const f = await fixture(t);
  assert.equal((await f.call(0, 'game:rps:start', { mode: 'hanabagi' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:rps:start', { mode: 'rps3' })).ok, true);
});
