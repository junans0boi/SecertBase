/**
 * REST API Routes for Phase 3 Archiving Features
 * Endpoints: /api/auth, /api/user, /api/setlog, /api/map, /api/qa, /api/challenges, /api/jukebox
 */

import express from 'express';
import multer from 'multer';
import { ZipArchive } from 'archiver';
import bcrypt from 'bcryptjs';
import { createHash } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { OAuth2Client } from 'google-auth-library';
import { query, transaction } from './db.js';
import { config } from './config.js';
import { providerState, searchPlaces } from './place-search.js';
import { canEditMapPin, normalizeMapEditorUserId } from './map-ownership.js';
import { partnerIdForCouple } from './couple-separation.js';
import {
  isPasswordUser,
  buildTombstoneFields,
  classifyPinsForDeletion,
  collectMediaPaths,
} from './account-deletion.js';
import { normalizeMomentClip } from './moment-clip.js';
import { businessDate } from './business-date.js';
import { createExplanationProvider } from './relationship-explanation-provider.js';
import { createExplanationAttempt } from './relationship-explanation-service.js';
import {
  FORTUNE_CONTENT_VERSION,
  buildEmotionalFlow,
  buildPersonalFortune,
  buildRelationshipFortune,
} from './relationship-fortune.js';
import {
  SAJU_CALCULATION_VERSION,
  buildRelationshipSaju,
  calculatePersonalSaju,
  fingerprintSajuInput,
  fingerprintSajuPair,
  getSajuProfileState,
} from './relationship-saju.js';
import {
  TAROT_CATALOG_VERSION,
  drawSelectedTarot,
  undrawnTarot,
} from './relationship-tarot.js';
import {
  MINDCARE_CONTENT_VERSION,
  advanceMindcareState,
  createMindcareState,
  detectRiskCandidate,
  mindcareStateView,
  resolveMindcareSafety,
} from './relationship-mindcare.js';
import { buildSafetyResources } from './relationship-safety.js';
import { buildAssessmentComparison } from './relationship-comparison.js';
import {
  buildFortuneContext,
  buildPrivateCounselingContext,
  buildRelationshipContentAttempt,
  buildSharedCounselingContext,
} from './relationship-context-builder.js';
import {
  canReplaceTodayMoment,
  canViewTodayMoment,
  maskLockedTodayMoment,
  todayMomentStatus,
} from './today-moment-policy.js';
import {
  disabledFeature,
  mvpRestFeatureGate,
  requireAuth,
} from './backend-access.js';
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
    await query(`ALTER TABLE setlog_posts ADD COLUMN IF NOT EXISTS session_id VARCHAR(64) NULL`);
    await query(`ALTER TABLE setlog_posts ADD INDEX IF NOT EXISTS idx_setlog_session (session_id)`);
    await query(`
      CREATE TABLE IF NOT EXISTS setlog_reactions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        couple_id INT NOT NULL,
        session_id VARCHAR(64) NOT NULL,
        user_id INT NOT NULL,
        emoji VARCHAR(8) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_reaction (couple_id, session_id, user_id),
        INDEX idx_reaction_session (couple_id, session_id)
      )
    `);
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
  await query(`ALTER TABLE map_pins ADD COLUMN IF NOT EXISTS media_url TEXT NULL`);

  // 비밀장소 리뷰 테이블 (0013)
  await query(`CREATE TABLE IF NOT EXISTS map_pin_reviews (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    map_pin_id INT         NOT NULL,
    user_id    INT         NOT NULL,
    couple_id  INT         NOT NULL,
    user_code  VARCHAR(50) NULL,
    content    TEXT        NULL,
    media_url  TEXT        NULL,
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_reviews_pin    (map_pin_id),
    INDEX idx_reviews_couple (couple_id)
  )`);

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

    // 탈퇴 tombstone 컬럼
    await query(`ALTER TABLE Users ADD COLUMN IF NOT EXISTS IsDeleted TINYINT(1) NOT NULL DEFAULT 0`);
    await query(`ALTER TABLE Users ADD COLUMN IF NOT EXISTS DeletedAt DATETIME NULL`);
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

const normalizeBirthTime = (value) => {
  if (value == null || String(value).trim() === '') return null;
  const time = String(value).trim();
  if (!/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(time)) {
    return undefined;
  }
  return time.length === 5 ? `${time}:00` : time;
};

const isValidIsoDate = (value) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
};

const isFutureDate = (value) => value > new Date().toISOString().slice(0, 10);

const isValidTimezone = (value) => {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format();
    return true;
  } catch {
    return false;
  }
};

const birthProfileFromRow = (user) => ({
  calendarType: user.BirthCalendarType,
  birthDate: dateOnly(user.BirthDate),
  lunarLeapMonth: Boolean(user.BirthLunarLeapMonth),
  birthTime: user.BirthTime == null ? null : String(user.BirthTime),
  timezone: user.BirthTimezone,
  birthPlace: user.BirthPlace ?? null,
});

const relationshipLikertScale = [
  { value: 1, label: '전혀 그렇지 않다' },
  { value: 2, label: '그렇지 않다' },
  { value: 3, label: '보통이다' },
  { value: 4, label: '그렇다' },
  { value: 5, label: '매우 그렇다' },
];

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
  PartnerName: user.PartnerName ?? null,
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
            COALESCE(pu.Nickname, pu.UserName) AS PartnerName,
            c.RoomCode, c.RoomSecret, c.Status AS CoupleStatus,
            CASE
              WHEN c.ReunionCount > 0 AND c.User1Id = u.UserId AND c.ReunionNoticeUser1SeenAt IS NULL THEN 1
              WHEN c.ReunionCount > 0 AND c.User2Id = u.UserId AND c.ReunionNoticeUser2SeenAt IS NULL THEN 1
              ELSE 0
            END AS ReunionNoticePending
     FROM Users u
     JOIN User_Preference p ON u.UserId = p.UserId
     LEFT JOIN Couples c ON (u.UserId = c.User1Id OR u.UserId = c.User2Id) AND c.Status = 'active'
     LEFT JOIN Users pu ON pu.UserCode = p.PartnerCode
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

const shiftDate = (date, days) => {
  const value = new Date(`${date}T12:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
};

class TodayMomentRequestError extends Error {
  constructor(status, reason) {
    super(reason);
    this.status = status;
    this.reason = reason;
  }
}

const sendTodayMomentError = (res, error) => {
  if (!(error instanceof TodayMomentRequestError)) return false;
  res.status(error.status).json({ ok: false, reason: error.reason });
  return true;
};

class AfterglowRequestError extends Error {
  constructor(status, reason) {
    super(reason);
    this.status = status;
    this.reason = reason;
  }
}

const sendAfterglowError = (res, error) => {
  if (!(error instanceof AfterglowRequestError)) return false;
  res.status(error.status).json({ ok: false, reason: error.reason });
  return true;
};

const selectTodayMoment = async (connection, { coupleId, userId, postId, date }) => {
  await connection.execute(
    'SELECT CoupleId FROM Couples WHERE CoupleId = ? AND Status = \'active\' FOR UPDATE',
    [coupleId],
  );
  const [posts] = await connection.execute(
    `SELECT id FROM setlog_posts
     WHERE id = ? AND couple_id = ? AND user_id = ? AND taken_at = ?
     LIMIT 1`,
    [postId, coupleId, userId, date],
  );
  if (!posts[0]) throw new TodayMomentRequestError(404, 'today_moment_not_found');

  const [current] = await connection.execute(
    `SELECT revealed_at FROM today_moments
     WHERE couple_id = ? AND user_id = ? AND business_date = ?
     LIMIT 1 FOR UPDATE`,
    [coupleId, userId, date],
  );
  if (current[0] && !canReplaceTodayMoment(current[0].revealed_at)) {
    throw new TodayMomentRequestError(409, 'today_loop_locked');
  }

  await connection.execute(
    `INSERT INTO today_moments
       (couple_id, user_id, business_date, setlog_post_id, selected_at, revealed_at, deleted_at)
     VALUES (?, ?, ?, ?, NOW(), NULL, NULL)
     ON DUPLICATE KEY UPDATE
       setlog_post_id = VALUES(setlog_post_id), selected_at = NOW(), deleted_at = NULL`,
    [coupleId, userId, date, postId],
  );

  const [participants] = await connection.execute(
    `SELECT COUNT(*) AS count FROM today_moments
     WHERE couple_id = ? AND business_date = ? AND setlog_post_id IS NOT NULL`,
    [coupleId, date],
  );
  if (Number(participants[0]?.count) >= 2) {
    await connection.execute(
      `UPDATE today_moments SET revealed_at = COALESCE(revealed_at, NOW())
       WHERE couple_id = ? AND business_date = ?`,
      [coupleId, date],
    );
  }
};

const serializeTodayMomentRow = (row) => {
  if (!row) return null;
  if (row.deleted_at || !row.id) {
    return {
      user_id: row.user_id,
      UserName: row.UserName,
      deleted: true,
    };
  }
  return {
    id: row.id,
    user_id: row.user_id,
    UserName: row.UserName,
    media_type: row.media_type,
    media_url: row.media_url,
    caption: row.caption,
    tags: parseJsonArray(row.tags),
    taken_at: dateOnly(row.taken_at),
    captured_at: row.captured_at,
    map_pin_id: row.map_pin_id,
    linked_place_name: row.linked_place_name,
    deleted: false,
  };
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

    // 탈퇴한 사용자는 로그인 불가
    if (user.IsDeleted) {
      return res.status(401).json({ ok: false, reason: 'invalid_credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.PasswordHash?.toString());

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

router.get('/relationship/birth-profile', async (req, res) => {
  try {
    const result = await query(
      `SELECT BirthDate, BirthCalendarType, BirthLunarLeapMonth, BirthTime, BirthTimezone, BirthPlace
       FROM Users WHERE UserId = ?`,
      [req.auth.userId],
    );
    const user = result.rows[0];
    if (!user) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }
    return res.json({ ok: true, birthProfile: birthProfileFromRow(user) });
  } catch (error) {
    console.error('[API] /relationship/birth-profile GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/relationship/birth-profile', async (req, res) => {
  try {
    const calendarType = String(req.body?.calendarType ?? '').trim();
    const birthDate = String(req.body?.birthDate ?? '').trim();
    const lunarLeapMonthValue = req.body?.lunarLeapMonth;
    const lunarLeapMonth = lunarLeapMonthValue == null ? false : lunarLeapMonthValue;
    const timezone = String(req.body?.timezone ?? '').trim();
    const birthTime = normalizeBirthTime(req.body?.birthTime);
    const birthPlaceValue = req.body?.birthPlace;
    const birthPlace = birthPlaceValue == null || String(birthPlaceValue).trim() === ''
      ? null
      : String(birthPlaceValue).trim();

    if (!calendarType || !birthDate || !timezone) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    if (!['solar', 'lunar'].includes(calendarType)) {
      return res.status(400).json({ ok: false, reason: 'invalid_calendar_type' });
    }
    if (typeof lunarLeapMonth !== 'boolean') {
      return res.status(400).json({ ok: false, reason: 'invalid_lunar_leap_month' });
    }
    if (lunarLeapMonth && calendarType !== 'lunar') {
      return res.status(400).json({ ok: false, reason: 'invalid_lunar_leap_month' });
    }
    if (!isValidIsoDate(birthDate)) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_date' });
    }
    if (isFutureDate(birthDate)) {
      return res.status(400).json({ ok: false, reason: 'future_birth_date' });
    }
    if (birthTime === undefined) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_time' });
    }
    if (timezone.length > 64 || !isValidTimezone(timezone)) {
      return res.status(400).json({ ok: false, reason: 'invalid_timezone' });
    }
    if (birthPlace !== null && birthPlace.length > 255) {
      return res.status(400).json({ ok: false, reason: 'invalid_birth_place' });
    }

    await query(
      `UPDATE Users
       SET BirthCalendarType = ?, BirthDate = ?, BirthLunarLeapMonth = ?, BirthTime = ?,
           BirthTimezone = ?, BirthPlace = ?
       WHERE UserId = ?`,
      [calendarType, birthDate, lunarLeapMonth ? 1 : 0, birthTime, timezone, birthPlace, req.auth.userId],
    );
    const updated = await query(
      `SELECT BirthDate, BirthCalendarType, BirthLunarLeapMonth, BirthTime, BirthTimezone, BirthPlace
       FROM Users WHERE UserId = ?`,
      [req.auth.userId],
    );
    if (!updated.rows[0]) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }
    return res.json({
      ok: true,
      birthProfile: birthProfileFromRow(updated.rows[0]),
    });
  } catch (error) {
    console.error('[API] /relationship/birth-profile PATCH error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/assessments', async (req, res) => {
  try {
    const [catalogResult, dimensionResult, questionResult, statusResult] = await Promise.all([
      query(
        `SELECT a.code, a.audience, a.title, a.description,
                v.version_label, v.candidate_question_count, v.active_question_count
         FROM relationship_assessment_catalog a
         JOIN relationship_assessment_versions v
           ON v.assessment_id = a.assessment_id AND v.is_active = 1
         WHERE a.is_active = 1
         ORDER BY a.sort_order, a.assessment_id`,
      ),
      query(
        `SELECT a.code, d.dimension_key, d.display_name, d.sort_order
         FROM relationship_assessment_catalog a
         JOIN relationship_assessment_versions v
           ON v.assessment_id = a.assessment_id AND v.is_active = 1
         JOIN relationship_assessment_dimensions d ON d.version_id = v.version_id
         WHERE a.is_active = 1
         ORDER BY a.sort_order, d.sort_order`,
      ),
      query(
        `SELECT a.code, q.question_key, q.prompt, d.dimension_key,
                q.reverse_scored, q.question_order
         FROM relationship_assessment_catalog a
         JOIN relationship_assessment_versions v
           ON v.assessment_id = a.assessment_id AND v.is_active = 1
         JOIN relationship_assessment_questions q
           ON q.version_id = v.version_id AND q.is_active = 1
         JOIN relationship_assessment_dimensions d ON d.dimension_id = q.dimension_id
         WHERE a.is_active = 1
         ORDER BY a.sort_order, q.question_order`,
      ),
      query(
        `SELECT a.code,
                CASE
                  WHEN EXISTS (
                    SELECT 1
                    FROM relationship_assessment_attempts ra
                    WHERE ra.user_id = ? AND ra.version_id = v.version_id
                      AND ra.status = 'in_progress'
                  ) THEN 'in_progress'
                  WHEN EXISTS (
                    SELECT 1
                    FROM relationship_assessment_results rr
                    WHERE rr.user_id = ? AND rr.version_id = v.version_id
                  ) THEN 'completed'
                  ELSE 'not_started'
                END AS completion_status,
                EXISTS (
                  SELECT 1
                  FROM relationship_assessment_results rh
                  WHERE rh.user_id = ? AND rh.version_id = v.version_id
                ) AS has_result_history
         FROM relationship_assessment_catalog a
         JOIN relationship_assessment_versions v
           ON v.assessment_id = a.assessment_id AND v.is_active = 1
         WHERE a.is_active = 1
         ORDER BY a.sort_order, a.assessment_id`,
        [req.auth.userId, req.auth.userId, req.auth.userId],
      ),
    ]);

    const statusByCode = new Map(
      statusResult.rows.map((row) => [row.code, row.completion_status]),
    );
    const assessments = catalogResult.rows.map((row) => ({
      code: row.code,
      audience: row.audience,
      title: row.title,
      description: row.description,
      version: row.version_label,
      candidateQuestionCount: Number(row.candidate_question_count),
      activeQuestionCount: Number(row.active_question_count),
      completionStatus: statusByCode.get(row.code) ?? 'not_started',
      hasResultHistory:
        row.has_result_history === true || Number(row.has_result_history) === 1,
      dimensions: [],
      questions: [],
    }));
    const byCode = new Map(assessments.map((assessment) => [assessment.code, assessment]));

    for (const row of dimensionResult.rows) {
      const assessment = byCode.get(row.code);
      if (!assessment) continue;
      assessment.dimensions.push({
        key: row.dimension_key,
        title: row.display_name,
        order: Number(row.sort_order),
      });
    }
    for (const row of questionResult.rows) {
      const assessment = byCode.get(row.code);
      if (!assessment) continue;
      assessment.questions.push({
        key: row.question_key,
        prompt: row.prompt,
        dimensionKey: row.dimension_key,
        reverseScored: Boolean(row.reverse_scored),
        order: Number(row.question_order),
        likertScale: relationshipLikertScale,
      });
    }

    return res.json({
      ok: true,
      likertScale: relationshipLikertScale,
      assessments,
    });
  } catch (error) {
    console.error('[API] /relationship/assessments error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const getActiveRelationshipAssessment = async (code) => {
  const result = await query(
    `SELECT a.code, a.audience, v.version_id, v.version_label, v.active_question_count
     FROM relationship_assessment_catalog a
     JOIN relationship_assessment_versions v
       ON v.assessment_id = a.assessment_id AND v.is_active = 1
     WHERE a.code = ? AND a.is_active = 1
     LIMIT 1`,
    [code],
  );
  return result.rows[0] ?? null;
};

const relationshipAttemptPayload = async (attempt, assessment) => {
  const answersResult = await query(
    `SELECT q.question_key, aa.answer_value, aa.saved_at
     FROM relationship_assessment_attempt_answers aa
     JOIN relationship_assessment_questions q ON q.question_id = aa.question_id
     WHERE aa.attempt_id = ?
     ORDER BY q.question_order`,
    [attempt.attempt_id],
  );
  const answers = answersResult.rows.map((answer) => ({
    questionKey: answer.question_key,
    value: Number(answer.answer_value),
    savedAt: answer.saved_at instanceof Date
      ? answer.saved_at.toISOString()
      : answer.saved_at == null ? null : String(answer.saved_at),
  }));
  const totalCount = Number(assessment.active_question_count);
  const lastSavedAt = answers.length === 0 ? null : answers[answers.length - 1].savedAt;
  return {
    id: Number(attempt.attempt_id),
    assessmentCode: assessment.code,
    audience: assessment.audience,
    coupleId: attempt.couple_id == null ? null : Number(attempt.couple_id),
    version: assessment.version_label,
    status: attempt.status,
    startedAt: attempt.started_at instanceof Date
      ? attempt.started_at.toISOString()
      : String(attempt.started_at),
    updatedAt: attempt.updated_at instanceof Date
      ? attempt.updated_at.toISOString()
      : String(attempt.updated_at),
    progress: {
      answeredCount: answers.length,
      totalCount,
      percentage: totalCount === 0 ? 0 : Math.round((answers.length / totalCount) * 100),
      lastSavedAt,
    },
    answers,
  };
};

const findInProgressRelationshipAttempt = async (userId, versionId) => {
  const result = await query(
    `SELECT attempt_id, couple_id, status, started_at, updated_at
     FROM relationship_assessment_attempts
     WHERE user_id = ? AND version_id = ? AND status = 'in_progress'
     ORDER BY attempt_id DESC
     LIMIT 1`,
    [userId, versionId],
  );
  return result.rows[0] ?? null;
};

const findInProgressRelationshipCoupleAttempt = async (userId, versionId, coupleId) => {
  const result = await query(
    `SELECT attempt_id, couple_id, status, started_at, updated_at
     FROM relationship_assessment_attempts
     WHERE user_id = ? AND version_id = ? AND couple_id = ? AND status = 'in_progress'
     ORDER BY attempt_id DESC
     LIMIT 1`,
    [userId, versionId, coupleId],
  );
  return result.rows[0] ?? null;
};

router.get('/relationship/assessments/:code/attempt', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (!assessment) {
      return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    }
    if (assessment.audience !== 'individual') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_personal' });
    }
    const attempt = await findInProgressRelationshipAttempt(
      req.auth.userId,
      assessment.version_id,
    );
    return res.json({
      ok: true,
      attempt: attempt ? await relationshipAttemptPayload(attempt, assessment) : null,
    });
  } catch (error) {
    console.error('[API] /relationship/assessments/:code/attempt GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/assessments/:code/attempt', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (!assessment) {
      return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    }
    if (assessment.audience !== 'individual') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_personal' });
    }
    let attempt = await findInProgressRelationshipAttempt(
      req.auth.userId,
      assessment.version_id,
    );
    let created = false;
    if (!attempt) {
      const inserted = await query(
        `INSERT INTO relationship_assessment_attempts (user_id, version_id, couple_id)
         VALUES (?, ?, NULL)`,
        [req.auth.userId, assessment.version_id],
      );
      const createdResult = await query(
        `SELECT attempt_id, couple_id, status, started_at, updated_at
         FROM relationship_assessment_attempts
         WHERE attempt_id = ? AND user_id = ?`,
        [inserted.rows.insertId, req.auth.userId],
      );
      attempt = createdResult.rows[0] ?? null;
      created = true;
    }
    if (!attempt) {
      return res.status(500).json({ ok: false, reason: 'attempt_creation_failed' });
    }
    return res.status(created ? 201 : 200).json({
      ok: true,
      resumed: !created,
      attempt: await relationshipAttemptPayload(attempt, assessment),
    });
  } catch (error) {
    console.error('[API] /relationship/assessments/:code/attempt POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/couple-assessments/:code/attempt', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (!assessment) {
      return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    }
    if (assessment.audience !== 'couple') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_couple' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const attempt = await findInProgressRelationshipCoupleAttempt(
      req.auth.userId,
      assessment.version_id,
      coupleId,
    );
    return res.json({
      ok: true,
      attempt: attempt ? await relationshipAttemptPayload(attempt, assessment) : null,
    });
  } catch (error) {
    console.error('[API] /relationship/couple-assessments/:code/attempt GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/couple-assessments/:code/attempt', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (!assessment) {
      return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    }
    if (assessment.audience !== 'couple') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_couple' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    let attempt = await findInProgressRelationshipCoupleAttempt(
      req.auth.userId,
      assessment.version_id,
      coupleId,
    );
    let created = false;
    if (!attempt) {
      const inserted = await query(
        `INSERT INTO relationship_assessment_attempts (user_id, couple_id, version_id)
         VALUES (?, ?, ?)`,
        [req.auth.userId, coupleId, assessment.version_id],
      );
      const createdResult = await query(
        `SELECT attempt_id, couple_id, status, started_at, updated_at
         FROM relationship_assessment_attempts
         WHERE attempt_id = ? AND user_id = ? AND couple_id = ?`,
        [inserted.rows.insertId, req.auth.userId, coupleId],
      );
      attempt = createdResult.rows[0] ?? null;
      created = true;
    }
    if (!attempt) {
      return res.status(500).json({ ok: false, reason: 'attempt_creation_failed' });
    }
    return res.status(created ? 201 : 200).json({
      ok: true,
      resumed: !created,
      attempt: await relationshipAttemptPayload(attempt, assessment),
    });
  } catch (error) {
    console.error('[API] /relationship/couple-assessments/:code/attempt POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/relationship/assessment-attempts/:attemptId/answers/:questionKey', async (req, res) => {
  try {
    const attemptId = Number(req.params.attemptId);
    const value = Number(req.body?.value);
    if (!Number.isSafeInteger(attemptId) || attemptId <= 0) {
      return res.status(400).json({ ok: false, reason: 'invalid_attempt_id' });
    }
    if (!Number.isInteger(value) || value < 1 || value > 5) {
      return res.status(400).json({ ok: false, reason: 'invalid_answer_value' });
    }

    const attemptResult = await query(
      `SELECT a.attempt_id, a.couple_id, a.version_id, a.status, a.started_at, a.updated_at,
              v.version_label, c.code, c.audience, v.active_question_count
       FROM relationship_assessment_attempts a
       JOIN relationship_assessment_versions v ON v.version_id = a.version_id
       JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
       WHERE a.attempt_id = ? AND a.user_id = ? AND a.status = 'in_progress'
       LIMIT 1`,
      [attemptId, req.auth.userId],
    );
    const attempt = attemptResult.rows[0];
    if (!attempt) {
      return res.status(404).json({ ok: false, reason: 'attempt_not_found' });
    }
    if (attempt.audience === 'couple') {
      const activeCoupleId = await getCoupleIdForUser(req.auth.userId);
      if (
        activeCoupleId == null ||
        Number(activeCoupleId) !== Number(attempt.couple_id)
      ) {
        return res.status(409).json({ ok: false, reason: 'active_couple_required' });
      }
    }

    const questionResult = await query(
      `SELECT question_id
       FROM relationship_assessment_questions
       WHERE version_id = ? AND question_key = ? AND is_active = 1
       LIMIT 1`,
      [attempt.version_id, String(req.params.questionKey ?? '').trim()],
    );
    const question = questionResult.rows[0];
    if (!question) {
      return res.status(404).json({ ok: false, reason: 'question_not_found' });
    }

    await query(
      `INSERT INTO relationship_assessment_attempt_answers
         (attempt_id, question_id, answer_value)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE answer_value = VALUES(answer_value), saved_at = CURRENT_TIMESTAMP`,
      [attemptId, question.question_id, value],
    );
    await query(
      `UPDATE relationship_assessment_attempts
       SET updated_at = CURRENT_TIMESTAMP
       WHERE attempt_id = ? AND user_id = ?`,
      [attemptId, req.auth.userId],
    );

    const updatedResult = await query(
      `SELECT attempt_id, couple_id, status, started_at, updated_at
       FROM relationship_assessment_attempts
       WHERE attempt_id = ? AND user_id = ?`,
      [attemptId, req.auth.userId],
    );
    return res.json({
      ok: true,
      attempt: await relationshipAttemptPayload(updatedResult.rows[0], attempt),
    });
  } catch (error) {
    console.error('[API] /relationship/assessment-attempts/:attemptId/answers PATCH error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const relationshipDimensionScore = (rows) => {
  const byDimension = new Map();
  for (const row of rows) {
    const key = row.dimension_key;
    const bucket = byDimension.get(key) ?? {
      key,
      title: row.display_name,
      sortOrder: Number(row.sort_order),
      adjustedTotal: 0,
      answerCount: 0,
    };
    const rawValue = Number(row.answer_value);
    bucket.adjustedTotal += Number(row.reverse_scored) === 1 ? 6 - rawValue : rawValue;
    bucket.answerCount += 1;
    byDimension.set(key, bucket);
  }
  return [...byDimension.values()]
    .map((dimension) => {
      const mean = dimension.adjustedTotal / dimension.answerCount;
      return {
        key: dimension.key,
        title: dimension.title,
        score: Math.round(((mean - 1) / 4) * 100),
        mean: Math.round(mean * 100) / 100,
        answerCount: dimension.answerCount,
      };
    })
    .sort((left, right) => left.sortOrder - right.sortOrder)
    .map(({ sortOrder, ...dimension }) => dimension);
};

const attachmentTendency = (dimensions) => {
  const scores = new Map(dimensions.map((dimension) => [dimension.key, dimension.score]));
  const reassurance = scores.get('reassurance') ?? 0;
  const distance = scores.get('distance') ?? 0;
  const expression = scores.get('expression') ?? 0;
  if (reassurance >= 70 && distance >= 55 && expression >= 55) {
    return {
      key: 'balanced_connection',
      text: '안정감을 확인하면서도 관계와 개인 공간을 함께 조율하는 경향이 있어요.',
    };
  }
  if (reassurance >= 70 && distance < 50) {
    return {
      key: 'reassurance_seeking',
      text: '관계의 안정감을 자주 확인하고 싶은 경향이 있어요.',
    };
  }
  if (distance >= 70 && reassurance < 50) {
    return {
      key: 'autonomous_distance',
      text: '자율적인 거리와 개인 공간을 중요하게 여기는 경향이 있어요.',
    };
  }
  return {
    key: 'situational_balance',
    text: '상황에 따라 안정감과 개인 공간을 조율하는 경향이 있어요.',
  };
};

const socialBondingTendency = (dimensions) => {
  const scores = new Map(dimensions.map((dimension) => [dimension.key, dimension.score]));
  const depth = scores.get('depth') ?? 0;
  const dependence = scores.get('dependence') ?? 0;
  const isolation = scores.get('isolation') ?? 0;
  if (depth >= 70 && dependence < 50 && isolation < 50) {
    return {
      key: 'connected_and_balanced',
      text: '깊은 연결을 만들면서도 여러 관계와 나만의 균형을 함께 지키는 경향이 있어요.',
    };
  }
  if (dependence >= 70) {
    return {
      key: 'focused_dependence',
      text: '소수의 중요한 관계에 정서적 기대가 많이 모이는 경향이 있어요.',
    };
  }
  if (isolation >= 70) {
    return {
      key: 'isolation_awareness',
      text: '외로움과 연결의 부족을 자주 알아차리고 관계 자원이 필요한 경향이 있어요.',
    };
  }
  return {
    key: 'developing_connections',
    text: '관계의 깊이와 연결 방식을 상황에 따라 넓혀가는 경향이 있어요.',
  };
};

const emotionalRegulationTendency = (dimensions) => {
  const scores = new Map(dimensions.map((dimension) => [dimension.key, dimension.score]));
  const internal = scores.get('internal') ?? 0;
  const stimulation = scores.get('stimulation') ?? 0;
  const dialogue = scores.get('dialogue') ?? 0;
  if (internal >= 70 && dialogue >= 60) {
    return {
      key: 'reflective_dialogue',
      text: '혼자 감정을 정리한 뒤 안전한 대화로 풀어가는 경향이 있어요.',
    };
  }
  if (stimulation >= 70) {
    return {
      key: 'external_activation',
      text: '활동과 환경의 변화를 통해 감정의 흐름을 바꾸는 경향이 있어요.',
    };
  }
  if (dialogue >= 70) {
    return {
      key: 'dialogue_seeking',
      text: '대화와 공감을 통해 감정을 이해하고 회복하는 경향이 있어요.',
    };
  }
  return {
    key: 'mixed_regulation',
    text: '상황에 따라 혼자 정리하기와 외부 도움을 섞어 감정을 조절하는 경향이 있어요.',
  };
};

const relationshipDeficiencyTendency = (dimensions) => {
  const scores = new Map(dimensions.map((dimension) => [dimension.key, dimension.score]));
  const selfAwareness = scores.get('self_awareness') ?? 0;
  const partnerExpectation = scores.get('partner_expectation') ?? 0;
  const alternativeResources = scores.get('alternative_resources') ?? 0;
  if (selfAwareness >= 70 && alternativeResources >= 60) {
    return {
      key: 'aware_and_resourced',
      text: '내 필요를 알아차리고 관계 밖의 자원도 함께 활용하려는 경향이 있어요.',
    };
  }
  if (partnerExpectation >= 70) {
    return {
      key: 'expectation_exploration',
      text: '파트너에게 기대하는 마음이 커질 때, 그 필요를 구체적으로 탐색해볼 수 있는 경향이 있어요.',
    };
  }
  if (selfAwareness < 50) {
    return {
      key: 'self_awareness_exploration',
      text: '관계에서 느끼는 부족함의 이름을 천천히 찾아가는 경향이 있어요.',
    };
  }
  return {
    key: 'needs_in_context',
    text: '관계 안팎의 필요와 자원을 상황에 맞게 살펴보는 경향이 있어요.',
  };
};

const relationshipTendency = (code, dimensions) => {
  if (code === 'social_bonding') return socialBondingTendency(dimensions);
  if (code === 'emotional_regulation') return emotionalRegulationTendency(dimensions);
  if (code === 'relationship_deficiency') return relationshipDeficiencyTendency(dimensions);
  return attachmentTendency(dimensions);
};

const parseRelationshipResult = (value) => {
  if (value && typeof value === 'object') return value;
  try {
    return JSON.parse(String(value));
  } catch {
    return null;
  }
};

const getCurrentPersonalResultSource = async (userId, code) => {
  const assessment = await getActiveRelationshipAssessment(code);
  if (!assessment) return { error: { status: 404, reason: 'assessment_not_found' } };
  if (assessment.audience !== 'individual') {
    return { error: { status: 400, reason: 'assessment_not_personal' } };
  }
  const result = await query(
    `SELECT r.result_id, r.result_json, v.version_label
     FROM relationship_assessment_results r
     JOIN relationship_assessment_versions v ON v.version_id = r.version_id
     JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
     WHERE r.user_id = ? AND r.version_id = ? AND c.code = ?
     ORDER BY r.result_id DESC
     LIMIT 1`,
    [userId, assessment.version_id, code],
  );
  const row = result.rows[0];
  if (!row) return { assessment, result: null };
  return { assessment, result: row, parsed: parseRelationshipResult(row.result_json) };
};

const explanationGenerationPayload = (row) => ({
  id: Number(row.generation_id),
  status: row.status,
  provider: row.provider,
  model: row.model,
  promptVersion: row.prompt_version,
  contextVersion: row.context_version,
  explanation: row.explanation_text ?? null,
  errorCode: row.error_code ?? null,
  createdAt: row.created_at instanceof Date
    ? row.created_at.toISOString()
    : row.created_at == null ? null : String(row.created_at),
  completedAt: row.completed_at instanceof Date
    ? row.completed_at.toISOString()
    : row.completed_at == null ? null : String(row.completed_at),
});

const buildPersonalExplanationInput = (source) => ({
  sourceType: 'assessment',
  assessmentCode: source.assessment.code,
  version: source.result.version ?? source.assessment.version_label,
  dimensions: (source.parsed?.dimensions ?? []).map((dimension) => ({
    key: dimension.key,
    title: dimension.title,
    score: dimension.score,
  })),
  patternKey: source.parsed?.overallTendencyKey ?? null,
  metadata: { locale: 'ko-KR', nonClinical: true },
});

const runPersonalExplanationGeneration = async (userId, source) => {
  const input = buildPersonalExplanationInput(source);
  const provider = createExplanationProvider(config);
  const providerName = provider?.name ?? 'disabled';
  const model = provider?.model ?? null;
  const inserted = await query(
    `INSERT INTO relationship_explanation_generations
       (requester_user_id, scope_type, source_key, status, provider, model,
        prompt_version, context_version, input_json)
     VALUES (?, 'personal_assessment', ?, 'pending', ?, ?, ?, ?, ?)`,
    [
      userId,
      `assessment-result:${source.result.result_id}`,
      providerName,
      model,
      config.LLM_PROMPT_VERSION,
      config.LLM_CONTEXT_VERSION,
      JSON.stringify(input),
    ],
  );
  const attempt = await createExplanationAttempt({
    provider,
    input,
    providerName,
    model,
  });
  const updated = await query(
    `UPDATE relationship_explanation_generations
     SET status = ?, explanation_text = ?, error_code = ?,
         completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
     WHERE generation_id = ? AND requester_user_id = ?`,
    [
      attempt.status,
      attempt.text,
      attempt.errorCode,
      inserted.rows.insertId,
      userId,
    ],
  );
  void updated;
  const generation = await query(
    `SELECT generation_id, status, provider, model, prompt_version,
            context_version, explanation_text, error_code, created_at, completed_at
     FROM relationship_explanation_generations
     WHERE generation_id = ? AND requester_user_id = ?
     LIMIT 1`,
    [inserted.rows.insertId, userId],
  );
  return generation.rows[0] ?? null;
};

const coupleAssessmentCodes = new Set([
  'conflict_repair',
  'togetherness_personal_time',
  'affection_alignment',
]);

const relationshipCouplePattern = (dimensions) => {
  const lowestAlignment = dimensions.reduce(
    (lowest, dimension) => Math.min(lowest, dimension.alignmentScore),
    100,
  );
  if (lowestAlignment >= 85) {
    return {
      key: 'shared_rhythm',
      text: '두 사람의 관계 감각이 비슷한 편이라, 서로의 강점을 확인하며 이어가기 좋아요.',
    };
  }
  if (lowestAlignment >= 70) {
    return {
      key: 'different_but_coordination_possible',
      text: '두 사람의 감각에 차이가 있지만, 차이를 설명하고 조율할 여지가 보여요.',
    };
  }
  return {
    key: 'coordination_needed',
    text: '차이가 크게 느껴지는 영역부터 각자의 필요를 말로 확인하는 연습이 도움이 될 수 있어요.',
  };
};

const relationshipConversationPrompts = (assessmentCode) => {
  if (assessmentCode === 'togetherness_personal_time') {
    return [
      '최근 함께하는 시간과 개인 시간이 엇갈렸던 장면에서 서로 무엇을 기대했는지 말해보세요.',
      '각자에게 필요한 함께 있음과 개인 시간을 미리 확인하려면 어떤 약속이 편할까요?',
      '시간의 양보다 두 사람이 만족했다고 느끼는 방식을 어떻게 만들 수 있을까요?',
    ];
  }
  if (assessmentCode === 'affection_alignment') {
    return [
      '내가 사랑받는다고 느끼는 구체적인 행동을 서로 한 가지씩 설명해보세요.',
      '상대의 표현을 내 방식과 다르게 번역해서 이해할 수 있는 장면은 무엇일까요?',
      '부족함을 비난 대신 부탁으로 바꾸면 어떤 말이 될까요?',
    ];
  }
  return [
    '갈등이 커지기 전에 서로 알아차릴 수 있는 신호는 무엇인가요?',
    '회복을 시작할 때 상대가 해주면 도움이 되는 행동은 무엇인가요?',
    '안전하게 대화하기 위해 잠시 멈추거나 다시 시작하는 약속을 정해보세요.',
  ];
};

const buildRelationshipCoupleResult = ({ assessmentCode, version, first, second }) => {
  const secondByKey = new Map(
    (second.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const dimensions = (first.dimensions ?? []).flatMap((dimension) => {
    const counterpart = secondByKey.get(dimension.key);
    if (!counterpart) return [];
    const firstScore = Number(dimension.score);
    const secondScore = Number(counterpart.score);
    const alignmentScore = 100 - Math.abs(firstScore - secondScore);
    return [{
      key: dimension.key,
      title: dimension.title,
      pairScore: Math.round((firstScore + secondScore) / 2),
      alignmentScore,
    }];
  });
  const overallScore = dimensions.length === 0
    ? 0
    : Math.round(
      dimensions.reduce((total, dimension) => total + dimension.pairScore, 0)
        / dimensions.length,
    );
  const overallAlignmentScore = dimensions.length === 0
    ? 0
    : Math.round(
      dimensions.reduce((total, dimension) => total + dimension.alignmentScore, 0)
        / dimensions.length,
    );
  const pattern = relationshipCouplePattern(dimensions);
  return {
    assessmentCode,
    version,
    dimensions,
    overallScore,
    overallAlignmentScore,
    relationshipPatternKey: pattern.key,
    relationshipPattern: pattern.text,
    conversationPrompts: relationshipConversationPrompts(assessmentCode),
    disclaimer: '두 사람의 응답 조합을 관계 대화의 참고 정보로 정리한 결과이며, 의료적 진단이나 우열을 의미하지 않아요.',
  };
};

const getCompletedCoupleAssessmentState = async (coupleId, versionId, assessment) => {
  const coupleResult = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE CoupleId = ? AND Status = 'active'
     LIMIT 1`,
    [coupleId],
  );
  const couple = coupleResult.rows[0];
  if (!couple) {
    return {
      status: 'pending',
      completedMemberCount: 0,
      requiredMemberCount: 2,
      result: null,
    };
  }

  const completedResult = await query(
    `SELECT a.attempt_id, a.user_id, r.result_json
     FROM relationship_assessment_attempts a
     JOIN relationship_assessment_results r ON r.attempt_id = a.attempt_id
     WHERE a.couple_id = ? AND a.version_id = ? AND a.status = 'completed'
       AND a.user_id IN (?, ?)
     ORDER BY a.user_id, a.attempt_id DESC`,
    [coupleId, versionId, couple.User1Id, couple.User2Id],
  );
  const latestByUser = new Map();
  for (const row of completedResult.rows) {
    const userId = Number(row.user_id);
    if (!latestByUser.has(userId)) latestByUser.set(userId, row);
  }
  const first = latestByUser.get(Number(couple.User1Id));
  const second = latestByUser.get(Number(couple.User2Id));
  const completedMemberCount = [first, second].filter(Boolean).length;
  if (!first || !second) {
    return {
      status: 'pending',
      completedMemberCount,
      requiredMemberCount: 2,
      result: null,
    };
  }

  const firstResult = parseRelationshipResult(first.result_json);
  const secondResult = parseRelationshipResult(second.result_json);
  const sharedResult = buildRelationshipCoupleResult({
    assessmentCode: assessment.code,
    version: assessment.version_label,
    first: firstResult,
    second: secondResult,
  });
  await query(
    `INSERT IGNORE INTO relationship_couple_assessment_results
       (couple_id, version_id, user1_attempt_id, user2_attempt_id, result_json)
     VALUES (?, ?, ?, ?, ?)`,
    [
      coupleId,
      versionId,
      first.attempt_id,
      second.attempt_id,
      JSON.stringify(sharedResult),
    ],
  );
  const storedResult = await query(
    `SELECT result_json
     FROM relationship_couple_assessment_results
     WHERE couple_id = ? AND version_id = ?
       AND user1_attempt_id = ? AND user2_attempt_id = ?
     LIMIT 1`,
    [coupleId, versionId, first.attempt_id, second.attempt_id],
  );
  return {
    status: 'ready',
    completedMemberCount: 2,
    requiredMemberCount: 2,
    result: parseRelationshipResult(storedResult.rows[0]?.result_json) ?? sharedResult,
  };
};

const getSharedCoupleAssessmentState = async (userId, code) => {
  const assessment = await getActiveRelationshipAssessment(code);
  if (!assessment) return { error: { status: 404, reason: 'assessment_not_found' } };
  if (assessment.audience !== 'couple' || !coupleAssessmentCodes.has(assessment.code)) {
    return { error: { status: 400, reason: 'assessment_not_couple' } };
  }
  const coupleId = await getCoupleIdForUser(userId);
  if (coupleId == null) return { error: { status: 409, reason: 'active_couple_required' } };
  return {
    assessment,
    coupleId,
    state: await getCompletedCoupleAssessmentState(coupleId, assessment.version_id, assessment),
  };
};

const buildAttachmentConflictCompatibility = ({ attachmentOne, attachmentTwo, conflict }) => {
  const firstByKey = new Map(
    (attachmentOne.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const secondByKey = new Map(
    (attachmentTwo.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const dimensions = [
    ['reassurance_gap', '안정감 확인 차이', 'reassurance'],
    ['distance_gap', '거리와 자율성 차이', 'distance'],
    ['expression_gap', '감정 표현 차이', 'expression'],
  ].flatMap(([key, title, sourceKey]) => {
    const first = firstByKey.get(sourceKey);
    const second = secondByKey.get(sourceKey);
    if (!first || !second) return [];
    return [{
      key,
      title,
      scoreDifference: Math.abs(Number(first.score) - Number(second.score)),
    }];
  });
  const reassuranceGap = dimensions.find((dimension) => dimension.key === 'reassurance_gap')?.scoreDifference ?? 0;
  const distanceGap = dimensions.find((dimension) => dimension.key === 'distance_gap')?.scoreDifference ?? 0;
  const safetyAlignment = conflict.dimensions
    ?.find((dimension) => dimension.key === 'safety')?.alignmentScore ?? 100;
  let complementaryPattern;
  let cautionInteractions;
  if (reassuranceGap >= 30 && safetyAlignment < 70) {
    complementaryPattern = {
      key: 'reassurance_and_repair_tension',
      text: '안정감을 확인하는 방식의 차이가 갈등 뒤 회복 속도와 맞물릴 수 있어요.',
    };
    cautionInteractions = [
      '한 사람은 확인을 원하고 다른 사람은 압박으로 느끼는 순간을 구분해보세요.',
      '답을 재촉하거나 대화를 닫기 전에 필요한 시간을 구체적으로 알려주세요.',
    ];
  } else if (distanceGap >= 30) {
    complementaryPattern = {
      key: 'space_and_closeness_translation',
      text: '가까이 있음과 거리를 두는 방식이 달라 서로의 신호를 번역하는 과정이 중요해요.',
    };
    cautionInteractions = [
      '개인 시간이 곧 관계 거절은 아니라는 점을 서로의 말로 확인해보세요.',
      '다시 대화할 시점을 정하면 거리 두기가 단절로 느껴지는 일을 줄일 수 있어요.',
    ];
  } else {
    complementaryPattern = {
      key: 'shared_attachment_language',
      text: '애착 신호를 이해하는 방식이 비교적 가까워 서로의 의도를 확인하기 좋아요.',
    };
    cautionInteractions = [
      '잘 맞는다고 느끼는 영역도 상황이 달라지면 달라질 수 있음을 기억해보세요.',
      '서로에게 도움이 되었던 안정감 표현을 한 가지씩 구체화해보세요.',
    ];
  }
  return {
    analysisCode: 'attachment_conflict',
    analysisVersion: 'v1',
    dimensions,
    complementaryPatternKey: complementaryPattern.key,
    complementaryPattern: complementaryPattern.text,
    cautionInteractions,
    conversationPrompts: [
      '갈등이 생겼을 때 내가 안정감을 느끼기 위해 필요한 것을 한 문장으로 말해보세요.',
      '상대가 잠시 거리를 원할 때 관계를 지키면서 기다리는 방법은 무엇일까요?',
      '다음 갈등에서 회복을 시작할 수 있는 신호를 하나 정해보세요.',
    ],
    conflictPatternKey: conflict.relationshipPatternKey ?? null,
    disclaimer: '두 사람의 개인검사 요약과 커플검사 결과를 조합한 관계 대화용 참고 정보이며, 누구의 잘못이나 의료적 진단을 의미하지 않아요.',
  };
};

const buildConflictRepairCompatibility = ({ attachmentOne, attachmentTwo, conflict }) => {
  const attachmentOneReassurance = attachmentOne.dimensions
    ?.find((dimension) => dimension.key === 'reassurance')?.score ?? 0;
  const attachmentTwoReassurance = attachmentTwo.dimensions
    ?.find((dimension) => dimension.key === 'reassurance')?.score ?? 0;
  const reassuranceGap = Math.abs(attachmentOneReassurance - attachmentTwoReassurance);
  const conflictByKey = new Map(
    (conflict.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const dimensions = [
    ['conflict_trigger', '갈등 촉발 신호', 'conflict_signal'],
    ['repair_approach', '회복 접근', 'repair_action'],
    ['dialogue_start', '대화 시작점', 'safety'],
  ].flatMap(([key, title, sourceKey]) => {
    const dimension = conflictByKey.get(sourceKey);
    if (!dimension) return [];
    return [{
      key,
      title,
      scoreDifference: Math.max(0, 100 - Number(dimension.alignmentScore ?? 0)),
    }];
  });
  const triggerScore = conflictByKey.get('conflict_signal')?.pairScore ?? 0;
  const repairScore = conflictByKey.get('repair_action')?.pairScore ?? 0;
  const safetyScore = conflictByKey.get('safety')?.pairScore ?? 0;
  return {
    analysisCode: 'conflict_repair',
    analysisVersion: 'v1',
    dimensions,
    complementaryPatternKey: reassuranceGap >= 30
      ? 'attachment_difference_needs_translation'
      : repairScore >= 60
      ? 'repair_can_be_practiced'
      : 'repair_needs_a_clear_start',
    complementaryPattern: reassuranceGap >= 30
      ? '안정감을 확인하는 방식의 차이를 갈등 뒤 회복 행동과 함께 번역해보는 것이 중요해요.'
      : repairScore >= 60
      ? '갈등 뒤 다시 연결되는 행동을 두 사람이 함께 연습할 여지가 보여요.'
      : '회복을 시작하는 행동을 작고 구체적인 약속으로 정해보는 것이 도움이 될 수 있어요.',
    conflictTrigger: triggerScore >= 60
      ? '갈등 신호가 커졌을 때 각자의 반응을 먼저 알아차리는 것이 중요해요.'
      : '갈등 신호가 작을 때도 불편함을 일찍 말해보는 것이 도움이 될 수 있어요.',
    repairApproach: repairScore >= 60
      ? '잠시 멈춘 뒤 다시 대화할 시점과 방법을 미리 정해두세요.'
      : '사과, 설명, 휴식 중 어떤 회복 행동이 필요한지 구체적으로 요청해보세요.',
    cautionInteractions: [
      safetyScore < 60
        ? '대화 안전감이 낮게 느껴지는 순간에는 결론보다 대화 환경을 먼저 돌봐주세요.'
        : '안전하다고 느끼는 방식도 갈등 상황에서는 달라질 수 있어 서로 확인해주세요.',
      '누가 더 옳은지보다 갈등이 시작되고 회복되는 순서를 함께 살펴보세요.',
    ],
    conversationPrompts: [
      '우리 사이에서 갈등이 시작되었다고 느끼는 첫 신호는 무엇인가요?',
      '회복을 시작할 때 상대가 해주면 도움이 되는 행동을 한 가지씩 말해보세요.',
      '대화를 다시 시작하기 위한 시간과 첫 문장을 미리 정해볼까요?',
    ],
    conflictPatternKey: conflict.relationshipPatternKey ?? null,
    disclaimer: '두 사람의 개인검사 요약과 커플검사 결과를 조합한 관계 대화용 참고 정보이며, 누구의 잘못이나 의료적 진단을 의미하지 않아요.',
  };
};

const getAttachmentConflictCompatibilityState = async (userId) => {
  const attachment = await getActiveRelationshipAssessment('attachment');
  const conflict = await getActiveRelationshipAssessment('conflict_repair');
  const coupleId = await getCoupleIdForUser(userId);
  if (coupleId == null) return { error: { status: 409, reason: 'active_couple_required' } };
  const coupleResult = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE CoupleId = ? AND Status = 'active'
     LIMIT 1`,
    [coupleId],
  );
  const couple = coupleResult.rows[0];
  if (!couple || !attachment || !conflict) {
    return { error: { status: 404, reason: 'compatibility_not_available' } };
  }

  const attachmentResult = await query(
    `SELECT r.result_id, r.user_id, r.result_json
     FROM relationship_assessment_results r
     JOIN relationship_assessment_attempts a ON a.attempt_id = r.attempt_id
     WHERE r.version_id = ? AND a.status = 'completed'
       AND r.user_id IN (?, ?)
     ORDER BY r.user_id, r.result_id DESC`,
    [attachment.version_id, couple.User1Id, couple.User2Id],
  );
  const attachmentByUser = new Map();
  for (const row of attachmentResult.rows) {
    if (!attachmentByUser.has(Number(row.user_id))) attachmentByUser.set(Number(row.user_id), row);
  }
  const conflictState = await getCompletedCoupleAssessmentState(
    coupleId,
    conflict.version_id,
    conflict,
  );
  const dependencyStatus = {
    attachment: attachmentByUser.size,
    conflictRepair: conflictState.completedMemberCount,
  };
  const firstAttachment = attachmentByUser.get(Number(couple.User1Id));
  const secondAttachment = attachmentByUser.get(Number(couple.User2Id));
  if (!firstAttachment || !secondAttachment || conflictState.status !== 'ready') {
    return {
      status: 'pending',
      dependencyStatus,
      result: null,
    };
  }
  const conflictResultRow = await query(
    `SELECT couple_result_id, result_json
     FROM relationship_couple_assessment_results
     WHERE couple_id = ? AND version_id = ?
     ORDER BY couple_result_id DESC
     LIMIT 1`,
    [coupleId, conflict.version_id],
  );
  const conflictResult = parseRelationshipResult(conflictResultRow.rows[0]?.result_json)
    ?? conflictState.result;
  const result = buildAttachmentConflictCompatibility({
    attachmentOne: parseRelationshipResult(firstAttachment.result_json),
    attachmentTwo: parseRelationshipResult(secondAttachment.result_json),
    conflict: conflictResult,
  });
  await query(
    `INSERT IGNORE INTO relationship_compatibility_analyses
       (couple_id, analysis_code, analysis_version,
        user1_attachment_result_id, user2_attachment_result_id,
        conflict_couple_result_id, result_json)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      coupleId,
      result.analysisCode,
      result.analysisVersion,
      firstAttachment.result_id,
      secondAttachment.result_id,
      conflictResultRow.rows[0]?.couple_result_id,
      JSON.stringify(result),
    ],
  );
  const stored = await query(
    `SELECT result_json
     FROM relationship_compatibility_analyses
     WHERE couple_id = ? AND analysis_code = ? AND analysis_version = ?
       AND user1_attachment_result_id = ? AND user2_attachment_result_id = ?
       AND conflict_couple_result_id = ?
     LIMIT 1`,
    [
      coupleId,
      result.analysisCode,
      result.analysisVersion,
      firstAttachment.result_id,
      secondAttachment.result_id,
      conflictResultRow.rows[0]?.couple_result_id,
    ],
  );
  return {
    status: 'ready',
    dependencyStatus,
    result: parseRelationshipResult(stored.rows[0]?.result_json) ?? result,
  };
};

const getConflictRepairCompatibilityState = async (userId) => {
  const attachment = await getActiveRelationshipAssessment('attachment');
  const conflict = await getActiveRelationshipAssessment('conflict_repair');
  const coupleId = await getCoupleIdForUser(userId);
  if (coupleId == null) return { error: { status: 409, reason: 'active_couple_required' } };
  const coupleResult = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE CoupleId = ? AND Status = 'active'
     LIMIT 1`,
    [coupleId],
  );
  const couple = coupleResult.rows[0];
  if (!couple || !attachment || !conflict) {
    return { error: { status: 404, reason: 'compatibility_not_available' } };
  }
  const attachmentResult = await query(
    `SELECT r.result_id, r.user_id, r.result_json
     FROM relationship_assessment_results r
     JOIN relationship_assessment_attempts a ON a.attempt_id = r.attempt_id
     WHERE r.version_id = ? AND a.status = 'completed'
       AND r.user_id IN (?, ?)
     ORDER BY r.user_id, r.result_id DESC`,
    [attachment.version_id, couple.User1Id, couple.User2Id],
  );
  const attachmentByUser = new Map();
  for (const row of attachmentResult.rows) {
    if (!attachmentByUser.has(Number(row.user_id))) attachmentByUser.set(Number(row.user_id), row);
  }
  const conflictState = await getCompletedCoupleAssessmentState(
    coupleId,
    conflict.version_id,
    conflict,
  );
  const dependencyStatus = {
    attachment: attachmentByUser.size,
    conflictRepair: conflictState.completedMemberCount,
  };
  const firstAttachment = attachmentByUser.get(Number(couple.User1Id));
  const secondAttachment = attachmentByUser.get(Number(couple.User2Id));
  if (!firstAttachment || !secondAttachment || conflictState.status !== 'ready') {
    return {
      status: 'pending',
      dependencyStatus,
      result: null,
    };
  }
  const conflictResultRow = await query(
    `SELECT couple_result_id, result_json
     FROM relationship_couple_assessment_results
     WHERE couple_id = ? AND version_id = ?
     ORDER BY couple_result_id DESC
     LIMIT 1`,
    [coupleId, conflict.version_id],
  );
  const conflictResult = parseRelationshipResult(conflictResultRow.rows[0]?.result_json)
    ?? conflictState.result;
  const result = buildConflictRepairCompatibility({
    attachmentOne: parseRelationshipResult(firstAttachment.result_json),
    attachmentTwo: parseRelationshipResult(secondAttachment.result_json),
    conflict: conflictResult,
  });
  const conflictResultId = conflictResultRow.rows[0]?.couple_result_id;
  if (conflictResultId == null) {
    return { error: { status: 500, reason: 'compatibility_source_missing' } };
  }
  await query(
    `INSERT IGNORE INTO relationship_compatibility_analyses
       (couple_id, analysis_code, analysis_version,
        user1_attachment_result_id, user2_attachment_result_id,
        conflict_couple_result_id, result_json)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      coupleId,
      result.analysisCode,
      result.analysisVersion,
      firstAttachment.result_id,
      secondAttachment.result_id,
      conflictResultId,
      JSON.stringify(result),
    ],
  );
  const stored = await query(
    `SELECT result_json
     FROM relationship_compatibility_analyses
     WHERE couple_id = ? AND analysis_code = ? AND analysis_version = ?
       AND user1_attachment_result_id = ? AND user2_attachment_result_id = ?
       AND conflict_couple_result_id = ?
     LIMIT 1`,
    [
      coupleId,
      result.analysisCode,
      result.analysisVersion,
      firstAttachment.result_id,
      secondAttachment.result_id,
      conflictResultId,
    ],
  );
  return {
    status: 'ready',
    dependencyStatus,
    result: parseRelationshipResult(stored.rows[0]?.result_json) ?? result,
  };
};

const personalCompatibilityDefinitions = new Map([
  ['social-bonding', {
    assessmentCode: 'social_bonding',
    dimensions: [
      ['depth_gap', '관계의 깊이 차이', 'depth'],
      ['dependence_gap', '의존과 균형 차이', 'dependence'],
      ['isolation_gap', '고립감 인식 차이', 'isolation'],
    ],
    pattern: '사회적 연결을 넓히는 속도와 기대를 서로의 언어로 확인해보는 것이 도움이 될 수 있어요.',
    prompts: [
      '각자에게 깊은 관계라고 느껴지는 신호는 무엇인가요?',
      '파트너 한 사람에게 기대가 몰릴 때 활용할 수 있는 다른 자원은 무엇일까요?',
      '외로움과 혼자 있는 시간을 구분하기 위해 어떤 신호를 살펴볼까요?',
    ],
  }],
  ['emotional-regulation', {
    assessmentCode: 'emotional_regulation',
    dimensions: [
      ['internal_gap', '내부 처리 차이', 'internal'],
      ['stimulation_gap', '외부 자극 차이', 'stimulation'],
      ['dialogue_gap', '대화 선호 차이', 'dialogue'],
    ],
    pattern: '감정을 정리하고 회복하는 순서가 다를 수 있어, 서로에게 필요한 도움의 형태를 확인해보세요.',
    prompts: [
      '감정이 생겼을 때 먼저 혼자 정리할 시간과 대화할 시점을 어떻게 알릴까요?',
      '기분 전환을 위해 각자 도움이 되는 활동은 무엇인가요?',
      '해결책보다 공감이 필요한 순간을 어떤 말로 알려줄 수 있을까요?',
    ],
  }],
  ['relationship-deficiency', {
    assessmentCode: 'relationship_deficiency',
    dimensions: [
      ['self_awareness_gap', '자기 인식 차이', 'self_awareness'],
      ['partner_expectation_gap', '파트너 기대 차이', 'partner_expectation'],
      ['alternative_resources_gap', '대안 자원 인식 차이', 'alternative_resources'],
    ],
    pattern: '관계에서 느끼는 필요를 한 사람의 책임으로 돌리기보다, 함께 이름 붙이고 자원을 넓혀보는 것이 좋아요.',
    prompts: [
      '지금 관계에서 가장 먼저 이름 붙이고 싶은 필요는 무엇인가요?',
      '파트너에게 바라는 것과 내가 직접 돌볼 수 있는 것을 어떻게 나눌까요?',
      '관계 밖에서 나를 지지하는 자원을 하나씩 찾아볼 수 있을까요?',
    ],
  }],
]);

const buildPersonalCompatibilityResult = (code, first, second) => {
  const definition = personalCompatibilityDefinitions.get(code);
  const firstByKey = new Map(
    (first.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const secondByKey = new Map(
    (second.dimensions ?? []).map((dimension) => [dimension.key, dimension]),
  );
  const dimensions = definition.dimensions.flatMap(([key, title, sourceKey]) => {
    const firstDimension = firstByKey.get(sourceKey);
    const secondDimension = secondByKey.get(sourceKey);
    if (!firstDimension || !secondDimension) return [];
    return [{
      key,
      title,
      scoreDifference: Math.abs(
        Number(firstDimension.score) - Number(secondDimension.score),
      ),
    }];
  });
  const maxDifference = dimensions.reduce(
    (max, dimension) => Math.max(max, dimension.scoreDifference),
    0,
  );
  return {
    analysisCode: `${code}_compatibility`,
    analysisVersion: 'v1',
    dimensions,
    complementaryPatternKey: maxDifference >= 30 ? 'needs_translation' : 'shared_context',
    complementaryPattern: definition.pattern,
    cautionInteractions: [
      '차이가 큰 영역을 누가 맞는지의 증거로 사용하지 말고 서로의 필요를 설명하는 출발점으로 삼아보세요.',
    ],
    conversationPrompts: definition.prompts,
    conflictPatternKey: null,
    disclaimer: '두 사람의 개인검사 요약을 조합한 관계 대화용 참고 정보이며, 의료적 진단이나 우열을 의미하지 않아요.',
  };
};

const getPersonalCompatibilityState = async (userId, code) => {
  const definition = personalCompatibilityDefinitions.get(code);
  if (!definition) return { error: { status: 404, reason: 'compatibility_not_found' } };
  const assessment = await getActiveRelationshipAssessment(definition.assessmentCode);
  const coupleId = await getCoupleIdForUser(userId);
  if (coupleId == null) return { error: { status: 409, reason: 'active_couple_required' } };
  const coupleResult = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE CoupleId = ? AND Status = 'active'
     LIMIT 1`,
    [coupleId],
  );
  const couple = coupleResult.rows[0];
  if (!couple || !assessment) {
    return { error: { status: 404, reason: 'compatibility_not_available' } };
  }
  const resultRows = await query(
    `SELECT r.result_id, r.user_id, r.result_json
     FROM relationship_assessment_results r
     JOIN relationship_assessment_attempts a ON a.attempt_id = r.attempt_id
     WHERE r.version_id = ? AND a.status = 'completed'
       AND r.user_id IN (?, ?)
     ORDER BY r.user_id, r.result_id DESC`,
    [assessment.version_id, couple.User1Id, couple.User2Id],
  );
  const resultByUser = new Map();
  for (const row of resultRows.rows) {
    if (!resultByUser.has(Number(row.user_id))) resultByUser.set(Number(row.user_id), row);
  }
  const first = resultByUser.get(Number(couple.User1Id));
  const second = resultByUser.get(Number(couple.User2Id));
  const dependencyStatus = { [definition.assessmentCode]: resultByUser.size };
  if (!first || !second) {
    return { status: 'pending', dependencyStatus, result: null };
  }
  const result = buildPersonalCompatibilityResult(
    code,
    parseRelationshipResult(first.result_json),
    parseRelationshipResult(second.result_json),
  );
  await query(
    `INSERT IGNORE INTO relationship_personal_compatibility_analyses
       (couple_id, analysis_code, analysis_version,
        user1_result_id, user2_result_id, result_json)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [
      coupleId,
      result.analysisCode,
      result.analysisVersion,
      first.result_id,
      second.result_id,
      JSON.stringify(result),
    ],
  );
  const stored = await query(
    `SELECT result_json
     FROM relationship_personal_compatibility_analyses
     WHERE couple_id = ? AND analysis_code = ? AND analysis_version = ?
       AND user1_result_id = ? AND user2_result_id = ?
     LIMIT 1`,
    [coupleId, result.analysisCode, result.analysisVersion, first.result_id, second.result_id],
  );
  return {
    status: 'ready',
    dependencyStatus,
    result: parseRelationshipResult(stored.rows[0]?.result_json) ?? result,
  };
};

const coupleCompatibilityDefinitions = new Map([
  ['togetherness-personal-time', {
    assessmentCode: 'togetherness_personal_time',
    pattern: '함께 있음과 개인 시간을 조율하는 방식의 차이를 서로의 생활 리듬으로 이해해보세요.',
    caution: '함께 있는 시간의 양을 사랑의 크기로 바로 해석하지 않도록 서로의 필요를 확인해보세요.',
  }],
  ['affection-alignment', {
    assessmentCode: 'affection_alignment',
    pattern: '애정을 표현하고 기대하는 방식의 차이를 번역하면 서로의 노력이 더 잘 보일 수 있어요.',
    caution: '표현의 빈도나 방식만으로 사랑의 크기를 단정하지 말고 구체적인 부탁으로 바꿔보세요.',
  }],
]);

const buildCoupleCompatibilityResult = (code, sharedResult) => {
  const definition = coupleCompatibilityDefinitions.get(code);
  return {
    analysisCode: `${code}_compatibility`,
    analysisVersion: 'v1',
    dimensions: (sharedResult.dimensions ?? []).map((dimension) => ({
      key: dimension.key,
      title: dimension.title,
      scoreDifference: Math.max(0, 100 - Number(dimension.alignmentScore ?? 0)),
    })),
    complementaryPatternKey: sharedResult.relationshipPatternKey ?? 'coordination_needed',
    complementaryPattern: definition.pattern,
    cautionInteractions: [definition.caution],
    conversationPrompts: sharedResult.conversationPrompts ?? [],
    conflictPatternKey: null,
    disclaimer: '두 사람의 커플검사 shared result를 관계 대화용으로 다시 정리한 참고 정보이며, 의료적 진단이나 우열을 의미하지 않아요.',
  };
};

const getCoupleCompatibilityState = async (userId, code) => {
  const definition = coupleCompatibilityDefinitions.get(code);
  if (!definition) return { error: { status: 404, reason: 'compatibility_not_found' } };
  const assessment = await getActiveRelationshipAssessment(definition.assessmentCode);
  const coupleId = await getCoupleIdForUser(userId);
  if (coupleId == null) return { error: { status: 409, reason: 'active_couple_required' } };
  if (!assessment) return { error: { status: 404, reason: 'compatibility_not_available' } };
  const sharedState = await getCompletedCoupleAssessmentState(
    coupleId,
    assessment.version_id,
    assessment,
  );
  const dependencyStatus = {
    [definition.assessmentCode]: sharedState.completedMemberCount,
  };
  if (sharedState.status !== 'ready') {
    return { status: 'pending', dependencyStatus, result: null };
  }
  const source = await query(
    `SELECT couple_result_id, result_json
     FROM relationship_couple_assessment_results
     WHERE couple_id = ? AND version_id = ?
     ORDER BY couple_result_id DESC
     LIMIT 1`,
    [coupleId, assessment.version_id],
  );
  const sourceRow = source.rows[0];
  if (!sourceRow) return { error: { status: 500, reason: 'compatibility_source_missing' } };
  const result = buildCoupleCompatibilityResult(
    code,
    parseRelationshipResult(sourceRow.result_json) ?? sharedState.result,
  );
  await query(
    `INSERT IGNORE INTO relationship_couple_compatibility_analyses
       (couple_id, analysis_code, analysis_version, source_couple_result_id, result_json)
     VALUES (?, ?, ?, ?, ?)`,
    [coupleId, result.analysisCode, result.analysisVersion, sourceRow.couple_result_id, JSON.stringify(result)],
  );
  const stored = await query(
    `SELECT result_json
     FROM relationship_couple_compatibility_analyses
     WHERE couple_id = ? AND analysis_code = ? AND analysis_version = ?
       AND source_couple_result_id = ?
     LIMIT 1`,
    [coupleId, result.analysisCode, result.analysisVersion, sourceRow.couple_result_id],
  );
  return {
    status: 'ready',
    dependencyStatus,
    result: parseRelationshipResult(stored.rows[0]?.result_json) ?? result,
  };
};

const compatibilityDashboardDefinitions = [
  {
    code: 'attachment-conflict',
    title: '애착과 갈등의 상호작용',
    description: '애착 요약과 갈등·회복 결과를 함께 살펴봅니다.',
  },
  {
    code: 'conflict-repair',
    title: '갈등과 회복 궁합',
    description: '갈등 촉발과 회복 접근의 조합을 살펴봅니다.',
  },
  {
    code: 'social-bonding',
    title: '사회적 유대 궁합',
    description: '두 사람의 연결 깊이와 관계 자원을 비교합니다.',
  },
  {
    code: 'emotional-regulation',
    title: '감정 해소 궁합',
    description: '감정을 처리하고 회복하는 방식의 차이를 살펴봅니다.',
  },
  {
    code: 'relationship-deficiency',
    title: '관계 결핍 인식 궁합',
    description: '관계의 필요와 대안 자원을 함께 이름 붙입니다.',
  },
  {
    code: 'togetherness-personal-time',
    title: '함께 있음과 개인 시간 궁합',
    description: '함께 보내는 시간과 자율성의 조율을 살펴봅니다.',
  },
  {
    code: 'affection-alignment',
    title: '애정 표현과 기대 궁합',
    description: '표현 방식과 기대를 서로의 언어로 번역합니다.',
  },
];

const getCompatibilityState = async (userId, code) => {
  if (code === 'attachment-conflict') return getAttachmentConflictCompatibilityState(userId);
  if (code === 'conflict-repair') return getConflictRepairCompatibilityState(userId);
  if (personalCompatibilityDefinitions.has(code)) {
    return getPersonalCompatibilityState(userId, code);
  }
  return getCoupleCompatibilityState(userId, code);
};

const compatibilityCodes = new Set([
  'attachment-conflict',
  'conflict-repair',
  ...personalCompatibilityDefinitions.keys(),
  ...coupleCompatibilityDefinitions.keys(),
]);

const compatibilityExplanationSourceKey = (code, result) => {
  const digest = createHash('sha256')
    .update(JSON.stringify(result))
    .digest('hex');
  return `compatibility:${code}:${digest}`;
};

const buildCompatibilityExplanationInput = (code, result) => ({
  sourceType: 'compatibility',
  analysisCode: result.analysisCode ?? `${code}_compatibility`,
  version: result.analysisVersion ?? 'v1',
  dimensions: (result.dimensions ?? []).map((dimension) => ({
    key: dimension.key,
    title: dimension.title,
    scoreDifference: dimension.scoreDifference,
  })),
  patternKey: result.complementaryPatternKey ?? null,
  metadata: { locale: 'ko-KR', nonClinical: true },
});

const runCompatibilityExplanationGeneration = async (
  userId,
  coupleId,
  code,
  result,
) => {
  const input = buildCompatibilityExplanationInput(code, result);
  const sourceKey = compatibilityExplanationSourceKey(code, result);
  const provider = createExplanationProvider(config);
  const providerName = provider?.name ?? 'disabled';
  const model = provider?.model ?? null;
  const inserted = await query(
    `INSERT INTO relationship_explanation_generations
       (requester_user_id, couple_id, scope_type, source_key, status, provider, model,
        prompt_version, context_version, input_json)
     VALUES (?, ?, 'compatibility', ?, 'pending', ?, ?, ?, ?, ?)`,
    [
      userId,
      coupleId,
      sourceKey,
      providerName,
      model,
      config.LLM_PROMPT_VERSION,
      config.LLM_CONTEXT_VERSION,
      JSON.stringify(input),
    ],
  );
  const attempt = await createExplanationAttempt({
    provider,
    input,
    providerName,
    model,
  });
  await query(
    `UPDATE relationship_explanation_generations
     SET status = ?, explanation_text = ?, error_code = ?,
         completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
     WHERE generation_id = ? AND couple_id = ?`,
    [attempt.status, attempt.text, attempt.errorCode, inserted.rows.insertId, coupleId],
  );
  const generation = await query(
    `SELECT generation_id, status, provider, model, prompt_version,
            context_version, explanation_text, error_code, created_at, completed_at
     FROM relationship_explanation_generations
     WHERE generation_id = ? AND couple_id = ?
     LIMIT 1`,
    [inserted.rows.insertId, coupleId],
  );
  return {
    row: generation.rows[0] ?? null,
    sourceKey,
  };
};

router.get('/relationship/compatibility/current', async (req, res) => {
  try {
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const cards = await Promise.all(
      compatibilityDashboardDefinitions.map(async (definition) => {
        const state = await getCompatibilityState(req.auth.userId, definition.code);
        if (state.error) {
          return {
            ...definition,
            status: 'unavailable',
            dependencyStatus: {},
            result: null,
          };
        }
        return { ...definition, ...state };
      }),
    );
    return res.json({ ok: true, cards });
  } catch (error) {
    console.error('[API] /relationship/compatibility/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/compatibility/:code/current', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    if (![
      'attachment-conflict',
      'conflict-repair',
      ...personalCompatibilityDefinitions.keys(),
      ...coupleCompatibilityDefinitions.keys(),
    ].includes(code)) {
      return res.status(404).json({ ok: false, reason: 'compatibility_not_found' });
    }
    const state = code === 'attachment-conflict'
      ? await getAttachmentConflictCompatibilityState(req.auth.userId)
      : code === 'conflict-repair'
      ? await getConflictRepairCompatibilityState(req.auth.userId)
      : personalCompatibilityDefinitions.has(code)
      ? await getPersonalCompatibilityState(req.auth.userId, code)
      : await getCoupleCompatibilityState(req.auth.userId, code);
    if (state.error) {
      return res.status(state.error.status).json({ ok: false, reason: state.error.reason });
    }
    return res.json({ ok: true, ...state });
  } catch (error) {
    console.error('[API] /relationship/compatibility/:code/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/explanations/compatibility/:code/current', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    if (!compatibilityCodes.has(code)) {
      return res.status(404).json({ ok: false, reason: 'compatibility_not_found' });
    }
    const state = await getCompatibilityState(req.auth.userId, code);
    if (state.error) {
      return res.status(state.error.status).json({ ok: false, reason: state.error.reason });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    if (!state.result) {
      return res.json({ ok: true, status: 'idle', generation: null });
    }
    const sourceKey = compatibilityExplanationSourceKey(code, state.result);
    const generations = await query(
      `SELECT generation_id, status, provider, model, prompt_version,
              context_version, explanation_text, error_code, created_at, completed_at
       FROM relationship_explanation_generations
       WHERE couple_id = ? AND scope_type = 'compatibility' AND source_key = ?
       ORDER BY generation_id DESC
       LIMIT 1`,
      [coupleId, sourceKey],
    );
    return res.json({
      ok: true,
      status: generations.rows[0]?.status ?? 'idle',
      generation: generations.rows[0]
        ? explanationGenerationPayload(generations.rows[0])
        : null,
    });
  } catch (error) {
    console.error('[API] /relationship/explanations/compatibility/:code/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/explanations/compatibility/:code', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    if (!compatibilityCodes.has(code)) {
      return res.status(404).json({ ok: false, reason: 'compatibility_not_found' });
    }
    const state = await getCompatibilityState(req.auth.userId, code);
    if (state.error) {
      return res.status(state.error.status).json({ ok: false, reason: state.error.reason });
    }
    if (!state.result) {
      return res.status(409).json({ ok: false, reason: 'compatibility_result_required' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const generation = await runCompatibilityExplanationGeneration(
      req.auth.userId,
      coupleId,
      code,
      state.result,
    );
    if (!generation.row) {
      return res.status(500).json({ ok: false, reason: 'explanation_generation_failed' });
    }
    return res.status(201).json({
      ok: true,
      status: generation.row.status,
      generation: explanationGenerationPayload(generation.row),
    });
  } catch (error) {
    console.error('[API] /relationship/explanations/compatibility/:code POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/couple-assessment-attempts/:attemptId/submit', async (req, res) => {
  try {
    const attemptId = Number(req.params.attemptId);
    if (!Number.isSafeInteger(attemptId) || attemptId <= 0) {
      return res.status(400).json({ ok: false, reason: 'invalid_attempt_id' });
    }
    const attemptResult = await query(
      `SELECT a.attempt_id, a.user_id, a.couple_id, a.version_id, a.status,
              v.version_label, v.active_question_count, c.code, c.audience
       FROM relationship_assessment_attempts a
       JOIN relationship_assessment_versions v ON v.version_id = a.version_id
       JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
       WHERE a.attempt_id = ? AND a.user_id = ?
       LIMIT 1`,
      [attemptId, req.auth.userId],
    );
    const attempt = attemptResult.rows[0];
    if (!attempt) return res.status(404).json({ ok: false, reason: 'attempt_not_found' });
    if (attempt.audience !== 'couple' || !coupleAssessmentCodes.has(attempt.code)) {
      return res.status(400).json({ ok: false, reason: 'assessment_not_couple' });
    }
    if (attempt.status !== 'in_progress') {
      return res.status(409).json({ ok: false, reason: 'attempt_not_in_progress' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null || Number(coupleId) !== Number(attempt.couple_id)) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    const answerResult = await query(
      `SELECT q.question_key, q.reverse_scored, d.dimension_key,
              d.display_name, d.sort_order, aa.answer_value
       FROM relationship_assessment_attempt_answers aa
       JOIN relationship_assessment_questions q ON q.question_id = aa.question_id
       JOIN relationship_assessment_dimensions d ON d.dimension_id = q.dimension_id
       WHERE aa.attempt_id = ? AND q.is_active = 1
       ORDER BY q.question_order`,
      [attemptId],
    );
    const totalCount = Number(attempt.active_question_count);
    if (answerResult.rows.length !== totalCount) {
      return res.status(400).json({
        ok: false,
        reason: 'incomplete_attempt',
        progress: {
          answeredCount: answerResult.rows.length,
          totalCount,
          percentage: totalCount === 0
            ? 0
            : Math.round((answerResult.rows.length / totalCount) * 100),
        },
      });
    }

    const dimensions = relationshipDimensionScore(answerResult.rows);
    const participantResult = {
      assessmentCode: attempt.code,
      version: attempt.version_label,
      dimensions,
      overallScore: dimensions.length === 0
        ? 0
        : Math.round(dimensions.reduce((total, dimension) => total + dimension.score, 0) / dimensions.length),
      disclaimer: '커플 공유 결과 계산을 위한 비공개 중간 결과예요.',
    };
    await query(
      `INSERT INTO relationship_assessment_results
         (attempt_id, user_id, version_id, result_json)
       VALUES (?, ?, ?, ?)`,
      [attemptId, req.auth.userId, attempt.version_id, JSON.stringify(participantResult)],
    );
    await query(
      `UPDATE relationship_assessment_attempts
       SET status = 'completed', completed_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE attempt_id = ? AND user_id = ? AND status = 'in_progress'`,
      [attemptId, req.auth.userId],
    );

    const assessment = {
      code: attempt.code,
      audience: attempt.audience,
      version_label: attempt.version_label,
    };
    const state = await getCompletedCoupleAssessmentState(
      coupleId,
      attempt.version_id,
      assessment,
    );
    return res.status(201).json({ ok: true, ...state });
  } catch (error) {
    console.error('[API] /relationship/couple-assessment-attempts/:attemptId/submit error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/couple-assessment-results/:code/current', async (req, res) => {
  try {
    const shared = await getSharedCoupleAssessmentState(
      req.auth.userId,
      String(req.params.code ?? '').trim(),
    );
    if (shared.error) {
      return res.status(shared.error.status).json({ ok: false, reason: shared.error.reason });
    }
    return res.json({ ok: true, ...shared.state });
  } catch (error) {
    console.error('[API] /relationship/couple-assessment-results/:code/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/assessment-attempts/:attemptId/submit', async (req, res) => {
  try {
    const attemptId = Number(req.params.attemptId);
    if (!Number.isSafeInteger(attemptId) || attemptId <= 0) {
      return res.status(400).json({ ok: false, reason: 'invalid_attempt_id' });
    }

    const attemptResult = await query(
      `SELECT a.attempt_id, a.user_id, a.version_id, a.status,
              v.version_label, v.active_question_count, c.code
       FROM relationship_assessment_attempts a
       JOIN relationship_assessment_versions v ON v.version_id = a.version_id
       JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
       WHERE a.attempt_id = ? AND a.user_id = ?
       LIMIT 1`,
      [attemptId, req.auth.userId],
    );
    const attempt = attemptResult.rows[0];
    if (!attempt) {
      return res.status(404).json({ ok: false, reason: 'attempt_not_found' });
    }
    if (![
      'attachment',
      'social_bonding',
      'emotional_regulation',
      'relationship_deficiency',
    ].includes(attempt.code)) {
      return res.status(400).json({ ok: false, reason: 'unsupported_assessment' });
    }
    if (attempt.status !== 'in_progress') {
      return res.status(409).json({ ok: false, reason: 'attempt_not_in_progress' });
    }

    const answerResult = await query(
      `SELECT q.question_key, q.reverse_scored, d.dimension_key,
              d.display_name, d.sort_order, aa.answer_value
       FROM relationship_assessment_attempt_answers aa
       JOIN relationship_assessment_questions q ON q.question_id = aa.question_id
       JOIN relationship_assessment_dimensions d ON d.dimension_id = q.dimension_id
       WHERE aa.attempt_id = ? AND q.is_active = 1
       ORDER BY q.question_order`,
      [attemptId],
    );
    const totalCount = Number(attempt.active_question_count);
    if (answerResult.rows.length !== totalCount) {
      return res.status(400).json({
        ok: false,
        reason: 'incomplete_attempt',
        progress: {
          answeredCount: answerResult.rows.length,
          totalCount,
          percentage: totalCount === 0
            ? 0
            : Math.round((answerResult.rows.length / totalCount) * 100),
        },
      });
    }

    const dimensions = relationshipDimensionScore(answerResult.rows);
    const overallScore = Math.round(
      dimensions.reduce((total, dimension) => total + dimension.score, 0) / dimensions.length,
    );
    const tendency = relationshipTendency(attempt.code, dimensions);
    const result = {
      assessmentCode: attempt.code,
      version: attempt.version_label,
      dimensions,
      overallScore,
      overallTendencyKey: tendency.key,
      overallTendency: tendency.text,
      disclaimer: '이 결과는 자기이해를 위한 참고 정보이며 의료적 진단이나 치료를 대신하지 않아요.',
    };

    await query(
      `INSERT INTO relationship_assessment_results
         (attempt_id, user_id, version_id, result_json)
       VALUES (?, ?, ?, ?)`,
      [attemptId, req.auth.userId, attempt.version_id, JSON.stringify(result)],
    );
    await query(
      `UPDATE relationship_assessment_attempts
       SET status = 'completed', completed_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE attempt_id = ? AND user_id = ? AND status = 'in_progress'`,
      [attemptId, req.auth.userId],
    );
    return res.status(201).json({ ok: true, result });
  } catch (error) {
    console.error('[API] /relationship/assessment-attempts/:attemptId/submit error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/explanations/personal/:code/current', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    const source = await getCurrentPersonalResultSource(req.auth.userId, code);
    if (source.error) {
      return res.status(source.error.status).json({ ok: false, reason: source.error.reason });
    }
    if (!source.result) {
      return res.json({ ok: true, status: 'idle', generation: null });
    }
    const generations = await query(
      `SELECT generation_id, status, provider, model, prompt_version,
              context_version, explanation_text, error_code, created_at, completed_at
       FROM relationship_explanation_generations
       WHERE requester_user_id = ? AND scope_type = 'personal_assessment'
         AND source_key = ?
       ORDER BY generation_id DESC
       LIMIT 1`,
      [req.auth.userId, `assessment-result:${source.result.result_id}`],
    );
    return res.json({
      ok: true,
      status: generations.rows[0]?.status ?? 'idle',
      generation: generations.rows[0] ? explanationGenerationPayload(generations.rows[0]) : null,
    });
  } catch (error) {
    console.error('[API] /relationship/explanations/personal/:code/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/explanations/personal/:code', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    const source = await getCurrentPersonalResultSource(req.auth.userId, code);
    if (source.error) {
      return res.status(source.error.status).json({ ok: false, reason: source.error.reason });
    }
    if (!source.result || !source.parsed) {
      return res.status(409).json({ ok: false, reason: 'personal_result_required' });
    }
    const generation = await runPersonalExplanationGeneration(req.auth.userId, source);
    if (!generation) {
      return res.status(500).json({ ok: false, reason: 'explanation_generation_failed' });
    }
    return res.status(201).json({
      ok: true,
      status: generation.status,
      generation: explanationGenerationPayload(generation),
    });
  } catch (error) {
    console.error('[API] /relationship/explanations/personal/:code POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/assessment-results/:code/current', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (assessment && assessment.audience !== 'individual') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_personal' });
    }
    const result = await query(
      `SELECT r.result_json
       FROM relationship_assessment_results r
       JOIN relationship_assessment_versions v ON v.version_id = r.version_id
       JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
       WHERE r.user_id = ? AND c.code = ?
       ORDER BY r.result_id DESC
       LIMIT 1`,
      [req.auth.userId, String(req.params.code ?? '').trim()],
    );
    const parsed = result.rows[0] ? parseRelationshipResult(result.rows[0].result_json) : null;
    return res.json({ ok: true, result: parsed });
  } catch (error) {
    console.error('[API] /relationship/assessment-results/:code/current error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/assessment-results/:code/history', async (req, res) => {
  try {
    const assessment = await getActiveRelationshipAssessment(String(req.params.code ?? '').trim());
    if (assessment && assessment.audience !== 'individual') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_personal' });
    }
    const result = await query(
      `SELECT r.result_id, r.result_json, r.created_at, v.version_label,
              q.question_key, q.prompt, q.question_order, q.reverse_scored,
              d.display_name AS dimension_title, aa.answer_value
       FROM relationship_assessment_results r
       JOIN relationship_assessment_versions v ON v.version_id = r.version_id
       JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
       LEFT JOIN relationship_assessment_attempt_answers aa
         ON aa.attempt_id = r.attempt_id
       LEFT JOIN relationship_assessment_questions q
         ON q.question_id = aa.question_id AND q.version_id = r.version_id
       LEFT JOIN relationship_assessment_dimensions d
         ON d.dimension_id = q.dimension_id
       WHERE r.user_id = ? AND c.code = ?
       ORDER BY r.result_id DESC, q.question_order`,
      [req.auth.userId, String(req.params.code ?? '').trim()],
    );
    const historyById = new Map();
    for (const row of result.rows) {
      const resultId = Number(row.result_id);
      let item = historyById.get(resultId);
      if (!item) {
        const parsed = parseRelationshipResult(row.result_json);
        if (!parsed) continue;
        item = {
          id: resultId,
          version: row.version_label,
          createdAt: row.created_at instanceof Date
            ? row.created_at.toISOString()
            : row.created_at == null ? null : String(row.created_at),
          result: parsed,
          answers: [],
        };
        historyById.set(resultId, item);
      }
      if (row.question_key != null) {
        const value = Number(row.answer_value);
        item.answers.push({
          questionKey: row.question_key,
          prompt: row.prompt,
          order: Number(row.question_order),
          dimensionTitle: row.dimension_title,
          value,
          label: relationshipLikertScale.find((option) => option.value === value)?.label ?? String(value),
          reverseScored: Boolean(row.reverse_scored),
        });
      }
    }
    const history = [...historyById.values()];
    return res.json({ ok: true, history });
  } catch (error) {
    console.error('[API] /relationship/assessment-results/:code/history error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const comparisonRecord = (row, idColumn = 'result_id') => ({
  id: row[idColumn] == null ? null : Number(row[idColumn]),
  createdAt: row.created_at instanceof Date
    ? row.created_at.toISOString()
    : row.created_at == null ? null : String(row.created_at),
  result: parseRelationshipResult(row.result_json),
});

router.get('/relationship/assessment-results/:code/comparison', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    const assessment = await getActiveRelationshipAssessment(code);
    if (!assessment) return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    if (assessment.audience !== 'individual') {
      return res.status(400).json({ ok: false, reason: 'assessment_not_personal' });
    }
    const result = await query(
      `SELECT r.result_id, r.result_json, r.created_at
       FROM relationship_assessment_results r
       WHERE r.user_id = ? AND r.version_id = ?
       ORDER BY r.result_id DESC
       LIMIT 2`,
      [req.auth.userId, assessment.version_id],
    );
    return res.json({
      ok: true,
      ...buildAssessmentComparison({
        scope: 'personal',
        assessmentCode: code,
        version: assessment.version_label,
        records: result.rows.map((row) => comparisonRecord(row)),
      }),
    });
  } catch (error) {
    console.error('[API] personal assessment comparison GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/couple-assessment-results/:code/comparison', async (req, res) => {
  try {
    const code = String(req.params.code ?? '').trim();
    const assessment = await getActiveRelationshipAssessment(code);
    if (!assessment) return res.status(404).json({ ok: false, reason: 'assessment_not_found' });
    if (assessment.audience !== 'couple' || !coupleAssessmentCodes.has(code)) {
      return res.status(400).json({ ok: false, reason: 'assessment_not_couple' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (coupleId == null) return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    const result = await query(
      `SELECT couple_result_id, result_json, created_at
       FROM relationship_couple_assessment_results
       WHERE couple_id = ? AND version_id = ?
       ORDER BY couple_result_id DESC
       LIMIT 2`,
      [coupleId, assessment.version_id],
    );
    return res.json({
      ok: true,
      ...buildAssessmentComparison({
        scope: 'couple',
        assessmentCode: code,
        version: assessment.version_label,
        records: result.rows.map((row) => comparisonRecord(row, 'couple_result_id')),
      }),
    });
  } catch (error) {
    console.error('[API] couple assessment comparison GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

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
    req.app.locals.io?.in(couple.RoomCode).disconnectSockets(true);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /user/partner DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 회원 탈퇴
// POST body: { password } (이메일 사용자만. Google 사용자는 password 불필요)
// 완료 조건:
//   1. 이메일 사용자: 현재 비밀번호 + 명시적 확인
//   2. 활성 커플 비활성화 → 상대방 소켓 알림
//   3. 탈퇴 사용자의 setlog_posts 영구 삭제 + 미디어 파일 삭제
//   4. 탈퇴 사용자의 map_pins: 연결된 핀 → 익명화, 연결 없는 핀 → 삭제
//   5. Users 행 → tombstone (이메일/이름/자격증명 제거, IsDeleted=1)
router.delete('/user', async (req, res) => {
  try {
    await ensureUserColumns();
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({ ok: false, reason: 'unauthorized' });
    }

    // 사용자 조회
    const userRes = await query(
      `SELECT UserId, Email, PasswordHash, AuthProvider
       FROM Users WHERE UserId = ? LIMIT 1`,
      [userId],
    );
    const user = userRes.rows[0];
    if (!user) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }

    // 이메일 사용자: 현재 비밀번호 필수
    if (isPasswordUser(user.AuthProvider)) {
      const { password } = req.body || {};
      if (!password) {
        return res.status(400).json({ ok: false, reason: 'password_required' });
      }
      const isMatch = await bcrypt.compare(password, user.PasswordHash || '');
      if (!isMatch) {
        return res.status(401).json({ ok: false, reason: 'invalid_password' });
      }
    }

    // 1. 활성 커플 찾기
    const coupleRes = await query(
      `SELECT CoupleId, User1Id, User2Id, RoomCode
       FROM Couples
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)
       LIMIT 1`,
      [userId, userId],
    );
    const couple = coupleRes.rows[0] ?? null;
    const partnerId = partnerIdForCouple(couple, userId);

    // 2. setlog_posts 목록 수집 (미디어 파일 경로 확보)
    const setlogRes = await query(
      'SELECT id, media_url FROM setlog_posts WHERE user_id = ?',
      [userId],
    );
    const setlogPosts = setlogRes.rows;

    // 3. map_pins 분류: setlog_posts 가 참조하는 핀 → 익명화, 나머지 → 삭제
    const pinsRes = await query(
      `SELECT mp.id,
              EXISTS(
                SELECT 1 FROM setlog_posts sp
                WHERE sp.map_pin_id = mp.id
              ) AS hasLinkedMoment
       FROM map_pins mp
       WHERE mp.user_id = ?`,
      [userId],
    );
    const pinRows = (pinsRes.rows || []).map((r) => ({
      id: r.id,
      hasLinkedMoment: Boolean(r.hasLinkedMoment),
    }));
    const { toAnonymize, toDelete } = classifyPinsForDeletion(pinRows);

    // 미디어 파일 경로 목록
    const mediaPaths = collectMediaPaths(setlogPosts, mediaFilePath);

    // ─── 트랜잭션으로 DB 변경 ─────────────────────────────────────────────
    await transaction(async (conn) => {
      // 커플 비활성화
      if (couple) {
        await conn.execute(
          `UPDATE Couples SET Status = 'inactive', DeactivatedAt = CURRENT_TIMESTAMP WHERE CoupleId = ?`,
          [couple.CoupleId],
        );
        if (partnerId) {
          await conn.execute(
            'UPDATE User_Preference SET PartnerCode = NULL WHERE UserId IN (?, ?)',
            [userId, partnerId],
          );
        }
      }

      // setlog 삭제
      if (setlogPosts.length > 0) {
        await conn.execute('DELETE FROM setlog_posts WHERE user_id = ?', [userId]);
      }

      // map_pins 처리
      if (toAnonymize.length > 0) {
        await conn.execute(
          `UPDATE map_pins
           SET user_id = NULL, archived_at = CURRENT_TIMESTAMP
           WHERE id IN (${toAnonymize.map(() => '?').join(',')})`,
          toAnonymize,
        );
      }
      if (toDelete.length > 0) {
        await conn.execute(
          `DELETE FROM map_pins WHERE id IN (${toDelete.map(() => '?').join(',')})`,
          toDelete,
        );
      }

      // Users tombstone 전환
      const tombstone = buildTombstoneFields(userId);
      await conn.execute(
        `UPDATE Users
         SET Email = ?, UserName = ?, FullName = ?, Nickname = ?,
             PasswordHash = ?, GoogleSubject = NULL, GooglePictureUrl = NULL,
             IsDeleted = ?, DeletedAt = ?
         WHERE UserId = ?`,
        [
          tombstone.Email,
          tombstone.UserName,
          tombstone.FullName,
          tombstone.Nickname,
          tombstone.PasswordHash,
          tombstone.IsDeleted,
          tombstone.DeletedAt,
          userId,
        ],
      );
    });

    // ─── 트랜잭션 외부: 미디어 파일 삭제, 소켓 알림 ──────────────────────
    await Promise.allSettled(
      mediaPaths.map((fp) => fs.promises.rm(fp, { force: true })),
    );

    if (couple) {
      req.app.locals.io?.to(couple.RoomCode).emit('partner:disconnected', {
        reason: 'partner_deleted_account',
      });
      req.app.locals.io?.in(couple.RoomCode).disconnectSockets(true);
    }

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /user DELETE error:', err);
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

    const { month } = req.query; // YYYY-MM 형식
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    let sql = `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName,
                      mp.place_name AS linked_place_name, mp.category AS linked_place_category,
                      mp.archived_at AS linked_place_archived_at,
                      tm.business_date AS today_business_date,
                      tm.revealed_at AS today_revealed_at,
                      viewer_tm.id AS viewer_today_moment_id,
                      (SELECT JSON_ARRAYAGG(JSON_OBJECT('user_id', r.user_id, 'emoji', r.emoji))
                       FROM setlog_reactions r
                       WHERE p.session_id IS NOT NULL AND r.session_id = p.session_id AND r.couple_id = p.couple_id
                      ) AS session_reactions
               FROM setlog_posts p
               LEFT JOIN Users u ON p.user_id = u.UserId
               LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
               LEFT JOIN today_moments tm ON tm.setlog_post_id = p.id
               LEFT JOIN today_moments viewer_tm
                 ON viewer_tm.couple_id = tm.couple_id
                AND viewer_tm.business_date = tm.business_date
                AND viewer_tm.user_id = ?
               WHERE p.couple_id = ?`;
    const params = [req.auth.userId, coupleId];

    if (month) {
      sql += ` AND DATE_FORMAT(p.taken_at, '%Y-%m') = ?`;
      params.push(month);
    }

    sql += ` ORDER BY p.captured_at DESC, p.id DESC`;

    const result = await query(sql, params);
    res.json({
      ok: true,
      posts: result.rows.map((post) => maskLockedTodayMoment({
        post,
        viewerUserId: req.auth.userId,
      })),
    });
  } catch (err) {
    console.error('[API] /setlog GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const uploadedFilePath = (file) => file?.path || (file?.filename
  ? path.join(config.UPLOADS_ROOT, file.filename)
  : null);

const removeUploadedFile = async (file) => {
  const filePath = uploadedFilePath(file);
  if (!filePath) return;
  await fs.promises.rm(filePath, { force: true });
};

const mediaFilePath = (mediaUrl) => {
  const filename = path.basename(String(mediaUrl || ''));
  return filename ? path.join(config.UPLOADS_ROOT, filename) : null;
};

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
  if (!sameCouple) return { error: 'map_pin_forbidden' };

  return { id: pinId };
};

// 셋로그 생성
router.post('/setlog', upload.single('media'), async (req, res) => {
  let keepUpload = false;
  try {
    await ensureUserColumns();
    await ensureSetlogTable();

    const {
      caption,
      tags,
      taken_at,
      captured_at,
      media_type,
      map_pin_id,
      session_id,
      today_moment,
    } = req.body;
    let mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const uploadedMediaType = req.file?.mimetype.startsWith('video/') ? 'video' : 'image';
    const normalizedMediaType = mediaUrl ? uploadedMediaType : (media_type || 'text');
    const reject = async (status, reason) => {
      await removeUploadedFile(req.file);
      return res.status(status).json({ ok: false, reason });
    };
    const allowedMomentMimes = new Set([
      'image/jpeg',
      'image/png',
      'image/webp',
      'video/mp4',
      'video/quicktime',
      'video/webm',
    ]);

    if (req.file && !allowedMomentMimes.has(req.file.mimetype)) {
      return reject(415, 'unsupported_media_type');
    }

    if (!taken_at) {
      return reject(400, 'missing_fields');
    }

    if (!['text', 'image', 'video'].includes(normalizedMediaType)) {
      return reject(400, 'invalid_media_type');
    }

    if (normalizedMediaType === 'text' && !caption?.trim()) {
      return reject(400, 'caption_required');
    }

    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return reject(409, 'active_couple_required');
    }
    const resolvedMapPin = await resolveSetlogMapPinId(map_pin_id, userId, coupleId);
    if (resolvedMapPin?.error) {
      return reject(400, resolvedMapPin.error);
    }
    if (req.file?.mimetype.startsWith('video/')) {
      try {
        const normalizedPath = await normalizeMomentClip(uploadedFilePath(req.file));
        req.file.path = normalizedPath;
        req.file.filename = path.basename(normalizedPath);
        req.file.mimetype = 'video/mp4';
        mediaUrl = `/uploads/${req.file.filename}`;
      } catch (error) {
        return reject(422, error.message);
      }
    }
    const tagsArray = parseJsonArray(tags);
    const user = await query('SELECT UserCode FROM Users WHERE UserId = ? LIMIT 1', [userId]);
    const designateAsToday = today_moment === true || today_moment === 'true';
    const today = businessDate();
    if (designateAsToday && taken_at !== today) {
      return reject(400, 'today_moment_date_required');
    }

    const createdPost = await transaction(async (connection) => {
      const [result] = await connection.execute(
        `INSERT INTO setlog_posts
         (couple_id, user_id, map_pin_id, user_code, media_type, media_url, caption, tags, taken_at, captured_at, session_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW()), ?)`,
        [
          coupleId,
          userId,
          resolvedMapPin?.id ?? null,
          user.rows[0]?.UserCode || null,
          normalizedMediaType,
          mediaUrl,
          caption || null,
          JSON.stringify(tagsArray),
          taken_at,
          captured_at || null,
          session_id || null,
        ],
      );
      if (designateAsToday) {
        await selectTodayMoment(connection, {
          coupleId,
          userId,
          postId: result.insertId,
          date: today,
        });
      }
      const [created] = await connection.execute(
        `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName,
                mp.place_name AS linked_place_name, mp.category AS linked_place_category,
                mp.archived_at AS linked_place_archived_at
         FROM setlog_posts p
         LEFT JOIN Users u ON p.user_id = u.UserId
         LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
         WHERE p.id = ?`,
        [result.insertId],
      );
      return created[0];
    });
    keepUpload = true;

    res.status(201).json({ ok: true, post: createdPost });
  } catch (err) {
    console.error('[API] /setlog POST error:', err);
    await removeUploadedFile(req.file).catch(() => {});
    if (sendTodayMomentError(res, err)) return;
    res.status(500).json({ ok: false, reason: 'internal_error' });
  } finally {
    if (req.file && !keepUpload) {
      await removeUploadedFile(req.file).catch((error) => {
        console.error('[API] failed to clean rejected MomentLoop upload:', error);
      });
    }
  }
});

// 셋로그 이모지 반응 토글
router.post('/setlog/reaction', async (req, res) => {
  try {
    await ensureSetlogTable();
    const { session_id, emoji } = req.body;
    if (!session_id || !emoji) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    const existing = await query(
      'SELECT emoji FROM setlog_reactions WHERE couple_id = ? AND session_id = ? AND user_id = ? LIMIT 1',
      [coupleId, session_id, userId]
    );

    if (existing.rows[0]?.emoji === emoji) {
      await query(
        'DELETE FROM setlog_reactions WHERE couple_id = ? AND session_id = ? AND user_id = ?',
        [coupleId, session_id, userId]
      );
    } else {
      await query(
        `INSERT INTO setlog_reactions (couple_id, session_id, user_id, emoji)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE emoji = VALUES(emoji), created_at = NOW()`,
        [coupleId, session_id, userId, emoji]
      );
    }

    const reactions = await query(
      'SELECT user_id, emoji FROM setlog_reactions WHERE couple_id = ? AND session_id = ?',
      [coupleId, session_id]
    );
    res.json({ ok: true, reactions: reactions.rows });
  } catch (err) {
    console.error('[API] /setlog/reaction POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.patch('/setlog/:id', async (req, res) => {
  try {
    await ensureSetlogTable();
    const postId = Number(req.params.id);
    const existing = await query(
      'SELECT id, user_id, couple_id FROM setlog_posts WHERE id = ? LIMIT 1',
      [postId],
    );
    const post = existing.rows[0];
    if (!post) return res.status(404).json({ ok: false, reason: 'moment_not_found' });
    if (Number(post.user_id) !== req.auth.userId) {
      return res.status(403).json({ ok: false, reason: 'moment_author_required' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (!coupleId || Number(post.couple_id) !== Number(coupleId)) {
      return res.status(403).json({ ok: false, reason: 'active_couple_required' });
    }

    const caption = typeof req.body.caption === 'string' ? req.body.caption.trim() : null;
    const takenAt = typeof req.body.taken_at === 'string' ? req.body.taken_at : null;
    const tags = req.body.tags === undefined ? null : JSON.stringify(parseJsonArray(req.body.tags));
    const hasMapPinId = Object.prototype.hasOwnProperty.call(req.body, 'map_pin_id');
    let mapPinId = hasMapPinId ? (req.body.map_pin_id ? Number(req.body.map_pin_id) : null) : null;
    if (hasMapPinId && mapPinId !== null) {
      const resolvedMapPin = await resolveSetlogMapPinId(mapPinId, req.auth.userId, coupleId);
      if (resolvedMapPin?.error) {
        return res.status(400).json({ ok: false, reason: resolvedMapPin.error });
      }
      mapPinId = resolvedMapPin.id;
    }
    if (caption === null && takenAt === null && tags === null && !hasMapPinId) {
      return res.status(400).json({ ok: false, reason: 'no_changes' });
    }
    const updates = [];
    const params = [];
    if (caption !== null) { updates.push('caption = ?'); params.push(caption); }
    if (takenAt !== null) { updates.push('taken_at = ?'); params.push(takenAt); }
    if (tags !== null) { updates.push('tags = ?'); params.push(tags); }
    if (hasMapPinId) { updates.push('map_pin_id = ?'); params.push(mapPinId); }

    await query(
      `UPDATE setlog_posts SET ${updates.join(', ')} WHERE id = ?`,
      [...params, postId],
    );
    const updated = await query(
      `SELECT p.*, u.Nickname, COALESCE(u.Nickname, u.UserName) AS UserName
       FROM setlog_posts p LEFT JOIN Users u ON p.user_id = u.UserId WHERE p.id = ?`,
      [postId],
    );
    res.json({ ok: true, post: updated.rows[0] });
  } catch (err) {
    console.error('[API] /setlog PATCH error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 셋로그 삭제
router.delete('/setlog/:id', async (req, res) => {
  try {
    await ensureSetlogTable();

    const id = Number(req.params.id);
    const existing = await query(
      'SELECT id, user_id, couple_id, media_url FROM setlog_posts WHERE id = ? LIMIT 1',
      [id],
    );
    const post = existing.rows[0];
    if (!post) return res.status(404).json({ ok: false, reason: 'moment_not_found' });
    if (Number(post.user_id) !== req.auth.userId) {
      return res.status(403).json({ ok: false, reason: 'moment_author_required' });
    }
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (!coupleId || Number(post.couple_id) !== Number(coupleId)) {
      return res.status(403).json({ ok: false, reason: 'active_couple_required' });
    }
    await transaction(async (connection) => {
      const [lockedPosts] = await connection.execute(
        'SELECT id FROM setlog_posts WHERE id = ? LIMIT 1 FOR UPDATE',
        [id],
      );
      if (!lockedPosts[0]) return;
      const [todayRows] = await connection.execute(
        `SELECT id, revealed_at FROM today_moments
         WHERE setlog_post_id = ? LIMIT 1 FOR UPDATE`,
        [id],
      );
      const todayMoment = todayRows[0];
      if (todayMoment?.revealed_at) {
        await connection.execute(
          `UPDATE today_moments
           SET setlog_post_id = NULL, deleted_at = NOW()
           WHERE id = ?`,
          [todayMoment.id],
        );
      } else if (todayMoment) {
        await connection.execute('DELETE FROM today_moments WHERE id = ?', [todayMoment.id]);
      }
      await connection.execute(
        `UPDATE afterglow_contributions
         SET setlog_post_id = NULL, deleted_at = NOW()
         WHERE setlog_post_id = ?`,
        [id],
      );
      await connection.execute('DELETE FROM setlog_posts WHERE id = ?', [id]);
    });
    const filePath = mediaFilePath(post.media_url);
    if (filePath) await fs.promises.rm(filePath, { force: true });
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /setlog DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 1.1 Today Moment / Today Loop
// ============================================

router.get('/retention/today', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const date = businessDate();
    const result = await query(
      `SELECT tm.user_id, tm.revealed_at, tm.deleted_at,
              p.id, p.media_type, p.media_url, p.caption, p.tags, p.taken_at, p.captured_at,
              p.map_pin_id, mp.place_name AS linked_place_name,
              COALESCE(u.Nickname, u.UserName) AS UserName
       FROM today_moments tm
       LEFT JOIN setlog_posts p ON p.id = tm.setlog_post_id
       LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
       LEFT JOIN Users u ON u.UserId = tm.user_id
       WHERE tm.couple_id = ? AND tm.business_date = ?`,
      [coupleId, date],
    );
    const mine = result.rows.find((row) => Number(row.user_id) === userId) ?? null;
    const partner = result.rows.find((row) => Number(row.user_id) !== userId) ?? null;
    const hasMine = Boolean(mine);
    const hasPartner = Boolean(partner);
    const revealedAt = mine?.revealed_at ?? partner?.revealed_at ?? null;
    const viewResult = await query(
      `SELECT viewed_at FROM today_loop_views
       WHERE couple_id = ? AND user_id = ? AND business_date = ? LIMIT 1`,
      [coupleId, userId, date],
    );
    const viewedAt = viewResult.rows[0]?.viewed_at ?? null;
    const canViewPartner = hasPartner && canViewTodayMoment({
      isAuthor: false,
      revealed: Boolean(revealedAt),
      viewerHasMoment: hasMine,
    });
    res.json({
      ok: true,
      date,
      status: todayMomentStatus({ hasMine, hasPartner, viewed: Boolean(viewedAt) }),
      hasPartnerMoment: hasPartner,
      revealedAt: revealedAt,
      viewedAt,
      myMoment: serializeTodayMomentRow(mine),
      partnerMoment: canViewPartner ? serializeTodayMomentRow(partner) : null,
    });
  } catch (err) {
    console.error('[API] /retention/today GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/retention/today/view', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const date = businessDate();
    const result = await transaction(async (connection) => {
      const [moments] = await connection.execute(
        `SELECT COUNT(*) AS count, MIN(revealed_at) AS revealed_at
         FROM today_moments
         WHERE couple_id = ? AND business_date = ? AND revealed_at IS NOT NULL`,
        [coupleId, date],
      );
      if (Number(moments[0]?.count) < 2 || !moments[0]?.revealed_at) {
        throw new TodayMomentRequestError(409, 'today_loop_not_revealed');
      }
      await connection.execute(
        `INSERT INTO today_loop_views (couple_id, user_id, business_date, viewed_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE viewed_at = LEAST(viewed_at, VALUES(viewed_at))`,
        [coupleId, userId, date],
      );
      const [views] = await connection.execute(
        `SELECT viewed_at FROM today_loop_views
         WHERE couple_id = ? AND user_id = ? AND business_date = ? LIMIT 1`,
        [coupleId, userId, date],
      );
      return views[0]?.viewed_at;
    });
    res.json({ ok: true, date, viewedAt: result });
  } catch (err) {
    if (sendTodayMomentError(res, err)) return;
    console.error('[API] /retention/today/view POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/retention/beta/summary', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const requestedDays = Number(req.query.days ?? 7);
    const days = Number.isFinite(requestedDays)
      ? Math.min(Math.max(Math.trunc(requestedDays), 1), 30)
      : 7;
    const endDate = businessDate();
    const startDate = shiftDate(endDate, -(days - 1));
    const result = await query(
      `SELECT
         COUNT(DISTINCT CASE WHEN daily.contribution_count >= 2 THEN daily.business_date END) AS loop_days,
         COUNT(tm.id) AS moments_total,
         COALESCE(SUM(CASE
           WHEN v.viewed_at >= tm.selected_at
             AND v.viewed_at <= DATE_ADD(tm.selected_at, INTERVAL 24 HOUR)
           THEN 1 ELSE 0 END), 0) AS viewed_within_24_hours
       FROM today_moments tm
       JOIN Couples c ON c.CoupleId = tm.couple_id AND c.Status = 'active'
       JOIN (
         SELECT couple_id, business_date, COUNT(*) AS contribution_count
         FROM today_moments
         WHERE revealed_at IS NOT NULL
         GROUP BY couple_id, business_date
       ) daily ON daily.couple_id = tm.couple_id AND daily.business_date = tm.business_date
       LEFT JOIN today_loop_views v
         ON v.couple_id = tm.couple_id
        AND v.business_date = tm.business_date
        AND v.user_id = CASE WHEN tm.user_id = c.User1Id THEN c.User2Id ELSE c.User1Id END
       WHERE tm.couple_id = ? AND tm.business_date BETWEEN ? AND ?`,
      [coupleId, startDate, endDate],
    );
    const row = result.rows[0] ?? {};
    const momentsTotal = Number(row.moments_total ?? 0);
    const momentsViewedWithin24Hours = Number(row.viewed_within_24_hours ?? 0);
    res.json({
      ok: true,
      days,
      startDate,
      endDate,
      loopDays: Number(row.loop_days ?? 0),
      momentsTotal,
      momentsViewedWithin24Hours,
      viewRateWithin24Hours: momentsTotal === 0
        ? 0
        : momentsViewedWithin24Hours / momentsTotal,
    });
  } catch (err) {
    console.error('[API] /retention/beta/summary GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.put('/retention/today/moment', async (req, res) => {
  try {
    const postId = Number(req.body.post_id);
    if (!Number.isInteger(postId) || postId <= 0) {
      return res.status(400).json({ ok: false, reason: 'invalid_post_id' });
    }
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const date = businessDate();
    await transaction((connection) => selectTodayMoment(connection, {
      coupleId,
      userId,
      postId,
      date,
    }));
    res.json({ ok: true, date, postId });
  } catch (err) {
    if (sendTodayMomentError(res, err)) return;
    console.error('[API] /retention/today/moment PUT error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.delete('/retention/today/moment', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const date = businessDate();
    const removed = await transaction(async (connection) => {
      const [rows] = await connection.execute(
        `SELECT id, revealed_at FROM today_moments
         WHERE couple_id = ? AND user_id = ? AND business_date = ?
         LIMIT 1 FOR UPDATE`,
        [coupleId, userId, date],
      );
      if (!rows[0]) return false;
      if (!canReplaceTodayMoment(rows[0].revealed_at)) {
        throw new TodayMomentRequestError(409, 'today_loop_locked');
      }
      await connection.execute('DELETE FROM today_moments WHERE id = ?', [rows[0].id]);
      return true;
    });
    res.json({ ok: true, removed });
  } catch (err) {
    if (sendTodayMomentError(res, err)) return;
    console.error('[API] /retention/today/moment DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ============================================
// 2. Map API (데이트 장소 핀)
// ============================================

router.post('/retention/afterglow/:pinId/visit', async (req, res) => {
  try {
    await ensureTables();
    const pinId = Number(req.params.pinId);
    if (!Number.isInteger(pinId) || pinId <= 0) {
      return res.status(404).json({ ok: false, reason: 'afterglow_pin_not_found' });
    }
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const visitDate = businessDate();
    const result = await transaction(async (connection) => {
      const [pins] = await connection.execute(
        `SELECT id, status FROM map_pins
         WHERE id = ? AND couple_id = ? AND archived_at IS NULL
         LIMIT 1 FOR UPDATE`,
        [pinId, coupleId],
      );
      const pin = pins[0];
      if (!pin) throw new AfterglowRequestError(404, 'afterglow_pin_not_found');

      const [existingRows] = await connection.execute(
        `SELECT id, map_pin_id, visit_date, marked_by_user_id, created_at
         FROM afterglow_visits WHERE map_pin_id = ? LIMIT 1`,
        [pinId],
      );
      if (existingRows[0]) return { created: false, row: existingRows[0] };
      if (pin.status !== 'wishlist') {
        throw new AfterglowRequestError(409, 'afterglow_requires_wishlist');
      }

      const [inserted] = await connection.execute(
        `INSERT INTO afterglow_visits
           (couple_id, map_pin_id, visit_date, marked_by_user_id)
         VALUES (?, ?, ?, ?)`,
        [coupleId, pinId, visitDate, userId],
      );
      await connection.execute(
        `UPDATE map_pins
         SET status = 'visited', visit_date = ?, updated_at = NOW()
         WHERE id = ?`,
        [visitDate, pinId],
      );
      const [rows] = await connection.execute(
        `SELECT id, map_pin_id, visit_date, marked_by_user_id, created_at
         FROM afterglow_visits WHERE id = ? LIMIT 1`,
        [inserted.insertId],
      );
      return { created: true, row: rows[0] };
    });
    const visit = {
      id: Number(result.row.id),
      mapPinId: Number(result.row.map_pin_id),
      visitDate: dateOnly(result.row.visit_date),
      markedByUserId: Number(result.row.marked_by_user_id),
      createdAt: result.row.created_at,
    };
    res.status(result.created ? 201 : 200).json({ ok: true, visit });
  } catch (err) {
    if (sendAfterglowError(res, err)) return;
    console.error('[API] /retention/afterglow/:pinId/visit POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.put('/retention/afterglow/:visitId/contribution', async (req, res) => {
  try {
    const visitId = Number(req.params.visitId);
    const postId = Number(req.body.post_id);
    if (!Number.isInteger(visitId) || visitId <= 0 || !Number.isInteger(postId) || postId <= 0) {
      return res.status(400).json({ ok: false, reason: 'invalid_afterglow_contribution' });
    }
    const caption = req.body.caption == null ? null : String(req.body.caption).trim() || null;
    const emotionTag = req.body.emotion_tag == null
      ? null
      : String(req.body.emotion_tag).trim() || null;
    if (caption && caption.length > 120) {
      return res.status(400).json({ ok: false, reason: 'afterglow_caption_too_long' });
    }
    if (emotionTag && emotionTag.length > 24) {
      return res.status(400).json({ ok: false, reason: 'afterglow_emotion_tag_too_long' });
    }
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const contribution = await transaction(async (connection) => {
      const [visits] = await connection.execute(
        `SELECT v.id, v.map_pin_id, v.visit_date
         FROM afterglow_visits v
         JOIN map_pins mp ON mp.id = v.map_pin_id
         WHERE v.id = ? AND v.couple_id = ? AND mp.archived_at IS NULL
         LIMIT 1 FOR UPDATE`,
        [visitId, coupleId],
      );
      const visit = visits[0];
      if (!visit) throw new AfterglowRequestError(404, 'afterglow_visit_not_found');

      const [posts] = await connection.execute(
        `SELECT id FROM setlog_posts
         WHERE id = ? AND user_id = ? AND couple_id = ?
           AND map_pin_id = ? AND taken_at = ?
         LIMIT 1 FOR UPDATE`,
        [postId, userId, coupleId, visit.map_pin_id, visit.visit_date],
      );
      if (!posts[0]) throw new AfterglowRequestError(404, 'afterglow_moment_not_found');

      await connection.execute(
        `INSERT INTO afterglow_contributions
           (visit_id, user_id, setlog_post_id, caption, emotion_tag, deleted_at)
         VALUES (?, ?, ?, ?, ?, NULL)
         ON DUPLICATE KEY UPDATE
           setlog_post_id = VALUES(setlog_post_id), caption = VALUES(caption),
           emotion_tag = VALUES(emotion_tag), deleted_at = NULL`,
        [visitId, userId, postId, caption, emotionTag],
      );
      const [rows] = await connection.execute(
        `SELECT id, visit_id, user_id, setlog_post_id, caption, emotion_tag, created_at
         FROM afterglow_contributions
         WHERE visit_id = ? AND user_id = ? LIMIT 1`,
        [visitId, userId],
      );
      return rows[0];
    });
    res.json({
      ok: true,
      contribution: {
        id: Number(contribution.id),
        visitId: Number(contribution.visit_id),
        userId: Number(contribution.user_id),
        postId: Number(contribution.setlog_post_id),
        caption: contribution.caption,
        emotionTag: contribution.emotion_tag,
        createdAt: contribution.created_at,
      },
    });
  } catch (err) {
    if (sendAfterglowError(res, err)) return;
    console.error('[API] /retention/afterglow/:visitId/contribution PUT error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/retention/afterglow/pin/:pinId', async (req, res) => {
  try {
    const pinId = Number(req.params.pinId);
    if (!Number.isInteger(pinId) || pinId <= 0) {
      return res.status(404).json({ ok: false, reason: 'afterglow_pin_not_found' });
    }
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const pins = await query(
      `SELECT id, place_name, status, visit_date
       FROM map_pins
       WHERE id = ? AND couple_id = ? AND archived_at IS NULL LIMIT 1`,
      [pinId, coupleId],
    );
    const pin = pins.rows[0];
    if (!pin) return res.status(404).json({ ok: false, reason: 'afterglow_pin_not_found' });

    const visits = await query(
      `SELECT id, map_pin_id, visit_date, marked_by_user_id, created_at
       FROM afterglow_visits
       WHERE map_pin_id = ? AND couple_id = ? LIMIT 1`,
      [pinId, coupleId],
    );
    const visit = visits.rows[0];
    if (!visit) {
      return res.json({ ok: true, pin: { id: pinId, placeName: pin.place_name }, visit: null, contributions: [] });
    }

    const slots = await query(
      `SELECT u.UserId AS user_id, COALESCE(u.Nickname, u.UserName) AS user_name,
              ac.id AS contribution_id, ac.caption, ac.emotion_tag, ac.deleted_at,
              p.id AS post_id, p.media_type, p.media_url, p.caption AS moment_caption
       FROM Couples c
       JOIN Users u ON (u.UserId = c.User1Id OR u.UserId = c.User2Id)
       LEFT JOIN afterglow_contributions ac ON ac.visit_id = ? AND ac.user_id = u.UserId
       LEFT JOIN setlog_posts p ON p.id = ac.setlog_post_id
       WHERE c.CoupleId = ? AND c.Status = 'active'
       ORDER BY CASE WHEN u.UserId = ? THEN 0 ELSE 1 END`,
      [visit.id, coupleId, userId],
    );
    const contributions = slots.rows.map((slot) => {
      const contributed = Boolean(slot.contribution_id);
      const deleted = contributed && Boolean(slot.deleted_at || !slot.post_id);
      return {
        userId: Number(slot.user_id),
        userName: slot.user_name,
        contributed,
        deleted,
        contributionId: contributed ? Number(slot.contribution_id) : null,
        postId: contributed && !deleted ? Number(slot.post_id) : null,
        caption: contributed && !deleted ? slot.caption : null,
        emotionTag: contributed && !deleted ? slot.emotion_tag : null,
        mediaType: contributed && !deleted ? slot.media_type : null,
        mediaUrl: contributed && !deleted ? slot.media_url : null,
        momentCaption: contributed && !deleted ? slot.moment_caption : null,
      };
    });
    res.json({
      ok: true,
      pin: { id: pinId, placeName: pin.place_name },
      visit: {
        id: Number(visit.id),
        mapPinId: Number(visit.map_pin_id),
        visitDate: dateOnly(visit.visit_date),
        markedByUserId: Number(visit.marked_by_user_id),
        createdAt: visit.created_at,
      },
      contributions,
    });
  } catch (err) {
    console.error('[API] /retention/afterglow/pin/:pinId GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/retention/afterglow/beta/summary', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const requestedDays = Number(req.query.days ?? 7);
    const days = Number.isFinite(requestedDays)
      ? Math.min(Math.max(Math.trunc(requestedDays), 1), 30)
      : 7;
    const endDate = businessDate();
    const startDate = shiftDate(endDate, -(days - 1));
    const result = await query(
      `SELECT COUNT(DISTINCT v.id) AS visits,
              COUNT(DISTINCT CASE WHEN c.id IS NOT NULL THEN v.id END) AS visits_with_contribution,
              COUNT(c.id) AS contributions
       FROM afterglow_visits v
       LEFT JOIN afterglow_contributions c
         ON c.visit_id = v.id AND c.setlog_post_id IS NOT NULL AND c.deleted_at IS NULL
       WHERE v.couple_id = ? AND v.visit_date BETWEEN ? AND ?`,
      [coupleId, startDate, endDate],
    );
    const visits = Number(result.rows[0]?.visits ?? 0);
    const visitsWithContribution = Number(result.rows[0]?.visits_with_contribution ?? 0);
    const contributions = Number(result.rows[0]?.contributions ?? 0);
    res.json({
      ok: true,
      days,
      startDate,
      endDate,
      visits,
      visitsWithContribution,
      contributions,
      visitContributionRate: visits === 0 ? 0 : visitsWithContribution / visits,
      contributionRate: visits === 0 ? 0 : contributions / (visits * 2),
    });
  } catch (err) {
    console.error('[API] /retention/afterglow/beta/summary GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── MVP3: Memory Card ────────────────────────────────────────────────────────

router.get('/retention/memory-card', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const today = businessDate();
    const monthDay = today.slice(5); // 'MM-DD'
    const currentYear = new Date().getFullYear();

    const cardResult = await query(
      `SELECT p.id, p.caption, p.media_url, p.captured_at, mp.place_name
       FROM setlog_posts p
       LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
       WHERE p.couple_id = ?
         AND DATE_FORMAT(p.captured_at, '%m-%d') = ?
         AND YEAR(p.captured_at) < YEAR(CURDATE())
       ORDER BY RAND()
       LIMIT 1`,
      [coupleId, monthDay],
    );

    const countResult = await query(
      `SELECT COUNT(*) AS total
       FROM setlog_posts
       WHERE couple_id = ?
         AND DATE_FORMAT(captured_at, '%m-%d') = ?
         AND YEAR(captured_at) < YEAR(CURDATE())`,
      [coupleId, monthDay],
    );

    const raw = cardResult.rows[0] ?? null;
    const card = raw
      ? {
          id: raw.id,
          caption: raw.caption,
          media_url: raw.media_url,
          captured_at: raw.captured_at,
          place_name: raw.place_name ?? null,
          years_ago: currentYear - new Date(raw.captured_at).getFullYear(),
        }
      : null;

    res.json({
      ok: true,
      card,
      total_count: Number(countResult.rows[0]?.total ?? 0),
      business_date: today,
    });
  } catch (err) {
    console.error('[API] /retention/memory-card GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/retention/memory-card/list', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const today = businessDate();
    const monthDay = today.slice(5); // 'MM-DD'
    const currentYear = new Date().getFullYear();

    const result = await query(
      `SELECT p.id, p.caption, p.media_url, p.captured_at, mp.place_name
       FROM setlog_posts p
       LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
       WHERE p.couple_id = ?
         AND DATE_FORMAT(p.captured_at, '%m-%d') = ?
         AND YEAR(p.captured_at) < YEAR(CURDATE())
       ORDER BY p.captured_at DESC`,
      [coupleId, monthDay],
    );

    const posts = result.rows.map((row) => ({
      id: row.id,
      caption: row.caption,
      media_url: row.media_url,
      captured_at: row.captured_at,
      place_name: row.place_name ?? null,
      years_ago: currentYear - new Date(row.captured_at).getFullYear(),
    }));

    res.json({ ok: true, posts, business_date: today });
  } catch (err) {
    console.error('[API] /retention/memory-card/list GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── MVP4: Secret Base Milestones ─────────────────────────────────────────────

const MILESTONE_REWARDS = {
  first_moment:      { item_id: 30, icon: '🐾', name: '동물 말',         grade: 'B'   },
  moments_10:        { item_id: 10, icon: '🌸', name: '벚꽃 카드뒷면',   grade: 'B'   },
  moments_50:        { item_id: 20, icon: '🎋', name: '대나무 윷',        grade: 'B'   },
  moments_100:       { item_id: 31, icon: '🍡', name: '음식 말',          grade: 'A'   },
  moments_200:       { item_id: 22, icon: '💎', name: '크리스탈 윷',      grade: 'S'   },
  moments_500:       { item_id: 23, icon: '🔥', name: '불꽃 윷',          grade: 'SS'  },
  moments_1000:      { item_id: 15, icon: '💑', name: '커플 카드뒷면',    grade: 'SSS' },
  first_pin:         { item_id: 11, icon: '🌌', name: '우주 카드뒷면',    grade: 'A'   },
  pins_5:            { item_id: 12, icon: '❤️', name: '하트 카드뒷면',    grade: 'A'   },
  first_visit:       { item_id: 21, icon: '🏆', name: '황금 윷',          grade: 'A'   },
  visited_5:         { item_id: 13, icon: '✨', name: '황금 카드뒷면',    grade: 'S'   },
  visited_10:        { item_id: 33, icon: '👑', name: '왕관 말',          grade: 'SS'  },
  visited_20:        { item_id: 34, icon: '💏', name: '커플 말',          grade: 'SSS' },
  first_memory_card: { item_id: 32, icon: '⭐', name: '별 말',            grade: 'S'   },
  d100:              { item_id: 14, icon: '🌈', name: '무지개 카드뒷면',  grade: 'SS'  },
  d200:              { item_id: 33, icon: '👑', name: '왕관 말',          grade: 'SS'  },
  d365:              { item_id: 24, icon: '🎆', name: '전설의 윷',        grade: 'SSS' },
  d500:              { item_id: 34, icon: '💏', name: '커플 말',          grade: 'SSS' },
  d730:              { item_id: 15, icon: '💑', name: '커플 카드뒷면',    grade: 'SSS' },
  d1000:             { item_id: 24, icon: '🎆', name: '전설의 윷',        grade: 'SSS' },
  d1461:             { item_id: 34, icon: '💏', name: '커플 말',          grade: 'SSS' },
};

async function computeMilestones(coupleId) {
  const coupleResult = await query(
    `SELECT COALESCE(StartDate, DATE(ActivatedAt)) AS startDate
     FROM Couples WHERE CoupleId = ? LIMIT 1`,
    [coupleId],
  );
  const startDate = coupleResult.rows[0]?.startDate ?? null;

  const postsResult = await query(
    `SELECT id, captured_at,
            ROW_NUMBER() OVER (ORDER BY captured_at ASC) AS rn
     FROM setlog_posts WHERE couple_id = ?`,
    [coupleId],
  );
  const postRows = postsResult.rows;
  const postByRank = (n) => postRows.find((r) => Number(r.rn) === n) ?? null;

  const firstPinResult = await query(
    `SELECT MIN(created_at) AS first_pin_at, COUNT(*) AS cnt
     FROM map_pins WHERE couple_id = ?`,
    [coupleId],
  );
  const firstPinAt = firstPinResult.rows[0]?.first_pin_at ?? null;
  const pinsCount = Number(firstPinResult.rows[0]?.cnt ?? 0);

  const visitsResult = await query(
    `SELECT id, visit_date,
            ROW_NUMBER() OVER (ORDER BY visit_date ASC) AS rn
     FROM afterglow_visits WHERE couple_id = ?`,
    [coupleId],
  );
  const visitRows = visitsResult.rows;
  const visitByRank = (n) => visitRows.find((r) => Number(r.rn) === n) ?? null;

  const memoryCardResult = await query(
    `SELECT MIN(a.captured_at) AS first_discovery
     FROM setlog_posts a
     JOIN setlog_posts b
       ON b.couple_id = a.couple_id
          AND DATE_FORMAT(b.captured_at, '%m-%d') = DATE_FORMAT(a.captured_at, '%m-%d')
          AND YEAR(b.captured_at) <> YEAR(a.captured_at)
     WHERE a.couple_id = ?`,
    [coupleId],
  );
  const firstMemoryCardAt = memoryCardResult.rows[0]?.first_discovery ?? null;

  const toDate = (v) => {
    if (!v) return null;
    if (typeof v === 'string') return v.slice(0, 10);
    if (v instanceof Date) return v.toISOString().slice(0, 10);
    return String(v).slice(0, 10);
  };

  const ms = (type, label, achievedAt, value = null) => ({
    type,
    label,
    achieved: achievedAt !== null,
    achieved_at: toDate(achievedAt),
    value: value !== null ? value : undefined,
  });

  const d = (n) => (startDate ? shiftDate(toDate(startDate), n - 1) : null);

  return [
    ms('first_moment',      '첫 번째 순간',       postByRank(1)?.captured_at    ?? null),
    ms('moments_10',        '10번째 순간',         postByRank(10)?.captured_at   ?? null),
    ms('moments_50',        '50번째 순간',         postByRank(50)?.captured_at   ?? null),
    ms('moments_100',       '100번째 순간',        postByRank(100)?.captured_at  ?? null),
    ms('moments_200',       '200번째 순간',        postByRank(200)?.captured_at  ?? null),
    ms('moments_500',       '500번째 순간',        postByRank(500)?.captured_at  ?? null),
    ms('moments_1000',      '1000번째 순간',       postByRank(1000)?.captured_at ?? null),
    ms('first_pin',         '첫 번째 장소',        firstPinAt),
    ms('pins_5',            '5번째 장소',          pinsCount >= 5 ? firstPinAt : null),
    ms('first_visit',       '첫 번째 방문',        visitByRank(1)?.visit_date    ?? null),
    ms('visited_5',         '5번째 방문',          visitByRank(5)?.visit_date    ?? null),
    ms('visited_10',        '10번째 방문',         visitByRank(10)?.visit_date   ?? null),
    ms('visited_20',        '20번째 방문',         visitByRank(20)?.visit_date   ?? null),
    ms('first_memory_card', '첫 메모리 카드 발견', firstMemoryCardAt),
    ms('d100',   '100일',  d(100)),
    ms('d200',   '200일',  d(200)),
    ms('d365',   '1주년',  d(365)),
    ms('d500',   '500일',  d(500)),
    ms('d730',   '2주년',  d(730)),
    ms('d1000',  '1000일', d(1000)),
    ms('d1461',  '4주년',  d(1461)),
  ];
}

router.get('/retention/secret-base/milestones', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    const [milestones, claimedSet] = await Promise.all([
      computeMilestones(coupleId),
      query('SELECT milestone_type FROM milestone_claims WHERE couple_id = ?', [coupleId])
        .then((r) => new Set(r.rows.map((x) => x.milestone_type))),
    ]);

    const result = milestones.map((m) => ({
      ...m,
      reward: MILESTONE_REWARDS[m.type] ?? null,
      claimed: claimedSet.has(m.type),
    }));

    res.json({ ok: true, milestones: result });
  } catch (err) {
    console.error('[API] /retention/secret-base/milestones GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/retention/secret-base/milestones/:type/claim
router.post('/retention/secret-base/milestones/:type/claim', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    const { type } = req.params;
    const reward = MILESTONE_REWARDS[type];
    if (!reward) return res.status(404).json({ ok: false, reason: 'unknown_milestone' });

    const milestones = await computeMilestones(coupleId);
    const milestone = milestones.find((m) => m.type === type);
    if (!milestone?.achieved) {
      return res.status(400).json({ ok: false, reason: 'not_achieved' });
    }

    const { rows: existing } = await query(
      'SELECT id FROM milestone_claims WHERE couple_id = ? AND milestone_type = ?',
      [coupleId, type],
    );
    if (existing.length > 0) {
      return res.status(409).json({ ok: false, reason: 'already_claimed' });
    }

    await transaction(async (conn) => {
      await conn.execute(
        `INSERT INTO owned_items (user_id, item_id)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE item_id = item_id`,
        [userId, reward.item_id],
      );
      await conn.execute(
        'INSERT INTO milestone_claims (couple_id, milestone_type, item_id) VALUES (?, ?, ?)',
        [coupleId, type, reward.item_id],
      );
    });

    res.json({ ok: true, item_id: reward.item_id, item_name: reward.name, item_icon: reward.icon });
  } catch (err) {
    console.error('[API] /retention/secret-base/milestones/:type/claim POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── MVP4: Base Postcard ───────────────────────────────────────────────────────

router.get('/retention/secret-base/postcard/:year/:month', async (req, res) => {
  try {
    const userId = req.auth.userId;
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }

    const year = Math.trunc(Number(req.params.year));
    const month = Math.trunc(Number(req.params.month));
    if (!Number.isFinite(year) || !Number.isFinite(month) || month < 1 || month > 12 || year < 2000 || year > 2100) {
      return res.status(400).json({ ok: false, reason: 'invalid_year_month' });
    }

    const monthStr = String(month).padStart(2, '0');
    const rangeStart = `${year}-${monthStr}-01`;
    const rangeEnd = `${year}-${monthStr}-31`; // MySQL handles last-day clamping in BETWEEN

    // moments count
    const momentsResult = await query(
      `SELECT COUNT(*) AS cnt FROM setlog_posts
       WHERE couple_id = ? AND captured_at >= ? AND captured_at < DATE_ADD(?, INTERVAL 1 MONTH)`,
      [coupleId, rangeStart, rangeStart],
    );
    const moments_count = Number(momentsResult.rows[0]?.cnt ?? 0);

    // visited count
    const visitedResult = await query(
      `SELECT COUNT(*) AS cnt FROM afterglow_visits
       WHERE couple_id = ? AND visit_date >= ? AND visit_date < DATE_ADD(?, INTERVAL 1 MONTH)`,
      [coupleId, rangeStart, rangeStart],
    );
    const visited_count = Number(visitedResult.rows[0]?.cnt ?? 0);

    // highlight post (prefer media, then most recent)
    const highlightResult = await query(
      `SELECT id, caption, media_url, captured_at
       FROM setlog_posts
       WHERE couple_id = ? AND captured_at >= ? AND captured_at < DATE_ADD(?, INTERVAL 1 MONTH)
       ORDER BY (media_url IS NOT NULL) DESC, captured_at DESC
       LIMIT 1`,
      [coupleId, rangeStart, rangeStart],
    );
    const highlightRaw = highlightResult.rows[0] ?? null;
    const highlight_post = highlightRaw
      ? {
          id: highlightRaw.id,
          caption: highlightRaw.caption,
          media_url: highlightRaw.media_url,
          captured_at: highlightRaw.captured_at,
        }
      : null;

    // visited places
    const placesResult = await query(
      `SELECT mp.id AS pin_id, mp.place_name, av.visit_date
       FROM afterglow_visits av
       JOIN map_pins mp ON mp.id = av.map_pin_id
       WHERE av.couple_id = ? AND av.visit_date >= ? AND av.visit_date < DATE_ADD(?, INTERVAL 1 MONTH)
       ORDER BY av.visit_date ASC`,
      [coupleId, rangeStart, rangeStart],
    );
    const visited_places = placesResult.rows.map((r) => ({
      pin_id: r.pin_id,
      place_name: r.place_name,
      visit_date: r.visit_date instanceof Date ? r.visit_date.toISOString().slice(0, 10) : String(r.visit_date).slice(0, 10),
    }));

    res.json({
      ok: true,
      postcard: {
        year,
        month,
        moments_count,
        visited_count,
        highlight_post,
        visited_places,
      },
    });
  } catch (err) {
    console.error('[API] /retention/secret-base/postcard GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

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
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const result = await query(
      'SELECT * FROM map_pins WHERE couple_id = ? AND archived_at IS NULL ORDER BY visit_date DESC, created_at DESC',
      [coupleId],
    );
    res.json({
      ok: true,
      pins: result.rows.map((pin) => ({
        ...pin,
        visit_date: dateOnly(pin.visit_date),
      })),
    });
  } catch (err) {
    console.error('[API] /map GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 생성 (lat/lng 선택사항, couple_id 자동 설정)
router.post('/map', upload.single('media'), async (req, res) => {
  try {
    await ensureTables();
    const { place_name, latitude, longitude, category, rating, visit_date, memo, status, emotion_tags } = req.body;

    if (!place_name) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const uid = req.auth.userId;
    const coupleId = await getCoupleIdForUser(uid);
    if (!coupleId) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    const userResult = await query('SELECT UserCode FROM Users WHERE UserId = ? LIMIT 1', [uid]);
    const createdBy = userResult.rows[0]?.UserCode;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : (req.body.media_url || null);

    const result = await query(
      `INSERT INTO map_pins (place_name, latitude, longitude, category, rating, visit_date, memo, created_by, user_id, couple_id, status, emotion_tags, media_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        place_name,
        latitude ?? 0,
        longitude ?? 0,
        category ?? null,
        rating ?? null,
        visit_date ?? null,
        memo ?? null,
        createdBy,
        uid,
        coupleId,
        status ?? null,
        emotion_tags ? (typeof emotion_tags === 'string' ? emotion_tags : JSON.stringify(emotion_tags)) : null,
        mediaUrl,
      ]
    );

    res.json({ ok: true, id: result.rows.insertId, media_url: mediaUrl });
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

// 지도 핀 업데이트 (활성 커플 공동 편집)
router.patch('/map/:id', upload.single('media'), async (req, res) => {
  try {
    await ensureTables();
    const { id } = req.params;
    const editorUserId = getAuthenticatedUserId(req);
    if (!editorUserId) {
      return res.status(401).json({ ok: false, reason: 'unauthorized' });
    }

    const { pin } = await loadMapPinForEditor(id, editorUserId);
    if (!pin) {
      return res.status(404).json({ ok: false, reason: 'not_found' });
    }
    if (pin.archived_at) {
      return res.status(404).json({ ok: false, reason: 'not_found' });
    }
    const coupleId = await getCoupleIdForUser(editorUserId);
    if (!coupleId || Number(pin.couple_id) !== Number(coupleId)) {
      return res.status(403).json({ ok: false, reason: 'forbidden' });
    }

    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : req.body.media_url;

    const allowedFields = {
      rating: req.body.rating ?? null,
      memo: req.body.memo ?? null,
      visit_date: req.body.visit_date ?? null,
      status: req.body.status ?? null,
      emotion_tags: Object.prototype.hasOwnProperty.call(req.body, 'emotion_tags')
        ? parseMapEmotionTags(req.body.emotion_tags)
        : null,
      media_url: mediaUrl ?? null,
    };

    if (allowedFields.status && !['visited', 'wishlist'].includes(allowedFields.status)) {
      return res.status(400).json({ ok: false, reason: 'invalid_status' });
    }

    const updates = [];
    const params = [];
    for (const [field, value] of Object.entries(allowedFields)) {
      if (!Object.prototype.hasOwnProperty.call(req.body, field) && !(field === 'media_url' && req.file)) continue;
      updates.push(`${field} = ?`);
      params.push(value);
    }

    if (updates.length === 0) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const updated = await transaction(async (connection) => {
      const [lockedPins] = await connection.execute(
        `SELECT id FROM map_pins
         WHERE id = ? AND couple_id = ? AND archived_at IS NULL
         LIMIT 1 FOR UPDATE`,
        [id, coupleId],
      );
      if (!lockedPins[0]) return false;
      const [afterglowRows] = await connection.execute(
        'SELECT visit_date FROM afterglow_visits WHERE map_pin_id = ? LIMIT 1',
        [id],
      );
      const afterglowVisitDate = dateOnly(afterglowRows[0]?.visit_date);
      if (afterglowVisitDate) {
        const requestedStatus = Object.prototype.hasOwnProperty.call(req.body, 'status')
          ? req.body.status
          : 'visited';
        const requestedVisitDate = Object.prototype.hasOwnProperty.call(req.body, 'visit_date')
          ? String(req.body.visit_date || '').slice(0, 10)
          : afterglowVisitDate;
        if (requestedStatus !== 'visited' || requestedVisitDate !== afterglowVisitDate) {
          throw new AfterglowRequestError(409, 'afterglow_visit_managed');
        }
      }
      await connection.execute(
        `UPDATE map_pins SET ${updates.join(', ')}, updated_at = NOW() WHERE id = ?`,
        [...params, id],
      );
      return true;
    });
    if (!updated) return res.status(403).json({ ok: false, reason: 'forbidden' });

    res.json({ ok: true });
  } catch (err) {
    if (sendAfterglowError(res, err)) return;
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
    const activeCoupleId = await getCoupleIdForUser(editorUserId);
    if (!activeCoupleId || Number(pin.couple_id) !== Number(activeCoupleId) || pin.archived_at) {
      return res.status(403).json({ ok: false, reason: 'forbidden' });
    }

    const linked = await transaction(async (connection) => {
      const [lockedPins] = await connection.execute(
        `SELECT id FROM map_pins
         WHERE id = ? AND couple_id = ? AND archived_at IS NULL
         LIMIT 1 FOR UPDATE`,
        [id, activeCoupleId],
      );
      if (!lockedPins[0]) return null;
      const [links] = await connection.execute(
        `SELECT
           (SELECT COUNT(*) FROM setlog_posts WHERE map_pin_id = ?) +
           (SELECT COUNT(*) FROM afterglow_visits WHERE map_pin_id = ?) AS count`,
        [id, id],
      );
      const hasLinks = Number(links[0]?.count) > 0;
      if (hasLinks) {
        await connection.execute(
          'UPDATE map_pins SET archived_at = CURRENT_TIMESTAMP WHERE id = ?',
          [id],
        );
      } else {
        await connection.execute('DELETE FROM map_pins WHERE id = ?', [id]);
      }
      return hasLinks;
    });
    if (linked == null) return res.status(403).json({ ok: false, reason: 'forbidden' });
    res.json({ ok: true, archived: linked });
  } catch (err) {
    console.error('[API] /map DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── 비밀장소 리뷰 ──────────────────────────────────────────────────────────

router.get('/map/:id/reviews', async (req, res) => {
  try {
    await ensureTables();
    const pinId = Number(req.params.id);
    const coupleId = await getCoupleIdForUser(req.auth.userId);
    if (!coupleId) return res.status(409).json({ ok: false, reason: 'active_couple_required' });

    const pinCheck = await query(
      'SELECT id FROM map_pins WHERE id = ? AND couple_id = ? AND archived_at IS NULL',
      [pinId, coupleId],
    );
    if (!pinCheck.rows.length) return res.status(404).json({ ok: false, reason: 'not_found' });

    const result = await query(
      `SELECT r.id, r.user_id, r.user_code, r.content, r.media_url, r.created_at
       FROM map_pin_reviews r
       WHERE r.map_pin_id = ? AND r.couple_id = ?
       ORDER BY r.created_at ASC`,
      [pinId, coupleId],
    );
    res.json({ ok: true, reviews: result.rows });
  } catch (err) {
    console.error('[API] /map/:id/reviews GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/map/:id/reviews', upload.single('media'), async (req, res) => {
  try {
    await ensureTables();
    const pinId = Number(req.params.id);
    const uid = req.auth.userId;
    const coupleId = await getCoupleIdForUser(uid);
    if (!coupleId) return res.status(409).json({ ok: false, reason: 'active_couple_required' });

    const pinCheck = await query(
      'SELECT id FROM map_pins WHERE id = ? AND couple_id = ? AND archived_at IS NULL',
      [pinId, coupleId],
    );
    if (!pinCheck.rows.length) return res.status(404).json({ ok: false, reason: 'not_found' });

    const content = (req.body.content ?? '').trim() || null;
    const mediaUrl = req.file ? `/uploads/${req.file.filename}` : null;
    if (!content && !mediaUrl) {
      return res.status(400).json({ ok: false, reason: 'content_or_media_required' });
    }

    const userResult = await query('SELECT UserCode FROM Users WHERE UserId = ? LIMIT 1', [uid]);
    const userCode = userResult.rows[0]?.UserCode ?? null;

    const result = await query(
      `INSERT INTO map_pin_reviews (map_pin_id, user_id, couple_id, user_code, content, media_url)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [pinId, uid, coupleId, userCode, content, mediaUrl],
    );
    res.json({ ok: true, id: result.rows.insertId, media_url: mediaUrl });
  } catch (err) {
    console.error('[API] /map/:id/reviews POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.delete('/map/:id/reviews/:reviewId', async (req, res) => {
  try {
    await ensureTables();
    const pinId = Number(req.params.id);
    const reviewId = Number(req.params.reviewId);
    const uid = req.auth.userId;
    const coupleId = await getCoupleIdForUser(uid);
    if (!coupleId) return res.status(409).json({ ok: false, reason: 'active_couple_required' });

    const reviewCheck = await query(
      'SELECT user_id FROM map_pin_reviews WHERE id = ? AND map_pin_id = ? AND couple_id = ?',
      [reviewId, pinId, coupleId],
    );
    if (!reviewCheck.rows.length) return res.status(404).json({ ok: false, reason: 'not_found' });
    if (reviewCheck.rows[0].user_id !== uid) return res.status(403).json({ ok: false, reason: 'forbidden' });

    await query('DELETE FROM map_pin_reviews WHERE id = ?', [reviewId]);
    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /map/:id/reviews DELETE error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const requirePairingWait = async (req, res) => {
  const activeCoupleId = await getCoupleIdForUser(req.auth.userId);
  if (activeCoupleId) {
    res.status(409).json({ ok: false, reason: 'personal_history_requires_pairing_wait' });
    return false;
  }
  return true;
};

const loadPersonalHistory = async (userId) => {
  const moments = await query(
    `SELECT p.*, mp.place_name AS linked_place_name
     FROM setlog_posts p
     LEFT JOIN Couples c ON c.CoupleId = p.couple_id
     LEFT JOIN map_pins mp ON mp.id = p.map_pin_id
     WHERE p.user_id = ? AND (c.Status = 'inactive' OR c.CoupleId IS NULL)
     ORDER BY p.captured_at DESC, p.id DESC`,
    [userId],
  );
  const pins = await query(
    `SELECT p.* FROM map_pins p
     LEFT JOIN Couples c ON c.CoupleId = p.couple_id
     WHERE p.user_id = ? AND (c.Status = 'inactive' OR c.CoupleId IS NULL)
       AND p.archived_at IS NULL
     ORDER BY p.created_at DESC, p.id DESC`,
    [userId],
  );
  return { moments: moments.rows, pins: pins.rows };
};

router.get('/history', async (req, res) => {
  try {
    if (!await requirePairingWait(req, res)) return;
    res.json({ ok: true, ...await loadPersonalHistory(req.auth.userId) });
  } catch (error) {
    console.error('[API] /history GET error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.delete('/history/moments/:id', async (req, res) => {
  try {
    if (!await requirePairingWait(req, res)) return;
    const result = await query(
      `SELECT p.id, p.media_url FROM setlog_posts p
       LEFT JOIN Couples c ON c.CoupleId = p.couple_id
       WHERE p.id = ? AND p.user_id = ?
         AND (c.Status = 'inactive' OR c.CoupleId IS NULL) LIMIT 1`,
      [req.params.id, req.auth.userId],
    );
    const moment = result.rows[0];
    if (!moment) return res.status(404).json({ ok: false, reason: 'history_not_found' });
    await query('DELETE FROM setlog_posts WHERE id = ?', [moment.id]);
    const filePath = mediaFilePath(moment.media_url);
    if (filePath) await fs.promises.rm(filePath, { force: true });
    res.json({ ok: true });
  } catch (error) {
    console.error('[API] history moment DELETE error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.delete('/history/pins/:id', async (req, res) => {
  try {
    if (!await requirePairingWait(req, res)) return;
    const result = await query(
      `SELECT p.id FROM map_pins p
       LEFT JOIN Couples c ON c.CoupleId = p.couple_id
       WHERE p.id = ? AND p.user_id = ? AND p.archived_at IS NULL
         AND (c.Status = 'inactive' OR c.CoupleId IS NULL) LIMIT 1`,
      [req.params.id, req.auth.userId],
    );
    const pin = result.rows[0];
    if (!pin) return res.status(404).json({ ok: false, reason: 'history_not_found' });
    const links = await query('SELECT COUNT(*) AS count FROM setlog_posts WHERE map_pin_id = ?', [pin.id]);
    if (Number(links.rows[0]?.count) > 0) {
      await query('UPDATE map_pins SET archived_at = CURRENT_TIMESTAMP WHERE id = ?', [pin.id]);
    } else {
      await query('DELETE FROM map_pins WHERE id = ?', [pin.id]);
    }
    res.json({ ok: true });
  } catch (error) {
    console.error('[API] history pin DELETE error:', error);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/history/export', async (req, res) => {
  try {
    if (!await requirePairingWait(req, res)) return;
    const history = await loadPersonalHistory(req.auth.userId);
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', 'attachment; filename="secretbase-personal-history.zip"');
    const archive = new ZipArchive({ zlib: { level: 9 } });
    archive.on('warning', (error) => console.warn('[Export] skipped media:', error.message));
    archive.on('error', (error) => res.destroy(error));
    archive.pipe(res);
    archive.append(JSON.stringify(history.moments, null, 2), { name: 'momentloop.json' });
    archive.append(JSON.stringify(history.pins, null, 2), { name: 'map-pins.json' });
    for (const moment of history.moments) {
      const filePath = mediaFilePath(moment.media_url);
      if (filePath && fs.existsSync(filePath)) {
        archive.file(filePath, { name: `media/${moment.id}-${path.basename(filePath)}` });
      }
    }
    await archive.finalize();
  } catch (error) {
    console.error('[API] history export error:', error);
    if (!res.headersSent) res.status(500).json({ ok: false, reason: 'internal_error' });
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

const previousDateString = (date) => {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - 1);
  return businessDate(value);
};

const getOrCreateTodayQuestion = async () => {
  const today = businessDate();
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
  eventDate = businessDate(),
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

    const today = businessDate();
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
      const today = businessDate();
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
      eventDate: businessDate(),
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
      eventDate: businessDate(),
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
    const month = String(req.query.month || businessDate().slice(0, 7));
    if (!userId || !/^\d{4}-\d{2}$/.test(month)) {
      return res.status(400).json({ ok: false, reason: 'invalid_request' });
    }
    const coupleId = await getCoupleIdForUser(userId);
    if (!coupleId) return res.json({ ok: true, report: null });

    const startDate = `${month}-01`;
    const endDate = businessDate(new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 1)));
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
    const today = businessDate();
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
    const today = businessDate();
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
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(start_date ?? ''))) {
      return res.status(400).json({ ok: false, reason: 'invalid_start_date' });
    }

    const couple = await query(
      `SELECT CoupleId FROM Couples
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)
       LIMIT 1`,
      [userId, userId],
    );
    if (couple.rows.length === 0) {
      return res.status(404).json({ ok: false, reason: 'couple_not_found' });
    }

    await query(
      `UPDATE Couples SET StartDate = ?
       WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)`,
      [start_date, userId, userId]
    );

    res.json({
      ok: true,
      coupleId: couple.rows[0].CoupleId,
      startDate: String(start_date),
    });
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

    const archive = new ZipArchive({ zlib: { level: 9 } });
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

// ── 게임 기록 ────────────────────────────────────────────────────
router.get('/arcade/records', async (req, res) => {
  try {
    const { game_type } = req.query;
    const userCode = req.auth.userCode;
    if (!userCode) return res.status(400).json({ ok: false, reason: 'no_user_code' });

    // 내 커플 ID 조회
    const { rows: coupleRows } = await query(
      `SELECT c.CoupleId FROM Couples c
       JOIN Users u ON (c.User1Id = u.UserId OR c.User2Id = u.UserId)
       WHERE u.UserCode = ? AND c.Status = 'active' LIMIT 1`,
      [userCode],
    );
    if (!coupleRows[0]) return res.json({ ok: true, records: {} });
    const coupleId = coupleRows[0].CoupleId;

    const typeFilter = game_type ? 'AND game_type = ?' : '';
    const params = game_type ? [coupleId, game_type] : [coupleId];
    const { rows } = await query(
      `SELECT game_type,
              SUM(winner_user_code = ?) AS wins,
              SUM(loser_user_code = ?)  AS losses,
              COUNT(*)                  AS total
       FROM game_results
       WHERE couple_id = ? ${typeFilter}
       GROUP BY game_type`,
      [userCode, userCode, ...params],
    );

    const records = {};
    for (const r of rows) {
      records[r.game_type] = {
        wins: Number(r.wins),
        losses: Number(r.losses),
        total: Number(r.total),
      };
    }
    res.json({ ok: true, records });
  } catch (err) {
    console.error('[API] /arcade/records GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── 재화(Wallet) ────────────────────────────────────────────────
import { getBalance, claimDailyBonus } from './wallet-engine.js';

router.get('/wallet/balance', async (req, res) => {
  try {
    const wallet = await getBalance(req.auth.userId);
    res.json({ ok: true, balance: wallet.balance, last_bonus_date: wallet.last_bonus_date });
  } catch (err) {
    console.error('[API] /wallet/balance GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/wallet/daily-bonus', async (req, res) => {
  try {
    const result = await claimDailyBonus(req.auth.userId);
    res.json({ ok: true, ...result });
  } catch (err) {
    console.error('[API] /wallet/daily-bonus POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── 상점(Shop) ───────────────────────────────────────────────────────────────
import { transferGameReward } from './wallet-engine.js';

// GET /api/shop/items — full catalog with grade, slot, game, and stats
router.get('/shop/items', async (req, res) => {
  try {
    const { rows: items } = await query(
      `SELECT id, category, game, slot, grade, name, description, price, icon, character_id
       FROM shop_items WHERE active = 1 ORDER BY game, slot, grade, id`
    );
    const { rows: statRows } = await query(
      `SELECT item_id, stat_key, stat_value FROM item_stats
       WHERE item_id IN (${items.map(() => '?').join(',') || '0'})`,
      items.map((i) => i.id)
    );
    const statsMap = {};
    for (const s of statRows) {
      (statsMap[s.item_id] ??= []).push({ key: s.stat_key, value: Number(s.stat_value) });
    }
    const result = items.map((i) => ({ ...i, stats: statsMap[i.id] ?? [] }));
    res.json({ ok: true, items: result });
  } catch (err) {
    console.error('[API] /shop/items GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// GET /api/shop/owned — items owned by this user (personal, not couple)
router.get('/shop/owned', async (req, res) => {
  try {
    const { rows: owned } = await query(
      `SELECT oi.item_id, oi.quantity, si.name, si.category, si.game, si.slot, si.grade, si.icon, si.character_id,
              ei.slot IS NOT NULL AS is_equipped,
              (SELECT JSON_OBJECTAGG(ist2.stat_key, ist2.stat_value)
               FROM item_stats ist2 WHERE ist2.item_id = si.id) AS stats
       FROM owned_items oi
       JOIN shop_items si ON si.id = oi.item_id
       LEFT JOIN equipped_items ei ON ei.item_id = oi.item_id AND ei.user_id = ?
       WHERE oi.user_id = ?`,
      [req.auth.userId, req.auth.userId]
    );
    res.json({ ok: true, owned });
  } catch (err) {
    console.error('[API] /shop/owned GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// GET /api/shop/equipped?game=onecard — equipped items + aggregated stats for a game
router.get('/shop/equipped', async (req, res) => {
  try {
    const { game } = req.query;
    const gameFilter = game ? 'AND si.game = ?' : '';
    const params = game
      ? [req.auth.userId, game]
      : [req.auth.userId];
    const { rows: equipped } = await query(
      `SELECT ei.slot, si.id AS item_id, si.name, si.icon, si.grade, si.character_id,
              ist.stat_key, ist.stat_value
       FROM equipped_items ei
       JOIN shop_items si ON si.id = ei.item_id
       LEFT JOIN item_stats ist ON ist.item_id = ei.item_id
       WHERE ei.user_id = ? ${gameFilter}`,
      params
    );
    // Aggregate: slot → item info + flatten stats
    const slotsMap = {};
    const aggregatedStats = {};
    for (const row of equipped) {
      if (!slotsMap[row.slot]) {
        slotsMap[row.slot] = { item_id: row.item_id, name: row.name, icon: row.icon, grade: row.grade, character_id: row.character_id ?? null, stats: {} };
      }
      if (row.stat_key) {
        const val = Number(row.stat_value);
        slotsMap[row.slot].stats[row.stat_key] = (slotsMap[row.slot].stats[row.stat_key] ?? 0) + val;
        aggregatedStats[row.stat_key] = (aggregatedStats[row.stat_key] ?? 0) + val;
      }
    }
    res.json({ ok: true, slots: slotsMap, stats: aggregatedStats });
  } catch (err) {
    console.error('[API] /shop/equipped GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/shop/equip — equip an owned item to its slot
router.post('/shop/equip', async (req, res) => {
  try {
    const { item_id } = req.body ?? {};
    if (!item_id) return res.status(400).json({ ok: false, reason: 'missing_item_id' });

    // Verify ownership
    const { rows: ownedRows } = await query(
      'SELECT item_id FROM owned_items WHERE user_id = ? AND item_id = ?',
      [req.auth.userId, item_id]
    );
    if (!ownedRows[0]) return res.status(403).json({ ok: false, reason: 'not_owned' });

    const { rows: itemRows } = await query(
      'SELECT slot FROM shop_items WHERE id = ? AND active = 1',
      [item_id]
    );
    if (!itemRows[0]?.slot) return res.status(404).json({ ok: false, reason: 'item_not_found' });
    const { slot } = itemRows[0];

    await query(
      `INSERT INTO equipped_items (user_id, slot, item_id)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE item_id = VALUES(item_id), equipped_at = NOW()`,
      [req.auth.userId, slot, item_id]
    );
    res.json({ ok: true, slot, item_id });
  } catch (err) {
    console.error('[API] /shop/equip POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/shop/unequip — 슬롯 장착 해제 (기본 아이템으로 되돌리기)
router.post('/shop/unequip', async (req, res) => {
  try {
    const { slot } = req.body ?? {};
    if (!slot) return res.status(400).json({ ok: false, reason: 'missing_slot' });
    await query(
      'DELETE FROM equipped_items WHERE user_id = ? AND slot = ?',
      [req.auth.userId, slot]
    );
    res.json({ ok: true, slot });
  } catch (err) {
    console.error('[API] /shop/unequip POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/shop/buy — purchase item with coins (B/A grade only; S+ are gacha-only)
router.post('/shop/buy', async (req, res) => {
  try {
    const { item_id } = req.body ?? {};
    if (!item_id) return res.status(400).json({ ok: false, reason: 'missing_item_id' });

    const { rows: itemRows } = await query(
      `SELECT id, category, game, slot, grade, name, price
       FROM shop_items WHERE id = ? AND active = 1`,
      [item_id]
    );
    const item = itemRows[0];
    if (!item) return res.status(404).json({ ok: false, reason: 'item_not_found' });
    if (['S', 'SS', 'SSS'].includes(item.grade)) {
      return res.status(400).json({ ok: false, reason: 'gacha_only' });
    }

    // 장착 아이템의 shop_discount_pct 적용 (최대 20%)
    const { rows: statRows } = await query(
      `SELECT SUM(ist.stat_value) AS discount
       FROM equipped_items ei
       JOIN item_stats ist ON ist.item_id = ei.item_id
       WHERE ei.user_id = ? AND ist.stat_key = 'shop_discount_pct'`,
      [req.auth.userId]
    );
    const discountPct = Math.min(statRows[0]?.discount ?? 0, 20);
    const finalPrice = Math.floor(item.price * (1 - discountPct / 100));

    // Spend coins atomically (debit from buyer; skin ownership is per-user)
    let newBalance;
    try {
      newBalance = await transaction(async (conn) => {
        const [[wallet]] = await conn.execute(
          'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
          [req.auth.userId]
        );
        if (!wallet || wallet.balance < finalPrice) {
          const err = new Error('insufficient_coins');
          err.code = 'INSUFFICIENT_COINS';
          throw err;
        }
        const after = wallet.balance - finalPrice;
        await conn.execute(
          'UPDATE wallets SET balance = ? WHERE user_id = ?',
          [after, req.auth.userId]
        );
        await conn.execute(
          `INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id)
           VALUES (?, ?, ?, 'shop_purchase', ?)`,
          [req.auth.userId, -finalPrice, after, `shop:${item.id}`]
        );
        await conn.execute(
          `INSERT INTO owned_items (user_id, item_id, quantity)
           VALUES (?, ?, 1)
           ON DUPLICATE KEY UPDATE quantity = quantity + 1`,
          [req.auth.userId, item.id]
        );
        return after;
      });
    } catch (e) {
      if (e.code === 'INSUFFICIENT_COINS') {
        return res.status(400).json({ ok: false, reason: 'insufficient_coins' });
      }
      throw e;
    }

    // fire-and-forget mission progress
    updateMissionProgress(req.auth.userId, 'item_buy').catch(() => {});

    res.json({ ok: true, new_balance: newBalance, paid: finalPrice, discount_pct: discountPct });
  } catch (err) {
    console.error('[API] /shop/buy POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// GET /api/shop/coupons — date coupons for this user
router.get('/shop/coupons', async (req, res) => {
  try {
    const { rows: coupons } = await query(
      `SELECT id, issuer_user_code, receiver_user_code, title, description,
              status, issued_at, expires_at, redeemed_at
       FROM date_coupons
       WHERE receiver_user_code = ? AND status = 'pending'
         AND expires_at > NOW()
       ORDER BY issued_at DESC`,
      [req.auth.userCode]
    );
    res.json({ ok: true, coupons });
  } catch (err) {
    console.error('[API] /shop/coupons GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/shop/coupons/redeem — receiver redeems coupon
router.post('/shop/coupons/redeem', async (req, res) => {
  try {
    const { coupon_id } = req.body ?? {};
    if (!coupon_id) return res.status(400).json({ ok: false, reason: 'missing_coupon_id' });

    const result = await query(
      `UPDATE date_coupons SET status = 'redeemed', redeemed_at = NOW()
       WHERE id = ? AND receiver_user_code = ? AND status = 'pending' AND expires_at > NOW()`,
      [coupon_id, req.auth.userCode]
    );
    if (!result.rows.affectedRows) return res.status(400).json({ ok: false, reason: 'not_redeemable' });

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /shop/coupons/redeem POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/shop/coupons/issue — buyer sends a date coupon
router.post('/shop/coupons/issue', async (req, res) => {
  try {
    const { title, description, template_id } = req.body ?? {};
    if (!title) return res.status(400).json({ ok: false, reason: 'missing_title' });

    const COUPON_COST = 500;

    // Find partner
    const { rows: coupleRows } = await query(
      `SELECT c.CoupleId,
              CASE WHEN u.UserId = c.User1Id THEN u2.UserCode ELSE u1.UserCode END AS partnerCode
       FROM Couples c
       JOIN Users u  ON u.UserCode  = ?
       JOIN Users u1 ON u1.UserId   = c.User1Id
       JOIN Users u2 ON u2.UserId   = c.User2Id
       WHERE u.UserId = c.User1Id OR u.UserId = c.User2Id LIMIT 1`,
      [req.auth.userCode]
    );
    const coupleRow = coupleRows[0];
    if (!coupleRow) return res.status(400).json({ ok: false, reason: 'no_couple' });

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    let newBalance;
    try {
      newBalance = await transaction(async (conn) => {
        const [[wallet]] = await conn.execute(
          'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
          [req.auth.userId]
        );
        if (!wallet || wallet.balance < COUPON_COST) {
          const err = new Error('insufficient_coins');
          err.code = 'INSUFFICIENT_COINS';
          throw err;
        }
        const after = wallet.balance - COUPON_COST;
        await conn.execute(
          'UPDATE wallets SET balance = ? WHERE user_id = ?',
          [after, req.auth.userId]
        );
        await conn.execute(
          `INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id)
           VALUES (?, ?, ?, 'coupon_purchase', NULL)`,
          [req.auth.userId, -COUPON_COST, after]
        );
        await conn.execute(
          `INSERT INTO date_coupons
             (couple_id, issuer_user_code, receiver_user_code, template_id, title, description, expires_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [coupleRow.CoupleId, req.auth.userCode, coupleRow.partnerCode,
           template_id ?? null, title, description ?? null, expiresAt]
        );
        return after;
      });
    } catch (e) {
      if (e.code === 'INSUFFICIENT_COINS') {
        return res.status(400).json({ ok: false, reason: 'insufficient_coins' });
      }
      throw e;
    }

    res.json({ ok: true, new_balance: newBalance });
  } catch (err) {
    console.error('[API] /shop/coupons/issue POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ── 레벨/미션/가챠 ──────────────────────────────────────────────────────────
import {
  getUserLevel,
  getMissions,
  claimMission,
  pullGacha,
  updateMissionProgress,
} from './level-engine.js';

// GET /api/user/level — { level, xp, xpNeeded, tickets }
router.get('/user/level', async (req, res) => {
  try {
    const data = await getUserLevel(req.auth.userId);
    res.json({ ok: true, ...data });
  } catch (err) {
    console.error('[API] /user/level GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// GET /api/missions — 전체 미션 + 진행 상태
router.get('/missions', async (req, res) => {
  try {
    const missions = await getMissions(req.auth.userId);
    res.json({ ok: true, missions });
  } catch (err) {
    console.error('[API] /missions GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// POST /api/missions/:id/claim — 완료된 미션 보상 수령
router.post('/missions/:id/claim', async (req, res) => {
  const templateId = parseInt(req.params.id, 10);
  if (!templateId) return res.status(400).json({ ok: false, reason: 'invalid_id' });
  try {
    const rewards = await claimMission(req.auth.userId, templateId);
    res.json({ ok: true, ...rewards });
  } catch (err) {
    const status = err.status ?? 500;
    console.error('[API] /missions/:id/claim POST error:', err);
    res.status(status).json({ ok: false, reason: err.message });
  }
});

// POST /api/shop/gacha — v2: 카테고리별 3티어 가챠
// Body: { game: 'yut'|'onecard', tier: 'normal'|'advanced'|'rare' }
router.post('/shop/gacha', async (req, res) => {
  try {
    const { game, tier } = req.body ?? {};
    if (!game || !['yut', 'onecard'].includes(game)) {
      return res.status(400).json({ ok: false, reason: 'invalid_game' });
    }
    if (!tier || !['normal', 'advanced', 'rare'].includes(tier)) {
      return res.status(400).json({ ok: false, reason: 'invalid_tier' });
    }

    const result = await transaction(async (conn) => {
      // 1. 가챠 티어 설정 로드
      const [tierRows] = await conn.execute(
        'SELECT grade, weight, cost FROM gacha_tiers WHERE tier = ? AND game = ? ORDER BY grade',
        [tier, game]
      );
      if (!tierRows.length) throw Object.assign(new Error('tier_not_found'), { status: 400 });

      const cost = tierRows[0].cost;

      // 2. 잔액 확인 및 차감
      const [[wallet]] = await conn.execute(
        'SELECT balance FROM wallets WHERE user_id = ? FOR UPDATE',
        [req.auth.userId]
      );
      if (!wallet || wallet.balance < cost) {
        throw Object.assign(new Error('insufficient_coins'), { status: 402 });
      }
      const newBalance = wallet.balance - cost;
      await conn.execute('UPDATE wallets SET balance = ? WHERE user_id = ?', [newBalance, req.auth.userId]);
      await conn.execute(
        `INSERT INTO wallet_transactions (user_id, delta, balance_after, reason, ref_id)
         VALUES (?, ?, ?, 'gacha_pull', ?)`,
        [req.auth.userId, -cost, newBalance, `gacha:${game}:${tier}`]
      );

      // 3. gacha_rate_up 스탯 확인 → 최고 등급 가중치 증폭 (최대 20%)
      const [[rateUpRow]] = await conn.execute(
        `SELECT COALESCE(SUM(ist.stat_value), 0) AS total
         FROM equipped_items ei
         JOIN item_stats ist ON ist.item_id = ei.item_id
         WHERE ei.user_id = ? AND ist.stat_key = 'gacha_rate_up'`,
        [req.auth.userId]
      );
      const rateUpPct = Math.min(Number(rateUpRow.total ?? 0), 20);

      // 가중치 기반 등급 결정 (tierRows는 grade 오름차순: B→SSS)
      const adjustedTiers = tierRows.map((r) => ({ ...r, weight: r.weight }));
      if (rateUpPct > 0 && adjustedTiers.length > 1) {
        const totalW = adjustedTiers.reduce((s, r) => s + r.weight, 0);
        const shift = Math.floor(totalW * rateUpPct / 100);
        adjustedTiers[0].weight = Math.max(0, adjustedTiers[0].weight - shift); // 최저 등급 감소
        adjustedTiers[adjustedTiers.length - 1].weight += shift;                // 최고 등급 증가
      }

      const totalWeight = adjustedTiers.reduce((sum, r) => sum + r.weight, 0);
      let roll = Math.floor(Math.random() * totalWeight);
      let selectedGrade = adjustedTiers[adjustedTiers.length - 1].grade;
      for (const row of adjustedTiers) {
        if (roll < row.weight) { selectedGrade = row.grade; break; }
        roll -= row.weight;
      }

      // 4. 해당 등급 + 게임 카테고리 아이템 중 랜덤 선택 (active 무관 — 가챠 전용 아이템 포함)
      const [itemRows] = await conn.execute(
        `SELECT id, name, description, icon, slot, grade,
                (SELECT JSON_OBJECTAGG(stat_key, stat_value) FROM item_stats WHERE item_id = shop_items.id) AS stats
         FROM shop_items
         WHERE game = ? AND grade = ?
         ORDER BY RAND() LIMIT 1`,
        [game, selectedGrade]
      );
      if (!itemRows.length) throw Object.assign(new Error('no_items_available'), { status: 500 });
      const item = itemRows[0];

      // 5. 보유 처리 (중복 시 quantity++)
      const [[existing]] = await conn.execute(
        'SELECT quantity FROM owned_items WHERE user_id = ? AND item_id = ?',
        [req.auth.userId, item.id]
      );
      const isNew = !existing;
      await conn.execute(
        `INSERT INTO owned_items (user_id, item_id, quantity)
         VALUES (?, ?, 1)
         ON DUPLICATE KEY UPDATE quantity = quantity + 1`,
        [req.auth.userId, item.id]
      );

      return {
        item: { ...item, stats: item.stats ? JSON.parse(item.stats) : {} },
        is_new: isNew,
        new_balance: newBalance,
        grade: selectedGrade,
      };
    });

    res.json({ ok: true, ...result });
  } catch (err) {
    const status = err.status ?? 500;
    console.error('[API] /shop/gacha POST error:', err);
    res.status(status).json({ ok: false, reason: err.message });
  }
});

// GET /api/shop/catalog — 도감: 전체 아이템 (미공개 포함), 보유 여부 포함
router.get('/shop/catalog', async (req, res) => {
  try {
    const { game } = req.query;
    const whereGame = game && ['yut', 'onecard'].includes(game) ? 'AND si.game = ?' : '';
    const params = game && ['yut', 'onecard'].includes(game) ? [req.auth.userId, game] : [req.auth.userId];

    const { rows } = await query(
      `SELECT si.id, si.game, si.slot, si.grade, si.name, si.description, si.icon, si.active,
              oi.quantity,
              (SELECT JSON_OBJECTAGG(stat_key, stat_value) FROM item_stats WHERE item_id = si.id) AS stats
       FROM shop_items si
       LEFT JOIN owned_items oi ON oi.item_id = si.id AND oi.user_id = ?
       WHERE 1=1 ${whereGame}
       ORDER BY si.game, si.slot, FIELD(si.grade,'B','A','S','SS','SSS'), si.id`,
      params
    );

    const items = rows.map(r => ({
      id: r.id,
      game: r.game,
      slot: r.slot,
      grade: r.grade,
      name: r.active ? r.name : '???',
      description: r.active ? r.description : null,
      icon: r.active ? r.icon : '❓',
      active: !!r.active,
      owned: (r.quantity ?? 0) > 0,
      quantity: r.quantity ?? 0,
      stats: r.active && r.stats ? JSON.parse(r.stats) : null,
    }));

    res.json({ ok: true, items });
  } catch (err) {
    console.error('[API] /shop/catalog GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// ---------------------------------------------------------------------------
// Relationship fortune and counseling
// ---------------------------------------------------------------------------

const relationshipDateTime = (value) => value instanceof Date
  ? value.toISOString()
  : value == null ? null : String(value);

const getBirthProfileByUserId = async (userId) => {
  const result = await query(
    `SELECT BirthDate, BirthCalendarType, BirthLunarLeapMonth, BirthTime, BirthTimezone, BirthPlace
     FROM Users WHERE UserId = ? LIMIT 1`,
    [userId],
  );
  return result.rows[0] ? birthProfileFromRow(result.rows[0]) : null;
};

const getActiveCoupleRow = async (userId) => {
  const result = await query(
    `SELECT CoupleId, User1Id, User2Id
     FROM Couples
     WHERE Status = 'active' AND (User1Id = ? OR User2Id = ?)
     LIMIT 1`,
    [userId, userId],
  );
  return result.rows[0] ?? null;
};

const parseRelationshipJson = (value) => {
  if (value == null) return null;
  if (typeof value === 'object') return value;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
};

const fortunePayload = (row) => {
  const result = parseRelationshipJson(row.result_json) ?? {};
  return {
    id: Number(row.fortune_id),
    type: row.fortune_type,
    date: dateOnly(row.content_date),
    version: row.content_version,
    status: row.status,
    provider: row.provider,
    model: row.model ?? null,
    promptVersion: row.prompt_version,
    contextVersion: row.context_version,
    createdAt: relationshipDateTime(row.created_at),
    updatedAt: relationshipDateTime(row.updated_at),
    result,
  };
};

const fortuneFallbackText = (type) => type === 'relationship'
  ? '오늘은 서로의 행동을 바로 해석하기보다 필요한 관심의 모양을 확인해보세요.'
  : type === 'emotional_flow'
  ? '오늘의 감정은 해결보다 이름 붙이기와 회복에 먼저 기대어보세요.'
  : '오늘은 감정과 부탁을 한 문장씩 나누며 내 마음의 속도를 살펴보세요.';

const createFortuneContent = async ({ type, date, result, profile, partnerProfile }) => {
  const provider = createExplanationProvider(config);
  const input = {
    sourceType: 'fortune',
    contentType: type,
    version: FORTUNE_CONTENT_VERSION,
    core: {
      title: result.title,
      summary: result.summary,
      suggestion: result.suggestion,
    },
    context: buildFortuneContext({ date, profile, partnerProfile }),
  };
  const generated = await buildRelationshipContentAttempt({
    provider,
    input,
    fallbackText: fortuneFallbackText(type),
  });
  return {
    ...result,
    generatedText: generated.text,
    generationStatus: generated.status,
    generationErrorCode: generated.errorCode,
  };
};

const readStoredFortune = async ({ userId = null, coupleId = null, date, type }) => {
  const scopeColumn = userId == null ? 'couple_id' : 'user_id';
  const scopeId = userId == null ? coupleId : userId;
  const result = await query(
    `SELECT fortune_id, content_date, fortune_type, content_version,
            provider, model, prompt_version, context_version, status,
            result_json, created_at, updated_at
     FROM relationship_fortune_contents
     WHERE ${scopeColumn} = ? AND content_date = ? AND fortune_type = ?
       AND content_version = ?
     LIMIT 1`,
    [scopeId, date, type, FORTUNE_CONTENT_VERSION],
  );
  return result.rows[0] ?? null;
};

const saveFortune = async ({ userId = null, coupleId = null, date, type, result, profile, partnerProfile, regenerate }) => {
  if (!regenerate) {
    const existing = await readStoredFortune({ userId, coupleId, date, type });
    if (existing) return fortunePayload(existing);
  }
  const generatedResult = await createFortuneContent({
    type,
    date,
    result,
    profile,
    partnerProfile,
  });
  const provider = createExplanationProvider(config);
  await query(
    `INSERT INTO relationship_fortune_contents
       (user_id, couple_id, content_date, fortune_type, content_version,
        provider, model, prompt_version, context_version, status, result_json)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       provider = VALUES(provider), model = VALUES(model),
       prompt_version = VALUES(prompt_version), context_version = VALUES(context_version),
       status = VALUES(status), result_json = VALUES(result_json),
       updated_at = CURRENT_TIMESTAMP`,
    [
      userId,
      coupleId,
      date,
      type,
      FORTUNE_CONTENT_VERSION,
      provider?.name ?? 'disabled',
      provider?.model ?? null,
      config.LLM_PROMPT_VERSION,
      config.LLM_CONTEXT_VERSION,
      generatedResult.generationStatus,
      JSON.stringify(generatedResult),
    ],
  );
  const stored = await readStoredFortune({ userId, coupleId, date, type });
  if (!stored) throw new Error('fortune_storage_failed');
  return fortunePayload(stored);
};

const loadFortuneProfilePair = async (userId, couple) => {
  const ownProfile = await getBirthProfileByUserId(userId);
  if (!couple) return { ownProfile, firstProfile: ownProfile, secondProfile: null };
  const firstProfile = await getBirthProfileByUserId(Number(couple.User1Id));
  const secondProfile = await getBirthProfileByUserId(Number(couple.User2Id));
  return { ownProfile, firstProfile, secondProfile };
};

const relationshipFortuneResult = ({ type, date, ownProfile, firstProfile, secondProfile }) => {
  if (type === 'personal') return buildPersonalFortune({ profile: ownProfile, date });
  if (type === 'emotional_flow') return buildEmotionalFlow({ profile: ownProfile, date });
  return buildRelationshipFortune({ firstProfile, secondProfile, date });
};

const loadTodayFortunes = async (userId, { regenerate = false, types = null } = {}) => {
  const date = businessDate();
  const couple = await getActiveCoupleRow(userId);
  const { ownProfile, firstProfile, secondProfile } = await loadFortuneProfilePair(userId, couple);
  const requestedTypes = types ?? ['personal', 'emotional_flow', ...(couple ? ['relationship'] : [])];
  const fortunes = {};
  for (const type of requestedTypes) {
    if (type === 'relationship' && !couple) continue;
    const isShared = type === 'relationship';
    fortunes[type] = await saveFortune({
      userId: isShared ? null : userId,
      coupleId: isShared ? Number(couple.CoupleId) : null,
      date,
      type,
      result: relationshipFortuneResult({
        type,
        date,
        ownProfile,
        firstProfile,
        secondProfile,
      }),
      profile: isShared ? firstProfile : ownProfile,
      partnerProfile: isShared ? secondProfile : null,
      regenerate,
    });
  }
  return {
    date,
    contentVersion: FORTUNE_CONTENT_VERSION,
    profileReady: Boolean(ownProfile?.birthDate),
    fortunes,
  };
};

const sajuPayload = (row) => {
  const result = parseRelationshipJson(row.result_json) ?? {};
  return {
    ...result,
    scope: 'user',
    status: row.status,
    calculationVersion: row.calculation_version,
    inputSummary: parseRelationshipJson(row.input_summary_json) ?? result.inputSummary ?? {},
  };
};

const readStoredSaju = async ({ userId, fingerprint, mode }) => {
  const result = await query(
    `SELECT calculation_version, mode, status, input_summary_json, result_json
     FROM relationship_saju_results
     WHERE user_id = ? AND calculation_version = ? AND input_fingerprint = ? AND mode = ?
     LIMIT 1`,
    [userId, SAJU_CALCULATION_VERSION, fingerprint, mode],
  );
  return result.rows[0] ?? null;
};

const saveSaju = async ({ userId, result, fingerprint }) => {
  await query(
    `INSERT INTO relationship_saju_results
       (user_id, calculation_version, input_fingerprint, mode, status,
        input_summary_json, result_json)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       status = VALUES(status), input_summary_json = VALUES(input_summary_json),
       result_json = VALUES(result_json), updated_at = CURRENT_TIMESTAMP`,
    [
      userId,
      result.calculationVersion,
      fingerprint,
      result.mode,
      result.status,
      JSON.stringify(result.inputSummary),
      JSON.stringify(result),
    ],
  );
  const stored = await readStoredSaju({ userId, fingerprint, mode: result.mode });
  if (!stored) throw new Error('saju_storage_failed');
  return sajuPayload(stored);
};

const sendSajuError = (res, error) => {
  if (!error?.code) return false;
  if (error.code === 'saju_limited_confirmation_required') {
    res.status(409).json({
      ok: false,
      status: 'limited',
      reason: error.code,
      missingFields: error.missingFields ?? [],
      limitations: error.limitations ?? [],
    });
    return true;
  }
  if (
    error.code === 'birth_profile_incomplete' ||
    error.code === 'unsupported_birth_date_range' ||
    error.code === 'relationship_saju_profile_incomplete' ||
    error.code === 'relationship_saju_unsupported_range'
  ) {
    res.status(422).json({
      ok: false,
      status: error.code.includes('unsupported') ? 'unsupported_range' : 'requires_profile',
      reason: error.code,
    });
    return true;
  }
  return false;
};

const calculateAndStorePersonalSaju = async (userId, mode) => {
  const profile = await getBirthProfileByUserId(userId);
  const result = calculatePersonalSaju({ profile, mode });
  const fingerprint = fingerprintSajuInput(profile);
  return saveSaju({ userId, result, fingerprint });
};

const relationshipSajuPayload = (row) => ({
  ...(parseRelationshipJson(row.result_json) ?? {}),
  scope: 'couple',
  status: row.status,
  calculationVersion: row.calculation_version,
});

const readStoredRelationshipSaju = async ({ coupleId, fingerprint, mode }) => {
  const result = await query(
    `SELECT calculation_version, mode, status, result_json
     FROM relationship_saju_couple_results
     WHERE couple_id = ? AND calculation_version = ? AND input_fingerprint = ? AND mode = ?
     LIMIT 1`,
    [coupleId, SAJU_CALCULATION_VERSION, fingerprint, mode],
  );
  return result.rows[0] ?? null;
};

const saveRelationshipSaju = async ({ coupleId, result, fingerprint }) => {
  await query(
    `INSERT INTO relationship_saju_couple_results
       (couple_id, calculation_version, input_fingerprint, mode, status, result_json)
     VALUES (?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       status = VALUES(status), result_json = VALUES(result_json),
       updated_at = CURRENT_TIMESTAMP`,
    [
      coupleId,
      result.calculationVersion,
      fingerprint,
      result.mode,
      result.status,
      JSON.stringify(result),
    ],
  );
  const stored = await readStoredRelationshipSaju({
    coupleId,
    fingerprint,
    mode: result.mode,
  });
  if (!stored) throw new Error('relationship_saju_storage_failed');
  return relationshipSajuPayload(stored);
};

const calculateAndStoreRelationshipSaju = async ({ couple, mode }) => {
  if (!couple) return null;
  const firstProfile = await getBirthProfileByUserId(Number(couple.User1Id));
  const secondProfile = await getBirthProfileByUserId(Number(couple.User2Id));
  const firstState = getSajuProfileState(firstProfile);
  const secondState = getSajuProfileState(secondProfile);
  const relationMode = mode === 'limited' || firstState.status !== 'ready' || secondState.status !== 'ready'
    ? 'limited'
    : 'complete';
  const result = buildRelationshipSaju({
    firstProfile,
    secondProfile,
    mode: relationMode,
  });
  const fingerprint = fingerprintSajuPair(firstProfile, secondProfile);
  return saveRelationshipSaju({
    coupleId: Number(couple.CoupleId),
    result: { ...result, calculationVersion: SAJU_CALCULATION_VERSION },
    fingerprint,
  });
};

router.get('/relationship/saju', async (req, res) => {
  try {
    const profile = await getBirthProfileByUserId(req.auth.userId);
    const state = getSajuProfileState(profile);
    if (state.status === 'requires_profile') {
      return res.status(422).json({
        ok: false,
        status: 'requires_profile',
        reason: 'birth_profile_incomplete',
      });
    }
    if (state.status === 'unsupported_range') {
      return res.status(422).json({
        ok: false,
        status: 'unsupported_range',
        reason: 'unsupported_birth_date_range',
        limitations: state.limitations,
      });
    }
    if (state.status !== 'ready') {
      return res.status(409).json({
        ok: false,
        status: 'limited',
        reason: 'saju_limited_confirmation_required',
        missingFields: state.missingFields,
        limitations: state.limitations,
      });
    }
    const personal = await calculateAndStorePersonalSaju(req.auth.userId, 'complete');
    const relationship = await calculateAndStoreRelationshipSaju({
      couple: await getActiveCoupleRow(req.auth.userId),
      mode: 'complete',
    });
    return res.json({
      ok: true,
      status: personal.status,
      calculationVersion: personal.calculationVersion,
      personal,
      relationship,
    });
  } catch (error) {
    if (sendSajuError(res, error)) return;
    console.error('[API] /relationship/saju GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/saju', async (req, res) => {
  try {
    const mode = String(req.body?.mode ?? '').trim();
    if (!['complete', 'limited'].includes(mode)) {
      return res.status(400).json({ ok: false, reason: 'invalid_saju_mode' });
    }
    const personal = await calculateAndStorePersonalSaju(req.auth.userId, mode);
    const relationship = await calculateAndStoreRelationshipSaju({
      couple: await getActiveCoupleRow(req.auth.userId),
      mode,
    });
    return res.json({
      ok: true,
      status: personal.status,
      calculationVersion: personal.calculationVersion,
      personal,
      relationship,
    });
  } catch (error) {
    if (sendSajuError(res, error)) return;
    console.error('[API] /relationship/saju POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const tarotPayload = (row, { scope, date }) => {
  const payload = parseRelationshipJson(row.result_json);
  const selectedByUser = Number(row.selected_by_user) === 1 || payload?.selectedByUser === true;
  if (!selectedByUser || !payload?.card) {
    return undrawnTarot({ scope, date });
  }
  return {
    ...payload,
    drawn: true,
    drawRequired: false,
    selectedByUser: true,
  };
};

const readStoredTarot = async ({ userId = null, coupleId = null, date }) => {
  const scopeColumn = userId == null ? 'couple_id' : 'user_id';
  const scopeId = userId == null ? coupleId : userId;
  const result = await query(
    `SELECT result_json, selected_by_user
     FROM relationship_tarot_contents
     WHERE ${scopeColumn} = ? AND content_date = ? AND catalog_version = ?
     LIMIT 1`,
    [scopeId, date, TAROT_CATALOG_VERSION],
  );
  return result.rows[0] ?? null;
};

const readCurrentTarot = async ({ userId = null, coupleId = null, date }) => {
  const scope = userId == null ? 'couple' : 'user';
  const existing = await readStoredTarot({ userId, coupleId, date });
  return existing
    ? tarotPayload(existing, { scope, date })
    : undrawnTarot({ scope, date });
};

const saveSelectedTarot = async ({ userId = null, coupleId = null, date, cardKey }) => {
  const scope = userId == null ? 'couple' : 'user';
  const existing = await readStoredTarot({ userId, coupleId, date });
  if (existing && Number(existing.selected_by_user) === 1) {
    const error = new Error('tarot_already_drawn');
    error.code = 'tarot_already_drawn';
    error.status = 409;
    throw error;
  }
  const result = drawSelectedTarot({ scope, date, cardKey });
  await query(
    `INSERT INTO relationship_tarot_contents
       (user_id, couple_id, content_date, catalog_version, card_key, result_json, selected_by_user)
     VALUES (?, ?, ?, ?, ?, ?, 1)
     ON DUPLICATE KEY UPDATE
       card_key = IF(selected_by_user = 1, card_key, VALUES(card_key)),
       result_json = IF(selected_by_user = 1, result_json, VALUES(result_json)),
       selected_by_user = IF(selected_by_user = 1, selected_by_user, VALUES(selected_by_user)),
       updated_at = CURRENT_TIMESTAMP`,
    [
      userId,
      coupleId,
      date,
      TAROT_CATALOG_VERSION,
      result.card.key,
      JSON.stringify(result),
    ],
  );
  const stored = await readStoredTarot({ userId, coupleId, date });
  if (!stored) throw new Error('tarot_storage_failed');
  if (Number(stored.selected_by_user) !== 1) throw new Error('tarot_storage_failed');
  return tarotPayload(stored, { scope, date });
};

const readTarotToday = async (userId, date) => {
  const couple = await getActiveCoupleRow(userId);
  const personal = await readCurrentTarot({ userId, date });
  const relationship = couple
    ? await readCurrentTarot({ coupleId: Number(couple.CoupleId), date })
    : null;
  return { date, catalogVersion: TAROT_CATALOG_VERSION, redrawAvailable: false, personal, relationship };
};

router.get('/relationship/tarot/today', async (req, res) => {
  try {
    const date = businessDate();
    return res.json({
      ok: true,
      ...(await readTarotToday(req.auth.userId, date)),
    });
  } catch (error) {
    console.error('[API] /relationship/tarot/today GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/tarot/today/draw', async (req, res) => {
  try {
    const scope = String(req.body?.scope ?? 'user').trim();
    const cardKey = String(req.body?.cardKey ?? '').trim();
    if (!['user', 'couple'].includes(scope) || !cardKey) {
      return res.status(400).json({ ok: false, reason: 'invalid_tarot_selection' });
    }
    const date = businessDate();
    if (scope === 'couple') {
      const couple = await getActiveCoupleRow(req.auth.userId);
      if (!couple) {
        return res.status(404).json({ ok: false, reason: 'tarot_couple_unavailable' });
      }
      await saveSelectedTarot({
        coupleId: Number(couple.CoupleId),
        date,
        cardKey,
      });
    } else {
      await saveSelectedTarot({ userId: req.auth.userId, date, cardKey });
    }
    return res.json({ ok: true, ...(await readTarotToday(req.auth.userId, date)) });
  } catch (error) {
    if (error.code === 'invalid_tarot_card' || error.code === 'tarot_already_drawn') {
      return res.status(error.status ?? 409).json({ ok: false, reason: error.code });
    }
    console.error('[API] /relationship/tarot/today/draw error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const mindcareSessionPayload = (row) => ({
  id: Number(row.session_id),
  status: row.status,
  currentState: row.current_state,
  stepIndex: Number(row.step_index ?? 0),
  userResponseCount: Number(row.user_response_count ?? 0),
  contentVersion: row.content_version,
  ownerOnly: true,
  createdAt: relationshipDateTime(row.created_at),
  updatedAt: relationshipDateTime(row.updated_at),
  lastMessageAt: relationshipDateTime(row.last_message_at),
});

const mindcareMessagePayload = (row) => ({
  id: Number(row.message_id),
  sequence: Number(row.sequence_no),
  role: row.role,
  inputType: row.input_type ?? null,
  choiceKey: row.choice_key ?? null,
  riskCandidate: row.risk_candidate ?? null,
  content: row.content,
  createdAt: relationshipDateTime(row.created_at),
});

const getMindcareMessages = async (sessionId) => {
  const result = await query(
    `SELECT message_id, sequence_no, role, input_type, choice_key,
            risk_candidate, content, created_at
     FROM relationship_mindcare_messages
     WHERE session_id = ? ORDER BY sequence_no, message_id`,
    [sessionId],
  );
  return result.rows.map(mindcareMessagePayload);
};

const getMindcareSession = async (sessionId, userId) => {
  const result = await query(
    `SELECT session_id, owner_user_id, content_version, status, current_state,
            step_index, user_response_count, state_json,
            created_at, updated_at, last_message_at
     FROM relationship_mindcare_sessions
     WHERE session_id = ? AND owner_user_id = ?
     LIMIT 1`,
    [sessionId, userId],
  );
  return result.rows[0] ?? null;
};

const getLatestMindcareSession = async (userId) => {
  const result = await query(
    `SELECT session_id, owner_user_id, content_version, status, current_state,
            step_index, user_response_count, state_json,
            created_at, updated_at, last_message_at
     FROM relationship_mindcare_sessions
     WHERE owner_user_id = ? AND status IN ('active', 'safety_pending', 'safety_support')
     ORDER BY updated_at DESC, session_id DESC
     LIMIT 1`,
    [userId],
  );
  return result.rows[0] ?? null;
};

const insertMindcareMessage = async ({
  sessionId,
  role,
  inputType = null,
  choiceKey = null,
  riskCandidate = null,
  content,
}) => {
  const next = await query(
    'SELECT COALESCE(MAX(sequence_no), 0) + 1 AS next_sequence FROM relationship_mindcare_messages WHERE session_id = ?',
    [sessionId],
  );
  await query(
    `INSERT INTO relationship_mindcare_messages
       (session_id, sequence_no, role, input_type, choice_key, risk_candidate, content)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      sessionId,
      Number(next.rows[0]?.next_sequence ?? 1),
      role,
      inputType,
      choiceKey,
      riskCandidate,
      content,
    ],
  );
};

const mindcareStateFromRow = (row) => parseRelationshipJson(row.state_json) ?? createMindcareState();

const mindcareConversation = async (session, state) => ({
  session: mindcareSessionPayload(session),
  messages: await getMindcareMessages(session.session_id),
  choices: state.choices ?? [],
  nextQuestion: state.nextQuestion ?? null,
  state: mindcareStateView(state),
});

router.post('/relationship/mindcare/sessions', async (req, res) => {
  try {
    const existing = await getLatestMindcareSession(req.auth.userId);
    if (existing) {
      const state = mindcareStateFromRow(existing);
      return res.status(200).json({
        ok: true,
        resumed: true,
        ...(await mindcareConversation(existing, state)),
      });
    }
    const state = createMindcareState();
    const inserted = await query(
      `INSERT INTO relationship_mindcare_sessions
         (owner_user_id, content_version, status, current_state, step_index,
          user_response_count, state_json)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        req.auth.userId,
        MINDCARE_CONTENT_VERSION,
        state.status,
        state.currentState,
        state.stepIndex,
        state.userResponseCount,
        JSON.stringify(state),
      ],
    );
    const session = await getMindcareSession(inserted.rows.insertId, req.auth.userId);
    await insertMindcareMessage({
      sessionId: session.session_id,
      role: 'assistant',
      content: state.lastAssistantText,
    });
    return res.status(201).json({
      ok: true,
      created: true,
      ...(await mindcareConversation(session, state)),
    });
  } catch (error) {
    console.error('[API] mindcare session POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/mindcare/safety-resources', async (req, res) => {
  try {
    if (['latitude', 'longitude', 'lat', 'lng'].some((key) => req.query[key] != null)) {
      return res.status(400).json({ ok: false, reason: 'coordinates_not_supported' });
    }
    const resources = buildSafetyResources({
      locationPermission: String(req.query.permission ?? 'denied'),
      countryCode: req.query.country,
      adminArea: req.query.adminArea,
    });
    return res.json({ ok: true, ...resources });
  } catch (error) {
    console.error('[API] mindcare safety resources GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/mindcare/sessions', async (req, res) => {
  try {
    const result = await query(
      `SELECT session_id, owner_user_id, content_version, status, current_state,
              step_index, user_response_count, state_json,
              created_at, updated_at, last_message_at
       FROM relationship_mindcare_sessions
       WHERE owner_user_id = ? AND status <> 'archived'
       ORDER BY updated_at DESC, session_id DESC`,
      [req.auth.userId],
    );
    const sessions = result.rows.map(mindcareSessionPayload);
    const active = result.rows.find((row) =>
      ['active', 'safety_pending', 'safety_support'].includes(row.status));
    return res.json({
      ok: true,
      sessions,
      current: active ? await mindcareConversation(active, mindcareStateFromRow(active)) : null,
    });
  } catch (error) {
    console.error('[API] mindcare sessions GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/mindcare/sessions/:sessionId', async (req, res) => {
  try {
    const session = await getMindcareSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'mindcare_session_not_found' });
    return res.json({ ok: true, ...(await mindcareConversation(session, mindcareStateFromRow(session))) });
  } catch (error) {
    console.error('[API] mindcare session GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/mindcare/sessions/:sessionId/messages', async (req, res) => {
  try {
    const session = await getMindcareSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'mindcare_session_not_found' });
    if (session.status === 'safety_pending') {
      return res.status(409).json({ ok: false, reason: 'mindcare_safety_confirmation_required' });
    }
    if (session.status !== 'active') {
      return res.status(409).json({ ok: false, reason: 'mindcare_session_not_active' });
    }
    const hasChoice = typeof req.body?.choiceKey === 'string' && req.body.choiceKey.trim();
    const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
    if ((hasChoice && text) || (!hasChoice && !text)) {
      return res.status(400).json({ ok: false, reason: 'invalid_mindcare_input' });
    }
    const state = mindcareStateFromRow(session);
    const input = hasChoice ? { choiceKey: req.body.choiceKey.trim() } : { text };
    let next;
    try {
      next = advanceMindcareState(state, input);
    } catch (error) {
      if (['invalid_mindcare_choice', 'invalid_mindcare_input'].includes(error.message)) {
        return res.status(400).json({ ok: false, reason: error.message });
      }
      throw error;
    }
    const selectedLabel = hasChoice
      ? state.choices.find((item) => item.key === input.choiceKey)?.label ?? input.choiceKey
      : text;
    await insertMindcareMessage({
      sessionId: session.session_id,
      role: 'user',
      inputType: hasChoice ? 'choice' : 'text',
      choiceKey: hasChoice ? input.choiceKey : null,
      riskCandidate: next.safety?.status === 'pending' ? next.safety.reason : null,
      content: selectedLabel,
    });
    await insertMindcareMessage({
      sessionId: session.session_id,
      role: 'assistant',
      content: next.lastAssistantText,
    });
    await query(
      `UPDATE relationship_mindcare_sessions
       SET status = ?, current_state = ?, step_index = ?, user_response_count = ?,
           state_json = ?, last_message_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE session_id = ? AND owner_user_id = ?`,
      [
        next.status,
        next.currentState,
        next.stepIndex,
        next.userResponseCount,
        JSON.stringify(next),
        session.session_id,
        req.auth.userId,
      ],
    );
    const updated = await getMindcareSession(session.session_id, req.auth.userId);
    return res.status(201).json({ ok: true, ...(await mindcareConversation(updated, next)) });
  } catch (error) {
    console.error('[API] mindcare message POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/mindcare/sessions/:sessionId/safety', async (req, res) => {
  try {
    if (['latitude', 'longitude', 'lat', 'lng'].some((key) => req.body?.[key] != null)) {
      return res.status(400).json({ ok: false, reason: 'coordinates_not_supported' });
    }
    const session = await getMindcareSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'mindcare_session_not_found' });
    if (!['safety_pending', 'safety_support'].includes(session.status)) {
      return res.status(409).json({ ok: false, reason: 'mindcare_safety_not_required' });
    }
    if (typeof req.body?.safeNow !== 'boolean') {
      return res.status(400).json({ ok: false, reason: 'invalid_mindcare_safety' });
    }
    const state = mindcareStateFromRow(session);
    const next = resolveMindcareSafety(state, { safeNow: req.body.safeNow });
    await insertMindcareMessage({
      sessionId: session.session_id,
      role: 'user',
      inputType: 'safety',
      choiceKey: req.body.safeNow ? 'safe_now' : 'need_help',
      content: req.body.safeNow ? '지금은 안전해요' : '지금 도움이 필요해요',
    });
    await insertMindcareMessage({
      sessionId: session.session_id,
      role: 'assistant',
      content: next.lastAssistantText,
    });
    await query(
      `UPDATE relationship_mindcare_sessions
       SET status = ?, current_state = ?, step_index = ?, user_response_count = ?,
           state_json = ?, last_message_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE session_id = ? AND owner_user_id = ?`,
      [
        next.status,
        next.currentState,
        next.stepIndex,
        next.userResponseCount,
        JSON.stringify(next),
        session.session_id,
        req.auth.userId,
      ],
    );
    const updated = await getMindcareSession(session.session_id, req.auth.userId);
    return res.json({
      ok: true,
      safety: next.safety,
      ...(!req.body.safeNow
        ? buildSafetyResources({
            locationPermission: String(req.body.locationPermission ?? 'denied'),
            countryCode: req.body.countryCode,
            adminArea: req.body.adminArea,
          })
        : {}),
      ...(await mindcareConversation(updated, next)),
    });
  } catch (error) {
    console.error('[API] mindcare safety POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/fortune/today', async (req, res) => {
  try {
    return res.json({ ok: true, ...(await loadTodayFortunes(req.auth.userId)) });
  } catch (error) {
    console.error('[API] /relationship/fortune/today GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/fortune/today/regenerate', async (req, res) => {
  try {
    const requested = req.body?.type == null
      ? null
      : [String(req.body.type).trim()];
    const validTypes = new Set(['personal', 'relationship', 'emotional_flow']);
    if (requested && (requested.length !== 1 || !validTypes.has(requested[0]))) {
      return res.status(400).json({ ok: false, reason: 'invalid_fortune_type' });
    }
    const result = await loadTodayFortunes(req.auth.userId, {
      regenerate: true,
      types: requested,
    });
    if (requested?.[0] === 'relationship' && !result.fortunes.relationship) {
      return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    }
    return res.status(201).json({ ok: true, ...result });
  } catch (error) {
    console.error('[API] /relationship/fortune/today/regenerate POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const counselingSessionPayload = (row) => ({
  id: Number(row.session_id),
  scope: row.scope_type,
  title: row.title,
  status: row.status,
  coupleId: row.couple_id == null ? null : Number(row.couple_id),
  createdAt: relationshipDateTime(row.created_at),
  updatedAt: relationshipDateTime(row.updated_at),
  lastMessageAt: relationshipDateTime(row.last_message_at),
  messageCount: row.message_count == null ? undefined : Number(row.message_count),
});

const counselingMessagePayload = (row) => ({
  id: Number(row.message_id),
  sequence: Number(row.sequence_no),
  role: row.role,
  authorUserId: row.author_user_id == null ? null : Number(row.author_user_id),
  content: row.content,
  provider: row.provider ?? null,
  model: row.model ?? null,
  promptVersion: row.prompt_version ?? null,
  contextVersion: row.context_version ?? null,
  generationStatus: row.generation_status ?? null,
  errorCode: row.error_code ?? null,
  createdAt: relationshipDateTime(row.created_at),
});

const normalizeCounselingTitle = (value) => {
  const title = String(value ?? '').trim();
  return (title || '관계 대화').slice(0, 160);
};

const normalizeCounselingMessage = (value) => {
  const message = String(value ?? '').trim();
  if (!message || message.length > 4000) return null;
  return message;
};

const getPrivateCounselingSession = async (sessionId, userId) => {
  const result = await query(
    `SELECT session_id, scope_type, owner_user_id, couple_id, title, status,
            created_at, updated_at, last_message_at
     FROM relationship_counseling_sessions
     WHERE session_id = ? AND scope_type = 'private' AND owner_user_id = ?
     LIMIT 1`,
    [sessionId, userId],
  );
  return result.rows[0] ?? null;
};

const getSharedCounselingSession = async (sessionId, userId) => {
  const result = await query(
    `SELECT s.session_id, s.scope_type, s.owner_user_id, s.couple_id, s.title, s.status,
            s.created_at, s.updated_at, s.last_message_at
     FROM relationship_counseling_sessions s
     JOIN Couples c ON c.CoupleId = s.couple_id AND c.Status = 'active'
     WHERE s.session_id = ? AND s.scope_type = 'shared'
       AND (c.User1Id = ? OR c.User2Id = ?)
     LIMIT 1`,
    [sessionId, userId, userId],
  );
  return result.rows[0] ?? null;
};

const getCounselingMessages = async (sessionId) => {
  const result = await query(
    `SELECT message_id, sequence_no, role, author_user_id, content,
            provider, model, prompt_version, context_version,
            generation_status, error_code, created_at
     FROM relationship_counseling_messages
     WHERE session_id = ? ORDER BY sequence_no, message_id`,
    [sessionId],
  );
  return result.rows.map(counselingMessagePayload);
};

const getPersonalAssessmentSummaries = async (userId) => {
  const result = await query(
    `SELECT c.code, v.version_label, r.result_json
     FROM relationship_assessment_results r
     JOIN relationship_assessment_versions v ON v.version_id = r.version_id
     JOIN relationship_assessment_catalog c ON c.assessment_id = v.assessment_id
     JOIN (
       SELECT r2.user_id, v2.assessment_id, MAX(r2.result_id) AS result_id
       FROM relationship_assessment_results r2
       JOIN relationship_assessment_versions v2 ON v2.version_id = r2.version_id
       WHERE r2.user_id = ?
       GROUP BY r2.user_id, v2.assessment_id
     ) current ON current.result_id = r.result_id
     WHERE c.audience = 'individual'`,
    [userId],
  );
  return result.rows.flatMap((row) => {
    const parsed = parseRelationshipJson(row.result_json);
    if (!parsed) return [];
    return [{
      code: row.code,
      version: row.version_label,
      tendency: parsed.overallTendency ?? parsed.tendency ?? null,
      dimensions: parsed.dimensions,
    }];
  });
};

const getSharedCompatibilitySummaries = async (coupleId) => {
  const result = await query(
    `SELECT analysis_code, result_json
     FROM relationship_compatibility_analyses
     WHERE couple_id = ? ORDER BY analysis_id DESC`,
    [coupleId],
  );
  const seen = new Set();
  return result.rows.flatMap((row) => {
    if (seen.has(row.analysis_code)) return [];
    seen.add(row.analysis_code);
    const parsed = parseRelationshipJson(row.result_json);
    if (!parsed) return [];
    return [{
      code: row.analysis_code,
      patternKey: parsed.complementaryPatternKey,
      dimensions: parsed.dimensions,
    }];
  });
};

const getApprovedInsights = async (coupleId) => {
  const result = await query(
    `SELECT insight_id, private_session_id, creator_user_id, insight_text, created_at
     FROM relationship_shareable_insights
     WHERE couple_id = ? AND status = 'approved'
     ORDER BY insight_id`,
    [coupleId],
  );
  return result.rows.map((row) => ({
    id: Number(row.insight_id),
    privateSessionId: Number(row.private_session_id),
    creatorUserId: Number(row.creator_user_id),
    insightText: row.insight_text,
    createdAt: relationshipDateTime(row.created_at),
  }));
};

const counselingFallbackText = (scope) => scope === 'shared'
  ? '지금은 두 사람이 함께 확인할 수 있는 정보만 바탕으로 답했어요. 서로의 감정과 부탁을 한 문장씩 나눠보세요.'
  : '지금 적어준 감정을 판단하지 않고 천천히 살펴볼게요. 감정의 이름, 몸의 반응, 원하는 도움을 나누어 적어보세요.';

const generateCounselingReply = async ({ scope, userId, session, messages }) => {
  const provider = createExplanationProvider(config);
  let input;
  if (scope === 'private') {
    const profile = await getBirthProfileByUserId(userId);
    const assessments = await getPersonalAssessmentSummaries(userId);
    input = {
      sourceType: 'counseling',
      contentType: 'private',
      version: 'v1',
      context: buildPrivateCounselingContext({
        profile,
        assessmentSummaries: assessments,
        messages,
      }),
    };
  } else {
    const [compatibilitySummaries, approvedInsights] = await Promise.all([
      getSharedCompatibilitySummaries(Number(session.couple_id)),
      getApprovedInsights(Number(session.couple_id)),
    ]);
    input = {
      sourceType: 'counseling',
      contentType: 'shared',
      version: 'v1',
      context: buildSharedCounselingContext({
        compatibilitySummaries,
        approvedInsights,
        messages,
      }),
    };
  }
  return buildRelationshipContentAttempt({
    provider,
    input,
    fallbackText: counselingFallbackText(scope),
  });
};

const insertCounselingMessage = async ({ sessionId, role, authorUserId = null, content, generation = null }) => {
  const next = await query(
    'SELECT COALESCE(MAX(sequence_no), 0) + 1 AS next_sequence FROM relationship_counseling_messages WHERE session_id = ?',
    [sessionId],
  );
  await query(
    `INSERT INTO relationship_counseling_messages
       (session_id, sequence_no, role, author_user_id, content,
        provider, model, prompt_version, context_version,
        generation_status, error_code)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      sessionId,
      Number(next.rows[0]?.next_sequence ?? 1),
      role,
      authorUserId,
      content,
      generation?.provider ?? null,
      generation?.model ?? null,
      generation ? config.LLM_PROMPT_VERSION : null,
      generation ? config.LLM_CONTEXT_VERSION : null,
      generation?.status ?? null,
      generation?.errorCode ?? null,
    ],
  );
};

const createCounselingSession = async ({ scope, userId, coupleId, title }) => {
  const inserted = await query(
    `INSERT INTO relationship_counseling_sessions
       (scope_type, owner_user_id, couple_id, title)
     VALUES (?, ?, ?, ?)`,
    [scope, scope === 'private' ? userId : null, coupleId, title],
  );
  const result = await query(
    `SELECT session_id, scope_type, owner_user_id, couple_id, title, status,
            created_at, updated_at, last_message_at
     FROM relationship_counseling_sessions WHERE session_id = ?`,
    [inserted.rows.insertId],
  );
  return result.rows[0];
};

const counselingResponse = async (res, session) => res.json({
  ok: true,
  session: counselingSessionPayload(session),
  messages: await getCounselingMessages(session.session_id),
});

const createPrivateSessionFromRequest = async (req, res) => {
  const session = await createCounselingSession({
    scope: 'private',
    userId: req.auth.userId,
    coupleId: (await getActiveCoupleRow(req.auth.userId))?.CoupleId ?? null,
    title: normalizeCounselingTitle(req.body?.title),
  });
  return res.status(201).json({ ok: true, session: counselingSessionPayload(session), messages: [] });
};

router.post('/relationship/counseling/private/sessions', async (req, res) => {
  try {
    return await createPrivateSessionFromRequest(req, res);
  } catch (error) {
    console.error('[API] private counseling session POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/private/sessions', async (req, res) => {
  try {
    const result = await query(
      `SELECT s.session_id, s.scope_type, s.owner_user_id, s.couple_id, s.title, s.status,
              s.created_at, s.updated_at, s.last_message_at,
              COUNT(m.message_id) AS message_count
       FROM relationship_counseling_sessions s
       LEFT JOIN relationship_counseling_messages m ON m.session_id = s.session_id
       WHERE s.scope_type = 'private' AND s.owner_user_id = ?
       GROUP BY s.session_id ORDER BY s.updated_at DESC`,
      [req.auth.userId],
    );
    return res.json({ ok: true, sessions: result.rows.map(counselingSessionPayload) });
  } catch (error) {
    console.error('[API] private counseling sessions GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/private/sessions/:sessionId', async (req, res) => {
  try {
    const session = await getPrivateCounselingSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
    return counselingResponse(res, session);
  } catch (error) {
    console.error('[API] private counseling session GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/counseling/private/sessions/:sessionId/messages', async (req, res) => {
  try {
    const session = await getPrivateCounselingSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
    if (session.status !== 'active') return res.status(409).json({ ok: false, reason: 'counseling_session_archived' });
    const content = normalizeCounselingMessage(req.body?.content);
    if (!content) return res.status(400).json({ ok: false, reason: 'invalid_message' });
    await insertCounselingMessage({
      sessionId: session.session_id,
      role: 'user',
      authorUserId: req.auth.userId,
      content,
    });
    const messages = await getCounselingMessages(session.session_id);
    const generation = await generateCounselingReply({
      scope: 'private',
      userId: req.auth.userId,
      session,
      messages,
    });
    await insertCounselingMessage({
      sessionId: session.session_id,
      role: 'assistant',
      content: generation.text,
      generation,
    });
    await query(
      `UPDATE relationship_counseling_sessions
       SET last_message_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE session_id = ? AND owner_user_id = ?`,
      [session.session_id, req.auth.userId],
    );
    const updated = await getPrivateCounselingSession(session.session_id, req.auth.userId);
    return res.status(201).json({ ok: true, session: counselingSessionPayload(updated), messages: await getCounselingMessages(session.session_id) });
  } catch (error) {
    console.error('[API] private counseling message POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/counseling/shared/sessions', async (req, res) => {
  try {
    const couple = await getActiveCoupleRow(req.auth.userId);
    if (!couple) return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    const session = await createCounselingSession({
      scope: 'shared',
      userId: req.auth.userId,
      coupleId: couple.CoupleId,
      title: normalizeCounselingTitle(req.body?.title),
    });
    return res.status(201).json({ ok: true, session: counselingSessionPayload(session), messages: [] });
  } catch (error) {
    console.error('[API] shared counseling session POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/shared/sessions', async (req, res) => {
  try {
    const couple = await getActiveCoupleRow(req.auth.userId);
    if (!couple) return res.json({ ok: true, sessions: [] });
    const result = await query(
      `SELECT s.session_id, s.scope_type, s.owner_user_id, s.couple_id, s.title, s.status,
              s.created_at, s.updated_at, s.last_message_at,
              COUNT(m.message_id) AS message_count
       FROM relationship_counseling_sessions s
       LEFT JOIN relationship_counseling_messages m ON m.session_id = s.session_id
       WHERE s.scope_type = 'shared' AND s.couple_id = ?
       GROUP BY s.session_id ORDER BY s.updated_at DESC`,
      [couple.CoupleId],
    );
    return res.json({ ok: true, sessions: result.rows.map(counselingSessionPayload) });
  } catch (error) {
    console.error('[API] shared counseling sessions GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/shared/sessions/:sessionId', async (req, res) => {
  try {
    const session = await getSharedCounselingSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
    return counselingResponse(res, session);
  } catch (error) {
    console.error('[API] shared counseling session GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/counseling/shared/sessions/:sessionId/messages', async (req, res) => {
  try {
    const session = await getSharedCounselingSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
    if (session.status !== 'active') return res.status(409).json({ ok: false, reason: 'counseling_session_archived' });
    const content = normalizeCounselingMessage(req.body?.content);
    if (!content) return res.status(400).json({ ok: false, reason: 'invalid_message' });
    await insertCounselingMessage({
      sessionId: session.session_id,
      role: 'user',
      authorUserId: req.auth.userId,
      content,
    });
    const messages = await getCounselingMessages(session.session_id);
    const generation = await generateCounselingReply({
      scope: 'shared',
      userId: req.auth.userId,
      session,
      messages,
    });
    await insertCounselingMessage({
      sessionId: session.session_id,
      role: 'assistant',
      content: generation.text,
      generation,
    });
    await query(
      `UPDATE relationship_counseling_sessions
       SET last_message_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
       WHERE session_id = ? AND scope_type = 'shared'`,
      [session.session_id],
    );
    const updated = await getSharedCounselingSession(session.session_id, req.auth.userId);
    return res.status(201).json({ ok: true, session: counselingSessionPayload(updated), messages: await getCounselingMessages(session.session_id) });
  } catch (error) {
    console.error('[API] shared counseling message POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const archiveCounselingSession = async (req, res, scope) => {
  const session = scope === 'private'
    ? await getPrivateCounselingSession(req.params.sessionId, req.auth.userId)
    : await getSharedCounselingSession(req.params.sessionId, req.auth.userId);
  if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
  await query(
    'UPDATE relationship_counseling_sessions SET status = \'archived\', updated_at = CURRENT_TIMESTAMP WHERE session_id = ?',
    [session.session_id],
  );
  const updated = scope === 'private'
    ? await getPrivateCounselingSession(session.session_id, req.auth.userId)
    : await getSharedCounselingSession(session.session_id, req.auth.userId);
  return res.json({ ok: true, session: counselingSessionPayload(updated) });
};

router.post('/relationship/counseling/private/sessions/:sessionId/archive', async (req, res) => {
  try {
    return await archiveCounselingSession(req, res, 'private');
  } catch (error) {
    console.error('[API] private counseling archive POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/counseling/shared/sessions/:sessionId/archive', async (req, res) => {
  try {
    return await archiveCounselingSession(req, res, 'shared');
  } catch (error) {
    console.error('[API] shared counseling archive POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

const insightPayload = (row) => ({
  id: Number(row.insight_id),
  privateSessionId: Number(row.private_session_id),
  creatorUserId: Number(row.creator_user_id),
  coupleId: Number(row.couple_id),
  text: row.insight_text,
  status: row.status,
  createdAt: relationshipDateTime(row.created_at),
  revokedAt: relationshipDateTime(row.revoked_at),
});

router.post('/relationship/counseling/private/sessions/:sessionId/insights', async (req, res) => {
  try {
    const session = await getPrivateCounselingSession(req.params.sessionId, req.auth.userId);
    if (!session) return res.status(404).json({ ok: false, reason: 'counseling_session_not_found' });
    const couple = await getActiveCoupleRow(req.auth.userId);
    if (!couple) return res.status(409).json({ ok: false, reason: 'active_couple_required' });
    if (Number(session.couple_id) !== Number(couple.CoupleId)) {
      return res.status(409).json({ ok: false, reason: 'session_not_shareable_with_current_couple' });
    }
    const text = String(req.body?.text ?? '').trim();
    if (!text || text.length > 1200) return res.status(400).json({ ok: false, reason: 'invalid_insight' });
    const inserted = await query(
      `INSERT INTO relationship_shareable_insights
         (private_session_id, creator_user_id, couple_id, insight_text)
       VALUES (?, ?, ?, ?)`,
      [session.session_id, req.auth.userId, couple.CoupleId, text],
    );
    const result = await query(
      `SELECT insight_id, private_session_id, creator_user_id, couple_id,
              insight_text, status, created_at, revoked_at
       FROM relationship_shareable_insights WHERE insight_id = ?`,
      [inserted.rows.insertId],
    );
    return res.status(201).json({ ok: true, insight: insightPayload(result.rows[0]) });
  } catch (error) {
    console.error('[API] shareable insight POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/private/insights', async (req, res) => {
  try {
    const result = await query(
      `SELECT insight_id, private_session_id, creator_user_id, couple_id,
              insight_text, status, created_at, revoked_at
       FROM relationship_shareable_insights
       WHERE creator_user_id = ? ORDER BY insight_id DESC`,
      [req.auth.userId],
    );
    return res.json({ ok: true, insights: result.rows.map(insightPayload) });
  } catch (error) {
    console.error('[API] shareable insights GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.post('/relationship/counseling/insights/:insightId/revoke', async (req, res) => {
  try {
    const updated = await query(
      `UPDATE relationship_shareable_insights
       SET status = 'revoked', revoked_at = CURRENT_TIMESTAMP
       WHERE insight_id = ? AND creator_user_id = ? AND status = 'approved'`,
      [req.params.insightId, req.auth.userId],
    );
    if (updated.rows.affectedRows === 0) {
      return res.status(404).json({ ok: false, reason: 'insight_not_found' });
    }
    const result = await query(
      `SELECT insight_id, private_session_id, creator_user_id, couple_id,
              insight_text, status, created_at, revoked_at
       FROM relationship_shareable_insights WHERE insight_id = ?`,
      [req.params.insightId],
    );
    return res.json({ ok: true, insight: insightPayload(result.rows[0]) });
  } catch (error) {
    console.error('[API] shareable insight revoke POST error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

router.get('/relationship/counseling/shared/insights', async (req, res) => {
  try {
    const couple = await getActiveCoupleRow(req.auth.userId);
    if (!couple) return res.json({ ok: true, insights: [] });
    const insights = await getApprovedInsights(couple.CoupleId);
    return res.json({ ok: true, insights });
  } catch (error) {
    console.error('[API] shared insights GET error:', error);
    return res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

export default router;
