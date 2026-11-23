import { businessDate } from '../../business-date.js';
import { resolveActiveCouple } from '../../shared/access-context.js';
import {
  DatePlanError,
  decodeCursor,
  encodeCursor,
  normalizeId,
  normalizeLimit,
  normalizeMemo,
  normalizePinId,
  normalizePlanDate,
  normalizePlanTime,
  normalizeScope,
  normalizeTitle,
} from './domain.js';

const defaultQuery = async (...args) => (await import('../../db.js')).query(...args);

// 좌표·주소는 선택하지 않는다. 핀은 제목·상태만 노출한다.
const SELECT_PLAN = `
  SELECT p.id, DATE_FORMAT(p.plan_date, '%Y-%m-%d') AS plan_date,
         TIME_FORMAT(p.plan_time, '%H:%i') AS plan_time,
         IFNULL(TIME_FORMAT(p.plan_time, '%H:%i:%s'), '00:00:00') AS sort_time,
         p.title, p.memo, p.created_by, p.completed_at, p.completed_by, p.map_pin_id,
         mp.place_name AS pin_title, mp.status AS pin_status, mp.archived_at AS pin_archived_at,
         (SELECT av.id FROM afterglow_visits av
           WHERE av.map_pin_id = p.map_pin_id AND av.couple_id = p.couple_id LIMIT 1) AS visit_id
  FROM date_plans p
  LEFT JOIN map_pins mp ON mp.id = p.map_pin_id AND mp.couple_id = p.couple_id`;

const BY_SORT = (direction) => `p.plan_date ${direction}, sort_time ${direction}, p.id ${direction}`;

/**
 * 데이트 계획 서비스. 모든 메서드는 JWT에서 도출된 actor만 받고 활성 Couple은 서버에서 확인한다.
 * 정책: 두 사람 모두 수정·완료 가능, 삭제는 작성자만(MomentLoop 삭제 정책과 동일).
 * 완료는 기록만 남기고, 애프터글로우 방문 표시는 기존 /retention/afterglow API를 그대로 쓴다.
 */
export function DatePlanService({ queryFn = defaultQuery, now = () => new Date() } = {}) {
  const requireCouple = async (actor) => {
    const couple = await resolveActiveCouple(actor.userId, queryFn);
    if (!couple) throw new DatePlanError(403, 'active_couple_required');
    return { coupleId: Number(couple.CoupleId), userId: Number(actor.userId) };
  };

  const assertOwnPin = async (coupleId, pinId) => {
    if (pinId === null) return;
    const { rows } = await queryFn(
      'SELECT id FROM map_pins WHERE id = ? AND couple_id = ? AND archived_at IS NULL LIMIT 1',
      [pinId, coupleId],
    );
    if (!rows[0]) throw new DatePlanError(404, 'map_pin_not_found');
  };

  const assertNotPast = (date) => {
    if (date < businessDate(now())) throw new DatePlanError(400, 'plan_date_in_past');
  };

  const afterglowOf = (row) => {
    if (!row.completed_at || !row.map_pin_id || !row.pin_title || row.pin_archived_at) return null;
    if (row.visit_id) return { map_pin_id: Number(row.map_pin_id), state: 'recorded' };
    if (row.pin_status === 'wishlist') return { map_pin_id: Number(row.map_pin_id), state: 'needs_visit' };
    return null;
  };

  const view = (row, userId) => ({
    id: Number(row.id),
    plan_date: row.plan_date,
    plan_time: row.plan_time ?? null,
    title: row.title,
    memo: row.memo ?? null,
    mine: Number(row.created_by) === userId,
    completed: Boolean(row.completed_at),
    pin: row.map_pin_id && row.pin_title && !row.pin_archived_at
      ? { id: Number(row.map_pin_id), title: row.pin_title }
      : null,
    afterglow: afterglowOf(row),
  });

  const findOwned = async (coupleId, rawId) => {
    const id = normalizeId(rawId);
    const { rows } = await queryFn(`${SELECT_PLAN} WHERE p.id = ? AND p.couple_id = ? LIMIT 1`, [id, coupleId]);
    if (!rows[0]) throw new DatePlanError(404, 'plan_not_found');
    return rows[0];
  };

  return {
    async create(actor, input) {
      const scope = await requireCouple(actor);
      const planDate = normalizePlanDate(input.plan_date);
      const title = normalizeTitle(input.title);
      const planTime = normalizePlanTime(input.plan_time);
      const memo = normalizeMemo(input.memo);
      const pinId = normalizePinId(input.map_pin_id);
      assertNotPast(planDate);
      await assertOwnPin(scope.coupleId, pinId);
      const { rows } = await queryFn(
        `INSERT INTO date_plans (couple_id, created_by, plan_date, plan_time, title, memo, map_pin_id)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [scope.coupleId, scope.userId, planDate, planTime, title, memo, pinId],
      );
      return view(await findOwned(scope.coupleId, rows.insertId), scope.userId);
    },

    async get(actor, id) {
      const scope = await requireCouple(actor);
      return view(await findOwned(scope.coupleId, id), scope.userId);
    },

    async list(actor, { scope: rawScope, cursor: rawCursor, limit: rawLimit } = {}) {
      const scope = await requireCouple(actor);
      const kind = normalizeScope(rawScope);
      const limit = normalizeLimit(rawLimit);
      const cursor = decodeCursor(rawCursor);
      const today = businessDate(now());
      const upcoming = kind === 'upcoming';
      const where = ['p.couple_id = ?'];
      const params = [scope.coupleId];
      if (upcoming) {
        where.push('p.completed_at IS NULL AND p.plan_date >= ?');
      } else {
        where.push('(p.completed_at IS NOT NULL OR p.plan_date < ?)');
      }
      params.push(today);
      if (cursor) {
        const op = upcoming ? '>' : '<';
        where.push(`(p.plan_date ${op} ? OR (p.plan_date = ? AND (sort_time ${op} ? OR (sort_time = ? AND p.id ${op} ?))))`);
        params.push(cursor.date, cursor.date, cursor.time, cursor.time, cursor.id);
      }
      // sort_time 은 SELECT 별칭이라 WHERE 에서 쓸 수 없으므로 표현식으로 치환한다.
      const sql = `${SELECT_PLAN} WHERE ${where.join(' AND ').replaceAll('sort_time', "IFNULL(TIME_FORMAT(p.plan_time, '%H:%i:%s'), '00:00:00')")}
        ORDER BY ${BY_SORT(upcoming ? 'ASC' : 'DESC')} LIMIT ${limit + 1}`;
      const { rows } = await queryFn(sql, params);
      const page = rows.slice(0, limit);
      return {
        plans: page.map((row) => view(row, scope.userId)),
        next_cursor: rows.length > limit ? encodeCursor(page[page.length - 1]) : null,
      };
    },

    async update(actor, id, input) {
      const scope = await requireCouple(actor);
      const current = await findOwned(scope.coupleId, id);
      if (current.completed_at) throw new DatePlanError(409, 'plan_completed');
      const sets = [];
      const params = [];
      if ('plan_date' in input) {
        const planDate = normalizePlanDate(input.plan_date);
        if (planDate !== current.plan_date) assertNotPast(planDate);
        sets.push('plan_date = ?'); params.push(planDate);
      }
      if ('plan_time' in input) { sets.push('plan_time = ?'); params.push(normalizePlanTime(input.plan_time)); }
      if ('title' in input) { sets.push('title = ?'); params.push(normalizeTitle(input.title)); }
      if ('memo' in input) { sets.push('memo = ?'); params.push(normalizeMemo(input.memo)); }
      if ('map_pin_id' in input) {
        const pinId = normalizePinId(input.map_pin_id);
        if (pinId !== (current.map_pin_id === null ? null : Number(current.map_pin_id))) {
          await assertOwnPin(scope.coupleId, pinId);
        }
        sets.push('map_pin_id = ?'); params.push(pinId);
      }
      if (sets.length === 0) throw new DatePlanError(400, 'no_changes');
      await queryFn(
        `UPDATE date_plans SET ${sets.join(', ')} WHERE id = ? AND couple_id = ?`,
        [...params, Number(current.id), scope.coupleId],
      );
      return view(await findOwned(scope.coupleId, id), scope.userId);
    },

    async remove(actor, id) {
      const scope = await requireCouple(actor);
      const current = await findOwned(scope.coupleId, id);
      if (Number(current.created_by) !== scope.userId) throw new DatePlanError(403, 'plan_author_required');
      await queryFn('DELETE FROM date_plans WHERE id = ? AND couple_id = ?', [Number(current.id), scope.coupleId]);
    },

    // "다녀왔어요": 날짜가 오늘이거나 지난 계획만. 이미 완료돼 있으면 그대로 돌려준다(멱등).
    async complete(actor, id) {
      const scope = await requireCouple(actor);
      const current = await findOwned(scope.coupleId, id);
      if (!current.completed_at) {
        if (current.plan_date > businessDate(now())) throw new DatePlanError(409, 'plan_not_yet');
        await queryFn(
          `UPDATE date_plans SET completed_at = NOW(), completed_by = ?
           WHERE id = ? AND couple_id = ? AND completed_at IS NULL`,
          [scope.userId, Number(current.id), scope.coupleId],
        );
      }
      const plan = view(await findOwned(scope.coupleId, id), scope.userId);
      return { plan, afterglow: plan.afterglow };
    },
  };
}
