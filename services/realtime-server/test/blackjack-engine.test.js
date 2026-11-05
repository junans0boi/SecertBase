import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateScore,
  isBlackjack,
  createDeck,
  createMatch,
  hit,
  stand,
  nextRound,
  timeoutTurn,
  forfeit,
  serializeFor,
  nextFirstPlayer,
  visibleScore,
  TURN_MS,
  DEAL_MS,
  MAX_ROUNDS,
} from '../src/blackjack-engine.js';

const card = (rank, suit = '♠') => ({ rank, suit, value: rank === 'A' ? 11 : Number(rank) || 10 });

// Deterministic PRNG (mulberry32) so simulations are reproducible.
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

const NOW = 1_000_000;

/** A running round with fixed hands; A acts first. deck pops from the end. */
function round({ a, b, deck = [], first = 'A', round: r = 1, wins = { A: 0, B: 0 }, timeouts = { A: 0, B: 0 } }) {
  return {
    gameId: 'g1',
    status: 'playing',
    phase: 'player_turn',
    players: ['A', 'B'],
    winsNeeded: 2,
    maxRounds: MAX_ROUNDS,
    wins: { ...wins },
    openingPlayer: 'A',
    firstPlayer: first,
    currentTurn: first,
    round: r,
    deck: deck.map((x) => card(x)),
    hands: { A: a.map((x) => card(x)), B: b.map((x) => card(x)) },
    statuses: { A: 'playing', B: 'playing' },
    ready: { A: false, B: false },
    timeouts: { ...timeouts },
    turnDeadline: NOW + TURN_MS,
    rounds: [],
    lastRoundResult: null,
    result: null,
    series: null,
  };
}

const ok = (r) => {
  assert.equal(r.ok, true, `expected ok, got ${r.reason}`);
  return r.game;
};

test('score counts aces softly and blackjack needs exactly two cards', () => {
  assert.equal(calculateScore([card('10'), card('A')]), 21);
  assert.equal(calculateScore([card('A'), card('A'), card('9')]), 21);
  assert.equal(calculateScore([card('K'), card('Q'), card('5')]), 25);
  assert.equal(calculateScore([card('K'), { hidden: true }]), 10, 'hidden cards count as nothing');
  assert.equal(isBlackjack([card('A'), card('J')]), true);
  assert.equal(isBlackjack([card('10'), card('9'), card('2')]), false);
});

test('each round uses a fresh shuffled 52 card deck from the injected random', () => {
  const deck = createDeck(seeded(1));
  assert.equal(deck.length, 52);
  assert.equal(new Set(deck.map((c) => c.suit + c.rank)).size, 52);
  assert.deepEqual(createDeck(seeded(1)), deck, 'same seed, same order');
});

test('createMatch: random first player, two cards each, first deadline after the lobby countdown', () => {
  const firsts = new Set();
  for (let seed = 1; seed < 40; seed += 1) {
    const g = createMatch({ players: ['A', 'B'], random: seeded(seed), now: NOW, gameId: 'x' });
    firsts.add(g.firstPlayer);
    assert.equal(g.currentTurn, g.firstPlayer);
    assert.equal(g.openingPlayer, g.firstPlayer);
    assert.equal(g.hands.A.length, 2);
    assert.equal(g.hands.B.length, 2);
    assert.equal(g.deck.length, 48);
    assert.equal(g.round, 1);
    assert.deepEqual(g.wins, { A: 0, B: 0 });
    assert.equal(g.turnDeadline, NOW + DEAL_MS + TURN_MS);
    assert.equal(g.statuses.A, 'playing');
  }
  assert.deepEqual([...firsts].sort(), ['A', 'B'], 'either player can open');
  assert.equal(createMatch({ players: ['A', 'B'], firstPlayer: 'B', now: NOW }).currentTurn, 'B');
});

test('only the current player may act; hits are drawn from the deck and refresh the deadline', () => {
  let g = round({ a: ['10', '5'], b: ['10', '6'], deck: ['9', '2'] });
  assert.equal(hit(g, 'B', { now: NOW }).reason, 'not_your_turn');
  assert.equal(stand(g, 'B', { now: NOW }).reason, 'not_your_turn');
  assert.equal(hit(g, 'Z', { now: NOW }).reason, 'not_a_player');
  g = ok(hit(g, 'A', { now: NOW + 5000 }));
  assert.equal(calculateScore(g.hands.A), 17);
  assert.equal(g.currentTurn, 'A');
  assert.equal(g.turnDeadline, NOW + 5000 + TURN_MS);
  g = ok(stand(g, 'A', { now: NOW + 6000 }));
  assert.equal(g.statuses.A, 'stand');
  assert.equal(g.currentTurn, 'B');
  assert.equal(g.turnDeadline, NOW + 6000 + TURN_MS);
  g = ok(stand(g, 'B', { now: NOW + 7000 }));
  assert.equal(g.phase, 'round_result');
  assert.equal(g.lastRoundResult.winner, 'A');
  assert.equal(g.lastRoundResult.reason, 'score');
  assert.deepEqual(g.wins, { A: 1, B: 0 });
  assert.equal(g.turnDeadline, null);
});

test('a bust ends the round at once and the opponent wins it without acting', () => {
  let g = round({ a: ['10', '6'], b: ['2', '3'], deck: ['K'] });
  g = ok(hit(g, 'A', { now: NOW }));
  assert.equal(g.statuses.A, 'bust');
  assert.equal(g.statuses.B, 'playing', 'B never had to act');
  assert.equal(g.phase, 'round_result');
  assert.equal(g.lastRoundResult.winner, 'B');
  assert.equal(g.lastRoundResult.reason, 'bust');
  assert.deepEqual(g.wins, { A: 0, B: 1 });
});

test('a player on 21 cannot hit and is not auto-stood (no information leak)', () => {
  let g = round({ a: ['10', '5'], b: ['9', '9'], deck: ['6'] });
  g = ok(hit(g, 'A', { now: NOW }));
  assert.equal(calculateScore(g.hands.A), 21);
  assert.equal(g.statuses.A, 'playing', '21 by hitting keeps the turn');
  assert.equal(g.currentTurn, 'A');
  assert.equal(hit(g, 'A', { now: NOW }).reason, 'already_21');
  g = ok(stand(g, 'A', { now: NOW }));
  assert.equal(g.currentTurn, 'B');
});

test('a natural blackjack takes a normal turn, stays hidden and beats a drawn 21', () => {
  let g = round({ a: ['A', 'K'], b: ['10', '5'], deck: ['6'] });
  assert.equal(g.currentTurn, 'A', 'holder of a natural still acts in order');
  const view = serializeFor(g, 'B', { now: NOW });
  assert.equal(view.statuses.A, 'playing');
  assert.deepEqual(view.hands.A[1], { hidden: true });
  assert.equal(view.scores.A, undefined);
  assert.equal(view.visibleScores.A, 11);
  g = ok(stand(g, 'A', { now: NOW }));
  assert.equal(serializeFor(g, 'B', { now: NOW }).statuses.A, 'stand', 'looks like any other stand');
  g = ok(hit(g, 'B', { now: NOW }));
  assert.equal(calculateScore(g.hands.B), 21);
  g = ok(stand(g, 'B', { now: NOW }));
  assert.equal(g.lastRoundResult.winner, 'A');
  assert.equal(g.lastRoundResult.reason, 'blackjack');
  assert.deepEqual(g.lastRoundResult.naturals, { A: true, B: false });
});

test('two naturals or equal totals make a draw round that does not change the wins', () => {
  let g = round({ a: ['A', 'K'], b: ['A', 'Q'] });
  g = ok(stand(g, 'A', { now: NOW }));
  g = ok(stand(g, 'B', { now: NOW }));
  assert.equal(g.lastRoundResult.winner, 'tie');
  assert.deepEqual(g.wins, { A: 0, B: 0 });
  let h = round({ a: ['10', '8'], b: ['9', '9'] });
  h = ok(stand(h, 'A', { now: NOW }));
  h = ok(stand(h, 'B', { now: NOW }));
  assert.equal(h.lastRoundResult.winner, 'tie');
  assert.equal(h.phase, 'round_result');
});

test('serializeFor hides only the opponent hole card while playing and reveals everything after', () => {
  let g = round({ a: ['10', '5'], b: ['9', '7'], deck: ['3'] });
  g = ok(hit(g, 'A', { now: NOW }));
  const forB = serializeFor(g, 'B', { now: NOW + 1 });
  assert.deepEqual(forB.hands.A.map((c) => c.rank ?? 'hidden'), ['10', 'hidden', '3'], 'up card and hits are public');
  assert.equal(forB.visibleScores.A, 13);
  assert.equal(forB.scores.A, undefined);
  assert.equal(forB.scores.B, 16, 'my own total is complete');
  assert.equal(forB.hands.B[1].rank, '7');
  assert.equal(forB.serverNow, NOW + 1);
  assert.equal(forB.turnDeadline, NOW + TURN_MS);
  assert.equal('deck' in forB, false);
  g = ok(stand(g, 'A', { now: NOW }));
  g = ok(stand(g, 'B', { now: NOW }));
  const after = serializeFor(g, 'B', { now: NOW });
  assert.equal(after.hands.A[1].rank, '5');
  assert.equal(after.scores.A, 18);
});

test('next round waits for both ready; the round loser acts second and a draw swaps the order', () => {
  // B wins round 1 → B acts first in round 2 (A, the loser, acts second).
  let g = round({ a: ['10', '6'], b: ['2', '3'], deck: ['K'], first: 'A' });
  g = ok(hit(g, 'A', { now: NOW }));
  assert.equal(nextRound(g, 'Z', { now: NOW }).reason, 'not_a_player');
  g = ok(nextRound(g, 'A', { now: NOW, random: seeded(3) }));
  assert.equal(g.phase, 'round_result');
  assert.deepEqual(g.ready, { A: true, B: false });
  g = ok(nextRound(g, 'B', { now: NOW + 10, random: seeded(3) }));
  assert.equal(g.phase, 'player_turn');
  assert.equal(g.round, 2);
  assert.equal(g.firstPlayer, 'B');
  assert.equal(g.currentTurn, 'B');
  assert.equal(g.deck.length, 48, 'fresh deck every round');
  assert.equal(g.turnDeadline, NOW + 10 + DEAL_MS + TURN_MS);
  assert.equal(nextRound(g, 'A', { now: NOW }).reason, 'wrong phase');

  const tie = { ...round({ a: ['10', '8'], b: ['9', '9'], first: 'B' }) };
  assert.equal(nextFirstPlayer(tie, 'tie'), 'A');
  assert.equal(nextFirstPlayer(tie, 'A'), 'A');
  assert.equal(nextFirstPlayer(tie, 'B'), 'B');
});

test('first to two wins finishes the match without a ready step', () => {
  let g = round({ a: ['10', '9'], b: ['10', '7'], wins: { A: 1, B: 0 }, round: 2 });
  g = ok(stand(g, 'A', { now: NOW }));
  g = ok(stand(g, 'B', { now: NOW }));
  assert.equal(g.status, 'finished');
  assert.equal(g.phase, 'finished');
  assert.deepEqual(g.result, { winner: 'A', loser: 'B', reason: 'wins', wins: { A: 2, B: 0 } });
  assert.equal(g.lastRoundResult.round, 2);
  assert.equal(hit(g, 'A').reason, 'no_game');
  assert.equal(nextRound(g, 'A').reason, 'no_game');
});

test('after five rounds without two wins the match is a draw', () => {
  let g = round({ a: ['10', '8'], b: ['9', '9'], wins: { A: 1, B: 1 }, round: 5 });
  g = ok(stand(g, 'A', { now: NOW }));
  g = ok(stand(g, 'B', { now: NOW }));
  assert.equal(g.status, 'finished');
  assert.equal(g.result.winner, 'tie');
  assert.equal(g.result.reason, 'max_rounds');
  let one = round({ a: ['10', '8'], b: ['9', '9'], wins: { A: 1, B: 0 }, round: 5 });
  one = ok(stand(one, 'A', { now: NOW }));
  one = ok(stand(one, 'B', { now: NOW }));
  assert.equal(one.result.winner, 'tie', '1 : 0 after five rounds is still a draw');
});

test('timeout auto-stands; three consecutive timeouts forfeit; acting resets the count', () => {
  let g = round({ a: ['10', '5'], b: ['9', '7'], deck: ['2'] });
  let r = timeoutTurn(g, { now: NOW + TURN_MS });
  assert.equal(r.timedOut, 'A');
  g = r.game;
  assert.equal(g.statuses.A, 'stand');
  assert.equal(g.currentTurn, 'B');
  assert.equal(g.timeouts.A, 1);
  assert.equal(g.turnDeadline, NOW + 2 * TURN_MS);

  // Acting manually clears the streak.
  const acted = ok(hit(round({ a: ['10', '5'], b: ['9', '7'], deck: ['2'], timeouts: { A: 2, B: 0 } }), 'A', { now: NOW }));
  assert.equal(acted.timeouts.A, 0);

  const third = timeoutTurn(round({ a: ['10', '5'], b: ['9', '7'], timeouts: { A: 2, B: 0 } }), { now: NOW });
  assert.equal(third.game.status, 'finished');
  assert.deepEqual(third.game.result, { winner: 'B', loser: 'A', reason: 'timeout', wins: { A: 0, B: 0 } });

  const idle = timeoutTurn(third.game, { now: NOW });
  assert.equal(idle.timedOut, null, 'a finished game never times out');
});

test('forfeit ends the match for the other player and reveals the hands', () => {
  const g = forfeit(round({ a: ['10', '5'], b: ['9', '7'] }), 'B', 'afk');
  assert.equal(g.status, 'finished');
  assert.equal(g.result.winner, 'A');
  assert.equal(g.result.reason, 'afk');
  assert.equal(serializeFor(g, 'A').hands.B[1].rank, '7');
});

test('visibleScore ignores the hole card', () => {
  assert.equal(visibleScore([card('A'), card('K'), card('5')]), 16);
});

// --- balance -----------------------------------------------------------------

function playMatch(random, thresholds) {
  let g = createMatch({ players: ['A', 'B'], random, now: 0 });
  let guard = 0;
  while (g.status === 'playing' && guard++ < 200) {
    if (g.phase === 'round_result') {
      g = nextRound(g, 'A', { random, now: 0 }).game;
      g = nextRound(g, 'B', { random, now: 0 }).game;
      continue;
    }
    const me = g.currentTurn;
    const score = calculateScore(g.hands[me]);
    g = score < thresholds[me] ? hit(g, me, { now: 0 }).game : stand(g, me, { now: 0 }).game;
  }
  return g;
}

for (const standOn of [15, 16, 17]) {
  test(`balance: both standing on ${standOn}, final draws stay under 3% over 20,000 matches`, () => {
    const random = seeded(standOn * 7919);
    let draws = 0;
    let rounds = 0;
    const N = 20_000;
    for (let i = 0; i < N; i += 1) {
      const g = playMatch(random, { A: standOn, B: standOn });
      assert.equal(g.status, 'finished');
      if (g.result.winner === 'tie') draws += 1;
      rounds += g.round;
    }
    const drawRate = draws / N;
    assert.ok(drawRate < 0.03, `draw rate ${(drawRate * 100).toFixed(2)}%`);
    assert.ok(rounds / N < 3.5, `average rounds ${(rounds / N).toFixed(2)}`);
  });
}

test('balance: mixed strategies (16 vs 17) also stay under 3% draws', () => {
  const random = seeded(4242);
  let draws = 0;
  const N = 20_000;
  for (let i = 0; i < N; i += 1) {
    if (playMatch(random, { A: 16, B: 17 }).result.winner === 'tie') draws += 1;
  }
  assert.ok(draws / N < 0.03, `draw rate ${((draws / N) * 100).toFixed(2)}%`);
});
