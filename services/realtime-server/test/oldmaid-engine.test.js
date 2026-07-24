import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDeck,
  removePairs,
  initGame,
  drawCard,
  determineWinner,
} from '../src/oldmaid-engine.js';

test('createDeck creates 53 cards (52 standard + 1 Joker)', () => {
  const deck = createDeck();
  assert.equal(deck.length, 53);
  const jokers = deck.filter((c) => c.isJoker);
  assert.equal(jokers.length, 1);
});

test('removePairs removes matching pairs from a hand', () => {
  const hand = [
    { id: '1', rank: '7', suit: '♠', isJoker: false },
    { id: '2', rank: '7', suit: '♥', isJoker: false },
    { id: '3', rank: 'K', suit: '♦', isJoker: false },
    { id: '4', rank: 'JOKER', suit: '🃏', isJoker: true },
  ];
  const { updatedHand, removedCount } = removePairs(hand);
  assert.equal(removedCount, 2);
  assert.equal(updatedHand.length, 2);
  assert.equal(updatedHand.some((c) => c.rank === '7'), false);
  assert.equal(updatedHand.some((c) => c.isJoker), true);
});

test('initGame distributes cards to 2 players and auto-removes initial pairs', () => {
  const game = initGame('userA', 'userB');
  assert.equal(game.status, 'playing');
  assert.ok(game.turn === 'userA' || game.turn === 'userB');
  
  const p1Hand = game.players.userA.hand;
  const p2Hand = game.players.userB.hand;

  // Hand shouldn't have matching pairs
  const { removedCount: p1Pairs } = removePairs(p1Hand);
  const { removedCount: p2Pairs } = removePairs(p2Hand);
  assert.equal(p1Pairs, 0);
  assert.equal(p2Pairs, 0);

  // Total remaining cards across both players should equal 53 - total removed initial pairs
  const totalCards = p1Hand.length + p2Hand.length;
  assert.ok(totalCards <= 53);
  assert.ok(totalCards % 2 === 1); // 53 minus even number of pairs is always odd
});

test('drawCard moves selected card from opponent, discards pair if match, and switches turn', () => {
  const p1Id = 'userA';
  const p2Id = 'userB';
  let game = {
    status: 'playing',
    turn: p1Id,
    players: {
      [p1Id]: {
        hand: [
          { id: 'c1', rank: '10', suit: '♠', isJoker: false },
        ],
      },
      [p2Id]: {
        hand: [
          { id: 'c2', rank: '10', suit: '♥', isJoker: false },
          { id: 'c3', rank: 'JOKER', suit: '🃏', isJoker: true },
        ],
      },
    },
    discardedPairsCount: 25,
    result: null,
  };

  // p1Id draws c2 from p2Id
  game = drawCard(game, p1Id, 'c2');

  // Since p1Id had 10♠ and drew 10♥, pair 10s are removed!
  assert.equal(game.players[p1Id].hand.length, 0);
  assert.equal(game.players[p2Id].hand.length, 1); // only JOKER remains
  assert.equal(game.players[p2Id].hand[0].isJoker, true);

  // Now game is finished because only Joker remains in game
  assert.equal(game.status, 'finished');
  assert.equal(game.result.winner, p1Id);
  assert.equal(game.result.loser, p2Id);
});
