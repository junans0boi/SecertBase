import assert from 'node:assert/strict';
import test from 'node:test';
import { fixture, flush } from './support/socket-harness.js';
import pirate from '../src/games/pirate.js';
import { PIRATE_TURN_MS } from '../src/pirate-engine.js';

const ALPHA = 'ALPHA-code';
const BETA = 'BETA-code';
const NOW = 1_000_000;
const LOBBY_COUNTDOWN_MS = 5300;

// 난수 순서: [선공, 폭탄 위치, (자동 찌르기)...]
function useRandom(t, values) {
  let i = 0;
  const original = pirate.random;
  pirate.random = () => values[Math.min(i++, values.length - 1)];
  t.after(() => { pirate.random = original; });
}

function record(f, event) {
  const seen = [[], []];
  f.clients.forEach((c, i) => c.on(event, (data) => seen[i].push(data)));
  return seen;
}

async function startFromLobby(f, holes) {
  assert.equal((await f.call(0, 'game:lobby:join', { gameType: 'pirate' })).ok, true);
  assert.equal((await f.call(1, 'game:lobby:join', { gameType: 'pirate' })).ok, true);
  if (holes) assert.equal((await f.call(0, 'game:lobby:set_option', { gameType: 'pirate', key: 'holes', value: holes })).ok, true);
  assert.equal((await f.call(0, 'game:lobby:start', { gameType: 'pirate' })).ok, true);
  await flush();
  return JSON.parse(await f.redis.get(`pirate:${f.roomCode}:game`));
}

test('lobby start creates the game with lobby holes, random first player and a server deadline', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.9, 0.5]);
  const states = record(f, 'game:pirate:state');
  const s = await startFromLobby(f, 12);
  assert.equal(s.slots, 12);
  assert.equal(s.firstTurn, BETA, 'first player comes from the injected random, not the couple order');
  assert.equal(s.currentTurn, BETA);
  assert.equal(s.bombSlot, 6);
  assert.equal(s.phase, 'playing');
  assert.equal(s.turnDeadline, NOW + LOBBY_COUNTDOWN_MS + PIRATE_TURN_MS);
  assert.ok(s.gameId);
  for (const seen of states) {
    assert.equal(seen.length, 1);
    assert.equal(seen[0].bombSlot, null, 'the bomb stays hidden');
    assert.equal(seen[0].riskPct, 8);
    assert.equal(seen[0].remaining, 12);
    assert.equal(seen[0].serverNow, NOW);
    assert.equal(seen[0].gameId, s.gameId);
  }
});

test('default lobby option is 8 holes and old start/reset events no longer exist', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.1, 0.5]);
  const s = await startFromLobby(f);
  assert.equal(s.slots, 8);
  assert.equal(s.firstTurn, ALPHA);
  await assert.rejects(f.clients[0].timeout(300).emitWithAck('game:pirate:start', { slots: 8 }), 'in-game start was removed');
  await assert.rejects(f.clients[0].timeout(300).emitWithAck('game:pirate:reset', {}), 'host-only reset was removed');
});

test('sync returns the current state to the asking player and null without a game', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  assert.deepEqual(await f.call(0, 'game:pirate:sync', {}), { ok: true, state: null });
  useRandom(t, [0.1, 0.5]);
  await startFromLobby(f, 6);
  const synced = await f.call(1, 'game:pirate:sync', {});
  assert.equal(synced.state.slots, 6);
  assert.equal(synced.state.currentTurn, ALPHA);
  assert.equal(synced.state.bombSlot, null);
});

test('picks alternate, carry remaining and riskPct, and the bomb keeps the exploded state', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.1, 0.99]); // ALPHA first, bomb at 7 of 8
  const picked = record(f, 'game:pirate:slot_picked');
  const exploded = record(f, 'game:pirate:exploded');
  const s = await startFromLobby(f, 8);
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 0 })).reason, 'not_your_turn');
  assert.equal((await f.call(0, 'game:pirate:pick', { slot: 8 })).reason, 'invalid_slot');
  assert.equal((await f.call(0, 'game:pirate:pick', { slot: 'x' })).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:pirate:pick', { slot: 0, gameId: 'old' })).reason, 'stale_game');
  assert.deepEqual(await f.call(0, 'game:pirate:pick', { slot: 0, gameId: s.gameId }), { ok: true, exploded: false });
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 0 })).reason, 'slot_taken');
  await flush();
  assert.equal(picked[1][0].slot, 0);
  assert.equal(picked[1][0].by, ALPHA);
  assert.equal(picked[1][0].nextTurn, BETA);
  assert.equal(picked[1][0].remaining, 7);
  assert.equal(picked[1][0].riskPct, 14);
  assert.equal(picked[1][0].auto, false);
  for (let slot = 1; slot <= 5; slot++) {
    const who = slot % 2 === 1 ? 1 : 0;
    assert.equal((await f.call(who, 'game:pirate:pick', { slot })).ok, true);
  }
  await flush();
  assert.equal(picked[0].at(-1).remaining, 2);
  assert.equal(picked[0].at(-1).riskPct, 50);
  // 일곱 번째 찌르기는 ALPHA 차례. 남은 6·7 중 7이 폭탄.
  assert.deepEqual(await f.call(0, 'game:pirate:pick', { slot: 7 }), { ok: true, exploded: true });
  await flush();
  const e = exploded[1][0];
  assert.equal(e.loser, ALPHA);
  assert.equal(e.winner, BETA);
  assert.equal(e.bombSlot, 7);
  assert.equal(e.gameId, s.gameId);
  assert.equal(e.reason, 'bomb');
  assert.deepEqual(e.series.wins, { [ALPHA]: 0, [BETA]: 1 });
  const kept = JSON.parse(await f.redis.get(`pirate:${f.roomCode}:game`));
  assert.equal(kept.phase, 'exploded', 'the state is preserved for the penalty phase');
  assert.equal(kept.loser, ALPHA);
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 6 })).reason, 'not_playing');
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][1], 'pirate');
  assert.equal(f.results[0][2], BETA);
  assert.equal(f.results[0][7], s.gameId, 'the outcome is recorded with the gameId');
});

async function explodedGame(t, f) {
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.1, 0]); // ALPHA first, bomb at 0
  const s = await startFromLobby(f, 6);
  assert.equal((await f.call(0, 'game:pirate:pick', { slot: 0 })).exploded, true);
  await flush();
  return s; // ALPHA lost, BETA won
}

test('only the winner picks the penalty once, trimmed to 1..30 characters, then the loser completes it', async t => {
  const f = await fixture(t);
  const penalties = record(f, 'game:pirate:penalty');
  const dones = record(f, 'game:pirate:penalty_done');
  const states = record(f, 'game:pirate:state');
  const s = await explodedGame(t, f);
  assert.equal((await f.call(0, 'game:pirate:penalty', { text: '딱밤 한 대' })).reason, 'not_winner');
  assert.equal((await f.call(1, 'game:pirate:penalty', { text: '    ' })).reason, 'penalty_empty');
  assert.equal((await f.call(1, 'game:pirate:penalty', { text: '가'.repeat(31) })).reason, 'penalty_too_long');
  assert.equal((await f.call(1, 'game:pirate:penalty', {})).reason, 'invalid_payload');
  assert.equal((await f.call(0, 'game:pirate:penalty_done', {})).reason, 'no_penalty');
  assert.deepEqual(await f.call(1, 'game:pirate:penalty', { text: '  아이스크림 사기 ' }), { ok: true, text: '아이스크림 사기' });
  assert.equal((await f.call(1, 'game:pirate:penalty', { text: '다른 벌칙' })).reason, 'penalty_already_set');
  await flush();
  assert.deepEqual(penalties[0][0], { gameId: s.gameId, by: BETA, text: '아이스크림 사기' });
  assert.equal(states[0].at(-1).penalty.text, '아이스크림 사기');
  assert.equal((await f.call(1, 'game:pirate:penalty_done', {})).reason, 'not_loser');
  assert.deepEqual(await f.call(0, 'game:pirate:penalty_done', {}), { ok: true });
  assert.equal((await f.call(0, 'game:pirate:penalty_done', {})).reason, 'penalty_already_done');
  await flush();
  assert.deepEqual(dones[1][0], { gameId: s.gameId, by: ALPHA });
  assert.equal(states[1].at(-1).penalty.doneAt, NOW);
});

test('restore brings back the exploded game with its penalty phase', async t => {
  const f = await fixture(t);
  await explodedGame(t, f);
  await f.call(1, 'game:pirate:penalty', { text: '애교 한 번' });
  const states = record(f, 'game:pirate:state');
  const restored = await f.call(0, 'session:restore', {});
  assert.equal(restored.ok, true);
  await flush();
  assert.equal(states[1].length, 0, 'only the reconnecting socket gets the state');
  const view = states[0].at(-1);
  assert.equal(view.phase, 'exploded');
  assert.equal(view.loser, ALPHA);
  assert.equal(view.bombSlot, 0);
  assert.equal(view.penalty.text, '애교 한 번');
  assert.equal(view.series.wins[BETA], 1);
});

test('consented restart keeps holes and series, alternates the first player and makes a new gameId', async t => {
  const f = await fixture(t);
  const first = await explodedGame(t, f);
  assert.equal((await f.call(0, 'game:restart:request', { gameType: 'pirate' })).ok, true);
  assert.equal((await f.call(1, 'game:restart:respond', { gameType: 'pirate', accept: true })).accepted, true);
  await flush();
  const second = JSON.parse(await f.redis.get(`pirate:${f.roomCode}:game`));
  assert.equal(second.slots, 6);
  assert.notEqual(second.gameId, first.gameId);
  assert.equal(second.firstTurn, BETA, 'rematch alternates the first player');
  assert.equal(second.phase, 'playing');
  assert.equal(second.penalty, null);
  assert.equal(second.round, 2);
  // 두 번째 판: 폭탄 0번(난수 0), BETA가 찔러서 진다 → 전적 1:1.
  const exploded = record(f, 'game:pirate:exploded');
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 0 })).exploded, true);
  await flush();
  assert.deepEqual(exploded[0][0].series.wins, { [ALPHA]: 1, [BETA]: 1 });
  assert.equal(exploded[0][0].series.games, 2);
  assert.equal(f.results.length, 2);
  assert.notEqual(f.results[0][7], f.results[1][7]);
});

test('a timed-out turn auto-stabs a free slot and three timeouts in a row forfeit', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.1, 0.99, 0, 0, 0]); // ALPHA first, bomb 11 of 12; auto picks the lowest free slot
  const picked = record(f, 'game:pirate:slot_picked');
  const exploded = record(f, 'game:pirate:exploded');
  await startFromLobby(f, 12);
  f.tick(LOBBY_COUNTDOWN_MS + PIRATE_TURN_MS - 1);
  await flush();
  assert.equal(picked[0].length, 0, 'nothing happens before the deadline');
  f.tick(1);
  await flush();
  assert.equal(picked[0].length, 1);
  assert.equal(picked[0][0].auto, true);
  assert.equal(picked[0][0].by, ALPHA);
  assert.equal(picked[0][0].slot, 0);
  assert.equal(picked[0][0].turnDeadline, Date.now() + PIRATE_TURN_MS);
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 1 })).ok, true);
  f.tick(PIRATE_TURN_MS);
  await flush();
  assert.equal(picked[0].at(-1).slot, 2);
  assert.equal(picked[0].at(-1).auto, true);
  assert.equal((await f.call(1, 'game:pirate:pick', { slot: 3 })).ok, true);
  f.tick(PIRATE_TURN_MS);
  await flush();
  assert.equal(exploded[0].length, 1);
  assert.equal(exploded[0][0].loser, ALPHA);
  assert.equal(exploded[0][0].reason, 'timeout');
  assert.equal(exploded[0][0].forfeit, true);
  assert.equal(f.results.length, 1);
  assert.equal(f.results[0][2], BETA);
});

test('a manual stab cancels the pending auto-stab of that turn', async t => {
  const f = await fixture(t);
  t.mock.timers.enable({ apis: ['Date'], now: NOW });
  useRandom(t, [0.1, 0.99, 0]);
  const picked = record(f, 'game:pirate:slot_picked');
  await startFromLobby(f, 8);
  f.tick(LOBBY_COUNTDOWN_MS + 5000);
  assert.equal((await f.call(0, 'game:pirate:pick', { slot: 4 })).ok, true);
  f.tick(PIRATE_TURN_MS - 5000);
  await flush();
  assert.equal(picked[0].length, 1, 'the old deadline must not fire for the new turn');
  f.tick(5000);
  await flush();
  assert.equal(picked[0].length, 2);
  assert.equal(picked[0][1].by, BETA);
  assert.equal(picked[0][1].auto, true);
});

test('afk adapter waits only on the playing turn and its forfeit ends the game once', async () => {
  const values = new Map();
  const emitted = [];
  const outcomes = [];
  const kit = {
    redis: { get: async (k) => values.get(k) ?? null, set: async (k, v) => { values.set(k, v); return 'OK'; } },
    io: { to: () => ({ emit: (event, data) => emitted.push([event, data]) }) },
    series: { get: async () => null, record: async () => ({ wins: { [ALPHA]: 0, [BETA]: 1 }, draws: 0, games: 1 }) },
    recordGameOutcome: async (_room, outcome) => { outcomes.push(outcome); },
    timerApi: { setTimeout: () => ({}), clearTimeout: () => {} },
  };
  const adapter = pirate.afk(kit);
  const state = { gameId: 'g', slots: 6, bombSlot: 3, pickedSlots: [], stabs: [], players: [ALPHA, BETA], firstTurn: ALPHA, currentTurn: ALPHA, phase: 'playing', timeouts: {}, seq: 0 };
  assert.equal(adapter.key('R'), 'pirate:R:game');
  assert.equal(adapter.waitingOn(state), ALPHA);
  assert.equal(adapter.waitingOn({ ...state, phase: 'exploded' }), null);
  await adapter.forfeit('R', state, ALPHA, BETA);
  const kept = JSON.parse(values.get('pirate:R:game'));
  assert.equal(kept.phase, 'exploded');
  assert.equal(kept.reason, 'afk');
  assert.equal(kept.winner, BETA);
  assert.deepEqual(outcomes, [{ winner: BETA, players: [ALPHA, BETA], gameType: 'pirate', gameId: 'g' }]);
  assert.equal(emitted.find(([e]) => e === 'game:pirate:exploded')[1].forfeit, true);
});
