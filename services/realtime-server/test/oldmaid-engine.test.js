import test from 'node:test';
import assert from 'node:assert/strict';
import {
  checkEnd,
  createDeck,
  drawAt,
  drawnFor,
  forfeit,
  initGame,
  LOG_LIMIT,
  parseSlot,
  projectFor,
  removePairs,
} from '../src/oldmaid-engine.js';

// 재현 가능한 의사 난수(mulberry32).
const seeded = (seed) => () => {
  seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const card = (id, rank, suit = '♠') => ({ id, rank, suit, isJoker: rank === 'JOKER' });
const joker = () => card('card_joker', 'JOKER', '🃏');
const game = (hands, turn = 'A', extra = {}) => ({
  gameId: 'g1', status: 'playing', players: ['A', 'B'], hands, turn, firstTurn: turn,
  discards: [], log: [], drawCount: 0, timeouts: { A: 0, B: 0 }, result: null, ...extra,
});

test('createDeck has 52 cards plus one joker and unique ids', () => {
  const deck = createDeck(seeded(1));
  assert.equal(deck.length, 53);
  assert.equal(deck.filter((c) => c.isJoker).length, 1);
  assert.equal(new Set(deck.map((c) => c.id)).size, 53);
});

test('removePairs removes same-rank pairs and never the joker', () => {
  const { hand, pairedRanks } = removePairs([card('1', '7'), card('2', '7', '♥'), card('3', 'K'), joker(), card('4', '7', '♦')]);
  assert.deepEqual(pairedRanks, ['7']);
  assert.deepEqual(hand.map((c) => c.id).sort(), ['3', '4', 'card_joker']);
});

test('initGame deals 27/26, removes initial pairs into discards and keeps every card accounted for', () => {
  const g = initGame('A', 'B', { random: seeded(7), gameId: 'gid' });
  assert.equal(g.status, 'playing');
  assert.equal(g.gameId, 'gid');
  for (const id of ['A', 'B']) assert.equal(removePairs(g.hands[id]).pairedRanks.length, 0);
  const total = g.hands.A.length + g.hands.B.length + g.discards.length * 2;
  assert.equal(total, 53);
  // 짝이 없는 두 손패는 조커를 빼면 같은 랭크를 한 장씩 나눠 갖는다.
  const nonJoker = (h) => h.filter((c) => !c.isJoker).map((c) => c.rank).sort();
  assert.deepEqual(nonJoker(g.hands.A), nonJoker(g.hands.B));
});

test('initGame picks the first drawer at random and honors firstTurn', () => {
  assert.equal(initGame('A', 'B', { random: () => 0.1 }).turn, 'A');
  assert.equal(initGame('A', 'B', { random: () => 0.9 }).turn, 'B');
  assert.equal(initGame('A', 'B', { random: seeded(3), firstTurn: 'B' }).turn, 'B');
  const turns = new Set(Array.from({ length: 30 }, (_, i) => initGame('A', 'B', { random: seeded(i + 1) }).turn));
  assert.deepEqual([...turns].sort(), ['A', 'B']);
});

test('parseSlot accepts aliases and integers only, never real card ids', () => {
  assert.equal(parseSlot('slot-3'), 3);
  assert.equal(parseSlot(2), 2);
  assert.equal(parseSlot('card_joker'), null);
  assert.equal(parseSlot('card_12'), null);
  assert.equal(parseSlot('slot-x'), null);
});

test('drawAt with a matching rank discards the pair, records discards/log and passes the turn', () => {
  const g = game({ A: [card('a1', '10'), card('a2', '3')], B: [card('b1', '10', '♥'), joker(), card('b2', '3', '♣')] });
  const { game: next, draw } = drawAt(g, 'A', 0, { random: seeded(1), now: 500 });
  assert.equal(draw.paired, true);
  assert.equal(draw.pairedRank, '10');
  assert.equal(draw.card.id, 'b1');
  assert.equal(draw.matched.id, 'a1');
  assert.equal(draw.jokerMoved, false);
  assert.deepEqual(next.hands.A.map((c) => c.id), ['a2']);
  assert.equal(next.hands.B.length, 2);
  assert.deepEqual(next.discards, ['10']);
  assert.deepEqual(next.log, [{ by: 'A', paired: true, rank: '10', at: 500 }]);
  assert.equal(next.turn, 'B');
  assert.equal(next.drawCount, 1);
});

test('drawAt without a match keeps the card, logs rank null and flags a moved joker', () => {
  const g = game({ A: [card('a1', '5')], B: [joker(), card('b1', '5', '♥')] });
  const { game: next, draw } = drawAt(g, 'A', 0, { random: seeded(2), now: 9 });
  assert.equal(draw.paired, false);
  assert.equal(draw.pairedRank, null);
  assert.equal(draw.jokerMoved, true);
  assert.equal(next.hands.A.length, 2);
  assert.ok(next.hands.A.some((c) => c.isJoker));
  assert.deepEqual(next.log, [{ by: 'A', paired: false, rank: null, at: 9 }]);
  assert.deepEqual(next.discards, []);
});

test('drawAt rejects out of turn, bad slots and finished games without mutating', () => {
  const g = game({ A: [card('a1', '5')], B: [joker(), card('b1', '5', '♥')] });
  assert.equal(drawAt(g, 'B', 0).error, 'not_your_turn');
  assert.equal(drawAt(g, 'A', 2).error, 'invalid_slot');
  assert.equal(drawAt(g, 'A', -1).error, 'invalid_slot');
  assert.equal(drawAt(g, 'Z', 0).error, 'not_a_player');
  assert.equal(drawAt({ ...g, status: 'finished' }, 'A', 0).error, 'game_over');
  assert.equal(g.hands.B.length, 2);
});

test('the last joker holder loses: drawer pairing their last card leaves the victim with the joker', () => {
  const g = game({ A: [card('a1', '10')], B: [card('b1', '10', '♥'), joker()] });
  const { game: next } = drawAt(g, 'A', 0, { random: seeded(1) });
  assert.equal(next.status, 'finished');
  assert.deepEqual(next.result, { winner: 'A', loser: 'B', reason: 'joker' });
  assert.equal(next.turn, null);
});

test('the drawer loses when they take the victim\'s last card and are left holding the joker', () => {
  const g = game({ A: [card('a1', '10'), joker()], B: [card('b1', '10', '♥')] });
  const { game: next } = drawAt(g, 'A', 0, { random: seeded(1) });
  assert.equal(next.status, 'finished');
  assert.deepEqual(next.result, { winner: 'B', loser: 'A', reason: 'joker' });
});

test('log keeps only the latest entries and discards accumulate over a full random game', () => {
  let g = initGame('A', 'B', { random: seeded(11), gameId: 'full' });
  const random = seeded(12);
  let guard = 0;
  while (g.status === 'playing' && guard++ < 500) {
    const victim = g.turn === 'A' ? 'B' : 'A';
    const slot = Math.floor(random() * g.hands[victim].length);
    const before = g.discards.length;
    const r = drawAt(g, g.turn, slot, { random, now: guard });
    assert.ok(r.game, r.error);
    assert.equal(r.game.discards.length, before + (r.draw.paired ? 1 : 0));
    g = r.game;
    assert.ok(g.log.length <= LOG_LIMIT);
  }
  assert.equal(g.status, 'finished');
  assert.equal(g.discards.length, 26);
  const loserHand = g.hands[g.result.loser];
  assert.equal(loserHand.length, 1);
  assert.equal(loserHand[0].isJoker, true);
  assert.equal(g.hands[g.result.winner].length, 0);
});

test('auto draws count consecutive timeouts and a manual draw resets them', () => {
  const g = game({ A: [card('a1', '5'), card('a2', '6')], B: [card('b1', '7'), card('b2', '8'), joker()] });
  const first = drawAt(g, 'A', 0, { random: seeded(1), auto: true }).game;
  assert.equal(first.timeouts.A, 1);
  const second = drawAt({ ...first, turn: 'A' }, 'A', 0, { random: seeded(2), auto: true }).game;
  assert.equal(second.timeouts.A, 2);
  const manual = drawAt({ ...second, turn: 'A' }, 'A', 0, { random: seeded(3) }).game;
  assert.equal(manual.timeouts.A, 0);
});

test('projectFor hides the opponent hand behind slot aliases until the game ends', () => {
  const g = game({ A: [card('a1', '5')], B: [joker(), card('b1', '5', '♥')] });
  const forA = projectFor(g, 'A');
  assert.deepEqual(forA.hands.A, [card('a1', '5')]);
  assert.deepEqual(forA.hands.B, [{ id: 'slot-0' }, { id: 'slot-1' }]);
  assert.deepEqual(forA.handCounts, { A: 1, B: 2 });
  assert.ok(!JSON.stringify(forA.hands.B).includes('card_joker'));
  const done = projectFor(forfeit(g, 'B'), 'A');
  assert.equal(done.hands.B[0].isJoker, true);
  assert.equal(done.result.reason, 'forfeit');
});

test('drawnFor gives each side only the card it already knows', () => {
  const g = game({ A: [card('a1', '5')], B: [card('b9', '9', '♦'), joker(), card('b1', '5', '♥')] });
  const { game: next, draw } = drawAt(g, 'A', 2, { random: seeded(4), now: 1 });
  const drawer = drawnFor(next, draw, 'A');
  const victim = drawnFor(next, draw, 'B');
  const spectator = drawnFor(next, draw, 'C');
  assert.equal(drawer.role, 'drawer');
  assert.deepEqual(drawer.card, card('b1', '5', '♥'));
  assert.equal(drawer.matched.id, 'a1');
  assert.equal(drawer.handSize, 0);
  assert.equal(victim.role, 'victim');
  assert.deepEqual(victim.card, card('b1', '5', '♥'));
  assert.equal(victim.matched, null, 'the victim never sees the drawer\'s own cards');
  assert.equal(victim.handSize, 2);
  assert.equal(spectator.card, null);
  for (const view of [drawer, victim]) {
    assert.ok(!JSON.stringify(view).includes('b9'), 'no other opponent card id is ever sent');
    assert.ok(!JSON.stringify(view).includes('card_joker'));
  }
});

test('checkEnd leaves a playing game alone while non-joker cards remain', () => {
  const g = game({ A: [card('a1', '5')], B: [joker(), card('b1', '5', '♥')] });
  assert.equal(checkEnd(g), g);
});
