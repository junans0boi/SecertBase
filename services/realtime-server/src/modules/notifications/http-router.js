import express from 'express';
import { NOTIFICATION_TYPES } from './notifier.js';

const PLATFORMS = new Set(['android', 'ios', 'web']);

export function createNotificationRouter({ queryFn }) {
  const router = express.Router();

  router.post('/device-token', async (req, res) => {
    const token = String(req.body?.token ?? '').trim();
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
    } catch (error) {
      console.error('[API] /device-token POST error:', error);
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.delete('/device-token', async (req, res) => {
    const token = String(req.body?.token ?? '').trim();
    if (!token) return res.status(400).json({ ok: false, reason: 'invalid_token' });
    try {
      await queryFn(
        'UPDATE device_tokens SET revoked_at = NOW() WHERE token = ? AND user_id = ?',
        [token, req.auth.userId],
      );
      return res.json({ ok: true });
    } catch (error) {
      console.error('[API] /device-token DELETE error:', error);
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.get('/notification-prefs', async (req, res) => {
    try {
      const { rows } = await queryFn(
        'SELECT partner_moment, today_loop, game_invite FROM notification_prefs WHERE user_id = ?',
        [req.auth.userId],
      );
      const row = rows[0] ?? {};
      return res.json({
        ok: true,
        prefs: Object.fromEntries(
          NOTIFICATION_TYPES.map((t) => [t, row[t] === undefined ? true : Boolean(Number(row[t]))]),
        ),
      });
    } catch (error) {
      console.error('[API] /notification-prefs GET error:', error);
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.put('/notification-prefs', async (req, res) => {
    const input = req.body ?? {};
    const types = NOTIFICATION_TYPES.filter((t) => input[t] !== undefined);
    if (!types.length || types.some((t) => typeof input[t] !== 'boolean')) {
      return res.status(400).json({ ok: false, reason: 'invalid_prefs' });
    }
    try {
      // Column names come from the NOTIFICATION_TYPES whitelist, never from input.
      await queryFn(
        `INSERT INTO notification_prefs (user_id, ${types.join(', ')})
         VALUES (?, ${types.map(() => '?').join(', ')})
         ON DUPLICATE KEY UPDATE ${types.map((t) => `${t} = VALUES(${t})`).join(', ')}`,
        [req.auth.userId, ...types.map((t) => (input[t] ? 1 : 0))],
      );
      return res.json({ ok: true });
    } catch (error) {
      console.error('[API] /notification-prefs PUT error:', error);
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  return router;
}
