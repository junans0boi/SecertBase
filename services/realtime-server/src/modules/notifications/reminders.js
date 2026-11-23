// Scheduled reminders: 기념일 D-1, 마주 열기 "상대가 답했어요".
// Same lock/sent/delivered dedupe as the today-loop scheduler. Push bodies are fixed copy;
// no label, answer or place ever reaches FCM. Quiet hours / prefs are enforced by the notifier.
import { randomUUID } from 'node:crypto';
import { kstMinute } from './preferences.js';

export const ANNIVERSARY_SEND_HOUR_KST = 10;
const DELIVERY_TTL = 172800;
const RELEASE_LOCK = `if redis.call('get', KEYS[1]) == ARGV[1] then
  return redis.call('del', KEYS[1]) end return 0`;

const kstDate = (value, offsetDays = 0) => {
  const date = new Date(value.getTime() + 9 * 60 * 60 * 1000 + offsetDays * 86400000);
  return date.toISOString().slice(0, 10);
};

// One push per (key); retried each tick while it is deferred (quiet hours, temporary failure).
async function sendOnce({ redis, notifier, key, userId, type }) {
  if (await redis.get(`${key}:sent`)) return 0;
  const owner = randomUUID();
  if ((await redis.set(`${key}:lock`, owner, 'EX', 300, 'NX')) !== 'OK') return 0;
  try {
    if (await redis.get(`${key}:sent`)) return 0;
    const skipTokens = await redis.smembers(`${key}:delivered`);
    const result = await notifier.notifyUser(userId, type, {}, { skipTokens });
    if (result.deliveredTokens?.length) {
      await redis.sadd(`${key}:delivered`, ...result.deliveredTokens);
      await redis.expire(`${key}:delivered`, DELIVERY_TTL);
    }
    // A user who turned this type off will not be retried every minute.
    if ((result.sent > 0 && !result.failed) || result.skipped === 'already_delivered' || result.skipped === 'pref_off') {
      await redis.set(`${key}:sent`, '1', 'EX', DELIVERY_TTL);
    }
    return result.sent > 0 ? 1 : 0;
  } finally {
    await redis.eval(RELEASE_LOCK, 1, `${key}:lock`, owner);
  }
}

// Anniversaries falling on tomorrow (KST), for both members of an active Couple.
export async function notifyAnniversaryEve({ queryFn, redis, notifier, now = () => new Date() }) {
  const instant = now();
  if (kstMinute(instant) < ANNIVERSARY_SEND_HOUR_KST * 60) return 0;
  const target = kstDate(instant, 1);
  const monthDay = target.slice(5);
  const { rows } = await queryFn(
    `SELECT DISTINCT a.couple_id, c.User1Id AS user1_id, c.User2Id AS user2_id
     FROM anniversaries a
     JOIN Couples c ON c.CoupleId = a.couple_id AND c.Status = 'active'
     WHERE a.date = ? OR (a.repeat_yearly = 1 AND DATE_FORMAT(a.date, '%m-%d') = ? AND a.date <= ?)`,
    [target, monthDay, target],
  );
  let sent = 0;
  for (const row of rows) {
    for (const userId of [Number(row.user1_id), Number(row.user2_id)]) {
      sent += await sendOnce({
        redis, notifier, userId, type: 'anniversary_eve',
        key: `push:anniversary_eve:${row.couple_id}:${target}:${userId}`,
      });
    }
  }
  return sent;
}

// Today's question: exactly one of the two has answered -> remind the other, once per day.
export async function notifyTwoAnswersWaiting({ queryFn, redis, notifier, now = () => new Date() }) {
  const date = kstDate(now());
  const { rows } = await queryFn(
    `SELECT t.couple_id, DATE_FORMAT(t.business_date, '%Y-%m-%d') AS business_date,
       CASE WHEN c.User1Id = r.user_id THEN c.User2Id ELSE c.User1Id END AS recipient_id
     FROM two_answers t
     JOIN two_answer_responses r ON r.two_answer_id = t.id
     JOIN Couples c ON c.CoupleId = t.couple_id AND c.Status = 'active'
       AND r.user_id IN (c.User1Id, c.User2Id)
     WHERE t.business_date = ?
       AND NOT EXISTS (SELECT 1 FROM two_answer_responses r2
                       WHERE r2.two_answer_id = t.id AND r2.user_id <> r.user_id)`,
    [date],
  );
  let sent = 0;
  for (const row of rows) {
    const userId = Number(row.recipient_id);
    sent += await sendOnce({
      redis, notifier, userId, type: 'two_answers_waiting',
      key: `push:two_answers_waiting:${row.couple_id}:${row.business_date}:${userId}`,
    });
  }
  return sent;
}

export function startReminderScheduler({ cron, queryFn, redis, notifier, log = console, now = () => new Date() }) {
  return cron.schedule('* * * * *', async () => {
    for (const job of [notifyAnniversaryEve, notifyTwoAnswersWaiting]) {
      try {
        await job({ queryFn, redis, notifier, now });
      } catch {
        log.error(`[Push] ${job.name} failed`);
      }
    }
  }, { timezone: 'Asia/Seoul', noOverlap: true });
}
