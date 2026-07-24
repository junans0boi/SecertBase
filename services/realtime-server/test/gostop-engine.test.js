import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createHwatuDeck,
  createGostopGameState,
  calculateScore,
  playHandCard,
  selectDeckCapture,
  declareGoStop,
  currentPlayer,
  serializeGostopGame,
} from '../src/gostop-engine.js';

const P1 = 'player1';
const P2 = 'player2';

// ── 덱 기본 ──────────────────────────────────────────────────────
test('deck has 48 unique cards', () => {
  const deck = createHwatuDeck();
  assert.equal(deck.length, 48);
  const ids = new Set(deck.map(c => c.id));
  assert.equal(ids.size, 48);
});

test('deck has 5 brights, 11 animals, 8 ribbons, 24 junks', () => {
  const deck = createHwatuDeck();
  assert.equal(deck.filter(c => c.type === 'bright').length, 5);
  assert.equal(deck.filter(c => c.type === 'animal').length, 11);
  assert.equal(deck.filter(c => c.type === 'ribbon').length, 8);
  assert.equal(deck.filter(c => c.type === 'junk').length, 24);
});

test('deck has exactly 4 cards per month', () => {
  const deck = createHwatuDeck();
  for (let m = 1; m <= 12; m++) {
    assert.equal(deck.filter(c => c.month === m).length, 4, `month ${m}`);
  }
});

test('deck has 2 double-junk (쌍피) cards: month 11 and 12', () => {
  const deck = createHwatuDeck();
  const ssangpi = deck.filter(c => c.subtype === 'double');
  assert.equal(ssangpi.length, 2);
  assert.ok(ssangpi.some(c => c.month === 11));
  assert.ok(ssangpi.some(c => c.month === 12));
});

// ── 점수 계산 ─────────────────────────────────────────────────────
test('광 3장 = 3점, 비광 포함 시 2점', () => {
  const brights3 = [
    { id: 'm1_bright', month: 1, type: 'bright', subtype: null },
    { id: 'm3_bright', month: 3, type: 'bright', subtype: null },
    { id: 'm8_bright', month: 8, type: 'bright', subtype: null },
  ];
  assert.equal(calculateScore(brights3).gwangScore, 3);

  const withRain = [
    { id: 'm1_bright', month: 1, type: 'bright', subtype: null },
    { id: 'm3_bright', month: 3, type: 'bright', subtype: null },
    { id: 'm11_bright', month: 11, type: 'bright', subtype: 'rain' },
  ];
  assert.equal(calculateScore(withRain).gwangScore, 2);
});

test('광 5장 = 15점, 비광 포함 시 14점', () => {
  const all5 = [
    { id: 'm1_bright', month: 1,  type: 'bright', subtype: null },
    { id: 'm3_bright', month: 3,  type: 'bright', subtype: null },
    { id: 'm8_bright', month: 8,  type: 'bright', subtype: null },
    { id: 'm11_bright',month: 11, type: 'bright', subtype: 'rain' },
    { id: 'm12_bright',month: 12, type: 'bright', subtype: null },
  ];
  assert.equal(calculateScore(all5).gwangScore, 14);

  const noRain = all5.map(c => c.month === 11 ? { ...c, subtype: null } : c);
  assert.equal(calculateScore(noRain).gwangScore, 15);
});

test('열끗 5장=1점, 6장=2점', () => {
  const make = (n) => Array.from({ length: n }, (_, i) =>
    ({ id: `a${i}`, month: i + 1, type: 'animal', subtype: null }));
  assert.equal(calculateScore(make(4)).animScore, 0);
  assert.equal(calculateScore(make(5)).animScore, 1);
  assert.equal(calculateScore(make(6)).animScore, 2);
});

test('단 5장=1점, 홍단 세트 보너스 +3', () => {
  const ribbons = [
    { id: 'm2_ribbon', month: 2,  type: 'ribbon', subtype: 'red' },
    { id: 'm3_ribbon', month: 3,  type: 'ribbon', subtype: 'red' },
    { id: 'm10_ribbon',month: 10, type: 'ribbon', subtype: 'red' },
    { id: 'm4_ribbon', month: 4,  type: 'ribbon', subtype: 'blue' },
    { id: 'm9_ribbon', month: 9,  type: 'ribbon', subtype: null },
  ];
  const s = calculateScore(ribbons);
  assert.equal(s.ribScore, 1);
  assert.equal(s.hongdanBonus, 3);
  assert.equal(s.cheongdanBonus, 0);
});

test('청단 세트 보너스 +3', () => {
  const ribbons = [
    { id: 'm4_ribbon', month: 4, type: 'ribbon', subtype: 'blue' },
    { id: 'm5_ribbon', month: 5, type: 'ribbon', subtype: 'blue' },
    { id: 'm6_ribbon', month: 6, type: 'ribbon', subtype: 'blue' },
    { id: 'm2_ribbon', month: 2, type: 'ribbon', subtype: 'red' },
    { id: 'm3_ribbon', month: 3, type: 'ribbon', subtype: 'red' },
  ];
  const s = calculateScore(ribbons);
  assert.equal(s.cheongdanBonus, 3);
});

test('피 10개=1점, 쌍피는 2개로 계산', () => {
  const makePi = (n, hasDouble = false) =>
    Array.from({ length: n }, (_, i) =>
      ({ id: `p${i}`, month: i + 1, type: 'junk',
         subtype: (hasDouble && i === 0) ? 'double' : null }));
  assert.equal(calculateScore(makePi(9)).piScore, 0);
  assert.equal(calculateScore(makePi(10)).piScore, 1);
  // 쌍피 1 + 일반피 8 = 실질 10 → 1점
  const withDouble = [
    { id: 'pd', month: 11, type: 'junk', subtype: 'double' },
    ...Array.from({ length: 8 }, (_, i) => ({ id: `p${i}`, month: i + 1, type: 'junk', subtype: null })),
  ];
  assert.equal(calculateScore(withDouble).piScore, 1);
});

// ── 게임 생성 ─────────────────────────────────────────────────────
test('createGostopGameState deals 10 to each player, 8 to field, 20 in deck', () => {
  for (let i = 0; i < 10; i++) {
    const s = createGostopGameState(P1, P2);
    if (s.phase === 'finished') continue; // 총통 재 생성
    assert.equal(s.hands[P1].length, 10, 'p1 hand');
    assert.equal(s.hands[P2].length, 10, 'p2 hand');
    assert.equal(s.field.length, 8, 'field');
    assert.equal(s.deck.length, 20, 'deck');
    const total = s.hands[P1].length + s.hands[P2].length +
                  s.field.length + s.deck.length +
                  s.captures[P1].length + s.captures[P2].length;
    assert.equal(total, 48, 'total cards');
  }
});

test('initial scores are zero', () => {
  const s = createGostopGameState(P1, P2);
  if (s.phase === 'finished') return;
  assert.equal(s.scores[P1].total, 0);
  assert.equal(s.scores[P2].total, 0);
});

test('initial goCount is zero', () => {
  const s = createGostopGameState(P1, P2);
  if (s.phase === 'finished') return;
  assert.equal(s.goCount[P1], 0);
  assert.equal(s.goCount[P2], 0);
});

// ── 손패 카드 내기 ──────────────────────────────────────────────
function makeState(overrides = {}) {
  // 완전 제어 가능한 상태 생성
  const deck = [
    { id: 'm5_junk_1', month: 5, type: 'junk', subtype: null },
    { id: 'm9_animal', month: 9, type: 'animal', subtype: null },
  ];
  return {
    phase: 'playing',
    players: [P1, P2],
    currentPlayerIdx: 0,
    deck,
    field: [
      { id: 'm2_junk_1', month: 2, type: 'junk', subtype: null },
      { id: 'm3_junk_1', month: 3, type: 'junk', subtype: null },
    ],
    hands: {
      [P1]: [
        { id: 'm2_ribbon', month: 2, type: 'ribbon', subtype: 'red' },
        { id: 'm7_junk_1', month: 7, type: 'junk', subtype: null },
      ],
      [P2]: [],
    },
    captures: { [P1]: [], [P2]: [] },
    goCount: { [P1]: 0, [P2]: 0 },
    baseMultiplier: 1,
    shakeMultiplier: 1,
    shakers: [],
    chongtong: null,
    lastEvents: [],
    pending: null,
    scores: { [P1]: calculateScore([]), [P2]: calculateScore([]) },
    winner: null,
    loser: null,
    settlement: null,
    turn: 1,
    perPointBet: 100,
    ...overrides,
  };
}

test('playing a matching card captures field card', () => {
  const s = makeState();
  // P1 plays m2_ribbon, field has m2_junk_1
  const s2 = playHandCard(s, P1, 'm2_ribbon');
  // captured m2_ribbon + m2_junk_1 (plus any deck resolution)
  const captured = s2.captures[P1];
  assert.ok(captured.some(c => c.id === 'm2_ribbon'), 'hand card in captures');
  assert.ok(captured.some(c => c.id === 'm2_junk_1'), 'field card in captures');
});

test('playing a non-matching card places it on field', () => {
  const s = makeState();
  // P1 plays m7_junk_1, field has no month 7
  const s2 = playHandCard(s, P1, 'm7_junk_1');
  // m7 not captured; may be on field or deckcard captured/placed
  assert.ok(!s2.captures[P1].some(c => c.id === 'm7_junk_1'),
    'm7 should not be in captures immediately');
});

test('wrong player cannot play', () => {
  const s = makeState();
  assert.throws(() => playHandCard(s, P2, 'm2_ribbon'), /not your turn/);
});

test('card not in hand throws', () => {
  const s = makeState();
  assert.throws(() => playHandCard(s, P1, 'bad_card'), /card not in hand/);
});

test('deck_choice phase requires selectDeckCapture', () => {
  // 바닥에 같은 월 2장 → 덱 카드와 따닥 선택
  const state = makeState({
    deck: [{ id: 'm2_animal', month: 2, type: 'animal', subtype: null }],
    field: [
      { id: 'm2_junk_1', month: 2, type: 'junk', subtype: null },
      { id: 'm2_junk_2', month: 2, type: 'junk', subtype: null },
      { id: 'm3_junk_1', month: 3, type: 'junk', subtype: null },
    ],
    hands: {
      [P1]: [{ id: 'm6_junk_1', month: 6, type: 'junk', subtype: null }],
      [P2]: [],
    },
  });
  // P1 plays m6 (no match) → goes to field
  // deck flip: m2_animal → field has 2 x month-2 → deck_choice
  const s2 = playHandCard(state, P1, 'm6_junk_1');
  assert.equal(s2.phase, 'deck_choice');
  assert.ok(s2.pending?.fieldOptions?.length === 2);

  // resolve selection
  const s3 = selectDeckCapture(s2, P1, 'm2_junk_1');
  assert.ok(s3.captures[P1].some(c => c.id === 'm2_animal'));
  assert.ok(s3.captures[P1].some(c => c.id === 'm2_junk_1'));
  // other field card remains on field
  assert.ok(s3.field.some(c => c.id === 'm2_junk_2'));
});

test('after turn, currentPlayer switches', () => {
  const s = makeState();
  const s2 = playHandCard(s, P1, 'm2_ribbon');
  if (s2.phase === 'playing') {
    assert.equal(s2.currentPlayerIdx, 1);
  }
});

// ── 고/스톱 ────────────────────────────────────────────────────
test('declareGoStop stop → finished', () => {
  const s = makeState({
    phase: 'go_stop_choice',
    scores: {
      [P1]: { total: 7, gwangScore: 0, gwangCount: 0, hasRain: false,
               animScore: 0, animCount: 0, ribScore: 0, ribCount: 0,
               hongdanBonus: 0, cheongdanBonus: 0, piScore: 0, piTotal: 0 },
      [P2]: calculateScore([]),
    },
    captures: {
      [P1]: Array.from({ length: 7 }, (_, i) =>
        ({ id: `a${i}`, month: i + 1, type: 'animal', subtype: null })),
      [P2]: [],
    },
  });
  const s2 = declareGoStop(s, P1, 'stop');
  assert.equal(s2.phase, 'finished');
  assert.equal(s2.winner, P1);
  assert.equal(s2.loser, P2);
  assert.ok(s2.settlement != null);
  assert.ok(s2.settlement.amount >= 0);
});

test('declareGoStop go → increments goCount, next turn', () => {
  const s = makeState({ phase: 'go_stop_choice' });
  const s2 = declareGoStop(s, P1, 'go');
  assert.equal(s2.goCount[P1], 1);
  assert.equal(s2.phase, 'playing');
  assert.equal(s2.currentPlayerIdx, 1); // next player
});

// ── 정산 배수 ─────────────────────────────────────────────────────
test('settlement: GO 1회는 ×2 배수', () => {
  const base = makeState({
    phase: 'go_stop_choice',
    goCount: { [P1]: 1, [P2]: 0 },
    perPointBet: 100,
    scores: {
      [P1]: { total: 8, gwangScore: 0, gwangCount: 0, hasRain: false,
               animScore: 0, animCount: 0, ribScore: 0, ribCount: 0,
               hongdanBonus: 0, cheongdanBonus: 0, piScore: 0, piTotal: 0 },
      [P2]: calculateScore([]),
    },
    captures: { [P1]: [], [P2]: [] },
  });
  const s2 = declareGoStop(base, P1, 'stop');
  // 8점 × 100 × baseMultiplier(1) × shakeMultiplier(1) × goBonus(2) = 1600
  assert.equal(s2.settlement.amount, 1600);
  assert.equal(s2.settlement.multiplier, 2);
});

test('settlement: 나가리 이월 baseMultiplier 반영', () => {
  const s = makeState({
    phase: 'go_stop_choice',
    baseMultiplier: 2,
    perPointBet: 100,
    scores: {
      [P1]: { total: 7, gwangScore: 0, gwangCount: 0, hasRain: false,
               animScore: 0, animCount: 0, ribScore: 0, ribCount: 0,
               hongdanBonus: 0, cheongdanBonus: 0, piScore: 0, piTotal: 0 },
      [P2]: calculateScore([]),
    },
    captures: { [P1]: [], [P2]: [] },
  });
  const s2 = declareGoStop(s, P1, 'stop');
  assert.equal(s2.settlement.multiplier, 2);
  assert.equal(s2.settlement.amount, 1400); // 7 × 100 × 2
});

test('settlement: 피박 ×2', () => {
  const winners10pi = Array.from({ length: 10 }, (_, i) =>
    ({ id: `j${i}`, month: (i % 12) + 1, type: 'junk', subtype: null }));
  const s = makeState({
    phase: 'go_stop_choice',
    perPointBet: 100,
    scores: {
      [P1]: { total: 7, gwangScore: 0, gwangCount: 0, hasRain: false,
               animScore: 0, animCount: 0, ribScore: 0, ribCount: 0,
               hongdanBonus: 0, cheongdanBonus: 0, piScore: 1, piTotal: 10 },
      [P2]: { total: 0, gwangScore: 0, gwangCount: 0, hasRain: false,
               animScore: 0, animCount: 0, ribScore: 0, ribCount: 0,
               hongdanBonus: 0, cheongdanBonus: 0, piScore: 0, piTotal: 3 },
    },
    captures: { [P1]: winners10pi, [P2]: [] },
  });
  const s2 = declareGoStop(s, P1, 'stop');
  assert.equal(s2.settlement.pibak, true);
  assert.equal(s2.settlement.multiplier, 2); // 피박 ×2
  assert.equal(s2.settlement.amount, 1400); // 7 × 100 × 2
});

// ── 직렬화 ────────────────────────────────────────────────────────
test('serializeGostopGame hides deck card faces', () => {
  const s = createGostopGameState(P1, P2);
  if (s.phase === 'finished') return;
  const serialized = serializeGostopGame(s);
  assert.ok(serialized.deck.every(c => c.id === 'back'));
});

test('nageori when deck runs out with no winner', () => {
  const s = makeState({
    deck: [],
    field: [],
    hands: { [P1]: [], [P2]: [] },
    captures: { [P1]: [], [P2]: [] },
    scores: { [P1]: calculateScore([]), [P2]: calculateScore([]) },
  });
  // With empty deck, _checkNageori should trigger
  // Since deck is empty and no match, after playHandCard the deck resolution yields nageori
  // But hands are empty — in normal play hand won't be empty; test _checkNageori directly
  // Instead, create a state where deck flip triggers nageori
  const st2 = makeState({
    deck: [{ id: 'm5_junk_1', month: 5, type: 'junk', subtype: null }],
    field: [],
    scores: { [P1]: calculateScore([]), [P2]: calculateScore([]) },
  });
  const s2 = playHandCard(st2, P1, 'm2_ribbon');
  // after deck flip deck is now empty; neither player at 7 pts → nageori
  assert.equal(s2.phase, 'nageori');
  assert.equal(s2.baseMultiplier, 2); // 이월 ×2
});
