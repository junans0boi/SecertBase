import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDeck,
  calculateScore,
  isBust,
  isBlackjack,
  initGame,
  playerHit,
  playerStand,
  determineWinner,
} from '../src/blackjack-engine.js';

// initGame deals random cards; a natural blackjack (~10% of deals) auto-stands
// the player and can even auto-finish the game. These tests exercise the
// normal flow, so redeal until both players start in 'playing'.
function initPlayingGame(p1, p2) {
  for (let i = 0; i < 200; i++) {
    const game = initGame(p1, p2);
    if (
      game.status === 'playing' &&
      game.players[p1].status === 'playing' &&
      game.players[p2].status === 'playing'
    ) {
      return game;
    }
  }
  throw new Error('could not deal a blackjack-free game in 200 tries');
}

test('calculateScore handles Aces dynamically', () => {
  assert.equal(calculateScore([{ rank: '10' }, { rank: 'A' }]), 21);
  assert.equal(calculateScore([{ rank: 'A' }, { rank: 'A' }, { rank: '9' }]), 21);
  assert.equal(calculateScore([{ rank: 'K' }, { rank: 'Q' }, { rank: 'A' }]), 21);
  assert.equal(calculateScore([{ rank: 'K' }, { rank: 'Q' }, { rank: '5' }]), 25);
});

test('isBlackjack identifies 21 with 2 cards', () => {
  assert.equal(isBlackjack([{ rank: 'A' }, { rank: 'J' }]), true);
  assert.equal(isBlackjack([{ rank: '10' }, { rank: '9' }, { rank: '2' }]), false);
});

test('initGame deals 2 cards to each player and 2 cards to each dealer', () => {
  const game = initPlayingGame('userA', 'userB');
  assert.ok(game);
  assert.equal(game.status, 'playing');
  assert.equal(game.players.userA.hand.length, 2);
  assert.equal(game.players.userB.hand.length, 2);
  assert.equal(game.dealers.userA.hand.length, 2);
  assert.equal(game.dealers.userB.hand.length, 2);
  assert.equal(game.players.userA.status, 'playing');
  assert.equal(game.players.userB.status, 'playing');
});

test('playerHit draws a card for the specified player', () => {
  let game = initPlayingGame('userA', 'userB');
  game = playerHit(game, 'userA');
  assert.equal(game.players.userA.hand.length, 3);
  assert.equal(game.players.userB.hand.length, 2);
});

test('playerStand freezes player turn and plays dealer if both finished', () => {
  let game = initPlayingGame('userA', 'userB');
  game = playerStand(game, 'userA');
  assert.equal(game.players.userA.status, 'stand');
  assert.equal(game.status, 'playing');

  game = playerStand(game, 'userB');
  assert.equal(game.players.userB.status, 'stand');
  assert.equal(game.status, 'finished');
  assert.ok(game.result);
});

test('dealer hits until score >= 17 when both players finish', () => {
  let game = initGame('userA', 'userB');
  game = playerStand(game, 'userA');
  game = playerStand(game, 'userB');
  assert.ok(calculateScore(game.dealers.userA.hand) >= 17 || isBust(game.dealers.userA.hand));
  assert.ok(calculateScore(game.dealers.userB.hand) >= 17 || isBust(game.dealers.userB.hand));
});

test('determineWinner compares net results between two players', () => {
  const outcomeA = { playerBust: false, dealerBust: false, playerScore: 20, dealerScore: 18, isPlayerBJ: false, isDealerBJ: false, scoreMargin: 1 };
  const outcomeB = { playerBust: false, dealerBust: false, playerScore: 18, dealerScore: 19, isPlayerBJ: false, isDealerBJ: false, scoreMargin: -1 };
  
  const winner = determineWinner(outcomeA, outcomeB, 'userA', 'userB');
  assert.equal(winner, 'userA');
});
