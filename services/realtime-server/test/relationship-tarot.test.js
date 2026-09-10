import assert from 'node:assert/strict';
import test from 'node:test';
import {
  TAROT_CATALOG_VERSION,
  majorArcanaCatalog,
  tarotSelectionCatalog,
  drawSelectedTarot,
  undrawnTarot,
} from '../src/relationship-tarot.js';

test('Tarot catalog contains 22 upright Major Arcana cards', () => {
  assert.equal(majorArcanaCatalog.length, 22);
  assert.equal(new Set(majorArcanaCatalog.map((card) => card.key)).size, 22);
  assert.ok(majorArcanaCatalog.every((card) => card.orientation === 'upright'));
  assert.ok(majorArcanaCatalog.every((card) => card.plain && card.reflection));
});

test('Tarot shows a face-down selection catalog before the first draw', () => {
  const waiting = undrawnTarot({ scope: 'user', date: '2026-09-10' });

  assert.equal(waiting.drawn, false);
  assert.equal(waiting.drawRequired, true);
  assert.equal(waiting.catalogVersion, TAROT_CATALOG_VERSION);
  assert.equal(waiting.cards.length, 22);
  assert.equal(waiting.cards[0].position, 1);
  assert.equal('plain' in waiting.cards[0], false);
});

test('user-selected Tarot card is fixed for the date and cannot be replaced', () => {
  const selected = drawSelectedTarot({
    scope: 'user',
    date: '2026-09-10',
    cardKey: 'the_star',
  });

  assert.equal(selected.drawn, true);
  assert.equal(selected.drawRequired, false);
  assert.equal(selected.card.key, 'the_star');
  assert.equal(selected.redrawAvailable, false);
  assert.equal(tarotSelectionCatalog.length, 22);
  assert.equal('reversed' in selected.card, false);
  assert.throws(
    () => drawSelectedTarot({
      scope: 'user',
      date: '2026-09-10',
      cardKey: 'not-a-card',
    }),
    /invalid_tarot_card/,
  );
});
