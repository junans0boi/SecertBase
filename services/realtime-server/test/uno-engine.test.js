import test from 'node:test';
import assert from 'node:assert/strict';
import {
  COLORS,
  canPlayCard,
  createDeck,
  collectDiscardAllBatch,
  applyCardEffect,
  applyDiscardAllBatchEffects,
  canChallengeDraw4,
  getNextPlayer,
  createUnoGameState,
  playCard,
  drawForTurn,
  passDrawnCard,
  callOneCard,
  catchOneCard,
  challengeDraw4,
  autoAction,
  playableCardIds,
  serializeOneCardFor,
  isWildCard,
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

test('only a standalone +4 can be challenged', () => {
  assert.equal(
    canChallengeDraw4(
      { drawStack: 4, drawStackType: 'wild_draw4', currentPlayer: 'me' },
      'me',
    ),
    true,
  );
  assert.equal(
    canChallengeDraw4(
      { drawStack: 6, drawStackType: 'wild_draw4', currentPlayer: 'me' },
      'me',
    ),
    false,
  );
  assert.equal(
    canChallengeDraw4(
      { drawStack: 2, drawStackType: 'draw2', currentPlayer: 'me' },
      'me',
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

test('discard_all makes a swept +2 card have no attack effect', () => {
  const gameState = {
    drawStack: 0,
    drawStackType: null,
  };

  applyDiscardAllBatchEffects(gameState, [
    { color: 'red', value: 'draw2', id: 'red-draw2-a' },
    { color: 'red', value: 'discard_all', id: 'red-discard_all-a' },
  ]);

  assert.equal(gameState.drawStack, 0);
  assert.equal(gameState.drawStackType, null);
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

// ── 2.0 흐름(티켓 19) ─────────────────────────────────────────────────────────
const seeded = (seed) => () => {
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const c = (color, value, id = `${color ?? 'wild'}-${value}`) => ({ color, value, id });
function scenario(overrides = {}) {
  const g = createUnoGameState(['A', 'B'], 7, { mode: 'go_wild', random: seeded(7), starter: 'A' });
  return Object.assign(g, overrides);
}

test('starter is random by injection and can be forced for rematches', () => {
  assert.equal(createUnoGameState(['A', 'B'], 7, { random: () => 0 }).starter, 'A');
  assert.equal(createUnoGameState(['A', 'B'], 7, { random: () => 0.99 }).starter, 'B');
  const forced = createUnoGameState(['A', 'B'], 7, { starter: 'B' });
  assert.equal(forced.currentPlayer, 'B');
});

test('discard-all batch: two skips act once (two-player: the player goes again)', () => {
  const g = { players: ['A', 'B'], currentPlayer: 'A', direction: 1, drawStack: 0, drawStackType: null };
  applyDiscardAllBatchEffects(g, [c('red', 'skip', 's1'), c('red', 'skip', 's2'), c('red', 'discard_all')]);
  g.currentPlayer = getNextPlayer(g);
  assert.equal(g.currentPlayer, 'A');
});

test('a penalty draw ends the turn; a normal playable draw waits for a choice', () => {
  const g = scenario({ discardPile: [c('red', 'draw2')], drawStack: 2, drawStackType: 'draw2', currentPlayer: 'B' });
  g.deck.push(c('red', '4', 'drawn'));
  const r = drawForTurn(g, 'B');
  assert.equal(r.penalty, true);
  assert.equal(r.canPlayDrawn, false);
  assert.equal(g.currentPlayer, 'A');
  assert.equal(playCard(g, 'B', 'drawn').reason, 'not_your_turn');

  const h = scenario({ discardPile: [c('blue', '3')] });
  h.deck.push(c('blue', '9', 'drawn'));
  assert.equal(drawForTurn(h, 'A').canPlayDrawn, true);
  assert.equal(h.currentPlayer, 'A');
  assert.equal(passDrawnCard(h, 'A').ok, true);
  assert.equal(h.currentPlayer, 'B');
});

test('+4 challenge uses the hadColorAtDraw4 snapshot taken when it was played', () => {
  const g = scenario({ discardPile: [c('red', '7')] });
  g.hands.A = [c(null, 'wild_draw4'), c('blue', '1'), c('green', '2')];
  assert.equal(playCard(g, 'A', 'wild-wild_draw4', 'blue').ok, true);
  assert.equal(g.hadColorAtDraw4, false);
  g.hands.A.push(c('red', '9', 'later')); // hand changes after the play
  const r = challengeDraw4(g, 'B');
  assert.equal(r.success, false);
  assert.equal(r.drawnPlayer, 'B');
  assert.equal(r.drawnCount, 6);
  assert.equal(g.currentPlayer, 'A');
  assert.equal(g.declaredColor, 'blue');
});

test('wild requires a valid declared color and the current color follows it', () => {
  const g = scenario({ discardPile: [c('red', '7')] });
  g.hands.A = [c(null, 'wild'), c('blue', '1')];
  assert.equal(playCard(g, 'A', 'wild-wild', null).reason, 'must_declare_color');
  assert.equal(playCard(g, 'A', 'wild-wild', 'purple').reason, 'must_declare_color');
  assert.equal(playCard(g, 'A', 'wild-wild', 'green').ok, true);
  assert.equal(serializeOneCardFor(g, 'B').currentColor, 'green');
  assert.equal(g.lastAction.colorChanged, true);
});

test('turn actions reject after a winner exists', () => {
  const g = scenario({ discardPile: [c('red', '7')] });
  g.hands.A = [c('red', '1')];
  assert.equal(playCard(g, 'A', 'red-1').won, true);
  assert.equal(drawForTurn(g, 'B').reason, 'game_over');
  assert.equal(callOneCard(g, 'B').reason, 'game_over');
  assert.equal(catchOneCard(g, 'B').reason, 'game_over');
  assert.equal(autoAction(g).reason, 'game_over');
  assert.deepEqual(playableCardIds(g, 'B'), []);
});

test('auto action never plays a card: it serves the stack, draws one, or passes a pending choice', () => {
  const g = scenario({ discardPile: [c('blue', '3')] });
  g.deck.push(c('blue', '9', 'drawn'));
  const before = g.hands.A.length;
  assert.equal(autoAction(g).kind, 'draw');
  assert.equal(g.hands.A.length, before + 1, 'the playable drawn card is kept');
  assert.equal(g.currentPlayer, 'B');
  const s = scenario({ discardPile: [c(null, 'wild_draw4')], declaredColor: 'red', drawStack: 4, drawStackType: 'wild_draw4' });
  const n = s.hands.A.length;
  autoAction(s);
  assert.equal(s.hands.A.length, n + 4);
  const p = scenario({ discardPile: [c('blue', '3')] });
  p.deck.push(c('blue', '8', 'drawn'));
  drawForTurn(p, 'A');
  assert.equal(autoAction(p).kind, 'pass');
  assert.equal(p.currentPlayer, 'B');
});

test('view hides the opponent hand and the identity of cards the opponent drew', () => {
  const g = scenario({ discardPile: [c('blue', '3')] });
  drawForTurn(g, 'A');
  const mine = serializeOneCardFor(g, 'A');
  const theirs = serializeOneCardFor(g, 'B');
  assert.ok(mine.lastAction.cardIds.length >= 1);
  assert.equal(theirs.lastAction.cardIds, undefined);
  assert.equal(theirs.hands, undefined);
  assert.equal(theirs.drawnCardId, null);
});

test('simulation: both modes average 25–55 turns and never lose a card', () => {
  for (const mode of ['classic', 'go_wild']) {
    const random = seeded(2026);
    const games = 1500;
    const deckSize = mode === 'classic' ? 108 : 116;
    let total = 0;
    let starterWins = 0;
    for (let n = 0; n < games; n++) {
      const g = createUnoGameState(['A', 'B'], 7, { mode, random });
      let turns = 0;
      while (!g.winner && turns < 1000) {
        turns++;
        const p = g.currentPlayer;
        const counts = {};
        for (const card of g.hands[p]) if (card.color) counts[card.color] = (counts[card.color] ?? 0) + 1;
        const color = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'red';
        const ids = playableCardIds(g, p);
        if (ids.length) {
          const plain = ids.filter((id) => !isWildCard(g.hands[p].find((card) => card.id === id)));
          const pool = plain.length && random() < 0.5 ? plain : ids;
          playCard(g, p, pool[Math.floor(random() * pool.length)], color, { random });
        } else if (drawForTurn(g, p, { random }).canPlayDrawn) {
          playCard(g, p, g.drawnCardId, color, { random });
        }
        if (g.unoCallNeeded) callOneCard(g, g.unoCallNeeded);
        assert.equal(g.deck.length + g.discardPile.length + g.hands.A.length + g.hands.B.length, deckSize);
      }
      assert.ok(g.winner, 'every game ends');
      if (g.winner === g.starter) starterWins++;
      total += turns;
    }
    const avg = total / games;
    assert.ok(avg >= 25 && avg <= 55, `${mode} average ${avg.toFixed(1)} turns`);
    assert.ok(starterWins / games < 0.58, `${mode} starter advantage ${starterWins / games}`);
  }
});
