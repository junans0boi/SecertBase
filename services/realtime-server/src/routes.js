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

const router = express.Router();
const googleClient = new OAuth2Client();

let setlogReadyPromise;
const ensureSetlogTable = () => {
  setlogReadyPromise ??= query(`
    CREATE TABLE IF NOT EXISTS setlog_posts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      couple_id INT NULL,
      user_id INT NOT NULL,
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
      INDEX idx_setlog_user_taken (user_id, taken_at)
    )
  `);

  return setlogReadyPromise;
};

// 누락된 테이블 자동 생성
let _tablesReady = false;
const ensureTables = async () => {
  if (_tablesReady) return;
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

let googleAuthColumnsReadyPromise;
const ensureGoogleAuthColumns = async () => {
  if (googleAuthColumnsReadyPromise) return googleAuthColumnsReadyPromise;

  googleAuthColumnsReadyPromise = (async () => {
    const result = await query(
      `SELECT COLUMN_NAME
       FROM INFORMATION_SCHEMA.COLUMNS
       WHERE TABLE_SCHEMA = DATABASE()
         AND TABLE_NAME = 'Users'
         AND COLUMN_NAME IN ('AuthProvider', 'GoogleSubject', 'GooglePictureUrl')`
    );
    const existing = new Set(result.rows.map((row) => row.COLUMN_NAME));

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
  })();

  return googleAuthColumnsReadyPromise;
};

const createJwtForUser = (user) =>
  jwt.sign(
    { userId: user.UserId, email: user.Email, userCode: user.UserCode },
    config.JWT_SECRET,
    { expiresIn: '7d' }
  );

const normalizeAuthUser = (user) => ({
  id: user.UserId,
  UserId: user.UserId,
  email: user.Email,
  Email: user.Email,
  userName: user.UserName,
  UserName: user.UserName,
  userCode: user.UserCode,
  UserCode: user.UserCode,
  PartnerCode: user.PartnerCode ?? null,
  UserIcon: user.UserIcon ?? null,
  RoomCode: user.RoomCode ?? null,
  RoomSecret: user.RoomSecret ?? null,
  AuthProvider: user.AuthProvider ?? null,
  GooglePictureUrl: user.GooglePictureUrl ?? null,
});

const getProfileRowByUserId = async (userId) => {
  await ensureGoogleAuthColumns();
  const result = await query(
    `SELECT u.UserId, u.Email, u.UserName, u.UserCode,
            u.AuthProvider, u.GooglePictureUrl,
            p.UserIcon, p.PartnerCode,
            c.RoomCode, c.RoomSecret
     FROM Users u
     JOIN User_Preference p ON u.UserId = p.UserId
     LEFT JOIN Couples c ON (u.UserId = c.User1Id OR u.UserId = c.User2Id)
     WHERE u.UserId = ?`,
    [userId]
  );
  return result.rows[0] ?? null;
};

const getCoupleIdForUser = async (userId) => {
  const result = await query(
    'SELECT CoupleId FROM Couples WHERE User1Id = ? OR User2Id = ? LIMIT 1',
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
    const { email, password, user_name } = req.body;

    if (!email || !password) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

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
        `INSERT INTO Users (Email, PasswordHash, PasswordSalt, UserName, UserCode, CreatedBy) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [email, hash, salt, user_name || '사용자', userCode, 'system']
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

router.post('/auth/google', async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ ok: false, reason: 'missing_id_token' });
    }
    if (!config.GOOGLE_CLIENT_ID) {
      return res.status(503).json({ ok: false, reason: 'google_login_not_configured' });
    }

    await ensureGoogleAuthColumns();

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: config.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const googleSubject = payload?.sub;
    const email = payload?.email;
    const emailVerified = payload?.email_verified;
    const name = payload?.name || payload?.given_name || 'Google 사용자';
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
             END,
             ModifiedBy = 'google',
             ModifiedDateTime = NOW()
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
           (Email, PasswordHash, PasswordSalt, UserName, UserCode, CreatedBy,
            AuthProvider, GoogleSubject, GooglePictureUrl)
           VALUES (?, NULL, NULL, ?, ?, 'google', 'google', ?, ?)`,
          [email, name, userCode, googleSubject, picture]
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
});

// 애인 설정 (Partner Pairing - Mutual with Auto-Room)
router.post('/user/partner', async (req, res) => {
  try {
    const { userId, partnerCode } = req.body;

    if (!userId || !partnerCode) {
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
});

// 프로필 조회 (With Room Info)
router.get('/user/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
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

// Multer 설정 (파일 업로드)
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
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
    await ensureSetlogTable();

    const { month, user_id } = req.query; // YYYY-MM 형식
    let sql = `SELECT p.*, u.UserName
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

// 셋로그 생성
router.post('/setlog', upload.single('media'), async (req, res) => {
  try {
    await ensureSetlogTable();

    const {
      user_id,
      user_code,
      caption,
      tags,
      taken_at,
      captured_at,
      media_type,
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
    const tagsArray = parseJsonArray(tags);
    
    const result = await query(
      `INSERT INTO setlog_posts
       (couple_id, user_id, user_code, media_type, media_url, caption, tags, taken_at, captured_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NOW()))`,
      [
        coupleId,
        userId,
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
      `SELECT p.*, u.UserName
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

// 지도 핀 목록 조회
router.get('/map', async (req, res) => {
  try {
    await ensureTables();
    const result = await query('SELECT * FROM map_pins ORDER BY visit_date DESC');
    res.json({ ok: true, pins: result.rows });
  } catch (err) {
    console.error('[API] /map GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 생성 (lat/lng 선택사항)
router.post('/map', async (req, res) => {
  try {
    await ensureTables();
    const { place_name, latitude, longitude, category, rating, visit_date, memo, created_by } = req.body;

    if (!place_name || !created_by) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const result = await query(
      `INSERT INTO map_pins (place_name, latitude, longitude, category, rating, visit_date, memo, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [place_name, latitude ?? 0, longitude ?? 0, category ?? null, rating ?? null, visit_date ?? null, memo ?? null, created_by]
    );

    res.json({ ok: true, id: result.rows.insertId });
  } catch (err) {
    console.error('[API] /map POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 업데이트 (별점/메모)
router.patch('/map/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rating, memo } = req.body;

    await query(
      'UPDATE map_pins SET rating = COALESCE(?, rating), memo = COALESCE(?, memo), updated_at = NOW() WHERE id = ?',
      [rating, memo, id]
    );

    res.json({ ok: true });
  } catch (err) {
    console.error('[API] /map PATCH error:', err);
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

// 오늘의 질문 조회 (질문 없으면 자동 생성)
router.get('/qa/today', async (req, res) => {
  try {
    await ensureTables();
    const today = new Date().toISOString().split('T')[0];
    let result = await query('SELECT * FROM daily_questions WHERE scheduled_date = ?', [today]);

    if (result.rows.length === 0) {
      const dayOfYear = Math.floor((new Date() - new Date(new Date().getFullYear(), 0, 0)) / 86400000);
      const question = QA_POOL[dayOfYear % QA_POOL.length];
      try {
        await query('INSERT IGNORE INTO daily_questions (question, scheduled_date) VALUES (?, ?)', [question, today]);
      } catch {}
      result = await query('SELECT * FROM daily_questions WHERE scheduled_date = ?', [today]);
    }

    if (result.rows.length === 0) return res.json({ ok: true, question: null, answers: [] });

    const question = result.rows[0];
    const answers = await query(
      `SELECT qa.id, qa.question_id, qa.user_id, qa.answer, qa.answered_at, u.UserName
       FROM question_answers qa
       LEFT JOIN Users u ON qa.user_id = u.UserId
       WHERE qa.question_id = ?`,
      [question.id]
    );

    res.json({ ok: true, question, answers: answers.rows });
  } catch (err) {
    console.error('[API] /qa/today GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 답변 제출
router.post('/qa/answer', async (req, res) => {
  try {
    const { question_id, user_id, answer } = req.body;

    if (!question_id || !user_id || !answer) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const result = await query(
      'INSERT INTO question_answers (question_id, user_id, answer) VALUES (?, ?, ?)',
      [question_id, user_id, answer]
    );

    res.json({ ok: true, id: result.insertId });
  } catch (err) {
    console.error('[API] /qa/answer POST error:', err);
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

    res.json({ ok: true, id: result.insertId });
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

    res.json({ ok: true, id: result.insertId });
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
    await ensureCouplesStartDate();
    const { user_id } = req.query;
    if (!user_id) return res.status(400).json({ ok: false, reason: 'missing_user_id' });

    const uid = Number(user_id);
    const result = await query(
      `SELECT c.CoupleId, c.StartDate,
              u1.UserId AS U1Id, u1.UserName AS U1Name, u1.UserCode AS U1Code,
              u2.UserId AS U2Id, u2.UserName AS U2Name, u2.UserCode AS U2Code
       FROM Couples c
       JOIN Users u1 ON c.User1Id = u1.UserId
       JOIN Users u2 ON c.User2Id = u2.UserId
       WHERE c.User1Id = ? OR c.User2Id = ?`,
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
      const start = new Date(row.StartDate);
      start.setHours(0, 0, 0, 0);
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      dDay = Math.floor((today - start) / 86400000) + 1;
      startDateStr = start.toISOString().split('T')[0];
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
    const { user_id, start_date } = req.body;
    if (!user_id || !start_date) return res.status(400).json({ ok: false, reason: 'missing_fields' });

    await query(
      'UPDATE Couples SET StartDate = ? WHERE User1Id = ? OR User2Id = ?',
      [start_date, Number(user_id), Number(user_id)]
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

export default router;
