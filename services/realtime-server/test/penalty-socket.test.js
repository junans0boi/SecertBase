// 패널티킥 2.0 소켓 회귀: 로비 시작·제출·판정·20초 타이머·기권·재대결·복원·옛 형식 정리.
import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush, getUserLevel } from './support/socket-harness.js';
import penalty from '../src/games/penalty.js';
import { PENALTY_REVEAL_MS, PENALTY_TURN_MS, initPenaltyGame, resolvePenaltyRound } from '../src/penalty-engine.js';

const A = 'ALPHA-code';
const B = 'BETA-code';
const key = (f) => `game:${f.roomCode}:penalty`;
const stored = async (f) => JSON.parse(await f.redis.get(key(f)));

function useRandom(t, value) {
  const original = penalty.random;
  penalty.random = () => value;
  t.after(() => { penalty.random = original; });
}

function collect(f, index) {
  const seen = [];
  f.clients[index].on('game:penalty:state', (s) => seen.push(s));
  return seen;
}

async function startFromLobby(f, cells) {
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'penalty' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'penalty' })).ok, true);
  if (cells) assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'penalty', key: 'cells', value: cells })).ok, true);
  const started = new Promise((resolve) => f.clients[1].once('game:lobby:started', resolve));
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'penalty' })).ok, true);
  const event = await started;
  await flush();
  return event;
}

test('penalty: lobby start creates the game with the lobby cells, a random first kicker and a 20 s deadline', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
  useRandom(t, 0.9);
  const seen = collect(f, 1);
  const started = await startFromLobby(f, 6);
  assert.equal(started.metadata.serverStart, true, 'the client must not send a start event');
  await flush();
  const state = seen.at(-1);
  assert.equal(state.cells, 6);
  assert.equal(state.status, 'playing');
  assert.equal(state.kicker, B, 'random() = 0.9 picks the second player');
  assert.equal(state.keeper, A);
  assert.equal(state.serverNow, 1_000_000);
  assert.equal(state.turnDeadline, 1_000_000 + 5_300 + PENALTY_TURN_MS, 'countdown + 20 s');
  assert.ok(state.gameId);
  assert.deepEqual(state.series.wins, { [A]: 0, [B]: 0 });
  // 화면이 열리며 보내는 sync는 같은 상태를 돌려준다.
  const sync = await f.call(0, 'game:penalty:sync', {});
  assert.equal(sync.ok, true);
  assert.equal(sync.state.gameId, state.gameId);
});

test('penalty: a game without a lobby option has 3 cells and the choice range follows cells', async (t) => {
  const f = await fixture(t);
  useRandom(t, 0.1);
  const seen = collect(f, 1);
  await startFromLobby(f);
  assert.equal((await stored(f)).cells, 3);
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 3 })).reason, 'invalid_choice');
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: -1 })).reason, 'invalid_choice');
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: '1' })).reason, 'invalid_choice');
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 2 })).ok, true);
  await flush();
  const pending = seen.at(-1);
  assert.deepEqual(pending.submissions, { [A]: true }, 'the opponent only sees that I submitted');
  assert.equal(JSON.stringify(pending).includes('"choice"'), false);
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 1 })).reason, 'already_submitted');
  const resolved = await f.call(1, 'game:penalty:submit', { choice: 0 });
  assert.equal(resolved.ok, true);
  assert.equal(resolved.resolved, true);
  await flush();
  const after = seen.at(-1);
  assert.equal(after.round, 2);
  assert.equal(after.kicker, B, 'kicker and keeper swap');
  assert.deepEqual(after.rounds[0], { round: 1, kicker: A, keeper: B, kickerDir: 2, keeperDir: 0, isGoal: true, autoKicker: false, autoKeeper: false });
  assert.deepEqual(after.scores, { [A]: 1, [B]: 0 });
});

test('penalty: the 20 s timer auto picks, three in a row forfeit, the result is recorded once with gameId', async (t) => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: 2_000_000 });
  useRandom(t, 0.1);
  const seen = collect(f, 0);
  await startFromLobby(f, 6);
  const { gameId } = await stored(f);
  // 1킥: A(키커)만 고르고 B는 잠수.
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 5 })).ok, true);
  f.tick(5_300 + PENALTY_TURN_MS - 1);
  await flush();
  assert.equal((await stored(f)).round, 1, 'not before the deadline');
  f.tick(1);
  await flush();
  let state = seen.at(-1);
  assert.equal(state.round, 2);
  assert.equal(state.rounds[0].autoKeeper, true);
  assert.equal(state.rounds[0].autoKicker, false);
  assert.equal(state.rounds[0].keeperDir, 0, 'random 0.1 → cell 0');
  assert.equal(state.autoPicks[B], 1);
  // 2킥도 B는 잠수.
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 4 })).ok, true);
  f.tick(PENALTY_REVEAL_MS + PENALTY_TURN_MS);
  await flush();
  assert.equal(seen.at(-1).round, 3);
  assert.equal(seen.at(-1).autoPicks[B], 2);
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 4 })).ok, true);
  f.tick(PENALTY_REVEAL_MS + PENALTY_TURN_MS);
  await flush();
  state = seen.at(-1);
  assert.equal(state.status, 'finished');
  assert.equal(state.result.winner, A);
  assert.equal(state.result.reason, 'forfeit');
  assert.equal(state.series.wins[A], 1);
  assert.deepEqual(f.results, [[1, 'penalty', A, B, 0, A, B, gameId]]);
  assert.equal((await f.call(1, 'game:penalty:submit', { choice: 0 })).reason, 'finished');
});

test('penalty completion grants winner/loser XP once through its socket handler', async (t) => {
  const f = await fixture(t);
  let g = initPenaltyGame(A, B, { random: () => 0, gameId: 'game-xp' });
  g = resolvePenaltyRound(g, 0, 1); // A 골
  for (let i = 0; i < 8; i++) g = resolvePenaltyRound(g, 0, 0); // 선방 8번 → 1:0, 10번째 킥은 B
  assert.equal(g.kicker, B);
  await f.redis.set(key(f), JSON.stringify(g));
  await f.call(0, 'game:penalty:submit', { choice: 1 });
  assert.equal((await f.call(1, 'game:penalty:submit', { choice: 1 })).ok, true);
  await flush();
  assert.equal((await getUserLevel(11)).xp, 50);
  assert.equal((await getUserLevel(22)).xp, 20);
  assert.deepEqual(f.results, [[1, 'penalty', A, B, 0, A, B, 'game-xp']]);
  assert.equal((await f.call(1, 'game:penalty:submit', { choice: 1 })).ok, false);
  assert.equal((await getUserLevel(11)).xp, 50);
});

test('penalty: consent rematch keeps the cells and series and swaps the first kicker', async (t) => {
  const f = await fixture(t);
  useRandom(t, 0.1);
  await startFromLobby(f, 6);
  const first = await stored(f);
  assert.equal(first.firstKicker, A);
  // 판을 끝낸다(9킥 뒤 A 1:0 승).
  let g = first;
  g = resolvePenaltyRound(g, 0, 1);
  for (let i = 0; i < 8; i++) g = resolvePenaltyRound(g, 0, 0);
  await f.redis.set(key(f), JSON.stringify(g));
  await f.call(0, 'game:penalty:submit', { choice: 1 });
  await f.call(1, 'game:penalty:submit', { choice: 1 });
  await flush();
  assert.equal((await stored(f)).status, 'finished');

  const seen = collect(f, 1);
  assert.equal((await f.call(1, 'game:restart:request', { gameType: 'penalty' })).ok, true);
  assert.equal((await f.call(0, 'game:restart:respond', { gameType: 'penalty', accept: true })).accepted, true);
  await flush();
  const next = seen.at(-1);
  assert.equal(next.status, 'playing');
  assert.equal(next.cells, 6);
  assert.equal(next.firstKicker, B, 'the other player kicks first');
  assert.notEqual(next.gameId, first.gameId);
  assert.equal(next.series.games, 1);
  assert.equal(next.series.wins[A], 1);
  assert.deepEqual(next.rounds, []);
});

test('penalty: session restore re-sends the running game; old 9-cell states are dropped', async (t) => {
  const f = await fixture(t);
  useRandom(t, 0.1);
  await startFromLobby(f);
  const seen = collect(f, 1);
  const restored = await f.call(1, 'session:restore', {});
  assert.equal(restored.ok, true);
  assert.ok(restored.restored.includes('penalty'));
  await flush();
  assert.equal(seen.at(-1).cells, 3);

  await f.redis.set(key(f), JSON.stringify({
    status: 'playing', round: 2, kicker: B, keeper: A, submissions: { [A]: 7 },
    scores: { [A]: 1, [B]: 0 }, rounds: [{ kicker: A, keeper: B, kickerDir: 8, keeperDir: 4, isGoal: true }], result: null,
  }));
  const again = await f.call(1, 'session:restore', {});
  assert.equal(again.restored.includes('penalty'), false);
  assert.equal(await f.redis.get(key(f)), null, 'the legacy state is cleaned up');
  assert.deepEqual(await f.call(0, 'game:penalty:sync', {}), { ok: true, state: null });
  assert.equal((await f.call(0, 'game:penalty:submit', { choice: 0 })).reason, 'no_game');
});

test('penalty: the old start event is gone', async (t) => {
  const f = await fixture(t);
  await assert.rejects(f.call(0, 'game:penalty:start', {}), 'no handler acks the legacy start event');
  assert.equal(await f.redis.get(key(f)), null);
});
