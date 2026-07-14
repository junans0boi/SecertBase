-- Secret Base MariaDB/MySQL Schema

-- 1. 사용자 및 커플 정보 테이블
CREATE TABLE IF NOT EXISTS Users (
  UserId INT AUTO_INCREMENT PRIMARY KEY,
  Email VARCHAR(255) UNIQUE NOT NULL,
  PasswordHash VARCHAR(255) NULL,
  PasswordSalt VARCHAR(255) NULL,
  UserName VARCHAR(100) NOT NULL,
  FullName VARCHAR(100) NOT NULL,
  Nickname VARCHAR(50) NOT NULL,
  BirthDate DATE NOT NULL,
  UserCode VARCHAR(10) UNIQUE NOT NULL,
  AuthProvider VARCHAR(32) NULL DEFAULT 'password',
  GoogleSubject VARCHAR(255) NULL,
  GooglePictureUrl TEXT NULL,
  is_premium TINYINT(1) DEFAULT 0,
  premium_expires_at DATETIME NULL,
  CreatedBy VARCHAR(50) DEFAULT 'system',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY idx_users_google_subject (GoogleSubject)
);

CREATE TABLE IF NOT EXISTS User_Preference (
  UserId INT PRIMARY KEY,
  UserIcon VARCHAR(255) NULL,
  PartnerCode VARCHAR(10) NULL,
  FOREIGN KEY (UserId) REFERENCES Users(UserId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Couples (
  CoupleId INT AUTO_INCREMENT PRIMARY KEY,
  RoomCode VARCHAR(50) UNIQUE NOT NULL,
  RoomSecret VARCHAR(100) NOT NULL,
  User1Id INT NOT NULL,
  User2Id INT NOT NULL,
  StartDate DATE NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (User1Id) REFERENCES Users(UserId),
  FOREIGN KEY (User2Id) REFERENCES Users(UserId)
);

-- 2. 셋로그 (Setlog)
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
);

-- 3. 비밀 지도 (Secret Map)
CREATE TABLE IF NOT EXISTS map_pins (
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
);

-- 4. 10시의 Q&A (Daily Questions)
CREATE TABLE IF NOT EXISTS daily_questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question TEXT NOT NULL,
  scheduled_date DATE NOT NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS question_answers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question_id INT NOT NULL,
  user_id INT NOT NULL,
  answer TEXT NOT NULL,
  UserName VARCHAR(100) NULL,
  answered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_qa_question (question_id)
);

-- 5. 목표 챌린지 (Goal Challenge)
CREATE TABLE IF NOT EXISTS challenges (
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
);

CREATE TABLE IF NOT EXISTS challenge_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  challenge_id INT NOT NULL,
  value DECIMAL(10,2) NOT NULL,
  note TEXT NULL,
  logged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_cl_challenge (challenge_id)
);

-- 6. 프라이빗 주크박스 (Jukebox)
CREATE TABLE IF NOT EXISTS jukebox_tracks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  artist VARCHAR(200) NULL,
  file_url TEXT NOT NULL,
  duration_sec INT NULL,
  uploaded_by VARCHAR(50) NOT NULL,
  uploaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 7. 타임캡슐
CREATE TABLE IF NOT EXISTS time_capsules (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  message TEXT NULL,
  media_url VARCHAR(500) NULL,
  created_by VARCHAR(100) NOT NULL,
  open_date DATE NOT NULL,
  is_opened TINYINT(1) NOT NULL DEFAULT 0,
  opened_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. 앨범
CREATE TABLE IF NOT EXISTS album_folders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NULL,
  title VARCHAR(200) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS album_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  folder_id INT NOT NULL,
  user_id INT NOT NULL,
  user_code VARCHAR(32) NOT NULL,
  photo_url TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_album_photos_folder (folder_id)
);

-- 9. 개인 회고
CREATE TABLE IF NOT EXISTS private_reflections (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  content TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reflections_user (user_id)
);

-- 10. 리텐션 & 기타 테이블
CREATE TABLE IF NOT EXISTS daily_engagement_days (
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
);

CREATE TABLE IF NOT EXISTS daily_engagement_actions (
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
);

CREATE TABLE IF NOT EXISTS daily_missions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(200) NOT NULL,
  description TEXT NULL,
  mission_type VARCHAR(50) NOT NULL DEFAULT 'confirm',
  requirement_type VARCHAR(50) NOT NULL DEFAULT 'both_confirm',
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_daily_mission_title (title)
);

CREATE TABLE IF NOT EXISTS couple_mission_instances (
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
);

CREATE TABLE IF NOT EXISTS couple_streaks (
  couple_id INT PRIMARY KEY,
  current_count INT NOT NULL DEFAULT 0,
  longest_count INT NOT NULL DEFAULT 0,
  last_completed_date DATE NULL,
  last_grace_used_date DATE NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS couple_timeline_events (
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
);

CREATE TABLE IF NOT EXISTS notification_tokens (
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
);

CREATE TABLE IF NOT EXISTS notification_events (
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
);

CREATE TABLE IF NOT EXISTS wish_tickets (
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
);

CREATE TABLE IF NOT EXISTS balance_questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  option_a VARCHAR(120) NOT NULL,
  option_b VARCHAR(120) NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_balance_options (option_a, option_b)
);

CREATE TABLE IF NOT EXISTS couple_balance_answers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  user_id INT NOT NULL,
  question_id INT NOT NULL,
  date DATE NOT NULL,
  choice CHAR(1) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_balance_answer (couple_id, user_id, date)
);

-- 샘플 질문 및 프로필 데이터
INSERT INTO daily_questions (question, scheduled_date) VALUES
  ('오늘 가장 행복했던 순간은?', '2026-06-18'),
  ('내일 하고 싶은 한 가지는?', '2026-06-19'),
  ('가장 좋아하는 음식은?', '2026-06-20')
ON DUPLICATE KEY UPDATE question=VALUES(question);
