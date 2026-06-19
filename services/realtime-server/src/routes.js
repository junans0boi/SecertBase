/**
 * REST API Routes for Phase 3 Archiving Features
 * Endpoints: /api/auth, /api/user, /api/setlog, /api/map, /api/qa, /api/challenges, /api/jukebox
 */

import express from 'express';
import multer from 'multer';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { query, transaction } from './db.js';
import { config } from './config.js';

const router = express.Router();

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

    // JWT 토큰 생성
    const token = jwt.sign(
      { userId: user.UserId, email: user.Email, userCode: user.UserCode },
      config.JWT_SECRET || 'fallback_secret',
      { expiresIn: '7d' }
    );

    res.json({ 
      ok: true, 
      token, 
      user: {
        id: user.UserId,
        email: user.Email,
        userName: user.UserName,
        userCode: user.UserCode
      }
    });
  } catch (err) {
    console.error('[API] /auth/login error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
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
    const result = await query(
      `SELECT u.UserId, u.Email, u.UserName, u.UserCode, p.UserIcon, p.PartnerCode,
              c.RoomCode, c.RoomSecret
       FROM Users u 
       JOIN User_Preference p ON u.UserId = p.UserId 
       LEFT JOIN Couples c ON (u.UserId = c.User1Id OR u.UserId = c.User2Id)
       WHERE u.UserId = ?`,
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, reason: 'user_not_found' });
    }

    res.json({ ok: true, user: result.rows[0] });
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
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
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
    const result = await query('SELECT * FROM map_pins ORDER BY visit_date DESC');
    res.json({ ok: true, pins: result.rows });
  } catch (err) {
    console.error('[API] /map GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 지도 핀 생성
router.post('/map', async (req, res) => {
  try {
    const { place_name, latitude, longitude, category, rating, visit_date, memo, created_by } = req.body;

    if (!place_name || !latitude || !longitude || !created_by) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const result = await query(
      `INSERT INTO map_pins (place_name, latitude, longitude, category, rating, visit_date, memo, created_by) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [place_name, latitude, longitude, category, rating, visit_date, memo, created_by]
    );

    res.json({ ok: true, id: result.insertId });
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

// 오늘의 질문 조회
router.get('/qa/today', async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    const result = await query(
      'SELECT * FROM daily_questions WHERE scheduled_date = ?',
      [today]
    );

    if (result.rows.length === 0) {
      return res.json({ ok: true, question: null });
    }

    const question = result.rows[0];
    const answers = await query(
      'SELECT * FROM question_answers WHERE question_id = ?',
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
    const result = await query('SELECT * FROM active_challenges');
    res.json({ ok: true, challenges: result.rows });
  } catch (err) {
    console.error('[API] /challenges GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 챌린지 생성
router.post('/challenges', async (req, res) => {
  try {
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

export default router;
