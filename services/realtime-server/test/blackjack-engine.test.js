import test from 'node:test';
import assert from 'node:assert/strict';
import {
  calculateScore,
  isBust,
  isBlackjack,
  initGame,
  playerHit,
  playerStand,
  dealerHit,
  dealerStand,
  nextRound,
  determineWinner,
} from '../src/blackjack-engine.js';

const card = (rank) => ({ rank, suit: '♠', value: rank === 'A' ? 11 : Number(rank) || 10 });

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

test('initGame creates one shared table and assigns the first dealer', () => {
  const game = initGame('userA', 'userB');
  assert.deepEqual(game.players, ['userA', 'userB']);
  assert.equal(game.round, 1);
  assert.equal(game.dealerId, 'userA');
  assert.equal(game.playerId, 'userB');
  assert.equal(game.playerHand.length, 2);
  assert.equal(game.dealerHand.length, 2);
  assert.ok(['player_turn', 'dealer_turn'].includes(game.phase));
});

test('only the active player can hit and a bust ends the round', () => {
  let game = initGame('userA', 'userB');
  game = {
    ...game,
    phase: 'player_turn',
    playerStatus: 'playing',
    playerHand: [card('K'), card('K')],
    dealerHand: [card('9'), card('7')],
    deck: [card('Q')],
  };

  assert.strictEqual(playerHit(game, 'userA'), game);
  const next = playerHit(game, 'userB');
  assert.equal(next.phase, 'round_result');
  assert.equal(next.lastRoundResult.outcome, 'loss');
  assert.equal(next.lastRoundResult.playerBust, true);
  assert.equal(next.rounds.length, 1);
  assert.equal(isBust(next.playerHand), true);
});

test('player turn, dealer turn, and role swap are synchronized', () => {
  let game = initGame('userA', 'userB');
  game = {
    ...game,
    phase: 'player_turn',
    playerStatus: 'playing',
    dealerStatus: 'playing',
    playerHand: [card('10'), card('5')],
    dealerHand: [card('9'), card('7')],
    deck: [card('2'), card('3'), card('4'), card('2')],
  };

  game = playerStand(game, 'userB');
  assert.equal(game.phase, 'dealer_turn');
  assert.strictEqual(dealerHit(game, 'userB'), game);

  game = dealerHit(game, 'userA');
  assert.equal(calculateScore(game.dealerHand), 18);
  assert.equal(game.dealerStatus, 'stand');
  assert.equal(game.phase, 'round_result');
  assert.equal(game.rounds[0].outcome, 'loss');

  game = nextRound(game, 'userB');
  assert.equal(game.round, 2);
  assert.equal(game.dealerId, 'userB');
  assert.equal(game.playerId, 'userA');
  assert.equal(game.phase, 'player_turn');
  assert.equal(game.playerHand.length, 2);
  assert.equal(game.dealerHand.length, 2);
});

test('final result is based on the two role-swapped rounds', () => {
  const rounds = [
    { winner: 'userA' },
    { winner: 'userA' },
  ];
  assert.equal(determineWinner(rounds, 'userA', 'userB'), 'userA');

  let game = initGame('userA', 'userB');
  game = {
    ...game,
    round: 2,
    phase: 'round_result',
    rounds,
  };
  game = nextRound(game, 'userA');
  assert.equal(game.status, 'finished');
  assert.equal(game.phase, 'finished');
  assert.equal(game.result.winner, 'userA');
});
