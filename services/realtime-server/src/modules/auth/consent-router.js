// 로그인한 사용자의 동의 이력과 Google 신규 가입 마무리.
//   GET  /user/consents             → 항목별 최신 동의 상태와 현재 문서 버전
//   PUT  /user/consents/marketing   { agreed }  → 마케팅 수신 동의 변경(이력 추가)
//   POST /auth/complete-signup      { nickname, birth_date, consents } → Google 신규 가입 마무리
// requireAuth 뒤에 붙인다(req.auth.userId).
import express from 'express';
import {
  CONSENT_TYPES,
  CONSENT_VERSIONS,
  MIN_SIGNUP_AGE,
  ageOn,
  isMissingSchemaError,
  isValidBirthDate,
  normalizeConsents,
  recordConsents,
} from './policy.js';

export const NICKNAME_MAX_LENGTH = 50;

export function createConsentRouter({ queryFn, now = () => new Date(), log = console }) {
  if (typeof queryFn !== 'function') throw new TypeError('queryFn is required');
  const router = express.Router();
  const userIdOf = (req) => {
    const id = req.auth?.userId;
    return Number.isSafeInteger(id) && id > 0 ? id : null;
  };

  router.get('/user/consents', async (req, res) => {
    const userId = userIdOf(req);
    if (!userId) return res.status(401).json({ ok: false, reason: 'auth_required' });
    try {
      const { rows } = await queryFn(
        `SELECT consent_type, version, agreed, source, agreed_at
         FROM user_consents WHERE user_id = ?
         ORDER BY agreed_at DESC, id DESC`,
        [userId],
      );
      const consents = {};
      for (const type of CONSENT_TYPES) consents[type] = null;
      for (const row of rows) {
        const type = String(row.consent_type);
        if (!(type in consents) || consents[type]) continue;
        consents[type] = {
          agreed: Number(row.agreed) === 1,
          version: String(row.version),
          source: String(row.source),
          agreedAt: row.agreed_at instanceof Date ? row.agreed_at.toISOString() : String(row.agreed_at),
        };
      }
      return res.json({ ok: true, consents, versions: CONSENT_VERSIONS });
    } catch (error) {
      if (isMissingSchemaError(error)) {
        return res.status(503).json({ ok: false, reason: 'consents_unavailable' });
      }
      log.error?.('[API] /user/consents GET failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.put('/user/consents/marketing', async (req, res) => {
    const userId = userIdOf(req);
    if (!userId) return res.status(401).json({ ok: false, reason: 'auth_required' });
    const agreed = req.body?.agreed;
    if (typeof agreed !== 'boolean') {
      return res.status(400).json({ ok: false, reason: 'invalid_consents' });
    }
    try {
      await queryFn(
        `INSERT INTO user_consents (user_id, consent_type, version, agreed, source)
         VALUES (?, 'marketing', ?, ?, 'settings')`,
        [userId, CONSENT_VERSIONS.marketing, agreed ? 1 : 0],
      );
      return res.json({ ok: true, agreed });
    } catch (error) {
      if (isMissingSchemaError(error)) {
        return res.status(503).json({ ok: false, reason: 'consents_unavailable' });
      }
      log.error?.('[API] /user/consents/marketing failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.post('/auth/complete-signup', async (req, res) => {
    const userId = userIdOf(req);
    if (!userId) return res.status(401).json({ ok: false, reason: 'auth_required' });
    const nickname = String(req.body?.nickname ?? '').trim();
    const birthDate = String(req.body?.birth_date ?? req.body?.birthDate ?? '').trim();
    if (!nickname || !birthDate) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    if (nickname.length > NICKNAME_MAX_LENGTH) {
      return res.status(400).json({ ok: false, reason: 'invalid_nickname' });
    }
    const today = now();
    if (!isValidBirthDate(birthDate, today)) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_date' });
    }
    if (ageOn(birthDate, today) < MIN_SIGNUP_AGE) {
      return res.status(400).json({ ok: false, reason: 'under_age' });
    }
    const consents = normalizeConsents(req.body?.consents, { allowLegacy: false });
    if (!consents.ok) return res.status(400).json({ ok: false, reason: consents.reason });

    try {
      let updated;
      try {
        updated = await queryFn(
          `UPDATE Users
           SET Nickname = ?, UserName = ?, BirthDate = ?, SignupCompletedAt = ?
           WHERE UserId = ? AND SignupCompletedAt IS NULL`,
          [nickname, nickname, birthDate, today, userId],
        );
      } catch (error) {
        if (!isMissingSchemaError(error)) throw error;
        // 0050 전 스키마: 가입 마무리 컬럼이 없으면 프로필만 갱신한다.
        updated = await queryFn(
          'UPDATE Users SET Nickname = ?, UserName = ?, BirthDate = ? WHERE UserId = ?',
          [nickname, nickname, birthDate, userId],
        );
      }
      if (Number(updated?.rows?.affectedRows ?? 0) === 0) {
        return res.status(409).json({ ok: false, reason: 'signup_already_completed' });
      }
      await recordConsents(queryFn, userId, consents.records, 'google_signup', () => {
        log.error?.('[API] user_consents table missing; run migration 0050');
      });
      return res.json({ ok: true });
    } catch {
      log.error?.('[API] /auth/complete-signup failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  return router;
}
