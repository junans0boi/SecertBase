// 데이트 계획: Couple 공유 일정. 순수 검증·커서 규칙만 둔다.

export const TITLE_MAX = 80;
export const MEMO_MAX = 500;
export const LIST_DEFAULT_LIMIT = 20;
export const LIST_MAX_LIMIT = 50;

export class DatePlanError extends Error {
  constructor(status, reason) {
    super(reason);
    this.name = 'DatePlanError';
    this.status = status;
    this.reason = reason;
  }
}

export const isDate = (value) => /^\d{4}-\d{2}-\d{2}$/.test(String(value ?? ''))
  && new Date(`${value}T00:00:00Z`).toISOString().slice(0, 10) === value;

const isTime = (value) => /^([01]\d|2[0-3]):[0-5]\d$/.test(String(value ?? ''));

const cleanText = (value) => String(value).replace(/[\r\t]+/g, ' ').trim();

export function normalizeTitle(value) {
  if (typeof value !== 'string' || cleanText(value).length === 0) throw new DatePlanError(400, 'invalid_title');
  const title = cleanText(value).replace(/\n+/g, ' ');
  if ([...title].length > TITLE_MAX) throw new DatePlanError(400, 'title_too_long');
  return title;
}

export function normalizeMemo(value) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') throw new DatePlanError(400, 'invalid_memo');
  const memo = value.trim();
  if (memo.length === 0) return null;
  if ([...memo].length > MEMO_MAX) throw new DatePlanError(400, 'memo_too_long');
  return memo;
}

export function normalizePlanDate(value) {
  if (!isDate(value)) throw new DatePlanError(400, 'invalid_plan_date');
  return value;
}

export function normalizePlanTime(value) {
  if (value === null || value === undefined || value === '') return null;
  if (!isTime(value)) throw new DatePlanError(400, 'invalid_plan_time');
  return value;
}

export function normalizePinId(value) {
  if (value === null || value === undefined) return null;
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new DatePlanError(400, 'invalid_map_pin');
  return id;
}

export function normalizeId(value) {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) throw new DatePlanError(404, 'plan_not_found');
  return id;
}

export function normalizeLimit(value) {
  if (value === undefined || value === null || value === '') return LIST_DEFAULT_LIMIT;
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) throw new DatePlanError(400, 'invalid_limit');
  return Math.min(n, LIST_MAX_LIMIT);
}

export function normalizeScope(value) {
  const scope = value ?? 'upcoming';
  if (scope !== 'upcoming' && scope !== 'past') throw new DatePlanError(400, 'invalid_scope');
  return scope;
}

// 커서: "plan_date|HH:MM:SS|id" (시각 없는 계획은 00:00:00으로 정렬한다).
export const encodeCursor = ({ plan_date: date, sort_time: time, id }) => `${date}|${time}|${id}`;

export function decodeCursor(value) {
  if (value === undefined || value === null || value === '') return null;
  const [date, time, id, extra] = String(value).split('|');
  if (extra !== undefined || !isDate(date) || !/^\d{2}:\d{2}:\d{2}$/.test(time ?? '')
    || !Number.isSafeInteger(Number(id)) || Number(id) <= 0) {
    throw new DatePlanError(400, 'invalid_cursor');
  }
  return { date, time, id: Number(id) };
}
