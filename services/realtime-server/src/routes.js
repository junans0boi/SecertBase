/**
 * REST API Routes for Phase 3 Archiving Features
 * Endpoints: /api/setlog, /api/map, /api/qa, /api/challenges, /api/jukebox
 */

import express from 'express';
import multer from 'multer';
import { query, transaction } from './db.js';

const router = express.Router();

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
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('audio/')) {
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
    const { month } = req.query; // YYYY-MM 형식
    let sql = 'SELECT * FROM setlog_posts ORDER BY taken_at DESC';
    let params = [];

    if (month) {
      sql = `SELECT * FROM setlog_posts 
             WHERE DATE_TRUNC('month', taken_at) = $1::date 
             ORDER BY taken_at DESC`;
      params = [month + '-01'];
    }

    const result = await query(sql, params);
    res.json({ ok: true, posts: result.rows });
  } catch (err) {
    console.error('[API] /setlog GET error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 셋로그 생성
router.post('/setlog', upload.single('photo'), async (req, res) => {
  try {
    const { user_id, caption, tags, taken_at } = req.body;
    const photo_url = req.file ? `/uploads/${req.file.filename}` : null;

    if (!user_id || !photo_url || !taken_at) {
      return res.status(400).json({ ok: false, reason: 'missing_fields' });
    }

    const tagsArray = tags ? JSON.parse(tags) : [];
    
    const result = await query(
      `INSERT INTO setlog_posts (user_id, photo_url, caption, tags, taken_at) 
       VALUES ($1, $2, $3, $4, $5) 
       RETURNING *`,
      [user_id, photo_url, caption, tagsArray, taken_at]
    );

    res.json({ ok: true, post: result.rows[0] });
  } catch (err) {
    console.error('[API] /setlog POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

// 셋로그 삭제
router.delete('/setlog/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await query('DELETE FROM setlog_posts WHERE id = $1', [id]);
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
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) 
       RETURNING *`,
      [place_name, latitude, longitude, category, rating, visit_date, memo, created_by]
    );

    res.json({ ok: true, pin: result.rows[0] });
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

    const result = await query(
      'UPDATE map_pins SET rating = COALESCE($1, rating), memo = COALESCE($2, memo), updated_at = NOW() WHERE id = $3 RETURNING *',
      [rating, memo, id]
    );

    res.json({ ok: true, pin: result.rows[0] });
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
      'SELECT * FROM daily_questions WHERE scheduled_date = $1',
      [today]
    );

    if (result.rows.length === 0) {
      return res.json({ ok: true, question: null });
    }

    const question = result.rows[0];
    const answers = await query(
      'SELECT * FROM question_answers WHERE question_id = $1',
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
      'INSERT INTO question_answers (question_id, user_id, answer) VALUES ($1, $2, $3) RETURNING *',
      [question_id, user_id, answer]
    );

    res.json({ ok: true, answer: result.rows[0] });
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
       VALUES ($1, $2, $3, $4, $5, $6, $7) 
       RETURNING *`,
      [title, description, target_value, unit, owner_id, start_date, target_date]
    );

    res.json({ ok: true, challenge: result.rows[0] });
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

    await transaction(async (client) => {
      // 로그 추가
      await client.query(
        'INSERT INTO challenge_logs (challenge_id, value, note) VALUES ($1, $2, $3)',
        [id, value, note]
      );

      // 현재 값 업데이트
      await client.query(
        'UPDATE challenges SET current_value = current_value + $1, updated_at = NOW() WHERE id = $2',
        [value, id]
      );

      // 목표 달성 체크
      const result = await client.query(
        'SELECT current_value, target_value FROM challenges WHERE id = $1',
        [id]
      );

      const challenge = result.rows[0];
      if (challenge.current_value >= challenge.target_value) {
        await client.query(
          'UPDATE challenges SET status = $1, completed_at = NOW() WHERE id = $2',
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
      'INSERT INTO jukebox_tracks (title, artist, file_url, duration_sec, uploaded_by) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [title, artist, file_url, duration_sec, uploaded_by]
    );

    res.json({ ok: true, track: result.rows[0] });
  } catch (err) {
    console.error('[API] /jukebox POST error:', err);
    res.status(500).json({ ok: false, reason: 'internal_error' });
  }
});

export default router;
