/**
 * REST API Routes for Phase 3 Archiving Features
 * Endpoints: /api/auth, /api/user, /api/setlog, /api/map, /api/qa, /api/challenges, /api/jukebox
 */

import express from 'express';
import multer from 'multer';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { query, transaction } from './db.js';
import { config } from './config.js';
import { providerState, searchPlaces } from './place-search.js';
import { canEditMapPin, normalizeMapEditorUserId } from './map-ownership.js';
import { partnerIdForCouple } from './couple-separation.js';
import {
  disabledFeature,
  mvpRestFeatureGate,
  requireAuth,
} from './backend-access.js';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const archiver = require('archiver');
import path from 'path';
import fs from 'fs';

const router = express.Router();
const googleClient = new OAuth2Client();

let setlogReadyPromise;
const ensureSetlogTable = () => {
  setlogReadyPromise ??= (async () => {
    await query(`
    CREATE TABLE IF NOT EXISTS setlog_posts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NULL,
      user_id INT NOT NULL,
      map_pin_id INT NULL,
      user_code VARCHAR(32) NULL,
      media_type ENUM('text', 'image', 'video') NOT NULL DEFAULT 'text',
      media_url TEXT NULL,
      caption TEXT NULL,
      tags JSON NULL,
      taken_at DATE NOT NULL,
      captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_setlog_couple_taken (couple_id, taken_at),
      INDEX idx_setlog_user_taken (user_id, taken_at),
      INDEX idx_setlog_map_pin (map_pin_id)
    )
  `);
    await query(`ALTER TABLE setlog_posts ADD COLUMN IF NOT EXISTS map_pin_id INT NULL`);
    await query(`ALTER TABLE setlog_posts ADD INDEX IF NOT EXISTS idx_setlog_map_pin (map_pin_id)`);
  })();

  return setlogReadyPromise;
};

// 누락된 테이블 자동 생성
let _tablesReady = false;
const ensureTables = async () => {
  if (_tablesReady) return;
  await ensureUserColumns();
  await query(`CREATE TABLE IF NOT EXISTS map_pins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    place_name VARCHAR(200) NOT NULL,
    latitude DECIMAL(10,8) NOT NULL DEFAULT 0,
    longitude DECIMAL(11,8) NOT NULL DEFAULT 0,
    category VARCHAR(50) NULL,
    rating SMALLINT NULL,
    visit_date DATE NULL,
    memo TEXT NULL,
    created_by VARCHAR(50) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS daily_questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    question TEXT NOT NULL,
    scheduled_date DATE NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS question_answers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    question_id INT NOT NULL,
    user_id INT NOT NULL,
    answer TEXT NOT NULL,
    UserName VARCHAR(100) NULL,
    answered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_qa_question (question_id)
  )`);
  await query(`CREATE TABLE IF NOT EXISTS challenges (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    target_value DECIMAL(10,2) NOT NULL DEFAULT 1,
    current_value DECIMAL(10,2) NOT NULL DEFAULT 0,
    unit VARCHAR(20) NULL,
    owner_id INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    start_date DATE NOT NULL,
    target_date DATE NULL,
    completed_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS challenge_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    challenge_id INT NOT NULL,
    value DECIMAL(10,2) NOT NULL,
    note TEXT NULL,
    logged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_cl_challenge (challenge_id)
  )`);
  await query(`CREATE TABLE IF NOT EXISTS jukebox_tracks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    artist VARCHAR(200) NULL,
    file_url TEXT NOT NULL,
    duration_sec INT NULL,
    uploaded_by VARCHAR(50) NOT NULL,
    uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS time_capsules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    message TEXT NULL,
    media_url VARCHAR(500) NULL,
    created_by VARCHAR(100) NOT NULL,
    open_date DATE NOT NULL,
    is_opened TINYINT(1) NOT NULL DEFAULT 0,
    opened_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS album_folders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    couple_id INT NULL,
    title VARCHAR(200) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  )`);
  await query(`CREATE TABLE IF NOT EXISTS album_photos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    folder_id INT NOT NULL,
    user_id INT NOT NULL,
    user_code VARCHAR(32) NOT NULL,
    photo_url TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_album_photos_folder (folder_id)
  )`);
  await query(`CREATE TABLE IF NOT EXISTS private_reflections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_reflections_user (user_id)
  )`);
  await query(`CREATE TABLE IF NOT EXISTS premium_subscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    plan VARCHAR(20) NOT NULL DEFAULT 'monthly',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    amount_krw INT NULL,
    started_at DATETIME NULL,
    expires_at DATETIME NULL,
    payment_key VARCHAR(200) NULL,
    payment_method VARCHAR(50) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_premium_sub_user (user_id)
  )`);

  // album_folders 누락 컬럼 추가 (기존 테이블 대응)
  await query(`ALTER TABLE album_folders ADD COLUMN IF NOT EXISTS description TEXT NULL`);
  await query(`ALTER TABLE album_folders ADD COLUMN IF NOT EXISTS cover_url TEXT NULL`);
  await query(`ALTER TABLE album_folders ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0`);

  // album_photos 누락 컬럼 추가
  await query(`ALTER TABLE album_photos ADD COLUMN IF NOT EXISTS caption TEXT NULL`);
  await query(`ALTER TABLE album_photos ADD COLUMN IF NOT EXISTS is_premium_quality TINYINT(1) NOT NULL DEFAULT 0`);
  await query(`ALTER TABLE album_photos ADD COLUMN IF NOT EXISTS file_size_kb INT NULL`);

  // private_reflections 누락 컬럼 추가
  await query(`ALTER TABLE private_reflections ADD COLUMN IF NOT EXISTS mood_tag VARCHAR(50) NULL`);
  await query(`ALTER TABLE private_reflections ADD COLUMN IF NOT EXISTS category VARCHAR(50) NOT NULL DEFAULT 'general'`);

  // map_pins couple/user 스코핑 컬럼 추가
  await query(`ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS couple_id INT NULL`);
  await query(`ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS user_id INT NULL`);
  await query(`ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS status VARCHAR(20) NULL`);
  await query(`ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS emotion_tags JSON NULL`);

  _tablesReady = true;
};

const parseJsonArray = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string') return [];

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return value
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);
  }
};

let retentionTablesReadyPromise;
const ensureRetentionTables = async () => {
  if (retentionTablesReadyPromise) return retentionTablesReadyPromise;

  retentionTablesReadyPromise = (async () => {
    await query(`CREATE TABLE IF NOT EXISTS daily_engagement_days (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NOT NULL,
      date DATE NOT NULL,
      question_id INT NULL,
      mission_id INT NULL,
      streak_count_after INT NOT NULL DEFAULT 0,
      completed_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_daily_engagement_day (couple_id, date)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS daily_engagement_actions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NULL,
      user_id INT NOT NULL,
      date DATE NOT NULL,
      action_type VARCHAR(50) NOT NULL,
      target_id INT NULL,
      payload_json JSON NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_daily_actions_couple_date (couple_id, date),
      INDEX idx_daily_actions_user_date (user_id, date)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS daily_missions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      title VARCHAR(200) NOT NULL,
      description TEXT NULL,
      mission_type VARCHAR(50) NOT NULL DEFAULT 'confirm',
      requirement_type VARCHAR(50) NOT NULL DEFAULT 'both_confirm',
      active TINYINT(1) NOT NULL DEFAULT 1,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_daily_mission_title (title)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS couple_mission_instances (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NOT NULL,
      mission_id INT NOT NULL,
      date DATE NOT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'active',
      completed_by_user1 TINYINT(1) NOT NULL DEFAULT 0,
      completed_by_user2 TINYINT(1) NOT NULL DEFAULT 0,
      completed_at DATETIME NULL,
      payload_json JSON NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_couple_mission_date (couple_id, date)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS couple_streaks (
      couple_id INT PRIMARY KEY,
      current_count INT NOT NULL DEFAULT 0,
      longest_count INT NOT NULL DEFAULT 0,
      last_completed_date DATE NULL,
      last_grace_used_date DATE NULL,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )`);

    await query(`CREATE TABLE IF NOT EXISTS couple_timeline_events (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NOT NULL,
      event_type VARCHAR(50) NOT NULL,
      actor_user_id INT NULL,
      target_user_id INT NULL,
      title VARCHAR(200) NOT NULL,
      body TEXT NULL,
      payload_json JSON NULL,
      event_date DATE NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_timeline_couple_date (couple_id, event_date, id)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS notification_tokens (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      platform VARCHAR(32) NOT NULL,
      token TEXT NOT NULL,
      token_hash VARCHAR(128) NOT NULL,
      device_label VARCHAR(100) NULL,
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_notification_token_hash (token_hash),
      INDEX idx_notification_user (user_id)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS notification_events (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      couple_id INT NULL,
      event_type VARCHAR(50) NOT NULL,
      title VARCHAR(200) NOT NULL,
      body TEXT NULL,
      payload_json JSON NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'queued',
      sent_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_notification_events_user (user_id, created_at)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS wish_tickets (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NOT NULL,
      owner_user_id INT NOT NULL,
      issuer_user_id INT NULL,
      source_type VARCHAR(50) NULL,
      source_id INT NULL,
      title VARCHAR(200) NOT NULL,
      description TEXT NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'available',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      used_at DATETIME NULL,
      expires_at DATETIME NULL,
      INDEX idx_wish_tickets_couple_status (couple_id, status),
      INDEX idx_wish_tickets_owner (owner_user_id, status)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS balance_questions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      option_a VARCHAR(120) NOT NULL,
      option_b VARCHAR(120) NOT NULL,
      active TINYINT(1) NOT NULL DEFAULT 1,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_balance_options (option_a, option_b)
    )`);

    await query(`CREATE TABLE IF NOT EXISTS couple_balance_answers (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NOT NULL,
      user_id INT NOT NULL,
      question_id INT NOT NULL,
      date DATE NOT NULL,
      choice CHAR(1) NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_balance_answer (couple_id, user_id, date)
    )`);
  })();

  return retentionTablesReadyPromise;
};

let userColumnsReadyPromise;
const ensureUserColumns = async () => {
  if (userColumnsReadyPromise) return userColumnsReadyPromise;

  userColumnsReadyPromise = (async () => {
    const result = await query(
      `SELECT COLUMN_NAME, IS_NULLABLE
       FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE()
         AND TABLE_NAME = 'Users'
         AND COLUMN_NAME IN (
           'AuthProvider', 'GoogleSubject', 'GooglePictureUrl',
           'FullName', 'Nickname', 'BirthDate',
           'PasswordHash', 'PasswordSalt'
         )`
    );
    const existing = new Set(result.rows.map((row) => row.COLUMN_NAME));
    const nullableByColumn = new Map(result.rows.map((row) => [row.COLUMN_NAME, row.IS_NULLABLE]));

    if (!existing.has('AuthProvider')) {
      await query("ALTER TABLE Users ADD COLUMN AuthProvider VARCHAR(32) NULL DEFAULT 'password'");
    }
    if (!existing.has('GoogleSubject')) {
      await query('ALTER TABLE Users ADD COLUMN GoogleSubject VARCHAR(255) NULL');
      await query('CREATE UNIQUE INDEX idx_users_google_subject ON Users (GoogleSubject)');
    }
    if (!existing.has('GooglePictureUrl')) {
      await query('ALTER TABLE Users ADD COLUMN GooglePictureUrl TEXT NULL');
    }
    if (!existing.has('FullName')) {
      await query('ALTER TABLE Users ADD COLUMN FullName VARCHAR(100) NULL');
      await query("UPDATE Users SET FullName = COALESCE(NULLIF(TRIM(UserName), ''), SUBSTRING_INDEX(Email, '@', 1), '사용자') WHERE FullName IS NULL OR TRIM(FullName) = ''");
      await query("ALTER TABLE Users MODIFY COLUMN FullName VARCHAR(100) NOT NULL");
    }
    if (!existing.has('Nickname')) {
      await query('ALTER TABLE Users ADD COLUMN Nickname VARCHAR(50) NULL');
      await query("UPDATE Users SET Nickname = COALESCE(NULLIF(TRIM(UserName), ''), NULLIF(TRIM(FullName), ''), SUBSTRING_INDEX(Email, '@', 1), '사용자') WHERE Nickname IS NULL OR TRIM(Nickname) = ''");
      await query("ALTER TABLE Users MODIFY COLUMN Nickname VARCHAR(50) NOT NULL");
    }
    if (!existing.has('BirthDate')) {
      await query('ALTER TABLE Users ADD COLUMN BirthDate DATE NULL');
      await query("UPDATE Users SET BirthDate = '2000-01-01' WHERE BirthDate IS NULL");
      await query("ALTER TABLE Users MODIFY COLUMN BirthDate DATE NOT NULL");
    }
    if (existing.has('PasswordHash') && nullableByColumn.get('PasswordHash') === 'NO') {
      await query('ALTER TABLE Users MODIFY COLUMN PasswordHash VARCHAR(255) NULL');
    }
    if (existing.has('PasswordSalt') && nullableByColumn.get('PasswordSalt') === 'NO') {
      await query('ALTER TABLE Users MODIFY COLUMN PasswordSalt VARCHAR(255) NULL');
    }

    // 프리미엄 컬럼
    await query(`ALTER TABLE Users ADD COLUMN IF NOT EXISTS is_premium TINYINT(1) NOT NULL DEFAULT 0`);
    await query(`ALTER TABLE Users ADD COLUMN IF NOT EXISTS premium_since DATETIME NULL`);
    await query(`ALTER TABLE Users ADD COLUMN IF NOT EXISTS premium_expires_at DATETIME NULL`);
  })();

  return userColumnsReadyPromise;
};

const ensureGoogleAuthColumns = ensureUserColumns;

const createJwtForUser = (user) =>
  jwt.sign(
    { userId: user.UserId, userCode: user.UserCode },
    config.JWT_SECRET,
    { expiresIn: '7d' }
  );

const getAuthenticatedUserId = (req) => req.auth?.userId ?? null;

const dateOnly = (value) => {
  if (!value) return null;
  if (value instanceof Date) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, '0');
    const day = String(value.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  return String(value).split('T')[0];
};

const normalizeAuthUser = (user) => ({
  id: user.UserId,
  UserId: user.UserId,
  userName: user.UserName,
  UserName: user.UserName,
  fullName: user.FullName,
  FullName: user.FullName,
  nickname: user.Nickname,
  Nickname: user.Nickname,
  birthDate: dateOnly(user.BirthDate),
  BirthDate: dateOnly(user.BirthDate),
  userCode: user.UserCode,
  UserCode: user.UserCode,
  PartnerCode: user.PartnerCode ?? null,
  UserIcon: user.UserIcon ?? null,
  RoomCode: user.RoomCode ?? null,
  RoomSecret: user.RoomSecret ?? null,
  CoupleStatus: user.CoupleStatus ?? null,
  ReunionNoticePending: Boolean(user.ReunionNoticePending),
  AuthProvider: user.AuthProvider ?? null,
  GoogleLinked: Boolean(user.GoogleSubject),
  GooglePictureUrl: user.GooglePictureUrl ?? null,
});

const getProfileRowByUserId = async (userId) => {
  await ensureUserColumns();
  const result = await query(
    `SELECT u.UserId, u.Email, u.UserName, u.FullName, u.Nickname, u.BirthDate, u.UserCode,
            u.AuthProvider, u.GoogleSubject, u.GooglePictureUrl,
            p.UserIcon, p.PartnerCode,
            c.RoomCode, c.RoomSecret, c.Status AS CoupleStatus,
            CASE
              WHEN c.ReunionCount > 0 AND c.User1Id = u.UserId AND c.ReunionNoticeUser1SeenAt IS NULL THEN 1
              WHEN c.ReunionCount > 0 AND c.User2Id = u.UserId AND c.ReunionNoticeUser2SeenAt IS NULL THEN 1
              ELSE 0
            END AS ReunionNoticePending
     FROM Users u
     JOIN User_Preference p ON u.UserId = p.UserId
     LEFT JOIN Couples c ON (u.UserId = c.User1Id OR u.UserId = c.User2Id) AND c.Status = 'active'
     WHERE u.UserId = ?`,
    [userId]
  );
  return result.rows[0] ?? null;
};

const getCoupleIdForUser = async (userId) => {
  const result = await query(
    `SELECT CoupleId FROM Couples
     WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?) LIMIT 1`,
    [userId, userId],
  );

  return result.rows[0]?.CoupleId ?? null;
};

// ============================================
// 0. Auth & User Profile API
// ============================================

// 회원가입
router.post('/auth/register', async (req, res) => {
  try {
    const { email, password, user_name, full_name, nickname, birth_date } = req.body;
    const fullName = String(full_name || user_name || '').trim();
    const nicknameValue = String(nickname || user_name || fullName || '').trim();
    const birthDate = String(birth_date || '').trim();

    if (!email || !password || !fullName || !nicknameValue || !birthDate) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_date' });
    }

    await ensureUserColumns();

    // 중복 확인
    const existing = await query('SELECT UserId FROM Users WHERE Email = ?', [email]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ ok: false, reason: 'email_already_exists' });
    }

    // 비밀번호 해싱
    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(password, salt);

    // 고유 UserCode 생성 (6자리 대문자+숫자)
    let userCode;
    while (true) {
      userCode = Math.random().toString(36).substring(2, 8).toUpperCase();
      const codeCheck = await query('SELECT UserId FROM Users WHERE UserCode = ?', [userCode]);
      if (codeCheck.rows.length === 0) break;
    }

    await transaction(async (connection) => {
      // 사용자 생성
      const [userResult] = await connection.execute(
        `INSERT INTO Users
         (Email, PasswordHash, PasswordSalt, UserName, FullName, Nickname, BirthDate, UserCode, CreatedBy)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [email, hash, salt, nicknameValue, fullName, nicknameValue, birthDate, userCode, 'system']
      );

      const userId = userResult.insertId;

      // 기본 환경설정 생성
      await connection.execute(
        'INSERT INTO User_Preference (UserId) VALUES (?)',
        [userId]
      );
    });

    res.json({ ok: true, userCode });
  } catch (err) {
    console.error('[API] /auth/register error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 로그인
router.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await query('SELECT * FROM Users WHERE Email = ?', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ ok: false, reason: 'invalid_credentials' });
    }

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(password, user.PasswordHash);

    if (!isMatch) {
      return res.status(401).json({ ok: false, reason: 'invalid_credentials' });
    }

    const token = createJwtForUser(user);
    const profile = await getProfileRowByUserId(user.UserId);

    res.json({ 
      ok: true, 
      token, 
      user: normalizeAuthUser(profile ?? user),
    });
  } catch (err) {
    console.error('[API] /auth/login error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post(
  '/auth/review-login',
  disabledFeature(config.PUBLIC_FEATURE_SET, 'review_login'),
  async (req, res) => {
  try {
    if (!config.KAKAO_REVIEW_AUTO_LOGIN || !config.KAKAO_REVIEW_EMAIL) {
      return res.status(404).json({ ok: false, reason: 'not_found' });
    }

    await ensureUserColumns();

    const result = await query('SELECT * FROM Users WHERE Email = ?', [
      config.KAKAO_REVIEW_EMAIL,
    ]);
    if (result.rows.length === 0) {
      return res.status(503).json({ ok: false, reason: 'review_account_not_ready' });
    }

    const user = result.rows[0];
    const token = createJwtForUser(user);
    const profile = await getProfileRowByUserId(user.UserId);

    res.json({
      ok: true,
      token,
      user: normalizeAuthUser(profile ?? user),
    });
  } catch (err) {
    console.error('[API] /auth/review-login error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
  },
);

router.post(
  '/auth/google',
  disabledFeature(config.PUBLIC_FEATURE_SET, 'google_login'),
  async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ ok: false, reason: 'missing_id_token' });
    }
    if (!config.GOOGLE_CLIENT_ID) {
      return res.status(503).json({ ok: false, reason: 'google_login_not_configured' });
    }

    await ensureUserColumns();

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: config.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const googleSubject = payload?.sub;
    const email = payload?.email;
    const emailVerified = payload?.email_verified;
    const name = payload?.name || payload?.given_name || 'Google 사용자';
    const nickname = payload?.given_name || payload?.name || email.split('@')[0] || '사용자';
    const picture = payload?.picture || null;

    if (!googleSubject || !email || !emailVerified) {
      return res.status(401).json({ ok: false, reason: 'invalid_google_token' });
    }

    let userId;
    let existing = await query(
      'SELECT UserId FROM Users WHERE GoogleSubject = ? OR Email = ? LIMIT 1',
      [googleSubject, email]
    );

    if (existing.rows.length > 0) {
      userId = existing.rows[0].UserId;
      await query(
        `UPDATE Users
         SET GoogleSubject = COALESCE(GoogleSubject, ?),
             GooglePictureUrl = ?,
             AuthProvider = CASE
               WHEN AuthProvider IS NULL OR AuthProvider = 'password' THEN AuthProvider
               ELSE 'google'
             END
         WHERE UserId = ?`,
        [googleSubject, picture, userId]
      );
    } else {
      await transaction(async (connection) => {
        let userCode;
        while (true) {
          userCode = Math.random().toString(36).substring(2, 8).toUpperCase();
          const [codeRows] = await connection.execute(
            'SELECT UserId FROM Users WHERE UserCode = ?',
            [userCode]
          );
          if (codeRows.length === 0) break;
        }

        const [userResult] = await connection.execute(
          `INSERT INTO Users
           (Email, PasswordHash, PasswordSalt, UserName, FullName, Nickname, BirthDate, UserCode, CreatedBy,
            AuthProvider, GoogleSubject, GooglePictureUrl)
           VALUES (?, NULL, NULL, ?, ?, ?, '2000-01-01', ?, 'google', 'google', ?, ?)`,
          [email, nickname, name, nickname, userCode, googleSubject, picture]
        );
        userId = userResult.insertId;

        await connection.execute(
          'INSERT INTO User_Preference (UserId) VALUES (?)',
          [userId]
        );
      });
    }

    const profile = await getProfileRowByUserId(userId);
    const token = createJwtForUser(profile);

    res.json({
      ok: true,
      token,
      user: normalizeAuthUser(profile),
    });
  } catch (err) {
    console.error('[API] /auth/google error:', err);
    res.status(401).json({ ok: false, reason: 'google_auth_failed' });
  }
  },
);

router.use(requireAuth(config.JWT_SECRET));
router.use(mvpRestFeatureGate(config.PUBLIC_FEATURE_SET));

const expirePairingRequests = () =>
  query(
    `UPDATE PairingRequests
     SET Status = 'expired', RespondedAt = CURRENT_TIMESTAMP
     WHERE Status = 'pending' AND ExpiresAt <= CURRENT_TIMESTAMP`,
  );

router.get('/pairing/requests', async (req, res) => {
  try {
    await expirePairingRequests();
    const userId = req.auth.userId;
    const result = await query(
      `SELECT pr.PairingRequestId AS id, pr.SenderUserId AS senderUserId,
              pr.RecipientUserId AS recipientUserId, pr.Status AS status,
              pr.ExpiresAt AS expiresAt, pr.created_at AS createdAt,
              sender.UserCode AS senderCode, sender.Nickname AS senderNickname,
              recipient.UserCode AS recipientCode, recipient.Nickname AS recipientNickname
       FROM PairingRequests pr
       JOIN Users sender ON sender.UserId = pr.SenderUserId
       JOIN Users recipient ON recipient.UserId = pr.RecipientUserId
       WHERE pr.SenderUserId = ? OR pr.RecipientUserId = ?
       ORDER BY pr.created_at DESC`,
      [userId, userId],
    );
    res.json({
      ok: true,
      sent: result.rows.filter((item) => Number(item.senderUserId) === userId),
      received: result.rows.filter((item) => Number(item.recipientUserId) === userId),
    });
  } catch (error) {
    console.error('[API] pairing list error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/pairing/requests', async (req, res) => {
  try {
    await expirePairingRequests();
    const senderUserId = req.auth.userId;
    const recipientCode = String(req.body.recipientCode ?? '').trim().toUpperCase();
    if (!recipientCode) return res.status(400).json({ ok: false, reason: 'missing_recipient_code' });

    const recipientResult = await query(
      'SELECT UserId, UserCode, Nickname FROM Users WHERE UserCode = ? LIMIT 1',
      [recipientCode],
    );
    const recipient = recipientResult.rows[0];
    if (!recipient) return res.status(404).json({ ok: false, reason: 'recipient_not_found' });
    if (Number(recipient.UserId) === senderUserId) {
      return res.status(400).json({ ok: false, reason: 'cannot_pair_with_self' });
    }

    const active = await query(
      `SELECT CoupleId FROM Couples
       WHERE Status = 'active'
         AND (User1Id IN (?, ?) OR User2Id IN (?, ?))
       LIMIT 1`,
      [senderUserId, recipient.UserId, senderUserId, recipient.UserId],
    );
    if (active.rows.length > 0) {
      return res.status(409).json({ ok: false, reason: 'active_couple_exists' });
    }

    const pending = await query(
      `SELECT PairingRequestId FROM PairingRequests
       WHERE Status = 'pending'
         AND ((SenderUserId = ? AND RecipientUserId = ?)
           OR (SenderUserId = ? AND RecipientUserId = ?))
       LIMIT 1`,
      [senderUserId, recipient.UserId, recipient.UserId, senderUserId],
    );
    if (pending.rows.length > 0) {
      return res.status(409).json({ ok: false, reason: 'request_already_pending' });
    }

    const result = await query(
      `INSERT INTO PairingRequests (SenderUserId, RecipientUserId, ExpiresAt)
       VALUES (?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 7 DAY))`,
      [senderUserId, recipient.UserId],
    );
    res.status(201).json({ ok: true, requestId: result.rows.insertId });
  } catch (error) {
    console.error('[API] pairing create error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const updatePairingRequest = async (req, res, action) => {
  try {
    await expirePairingRequests();
    const userId = req.auth.userId;
    const requestId = Number(req.params.id);
    const ownerColumn = action === 'cancelled' ? 'SenderUserId' : 'RecipientUserId';
    const result = await query(
      `UPDATE PairingRequests
       SET Status = ?, RespondedAt = CURRENT_TIMESTAMP
       WHERE PairingRequestId = ? AND ${ownerColumn} = ? AND Status = 'pending'`,
      [action, requestId, userId],
    );
    if (result.rows.affectedRows === 0) {
      return res.status(404).json({ ok: false, reason: 'pending_request_not_found' });
    }
    res.json({ ok: true });
  } catch (error) {
    console.error(`[API] pairing ${action} error:`, error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
};

router.post('/pairing/requests/:id/reject', (req, res) =>
  updatePairingRequest(req, res, 'rejected'));
router.post('/pairing/requests/:id/cancel', (req, res) =>
  updatePairingRequest(req, res, 'cancelled'));

router.post('/pairing/requests/:id/accept', async (req, res) => {
  try {
    const recipientUserId = req.auth.userId;
    const requestId = Number(req.params.id);
    const activated = await transaction(async (connection) => {
      await connection.execute(
        'SELECT UserId FROM Users WHERE UserId = ? FOR UPDATE',
        [recipientUserId],
      );
      const [requestRows] = await connection.execute(
        `SELECT PairingRequestId, SenderUserId, RecipientUserId, Status, ExpiresAt
         FROM PairingRequests WHERE PairingRequestId = ? FOR UPDATE`,
        [requestId],
      );
      const request = requestRows[0];
      if (!request || Number(request.RecipientUserId) !== recipientUserId || request.Status !== 'pending') {
        return { error: 'pending_request_not_found', status: 404 };
      }
      if (new Date(request.ExpiresAt).getTime() <= Date.now()) {
        await connection.execute(
          `UPDATE PairingRequests SET Status = 'expired', RespondedAt = CURRENT_TIMESTAMP
           WHERE PairingRequestId = ?`,
          [requestId],
        );
        return { error: 'request_expired', status: 410 };
      }

      const senderUserId = Number(request.SenderUserId);
      const userIds = [senderUserId, recipientUserId].sort((a, b) => a - b);
      await connection.execute(
        'SELECT UserId FROM Users WHERE UserId = ? FOR UPDATE',
        [senderUserId],
      );
      const [couples] = await connection.execute(
        `SELECT CoupleId FROM Couples
         WHERE Status = 'active'
           AND (User1Id IN (?, ?) OR User2Id IN (?, ?))
         FOR UPDATE`,
        [userIds[0], userIds[1], userIds[0], userIds[1]],
      );
      if (couples.length > 0) return { error: 'active_couple_exists', status: 409 };

      const [users] = await connection.execute(
        'SELECT UserId, UserCode FROM Users WHERE UserId IN (?, ?)',
        userIds,
      );
      const codeById = new Map(users.map((user) => [Number(user.UserId), user.UserCode]));
      const pairKey = `${userIds[0]}:${userIds[1]}`;
      const roomCode = `room_${userIds[0]}_${userIds[1]}`;
      const roomSecret = Math.random().toString(36).slice(2, 14);
      const [existingRows] = await connection.execute(
        'SELECT CoupleId, Status FROM Couples WHERE PairKey = ? FOR UPDATE',
        [pairKey],
      );
      const existingCouple = existingRows[0];
      let coupleId;
      let reunited = false;
      if (existingCouple) {
        coupleId = existingCouple.CoupleId;
        reunited = existingCouple.Status === 'inactive';
        await connection.execute(
          `UPDATE Couples
           SET Status = 'active', ActivatedAt = CURRENT_TIMESTAMP, DeactivatedAt = NULL,
               ReunionCount = ReunionCount + 1, RoomSecret = ?,
               ReunionNoticeUser1SeenAt = NULL, ReunionNoticeUser2SeenAt = NULL
           WHERE CoupleId = ?`,
          [roomSecret, coupleId],
        );
      } else {
        const [coupleResult] = await connection.execute(
          `INSERT INTO Couples
           (User1Id, User2Id, PairKey, RoomCode, RoomSecret, Status, ActivatedAt)
           VALUES (?, ?, ?, ?, ?, 'active', CURRENT_TIMESTAMP)`,
          [userIds[0], userIds[1], pairKey, roomCode, roomSecret],
        );
        coupleId = coupleResult.insertId;
      }
      await connection.execute(
        `UPDATE User_Preference SET PartnerCode = CASE UserId
           WHEN ? THEN ? WHEN ? THEN ? END
         WHERE UserId IN (?, ?)`,
        [
          senderUserId,
          codeById.get(recipientUserId),
          recipientUserId,
          codeById.get(senderUserId),
          senderUserId,
          recipientUserId,
        ],
      );
      await connection.execute(
        `UPDATE PairingRequests SET Status = 'accepted', RespondedAt = CURRENT_TIMESTAMP
         WHERE PairingRequestId = ?`,
        [requestId],
      );
      await connection.execute(
        `UPDATE PairingRequests SET Status = 'cancelled', RespondedAt = CURRENT_TIMESTAMP
         WHERE Status = 'pending' AND PairingRequestId <> ?
           AND (SenderUserId IN (?, ?) OR RecipientUserId IN (?, ?))`,
        [requestId, userIds[0], userIds[1], userIds[0], userIds[1]],
      );
      return { coupleId, reunited };
    });

    if (activated.error) {
      return res.status(activated.status).json({ ok: false, reason: activated.error });
    }
    res.json({ ok: true, coupleId: activated.coupleId, reunited: activated.reunited });
  } catch (error) {
    console.error('[API] pairing accept error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/user/profile/:userId', async (req, res) => {
  try {
    await ensureUserColumns();

    const userId = req.auth.userId;
    const fullName = String(req.body.fullName || req.body.FullName || '').trim();
    const nickname = String(req.body.nickname || req.body.Nickname || '').trim();
    const birthDate = String(req.body.birthDate || req.body.BirthDate || '').trim();

    if (!fullName || !nickname || !birthDate) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    if (fullName.length > 100 || nickname.length > 50) {
      return res.status(400).json({ ok: false, reason: 'invalid_length' });
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate)) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_date' });
    }

    const result = await query(
      `UPDATE Users
       SET FullName = ?, Nickname = ?, BirthDate = ?, UserName = ?
       WHERE UserId = ?`,
      [fullName, nickname, birthDate, nickname, userId]
    );

    if (result.rows.affectedRows === 0) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }

    const user = await getProfileRowByUserId(userId);
    res.json({ ok: true, user: normalizeAuthUser(user) });
  } catch (err) {
    console.error('[API] /user/profile PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/user/password/:userId', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    if (String(newPassword).length < 6) {
      return res.status(400).json({ ok: false, reason: 'weak_password' });
    }

    const result = await query(
      'SELECT PasswordHash FROM Users WHERE UserId = ?',
      [userId]
    );
    const user = result.rows[0];
    if (!user) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }
    if (!user.PasswordHash) {
      return res.status(400).json({ ok: false, reason: 'password_login_not_enabled' });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.PasswordHash);
    if (!isMatch) {
      return res.status(401).json({ ok: false, reason: 'invalid_current_password' });
    }

    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(newPassword, salt);
    await query(
      `UPDATE Users
       SET PasswordHash = ?, PasswordSalt = ?
       WHERE UserId = ?`,
      [hash, salt, userId]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /user/password PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 애인 설정 (Partner Pairing - Mutual with Auto-Room)
router.post(
  '/user/partner',
  disabledFeature(config.PUBLIC_FEATURE_SET, 'legacy_pairing'),
  async (req, res) => {
  try {
    const userId = req.auth.userId;
    const { partnerCode } = req.body;

    if (!partnerCode) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    // 1. 파트너 정보 확인
    const partnerRes = await query('SELECT UserId, UserCode FROM Users WHERE UserCode = ?', [partnerCode]);
    if (partnerRes.rows.length === 0) {
      return res.status(404).json({ ok: false, reason: 'partner_not_found' });
    }
    const partner = partnerRes.rows[0];

    // 2. 본인 정보 확인
    const selfRes = await query('SELECT UserCode FROM Users WHERE UserId = ?', [userId]);
    const selfCode = selfRes.rows[0].UserCode;

    if (selfCode === partnerCode) {
      return res.status(400).json({ ok: false, reason: 'cannot_pair_with_self' });
    }

    // 3. 방 정보 생성 (Deterministic RoomCode, Random Secret)
    const userIds = [userId, partner.UserId].sort((a, b) => a - b);
    const roomCode = `room_${userIds[0]}_${userIds[1]}`;
    const roomSecret = Math.random().toString(36).substring(2, 12);

    // 4. 상호 연결 및 커플 정보 저장 (트랜잭션)
    await transaction(async (connection) => {
      // 내 파트너 설정
      await connection.execute(
        'UPDATE User_Preference SET PartnerCode = ? WHERE UserId = ?',
        [partnerCode, userId]
      );
      // 상대방의 파트너를 나로 설정
      await connection.execute(
        'UPDATE User_Preference SET PartnerCode = ? WHERE UserId = ?',
        [selfCode, partner.UserId]
      );
      // 커플/방 정보 저장 (이미 있으면 무시하거나 업데이트)
      await connection.execute(
        'INSERT INTO Couples (User1Id, User2Id, RoomCode, RoomSecret) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE RoomSecret = RoomSecret',
        [userIds[0], userIds[1], roomCode, roomSecret]
      );
    });

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /user/partner error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
  },
);

// 애인 연결 해제
router.delete('/user/partner', async (req, res) => {
  try {
    await ensureUserColumns();
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({ ok: false, reason: 'unauthorized' });
    }

    const coupleRes = await query(
      `SELECT CoupleId, User1Id, User2Id, RoomCode
       FROM Couples
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)
       LIMIT 1`,
      [userId, userId]
    );
    const couple = coupleRes.rows[0] ?? null;
    const partnerId = partnerIdForCouple(couple, userId);

    if (!couple || !partnerId) {
      return res.status(404).json({ ok: false, reason: 'couple_not_found' });
    }

    await transaction(async (connection) => {
      await connection.execute(
        'UPDATE User_Preference SET PartnerCode = NULL WHERE UserId IN (?, ?)',
        [userId, partnerId]
      );
      await connection.execute(
        `UPDATE Couples
         SET Status = 'inactive', DeactivatedAt = CURRENT_TIMESTAMP
         WHERE CoupleId = ?`,
        [couple.CoupleId],
      );
    });

    req.app.locals.io?.to(couple.RoomCode).emit('partner:disconnected', {
      reason: 'partner_disconnected',
    });
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /user/partner DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 프로필 조회 (With Room Info)
router.get('/user/profile/:userId', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const user = await getProfileRowByUserId(userId);

    if (!user) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }

    res.json({ ok: true, user: normalizeAuthUser(user) });
  } catch (err) {
    console.error('[API] /user/profile error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/couple/reunion-notice/seen', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const result = await query(
      `UPDATE Couples
       SET ReunionNoticeUser1SeenAt = CASE WHEN User1Id = ? THEN CURRENT_TIMESTAMP ELSE ReunionNoticeUser1SeenAt END,
           ReunionNoticeUser2SeenAt = CASE WHEN User2Id = ? THEN CURRENT_TIMESTAMP ELSE ReunionNoticeUser2SeenAt END
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?) AND ReunionCount > 0`,
      [userId, userId, userId, userId],
    );
    res.json({ ok: true, updated: result.rows.affectedRows > 0 });
  } catch (error) {
    console.error('[API] reunion notice error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// Multer 설정 (파일 업로드)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, config.UPLOADS_ROOT);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + '.' + file.mimetype.split('/')[1]);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 30 * 1024 * 1024 }, // 30MB
  fileFilter: (req, file, cb) => {
    const ok = file.mimetype.startsWith('image/') ||
                file.mimetype.startsWith('video/') ||
                file.mimetype.startsWith('audio/') ||
                file.mimetype === 'application/octet-stream';
    if (ok) cb(null, true);
    else cb(new Error('Invalid file type'));
  }
});

// ============================================
// 1. Setlog API (OOTD & 데이트 사진)
// ============================================

// 셋로그 목록 조회 (달력 뷰용)
router.get('/setlog', async (req, res) => {
  try {
    await ensureUserColumns();
    await ensureSetlogTable();

    const { month, user_id } = req.query; // YYYY-MM 형식
    let sql = `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
               FROM setlog_posts p
               LEFT JOIN Users u ON p.user_id = u.UserId
               WHERE 1 = 1`;
    let params = [];

    if (month) {
      sql += ` AND DATE_FORMAT(p.taken_at, '%Y-%m') = ?`;
      params.push(month);
    }

    if (user_id) {
      const coupleId = await getCoupleIdForUser(Number(user_id));
      if (coupleId) {
        sql += ` AND p.couple_id = ?`;
        params.push(coupleId);
      } else {
        sql += ` AND p.user_id = ?`;
        params.push(Number(user_id));
      }
    }

    sql += ` ORDER BY p.captured_at DESC, p.id DESC`;

    const result = await query(sql, params);
    res.json({ ok: true, posts: result.rows });
  } catch (err) {
    console.error('[API] /setlog GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const resolveSetlogMapPinId = async (mapPinId, userId, coupleId) => {
  if (!mapPinId) return null;

  const pinId = Number(mapPinId);
  if (!Number.isInteger(pinId) || pinId <= 0) {
    return { error: 'invalid_map_pin' };
  }

  const result = await query(
    'SELECT id, user_id, couple_id FROM map_pins WHERE id = ? LIMIT 1',
    [pinId]
  );
  const pin = result.rows[0];
  if (!pin) return { error: 'map_pin_not_found' };

  const sameCouple = coupleId && Number(pin.couple_id) === Number(coupleId);
  const sameUser = Number(pin.user_id) === Number(userId);
  if (!sameCouple && !sameUser) return { error: 'map_pin_forbidden' };

  return { id: pinId };
};

// 셋로그 생성
router.post('/setlog', upload.single('media'), async (req, res) => {
  try {
    await ensureUserColumns();
    await ensureSetlogTable();

    const {
      user_id,
      user_code,
      caption,
      tags,
      taken_at,
      captured_at,
      media_type,
      map_pin_id,
    } = req.body;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const uploadedMediaType = req.file?.mimetype.startsWith('video/') ? 'video' : 'image';
    const normalizedMediaType = mediaUrl ? uploadedMediaType : (media_type || 'text');

    if (!user_id || !taken_at) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    if (!['text', 'image', 'video'].includes(normalizedMediaType)) {
      return res.status(400).json({ ok: false, reason: 'invalid_media_type' });
    }

    if (normalizedMediaType === 'text' && !caption?.trim()) {
      return res.status(400).json({ ok: false, reason: 'caption_required' });
    }

    const userId = Number(user_id);
    const coupleId = await getCoupleIdForUser(userId);
    const resolvedMapPin = await resolveSetlogMapPinId(map_pin_id, userId, coupleId);
    if (resolvedMapPin?.error) {
      return res.status(400).json({ ok: false, reason: resolvedMapPin.error });
    }
    const tagsArray = parseJsonArray(tags);
    
    const result = await query(
      `INSERT INTO setlog_posts
       (couple_id, user_id, map_pin_id, user_code, media_type, media_url, caption, tags, taken_at, captured_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW()))`,
      [
        coupleId,
        userId,
        resolvedMapPin?.id ?? null,
        user_code || null,
        normalizedMediaType,
        mediaUrl,
        caption || null,
        JSON.stringify(tagsArray),
        taken_at,
        captured_at || null,
      ]
    );

    const created = await query(
      `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
       FROM setlog_posts p
       LEFT JOIN Users u ON p.user_id = u.UserId
       WHERE p.id = ?`,
      [result.rows.insertId]
    );

    res.json({ ok: true, post: created.rows[0] });
  } catch (err) {
    console.error('[API] /setlog POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 셋로그 삭제
router.delete('/setlog/:id', async (req, res) => {
  try {
    await ensureSetlogTable();

    const { id } = req.params;
    await query('DELETE FROM setlog_posts WHERE id = ?', [id]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /setlog DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 2. Map API (데이트 장소 핀)
// ============================================

// 장소 검색 프록시 (Kakao Local 우선, Naver Local 보강)
router.get('/places/search', async (req, res) => {
  try {
    const q = String(req.query.q || '').trim();
    const limitRaw = Number(req.query.limit ?? 10);
    const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(Math.trunc(limitRaw), 1), 15) : 10;
    const latitude = Number(req.query.lat);
    const longitude = Number(req.query.lng);
    const providers = providerState(config);

    if (!q) {
      return res.status(400).json({ ok: false, reason: 'missing_query' });
    }

    if (!providers.kakao.enabled && !providers.naver.enabled) {
      return res.status(503).json({ ok: false, reason: 'place_search_not_configured', providers });
    }

    const result = await searchPlaces({
      query: q,
      latitude: Number.isFinite(latitude) ? latitude : undefined,
      longitude: Number.isFinite(longitude) ? longitude : undefined,
      limit,
      config,
    });

    if (result.places.length === 0 && Object.keys(result.errors || {}).length > 0) {
      return res.status(502).json({ ok: false, reason: 'place_search_failed', providers });
    }

    res.json({ ok: true, ...result });
  } catch (err) {
    console.error('[API] /places/search GET error:', err);
    res.status(502).json({ ok: false, reason: 'place_search_failed' });
  }
});

// 지도 핀 목록 조회 (couple_id 스코핑)
router.get('/map', async (req, res) => {
  try {
    await ensureTables();
    const userId = Number(req.query.user_id);
    if (!userId) {
      return res.status(400).json({ ok: false, reason: 'missing_user_id' });
    }
    const coupleId = await getCoupleIdForUser(userId);
    let result;
    if (coupleId) {
      result = await query(
        'SELECT * FROM map_pins WHERE couple_id = ? ORDER BY visit_date DESC, created_at DESC',
        [coupleId]
      );
    } else {
      result = await query(
        'SELECT * FROM map_pins WHERE user_id = ? ORDER BY visit_date DESC, created_at DESC',
        [userId]
      );
    }
    res.json({ ok: true, pins: result.rows });
  } catch (err) {
    console.error('[API] /map GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 생성 (lat/lng 선택사항, couple_id 자동 설정)
router.post('/map', async (req, res) => {
  try {
    await ensureTables();
    const { place_name, latitude, longitude, category, rating, visit_date, memo, created_by, user_id, status, emotion_tags } = req.body;

    if (!place_name || !created_by) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    // user_id 우선, 없으면 created_by(UserCode)로 조회
    let uid = user_id ? Number(user_id) : null;
    if (!uid && created_by) {
      const userRes = await query('SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1', [created_by]);
      uid = userRes.rows[0]?.UserId ?? null;
    }
    const coupleId = uid ? await getCoupleIdForUser(uid) : null;

    const result = await query(
      `INSERT INTO map_pins (place_name, latitude, longitude, category, rating, visit_date, memo, created_by, user_id, couple_id, status, emotion_tags)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        place_name,
        latitude ?? 0,
        longitude ?? 0,
        category ?? null,
        rating ?? null,
        visit_date ?? null,
        memo ?? null,
        created_by,
        uid,
        coupleId,
        status ?? null,
        emotion_tags ? JSON.stringify(emotion_tags) : null,
      ]
    );

    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /map POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const loadMapPinForEditor = async (pinId, editorUserId) => {
  const result = await query(
    `SELECT p.*, u.UserCode AS editor_user_code
     FROM map_pins p
     LEFT JOIN Users u ON u.UserId = ?
     WHERE p.id = ?
     LIMIT 1`,
    [editorUserId, pinId]
  );

  const pin = result.rows[0] ?? null;
  if (!pin) return { pin: null, allowed: false };

  return {
    pin,
    allowed: canEditMapPin(pin, editorUserId, pin.editor_user_code),
  };
};

const parseMapEmotionTags = (value) => {
  const tags = parseJsonArray(value)
    .map((tag) => `${tag}`.trim())
    .filter(Boolean);
  return tags.length > 0 ? JSON.stringify(tags) : null;
};

// 지도 핀 업데이트 (작성자만 가능)
router.patch('/map/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    const editorUserId = getAuthenticatedUserId(req);
    if (!editorUserId) {
      return res.status(401).json({ ok: false, reason: 'unauthorized' });
    }

    const { pin, allowed } = await loadMapPinForEditor(id, editorUserId);
    if (!pin) {
      return res.status(404).json({ ok: false, reason: 'not_found' });
    }
    if (!allowed) {
      return res.status(403).json({ ok: false, reason: 'forbidden' });
    }

    const allowedFields = {
      rating: req.body.rating ?? null,
      memo: req.body.memo ?? null,
      visit_date: req.body.visit_date ?? null,
      status: req.body.status ?? null,
      emotion_tags: Object.prototype.hasOwnProperty.call(req.body, 'emotion_tags')
        ? parseMapEmotionTags(req.body.emotion_tags)
        : null,
    };

    if (allowedFields.status && !['visited', 'wishlist'].includes(allowedFields.status)) {
      return res.status(400).json({ ok: false, reason: 'invalid_status' });
    }

    const updates = [];
    const params = [];
    for (const [field, value] of Object.entries(allowedFields)) {
      if (!Object.prototype.hasOwnProperty.call(req.body, field)) continue;
      updates.push(`${field} = ?`);
      params.push(value);
    }

    if (updates.length === 0) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    await query(
      `UPDATE map_pins SET ${updates.join(', ')}, updated_at = NOW() WHERE id = ?`,
      [...params, id]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /map PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 삭제 (작성자만 가능)
router.delete('/map/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    const editorUserId = getAuthenticatedUserId(req);
    if (!editorUserId) {
      return res.status(401).json({ ok: false, reason: 'unauthorized' });
    }

    const { pin, allowed } = await loadMapPinForEditor(id, editorUserId);
    if (!pin) {
      return res.status(404).json({ ok: false, reason: 'not_found' });
    }
    if (!allowed) {
      return res.status(403).json({ ok: false, reason: 'forbidden' });
    }

    await query('DELETE FROM map_pins WHERE id = ?', [id]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /map DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 3. Q&A API (10시의 질문)
// ============================================

const QA_POOL = [
  '오늘 하루 중 가장 좋았던 순간은?',
  '요즘 가장 먹고 싶은 음식은?',
  '지금 이 순간 나에게 하고 싶은 말은?',
  '우리 둘이 꼭 가보고 싶은 여행지는?',
  '서로에게 감사한 점 하나씩 말해볼까요?',
  '요즘 나의 최대 관심사는?',
  '우리가 처음 만났을 때 가장 인상 깊었던 건?',
  '지금 가장 듣고 싶은 말은?',
  '다음 데이트에서 뭐 하고 싶어?',
  '우리만의 특별한 말이 있다면?',
  '지금 이 순간 무슨 생각 하고 있어?',
  '내가 제일 행복한 순간은 언제야?',
  '나에 대해 아직 모르는 것 같은 게 있어?',
  '우리가 닮은 점과 다른 점은?',
  '버킷리스트 중 꼭 같이 하고 싶은 건?',
  '오늘 나의 기분을 날씨로 표현한다면?',
  '내가 가장 좋아하는 우리 둘만의 습관은?',
  '지금 제일 하고 싶은 건 뭐야?',
  '우리 커플만의 테마곡이 있다면?',
  '10년 후 우리는 어떤 모습일까?',
  '내가 힘들 때 제일 듣고 싶은 말은?',
  '우리 첫 데이트 기억나?',
  '나를 보면 떠오르는 색이 있다면?',
  '지금 바로 어딘가로 떠난다면 어디로 가고 싶어?',
  '우리가 함께하면서 가장 웃겼던 순간은?',
  '상대방에게 배운 가장 좋은 점은?',
  '같이 살게 된다면 꼭 지키고 싶은 규칙이 있어?',
  '요즘 나를 보면서 어떤 생각이 들어?',
  '오늘 하루 나의 하이라이트는?',
  '우리만의 기념일을 만든다면?',
];

const MISSION_POOL = [
  ['칭찬 하나 남기기', '오늘 상대에게 고마웠던 점이나 예뻤던 점을 하나 말해줘요.'],
  ['사진 한 장 남기기', '오늘 하루를 기억할 사진 한 장을 남겨요.'],
  ['10초 안부 묻기', '바쁘더라도 오늘 기분을 짧게 물어봐요.'],
  ['데이트 후보 하나 고르기', '다음에 같이 가고 싶은 곳을 하나 골라요.'],
  ['게임 한 판 하기', '아케이드에서 짧게 한 판 같이 놀아요.'],
  ['서로 응원 한 마디', '오늘 상대에게 필요한 응원을 남겨요.'],
  ['추억 하나 꺼내기', '기억나는 우리 순간 하나를 이야기해요.'],
];

const BALANCE_POOL = [
  ['즉흥 여행', '계획 여행'],
  ['집 데이트', '밖 데이트'],
  ['달달한 말', '실질적인 도움'],
  ['같이 영화', '같이 산책'],
  ['매운 음식', '달달한 디저트'],
  ['전화 통화', '긴 메시지'],
  ['깜짝 선물', '원하는 선물'],
  ['아침 데이트', '밤 데이트'],
  ['사진 많이 찍기', '눈으로만 담기'],
  ['편한 사랑', '설레는 사랑'],
];

const dateString = (value = new Date()) => value.toISOString().split('T')[0];

const previousDateString = (date) => {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - 1);
  return dateString(value);
};

const getOrCreateTodayQuestion = async () => {
  const today = dateString();
  let result = await query('SELECT * FROM daily_questions WHERE scheduled_date = ?', [today]);

  if (result.rows.length === 0) {
    const now = new Date();
    const dayOfYear = Math.floor((now - new Date(now.getFullYear(), 0, 0)) / 86400000);
    const question = QA_POOL[dayOfYear % QA_POOL.length];
    try {
      await query(
        'INSERT IGNORE INTO daily_questions (question, scheduled_date) VALUES (?, ?)',
        [question, today]
      );
    } catch {}
    result = await query('SELECT * FROM daily_questions WHERE scheduled_date = ?', [today]);
  }

  return result.rows[0] ?? null;
};

const getCoupleMemberIds = async (userId) => {
  const result = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)
     LIMIT 1`,
    [userId, userId]
  );
  return result.rows[0] ?? null;
};

const seedDailyMissions = async () => {
  for (const [title, description] of MISSION_POOL) {
    await query(
      `INSERT IGNORE INTO daily_missions
       (title, description, mission_type, requirement_type)
       VALUES (?, ?, 'confirm', 'both_confirm')`,
      [title, description]
    );
  }
};

const seedBalanceQuestions = async () => {
  for (const [optionA, optionB] of BALANCE_POOL) {
    await query(
      'INSERT IGNORE INTO balance_questions (option_a, option_b) VALUES (?, ?)',
      [optionA, optionB]
    );
  }
};

const getTodayBalanceQuestion = async (coupleId, today) => {
  await seedBalanceQuestions();
  const questions = await query('SELECT * FROM balance_questions WHERE active = 1 ORDER BY id');
  if (questions.rows.length === 0) return null;
  const dayNumber = Math.floor(new Date(`${today}T00:00:00.000Z`).getTime() / 86400000);
  return questions.rows[(dayNumber + Number(coupleId || 0)) % questions.rows.length] ?? null;
};

const getOrCreateTodayMission = async (coupleId, today) => {
  if (!coupleId) return null;
  await seedDailyMissions();

  let instance = await query(
    `SELECT cmi.*, dm.title, dm.description, dm.mission_type, dm.requirement_type
     FROM couple_mission_instances cmi
     JOIN daily_missions dm ON cmi.mission_id = dm.id
     WHERE cmi.couple_id = ? AND cmi.date = ?
     LIMIT 1`,
    [coupleId, today]
  );
  if (instance.rows.length > 0) return instance.rows[0];

  const missions = await query(
    'SELECT * FROM daily_missions WHERE active = 1 ORDER BY id'
  );
  if (missions.rows.length === 0) return null;

  const dayNumber = Math.floor(new Date(`${today}T00:00:00.000Z`).getTime() / 86400000);
  const mission = missions.rows[(dayNumber + Number(coupleId)) % missions.rows.length];
  await query(
    `INSERT INTO couple_mission_instances (couple_id, mission_id, date)
     VALUES (?, ?, ?)`,
    [coupleId, mission.id, today]
  );

  instance = await query(
    `SELECT cmi.*, dm.title, dm.description, dm.mission_type, dm.requirement_type
     FROM couple_mission_instances cmi
     JOIN daily_missions dm ON cmi.mission_id = dm.id
     WHERE cmi.couple_id = ? AND cmi.date = ?
     LIMIT 1`,
    [coupleId, today]
  );
  return instance.rows[0] ?? null;
};

const getActionUsersForDate = async (coupleId, date) => {
  const actionRows = await query(
    `SELECT DISTINCT user_id
     FROM daily_engagement_actions
     WHERE couple_id = ? AND date = ?`,
    [coupleId, date]
  );
  return actionRows.rows.map((row) => Number(row.user_id));
};

const addTimelineEvent = async ({
  coupleId,
  eventType,
  actorUserId = null,
  targetUserId = null,
  title,
  body = null,
  payload = null,
  eventDate = dateString(),
}) => {
  if (!coupleId || !eventType || !title) return;
  await query(
    `INSERT INTO couple_timeline_events
     (couple_id, event_type, actor_user_id, target_user_id, title, body, payload_json, event_date)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      coupleId,
      eventType,
      actorUserId,
      targetUserId,
      title,
      body,
      payload ? JSON.stringify(payload) : null,
      eventDate,
    ]
  );
};

const addNotificationEvent = async ({
  userId,
  coupleId = null,
  eventType,
  title,
  body = null,
  payload = null,
}) => {
  if (!userId || !eventType || !title) return;
  await query(
    `INSERT INTO notification_events
     (user_id, couple_id, event_type, title, body, payload_json)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      userId,
      coupleId,
      eventType,
      title,
      body,
      payload ? JSON.stringify(payload) : null,
    ]
  );
};

const getStreakRow = async (coupleId) => {
  const streak = await query(
    'SELECT * FROM couple_streaks WHERE couple_id = ?',
    [coupleId]
  );
  return streak.rows[0] ?? {
    couple_id: coupleId,
    current_count: 0,
    longest_count: 0,
    last_completed_date: null,
  };
};

const updateStreakForDate = async (couple, date) => {
  if (!couple?.CoupleId) {
    return { current: 0, longest: 0, completedToday: false };
  }

  const coupleId = Number(couple.CoupleId);
  const user1Id = Number(couple.User1Id);
  const user2Id = Number(couple.User2Id);
  const actionUsers = await getActionUsersForDate(coupleId, date);
  const completed = actionUsers.includes(user1Id) && actionUsers.includes(user2Id);
  const existing = await getStreakRow(coupleId);
  const lastCompleted = dateOnly(existing.last_completed_date);

  if (!completed) {
    const yesterday = previousDateString(date);
    const activeCurrent = [date, yesterday].includes(lastCompleted)
      ? Number(existing.current_count) || 0
      : 0;
    return {
      current: activeCurrent,
      longest: Number(existing.longest_count) || 0,
      completedToday: false,
      actionUsers,
    };
  }

  if (lastCompleted === date) {
    return {
      current: Number(existing.current_count) || 1,
      longest: Number(existing.longest_count) || 1,
      completedToday: true,
      actionUsers,
    };
  }

  const yesterday = previousDateString(date);
  const nextCurrent = lastCompleted === yesterday
    ? (Number(existing.current_count) || 0) + 1
    : 1;
  const nextLongest = Math.max(Number(existing.longest_count) || 0, nextCurrent);

  await query(
    `INSERT INTO couple_streaks
     (couple_id, current_count, longest_count, last_completed_date)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       current_count = VALUES(current_count),
       longest_count = VALUES(longest_count),
       last_completed_date = VALUES(last_completed_date)`,
    [coupleId, nextCurrent, nextLongest, date]
  );

  await addTimelineEvent({
    coupleId,
    eventType: 'streak_completed',
    title: `스트릭 ${nextCurrent}일 달성`,
    body: '오늘의 커플 루프를 둘 다 완료했어요.',
    payload: { current: nextCurrent, longest: nextLongest },
    eventDate: date,
  });

  await query(
    `UPDATE daily_engagement_days
     SET streak_count_after = ?, completed_at = COALESCE(completed_at, NOW())
     WHERE couple_id = ? AND date = ?`,
    [nextCurrent, coupleId, date]
  );

  return {
    current: nextCurrent,
    longest: nextLongest,
    completedToday: true,
    actionUsers,
  };
};

router.get('/today', async (req, res) => {
  try {
    await ensureTables();
    await ensureRetentionTables();

    const userId = Number(req.query.user_id);
    if (!userId) {
      return res.status(400).json({ ok: false, reason: 'missing_user_id' });
    }

    const today = dateString();
    const couple = await getCoupleMemberIds(userId);
    const coupleId = couple?.CoupleId ?? await getCoupleIdForUser(userId);
    const partnerId = couple
      ? (Number(couple.User1Id) === userId ? Number(couple.User2Id) : Number(couple.User1Id))
      : null;

    const question = await getOrCreateTodayQuestion();
    const mission = await getOrCreateTodayMission(coupleId, today);
    let answers = [];
    if (question) {
      const answerRows = await query(
        `SELECT qa.id, qa.question_id, qa.user_id, qa.answer, qa.answered_at,
                u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
         FROM question_answers qa
         LEFT JOIN Users u ON qa.user_id = u.UserId
         WHERE qa.question_id = ?`,
        [question.id]
      );
      answers = answerRows.rows;

      if (coupleId) {
        await query(
          `INSERT INTO daily_engagement_days (couple_id, date, question_id, mission_id)
           VALUES (?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE
             question_id = VALUES(question_id),
             mission_id = COALESCE(VALUES(mission_id), mission_id)`,
          [coupleId, today, question.id, mission?.mission_id ?? null]
        );
      }
    }

    const myAnswered = answers.some((answer) => Number(answer.user_id) === userId);
    const partnerAnswered = partnerId
      ? answers.some((answer) => Number(answer.user_id) === partnerId)
      : answers.some((answer) => Number(answer.user_id) !== userId);
    const revealAvailable = myAnswered && partnerAnswered;

    const streakState = couple
      ? await updateStreakForDate(couple, today)
      : { current: 0, longest: 0, completedToday: false, actionUsers: [] };
    const actionUsers = streakState.actionUsers ?? [];
    const isUser1 = couple ? Number(couple.User1Id) === userId : false;
    const myMissionCompleted = mission
      ? (isUser1 ? mission.completed_by_user1 === 1 : mission.completed_by_user2 === 1)
      : false;
    const partnerMissionCompleted = mission
      ? (isUser1 ? mission.completed_by_user2 === 1 : mission.completed_by_user1 === 1)
      : false;
    let wishTicketCount = 0;
    let capsulesToOpen = 0;
    if (coupleId) {
      const wishRows = await query(
        `SELECT COUNT(*) AS count
         FROM wish_tickets
         WHERE owner_user_id = ? AND status = 'available'`,
        [userId]
      );
      wishTicketCount = Number(wishRows.rows[0]?.count) || 0;

      const capsuleRows = await query(
        `SELECT COUNT(*) AS count
         FROM time_capsules
         WHERE is_opened = 0 AND open_date <= ?`,
        [today]
      );
      capsulesToOpen = Number(capsuleRows.rows[0]?.count) || 0;
    }

    res.json({
      ok: true,
      date: today,
      coupleId: coupleId ?? null,
      streak: {
        current: streakState.current,
        longest: streakState.longest,
        completedToday: streakState.completedToday,
        myCompleted: actionUsers.includes(userId) || myAnswered,
        partnerCompleted: partnerId ? actionUsers.includes(partnerId) || partnerAnswered : partnerAnswered,
      },
      question: question
        ? {
            id: question.id,
            text: question.question,
            scheduledDate: dateOnly(question.scheduled_date),
            myAnswered,
            partnerAnswered,
            revealAvailable,
            answerCount: answers.length,
          }
        : null,
      mission: mission
        ? {
            instanceId: mission.id,
            missionId: mission.mission_id,
            title: mission.title,
            description: mission.description,
            status: mission.status,
            myCompleted: myMissionCompleted,
            partnerCompleted: partnerMissionCompleted,
            completed: mission.status === 'completed',
          }
        : null,
      pending: {
        wishTickets: wishTicketCount,
        capsulesToOpen,
      },
    });
  } catch (err) {
    console.error('[API] /today GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/missions/:instanceId/complete', async (req, res) => {
  try {
    await ensureRetentionTables();
    const instanceId = Number(req.params.instanceId);
    const userId = Number(req.body.user_id);
    if (!instanceId || !userId) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const missionResult = await query(
      `SELECT cmi.*, c.User1Id, c.User2Id
       FROM couple_mission_instances cmi
       JOIN Couples c ON cmi.couple_id = c.CoupleId
       WHERE cmi.id = ?
       LIMIT 1`,
      [instanceId]
    );
    const mission = missionResult.rows[0];
    if (!mission) {
      return res.status(404).json({ ok: false, reason: 'mission_not_found' });
    }
    if (![Number(mission.User1Id), Number(mission.User2Id)].includes(userId)) {
      return res.status(403).json({ ok: false, reason: 'forbidden_user' });
    }

    const isUser1 = Number(mission.User1Id) === userId;
    const completedByUser1 = isUser1 ? 1 : Number(mission.completed_by_user1) ? 1 : 0;
    const completedByUser2 = !isUser1 ? 1 : Number(mission.completed_by_user2) ? 1 : 0;
    const completed = completedByUser1 === 1 && completedByUser2 === 1;

    await query(
      `UPDATE couple_mission_instances
       SET completed_by_user1 = ?,
           completed_by_user2 = ?,
           status = ?,
           completed_at = CASE WHEN ? THEN COALESCE(completed_at, NOW()) ELSE completed_at END
       WHERE id = ?`,
      [completedByUser1, completedByUser2, completed ? 'completed' : 'active', completed, instanceId]
    );

    await query(
      `INSERT INTO daily_engagement_actions
       (couple_id, user_id, date, action_type, target_id, payload_json)
       VALUES (?, ?, ?, 'mission_completed', ?, ?)`,
      [
        mission.couple_id,
        userId,
        dateOnly(mission.date),
        instanceId,
        JSON.stringify({ missionId: mission.mission_id }),
      ]
    );

    await addTimelineEvent({
      coupleId: mission.couple_id,
      eventType: 'mission_completed',
      actorUserId: userId,
      title: '오늘의 미션 완료',
      body: '한 사람이 오늘의 미션을 완료했어요.',
      payload: { missionInstanceId: instanceId, missionId: mission.mission_id },
      eventDate: dateOnly(mission.date),
    });

    await updateStreakForDate(
      {
        CoupleId: mission.couple_id,
        User1Id: mission.User1Id,
        User2Id: mission.User2Id,
      },
      dateOnly(mission.date)
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /missions/:instanceId/complete POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 오늘의 질문 조회 (질문 없으면 자동 생성)
router.get('/qa/today', async (req, res) => {
  try {
    await ensureTables();
    const question = await getOrCreateTodayQuestion();

    if (!question) return res.json({ ok: true, question: null, answers: [] });
    const userId = Number(req.query.user_id);
    const answers = await query(
      `SELECT qa.id, qa.question_id, qa.user_id, qa.answer, qa.answered_at,
              u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
       FROM question_answers qa
       LEFT JOIN Users u ON qa.user_id = u.UserId
       WHERE qa.question_id = ?`,
      [question.id]
    );

    if (!userId) {
      return res.json({ ok: true, question, answers: answers.rows });
    }

    const couple = await getCoupleMemberIds(userId);
    const partnerId = couple
      ? (Number(couple.User1Id) === userId ? Number(couple.User2Id) : Number(couple.User1Id))
      : null;
    const myAnswered = answers.rows.some((answer) => Number(answer.user_id) === userId);
    const partnerAnswered = partnerId
      ? answers.rows.some((answer) => Number(answer.user_id) === partnerId)
      : answers.rows.some((answer) => Number(answer.user_id) !== userId);
    const revealAvailable = myAnswered && partnerAnswered;
    const visibleAnswers = revealAvailable
      ? answers.rows
      : answers.rows.filter((answer) => Number(answer.user_id) === userId);

    res.json({
      ok: true,
      question,
      answers: visibleAnswers,
      status: {
        myAnswered,
        partnerAnswered,
        revealAvailable,
      },
    });
  } catch (err) {
    console.error('[API] /qa/today GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 답변 제출
router.post('/qa/answer', async (req, res) => {
  try {
    await ensureRetentionTables();
    const { question_id, user_id, answer } = req.body;

    if (!question_id || !user_id || !answer) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const existing = await query(
      'SELECT id FROM question_answers WHERE question_id = ? AND user_id = ? LIMIT 1',
      [question_id, user_id]
    );
    let answerId;
    if (existing.rows.length > 0) {
      answerId = existing.rows[0].id;
      await query(
        'UPDATE question_answers SET answer = ?, answered_at = NOW() WHERE id = ?',
        [answer, answerId]
      );
    } else {
      const result = await query(
        'INSERT INTO question_answers (question_id, user_id, answer) VALUES (?, ?, ?)',
        [question_id, user_id, answer]
      );
      answerId = result.rows.insertId;
    }

    const userId = Number(user_id);
    const coupleId = await getCoupleIdForUser(userId);
    if (coupleId) {
      const today = dateString();
      await query(
        `INSERT INTO daily_engagement_actions
         (couple_id, user_id, date, action_type, target_id, payload_json)
         VALUES (?, ?, ?, 'question_answered', ?, ?)`,
        [
          coupleId,
          userId,
          today,
          Number(question_id),
          JSON.stringify({ answerId }),
        ]
      );
      await addTimelineEvent({
        coupleId,
        eventType: 'question_answered',
        actorUserId: userId,
        title: '오늘의 질문 답변 완료',
        body: '한 사람이 오늘의 질문에 답했어요.',
        payload: { questionId: Number(question_id), answerId },
        eventDate: today,
      });
      const couple = await getCoupleMemberIds(userId);
      if (couple) {
        await updateStreakForDate(couple, today);
      }
    }

    res.json({ ok: true, id: answerId });
  } catch (err) {
    console.error('[API] /qa/answer POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/timeline', async (req, res) => {
  try {
    await ensureUserColumns();
    await ensureRetentionTables();
    const userId = Number(req.query.user_id);
    const limit = Math.min(Number(req.query.limit) || 30, 100);
    if (!userId) {
      return res.status(400).json({ ok: false, reason: 'missing_user_id' });
    }

    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.json({ ok: true, events: [] });
    }

    const events = await query(
      `SELECT e.*, u.Nickname AS ActorNickname, COALESCE(u.Nickname, u.UserName) AS ActorName
       FROM couple_timeline_events e
       LEFT JOIN Users u ON e.actor_user_id = u.UserId
       WHERE e.couple_id = ?
       ORDER BY e.event_date DESC, e.id DESC
       LIMIT ?`,
      [coupleId, limit]
    );

    res.json({ ok: true, events: events.rows });
  } catch (err) {
    console.error('[API] /timeline GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/push/token', async (req, res) => {
  try {
    await ensureRetentionTables();
    const { user_id, platform, token, device_label } = req.body;
    if (!user_id || !platform || !token) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const tokenHash = Buffer.from(String(token)).toString('base64').slice(0, 128);
    await query(
      `INSERT INTO notification_tokens
       (user_id, platform, token, token_hash, device_label, enabled, last_seen_at)
       VALUES (?, ?, ?, ?, ?, 1, NOW())
       ON DUPLICATE KEY UPDATE
         user_id = VALUES(user_id),
         platform = VALUES(platform),
         token = VALUES(token),
         device_label = VALUES(device_label),
         enabled = 1,
         last_seen_at = NOW()`,
      [Number(user_id), platform, token, tokenHash, device_label ?? null]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /push/token POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.delete('/push/token', async (req, res) => {
  try {
    await ensureRetentionTables();
    const { user_id, token } = req.body;
    if (!user_id || !token) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const tokenHash = Buffer.from(String(token)).toString('base64').slice(0, 128);
    await query(
      'UPDATE notification_tokens SET enabled = 0 WHERE user_id = ? AND token_hash = ?',
      [Number(user_id), tokenHash]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /push/token DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/wish-tickets', async (req, res) => {
  try {
    await ensureUserColumns();
    await ensureRetentionTables();
    const userId = Number(req.query.user_id);
    if (!userId) {
      return res.status(400).json({ ok: false, reason: 'missing_user_id' });
    }
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) return res.json({ ok: true, tickets: [] });

    const tickets = await query(
      `SELECT wt.*, owner.Nickname AS OwnerNickname, issuer.Nickname AS IssuerNickname
       FROM wish_tickets wt
       LEFT JOIN Users owner ON wt.owner_user_id = owner.UserId
       LEFT JOIN Users issuer ON wt.issuer_user_id = issuer.UserId
       WHERE wt.couple_id = ?
       ORDER BY FIELD(wt.status, 'available', 'requested', 'used', 'expired', 'canceled'), wt.id DESC`,
      [coupleId]
    );

    res.json({ ok: true, tickets: tickets.rows });
  } catch (err) {
    console.error('[API] /wish-tickets GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/wish-tickets', async (req, res) => {
  try {
    await ensureRetentionTables();
    const { issuer_user_id, owner_user_id, owner_user_code, title, description, source_type, source_id } = req.body;
    if (!issuer_user_id || (!owner_user_id && !owner_user_code) || !title) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const coupleId = await getCoupleIdForUser(Number(issuer_user_id));
    if (!coupleId) {
      return res.status(400).json({ ok: false, reason: 'couple_not_found' });
    }
    let ownerUserId = Number(owner_user_id);
    if (!ownerUserId && owner_user_code) {
      const ownerRows = await query(
        'SELECT UserId FROM Users WHERE UserCode = ? LIMIT 1',
        [owner_user_code]
      );
      ownerUserId = Number(ownerRows.rows[0]?.UserId);
    }
    if (!ownerUserId) {
      return res.status(404).json({ ok: false, reason: 'owner_not_found' });
    }

    const result = await query(
      `INSERT INTO wish_tickets
       (couple_id, owner_user_id, issuer_user_id, source_type, source_id, title, description)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        coupleId,
        ownerUserId,
        Number(issuer_user_id),
        source_type ?? 'manual',
        source_id ?? null,
        title,
        description ?? null,
      ]
    );

    await addTimelineEvent({
      coupleId,
      eventType: 'wish_ticket_created',
      actorUserId: Number(issuer_user_id),
      targetUserId: ownerUserId,
      title: '소원권 생성',
      body: title,
      payload: { ticketId: result.rows.insertId },
      eventDate: dateString(),
    });
    await addNotificationEvent({
      userId: ownerUserId,
      coupleId,
      eventType: 'wish_ticket_created',
      title: '새 소원권이 생겼어요',
      body: title,
      payload: { ticketId: result.rows.insertId },
    });

    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /wish-tickets POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/wish-tickets/:id/use', async (req, res) => {
  try {
    await ensureRetentionTables();
    const id = Number(req.params.id);
    const userId = Number(req.body.user_id);
    if (!id || !userId) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const ticketRows = await query('SELECT * FROM wish_tickets WHERE id = ? LIMIT 1', [id]);
    const ticket = ticketRows.rows[0];
    if (!ticket) return res.status(404).json({ ok: false, reason: 'ticket_not_found' });
    if (Number(ticket.owner_user_id) !== userId) {
      return res.status(403).json({ ok: false, reason: 'forbidden_user' });
    }

    await query(
      "UPDATE wish_tickets SET status = 'used', used_at = NOW() WHERE id = ?",
      [id]
    );
    await addTimelineEvent({
      coupleId: ticket.couple_id,
      eventType: 'wish_ticket_used',
      actorUserId: userId,
      title: '소원권 사용',
      body: ticket.title,
      payload: { ticketId: id },
      eventDate: dateString(),
    });
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /wish-tickets/:id/use PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/wish-tickets/:id/cancel', async (req, res) => {
  try {
    await ensureRetentionTables();
    const id = Number(req.params.id);
    const userId = Number(req.body.user_id);
    if (!id || !userId) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const ticketRows = await query('SELECT * FROM wish_tickets WHERE id = ? LIMIT 1', [id]);
    const ticket = ticketRows.rows[0];
    if (!ticket) return res.status(404).json({ ok: false, reason: 'ticket_not_found' });
    if (![Number(ticket.owner_user_id), Number(ticket.issuer_user_id)].includes(userId)) {
      return res.status(403).json({ ok: false, reason: 'forbidden_user' });
    }

    await query(
      "UPDATE wish_tickets SET status = 'canceled' WHERE id = ?",
      [id]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /wish-tickets/:id/cancel PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/reports/monthly', async (req, res) => {
  try {
    await ensureRetentionTables();
    const userId = Number(req.query.user_id);
    const month = String(req.query.month || dateString().slice(0, 7));
    if (!userId || !/^\d{4}-\d{2}$/.test(month)) {
      return res.status(400).json({ ok: false, reason: 'invalid_request' });
    }
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) return res.json({ ok: true, report: null });

    const startDate = `${month}-01`;
    const endDate = dateString(new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 1)));
    const actions = await query(
      `SELECT action_type, COUNT(*) AS count
       FROM daily_engagement_actions
       WHERE couple_id = ? AND date >= ? AND date < ?
       GROUP BY action_type`,
      [coupleId, startDate, endDate]
    );
    const days = await query(
      `SELECT COUNT(*) AS count, MAX(streak_count_after) AS maxStreak
       FROM daily_engagement_days
       WHERE couple_id = ? AND date >= ? AND date < ? AND completed_at IS NOT NULL`,
      [coupleId, startDate, endDate]
    );
    const tickets = await query(
      `SELECT status, COUNT(*) AS count
       FROM wish_tickets
       WHERE couple_id = ? AND created_at >= ? AND created_at < ?
       GROUP BY status`,
      [coupleId, startDate, endDate]
    );

    res.json({
      ok: true,
      report: {
        month,
        coupleId,
        completedDays: Number(days.rows[0]?.count) || 0,
        maxStreak: Number(days.rows[0]?.maxStreak) || 0,
        actions: actions.rows,
        wishTickets: tickets.rows,
      },
    });
  } catch (err) {
    console.error('[API] /reports/monthly GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/balance/today', async (req, res) => {
  try {
    await ensureRetentionTables();
    const userId = Number(req.query.user_id);
    if (!userId) {
      return res.status(400).json({ ok: false, reason: 'missing_user_id' });
    }
    const today = dateString();
    const couple = await getCoupleMemberIds(userId);
    if (!couple) {
      return res.status(404).json({ ok: false, reason: 'couple_not_found' });
    }
    const question = await getTodayBalanceQuestion(couple.CoupleId, today);
    if (!question) return res.json({ ok: true, question: null, answers: [] });

    const answers = await query(
      `SELECT cba.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
       FROM couple_balance_answers cba
       LEFT JOIN Users u ON cba.user_id = u.UserId
       WHERE cba.couple_id = ? AND cba.date = ? AND cba.question_id = ?`,
      [couple.CoupleId, today, question.id]
    );
    const partnerId = Number(couple.User1Id) === userId ? Number(couple.User2Id) : Number(couple.User1Id);
    const myAnswered = answers.rows.some((answer) => Number(answer.user_id) === userId);
    const partnerAnswered = answers.rows.some((answer) => Number(answer.user_id) === partnerId);
    const revealAvailable = myAnswered && partnerAnswered;

    res.json({
      ok: true,
      date: today,
      question: {
        id: question.id,
        optionA: question.option_a,
        optionB: question.option_b,
      },
      answers: revealAvailable
        ? answers.rows
        : answers.rows.filter((answer) => Number(answer.user_id) === userId),
      status: {
        myAnswered,
        partnerAnswered,
        revealAvailable,
        matched: revealAvailable
          ? new Set(answers.rows.map((answer) => answer.choice)).size === 1
          : null,
      },
    });
  } catch (err) {
    console.error('[API] /balance/today GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/balance/answer', async (req, res) => {
  try {
    await ensureRetentionTables();
    const userId = Number(req.body.user_id);
    const questionId = Number(req.body.question_id);
    const choice = String(req.body.choice || '').toUpperCase();
    if (!userId || !questionId || !['A', 'B'].includes(choice)) {
      return res.status(400).json({ ok: false, reason: 'invalid_request' });
    }
    const couple = await getCoupleMemberIds(userId);
    if (!couple) {
      return res.status(404).json({ ok: false, reason: 'couple_not_found' });
    }
    const today = dateString();
    await query(
      `INSERT INTO couple_balance_answers
       (couple_id, user_id, question_id, date, choice)
       VALUES (?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE choice = VALUES(choice), question_id = VALUES(question_id)`,
      [couple.CoupleId, userId, questionId, today, choice]
    );
    await query(
      `INSERT INTO daily_engagement_actions
       (couple_id, user_id, date, action_type, target_id, payload_json)
       VALUES (?, ?, ?, 'balance_answered', ?, ?)`,
      [couple.CoupleId, userId, today, questionId, JSON.stringify({ choice })]
    );
    await addTimelineEvent({
      coupleId: couple.CoupleId,
      eventType: 'balance_answered',
      actorUserId: userId,
      title: '밸런스 선택 완료',
      body: '오늘의 밸런스 게임에 답했어요.',
      payload: { questionId, choice },
      eventDate: today,
    });
    await updateStreakForDate(couple, today);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /balance/answer POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 4. Challenges API (목표 챌린지)
// ============================================

// 활성 챌린지 목록
router.get('/challenges', async (req, res) => {
  try {
    await ensureTables();
    const result = await query("SELECT * FROM challenges WHERE status = 'active' ORDER BY created_at DESC");
    res.json({ ok: true, challenges: result.rows });
  } catch (err) {
    console.error('[API] /challenges GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 챌린지 생성
router.post('/challenges', async (req, res) => {
  try {
    await ensureTables();
    const { title, description, target_value, unit, owner_id, start_date, target_date } = req.body;

    if (!title || !target_value || !owner_id || !start_date) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const result = await query(
      `INSERT INTO challenges (title, description, target_value, unit, owner_id, start_date, target_date) 
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [title, description, target_value, unit, owner_id, start_date, target_date]
    );

    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /challenges POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 챌린지 진행 기록
router.post('/challenges/:id/log', async (req, res) => {
  try {
    const { id } = req.params;
    const { value, note } = req.body;

    if (!value) {
      return res.status(400).json({ ok: false, reason: 'missing_value' });
    }

    await transaction(async (connection) => {
      // 로그 추가
      await connection.execute(
        'INSERT INTO challenge_logs (challenge_id, value, note) VALUES (?, ?, ?)',
        [id, value, note]
      );

      // 현재 값 업데이트
      await connection.execute(
        'UPDATE challenges SET current_value = current_value + ?, updated_at = NOW() WHERE id = ?',
        [value, id]
      );

      // 목표 달성 체크
      const [rows] = await connection.execute(
        'SELECT current_value, target_value FROM challenges WHERE id = ?',
        [id]
      );

      const challenge = rows[0];
      if (challenge.current_value >= challenge.target_value) {
        await connection.execute(
          'UPDATE challenges SET status = ?, completed_at = NOW() WHERE id = ?',
          ['completed', id]
        );
      }
    });

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /challenges/:id/log POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 5. Jukebox API (음원 관리)
// ============================================

// 트랙 목록 조회
router.get('/jukebox', async (req, res) => {
  try {
    await ensureTables();
    const result = await query('SELECT * FROM jukebox_tracks ORDER BY uploaded_at DESC');
    res.json({ ok: true, tracks: result.rows });
  } catch (err) {
    console.error('[API] /jukebox GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 트랙 업로드
router.post('/jukebox', upload.single('audio'), async (req, res) => {
  try {
    await ensureTables();
    const { title, artist, duration_sec, uploaded_by } = req.body;
    const file_url = req.file ? `/uploads/${req.file.filename}` : null;

    if (!title || !file_url || !uploaded_by) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const result = await query(
      'INSERT INTO jukebox_tracks (title, artist, file_url, duration_sec, uploaded_by) VALUES (?, ?, ?, ?, ?)',
      [title, artist, file_url, duration_sec, uploaded_by]
    );

    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /jukebox POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 6. Couple Info API (D-Day / 기념일)
// ============================================

let _couplesColumnReady = false;
const ensureCouplesStartDate = async () => {
  if (_couplesColumnReady) return;
  try {
    await query('ALTER TABLE Couples ADD COLUMN IF NOT EXISTS StartDate DATE NULL');
  } catch {}
  _couplesColumnReady = true;
};

router.get('/couple/info', async (req, res) => {
  try {
    await ensureUserColumns();
    await ensureCouplesStartDate();
    const uid = req.auth.userId;
    const result = await query(
      `SELECT c.CoupleId, c.StartDate,
              u1.UserId AS U1Id, COALESCE(u1.Nickname, u1.UserName) AS U1Name, u1.UserCode AS U1Code,
              u2.UserId AS U2Id, COALESCE(u2.Nickname, u2.UserName) AS U2Name, u2.UserCode AS U2Code
       FROM Couples c
       JOIN Users u1 ON c.User1Id = u1.UserId
       JOIN Users u2 ON c.User2Id = u2.UserId
       WHERE c.Status = 'active' AND (c.User1Id = ? OR c.User2Id = ?)`,
      [uid, uid]
    );

    if (result.rows.length === 0) return res.status(404).json({ ok: false, reason: 'couple_not_found' });

    const row = result.rows[0];
    const isUser1 = Number(row.U1Id) === uid;
    const partnerName = isUser1 ? row.U2Name : row.U1Name;
    const partnerCode = isUser1 ? row.U2Code : row.U1Code;

    let dDay = null;
    let startDateStr = null;
    if (row.StartDate) {
      startDateStr = dateOnly(row.StartDate);
      const [year, month, day] = startDateStr.split('-').map(Number);
      const start = new Date(year, month - 1, day);
      start.setHours(0, 0, 0, 0);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      dDay = Math.floor((today - start) / 86400000) + 1;
    }

    res.json({ ok: true, coupleId: row.CoupleId, startDate: startDateStr, dDay, partnerName, partnerCode });
  } catch (err) {
    console.error('[API] /couple/info GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/couple/info', async (req, res) => {
  try {
    await ensureCouplesStartDate();
    const { start_date } = req.body;
    const userId = req.auth.userId;
    if (!start_date) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    await query(
      `UPDATE Couples SET StartDate = ?
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)`,
      [start_date, userId, userId]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /couple/info PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// Time Capsule API
// ============================================

router.get('/capsules', async (req, res) => {
  try {
    await ensureTables();
    const today = new Date().toISOString().split('T')[0];
    const result = await query(
      `SELECT *, (open_date <= ?) AS is_openable FROM time_capsules ORDER BY open_date ASC`,
      [today]
    );
    res.json({ ok: true, capsules: result.rows });
  } catch (err) {
    console.error('[API] /capsules GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/capsules', async (req, res) => {
  try {
    await ensureTables();
    const { title, message, created_by, open_date } = req.body;
    if (!title || !created_by || !open_date) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    const today = new Date().toISOString().split('T')[0];
    if (open_date <= today) {
      return res.status(400).json({ ok: false, reason: 'open_date_must_be_future' });
    }
    await query(
      'INSERT INTO time_capsules (title, message, created_by, open_date) VALUES (?, ?, ?, ?)',
      [title, message || null, created_by, open_date]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /capsules POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/capsules/:id/open', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    const today = new Date().toISOString().split('T')[0];
    const check = await query(
      'SELECT id, is_opened, open_date FROM time_capsules WHERE id = ?',
      [Number(id)]
    );
    if (!check.rows.length) return res.status(404).json({ ok: false, reason: 'not_found' });
    const capsule = check.rows[0];
    if (capsule.open_date > today) {
      return res.status(403).json({ ok: false, reason: 'not_yet' });
    }
    if (capsule.is_opened) return res.json({ ok: true, already: true });
    await query(
      'UPDATE time_capsules SET is_opened = 1, opened_at = NOW() WHERE id = ?',
      [Number(id)]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /capsules/:id/open PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// ============================================
// Helpers for premium & limits
// ============================================

const FREE_FOLDER_LIMIT = 15;
const FREE_PHOTO_LIMIT  = 10;   // 각자 per folder
const PRE_FOLDER_LIMIT  = 100;
const PRE_PHOTO_LIMIT   = 50;

const getUserPremium = async (userId) => {
  const r = await query(
    'SELECT is_premium, premium_expires_at FROM Users WHERE UserId = ?',
    [userId]
  );
  const u = r.rows[0];
  if (!u) return false;
  if (!u.is_premium) return false;
  // 만료 확인
  if (u.premium_expires_at && new Date(u.premium_expires_at) < new Date()) {
    // 만료됨 → is_premium 초기화
    await query('UPDATE Users SET is_premium=0, premium_expires_at=NULL WHERE UserId=?', [userId]);
    return false;
  }
  return true;
};

// ============================================
// Our Album API
// ============================================

// 폴더 목록 조회
router.get('/album/folders', async (req, res) => {
  try {
    await ensureTables();
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const coupleId = await getCoupleIdForUser(Number(user_id));
    if (!coupleId) return res.json({ ok: true, folders: [] });

    const isPremium = await getUserPremium(Number(user_id));
    const result = await query(
      'SELECT * FROM album_folders WHERE couple_id = ? ORDER BY sort_order ASC, created_at DESC',
      [coupleId]
    );

    const folderLimit = isPremium ? PRE_FOLDER_LIMIT : FREE_FOLDER_LIMIT;
    res.json({
      ok: true,
      folders: result.rows,
      is_premium: isPremium,
      folder_limit: folderLimit,
      folder_count: result.rows.length,
    });
  } catch (err) {
    console.error('[API] /album/folders GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 폴더 생성
router.post('/album/folders', async (req, res) => {
  try {
    await ensureTables();
    const { user_id, title, description } = req.body;
    if (!user_id || !title) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const coupleId = await getCoupleIdForUser(Number(user_id));
    if (!coupleId) return res.status(400).json({ ok: false, reason: 'not_paired' });

    const isPremium = await getUserPremium(Number(user_id));
    const folderLimit = isPremium ? PRE_FOLDER_LIMIT : FREE_FOLDER_LIMIT;

    const checkFolders = await query(
      'SELECT COUNT(*) as count FROM album_folders WHERE couple_id = ?',
      [coupleId]
    );
    const count = Number(checkFolders.rows[0]?.count || 0);
    if (count >= folderLimit) {
      return res.status(400).json({
        ok: false,
        reason: 'folder_limit_exceeded',
        is_premium: isPremium,
        current: count,
        limit: folderLimit,
        message: isPremium
          ? `Premium 요금제에서는 최대 ${PRE_FOLDER_LIMIT}개의 폴더를 생성할 수 있어요.`
          : `무료 버전에서는 최대 ${FREE_FOLDER_LIMIT}개의 폴더만 만들 수 있어요. Premium으로 업그레이드하시면 최대 ${PRE_FOLDER_LIMIT}개까지 가능해요!`,
      });
    }

    const result = await query(
      'INSERT INTO album_folders (couple_id, title, description) VALUES (?, ?, ?)',
      [coupleId, title, description || null]
    );
    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /album/folders POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 폴더 커버 이미지 업데이트
router.patch('/album/folders/:id/cover', upload.single('cover'), async (req, res) => {
  try {
    const { id } = req.params;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;
    if (!mediaUrl) return res.status(400).json({ ok: false, reason: 'no_file' });

    await query('UPDATE album_folders SET cover_url = ? WHERE id = ?', [mediaUrl, Number(id)]);
    res.json({ ok: true, cover_url: mediaUrl });
  } catch (err) {
    console.error('[API] /album/folders/:id/cover PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 기존 사진을 폴더 커버로 설정
router.patch('/album/folders/:id/set-cover', async (req, res) => {
  try {
    const { id } = req.params;
    const { photo_url } = req.body;
    if (!photo_url) return res.status(400).json({ ok: false, reason: 'no_photo_url' });

    await query('UPDATE album_folders SET cover_url = ? WHERE id = ?', [photo_url, Number(id)]);
    res.json({ ok: true, cover_url: photo_url });
  } catch (err) {
    console.error('[API] /album/folders/:id/set-cover PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});


// 폴더 삭제
router.delete('/album/folders/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    await query('DELETE FROM album_photos WHERE folder_id = ?', [Number(id)]);
    await query('DELETE FROM album_folders WHERE id = ?', [Number(id)]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /album/folders/:id DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 폴더 전체 사진 일괄 다운로드 (ZIP)
router.get('/album/folders/:id/download-all', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    
    // 폴더 이름 확인
    const folderRows = await query('SELECT title FROM album_folders WHERE id = ?', [Number(id)]);
    if (folderRows.rows.length === 0) return res.status(404).json({ ok: false, reason: 'folder_not_found' });
    const folderTitle = folderRows.rows[0].title || 'album';

    // 사진 목록 가져오기
    const photos = await query('SELECT photo_url FROM album_photos WHERE folder_id = ?', [Number(id)]);
    if (photos.rows.length === 0) return res.status(404).json({ ok: false, reason: 'no_photos' });

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(folderTitle)}.zip"`);

    const archive = archiver('zip', { zlib: { level: 9 } });
    archive.on('error', (err) => { throw err; });
    archive.pipe(res);

    for (let i = 0; i < photos.rows.length; i++) {
      const p = photos.rows[i];
      if (p.photo_url) {
        // url is like /uploads/album/...
        // The static files are served from realtime-server directory if starting there, usually 'uploads' folder
        // Let's build the absolute path
        const relativePath = p.photo_url.startsWith('/') ? p.photo_url.slice(1) : p.photo_url;
        const absPath = path.resolve(process.cwd(), relativePath);
        if (fs.existsSync(absPath)) {
          const ext = path.extname(absPath) || '.jpg';
          archive.file(absPath, { name: `photo_${i + 1}${ext}` });
        }
      }
    }

    await archive.finalize();
  } catch (err) {
    console.error('[API] /album/folders/:id/download-all GET error:', err);
    if (!res.headersSent) {
      res.status(500).json({ ok: false, reason: 'internal_error' });
    }
  }
});

// 폴더별 사진 조회
router.get('/album/photos', async (req, res) => {
  try {
    await ensureTables();
    const { folder_id } = req.query;
    if (!folder_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const result = await query(
      'SELECT * FROM album_photos WHERE folder_id = ? ORDER BY created_at ASC',
      [Number(folder_id)]
    );
    res.json({ ok: true, photos: result.rows });
  } catch (err) {
    console.error('[API] /album/photos GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 폴더별 사진 등록
router.post('/album/photos', upload.single('media'), async (req, res) => {
  try {
    await ensureTables();
    const { folder_id, user_id, user_code, caption } = req.body;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;

    if (!folder_id || !user_id || !user_code || !mediaUrl) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const isPremium = await getUserPremium(Number(user_id));
    const photoLimit = isPremium ? PRE_PHOTO_LIMIT : FREE_PHOTO_LIMIT;

    // 각자 사진 개수 체크
    const checkCount = await query(
      'SELECT COUNT(*) as count FROM album_photos WHERE folder_id = ? AND user_id = ?',
      [Number(folder_id), Number(user_id)]
    );
    const count = Number(checkCount.rows[0]?.count || 0);
    if (count >= photoLimit) {
      return res.status(400).json({
        ok: false,
        reason: 'limit_exceeded',
        is_premium: isPremium,
        current: count,
        limit: photoLimit,
        message: isPremium
          ? `Premium 요금제에서는 한 폴더에 최대 ${PRE_PHOTO_LIMIT}장씩 올릴 수 있어요.`
          : `무료 버전에서는 한 폴더에 각자 최대 ${FREE_PHOTO_LIMIT}장까지만 올릴 수 있어요. Premium으로 업그레이드하시면 ${PRE_PHOTO_LIMIT}장까지 가능해요!`,
      });
    }

    // 파일 크기 계산 (KB)
    const fileSizeKb = req.file?.size ? Math.round(req.file.size / 1024) : null;

    const result = await query(
      'INSERT INTO album_photos (folder_id, user_id, user_code, photo_url, caption, is_premium_quality, file_size_kb) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [Number(folder_id), Number(user_id), user_code, mediaUrl, caption || null, isPremium ? 1 : 0, fileSizeKb]
    );

    res.json({ ok: true, id: result.rows.insertId, photo_url: mediaUrl });
  } catch (err) {
    console.error('[API] /album/photos POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 사진 삭제
router.delete('/album/photos/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    await query('DELETE FROM album_photos WHERE id = ?', [Number(id)]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /album/photos/:id DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// Private Reflections API (마음 대피소)
// ============================================

// 대피소 고민 목록 조회
router.get('/reflections', async (req, res) => {
  try {
    await ensureTables();
    const { user_id, category } = req.query;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    let sql = 'SELECT * FROM private_reflections WHERE user_id = ?';
    const params = [Number(user_id)];
    if (category && category !== 'all') {
      sql += ' AND category = ?';
      params.push(category);
    }
    sql += ' ORDER BY created_at DESC';

    const result = await query(sql, params);
    res.json({ ok: true, reflections: result.rows });
  } catch (err) {
    console.error('[API] /reflections GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 고민 등록
router.post('/reflections', async (req, res) => {
  try {
    await ensureTables();
    const { user_id, content, mood_tag, category } = req.body;
    if (!user_id || !content) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const result = await query(
      'INSERT INTO private_reflections (user_id, content, mood_tag, category) VALUES (?, ?, ?, ?)',
      [Number(user_id), content, mood_tag || null, category || 'general']
    );
    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /reflections POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 고민 수정
router.patch('/reflections/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    const { content, mood_tag, category } = req.body;
    if (!content) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    await query(
      'UPDATE private_reflections SET content = ?, mood_tag = ?, category = ? WHERE id = ?',
      [content, mood_tag || null, category || 'general', Number(id)]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /reflections/:id PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 고민 삭제
router.delete('/reflections/:id', async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    await query('DELETE FROM private_reflections WHERE id = ?', [Number(id)]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /reflections/:id DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// Premium Subscription API
// ============================================

// 현재 프리미엄 상태 조회
router.get('/premium/status', async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const uid = Number(user_id);
    const userRes = await query(
      'SELECT is_premium, premium_since, premium_expires_at FROM Users WHERE UserId = ?',
      [uid]
    );
    const u = userRes.rows[0];
    if (!u) return res.status(404).json({ ok: false, reason: 'user_not_found' });

    // 만료 확인 및 자동 해제
    let isPremium = Boolean(u.is_premium);
    if (isPremium && u.premium_expires_at && new Date(u.premium_expires_at) < new Date()) {
      await query('UPDATE Users SET is_premium=0 WHERE UserId=?', [uid]);
      isPremium = false;
    }

    // 최신 구독 정보
    const subRes = await query(
      'SELECT * FROM premium_subscriptions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
      [uid]
    );

    res.json({
      ok: true,
      is_premium: isPremium,
      premium_since: u.premium_since,
      premium_expires_at: u.premium_expires_at,
      subscription: subRes.rows[0] || null,
      limits: {
        folder_limit: isPremium ? PRE_FOLDER_LIMIT : FREE_FOLDER_LIMIT,
        photo_limit_per_user: isPremium ? PRE_PHOTO_LIMIT : FREE_PHOTO_LIMIT,
        hd_quality: isPremium,
      },
    });
  } catch (err) {
    console.error('[API] /premium/status GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 프리미엄 구독 활성화 (결제 완료 후 호출)
router.post('/premium/activate', async (req, res) => {
  try {
    const { user_id, payment_key, payment_method, plan } = req.body;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const uid = Number(user_id);
    const planType = plan || 'monthly';

    // 만료일 계산
    const now = new Date();
    const expiresAt = new Date(now);
    if (planType === 'yearly') {
      expiresAt.setFullYear(expiresAt.getFullYear() + 1);
    } else {
      expiresAt.setMonth(expiresAt.getMonth() + 1);
    }

    // Users 테이블 업데이트
    await query(
      'UPDATE Users SET is_premium=1, premium_since=?, premium_expires_at=? WHERE UserId=?',
      [now, expiresAt, uid]
    );

    // 구독 기록 삽입
    const amount = planType === 'yearly' ? 19000 : 1900;
    await query(
      'INSERT INTO premium_subscriptions (user_id, plan, status, amount_krw, started_at, expires_at, payment_key, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [uid, planType, 'active', amount, now, expiresAt, payment_key || 'demo', payment_method || 'card']
    );

    res.json({
      ok: true,
      is_premium: true,
      premium_since: now,
      premium_expires_at: expiresAt,
      message: 'Premium 구독이 활성화되었어요! 이제 더 많은 추억을 저장할 수 있어요 🎉',
    });
  } catch (err) {
    console.error('[API] /premium/activate POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 프리미엄 구독 취소
router.post('/premium/cancel', async (req, res) => {
  try {
    const { user_id } = req.body;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    const uid = Number(user_id);
    await query(
      'UPDATE premium_subscriptions SET status = ? WHERE user_id = ? AND status = ?',
      ['cancelled', uid, 'active']
    );
    // 현재 구독 기간이 끝날 때까지는 premium 유지 (expires_at 그대로)
    res.json({ ok: true, message: '구독이 취소되었어요. 현재 구독 기간이 끝나면 자동으로 무료 플랜으로 전환됩니다.' });
  } catch (err) {
    console.error('[API] /premium/cancel POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

export default router;
