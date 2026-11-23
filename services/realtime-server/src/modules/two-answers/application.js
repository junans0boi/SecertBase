import { businessDate } from '../../business-date.js';
import { resolveActiveCouple } from '../../shared/access-context.js';
import {
  RECENT_WINDOW_DAYS,
  TwoAnswersError,
  addDays,
  computeStreak,
  normalizeAnswerBody,
  questionStatus,
  selectQuestion,
} from './domain.js';

const defaultQuery = async (...args) => (await import('../../db.js')).query(...args);
const defaultTransaction = async (...args) => (await import('../../db.js')).transaction(...args);

const DATE_SQL = "DATE_FORMAT(t.business_date, '%Y-%m-%d')";
const HISTORY_DEFAULT_LIMIT = 20;
const HISTORY_MAX_LIMIT = 50;

const positiveInt = (value) => {
  const number = Number(value);
  return Number.isSafeInteger(number) && number > 0 ? number : null;
};

/**
 * 마주 열기 서비스. 모든 메서드는 JWT에서 도출된 actor만 받고,
 * 활성 Couple은 서버에서 다시 확인한다. 상대 답변 본문은 두 사람이 모두 답한 뒤에만 돌려준다.
 */
export function TwoAnswersService({
  queryFn = defaultQuery,
  transactionFn = defaultTransaction,
  now = () => new Date(),
  publish = () => {},
} = {}) {
  const requireCouple = async (actor) => {
    const couple = await resolveActiveCouple(actor.userId, queryFn);
    if (!couple) throw new TwoAnswersError(403, 'active_couple_required');
    return { coupleId: Number(couple.CoupleId), userId: actor.userId };
  };

  const findByDate = async (coupleId, date) => {
    const { rows } = await queryFn(
      `SELECT t.id, ${DATE_SQL} AS business_date, t.question_id, t.category, t.question_text
       FROM two_answers t WHERE t.couple_id = ? AND t.business_date = ? LIMIT 1`,
      [coupleId, date],
    );
    return rows[0] ?? null;
  };

  const findOwned = async (coupleId, id) => {
    const { rows } = await queryFn(
      `SELECT t.id, ${DATE_SQL} AS business_date, t.question_id, t.category, t.question_text
       FROM two_answers t WHERE t.id = ? AND t.couple_id = ? LIMIT 1`,
      [id, coupleId],
    );
    if (!rows[0]) throw new TwoAnswersError(404, 'question_not_found');
    return rows[0];
  };

  const ensureQuestion = async (coupleId, date) => {
    const existing = await findByDate(coupleId, date);
    if (existing) return existing;

    const [recent, pins, anniversaries] = await Promise.all([
      queryFn(
        `SELECT question_id FROM two_answers
         WHERE couple_id = ? AND business_date >= ? AND business_date < ?`,
        [coupleId, addDays(date, -RECENT_WINDOW_DAYS), date],
      ),
      // 좌표·주소는 조회하지 않는다. 핀 제목만 질문에 쓴다.
      queryFn(
        `SELECT place_name FROM map_pins
         WHERE couple_id = ? AND archived_at IS NULL AND place_name <> '' ORDER BY id`,
        [coupleId],
      ),
      queryFn('SELECT label FROM anniversaries WHERE couple_id = ? ORDER BY id', [coupleId]),
    ]);
    const picked = selectQuestion({
      coupleId,
      date,
      recentQuestionIds: recent.rows.map((row) => row.question_id),
      pinTitles: pins.rows.map((row) => row.place_name),
      anniversaryLabels: anniversaries.rows.map((row) => row.label),
    });
    await queryFn(
      `INSERT IGNORE INTO two_answers (couple_id, business_date, question_id, category, question_text)
       VALUES (?, ?, ?, ?, ?)`,
      [coupleId, date, picked.questionId, picked.category, picked.text],
    );
    return findByDate(coupleId, date);
  };

  const streakFor = async (coupleId, today) => {
    const { rows } = await queryFn(
      `SELECT ${DATE_SQL} AS business_date
       FROM two_answers t
       WHERE t.couple_id = ? AND t.business_date <= ? AND t.business_date >= ?
         AND (SELECT COUNT(*) FROM two_answer_responses r WHERE r.two_answer_id = t.id) = 2`,
      [coupleId, today, addDays(today, -400)],
    );
    return computeStreak(rows.map((row) => row.business_date), today);
  };

  const view = async (question, { coupleId, userId }) => {
    const { rows } = await queryFn(
      `SELECT user_id, body, is_late, UNIX_TIMESTAMP(updated_at) AS updated_at
       FROM two_answer_responses WHERE two_answer_id = ? AND couple_id = ?`,
      [question.id, coupleId],
    );
    const mine = rows.find((row) => Number(row.user_id) === userId) ?? null;
    const partner = rows.find((row) => Number(row.user_id) !== userId) ?? null;
    const status = questionStatus({ mine, partner });
    return {
      id: Number(question.id),
      business_date: question.business_date,
      category: question.category,
      question: question.question_text,
      status,
      my_answer: mine ? { body: mine.body, is_late: Boolean(mine.is_late) } : null,
      partner_answered: Boolean(partner),
      // 둘 다 답한 뒤에만 상대 본문을 싣는다.
      partner_answer: status === 'open' ? { body: partner.body } : null,
    };
  };

  const saveResponse = async (scope, question, rawBody, isLate) => {
    const body = normalizeAnswerBody(rawBody);
    const total = await transactionFn(async (connection) => {
      const [locked] = await connection.execute(
        'SELECT id FROM two_answers WHERE id = ? AND couple_id = ? FOR UPDATE',
        [question.id, scope.coupleId],
      );
      if (!locked[0]) throw new TwoAnswersError(404, 'question_not_found');
      const [counted] = await connection.execute(
        'SELECT COUNT(*) AS total FROM two_answer_responses WHERE two_answer_id = ?',
        [question.id],
      );
      if (Number(counted[0].total) >= 2) throw new TwoAnswersError(409, 'already_open');
      await connection.execute(
        `INSERT INTO two_answer_responses (two_answer_id, couple_id, user_id, body, is_late)
         VALUES (?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE body = VALUES(body)`,
        [question.id, scope.coupleId, scope.userId, body, isLate ? 1 : 0],
      );
      const [after] = await connection.execute(
        'SELECT COUNT(*) AS total FROM two_answer_responses WHERE two_answer_id = ?',
        [question.id],
      );
      return Number(after[0].total);
    });
    // 본문 없는 상태 이벤트만, 활성 Couple 상대에게. 실패해도 답변 저장은 영향받지 않는다.
    try {
      const couple = await resolveActiveCouple(scope.userId, queryFn);
      const partnerId = couple
        ? [Number(couple.User1Id), Number(couple.User2Id)].find((id) => id !== scope.userId)
        : null;
      if (partnerId) {
        publish(partnerId, 'two-answers:updated', {
          question_id: Number(question.id),
          state: total >= 2 ? 'open' : 'partner_answered',
        });
      }
    } catch (error) {
      console.error('[two-answers] publish failed:', error?.message);
    }
  };

  return {
    async getToday(actor) {
      const scope = await requireCouple(actor);
      const today = businessDate(now());
      const question = await ensureQuestion(scope.coupleId, today);
      return {
        ...(await view(question, scope)),
        streak: await streakFor(scope.coupleId, today),
      };
    },

    async answerToday(actor, rawBody) {
      const scope = await requireCouple(actor);
      const today = businessDate(now());
      const question = await ensureQuestion(scope.coupleId, today);
      await saveResponse(scope, question, rawBody, false);
      return {
        ...(await view(question, scope)),
        streak: await streakFor(scope.coupleId, today),
      };
    },

    async answerLate(actor, rawId, rawBody) {
      const scope = await requireCouple(actor);
      const id = positiveInt(rawId);
      if (!id) throw new TwoAnswersError(404, 'question_not_found');
      const question = await findOwned(scope.coupleId, id);
      const today = businessDate(now());
      if (question.business_date >= today) throw new TwoAnswersError(400, 'not_past_question');
      await saveResponse(scope, question, rawBody, true);
      return view(question, scope);
    },

    async listMissed(actor) {
      const scope = await requireCouple(actor);
      const today = businessDate(now());
      const { rows } = await queryFn(
        `SELECT t.id, ${DATE_SQL} AS business_date, t.question_id, t.category, t.question_text
         FROM two_answers t
         WHERE t.couple_id = ? AND t.business_date < ? AND t.business_date >= ?
           AND NOT EXISTS (SELECT 1 FROM two_answer_responses r
                           WHERE r.two_answer_id = t.id AND r.user_id = ?)
         ORDER BY t.business_date DESC LIMIT 30`,
        [scope.coupleId, today, addDays(today, -RECENT_WINDOW_DAYS), scope.userId],
      );
      return Promise.all(rows.map((row) => view(row, scope)));
    },

    async listHistory(actor, { cursor, limit } = {}) {
      const scope = await requireCouple(actor);
      const size = Math.min(positiveInt(limit) ?? HISTORY_DEFAULT_LIMIT, HISTORY_MAX_LIMIT);
      const before = positiveInt(cursor) ?? Number.MAX_SAFE_INTEGER;
      const { rows } = await queryFn(
        `SELECT t.id, ${DATE_SQL} AS business_date, t.question_id, t.category, t.question_text
         FROM two_answers t
         WHERE t.couple_id = ? AND t.id < ?
           AND (SELECT COUNT(*) FROM two_answer_responses r WHERE r.two_answer_id = t.id) = 2
         ORDER BY t.id DESC LIMIT ${size + 1}`,
        [scope.coupleId, before],
      );
      const page = rows.slice(0, size);
      const items = await Promise.all(page.map((row) => view(row, scope)));
      return {
        items,
        next_cursor: rows.length > size ? Number(page[page.length - 1].id) : null,
      };
    },
  };
}
