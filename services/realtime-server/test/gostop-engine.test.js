// 고스톱(2인 맞고) 2.0 엔진. 규칙 기준: docs/plans/game-renewal-2026-11-wave2/01-grilling.md Q25.
// G1–G12는 00-analysis.md §4의 재현 시나리오(가짜 판쓸이·마지막 턴·고 배수 …)를 그대로 옮긴 것이다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import * as E from '../src/gostop-engine.js';

const A = 'A';
const B = 'B';
const card = id => {
  const c = E.cardById(id);
  if (!c) throw new Error(`unknown card ${id}`);
  return c;
};
const cards = list => list.map(card);
const idsOf = list => list.map(c => c.id);

/** 진행 중인 판을 직접 꾸민다(덱은 마지막 장이 맨 위). */
function table(over = {}) {
  const base = E.createGostopGameState(A, B, { starter: A, perPointBet: 100, gameId: 'g-test', random: seeded(1) });
  const s = {
    ...base,
    phase: 'playing',
    current: A,
    chongtong: null,
    field: [],
    deck: [],
    hands: { [A]: [], [B]: [] },
    captures: { [A]: [], [B]: [] },
    ...over,
  };
  return E.rescore(s);
}

function seeded(seed) {
  let x = seed >>> 0 || 1;
  return () => {
    x ^= x << 13; x >>>= 0;
    x ^= x >>> 17;
    x ^= x << 5; x >>>= 0;
    return (x % 1_000_000) / 1_000_000;
  };
}

const ok = r => {
  assert.equal(r.ok, true, `expected ok, got ${r.reason}`);
  return r.state;
};

const junks = (n, from = 0) => E.DECK_DEF.filter(c => c.type === 'junk' && c.subtype !== 'double').slice(from, from + n);

// 7점: 3광(3) + 홍단(3) + 띠 5장(1)
const SEVEN = ['m1_bright', 'm3_bright', 'm8_bright', 'm1_animal', 'm2_ribbon', 'm3_ribbon', 'm6_ribbon', 'm9_ribbon'];

// ── 덱 ───────────────────────────────────────────────────────────
test('deck has 48 unique cards, 4 per month, standard 5/9/10/24 split and two 쌍피', () => {
  const deck = E.createHwatuDeck(seeded(3));
  assert.equal(deck.length, 48);
  assert.equal(new Set(idsOf(deck)).size, 48);
  for (let m = 1; m <= 12; m++) assert.equal(deck.filter(c => c.month === m).length, 4, `month ${m}`);
  assert.equal(deck.filter(c => c.type === 'bright').length, 5);
  assert.equal(deck.filter(c => c.type === 'animal').length, 9);
  assert.equal(deck.filter(c => c.type === 'ribbon').length, 10);
  assert.equal(deck.filter(c => c.type === 'junk').length, 24);
  assert.deepEqual(deck.filter(c => c.subtype === 'double').map(c => c.month).sort((a, b) => a - b), [11, 12]);
  assert.deepEqual(deck.filter(c => c.subtype === 'red').map(c => c.month).sort((a, b) => a - b), [1, 2, 3]);
  assert.deepEqual(deck.filter(c => c.subtype === 'blue').map(c => c.month).sort((a, b) => a - b), [6, 9, 10]);
});

test('Flutter artwork filenames match the server deck contract', () => {
  const assetDir = new URL('../../../apps/secret_base_app/assets/images/hwatu/', import.meta.url);
  const assetIds = readdirSync(assetDir).filter(n => n.endsWith('.png')).map(n => n.slice(0, -4)).sort();
  assert.deepEqual(assetIds, idsOf(E.DECK_DEF).sort());
});

test('the shuffle uses the injected random (same seed → same deal)', () => {
  const a = E.createGostopGameState(A, B, { random: seeded(42), starter: A });
  const b = E.createGostopGameState(A, B, { random: seeded(42), starter: A });
  assert.deepEqual(idsOf(a.hands[A]), idsOf(b.hands[A]));
  assert.deepEqual(idsOf(a.deck), idsOf(b.deck));
});

// ── 점수 ─────────────────────────────────────────────────────────
test('광: 3장 3점, 비광 낀 3장 2점, 4광 4점(비광 포함), 5광 15점', () => {
  assert.equal(E.calculateScore(cards(['m1_bright', 'm3_bright', 'm8_bright'])).gwangScore, 3);
  assert.equal(E.calculateScore(cards(['m1_bright', 'm3_bright', 'm12_bright'])).gwangScore, 2);
  assert.equal(E.calculateScore(cards(['m1_bright', 'm3_bright', 'm8_bright', 'm12_bright'])).gwangScore, 4);
  assert.equal(E.calculateScore(cards(['m1_bright', 'm3_bright', 'm8_bright', 'm11_bright', 'm12_bright'])).gwangScore, 15);
});

test('열끗 5장 1점·6장 2점, 고도리 5점, 국진(9월)은 열끗', () => {
  const five = cards(['m2_animal', 'm4_animal', 'm5_animal', 'm6_animal', 'm9_animal']);
  assert.equal(E.calculateScore(five).animScore, 1);
  assert.equal(E.calculateScore([...five, card('m10_animal')]).animScore, 2);
  assert.equal(E.calculateScore(cards(['m2_animal', 'm4_animal', 'm8_animal'])).godoriScore, 5);
  assert.equal(card('m9_animal').type, 'animal');
});

test('띠 5장 1점, 홍단·청단·초단 각 3점', () => {
  const s = E.calculateScore(cards(['m1_animal', 'm2_ribbon', 'm3_ribbon', 'm4_ribbon', 'm5_ribbon']));
  assert.equal(s.ribScore, 1);
  assert.equal(s.hongdanBonus, 3);
  assert.equal(E.calculateScore(cards(['m6_ribbon', 'm9_ribbon', 'm10_ribbon'])).cheongdanBonus, 3);
  assert.equal(E.calculateScore(cards(['m4_ribbon', 'm5_ribbon', 'm7_animal_2'])).chodanBonus, 3);
});

test('피 10장 1점, 쌍피는 2장으로 센다', () => {
  assert.equal(E.calculateScore(junks(9)).piScore, 0);
  assert.equal(E.calculateScore(junks(10)).piScore, 1);
  assert.equal(E.calculateScore([card('m11_junk_d'), ...junks(8)]).piTotal, 10);
});

// ── 분배 (G9, G10) ───────────────────────────────────────────────
test('deal: 10 / 10 / 8 / 20, starter acts first, no shake phase at the start (G8)', () => {
  const s = E.createGostopGameState(A, B, { random: seeded(7), starter: B });
  assert.equal(s.hands[A].length, 10);
  assert.equal(s.hands[B].length, 10);
  assert.equal(s.field.length, 8);
  assert.equal(s.deck.length, 20);
  assert.equal(s.starter, B);
  assert.notEqual(s.phase, 'shake_choice');
  if (s.phase === 'playing') assert.equal(s.current, B);
});

test('G9: four cards of one month on the field → redeal', () => {
  const bad = E.buildDeck({ field: ['m1_bright', 'm1_animal', 'm1_junk_1', 'm1_junk_2', 'm2_junk_1', 'm3_junk_1', 'm4_junk_1', 'm5_junk_1'] });
  const good = E.buildDeck({});
  const s = E.createGostopGameState(A, B, { decks: [bad, good], starter: A });
  assert.deepEqual(s.redeals, ['field_four']);
  const months = {};
  for (const c of s.field) months[c.month] = (months[c.month] ?? 0) + 1;
  assert.ok(Object.values(months).every(n => n < 4));
});

test('G9: random deals never leave four of a month on the field', () => {
  const random = seeded(99);
  for (let g = 0; g < 4000; g++) {
    const s = E.createGostopGameState(A, B, { random, starter: A });
    const months = {};
    for (const c of s.field) months[c.month] = (months[c.month] ?? 0) + 1;
    assert.ok(Object.values(months).every(n => n < 4), `deal ${g}`);
  }
});

test('G10: 총통 is offered to its holder; declaring wins 10 points at once', () => {
  const deck = E.buildDeck({ a: ['m5_animal', 'm5_ribbon', 'm5_junk_1', 'm5_junk_2'] });
  const s = E.createGostopGameState(A, B, { decks: [deck], starter: B, perPointBet: 100 });
  assert.equal(s.phase, 'chongtong');
  assert.equal(s.current, A);
  assert.deepEqual(s.chongtong, { player: A, month: 5 });
  const won = ok(E.decideChongtong(s, A, true));
  assert.equal(won.phase, 'finished');
  assert.equal(won.result.reason, 'chongtong');
  assert.equal(won.result.winner, A);
  assert.equal(won.result.points.total, 10);
  assert.equal(won.result.multiplier, 1);
  assert.equal(won.result.amount, 1000);
});

test('G10: 총통 can be declined and the game goes on with the starter', () => {
  const deck = E.buildDeck({ a: ['m5_animal', 'm5_ribbon', 'm5_junk_1', 'm5_junk_2'] });
  const s = E.createGostopGameState(A, B, { decks: [deck], starter: B });
  const next = ok(E.decideChongtong(s, A, false));
  assert.equal(next.phase, 'playing');
  assert.equal(next.current, B);
  assert.equal(next.hands[A].length, 10);
  assert.equal(E.decideChongtong(s, B, true).reason, 'not_your_turn');
});

test('G10: both players holding 총통 → redeal', () => {
  const both = E.buildDeck({ a: ['m5_animal', 'm5_ribbon', 'm5_junk_1', 'm5_junk_2'], b: ['m6_animal', 'm6_ribbon', 'm6_junk_1', 'm6_junk_2'] });
  const s = E.createGostopGameState(A, B, { decks: [both, E.buildDeck({})], starter: A });
  assert.deepEqual(s.redeals, ['double_chongtong']);
  assert.notEqual(s.phase, 'chongtong');
});

// ── 기본 진행 ─────────────────────────────────────────────────────
test('playing a matching card captures the pair; a lone card stays on the field', () => {
  const s = table({
    field: cards(['m2_junk_1', 'm3_junk_1']),
    hands: { [A]: cards(['m2_ribbon', 'm7_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_animal', 'm5_junk_1']),
  });
  const r = ok(E.playCard(s, A, { cardId: 'm2_ribbon' }));
  assert.deepEqual(idsOf(r.captures[A]).sort(), ['m2_junk_1', 'm2_ribbon']);
  assert.ok(idsOf(r.field).includes('m5_junk_1'), 'flipped card lands');
  assert.equal(r.current, B);
  assert.equal(r.lastTurn.by, A);
  assert.equal(r.lastTurn.played.id, 'm2_ribbon');
  assert.equal(r.lastTurn.flipped.id, 'm5_junk_1');

  const s2 = table({ field: cards(['m2_junk_1']), hands: { [A]: cards(['m7_junk_1']), [B]: cards(['m10_junk_1']) }, deck: cards(['m5_junk_1']) });
  const r2 = ok(E.playCard(s2, A, { cardId: 'm7_junk_1' }));
  assert.ok(idsOf(r2.field).includes('m7_junk_1'));
});

test('engine refuses with codes, never English sentences', () => {
  const s = table({ hands: { [A]: cards(['m2_ribbon']), [B]: cards(['m10_junk_1']) }, deck: cards(['m5_junk_1']) });
  assert.equal(E.playCard(s, B, { cardId: 'm10_junk_1' }).reason, 'not_your_turn');
  assert.equal(E.playCard(s, A, { cardId: 'm3_bright' }).reason, 'card_not_in_hand');
  assert.equal(E.declare(s, A, 'go').reason, 'invalid_phase');
  assert.equal(E.choose(s, A, 'x').reason, 'invalid_phase');
  assert.equal(E.playDotan(s, A).reason, 'no_dotan');
  assert.equal(E.playBomb(s, A, 2).reason, 'cannot_bomb');
  for (const reason of Object.keys(E.REASONS)) assert.match(reason, /^[a-z_]+$/);
});

test('쪽: a lone card plus the same month flipped are both taken and 1 피 is stolen', () => {
  const s = table({
    field: cards(['m2_junk_1']),
    hands: { [A]: cards(['m7_junk_1', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m4_junk_1', 'm7_junk_2']),
    captures: { [A]: [], [B]: cards(['m11_junk_d', 'm8_junk_1']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm7_junk_1' }));
  assert.ok(r.lastTurn.events.includes('jjok'));
  assert.deepEqual(idsOf(r.captures[A]).sort(), ['m7_junk_1', 'm7_junk_2', 'm8_junk_1'], 'plain 피 is stolen before 쌍피');
  assert.deepEqual(idsOf(r.lastTurn.stolen), ['m8_junk_1']);
});

test('뻑: pairing one card then flipping the same month leaves all three, marked by the 뻑 pile', () => {
  const s = table({
    field: cards(['m3_junk_1', 'm4_junk_1']),
    hands: { [A]: cards(['m3_ribbon', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m6_junk_1', 'm3_junk_2']),
  });
  const r = ok(E.playCard(s, A, { cardId: 'm3_ribbon' }));
  assert.ok(r.lastTurn.events.includes('ppeok'));
  assert.equal(r.field.filter(c => c.month === 3).length, 3);
  assert.deepEqual(r.ppeok, { 3: A });
  assert.equal(r.captures[A].length, 0);
});

test('뻑 가져오기: taking the 뻑 pile steals 1 피 and clears the marker', () => {
  const s = table({
    field: cards(['m3_junk_1', 'm3_ribbon', 'm3_junk_2', 'm4_junk_1']),
    ppeok: { 3: A },
    hands: { [A]: cards(['m1_junk_1']), [B]: cards(['m3_bright', 'm10_junk_1']) },
    current: B,
    deck: cards(['m6_junk_1', 'm9_junk_1']),
    captures: { [A]: cards(['m8_junk_1']), [B]: [] },
  });
  const r = ok(E.playCard(s, B, { cardId: 'm3_bright' }));
  assert.ok(r.lastTurn.events.includes('ppeok_take'));
  assert.equal(r.captures[B].filter(c => c.month === 3).length, 4);
  assert.deepEqual(r.ppeok, {});
  assert.ok(idsOf(r.captures[B]).includes('m8_junk_1'));
});

test('따닥: one of two taken by hand, then the flip takes the rest and steals 1 피', () => {
  const s = table({
    field: cards(['m4_junk_1', 'm4_junk_2', 'm6_junk_1']),
    hands: { [A]: cards(['m4_animal', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm4_ribbon']),
    captures: { [A]: [], [B]: cards(['m8_junk_1']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm4_animal' }));
  assert.ok(r.lastTurn.events.includes('ttadak'));
  assert.equal(r.captures[A].filter(c => c.month === 4).length, 4);
  assert.ok(idsOf(r.captures[A]).includes('m8_junk_1'));
});

// ── G6: 손패 두 장 매치 선택 ─────────────────────────────────────
test('G6: a hand card matching two different field cards waits for the player to choose', () => {
  const s = table({
    field: cards(['m8_bright', 'm8_junk_1', 'm2_junk_1']),
    hands: { [A]: cards(['m8_junk_2', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm6_junk_1']),
  });
  const waiting = ok(E.playCard(s, A, { cardId: 'm8_junk_2' }));
  assert.equal(waiting.phase, 'choice');
  assert.equal(waiting.pending.kind, 'hand');
  assert.equal(waiting.current, A);
  assert.deepEqual(idsOf(waiting.pending.options).sort(), ['m8_bright', 'm8_junk_1']);
  assert.equal(waiting.deck.length, 2, 'nothing is flipped before the choice');
  assert.equal(E.choose(waiting, B, 'm8_junk_1').reason, 'not_your_turn');
  assert.equal(E.choose(waiting, A, 'm2_junk_1').reason, 'invalid_choice');
  const r = ok(E.choose(waiting, A, 'm8_junk_1'));
  assert.deepEqual(idsOf(r.captures[A]).sort(), ['m8_junk_1', 'm8_junk_2']);
  assert.ok(idsOf(r.field).includes('m8_bright'));
  assert.equal(r.current, B);
});

test('G6: a target sent with the card skips the wait; equal options never ask', () => {
  const s = table({
    field: cards(['m8_bright', 'm8_junk_1']),
    hands: { [A]: cards(['m8_junk_2', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm6_junk_1']),
  });
  const r = ok(E.playCard(s, A, { cardId: 'm8_junk_2', targetId: 'm8_bright' }));
  assert.ok(idsOf(r.captures[A]).includes('m8_bright'));

  const same = table({
    field: cards(['m9_junk_1', 'm9_junk_2']),
    hands: { [A]: cards(['m9_animal', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m4_junk_1', 'm6_junk_1']),
  });
  const auto = ok(E.playCard(same, A, { cardId: 'm9_animal' }));
  assert.equal(auto.phase, 'playing');
  assert.equal(auto.captures[A].length, 2);
});

test('G6: a flipped card matching two different field cards waits for a deck choice', () => {
  const s = table({
    field: cards(['m12_bright', 'm12_junk_d', 'm2_junk_1']),
    hands: { [A]: cards(['m1_junk_1', 'm1_junk_2']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm12_animal']),
  });
  const waiting = ok(E.playCard(s, A, { cardId: 'm1_junk_1' }));
  assert.equal(waiting.phase, 'choice');
  assert.equal(waiting.pending.kind, 'deck');
  assert.equal(waiting.pending.card.id, 'm12_animal');
  const r = ok(E.choose(waiting, A, 'm12_junk_d'));
  assert.ok(idsOf(r.captures[A]).includes('m12_junk_d'));
  assert.equal(r.current, B);
});

test('G6/G11: the automatic choice takes the option worth more points', () => {
  const s = table({
    field: cards(['m8_bright', 'm8_junk_1']),
    hands: { [A]: cards(['m8_junk_2', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm6_junk_1']),
    captures: { [A]: cards(['m1_bright', 'm3_bright']), [B]: [] },
  });
  const waiting = ok(E.playCard(s, A, { cardId: 'm8_junk_2' }));
  const action = E.autoAction(waiting);
  assert.deepEqual(action, { type: 'choose', cardId: 'm8_bright' });
});

// ── G1: 쓸은 턴 끝 판정 ─────────────────────────────────────────
test('G1: emptying the field with the hand card is not 쓸 when the flipped card stays', () => {
  const s = table({
    field: cards(['m5_junk_1']),
    hands: { [A]: cards(['m5_junk_2', 'm1_junk_1']), [B]: cards(['m2_junk_1', 'm3_junk_1']) },
    deck: cards(['m9_junk_1', 'm9_junk_2']),
    captures: { [A]: [], [B]: cards(['m4_junk_1', 'm4_junk_2']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm5_junk_2' }));
  assert.ok(!r.lastTurn.events.includes('sseul'));
  assert.deepEqual(idsOf(r.field), ['m9_junk_2']);
  assert.equal(r.captures[B].length, 2, 'no 피 stolen');
});

test('G1: sweeping a three-stack is not 쓸 when the flipped card stays', () => {
  const s = table({
    field: cards(['m5_junk_1', 'm5_ribbon', 'm5_animal']),
    hands: { [A]: cards(['m5_junk_2', 'm1_junk_1']), [B]: cards(['m2_junk_1', 'm3_junk_1']) },
    deck: cards(['m9_junk_1', 'm9_junk_2']),
    captures: { [A]: [], [B]: cards(['m4_junk_1', 'm4_junk_2']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm5_junk_2' }));
  assert.ok(!r.lastTurn.events.includes('sseul'));
  assert.equal(r.captures[B].length, 2);
});

test('G1: an empty field at the end of the turn is 쓸 and steals 1 피', () => {
  const s = table({
    field: cards(['m5_junk_1', 'm9_junk_1']),
    hands: { [A]: cards(['m5_junk_2', 'm1_junk_1']), [B]: cards(['m2_junk_1', 'm3_junk_1']) },
    deck: cards(['m6_junk_1', 'm9_junk_2']),
    captures: { [A]: [], [B]: cards(['m4_junk_1', 'm4_junk_2']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm5_junk_2' }));
  assert.equal(r.field.length, 0);
  assert.ok(r.lastTurn.events.includes('sseul'));
  assert.equal(r.captures[B].length, 1);
});

test('G1: the very last turn of the game never counts as 쓸', () => {
  const s = table({
    field: cards(['m5_junk_1', 'm9_junk_1']),
    hands: { [A]: cards(['m5_junk_2']), [B]: [] },
    deck: cards(['m9_junk_2']),
    captures: { [A]: [], [B]: cards(['m4_junk_1', 'm4_junk_2']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm5_junk_2' }));
  assert.equal(r.field.length, 0);
  assert.ok(!r.lastTurn.events.includes('sseul'));
  assert.equal(r.captures[B].length, 2);
});

// ── G2: 마지막 턴 ─────────────────────────────────────────────────
test('G2: on the final turn only the player who just scored can win (the stalled go-caller pays 고박)', () => {
  const Acap = cards(['m1_bright', 'm3_bright', 'm8_bright', 'm11_bright', 'm1_animal', 'm2_ribbon', 'm3_ribbon', 'm6_ribbon', 'm9_ribbon']);
  const Bcap = cards(['m2_animal', 'm4_animal', 'm8_animal', 'm5_animal', 'm9_animal']);
  let s = table({
    current: B,
    field: cards(['m10_junk_1']),
    hands: { [A]: [], [B]: cards(['m10_animal']) },
    deck: cards(['m7_junk_1']),
    captures: { [A]: Acap, [B]: Bcap },
    goCount: { [A]: 1, [B]: 0 },
  });
  s = { ...s, goScore: { [A]: s.scores[A].total, [B]: 0 } };
  assert.ok(s.scores[A].total > 7);
  assert.equal(s.scores[B].total, 6);
  const r = ok(E.playCard(s, B, { cardId: 'm10_animal' }));
  assert.equal(r.scores[B].total, 7);
  assert.equal(r.phase, 'finished');
  assert.equal(r.result.winner, B, 'the higher total of the stalled go-caller does not win');
  assert.equal(r.result.reason, 'auto_stop');
  assert.ok(r.result.multipliers.some(m => m.code === 'gobak' && m.factor === 2));
});

test('G2: a go-caller who never scores again before the cards run out → 나가리', () => {
  let s = table({
    current: B,
    field: cards(['m12_junk_d']),
    hands: { [A]: [], [B]: cards(['m4_junk_1']) },
    deck: cards(['m7_junk_1']),
    captures: { [A]: cards(SEVEN), [B]: [] },
    goCount: { [A]: 1, [B]: 0 },
  });
  s = { ...s, goScore: { [A]: s.scores[A].total, [B]: 0 } };
  const r = ok(E.playCard(s, B, { cardId: 'm4_junk_1' }));
  assert.equal(r.phase, 'nagari');
  assert.equal(r.result.reason, 'nagari');
  assert.equal(r.result.winner, null);
  assert.equal(r.result.amount, 0);
});

test('G2: nobody reaching 7 by the last card → 나가리', () => {
  const s = table({
    field: cards(['m12_junk_d']),
    hands: { [A]: cards(['m4_junk_1']), [B]: [] },
    deck: cards(['m7_junk_1']),
    captures: { [A]: cards(['m1_bright', 'm3_bright']), [B]: cards(['m8_bright', 'm11_bright']) },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm4_junk_1' }));
  assert.equal(r.phase, 'nagari');
});

test('G2: scoring with the last card in hand stops automatically (no go without cards)', () => {
  const s = table({
    field: cards(['m9_junk_1']),
    hands: { [A]: cards(['m9_ribbon']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m4_junk_1', 'm7_junk_1']),
    captures: { [A]: cards(['m1_bright', 'm3_bright', 'm8_bright', 'm1_animal', 'm2_ribbon', 'm3_ribbon', 'm6_ribbon']), [B]: [] },
  });
  const r = ok(E.playCard(s, A, { cardId: 'm9_ribbon' }));
  assert.equal(r.phase, 'finished');
  assert.equal(r.result.winner, A);
  assert.equal(r.result.reason, 'auto_stop');
});

test('reaching 7 with cards left asks go/stop; go needs a higher score before the next ask', () => {
  const s = table({
    field: cards(['m9_junk_1', 'm2_junk_1']),
    hands: { [A]: cards(['m9_ribbon', 'm5_junk_1', 'm6_junk_1']), [B]: cards(['m10_junk_1', 'm11_junk_1']) },
    deck: cards(['m4_junk_2', 'm8_junk_1', 'm4_junk_1', 'm7_junk_1']),
    captures: { [A]: cards(['m1_bright', 'm3_bright', 'm8_bright', 'm1_animal', 'm2_ribbon', 'm3_ribbon', 'm6_ribbon']), [B]: [] },
  });
  const asked = ok(E.playCard(s, A, { cardId: 'm9_ribbon' }));
  assert.equal(asked.phase, 'go_stop');
  assert.equal(asked.current, A);
  const went = ok(E.declare(asked, A, 'go'));
  assert.equal(went.goCount[A], 1);
  assert.equal(went.goScore[A], 7);
  assert.equal(went.current, B);
  assert.equal(went.lastTurn.kind, 'go');
  const bTurn = ok(E.playCard(went, B, { cardId: 'm10_junk_1' }));
  const again = ok(E.playCard(bTurn, A, { cardId: 'm5_junk_1' }));
  assert.equal(again.phase, 'playing', 'same score after a go → no new ask');
  assert.equal(again.current, B);
});

// ── G3: 고 점수·배수 ──────────────────────────────────────────────
for (const [go, points, factor] of [[1, 8, 1], [2, 9, 1], [3, 10, 2], [4, 11, 4], [5, 12, 8]]) {
  test(`G3: ${go}고 then stop at 7 → ${points} points ×${factor}`, () => {
    const s = table({
      phase: 'go_stop',
      captures: { [A]: cards(SEVEN), [B]: [card('m11_bright'), ...junks(8)] },
      goCount: { [A]: go, [B]: 0 },
      hands: { [A]: cards(['m10_junk_1']), [B]: cards(['m11_junk_1']) },
    });
    const r = ok(E.declare(s, A, 'stop'));
    assert.equal(r.result.points.base, 7);
    assert.equal(r.result.points.go, go);
    assert.equal(r.result.points.total, points);
    const goMult = r.result.multipliers.find(m => m.code === 'go');
    assert.equal(goMult?.factor ?? 1, factor);
    assert.equal(r.result.multiplier, factor);
    assert.equal(r.result.amount, points * factor * 100);
  });
}

// ── G4: 흔들기·폭탄은 선언한 사람이 이길 때만 ─────────────────────
test('G4: a shake doubles only when the shaker wins', () => {
  const stop = (winner, shakes) => ok(E.declare(table({
    phase: 'go_stop',
    current: winner,
    captures: { [winner]: cards(SEVEN), [winner === A ? B : A]: [card('m11_bright'), ...junks(8)] },
    shakes,
    hands: { [A]: cards(['m10_junk_1']), [B]: cards(['m11_junk_1']) },
  }), winner, 'stop')).result;
  assert.equal(stop(A, { [A]: [4], [B]: [] }).multiplier, 2);
  assert.equal(stop(B, { [A]: [4], [B]: [] }).multiplier, 1, "the loser's shake is worth nothing");
  assert.equal(stop(A, { [A]: [4, 5], [B]: [] }).multiplier, 4, 'each shake ×2');
});

test('G4: a bomb doubles only when the bomber wins', () => {
  const stop = (winner, bombs) => ok(E.declare(table({
    phase: 'go_stop',
    current: winner,
    captures: { [winner]: cards(SEVEN), [winner === A ? B : A]: [card('m11_bright'), ...junks(8)] },
    bombs,
    hands: { [A]: cards(['m10_junk_1']), [B]: cards(['m11_junk_1']) },
  }), winner, 'stop')).result;
  assert.equal(stop(A, { [A]: 1, [B]: 0 }).multiplier, 2);
  assert.equal(stop(B, { [A]: 1, [B]: 0 }).multiplier, 1);
});

// ── G5: 박 ────────────────────────────────────────────────────────
for (const [loserPi, expected] of [[0, true], [4, true], [5, true], [7, true], [8, false]]) {
  test(`G5: 피박 — winner scored with 피, loser holds ${loserPi} 피 → ${expected}`, () => {
    const s = table({ phase: 'go_stop', captures: { [A]: junks(10), [B]: junks(loserPi, 10) }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
    const r = ok(E.declare(s, A, 'stop'));
    assert.equal(r.result.multipliers.some(m => m.code === 'pibak'), expected);
  });
}

test('G5: no 피박 when the winner did not score with 피; 쌍피 counts as two', () => {
  const s = table({ phase: 'go_stop', captures: { [A]: cards(SEVEN), [B]: junks(2) }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  assert.equal(ok(E.declare(s, A, 'stop')).result.multipliers.some(m => m.code === 'pibak'), false);
  const d = table({ phase: 'go_stop', captures: { [A]: junks(10), [B]: [...junks(6, 10), card('m11_junk_d')] }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  assert.equal(ok(E.declare(d, A, 'stop')).result.multipliers.some(m => m.code === 'pibak'), false, '6 + 쌍피 = 8 피');
});

test('광박 when the winner scored with 광 and the loser has none; 고박 when the loser had called go', () => {
  const s = table({ phase: 'go_stop', captures: { [A]: cards(SEVEN), [B]: junks(8) }, goCount: { [A]: 0, [B]: 1 }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  const r = ok(E.declare(s, A, 'stop')).result;
  assert.ok(r.multipliers.some(m => m.code === 'gwangbak'));
  assert.ok(r.multipliers.some(m => m.code === 'gobak'));
  assert.equal(r.multiplier, 4);
  assert.equal(r.amount, 7 * 4 * 100);
  const no = table({ phase: 'go_stop', captures: { [A]: cards(SEVEN), [B]: cards(['m12_bright']) }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  assert.equal(ok(E.declare(no, A, 'stop')).result.multipliers.some(m => m.code === 'gwangbak'), false);
});

test('the receipt multiplies (score + go points) × every factor × per-point stake', () => {
  const s = table({
    phase: 'go_stop',
    perPointBet: 500,
    captures: { [A]: [...cards(['m1_bright', 'm3_bright', 'm8_bright']), ...junks(10)], [B]: junks(3, 10) },
    goCount: { [A]: 3, [B]: 0 },
    shakes: { [A]: [4], [B]: [] },
    bombs: { [A]: 1, [B]: 0 },
    hands: { [A]: cards(['m10_animal']), [B]: [] },
  });
  const r = ok(E.declare(s, A, 'stop')).result;
  // 광 3 + 피 1 = 4, 3고 +3 → 7점; 3고 ×2 · 흔들 ×2 · 폭탄 ×2 · 피박 ×2 · 광박 ×2 = ×32
  assert.equal(r.points.total, 7);
  assert.equal(r.multiplier, 32);
  assert.equal(r.amount, 7 * 32 * 500);
  assert.deepEqual(r.multipliers.map(m => m.code), ['go', 'shake', 'bomb', 'pibak', 'gwangbak']);
});

// ── G7: 폭탄과 도탄 ───────────────────────────────────────────────
test('G7: a bomb takes 3 + 1, steals 1 피, and leaves two flip-only turns (도탄)', () => {
  const s = table({
    field: cards(['m6_junk_1', 'm2_junk_1']),
    hands: { [A]: cards(['m6_animal', 'm6_ribbon', 'm6_junk_2', 'm1_junk_1']), [B]: cards(['m10_junk_1', 'm10_junk_2', 'm11_junk_1', 'm11_junk_2']) },
    deck: cards(['m4_junk_1', 'm4_junk_2', 'm5_junk_1', 'm5_junk_2', 'm7_junk_1', 'm7_junk_2', 'm9_junk_1', 'm9_junk_2']),
    captures: { [A]: [], [B]: cards(['m8_junk_1']) },
  });
  const r = ok(E.playBomb(s, A, 6));
  assert.ok(r.lastTurn.events.includes('bomb'));
  assert.equal(r.captures[A].filter(c => c.month === 6).length, 4);
  assert.ok(idsOf(r.captures[A]).includes('m8_junk_1'));
  assert.equal(r.dotan[A], 2);
  assert.equal(r.bombs[A], 1);
  assert.equal(r.hands[A].length, 1);
  const b1 = ok(E.playCard(r, B, { cardId: 'm10_junk_1' }));
  const d1 = ok(E.playDotan(b1, A));
  assert.equal(d1.dotan[A], 1);
  assert.equal(d1.lastTurn.kind, 'dotan');
  assert.equal(d1.lastTurn.played, null);
  assert.ok(d1.lastTurn.flipped);
  assert.equal(d1.hands[A].length, 1, 'a 도탄 turn plays no hand card');
});

test('G7: hands, 도탄 and the deck always run out together (3,000 random games, cards conserved)', () => {
  const random = seeded(2024);
  let bombGames = 0;
  for (let g = 0; g < 3000; g++) {
    let s = E.createGostopGameState(A, B, { random, starter: g % 2 ? A : B });
    let steps = 0;
    let bombed = false;
    while (!['finished', 'nagari'].includes(s.phase)) {
      assert.ok(++steps < 200, 'game must end');
      const p = s.current;
      let r;
      if (s.phase === 'chongtong') r = E.decideChongtong(s, p, false);
      else if (s.phase === 'choice') r = E.choose(s, p, s.pending.options[Math.floor(random() * 2)].id);
      else if (s.phase === 'go_stop') r = E.declare(s, p, random() < 0.5 ? 'go' : 'stop');
      else {
        const opts = E.legalMoves(s, p);
        if (opts.bombable.length) { r = E.playBomb(s, p, opts.bombable[0]); bombed = true; }
        else if (s.dotan[p] > 0 && random() < 0.5) r = E.playDotan(s, p);
        else if (s.hands[p].length) {
          const c = s.hands[p][Math.floor(random() * s.hands[p].length)];
          r = E.playCard(s, p, { cardId: c.id, shake: opts.shakeable.includes(c.month) && random() < 0.5 });
        } else r = E.playDotan(s, p);
      }
      s = ok(r);
      const all = [...s.deck, ...s.field, ...s.hands[A], ...s.hands[B], ...s.captures[A], ...s.captures[B], ...(s.pending ? [s.pending.card] : [])];
      assert.equal(all.length, 48, `cards conserved (game ${g}, step ${steps})`);
      assert.equal(new Set(idsOf(all)).size, 48);
    }
    if (bombed) bombGames++;
    if (s.phase === 'nagari') {
      assert.equal(s.hands[A].length + s.hands[B].length + s.dotan[A] + s.dotan[B], 0, 'nagari only when every turn is used');
      assert.equal(s.deck.length, 0, 'nothing left in the pile at 나가리');
    }
  }
  assert.ok(bombGames > 20, `bombs were exercised (${bombGames})`);
});

// ── G8: 흔들기는 그 월 패를 낼 때 ─────────────────────────────────
test('G8: a shake is declared while playing a card of the three-card month', () => {
  const s = table({
    field: cards(['m2_junk_1']),
    hands: { [A]: cards(['m4_animal', 'm4_ribbon', 'm4_junk_1', 'm1_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1', 'm6_junk_1']),
  });
  assert.deepEqual(E.legalMoves(s, A).shakeable, [4]);
  const r = ok(E.playCard(s, A, { cardId: 'm4_animal', shake: true }));
  assert.deepEqual(r.shakes[A], [4]);
  assert.ok(r.lastTurn.events.includes('shake'));
  assert.deepEqual(idsOf(r.lastTurn.shown).sort(), ['m4_animal', 'm4_junk_1', 'm4_ribbon']);
  assert.equal(E.playCard(s, A, { cardId: 'm1_junk_1', shake: true }).reason, 'cannot_shake');
});

test('G8: no shake when the field already holds that month (that is a bomb)', () => {
  const s = table({
    field: cards(['m4_junk_2']),
    hands: { [A]: cards(['m4_animal', 'm4_ribbon', 'm4_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1']),
  });
  assert.deepEqual(E.legalMoves(s, A).shakeable, []);
  assert.deepEqual(E.legalMoves(s, A).bombable, [4]);
  assert.equal(E.playCard(s, A, { cardId: 'm4_animal', shake: true }).reason, 'cannot_shake');
});

// ── G11: 자동 행동 ────────────────────────────────────────────────
test('G11: the automatic action stops at go/stop, takes 총통, never shakes, and plays the coach card', () => {
  const gs = table({ phase: 'go_stop', captures: { [A]: cards(SEVEN), [B]: [] }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  assert.deepEqual(E.autoAction(gs), { type: 'decide', decision: 'stop' });
  const ct = E.createGostopGameState(A, B, { decks: [E.buildDeck({ a: ['m5_animal', 'm5_ribbon', 'm5_junk_1', 'm5_junk_2'] })], starter: B });
  assert.deepEqual(E.autoAction(ct), { type: 'chongtong', declare: true });
  const play = table({
    field: cards(['m3_bright']),
    hands: { [A]: cards(['m4_animal', 'm4_ribbon', 'm4_junk_1', 'm3_junk_1']), [B]: cards(['m10_junk_1']) },
    deck: cards(['m9_junk_1']),
  });
  const a = E.autoAction(play);
  assert.deepEqual(a, { type: 'play', cardId: 'm3_junk_1' }, 'takes the 광 rather than throwing a card away');
  assert.equal(E.recommendMove(play, A).cardId, 'm3_junk_1');
  const applied = ok(E.applyAuto(play));
  assert.deepEqual(applied.shakes[A], [], 'automatic play never shakes');
  assert.equal(applied.lastTurn.auto, true);
});

test('G11: with nothing to take, a 도탄 is used instead of throwing a card away', () => {
  const s = table({
    field: cards(['m3_bright']),
    dotan: { [A]: 1, [B]: 0 },
    hands: { [A]: cards(['m4_junk_1']), [B]: cards(['m10_junk_1', 'm11_junk_1']) },
    deck: cards(['m9_junk_1', 'm7_junk_1']),
  });
  assert.deepEqual(E.autoAction(s), { type: 'dotan' });
});

// ── 기권 ─────────────────────────────────────────────────────────
test('forfeit pays the winner real score and multipliers (not a fixed 7)', () => {
  const s = table({
    captures: { [A]: cards(['m1_bright', 'm3_bright', 'm8_bright']), [B]: junks(4) },
    goCount: { [A]: 0, [B]: 1 },
    shakes: { [A]: [9], [B]: [] },
    hands: { [A]: cards(['m10_animal']), [B]: cards(['m11_junk_1']) },
  });
  const r = ok(E.forfeit(s, B));
  assert.equal(r.result.reason, 'forfeit');
  assert.equal(r.result.winner, A);
  assert.equal(r.result.points.total, 3);
  // 흔들 ×2 · 광박 ×2 · 고박 ×2
  assert.equal(r.result.multiplier, 8);
  assert.equal(r.result.amount, 3 * 8 * 100);
  const zero = ok(E.forfeit(table({ hands: { [A]: cards(['m10_animal']), [B]: cards(['m11_junk_1']) } }), A));
  assert.equal(zero.result.winner, B);
  assert.equal(zero.result.amount, 0);
});

test('a finished game refuses every action', () => {
  const s = ok(E.forfeit(table({ hands: { [A]: cards(['m10_animal']), [B]: cards(['m11_junk_1']) } }), A));
  assert.equal(E.playCard(s, B, { cardId: 'm11_junk_1' }).reason, 'game_over');
  assert.equal(E.declare(s, B, 'stop').reason, 'game_over');
  assert.equal(E.forfeit(s, B).reason, 'game_over');
});

// ── 미리보기·직렬화 ──────────────────────────────────────────────
test('the stop/go preview shows the payout now and after one more point with one more go', () => {
  const s = table({ phase: 'go_stop', captures: { [A]: cards(SEVEN), [B]: junks(8) }, goCount: { [A]: 2, [B]: 0 }, hands: { [A]: cards(['m10_animal']), [B]: [] } });
  const p = E.goStopPreview(s, A);
  assert.equal(p.stopNow.amount, ok(E.declare(s, A, 'stop')).result.amount);
  assert.equal(p.stopNow.points.total, 9);
  // 3고 + 8점 = 11점 × 2(3고) × 2(광박) = 44
  assert.equal(p.afterGo.points.total, 11);
  assert.equal(p.afterGo.amount, 11 * 4 * 100);
});

test('serializeFor hides the opponent hand and the pile order, and gives the actor its options', () => {
  const s = table({
    field: cards(['m2_junk_1']),
    hands: { [A]: cards(['m4_animal', 'm4_ribbon', 'm4_junk_1', 'm2_ribbon']), [B]: cards(['m10_junk_1', 'm11_junk_1']) },
    deck: cards(['m9_junk_1', 'm6_junk_1']),
  });
  const forA = E.serializeFor(s, A);
  assert.equal(forA.hand.length, 4);
  assert.equal(forA.hands, undefined);
  assert.equal(forA.deck, undefined);
  assert.deepEqual(forA.handCount, { [A]: 4, [B]: 2 });
  assert.equal(forA.deckCount, 2);
  assert.deepEqual(forA.moves.shakeable, [4]);
  assert.ok(forA.coach.cardId);
  assert.ok(forA.projection[A]);
  const forB = E.serializeFor(s, B);
  assert.deepEqual(idsOf(forB.hand).sort(), ['m10_junk_1', 'm11_junk_1']);
  assert.equal(forB.moves, null, 'not B’s turn');
  assert.equal(forB.coach, null);
  assert.ok(!JSON.stringify(forB).includes('m4_animal'));
  assert.ok(!JSON.stringify(forB).includes('m9_junk_1'));
});

test('serializeFor keeps the 총통 month private to its holder', () => {
  const ct = E.createGostopGameState(A, B, { decks: [E.buildDeck({ a: ['m5_animal', 'm5_ribbon', 'm5_junk_1', 'm5_junk_2'] })], starter: B });
  assert.deepEqual(E.serializeFor(ct, A).chongtong, { player: A, month: 5 });
  assert.deepEqual(E.serializeFor(ct, B).chongtong, { player: A, month: null });
});
