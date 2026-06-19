import test from 'node:test';
import assert from 'node:assert/strict';
import {
  COLORS,
  createDeck,
  collectDiscardAllBatch,
  applyCardEffect,
  getNextPlayer,
} from '../src/uno-engine.js';

test('UNO deck includes colored discard_all cards', () => {
  const deck = createDeck();

  for (const color of COLORS) {
    const cards = deck.filter((card) => card.color === color && card.value === 'discard_all');
    assert.equal(cards.length, 2);
  }
});

test('discard_all card discards every card of its own color only', () => {
  const trigger = { color: 'blue', value: 'discard_all', id: 'blue-discard_all-a' };
  const hand = [
    { color: 'blue', value: '3', id: 'blue-3-a' },
    { color: 'red', value: '3', id: 'red-3-a' },
    { color: 'blue', value: 'skip', id: 'blue-skip-a' },
    { color: null, value: 'wild', id: 'wild-0' },
  ];

  const batch = collectDiscardAllBatch(hand, trigger);

  assert.deepEqual(batch.map((card) => card.id), [
    'blue-discard_all-a',
    'blue-3-a',
    'blue-skip-a',
  ]);
  assert.deepEqual(hand.map((card) => card.id), ['red-3-a', 'wild-0']);
});

test('skip returns turn to the same player in a two-player UNO game', () => {
  const gameState = {
    players: ['me', 'you'],
    currentPlayer: 'me',
    direction: 1,
  };

  applyCardEffect(gameState, { color: 'red', value: 'skip', id: 'red-skip-a' });
  gameState.currentPlayer = getNextPlayer(gameState);

  assert.equal(gameState.currentPlayer, 'me');
});
