import assert from 'node:assert/strict';
import test from 'node:test';
import {
  PIRATE_HOLES,
  PIRATE_MAX_TIMEOUTS,
  PIRATE_PENALTY_PRESETS,
  PIRATE_TURN_MS,
  applyForfeit,
  applyStab,
  applyTimeout,
  completePenalty,
  createPirateGame,
  firstPlayerLossProbability,
  freeSlots,
  nextFirstTurn,
  normalizeHoles,
  normalizePenaltyText,
  publicPirateState,
  riskPct,
  setPenalty,
} from '../src/pirate-engine.js';

const players = ['A', 'B'];
const seq = (...values) => { let i = 0; return () => values[i++ % values.length]; };
// 결정적 난수(mulberry32).
function seeded(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

test('first player comes from the injected random, not the couple order', () => {
  assert.equal(createPirateGame({ players, random: seq(0.1, 0) }).firstTurn, 'A');
  assert.equal(createPirateGame({ players, random: seq(0.9, 0) }).firstTurn, 'B');
  const g = createPirateGame({ players, random: seq(0.9, 0.99), holes: 8 });
  assert.equal(g.currentTurn, 'B');
  assert.equal(g.bombSlot, 7);
  assert.equal(g.phase, 'playing');
});

test('holes are limited to the even presets; anything else falls back to 8', () => {
  assert.deepEqual(PIRATE_HOLES, [6, 8, 12]);
  for (const h of PIRATE_HOLES) assert.equal(createPirateGame({ players, holes: h }).slots, h);
  for (const h of [4, 7, 10, 16, '8', null]) assert.equal(normalizeHoles(h), 8);
});

test('even hole counts make the first player lose exactly half the time; odd counts do not', () => {
  for (const h of PIRATE_HOLES) assert.equal(firstPlayerLossProbability(h), 0.5);
  assert.equal(firstPlayerLossProbability(5), 0.6);
  assert.ok(firstPlayerLossProbability(7) > 0.5);
});

test('simulated games with random stabs keep the first player near 50% for every preset', () => {
  const random = seeded(42);
  for (const holes of PIRATE_HOLES) {
    let firstLost = 0;
    const games = 20_000;
    for (let i = 0; i < games; i++) {
      let s = createPirateGame({ players, holes, random });
      while (s.phase === 'playing') {
        const free = freeSlots(s);
        s = applyStab(s, s.currentTurn, free[Math.floor(random() * free.length)]).state;
      }
      if (s.loser === s.firstTurn) firstLost++;
    }
    const rate = firstLost / games;
    assert.ok(Math.abs(rate - 0.5) < 0.015, `${holes} holes: first player lost ${rate}`);
  }
});

test('riskPct is round(100 / remaining)', () => {
  assert.equal(riskPct(8), 13);
  assert.equal(riskPct(6), 17);
  assert.equal(riskPct(12), 8);
  assert.equal(riskPct(3), 33);
  assert.equal(riskPct(2), 50);
  assert.equal(riskPct(1), 100);
});

test('stabs alternate turns and reject wrong turn, taken or out-of-range slots', () => {
  const g = createPirateGame({ players, holes: 6, random: seq(0, 0.99), now: 1000, startsAt: 1000 });
  assert.equal(g.bombSlot, 5);
  assert.equal(g.turnDeadline, 1000 + PIRATE_TURN_MS);
  assert.equal(applyStab(g, 'B', 0).reason, 'not_your_turn');
  assert.equal(applyStab(g, 'A', 6).reason, 'invalid_slot');
  assert.equal(applyStab(g, 'A', -1).reason, 'invalid_slot');
  assert.equal(applyStab(g, 'C', 0).reason, 'not_a_player');
  const r = applyStab(g, 'A', 2, { now: 5000 });
  assert.equal(r.ok, true);
  assert.equal(r.exploded, false);
  assert.equal(r.state.currentTurn, 'B');
  assert.equal(r.state.turnDeadline, 5000 + PIRATE_TURN_MS);
  assert.deepEqual(r.state.pickedSlots, [2]);
  assert.equal(applyStab(r.state, 'B', 2).reason, 'slot_taken');
  assert.deepEqual(g.pickedSlots, [], 'engine is pure');
});

test('hitting the bomb keeps the state as exploded with winner and loser', () => {
  const g = createPirateGame({ players, holes: 8, random: seq(0, 0) });
  const r = applyStab(g, 'A', 0, { now: 9 });
  assert.equal(r.exploded, true);
  assert.equal(r.state.phase, 'exploded');
  assert.equal(r.state.loser, 'A');
  assert.equal(r.state.winner, 'B');
  assert.equal(r.state.reason, 'bomb');
  assert.equal(r.state.currentTurn, null);
  assert.equal(r.state.turnDeadline, null);
  assert.equal(applyStab(r.state, 'B', 1).reason, 'not_playing');
});

test('timeouts auto-stab a free slot and the third consecutive one forfeits', () => {
  let s = createPirateGame({ players, holes: 12, random: seq(0, 0.99) }); // A first, bomb 11
  let r = applyTimeout(s, { random: () => 0 });
  assert.equal(r.slot, 0);
  assert.equal(r.state.stabs[0].auto, true);
  assert.equal(r.state.timeouts.A, 1);
  s = applyStab(r.state, 'B', 1).state; // B acts himself
  r = applyTimeout(s, { random: () => 0 });
  assert.equal(r.slot, 2, 'only free slots are auto-picked');
  assert.equal(r.state.timeouts.A, 2);
  s = applyStab(r.state, 'B', 3).state;
  r = applyTimeout(s);
  assert.equal(PIRATE_MAX_TIMEOUTS, 3);
  assert.equal(r.forfeit, true);
  assert.equal(r.state.phase, 'exploded');
  assert.equal(r.state.loser, 'A');
  assert.equal(r.state.reason, 'timeout');
});

test('a manual stab resets that player\'s timeout streak', () => {
  let s = createPirateGame({ players, holes: 12, random: seq(0, 0.99) });
  s = applyTimeout(s, { random: () => 0 }).state; // A auto
  s = applyStab(s, 'B', 1).state;
  s = applyStab(s, 'A', 2).state; // A manual
  assert.equal(s.timeouts.A, 0);
});

test('afk forfeit ends a playing game for the waiting player', () => {
  const s = createPirateGame({ players, random: seq(0, 0.5) });
  const r = applyForfeit(s, 'A');
  assert.equal(r.state.loser, 'A');
  assert.equal(r.state.reason, 'afk');
  assert.equal(applyForfeit(r.state, 'B').ok, false);
});

test('penalty text is trimmed, 1..30 characters, never empty', () => {
  assert.deepEqual(normalizePenaltyText('  노래 한 소절  '), { ok: true, text: '노래 한 소절' });
  assert.equal(normalizePenaltyText('   ').reason, 'penalty_empty');
  assert.equal(normalizePenaltyText('').reason, 'penalty_empty');
  assert.equal(normalizePenaltyText(42).reason, 'invalid_payload');
  assert.equal(normalizePenaltyText('가'.repeat(30)).ok, true);
  assert.equal(normalizePenaltyText('가'.repeat(31)).reason, 'penalty_too_long');
  assert.equal(normalizePenaltyText('🍦'.repeat(30)).ok, true, 'emoji count as one character');
  assert.equal(normalizePenaltyText('a\n\tb').text, 'a b');
  assert.equal(PIRATE_PENALTY_PRESETS.length, 10);
  for (const p of PIRATE_PENALTY_PRESETS) assert.equal(normalizePenaltyText(p).text, p);
});

test('only the winner sets the penalty once; only the loser completes it once', () => {
  const playing = createPirateGame({ players, random: seq(0, 0) });
  assert.equal(setPenalty(playing, 'B', '딱밤 한 대').reason, 'not_exploded');
  const exploded = applyStab(playing, 'A', 0).state; // A loses
  assert.equal(setPenalty(exploded, 'A', '딱밤 한 대').reason, 'not_winner');
  assert.equal(completePenalty(exploded, 'A').reason, 'no_penalty');
  const set = setPenalty(exploded, 'B', ' 딱밤 한 대 ', { now: 7 });
  assert.deepEqual(set.state.penalty, { text: '딱밤 한 대', by: 'B', at: 7, doneAt: null });
  assert.equal(setPenalty(set.state, 'B', '다른 것').reason, 'penalty_already_set');
  assert.equal(completePenalty(set.state, 'B').reason, 'not_loser');
  const done = completePenalty(set.state, 'A', { now: 8 });
  assert.equal(done.state.penalty.doneAt, 8);
  assert.equal(completePenalty(done.state, 'A').reason, 'penalty_already_done');
});

test('rematch alternates the first player', () => {
  assert.equal(nextFirstTurn({ firstTurn: 'A' }, players), 'B');
  assert.equal(nextFirstTurn({ firstTurn: 'B' }, players), 'A');
  assert.equal(nextFirstTurn(null, players), undefined);
  assert.equal(createPirateGame({ players, firstTurn: 'B', random: () => 0 }).firstTurn, 'B');
});

test('public state hides the bomb until it explodes and carries risk and server time', () => {
  const g = createPirateGame({ players, holes: 8, random: seq(0, 0.5), gameId: 'g1' });
  const view = publicPirateState(g, { now: 123, series: { wins: { A: 1, B: 0 }, draws: 0, games: 1 } });
  assert.equal(view.bombSlot, null);
  assert.equal(JSON.stringify(view).includes('bombSlot":4'), false);
  assert.equal(view.remaining, 8);
  assert.equal(view.riskPct, 13);
  assert.equal(view.serverNow, 123);
  assert.equal(view.turnMs, PIRATE_TURN_MS);
  assert.equal(view.series.wins.A, 1);
  const exploded = applyStab(g, 'A', 4).state;
  assert.equal(publicPirateState(exploded).bombSlot, 4);
});
