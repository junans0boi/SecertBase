import test from 'node:test';
import assert from 'node:assert/strict';
import {
  COLORS,
  canPlayCard,
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

test('classic deck excludes discard_all cards', () => {
  const deck = createDeck({ mode: 'classic' });

  assert.equal(deck.some((card) => card.value === 'discard_all'), false);
});

test('go wild allows a +4 response for a +2 draw stack', () => {
  const topCard = { color: 'red', value: 'draw2', id: 'red-draw2-a' };

  assert.equal(
    canPlayCard(
      { color: null, value: 'wild_draw4', id: 'wild_draw4-0' },
      topCard,
      null,
      2,
      'draw2',
      { mode: 'go_wild' },
    ),
    true,
  );

  assert.equal(
    canPlayCard(
      { color: 'yellow', value: 'draw2', id: 'yellow-draw2-a' },
      topCard,
      null,
      2,
      'draw2',
      { mode: 'go_wild' },
    ),
    true,
  );
});

test('go wild requires a +4 response for a +4 draw stack', () => {
  const topCard = { color: null, value: 'wild_draw4', id: 'wild_draw4-0' };

  assert.equal(
    canPlayCard(
      { color: 'yellow', value: 'draw2', id: 'yellow-draw2-a' },
      topCard,
      'red',
      4,
      'wild_draw4',
      { mode: 'go_wild' },
    ),
    false,
  );
});

test('discard_all cannot defend a pending draw stack', () => {
  const discardAll = { color: 'red', value: 'discard_all', id: 'red-discard_all-a' };

  for (const [drawStack, drawStackType, topCard] of [
    [2, 'draw2', { color: 'blue', value: 'draw2', id: 'blue-draw2-a' }],
    [4, 'wild_draw4', { color: null, value: 'wild_draw4', id: 'wild_draw4-0' }],
  ]) {
    assert.equal(
      canPlayCard(
        discardAll,
        topCard,
        null,
        drawStack,
        drawStackType,
        { mode: 'go_wild' },
      ),
      false,
    );
  }
});

test('discard_all preserves a draw stack created by its batch', () => {
  const gameState = {
    drawStack: 0,
    drawStackType: null,
  };

  applyCardEffect(gameState, { color: 'red', value: 'draw2', id: 'red-draw2-a' });
  applyCardEffect(gameState, { color: 'red', value: 'discard_all', id: 'red-discard_all-a' });

  assert.equal(gameState.drawStack, 2);
  assert.equal(gameState.drawStackType, 'draw2');
});

test('classic blocks draw stack defense', () => {
  const topCard = { color: 'red', value: 'draw2', id: 'red-draw2-a' };

  assert.equal(
    canPlayCard(
      { color: null, value: 'wild_draw4', id: 'wild_draw4-0' },
      topCard,
      null,
      2,
      'draw2',
      { mode: 'classic' },
    ),
    false,
  );
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

  // trigger is last → sits on top of discard pile
  assert.deepEqual(batch.map((card) => card.id), [
    'blue-3-a',
    'blue-skip-a',
    'blue-discard_all-a',
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
