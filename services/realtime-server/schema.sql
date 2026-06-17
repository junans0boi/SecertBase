-- Secret Base PostgreSQL Schema
-- Phase 3: 아카이빙 존 (Archiving Zone)

-- 1. 셋로그 (Setlog) - OOTD & 데이트 사진 폴라로이드 앨범
CREATE TABLE setlog_posts (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,  -- 'jun' or 'gf'
  photo_url TEXT NOT NULL,        -- S3/로컬 스토리지 경로
  caption TEXT,                   -- 사진 설명
  tags TEXT[],                    -- 해시태그 배열: ['#데이트', '#한강']
  taken_at DATE NOT NULL,         -- 사진 촬영일 (달력 그리드용)
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_setlog_taken_at ON setlog_posts(taken_at);
CREATE INDEX idx_setlog_tags ON setlog_posts USING GIN(tags);

-- 2. 비밀 지도 (Secret Map) - 데이트 장소 핀
CREATE TABLE map_pins (
  id SERIAL PRIMARY KEY,
  place_name VARCHAR(200) NOT NULL,   -- '을지로 술집', '한강 피크닉'
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  category VARCHAR(50),               -- 'restaurant', 'cafe', 'activity'
  rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
  visit_date DATE,
  memo TEXT,                          -- 방문 후기
  photos TEXT[],                      -- 사진 URL 배열
  created_by VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_map_coords ON map_pins(latitude, longitude);
CREATE INDEX idx_map_visit_date ON map_pins(visit_date);

-- 3. 10시의 Q&A (Daily Questions)
CREATE TABLE daily_questions (
  id SERIAL PRIMARY KEY,
  question TEXT NOT NULL,
  scheduled_date DATE NOT NULL UNIQUE, -- 매일 10시에 푸시할 날짜
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE question_answers (
  id SERIAL PRIMARY KEY,
  question_id INT REFERENCES daily_questions(id) ON DELETE CASCADE,
  user_id VARCHAR(50) NOT NULL,
  answer TEXT NOT NULL,
  answered_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_answers_question ON question_answers(question_id);
CREATE INDEX idx_answers_user ON question_answers(user_id);

-- 4. 목표 챌린지 (Goal Challenge)
CREATE TABLE challenges (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,        -- '벤치프레스 100kg', '5km 달리기'
  description TEXT,
  target_value DECIMAL(10, 2),        -- 목표 수치
  current_value DECIMAL(10, 2) DEFAULT 0,
  unit VARCHAR(20),                   -- 'kg', 'km', 'reps'
  owner_id VARCHAR(50) NOT NULL,      -- 'jun' or 'gf'
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'completed', 'abandoned'
  start_date DATE NOT NULL,
  target_date DATE,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE challenge_logs (
  id SERIAL PRIMARY KEY,
  challenge_id INT REFERENCES challenges(id) ON DELETE CASCADE,
  value DECIMAL(10, 2) NOT NULL,
  note TEXT,
  logged_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_challenge_owner ON challenges(owner_id);
CREATE INDEX idx_challenge_status ON challenges(status);

-- 5. 프라이빗 주크박스 (Jukebox) - 음원 메타데이터
CREATE TABLE jukebox_tracks (
  id SERIAL PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  artist VARCHAR(100),                -- 'Cover by Jun', 'Original Mix'
  file_url TEXT NOT NULL,             -- 서버 내 MP3 경로
  duration_sec INT,                   -- 재생 시간 (초)
  cover_art_url TEXT,                 -- 앨범 커버 이미지
  uploaded_by VARCHAR(50) NOT NULL,
  uploaded_at TIMESTAMP DEFAULT NOW()
);

-- 6. 사용자 프로필 (간단한 설정 저장)
CREATE TABLE user_profiles (
  user_id VARCHAR(50) PRIMARY KEY,
  display_name VARCHAR(100),
  avatar_url TEXT,
  push_token TEXT,                    -- FCM/APNS 푸시 토큰
  notification_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 샘플 데이터 (개발용)
INSERT INTO daily_questions (question, scheduled_date) VALUES
  ('오늘 가장 행복했던 순간은?', '2026-06-18'),
  ('내일 하고 싶은 한 가지는?', '2026-06-19'),
  ('가장 좋아하는 음식은?', '2026-06-20');

INSERT INTO user_profiles (user_id, display_name) VALUES
  ('jun', '준'),
  ('gf', '여친');

-- 뷰: 최근 셋로그 (달력 뷰용)
CREATE VIEW recent_setlog AS
SELECT 
  DATE_TRUNC('month', taken_at) AS month,
  ARRAY_AGG(
    JSON_BUILD_OBJECT(
      'id', id,
      'photo_url', photo_url,
      'caption', caption,
      'tags', tags,
      'taken_at', taken_at
    ) ORDER BY taken_at DESC
  ) AS posts
FROM setlog_posts
GROUP BY month
ORDER BY month DESC;

-- 뷰: 진행 중인 챌린지
CREATE VIEW active_challenges AS
SELECT 
  c.*,
  (c.current_value / NULLIF(c.target_value, 0) * 100) AS progress_pct,
  COUNT(cl.id) AS log_count
FROM challenges c
LEFT JOIN challenge_logs cl ON c.id = cl.challenge_id
WHERE c.status = 'active'
GROUP BY c.id;
