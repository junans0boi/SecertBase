import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

// 마주 열기: Couple 단위 하루 한 질문. 순수 규칙(선택·검증·스트릭)만 이 파일에 둔다.

export const ANSWER_MAX_LENGTH = 500;
export const RECENT_WINDOW_DAYS = 60;
export const CATEGORY_ORDER = Object.freeze(['daily', 'memory', 'place', 'future', 'play']);
export const PIN_TITLE_MAX = 30;

export class TwoAnswersError extends Error {
  constructor(status, reason) {
    super(reason);
    this.name = 'TwoAnswersError';
    this.status = status;
    this.reason = reason;
  }
}

export const loadQuestionBank = () => JSON.parse(
  readFileSync(new URL('../../data/two-answers-questions.json', import.meta.url), 'utf8'),
);

export const defaultBank = loadQuestionBank();

const hashInt = (text) => createHash('sha256').update(text).digest().readUInt32BE(0);

const dayNumber = (date) => Math.floor(Date.parse(`${date}T00:00:00Z`) / 86400000);

export const addDays = (date, days) => {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
};

export const isBusinessDate = (value) => /^\d{4}-\d{2}-\d{2}$/.test(String(value ?? ''))
  && !Number.isNaN(Date.parse(`${value}T00:00:00Z`));

// 핀 제목 수준만 사용한다. 좌표·주소는 이 함수에 전달되지도 않는다.
const cleanTitle = (value) => String(value ?? '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, PIN_TITLE_MAX);

export function normalizeAnswerBody(value) {
  if (typeof value !== 'string') throw new TwoAnswersError(400, 'invalid_answer');
  const body = value.trim();
  if (body.length === 0) throw new TwoAnswersError(400, 'invalid_answer');
  if ([...body].length > ANSWER_MAX_LENGTH) throw new TwoAnswersError(400, 'answer_too_long');
  return body;
}

/**
 * Couple별 결정적 선택. 같은 (coupleId, date, 입력 상태)에서는 항상 같은 결과를 낸다.
 * - 카테고리는 날짜 기준으로 로테이션한다(Couple마다 시작점이 다르다).
 * - 최근 60일에 쓴 질문 id는 제외한다.
 * - needs 템플릿은 해당 핀/기념일이 있을 때만 후보가 된다.
 */
export function selectQuestion({
  coupleId,
  date,
  bank = defaultBank,
  recentQuestionIds = [],
  pinTitles = [],
  anniversaryLabels = [],
}) {
  const recent = new Set(recentQuestionIds);
  const pins = pinTitles.map(cleanTitle).filter(Boolean);
  const labels = anniversaryLabels.map(cleanTitle).filter(Boolean);
  const start = (dayNumber(date) + Number(coupleId)) % CATEGORY_ORDER.length;

  for (let offset = 0; offset < CATEGORY_ORDER.length; offset += 1) {
    const category = CATEGORY_ORDER[(start + offset) % CATEGORY_ORDER.length];
    const pool = bank.questions.filter((question) => question.category === category
      && !recent.has(question.id)
      && (question.needs !== 'pin' || pins.length > 0)
      && (question.needs !== 'anniversary' || labels.length > 0));
    if (pool.length === 0) continue;
    const seed = `${coupleId}|${date}|${category}`;
    const picked = pool[hashInt(seed) % pool.length];
    let text = picked.text;
    if (picked.needs === 'pin') {
      text = text.replaceAll('{pin}', pins[hashInt(`${seed}|pin`) % pins.length]);
    } else if (picked.needs === 'anniversary') {
      text = text.replaceAll('{anniversary}', labels[hashInt(`${seed}|ann`) % labels.length]);
    }
    return { questionId: picked.id, category, text };
  }
  throw new TwoAnswersError(500, 'question_bank_exhausted');
}

export function questionStatus({ mine, partner }) {
  if (mine && partner) return 'open';
  if (mine) return 'waiting';
  return 'my_turn';
}

/**
 * 스트릭: 둘 다 답한 날짜의 연속 수. 오늘이 아직 완료되지 않았으면 어제까지를 센다.
 * 끊기면 0이며 별도 문구·벌점은 없다.
 */
export function computeStreak(completedDates, today) {
  const set = new Set(completedDates);
  let cursor = set.has(today) ? today : addDays(today, -1);
  let streak = 0;
  while (set.has(cursor)) {
    streak += 1;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

export const bankProblems = (bank) => {
  const problems = [];
  const ids = new Set();
  for (const category of CATEGORY_ORDER) {
    const count = bank.questions.filter((question) => question.category === category).length;
    if (count < 40) problems.push(`${category}: ${count} < 40`);
  }
  for (const question of bank.questions) {
    if (ids.has(question.id)) problems.push(`duplicate id ${question.id}`);
    ids.add(question.id);
    if (!bank.categories[question.category]) problems.push(`unknown category ${question.id}`);
  }
  return problems;
};
