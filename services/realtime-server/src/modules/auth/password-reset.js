// 비밀번호 재설정(2.0 신규).
//   POST /auth/password-reset/request  { email }                       → 메일로 6자리 코드 + 링크
//   POST /auth/password-reset/verify   { email, code } | { token }     → 코드가 맞는지만 확인
//   POST /auth/password-reset/confirm  { email, code } | { token }, password → 새 비밀번호 저장
//
// - 가입 여부를 드러내지 않는다: 없는 이메일에도 같은 성공 응답을 준다.
// - 발송 수단이 없으면 이메일을 조회하기 전에 503 mail_unavailable 을 준다.
// - 코드·링크 토큰은 HMAC 해시만 저장하고, 1시간 뒤 만료, 5번 틀리면 잠긴다, 한 번만 쓸 수 있다.
import express from 'express';
import bcrypt from 'bcryptjs';
import { createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { createRateLimiter, clientIpKey, emailKey } from '../../shared/rate-limit.js';
import { isStrongPassword } from './policy.js';
import { MailUnavailableError } from './mailer.js';

export const RESET_CODE_TTL_MS = 60 * 60 * 1000;
export const RESET_RESEND_COOLDOWN_SECONDS = 60;
export const RESET_MAX_ATTEMPTS = 5;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CODE_PATTERN = /^\d{6}$/;

const normalizeEmail = (value) => (typeof value === 'string' ? value.trim() : '');

export function createPasswordResetRouter({
  queryFn,
  mailer,
  secret,
  appUrl = 'https://secretbase.cloud',
  now = () => new Date(),
  generateCode = () => String(randomInt(0, 1_000_000)).padStart(6, '0'),
  generateLinkToken = () => randomBytes(32).toString('base64url'),
  limiterEnabled = true,
  log = console,
}) {
  if (typeof queryFn !== 'function') throw new TypeError('queryFn is required');
  if (!mailer) throw new TypeError('mailer is required');
  if (!secret) throw new TypeError('secret is required');

  const hash = (kind, value) =>
    createHmac('sha256', secret).update(`${kind}:${value}`).digest('hex');
  const sameHash = (a, b) => {
    const left = Buffer.from(String(a ?? ''), 'utf8');
    const right = Buffer.from(String(b ?? ''), 'utf8');
    return left.length === right.length && timingSafeEqual(left, right);
  };

  const router = express.Router();
  const requestLimiters = [
    // 같은 이메일로는 60초에 한 번(재전송 쿨다운), 한 시간에 5번까지.
    createRateLimiter({
      windowMs: RESET_RESEND_COOLDOWN_SECONDS * 1000,
      max: 1,
      keyFn: emailKey('reset-cooldown'),
      enabled: limiterEnabled,
      now: () => now().getTime(),
    }),
    createRateLimiter({
      windowMs: 60 * 60 * 1000,
      max: 5,
      keyFn: emailKey('reset-hour'),
      enabled: limiterEnabled,
      now: () => now().getTime(),
    }),
    createRateLimiter({
      windowMs: 60 * 60 * 1000,
      max: 30,
      keyFn: clientIpKey('reset'),
      enabled: limiterEnabled,
      now: () => now().getTime(),
    }),
  ];
  const verifyLimiter = createRateLimiter({
    windowMs: 15 * 60 * 1000,
    max: 60,
    keyFn: clientIpKey('reset-verify'),
    enabled: limiterEnabled,
    now: () => now().getTime(),
  });

  const accepted = (res) =>
    res.json({
      ok: true,
      cooldownSeconds: RESET_RESEND_COOLDOWN_SECONDS,
      expiresInMinutes: Math.round(RESET_CODE_TTL_MS / 60000),
    });

  router.post('/auth/password-reset/request', ...requestLimiters, async (req, res) => {
    const email = normalizeEmail(req.body?.email);
    if (!email || email.length > 255 || !EMAIL_PATTERN.test(email)) {
      return res.status(400).json({ ok: false, reason: 'invalid_email' });
    }
    if (!mailer.available) {
      return res.status(503).json({ ok: false, reason: 'mail_unavailable' });
    }
    try {
      const { rows } = await queryFn(
        `SELECT UserId, Email, PasswordHash, AuthProvider, IsDeleted
         FROM Users WHERE Email = ? LIMIT 1`,
        [email],
      );
      const user = rows[0];
      if (!user || Number(user.IsDeleted) === 1) return accepted(res);

      const hasPassword = Boolean(user.PasswordHash && String(user.PasswordHash).length > 0);
      if (!hasPassword) {
        await mailer.send({
          to: user.Email,
          subject: '[비밀기지] Google 계정으로 가입한 이메일이에요',
          text: [
            '비밀번호 재설정을 요청하셨어요.',
            '이 이메일은 Google 계정으로 가입되어 있어 따로 비밀번호가 없어요.',
            '앱의 "Google로 계속하기"를 눌러 로그인해 주세요.',
            '',
            '요청한 적이 없다면 이 메일은 무시해도 돼요.',
          ].join('\n'),
        });
        return accepted(res);
      }

      const code = generateCode();
      const linkToken = generateLinkToken();
      const issuedAt = now();
      const expiresAt = new Date(issuedAt.getTime() + RESET_CODE_TTL_MS);
      // 새 코드를 보내면 이전 코드는 쓸 수 없다.
      await queryFn(
        'UPDATE password_reset_tokens SET used_at = ? WHERE user_id = ? AND used_at IS NULL',
        [issuedAt, user.UserId],
      );
      const inserted = await queryFn(
        `INSERT INTO password_reset_tokens (user_id, code_hash, link_hash, expires_at)
         VALUES (?, ?, ?, ?)`,
        [user.UserId, hash(`code:${user.UserId}`, code), hash('link', linkToken), expiresAt],
      );
      const link = `${appUrl.replace(/\/$/, '')}/?reset=${encodeURIComponent(linkToken)}`;
      try {
        await mailer.send({
          to: user.Email,
          subject: '[비밀기지] 비밀번호 재설정 코드',
          text: [
            '비밀번호 재설정 코드예요.',
            '',
            `    ${code}`,
            '',
            '앱에 이 코드를 입력하거나, 아래 링크를 눌러 새 비밀번호를 만들어 주세요.',
            link,
            '',
            '코드와 링크는 1시간 동안만 쓸 수 있어요.',
            '요청한 적이 없다면 이 메일은 무시해도 돼요. 비밀번호는 바뀌지 않아요.',
          ].join('\n'),
        });
      } catch (error) {
        const insertId = inserted?.rows?.insertId;
        if (insertId) {
          await queryFn('UPDATE password_reset_tokens SET used_at = ? WHERE id = ?', [issuedAt, insertId])
            .catch(() => {});
        }
        throw error;
      }
      return accepted(res);
    } catch (error) {
      if (error instanceof MailUnavailableError) {
        log.error?.('[API] password reset mail unavailable');
        return res.status(503).json({ ok: false, reason: 'mail_unavailable' });
      }
      log.error?.('[API] /auth/password-reset/request failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  /**
   * 요청 본문으로 유효한 재설정 토큰 행을 찾는다. 틀린 코드는 시도 횟수를 올린다.
   * @returns {{ row } | { status, body }}
   */
  const resolveToken = async (body) => {
    const linkToken = typeof body?.token === 'string' ? body.token.trim() : '';
    let row;
    if (linkToken) {
      if (linkToken.length > 128) return { status: 400, body: { ok: false, reason: 'invalid_code' } };
      const { rows } = await queryFn(
        `SELECT id, user_id, code_hash, link_hash, attempts, expires_at, used_at
         FROM password_reset_tokens WHERE link_hash = ? LIMIT 1`,
        [hash('link', linkToken)],
      );
      row = rows[0];
      if (!row || row.used_at) return { status: 400, body: { ok: false, reason: 'invalid_code' } };
    } else {
      const email = normalizeEmail(body?.email);
      const code = typeof body?.code === 'string' ? body.code.trim() : '';
      if (!email || !CODE_PATTERN.test(code)) {
        return { status: 400, body: { ok: false, reason: 'invalid_code' } };
      }
      const { rows } = await queryFn(
        `SELECT t.id, t.user_id, t.code_hash, t.link_hash, t.attempts, t.expires_at, t.used_at
         FROM password_reset_tokens t
         JOIN Users u ON u.UserId = t.user_id
         WHERE u.Email = ? AND t.used_at IS NULL
         ORDER BY t.id DESC LIMIT 1`,
        [email],
      );
      row = rows[0];
      if (!row) return { status: 400, body: { ok: false, reason: 'invalid_code' } };
      if (Number(row.attempts) >= RESET_MAX_ATTEMPTS) {
        return { status: 429, body: { ok: false, reason: 'too_many_attempts' } };
      }
      if (new Date(row.expires_at).getTime() <= now().getTime()) {
        return { status: 410, body: { ok: false, reason: 'code_expired' } };
      }
      if (!sameHash(row.code_hash, hash(`code:${row.user_id}`, code))) {
        await queryFn(
          'UPDATE password_reset_tokens SET attempts = attempts + 1 WHERE id = ?',
          [row.id],
        );
        const attemptsLeft = Math.max(0, RESET_MAX_ATTEMPTS - Number(row.attempts) - 1);
        return attemptsLeft === 0
          ? { status: 429, body: { ok: false, reason: 'too_many_attempts' } }
          : { status: 400, body: { ok: false, reason: 'invalid_code', attemptsLeft } };
      }
      return { row };
    }
    if (new Date(row.expires_at).getTime() <= now().getTime()) {
      return { status: 410, body: { ok: false, reason: 'code_expired' } };
    }
    return { row };
  };

  router.post('/auth/password-reset/verify', verifyLimiter, async (req, res) => {
    try {
      const result = await resolveToken(req.body);
      if (!result.row) return res.status(result.status).json(result.body);
      return res.json({ ok: true });
    } catch {
      log.error?.('[API] /auth/password-reset/verify failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  router.post('/auth/password-reset/confirm', verifyLimiter, async (req, res) => {
    const password = req.body?.password;
    if (!isStrongPassword(password)) {
      return res.status(400).json({ ok: false, reason: 'weak_password' });
    }
    try {
      const result = await resolveToken(req.body);
      if (!result.row) return res.status(result.status).json(result.body);
      const usedAt = now();
      // 한 번만 쓸 수 있게 먼저 사용 처리하고, 성공한 요청만 비밀번호를 바꾼다.
      const claimed = await queryFn(
        'UPDATE password_reset_tokens SET used_at = ? WHERE id = ? AND used_at IS NULL',
        [usedAt, result.row.id],
      );
      if (Number(claimed?.rows?.affectedRows ?? 0) !== 1) {
        return res.status(400).json({ ok: false, reason: 'invalid_code' });
      }
      const salt = await bcrypt.genSalt(10);
      const passwordHash = await bcrypt.hash(password, salt);
      await queryFn(
        'UPDATE Users SET PasswordHash = ?, PasswordSalt = ? WHERE UserId = ?',
        [passwordHash, salt, result.row.user_id],
      );
      await queryFn(
        'UPDATE password_reset_tokens SET used_at = ? WHERE user_id = ? AND used_at IS NULL',
        [usedAt, result.row.user_id],
      );
      return res.json({ ok: true });
    } catch {
      log.error?.('[API] /auth/password-reset/confirm failed');
      return res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  });

  return router;
}
