import express from 'express';
import { PREF_FIELDS, notificationPrefs, validPreferencePatch } from './preferences.js';

const PLATFORMS = new Set(['android', 'ios', 'web']);
const parseToken = (value) => typeof value === 'string' ? value.trim() : '';

export function createNotificationRouter({ queryFn, log = console }) {
  const router = express.Router();
  router.use((req, res, next) => {
    if (!Number.isSafeInteger(req.auth?.userId) || req.auth.userId <= 0) {
      return res.status(401).json({ ok: false, reason: 'auth_required' });
    }
    next();
  });

  router.post('/device-token', async (req, res) => {
    const token = parseToken(req.body?.token);
    const platform = String(req.body?.platform ?? '').trim();
    if (!token || token.length > 512 || !PLATFORMS.has(platform)) {
      return res.status(400).json({ ok: false, reason: 'invalid_token' });
    }
    try {
      // A token belongs to whoever registered it last (shared device, re-login).
      await queryFn(
        `INSERT INTO device_tokens (user_id, platform, token, app_version, last_seen_at, revoked_at)
         VALUES (?, ?, ?, ?, NOW(), NULL)
         ON DUPLICATE KEY UPDATE user_id = VALUES(user_id), platform = VALUES(platform),
           app_version = VALUES(app_version), last_seen_at = NOW(), revoked_at = NULL`,
        [req.auth.userId, platform, token, req.body?.appVersion ? String(req.body.appVersion).slice(0, 32) : null],
      );
      return res.json({ ok: true });
    } catch {
      log.error('[API] /device-token POST failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.delete('/device-token', async (req, res) => {
    const token = parseToken(req.body?.token);
    if (!token || token.length > 512) return res.status(400).json({ ok: false, reason: 'invalid_token' });
    try {
      await queryFn(
        'UPDATE device_tokens SET revoked_at = NOW() WHERE token = ? AND user_id = ?',
        [token, req.auth.userId],
      );
      return res.json({ ok: true });
    } catch {
      log.error('[API] /device-token DELETE failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.get('/notification-prefs', async (req, res) => {
    try {
      const { rows } = await queryFn(
        `SELECT ${PREF_FIELDS.join(', ')} FROM notification_prefs WHERE user_id = ?`,
        [req.auth.userId],
      );
      const row = rows[0] ?? {};
      return res.json({
        ok: true,
        prefs: notificationPrefs(row),
      });
    } catch {
      log.error('[API] /notification-prefs GET failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.put('/notification-prefs', async (req, res) => {
    const input = req.body ?? {};
    if (!validPreferencePatch(input)) {
      return res.status(400).json({ ok: false, reason: 'invalid_prefs' });
    }
    const fields = PREF_FIELDS.filter((field) => Object.hasOwn(input, field));
    try {
      // Only whitelisted fields are updated; an omitted field keeps its value.
      await queryFn(
        `INSERT INTO notification_prefs (user_id, ${fields.join(', ')})
         VALUES (?, ${fields.map(() => '?').join(', ')})
         ON DUPLICATE KEY UPDATE ${fields.map((field) => `${field} = VALUES(${field})`).join(', ')}`,
        [req.auth.userId, ...fields.map((field) => typeof input[field] === 'boolean' ? Number(input[field]) : input[field])],
      );
      return res.json({ ok: true });
    } catch {
      log.error('[API] /notification-prefs PUT failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  return router;
}
