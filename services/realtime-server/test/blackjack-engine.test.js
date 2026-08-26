import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateScore,
  isBust,
  isBlackjack,
  initGame,
  hit,
  stand,
  nextRound,
  serializeFor,
  determineWinner,
} from '../src/blackjack-engine.js';

const card = (rank) => ({
  rank,
  suit: '♠',
  value: rank === 'A' ? 11 : Number(rank) || 10,
});

test('calculateScore handles Aces dynamically', () => {
  assert.equal(calculateScore([card('10'), card('A')]), 21);
  assert.equal(calculateScore([card('A'), card('A'), card('9')]), 21);
  assert.equal(calculateScore([card('K'), card('Q'), card('A')]), 21);
  assert.equal(calculateScore([card('K'), card('Q'), card('5')]), 25);
});

test('isBlackjack identifies 21 with exactly 2 cards', () => {
  assert.equal(isBlackjack([card('A'), card('J')]), true);
  assert.equal(isBlackjack([card('10'), card('9'), card('2')]), false);
});

test('initGame creates two symmetric players with private hands', () => {
  const game = initGame('userA', 'userB');
  assert.deepEqual(game.players, ['userA', 'userB']);
  assert.equal(game.round, 1);
  assert.equal(game.hands.userA.length, 2);
  assert.equal(game.hands.userB.length, 2);
  assert.equal('dealerId' in game, false);
  assert.equal('dealerHand' in game, false);
  assert.ok(['userA', 'userB', null].includes(game.currentTurn));
});

test('only the current player can hit or stand, then the turn passes', () => {
  let game = {
    status: 'playing',
    players: ['userA', 'userB'],
    round: 1,
    hands: {
      userA: [card('10'), card('5')],
      userB: [card('10'), card('6')],
    },
    statuses: { userA: 'playing', userB: 'playing' },
    currentTurn: 'userA',
    phase: 'player_turn',
    deck: [card('2')],
    rounds: [],
    lastRoundResult: null,
    result: null,
  };

  assert.strictEqual(hit(game, 'userB'), game);
  game = hit(game, 'userA');
  assert.equal(calculateScore(game.hands.userA), 17);
  assert.equal(game.currentTurn, 'userA');

  game = stand(game, 'userA');
  assert.equal(game.statuses.userA, 'stand');
  assert.equal(game.currentTurn, 'userB');

  game = stand(game, 'userB');
  assert.equal(game.phase, 'round_result');
  assert.equal(game.rounds[0].winner, 'userA');
  assert.deepEqual(game.rounds[0].scores, { userA: 17, userB: 16 });
});

test('a bust ends only that player turn and both busts resolve as a tie', () => {
  const game = {
    status: 'playing',
    players: ['userA', 'userB'],
    round: 1,
    hands: {
      userA: [card('K'), card('K')],
      userB: [card('K'), card('K')],
    },
    statuses: { userA: 'playing', userB: 'playing' },
    currentTurn: 'userA',
    phase: 'player_turn',
    deck: [card('Q'), card('Q')],
    rounds: [],
    lastRoundResult: null,
    result: null,
  };

  const afterFirstBust = hit(game, 'userA');
  assert.equal(afterFirstBust.statuses.userA, 'bust');
  assert.equal(afterFirstBust.currentTurn, 'userB');

  const afterSecondBust = hit(afterFirstBust, 'userB');
  assert.equal(afterSecondBust.phase, 'round_result');
  assert.equal(afterSecondBust.rounds[0].winner, 'tie');
  assert.equal(isBust(afterSecondBust.hands.userA), true);
  assert.equal(isBust(afterSecondBust.hands.userB), true);
});

test('next round keeps the same players and alternates the first turn', () => {
  const game = {
    status: 'playing',
    players: ['userA', 'userB'],
    round: 1,
    hands: { userA: [card('10'), card('5')], userB: [card('10'), card('6')] },
    statuses: { userA: 'stand', userB: 'stand' },
    currentTurn: null,
    phase: 'round_result',
    deck: [card('2'), card('3'), card('4'), card('5')],
    rounds: [{ winner: 'userA', scores: { userA: 15, userB: 16 } }],
    lastRoundResult: null,
    result: null,
  };

  const next = nextRound(game, 'userA');
  assert.deepEqual(next.players, ['userA', 'userB']);
  assert.equal(next.round, 2);
  assert.equal(next.currentTurn, 'userB');
  assert.equal(next.phase, 'player_turn');
  assert.equal(next.hands.userA.length, 2);
  assert.equal(next.hands.userB.length, 2);
});

test('serializeFor reveals only the viewer hand during a round', () => {
  const game = {
    status: 'playing',
    players: ['userA', 'userB'],
    round: 1,
    hands: {
      userA: [card('2'), card('K')],
      userB: [card('5'), card('9')],
    },
    statuses: { userA: 'playing', userB: 'playing' },
    currentTurn: 'userA',
    phase: 'player_turn',
    deck: [card('3')],
    rounds: [],
    lastRoundResult: null,
    result: null,
  };

  const stateForA = serializeFor(game, 'userA');
  assert.deepEqual(stateForA.hands.userA, game.hands.userA);
  assert.deepEqual(stateForA.hands.userB, [{ hidden: true }, { hidden: true }]);
  assert.deepEqual(stateForA.statuses, { userA: 'playing', userB: 'hidden' });
  assert.deepEqual(stateForA.scores, { userA: 12 });
  assert.equal('deck' in stateForA, false);

  const stateForB = serializeFor(game, 'userB');
  assert.deepEqual(stateForB.hands.userA, [{ hidden: true }, { hidden: true }]);
  assert.deepEqual(stateForB.hands.userB, game.hands.userB);
  assert.deepEqual(stateForB.statuses, { userA: 'hidden', userB: 'playing' });
  assert.deepEqual(stateForB.scores, { userB: 14 });

  const revealed = serializeFor({ ...game, phase: 'round_result' }, 'userA');
  assert.deepEqual(revealed.hands.userB, game.hands.userB);
  assert.deepEqual(revealed.scores, { userA: 12, userB: 14 });
});

test('final winner is based on the two symmetric rounds', () => {
  const rounds = [
    { winner: 'userA' },
    { winner: 'userA' },
  ];
  assert.equal(determineWinner(rounds, 'userA', 'userB'), 'userA');

  const game = {
    status: 'playing',
    players: ['userA', 'userB'],
    round: 2,
    hands: { userA: [card('10'), card('5')], userB: [card('10'), card('6')] },
    statuses: { userA: 'stand', userB: 'stand' },
    currentTurn: null,
    phase: 'round_result',
    deck: [],
    rounds,
    lastRoundResult: null,
    result: null,
  };
  const finished = nextRound(game, 'userA');
  assert.equal(finished.status, 'finished');
  assert.equal(finished.phase, 'finished');
  assert.equal(finished.result.winner, 'userA');
});
