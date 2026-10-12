// Push notifications: resolve recipient -> non-revoked tokens -> FCM.
// The sender is injected so tests (and servers without Firebase credentials) never touch FCM.

export const NOTIFICATION_TYPES = Object.freeze(['partner_moment', 'today_loop', 'game_invite']);

// Bodies are deliberately generic: no place names, captions, or other sensitive content.
export const MESSAGES = Object.freeze({
  partner_moment: { title: 'Secret Base', body: '상대방이 새 기록을 남겼어요.', screen: 'moment_detail' },
  today_loop: { title: 'Secret Base', body: '오늘의 루프가 공개됐어요.', screen: 'today_loop' },
  game_invite: { title: 'Secret Base', body: '상대방이 게임에 초대했어요.', screen: 'game_invite' },
});

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
        : (await import('firebase-admin')).default;
      const credential = json
        ? admin.credential.cert(JSON.parse(json))
        : admin.credential.applicationDefault();
      const app = admin.apps.length ? admin.app() : admin.initializeApp({ credential });
      return admin.messaging(app);
    })();
    return messagingPromise;
  };
  return {
    async send({ tokens, notification, data }) {
      const messaging = await getMessaging();
      const res = await messaging.sendEachForMulticast({ tokens, notification, data });
      return res.responses.map((r, i) => ({
        token: tokens[i],
        errorCode: r.success ? null : r.error?.code ?? 'unknown',
      }));
    },
  };
}

export function createNotifier({ queryFn, sender = null, log = console } = {}) {
  if (!queryFn) throw new TypeError('createNotifier requires queryFn');

  const partnerOf = async (userId) => {
    const { rows } = await queryFn(
      `SELECT CASE WHEN User1Id = ? THEN User2Id ELSE User1Id END AS partner_id
       FROM Couples WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?) LIMIT 1`,
      [userId, userId, userId],
    );
    return rows[0]?.partner_id ?? null;
  };

  const sendToUser = async (userId, type) => {
    const message = MESSAGES[type];
    if (!message) return { sent: 0, skipped: 'unknown_type' };
    if (!sender) {
      log.log(`[Push] sender not configured; skip ${type}`);
      return { sent: 0, skipped: 'no_sender' };
    }
    // `type` is whitelisted by MESSAGES above, so interpolating the column is safe.
    const { rows: prefRows } = await queryFn(
      `SELECT ${type} AS enabled FROM notification_prefs WHERE user_id = ?`,
      [userId],
    );
    if (prefRows[0] && !Number(prefRows[0].enabled)) return { sent: 0, skipped: 'pref_off' };

    const { rows: tokenRows } = await queryFn(
      'SELECT token FROM device_tokens WHERE user_id = ? AND revoked_at IS NULL',
      [userId],
    );
    const tokens = tokenRows.map((r) => r.token);
    if (!tokens.length) return { sent: 0, skipped: 'no_tokens' };

    const results = await sender.send({
      tokens,
      notification: { title: message.title, body: message.body },
      data: { screen: message.screen, type },
    });
    const dead = results.filter((r) => REVOKE_CODES.has(r.errorCode)).map((r) => r.token);
    for (const token of dead) {
      await queryFn('UPDATE device_tokens SET revoked_at = NOW() WHERE token = ?', [token]);
    }
    return { sent: results.filter((r) => !r.errorCode).length, revoked: dead.length };
  };

  return {
    // Never throw: a push failure must not fail the request that triggered it.
    async notifyPartner(actorUserId, type) {
      try {
        const partnerId = await partnerOf(actorUserId);
        if (!partnerId) return { sent: 0, skipped: 'no_partner' };
        return await sendToUser(partnerId, type);
      } catch (error) {
        log.error('[Push] notifyPartner failed:', error.message);
        return { sent: 0, skipped: 'error' };
      }
    },
    async notifyUser(userId, type) {
      try {
        return await sendToUser(userId, type);
      } catch (error) {
        log.error('[Push] notifyUser failed:', error.message);
        return { sent: 0, skipped: 'error' };
      }
    },
  };
}

// Today Loop reveal is event-driven (set when the 2nd partner designates), so the
// cron scans today's revealed couples; a per-couple/date Redis NX key sends once.
export async function notifyRevealedTodayLoops({ queryFn, redis, notifier, date }) {
  const { rows } = await queryFn(
    `SELECT DISTINCT couple_id, user_id FROM today_moments
     WHERE business_date = ? AND revealed_at IS NOT NULL AND deleted_at IS NULL`,
    [date],
  );
  const byCouple = new Map();
  for (const r of rows) {
    byCouple.set(r.couple_id, [...(byCouple.get(r.couple_id) ?? []), r.user_id]);
  }
  let notified = 0;
  for (const [coupleId, userIds] of byCouple) {
    const locked = await redis.set(`push:today_loop:${coupleId}:${date}`, '1', 'EX', 172800, 'NX');
    if (locked !== 'OK') continue;
    for (const userId of userIds) await notifier.notifyUser(userId, 'today_loop');
    notified += 1;
  }
  return notified;
}

export function startTodayLoopScheduler({ cron, queryFn, redis, notifier, businessDate, log = console }) {
  return cron.schedule('* * * * *', async () => {
    try {
      await notifyRevealedTodayLoops({ queryFn, redis, notifier, date: businessDate() });
    } catch (error) {
      log.error('[Push] today-loop scheduler failed:', error.message);
    }
  });
}
