import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  CATCH_ROUND_MS, SEEN_LIMIT, WORD_BANK, autoHintsDue, difficultyForRound, guessPoints, hintOrder, hintTiles,
  judgeGuess, maxHintReveals, nextAutoHintRemaining, normalizeAnswer, pickWord, rememberSeen, validateWordBank, winnerOf,
} from '../src/catch-engine.js';

const rawBank = JSON.parse(readFileSync(new URL('../src/data/catch-words.json', import.meta.url), 'utf8'));

function seeded(seed = 7) {
  let s = seed;
  return () => { s = (s * 1664525 + 1013904223) % 4294967296; return s / 4294967296; };
}

test('word bank: about 1,500 unique Korean words, 20 categories, spread over three difficulties', () => {
  assert.doesNotThrow(() => validateWordBank(rawBank));
  assert.ok(WORD_BANK.length >= 1400 && WORD_BANK.length <= 1600, `size ${WORD_BANK.length}`);
  const words = WORD_BANK.map((e) => e.w);
  assert.equal(new Set(words).size, words.length, 'unique');
  for (const e of WORD_BANK) {
    assert.match(e.w, /^[가-힣]+$/u, e.w);
    assert.ok(!/\s/u.test(e.w));
    for (const a of e.aliases) assert.match(a, /^[가-힣]+$/u, `${e.w} alias ${a}`);
  }
  const cats = new Map();
  for (const e of WORD_BANK) cats.set(e.cat, (cats.get(e.cat) ?? 0) + 1);
  assert.equal(cats.size, 20);
  for (const [cat, n] of cats) assert.ok(n >= 55 && n <= 90, `${cat}: ${n}`);
  const diff = [1, 2, 3].map((d) => WORD_BANK.filter((e) => e.diff === d).length);
  assert.ok(diff[0] >= 500, `easy ${diff[0]}`);
  assert.ok(diff[1] >= 400 && diff[2] >= 250, diff.join('/'));
});

test('word bank: brands, weapons, dark and abstract words are gone; common aliases exist', () => {
  const words = new Set(WORD_BANK.map((e) => e.w));
  for (const bad of ['레고', '젠가', '수류탄', '지뢰', '해골', '미세먼지', '인터넷', '소설', 'USB', 'PC방', '기타 픽', '총', '칼', '폭탄']) {
    assert.equal(words.has(bad), false, bad);
  }
  const alias = (w) => WORD_BANK.find((e) => e.w === w)?.aliases ?? [];
  assert.ok(alias('텔레비전').includes('티비'));
  assert.ok(alias('돈가스').includes('돈까스'));
  assert.ok(alias('핸드폰').includes('스마트폰'));
});

test('validateWordBank rejects duplicates, spaces, mixed script, bad diff and alias collisions', () => {
  const ok = (w, extra = {}) => ({ w, cat: '동물', diff: 1, aliases: [], ...extra });
  const big = (extra) => [...extra, ...Array.from({ length: 30 }, (_, i) => ok(`가${String.fromCharCode(0xAC00 + i)}`, { diff: (i % 3) + 1 }))];
  const opt = { minWords: 10 };
  assert.doesNotThrow(() => validateWordBank(big([ok('고양이')]), opt));
  assert.throws(() => validateWordBank(big([ok('고양이'), ok('고양이')]), opt), /duplicate/);
  assert.throws(() => validateWordBank(big([ok('기타 픽')]), opt), /Hangul/);
  assert.throws(() => validateWordBank(big([ok('PC방')]), opt), /Hangul/);
  assert.throws(() => validateWordBank(big([ok('고양이', { diff: 4 })]), opt), /diff/);
  assert.throws(() => validateWordBank(big([ok('고양이', { aliases: ['고양이'] })]), opt), /alias equals word/);
  assert.throws(() => validateWordBank(big([ok('고양이', { aliases: ['야옹이'] }), ok('야옹이')]), opt), /another word/);
  assert.throws(() => validateWordBank([ok('고양이')]), /need at least/);
});

test('difficulty ladder: early rounds easy, middle medium, late hard for 4, 6 and 8 rounds', () => {
  assert.deepEqual([1, 2, 3, 4, 5, 6].map((r) => difficultyForRound(r, 6)), [1, 1, 2, 2, 3, 3]);
  assert.deepEqual([1, 2, 3, 4].map((r) => difficultyForRound(r, 4)), [1, 2, 3, 3]);
  assert.deepEqual([1, 2, 3, 4, 5, 6, 7, 8].map((r) => difficultyForRound(r, 8)), [1, 1, 2, 2, 2, 3, 3, 3]);
});

test('pickWord excludes seen and used words, follows difficulty and prefers new categories', () => {
  const random = seeded(3);
  const used = [];
  for (let round = 1; round <= 6; round += 1) {
    const e = pickWord({ round, maxRounds: 6, random, used });
    assert.equal(e.diff, difficultyForRound(round, 6));
    assert.ok(!used.includes(e.w));
    used.push(e.w);
  }
  assert.equal(new Set(used.map((w) => WORD_BANK.find((e) => e.w === w).cat)).size, 6, 'six different categories');
  const seen = WORD_BANK.filter((e) => e.diff === 1 && e.w !== '고양이').map((e) => e.w);
  assert.equal(pickWord({ round: 1, maxRounds: 6, seen, random }).w, '고양이', 'only unseen easy word left');
  // 난이도 안의 단어가 모두 본 단어면 인접 난이도에서 뽑는다.
  const allEasy = WORD_BANK.filter((e) => e.diff === 1).map((e) => e.w);
  assert.equal(pickWord({ round: 1, maxRounds: 6, seen: allEasy, random }).diff, 2);
  // 모든 단어를 봤어도 이번 판 단어는 피한다.
  const everything = WORD_BANK.map((e) => e.w);
  const last = pickWord({ round: 1, maxRounds: 6, seen: everything, used: ['고양이'], random });
  assert.notEqual(last.w, '고양이');
});

test('50 games in a row (6 rounds each) never repeat a word in the same room', () => {
  const random = seeded(2026);
  let seen = [];
  const all = new Set();
  for (let game = 0; game < 50; game += 1) {
    const used = [];
    for (let round = 1; round <= 6; round += 1) {
      const e = pickWord({ round, maxRounds: 6, seen, used, random });
      assert.ok(!all.has(e.w), `game ${game} round ${round}: ${e.w} repeated`);
      all.add(e.w);
      used.push(e.w);
      assert.equal(e.diff, difficultyForRound(round, 6));
    }
    seen = rememberSeen(seen, used);
  }
  assert.equal(all.size, 300);
});

test('rememberSeen keeps the newest 600 words and never duplicates', () => {
  const words = Array.from({ length: 700 }, (_, i) => `w${i}`);
  const kept = rememberSeen([], words);
  assert.equal(kept.length, SEEN_LIMIT);
  assert.equal(kept[0], 'w100');
  assert.equal(kept.at(-1), 'w699');
  assert.deepEqual(rememberSeen(['a', 'b'], ['a', 'c']), ['b', 'a', 'c']);
});

test('normalizeAnswer folds spaces, punctuation, case and NFD hangul', () => {
  assert.equal(normalizeAnswer(' 고 양 이! '), '고양이');
  assert.equal(normalizeAnswer('ABC'), 'abc');
  assert.equal(normalizeAnswer('고양이'.normalize('NFD')), '고양이');
});

test('judgeGuess: exact, spaced, NFD and alias answers are correct', () => {
  const tv = { w: '텔레비전', aliases: ['티비', '텔레비젼'] };
  assert.equal(judgeGuess('텔레비전', tv), 'correct');
  assert.equal(judgeGuess(' 텔레 비전 ', tv), 'correct');
  assert.equal(judgeGuess('티비', tv), 'correct');
  assert.equal(judgeGuess('텔레비젼', tv), 'correct');
  assert.equal(judgeGuess('텔레비전'.normalize('NFD'), tv), 'correct');
  assert.equal(judgeGuess('', tv), 'wrong');
  assert.equal(judgeGuess('냉장고', tv), 'wrong');
});

test('judgeGuess: one letter off is close (아까워요), but short words and big misses are not', () => {
  const cat = { w: '고양이', aliases: [] };
  assert.equal(judgeGuess('고양', cat), 'close');
  assert.equal(judgeGuess('고양이다', cat), 'close');
  assert.equal(judgeGuess('고냥이', cat), 'close');
  assert.equal(judgeGuess('강아지', cat), 'wrong');
  assert.equal(judgeGuess('고', cat), 'wrong');
  const short = { w: '사과', aliases: [] };
  assert.equal(judgeGuess('사자', short), 'wrong', 'two-letter words need an exact answer');
  const pizza = { w: '돈가스', aliases: ['돈까스'] };
  assert.equal(judgeGuess('돈가즈', pizza), 'close');
  assert.equal(judgeGuess('돈까스', pizza), 'correct');
});

test('guessPoints: 3 + one per 20s left, minus a direct hint, never below 1', () => {
  assert.equal(guessPoints({ remainingMs: CATCH_ROUND_MS }), 6);
  assert.equal(guessPoints({ remainingMs: 59_999 }), 5);
  assert.equal(guessPoints({ remainingMs: 40_000 }), 5);
  assert.equal(guessPoints({ remainingMs: 39_999 }), 4);
  assert.equal(guessPoints({ remainingMs: 20_000 }), 4);
  assert.equal(guessPoints({ remainingMs: 19_999 }), 3);
  assert.equal(guessPoints({ remainingMs: 0 }), 3);
  assert.equal(guessPoints({ remainingMs: -500 }), 3);
  assert.equal(guessPoints({ remainingMs: 25_000, directHints: 1 }), 3);
  assert.equal(guessPoints({ remainingMs: 0, directHints: 1 }), 2);
  assert.equal(guessPoints({ remainingMs: 0, directHints: 9 }), 1);
});

test('hint schedule: letters open at 30s and 15s left, only for 3+ letter words, one always hidden', () => {
  assert.deepEqual([60_000, 30_001, 30_000, 15_001, 15_000, 0].map((ms) => autoHintsDue(3, ms)), [0, 0, 1, 1, 2, 2]);
  assert.equal(autoHintsDue(1, 0), 0);
  assert.equal(autoHintsDue(2, 0), 0);
  assert.equal(nextAutoHintRemaining(4, 0), 30_000);
  assert.equal(nextAutoHintRemaining(4, 1), 15_000);
  assert.equal(nextAutoHintRemaining(4, 2), null);
  assert.equal(nextAutoHintRemaining(2, 0), null);
  assert.equal(maxHintReveals(2), 0);
  assert.equal(maxHintReveals(3), 2);
  assert.equal(maxHintReveals(5), 4);
  const order = hintOrder(5, seeded(9));
  assert.deepEqual([...order].sort(), [0, 1, 2, 3, 4]);
  assert.deepEqual(hintTiles('고양이', [1]), ['', '양', '']);
  assert.deepEqual(hintTiles('고양이', []), ['', '', '']);
});

test('winnerOf picks the higher score and null on a tie', () => {
  assert.equal(winnerOf({ a: 5, b: 3 }, ['a', 'b']), 'a');
  assert.equal(winnerOf({ a: 2, b: 3 }, ['a', 'b']), 'b');
  assert.equal(winnerOf({ a: 3, b: 3 }, ['a', 'b']), null);
});
