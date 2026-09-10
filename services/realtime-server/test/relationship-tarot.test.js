import assert from 'node:assert/strict';
import test from 'node:test';
import {
  TAROT_CATALOG_VERSION,
  majorArcanaCatalog,
  drawDailyTarot,
} from '../src/relationship-tarot.js';

test('Tarot catalog contains 22 upright Major Arcana cards', () => {
  assert.equal(majorArcanaCatalog.length, 22);
  assert.equal(new Set(majorArcanaCatalog.map((card) => card.key)).size, 22);
  assert.ok(majorArcanaCatalog.every((card) => card.orientation === 'upright'));
  assert.ok(majorArcanaCatalog.every((card) => card.plain && card.reflection));
});

test('daily Tarot is deterministic per date, scope, and catalog version', () => {
  const personal = drawDailyTarot({ scope: 'user', scopeId: 12, date: '2026-09-10' });
  const personalAgain = drawDailyTarot({ scope: 'user', scopeId: 12, date: '2026-09-10' });
  const couple = drawDailyTarot({ scope: 'couple', scopeId: 99, date: '2026-09-10' });
  const nextDay = drawDailyTarot({ scope: 'user', scopeId: 12, date: '2026-09-11' });

  assert.equal(personal.catalogVersion, TAROT_CATALOG_VERSION);
  assert.deepEqual(personal, personalAgain);
  assert.notEqual(personal.card.key, nextDay.card.key);
  assert.equal(personal.scope, 'user');
  assert.equal(couple.scope, 'couple');
  assert.equal('reversed' in personal.card, false);
});
