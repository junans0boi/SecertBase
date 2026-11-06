// 그림 맞히기 2.0 엔진: 제시어 은행·뽑기·정답 판정·점수·힌트 일정. 순수 함수 + random 주입.
// 소켓 흐름은 games/catch.js. 이벤트 계약은 docs/socket-events/catch.md.
import { readFileSync } from "node:fs";

export const CATCH_ROUND_MS = 60_000;
/** 정답 점수: 맞힌 사람 기본 3점 + 남은 시간 20초당 1점. */
export const GUESS_BASE_POINTS = 3;
export const GUESS_BONUS_STEP_MS = 20_000;
/** 그린 사람이 정답이 나올 때 받는 점수. */
export const DRAWER_POINTS = 2;
/** 직접 힌트를 쓰면 맞힌 점수에서 깎이는 점수(최소 1점은 남는다). */
export const DIRECT_HINT_PENALTY = 1;
/** 남은 시간이 이 값 이하가 될 때마다 글자 하나가 자동으로 열린다. */
export const AUTO_HINT_REMAINING_MS = Object.freeze([30_000, 15_000]);
/** 힌트는 이 글자 수 이상인 제시어에서만 쓴다(한두 글자는 힌트가 곧 정답). */
export const MIN_HINT_LENGTH = 3;
/** 방별 본 단어 기록 상한. */
export const SEEN_LIMIT = 600;
export const MIN_BANK_WORDS = 1200;

const HANGUL_WORD = /^[가-힣]{1,8}$/u;
const HANGUL_ALIAS = /^[가-힣]{1,10}$/u;

/** 제시어 은행을 검사한다. 문제가 있으면 모든 사유를 모아 throw한다. */
export function validateWordBank(bank, { minWords = MIN_BANK_WORDS } = {}) {
  const problems = [];
  if (!Array.isArray(bank)) throw new Error("catch word bank must be an array");
  const words = new Set();
  const aliasOwner = new Map();
  const diffCount = { 1: 0, 2: 0, 3: 0 };
  for (const [i, e] of bank.entries()) {
    const at = `#${i} ${e?.w}`;
    if (!e || typeof e.w !== "string" || !HANGUL_WORD.test(e.w)) problems.push(`${at}: w must be 1-8 Hangul syllables without spaces`);
    else if (words.has(e.w)) problems.push(`${at}: duplicate word`);
    else words.add(e.w);
    if (typeof e?.cat !== "string" || !e.cat.trim()) problems.push(`${at}: cat missing`);
    if (![1, 2, 3].includes(e?.diff)) problems.push(`${at}: diff must be 1, 2 or 3`);
    else diffCount[e.diff] += 1;
    if (!Array.isArray(e?.aliases)) problems.push(`${at}: aliases must be an array`);
    else {
      for (const a of e.aliases) {
        if (typeof a !== "string" || !HANGUL_ALIAS.test(a)) problems.push(`${at}: bad alias ${a}`);
        else if (a === e.w) problems.push(`${at}: alias equals word`);
        else if (aliasOwner.has(a)) problems.push(`${at}: alias ${a} also on ${aliasOwner.get(a)}`);
        else aliasOwner.set(a, e.w);
      }
    }
  }
  for (const [a, owner] of aliasOwner) if (words.has(a)) problems.push(`${owner}: alias ${a} is another word`);
  if (bank.length < minWords) problems.push(`bank has ${bank.length} words, need at least ${minWords}`);
  for (const d of [1, 2, 3]) {
    if (diffCount[d] < bank.length * 0.15) problems.push(`difficulty ${d} has only ${diffCount[d]} words`);
  }
  if (problems.length) throw new Error(`invalid catch word bank:\n${problems.slice(0, 20).join("\n")}`);
  return bank;
}

export function loadWordBank(url = new URL("./data/catch-words.json", import.meta.url)) {
  const bank = JSON.parse(readFileSync(url, "utf8"));
  return Object.freeze(validateWordBank(bank));
}

/** 불러올 때 한 번 검증한 제시어 은행. */
export const WORD_BANK = loadWordBank();

/** 라운드별 난이도: 앞 3분의 1은 쉬움, 가운데는 보통, 마지막은 어려움. */
export function difficultyForRound(round, maxRounds) {
  const rounds = Math.max(1, maxRounds);
  return Math.min(3, Math.max(1, Math.ceil((round * 3) / rounds)));
}

/**
 * 이번 라운드의 제시어를 뽑는다.
 * seen = 방에서 이미 나온 단어(Set 또는 배열), used = 이번 판에서 이미 나온 단어.
 * 본 단어는 먼저 제외하고, 난이도가 모자라면 인접 난이도 → 본 단어까지 허용 순으로 넓힌다.
 * 이번 판에 아직 안 나온 분야를 먼저 고른다.
 */
export function pickWord({ bank = WORD_BANK, seen = [], used = [], round = 1, maxRounds = 6, random = Math.random } = {}) {
  const seenSet = seen instanceof Set ? seen : new Set(seen);
  const usedSet = new Set(used);
  const target = difficultyForRound(round, maxRounds);
  const order = [target, ...[1, 2, 3].filter((d) => d !== target).sort((a, b) => Math.abs(a - target) - Math.abs(b - target))];
  const usedCats = new Set(bank.filter((e) => usedSet.has(e.w)).map((e) => e.cat));
  const choose = (list) => list[Math.min(list.length - 1, Math.floor(random() * list.length))];
  for (const allowSeen of [false, true]) {
    for (const d of order) {
      const pool = bank.filter((e) => e.diff === d && !usedSet.has(e.w) && (allowSeen || !seenSet.has(e.w)));
      if (!pool.length) continue;
      const fresh = pool.filter((e) => !usedCats.has(e.cat));
      return choose(fresh.length ? fresh : pool);
    }
  }
  return choose(bank);
}

/** 본 단어 기록에 새 단어를 더하고 상한(600)을 넘으면 오래된 것부터 버린다. */
export function rememberSeen(seen, words, limit = SEEN_LIMIT) {
  const list = (Array.isArray(seen) ? seen : [...seen]).filter((w) => !words.includes(w));
  return [...list, ...words].slice(-limit);
}

/** 공백·구두점 제거 + NFC + 소문자. 비교용. */
export function normalizeAnswer(text) {
  return String(text ?? "")
    .normalize("NFC")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, "");
}

function editDistanceAtMostOne(a, b) {
  const x = [...a];
  const y = [...b];
  if (Math.abs(x.length - y.length) > 1) return false;
  let i = 0;
  while (i < x.length && i < y.length && x[i] === y[i]) i += 1;
  if (x.length === y.length) {
    // 한 글자만 다른 경우(바꾸기).
    return x.slice(i + 1).join("") === y.slice(i + 1).join("");
  }
  const [longer, shorter] = x.length > y.length ? [x, y] : [y, x];
  return longer.slice(i + 1).join("") === shorter.slice(i).join("");
}

/** 'correct' | 'close'(아까워요: 한 글자 차이) | 'wrong'. aliases도 정답으로 센다. */
export function judgeGuess(text, entry) {
  const guess = normalizeAnswer(text);
  if (!guess) return "wrong";
  const answers = [entry.w, ...(entry.aliases ?? [])].map(normalizeAnswer);
  if (answers.includes(guess)) return "correct";
  // 한두 글자 단어는 글자 하나만 달라도 전혀 다른 말이 되므로 세 글자 이상에서만 아깝다고 본다.
  if ([...guess].length >= 2) {
    for (const answer of answers) {
      if ([...answer].length >= 3 && editDistanceAtMostOne(guess, answer)) return "close";
    }
  }
  return "wrong";
}

/** 맞힌 사람 점수: 3 + 남은 20초당 1 - 직접 힌트 수(최소 1). */
export function guessPoints({ remainingMs, directHints = 0 }) {
  const left = Math.max(0, Math.min(CATCH_ROUND_MS, remainingMs));
  const bonus = Math.floor(left / GUESS_BONUS_STEP_MS);
  return Math.max(1, GUESS_BASE_POINTS + bonus - directHints * DIRECT_HINT_PENALTY);
}

/** 남은 시간에서 지금까지 자동으로 열려야 하는 글자 수. */
export function autoHintsDue(wordLength, remainingMs) {
  if (wordLength < MIN_HINT_LENGTH) return 0;
  return AUTO_HINT_REMAINING_MS.filter((at) => remainingMs <= at).length;
}

/** 다음 자동 힌트가 열리기까지 남은 시간(ms). 더 열 힌트가 없으면 null. */
export function nextAutoHintRemaining(wordLength, autoDone) {
  if (wordLength < MIN_HINT_LENGTH) return null;
  return AUTO_HINT_REMAINING_MS[autoDone] ?? null;
}

/** 힌트로 열 글자 순서. 하나는 항상 가려 둔다(전부 열면 정답이므로). */
export function hintOrder(wordLength, random = Math.random) {
  const idx = Array.from({ length: wordLength }, (_, i) => i);
  for (let i = idx.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [idx[i], idx[j]] = [idx[j], idx[i]];
  }
  return idx;
}

export const maxHintReveals = (wordLength) => (wordLength < MIN_HINT_LENGTH ? 0 : wordLength - 1);

/** 글자 칸 힌트: 열린 칸은 글자, 닫힌 칸은 빈 문자열. */
export function hintTiles(word, revealed) {
  const chars = [...word];
  return chars.map((c, i) => (revealed.includes(i) ? c : ""));
}

/** 점수로 승자 결정. 동점이면 null(무승부). */
export function winnerOf(scores, players) {
  const [a, b] = players;
  if ((scores[a] ?? 0) === (scores[b] ?? 0)) return null;
  return (scores[a] ?? 0) > (scores[b] ?? 0) ? a : b;
}
