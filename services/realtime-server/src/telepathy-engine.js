// 텔레파시 2.0 엔진(순수 함수, random 주입). 이벤트 계약: docs/socket-events/telepathy.md
//
// 밸런스 게임: 문제마다 A·B 중 하나를 둘이 몰래 고르고 동시에 공개한다. 같으면 "통했다".
// 문제는 서버 은행(data/telepathy-questions.json)에서 방별 셔플 가방으로 꺼낸다.
// 가방은 남은 문제 id 순서와 최근에 낸 50개를 들고 있고, 다 쓰면 전체를 다시 섞되
// 최근 50개는 맨 뒤로 보낸다. 한 판에서 같은 분야는 2문제까지만.
import { readFileSync } from "node:fs";

export const TELEPATHY_CATEGORIES = Object.freeze([
  Object.freeze({ id: "light", label: "가벼운 취향" }),
  Object.freeze({ id: "food", label: "음식·야식" }),
  Object.freeze({ id: "date", label: "데이트" }),
  Object.freeze({ id: "travel", label: "여행" }),
  Object.freeze({ id: "daily", label: "일상·생활습관" }),
  Object.freeze({ id: "romance", label: "연애·로맨스" }),
  Object.freeze({ id: "whatif", label: "만약에" }),
  Object.freeze({ id: "spicy", label: "살짝 매운맛" }),
  Object.freeze({ id: "sensual", label: "은근한 분위기" }),
  Object.freeze({ id: "nuclear", label: "19+ 은밀한 질문" }),
]);
const CATEGORY_IDS = new Set(TELEPATHY_CATEGORIES.map((c) => c.id));
/** 문제 id 접두사: 대부분 분야 id와 같고, 은근한 분위기는 `sen-001`, 19+ 분야는 `nuc-001`. */
export const telepathyIdPrefix = (cat) => (cat === "nuclear" ? "nuc" : cat === "sensual" ? "sen" : cat);

/** 로비 옵션 `heat` 값. */
export const TELEPATHY_HEATS = Object.freeze(["mild", "spicy", "nuclear"]);
/** 분야 → 수위. 19+ 분야만 nuclear, 살짝 매운맛·은근한 분위기 분야는 spicy, 나머지는 mild. */
export const heatOfCategory = (cat) =>
  cat === "nuclear" ? "nuclear" : cat === "spicy" || cat === "sensual" ? "spicy" : "mild";
/**
 * 수위별로 섞이는 분야.
 * - mild: 순한 분야만(매운맛·19+ 없음).
 * - spicy(살짝 매운맛): 순한 분야 + 살짝 매운맛 + 은근한 분위기(장소·속옷·스킨십 취향). 19+는 없다.
 * - nuclear(19+): 19+ 분야만, 한 판이 전부 19+ 문제다. 19+ 풀이 바닥났을 때만(문제 수가 모자랄 때)
 *   살짝 매운맛 수위로 채운다(drawQuestions의 마지막 예비 단계).
 */
export function heatAllows(heat, cat) {
  const h = heatOfCategory(cat);
  if (heat === "nuclear") return h === "nuclear";
  if (heat === "spicy") return h === "mild" || h === "spicy";
  return h === "mild";
}

/** 보기 하나의 최대 글자 수. */
export const TELEPATHY_OPTION_MAX = 14;
/** 가방을 다시 채울 때 맨 뒤로 보내는 최근 문제 수. */
export const TELEPATHY_RECENT_LIMIT = 50;
/** 한 판에 같은 분야 최대 문제 수(분야가 모자라 판을 못 채우면 그만큼만 늘린다). */
export const TELEPATHY_CATEGORY_CAP = 2;
export const TELEPATHY_CHOICES = Object.freeze(["A", "B"]);

// 한글 음절·숫자·공백과 약간의 문장부호만. 영어 글자·이모지는 보기에 들어갈 수 없다.
const KOREAN_TEXT = /^[가-힣0-9 ·,.?!~%()-]+$/;
const HANGUL = /[가-힣]/;
const ID_FORMAT = /^([a-z]+)-(\d{3})$/;

const charCount = (text) => [...text].length;

/**
 * 문제 은행 검증. 문제가 있으면 모든 사유를 모아 예외를 던진다(서버가 시작되지 않게).
 * 규칙: 배열, 고유 id(`<분야>-NNN`), 알려진 분야, 보기 둘 다 한국어·14자 이내·서로 다름,
 * 이모지 있음, spicy는 '살짝 매운맛' 분야와 일치, 보기 쌍 중복 없음.
 */
export function validateTelepathyBank(bank) {
  const errors = [];
  if (!Array.isArray(bank) || bank.length === 0) throw new Error("telepathy bank must be a non-empty array");
  const ids = new Set();
  const pairs = new Set();
  bank.forEach((q, index) => {
    const where = `#${index}${q?.id ? ` (${q.id})` : ""}`;
    if (!q || typeof q !== "object") {
      errors.push(`${where}: not an object`);
      return;
    }
    const idMatch = typeof q.id === "string" ? ID_FORMAT.exec(q.id) : null;
    if (!idMatch) errors.push(`${where}: id must look like "food-001"`);
    else if (idMatch[1] !== telepathyIdPrefix(q.cat)) errors.push(`${where}: id prefix must match cat`);
    if (ids.has(q.id)) errors.push(`${where}: duplicate id`);
    ids.add(q.id);
    if (!CATEGORY_IDS.has(q.cat)) errors.push(`${where}: unknown cat "${q.cat}"`);
    for (const key of ["a", "b"]) {
      const text = q[key];
      if (typeof text !== "string" || text.trim() !== text || text.length === 0) {
        errors.push(`${where}: ${key} must be trimmed non-empty text`);
        continue;
      }
      if (charCount(text) > TELEPATHY_OPTION_MAX) errors.push(`${where}: ${key} longer than ${TELEPATHY_OPTION_MAX}`);
      if (!KOREAN_TEXT.test(text) || !HANGUL.test(text)) errors.push(`${where}: ${key} must be Korean only`);
    }
    for (const key of ["emojiA", "emojiB"]) {
      const emoji = q[key];
      if (typeof emoji !== "string" || emoji.length === 0 || charCount(emoji) > 8 || HANGUL.test(emoji) || /[A-Za-z0-9]/.test(emoji)) {
        errors.push(`${where}: ${key} must be a short emoji`);
      }
    }
    if (q.a === q.b) errors.push(`${where}: a and b are the same`);
    if (q.heat !== heatOfCategory(q.cat)) errors.push(`${where}: heat must match the category`);
    if (typeof q.spicy !== "boolean") errors.push(`${where}: spicy must be boolean`);
    else if (q.spicy !== (q.heat !== "mild")) errors.push(`${where}: spicy must be true exactly for spicy and nuclear questions`);
    const pair = [q.a, q.b].sort().join("|");
    if (pairs.has(pair)) errors.push(`${where}: duplicate question`);
    pairs.add(pair);
  });
  if (errors.length) throw new Error(`invalid telepathy bank:\n${errors.join("\n")}`);
  return bank;
}

/** JSON 파일을 읽어 검증한 은행. */
export function loadTelepathyBank(url = new URL("./data/telepathy-questions.json", import.meta.url)) {
  const bank = validateTelepathyBank(JSON.parse(readFileSync(url, "utf8")));
  return Object.freeze(bank.map((q) => Object.freeze({ ...q })));
}

export const TELEPATHY_BANK = loadTelepathyBank();

export function shuffle(list, random = Math.random) {
  const out = [...list];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/** 새 가방 순서: 최근에 나오지 않은 문제를 섞어 앞에, 최근 문제는 오래된 것부터 맨 뒤에. */
export function refillOrder(bank, recent = [], random = Math.random) {
  const recentSet = new Set(recent);
  const fresh = bank.filter((q) => !recentSet.has(q.id)).map((q) => q.id);
  const known = new Set(bank.map((q) => q.id));
  const tail = recent.filter((id, i) => known.has(id) && recent.indexOf(id) === i);
  return [...shuffle(fresh, random), ...tail];
}

/** 빈 가방(첫 판이면 바로 채워진다). */
export function emptyBag() {
  return { order: [], recent: [], refills: 0 };
}

function sanitizeBag(bag, byId) {
  const seen = new Set();
  const order = [];
  for (const id of Array.isArray(bag?.order) ? bag.order : []) {
    if (byId.has(id) && !seen.has(id)) {
      seen.add(id);
      order.push(id);
    }
  }
  const recent = (Array.isArray(bag?.recent) ? bag.recent : []).filter((id) => byId.has(id)).slice(-TELEPATHY_RECENT_LIMIT);
  return { order, recent, refills: Number.isInteger(bag?.refills) ? bag.refills : 0 };
}

/**
 * 가방에서 n문제를 꺼낸다(입력은 바꾸지 않는다) → { questions, bag }.
 * - heat에 맞는 분야만 쓴다(heatAllows). 안 맞는 문제는 가방에 남아 다음 재셔플 때 함께 섞인다.
 * - 같은 분야는 판당 TELEPATHY_CATEGORY_CAP개까지. 남은 문제가 가장 많은 분야부터 꺼내 분야별 남은 수가
 *   고르게 줄어든다. 한 분야만 많이 남아 상한 때문에 판을 못 채우게 되면, 가방에 충분히 남아 있을 때는
 *   상한을 풀어 같은 가방에서 이어 꺼낸다(다시 섞기 전에는 반복이 없다).
 * - 가방에서 n개를 못 채우면 다시 섞어(최근 50개는 뒤로) 이어서 꺼낸다.
 * - 19+(nuclear)는 19+ 분야만 쓴다(한 판 전부). 19+ 풀이 문제 수보다 작을 때만 마지막에
 *   살짝 매운맛 수위(은근한 분위기·살짝 매운맛)로 채운다.
 * - 옛 호출 { spicy: true }는 heat 'spicy'와 같다.
 */
export function drawQuestions(bag, bank, n, { heat, spicy = false, random = Math.random } = {}) {
  const level = TELEPATHY_HEATS.includes(heat) ? heat : spicy ? "spicy" : "mild";
  const byId = new Map(bank.map((q) => [q.id, q]));
  const primary = (q) => heatAllows(level, q.cat);
  // 19+ 풀이 모자랄 때만 쓰는 예비: 살짝 매운맛 수위.
  const fallback = (q) => level === "nuclear" && heatOfCategory(q.cat) === "spicy";
  const pool = bank.filter(primary);
  const spare = bank.filter(fallback);
  const count = Math.max(0, Math.min(n, pool.length + spare.length));
  const categories = new Set(pool.map((q) => q.cat)).size;
  const evenCap = Math.max(TELEPATHY_CATEGORY_CAP, Math.ceil(count / Math.max(1, categories)));
  let relaxed = false;
  let useSpare = false;
  const eligible = (q) => primary(q) || (useSpare && fallback(q));
  const capOf = () => (relaxed || useSpare ? Infinity : evenCap);
  const state = sanitizeBag(bag, byId);
  const picked = [];
  const pickedSet = new Set();
  const perCat = new Map();

  const takeFrom = (order) => {
    while (picked.length < count) {
      // 분야별 후보(가방 순서대로 첫 문제)와 남은 수.
      const groups = new Map();
      for (const id of order) {
        if (pickedSet.has(id)) continue;
        const q = byId.get(id);
        if (!eligible(q) || (perCat.get(q.cat) ?? 0) >= capOf()) continue;
        const g = groups.get(q.cat);
        if (g) g.left += 1;
        else groups.set(q.cat, { first: id, left: 1 });
      }
      if (groups.size === 0) return;
      const most = Math.max(...[...groups.values()].map((g) => g.left));
      const top = [...groups.entries()].filter(([, g]) => g.left === most);
      const [cat, g] = top[Math.floor(random() * top.length)];
      picked.push(g.first);
      pickedSet.add(g.first);
      perCat.set(cat, (perCat.get(cat) ?? 0) + 1);
    }
  };
  const bagLeft = (order) => order.filter((id) => !pickedSet.has(id) && primary(byId.get(id))).length;

  takeFrom(state.order);
  let order = state.order;
  let refills = state.refills;
  let recent = state.recent;
  // 분야 상한 때문에 못 채웠지만 가방에 충분히 남았다면 상한을 풀어 같은 가방에서 이어 꺼낸다.
  if (picked.length < count && bagLeft(order) >= count - picked.length) {
    relaxed = true;
    takeFrom(order);
    relaxed = false;
  }
  if (picked.length < count) {
    recent = [...recent, ...picked].slice(-TELEPATHY_RECENT_LIMIT);
    order = refillOrder(bank, recent, random);
    refills += 1;
    takeFrom(order);
  }
  if (picked.length < count) {
    relaxed = true;
    takeFrom(order);
  }
  if (picked.length < count) {
    useSpare = true;
    takeFrom(order);
  }
  const shown = shuffle(picked, random);
  return {
    questions: shown.map((id) => byId.get(id)),
    bag: {
      order: order.filter((id) => !pickedSet.has(id)),
      recent: [...recent.filter((id) => !pickedSet.has(id)), ...shown].slice(-TELEPATHY_RECENT_LIMIT),
      refills,
    },
  };
}

/** 한 문제 판정. 시간 초과(null)는 불일치. */
export function judge(pickA, pickB) {
  const valid = (p) => TELEPATHY_CHOICES.includes(p);
  if (!valid(pickA) || !valid(pickB)) return { matched: false, outcome: "timeout" };
  return pickA === pickB ? { matched: true, outcome: "match" } : { matched: false, outcome: "miss" };
}

/** 통한 비율에 따른 등급(10문제 기준 9–10 / 7–8 / 4–6 / 0–3). */
export function tierFor(matches, total) {
  const ratio = total > 0 ? matches / total : 0;
  if (ratio >= 0.9) return { id: "soulmate", label: "텔레파시 커플" };
  if (ratio >= 0.7) return { id: "eyes", label: "눈빛만 봐도" };
  if (ratio >= 0.4) return { id: "learning", label: "알아가는 중" };
  return { id: "opposites", label: "반대가 끌려요" };
}

/** 지금까지의 기록 요약: 통한 수·현재 연속·최고 연속·등급. */
export function summary(history, total = history.length) {
  let matches = 0;
  let streak = 0;
  let bestStreak = 0;
  for (const h of history) {
    if (h.matched) {
      matches += 1;
      streak += 1;
      bestStreak = Math.max(bestStreak, streak);
    } else {
      streak = 0;
    }
  }
  return { matches, total, played: history.length, streak, bestStreak, tier: tierFor(matches, total) };
}

/** 방 시리즈에 한 판을 더한다(승패 없음: 판 수·통한 수·문제 수·최고 연속·최근 판). */
export function applyTelepathySeries(series, { matches, total, bestStreak }) {
  const prev = series ?? {};
  const recent = [...(Array.isArray(prev.recent) ? prev.recent : []), { matches, total }].slice(-10);
  const next = {
    games: (prev.games ?? 0) + 1,
    matches: (prev.matches ?? 0) + matches,
    questions: (prev.questions ?? 0) + total,
    bestStreak: Math.max(prev.bestStreak ?? 0, bestStreak),
    bestMatches: Math.max(prev.bestMatches ?? 0, matches),
    recent,
  };
  next.ratio = next.questions > 0 ? Math.round((next.matches / next.questions) * 100) : 0;
  return next;
}

export function emptyTelepathySeries() {
  return { games: 0, matches: 0, questions: 0, bestStreak: 0, bestMatches: 0, recent: [], ratio: 0 };
}
