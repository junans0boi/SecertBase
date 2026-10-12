// Push notifications: resolve recipient -> non-revoked tokens -> FCM.
// The sender is injected so tests (and servers without Firebase credentials) never touch FCM.
import { randomUUID } from 'node:crypto';
import { PREF_FIELDS, notificationPrefs, inQuietHours, kstMinute } from './preferences.js';

export const NOTIFICATION_TYPES = Object.freeze(['partner_moment', 'today_loop', 'game_invite']);

// Bodies are deliberately generic: no place names, captions, or other sensitive content.
export const MESSAGES = Object.freeze({
  partner_moment: { title: 'Secret Base', body: '상대방이 새 기록을 남겼어요.', screen: 'moment_detail' },
  today_loop: { title: 'Secret Base', body: '오늘의 루프가 공개됐어요.', screen: 'today_loop' },
  game_invite: { title: 'Secret Base', body: '상대방이 게임에 초대했어요.', screen: 'game_invite' },
});

const validUserId = (id) => Number.isSafeInteger(id) && id > 0;
const DATA_FIELDS = Object.freeze({
  partner_moment: ['post_id', 'session_id'],
  today_loop: ['business_date'],
  game_invite: ['game_type', 'room_code'],
});

function payload(type, extraData) {
  const data = { screen: MESSAGES[type].screen, type };
  for (const field of DATA_FIELDS[type]) {
    const value = extraData?.[field];
    if ((typeof value === 'string' || typeof value === 'number') && String(value).length <= 128) {
      data[field] = String(value);
    }
  }
  return data;
}

const REVOKE_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

// Sender contract: send({ tokens, notification, data }) -> [{ token, errorCode }]
// Returns null (notifier no-ops) when no Firebase credentials are configured.
export function createFcmSender({ env = process.env, log = console, importAdmin } = {}) {
  const json = env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json && !env.GOOGLE_APPLICATION_CREDENTIALS) {
    log.log('[Push] no Firebase credentials configured; push notifications disabled');
    return null;
  }
  let messagingPromise;
  const getMessaging = () => {
    messagingPromise ??= (async () => {
      const admin = importAdmin
        ? await importAdmin()
        : Object.assign({}, ...await Promise.all([import('firebase-admin/app'), import('firebase-admin/messaging')]));
      const credential = json
        ? admin.cert(JSON.parse(json))
        : admin.applicationDefault();
      const app = admin.getApps().length ? admin.getApp() : admin.initializeApp({ credential });
      return admin.getMessaging(app);
    })().catch((error) => {
      messagingPromise = undefined;
      throw error;
    });
    return messagingPromise;
  };
  return {
    async send({ tokens, notification, data }) {
      const messaging = await getMessaging();
      const results = [];
      for (let offset = 0; offset < tokens.length; offset += 500) {
        const batch = tokens.slice(offset, offset + 500);
        try {
          const res = await messaging.sendEachForMulticast({ tokens: batch, notification, data });
          results.push(...res.responses.map((r, i) => ({
            token: batch[i], errorCode: r.success ? null : r.error?.code ?? 'unknown',
          })));
        } catch (error) {
          // A rejected request is not per-token evidence; never revoke its tokens.
          const errorCode = REVOKE_CODES.has(error.code) ? 'messaging/batch-error' : error.code ?? 'unknown';
          results.push(...batch.map((token) => ({ token, errorCode })));
        }
      }
      return results;
    },
  };
}

export function createNotifier({ queryFn, sender = null, log = console, now = () => new Date() } = {}) {
  if (!queryFn) throw new TypeError('createNotifier requires queryFn');

  const partnerOf = async (userId) => {
    const { rows } = await queryFn(
      `SELECT CASE WHEN User1Id = ? THEN User2Id ELSE User1Id END AS partner_id
       FROM Couples WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?) LIMIT 1`,
      [userId, userId, userId],
    );
    return rows[0]?.partner_id ?? null;
  };

  const sendToUser = async (userId, type, extraData, { skipTokens = [] } = {}) => {
    if (!validUserId(userId)) return { sent: 0, skipped: 'invalid_user' };
    if (!Object.hasOwn(MESSAGES, type)) return { sent: 0, skipped: 'unknown_type' };
    const message = MESSAGES[type];
    if (!sender) {
      log.log(`[Push] sender not configured; skip ${type}`);
      return { sent: 0, skipped: 'no_sender' };
    }
    const { rows: prefRows } = await queryFn(
      `SELECT ${PREF_FIELDS.join(', ')} FROM notification_prefs WHERE user_id = ?`,
      [userId],
    );
    const prefs = notificationPrefs(prefRows[0]);
    if (!prefs[type]) return { sent: 0, skipped: 'pref_off' };
    if (inQuietHours(prefs, now())) return { sent: 0, skipped: 'quiet_hours' };

    const { rows: tokenRows } = await queryFn(
      'SELECT token FROM device_tokens WHERE user_id = ? AND revoked_at IS NULL',
      [userId],
    );
    const excluded = new Set(skipTokens);
    const tokens = [...new Set(tokenRows.map((r) => r.token))].filter((token) => !excluded.has(token));
    if (!tokens.length) return { sent: 0, skipped: skipTokens.length ? 'already_delivered' : 'no_tokens' };

    const results = await sender.send({
      tokens,
      notification: { title: message.title, body: message.body },
      data: payload(type, extraData),
    });
    const dead = results.filter((r) => REVOKE_CODES.has(r.errorCode)).map((r) => r.token);
    let revoked = 0;
    let failedRevocations = 0;
    for (const token of dead) {
      try {
        await queryFn('UPDATE device_tokens SET revoked_at = NOW() WHERE token = ? AND user_id = ?', [token, userId]);
        revoked += 1;
      } catch {
        // Preserve successes so retrying this recipient never repeats them.
        failedRevocations += 1;
        log.error('[Push] token revocation failed');
      }
    }
    const deliveredTokens = results.filter((r) => !r.errorCode).map((r) => r.token);
    return {
      sent: deliveredTokens.length,
      revoked,
      failed: failedRevocations + results.filter((r) => r.errorCode && !REVOKE_CODES.has(r.errorCode)).length,
      deliveredTokens,
    };
  };

  return {
    // Never throw: a push failure must not fail the request that triggered it.
    async notifyPartner(actorUserId, type, extraData = {}) {
      if (!validUserId(actorUserId)) return { sent: 0, skipped: 'invalid_user' };
      try {
        const partnerId = await partnerOf(actorUserId);
        if (!partnerId) return { sent: 0, skipped: 'no_partner' };
        return await sendToUser(Number(partnerId), type, extraData);
      } catch {
        log.error('[Push] notifyPartner failed');
        return { sent: 0, skipped: 'error' };
      }
    },
    async notifyUser(userId, type, extraData = {}, delivery = {}) {
      try {
        return await sendToUser(userId, type, extraData, delivery);
      } catch {
        log.error('[Push] notifyUser failed');
        return { sent: 0, skipped: 'error' };
      }
    },
  };
}

const DELIVERY_TTL = 172800;
const RELEASE_LOCK = `if redis.call('get', KEYS[1]) == ARGV[1] then
  return redis.call('del', KEYS[1]) end return 0`;

// Scan yesterday too: a reveal during quiet hours can be delivered next morning.
export async function notifyRevealedTodayLoops({ queryFn, redis, notifier, date, now = () => new Date() }) {
  const previous = new Date(`${date}T00:00:00Z`);
  previous.setUTCDate(previous.getUTCDate() - 1);
  const { rows } = await queryFn(
    `SELECT DISTINCT t.couple_id, t.user_id, DATE_FORMAT(t.business_date, '%Y-%m-%d') AS business_date,
       COALESCE(p.reveal_hour, 21) AS reveal_hour
     FROM today_moments t
     JOIN Couples c ON c.CoupleId = t.couple_id AND c.Status = 'active'
       AND t.user_id IN (c.User1Id, c.User2Id)
     LEFT JOIN notification_prefs p ON p.user_id = t.user_id
     WHERE t.business_date BETWEEN ? AND ? AND t.revealed_at IS NOT NULL AND t.deleted_at IS NULL`,
    [previous.toISOString().slice(0, 10), date],
  );
  const notified = new Set();
  for (const row of rows) {
    const deliveryDate = row.business_date;
    if (deliveryDate === date && kstMinute(now()) < Number(row.reveal_hour ?? 21) * 60) continue;
    const userId = Number(row.user_id);
    const key = `push:today_loop:${row.couple_id}:${deliveryDate}:${userId}`;
    if (await redis.get(`${key}:sent`)) continue;
    const owner = randomUUID();
    const locked = await redis.set(`${key}:lock`, owner, 'EX', 300, 'NX');
    if (locked !== 'OK') continue;
    try {
      if (await redis.get(`${key}:sent`)) continue;
      const skipTokens = await redis.smembers(`${key}:delivered`);
      const result = await notifier.notifyUser(userId, 'today_loop', { business_date: deliveryDate }, { skipTokens });
      if (result.deliveredTokens?.length) {
        await redis.sadd(`${key}:delivered`, ...result.deliveredTokens);
        await redis.expire(`${key}:delivered`, DELIVERY_TTL);
      }
      if ((result.sent > 0 && !result.failed) || result.skipped === 'already_delivered') {
        await redis.set(`${key}:sent`, '1', 'EX', DELIVERY_TTL);
      }
      if (result.sent > 0) {
        notified.add(`${row.couple_id}:${deliveryDate}`);
      }
    } finally {
      await redis.eval(RELEASE_LOCK, 1, `${key}:lock`, owner);
    }
  }
  return notified.size;
}

export function startTodayLoopScheduler({ cron, queryFn, redis, notifier, businessDate, log = console, now = () => new Date() }) {
  return cron.schedule('* * * * *', async () => {
    try {
      const instant = now();
      await notifyRevealedTodayLoops({ queryFn, redis, notifier, date: businessDate(instant), now: () => instant });
    } catch {
      log.error('[Push] today-loop scheduler failed');
    }
  }, { timezone: 'Asia/Seoul', noOverlap: true });
}
