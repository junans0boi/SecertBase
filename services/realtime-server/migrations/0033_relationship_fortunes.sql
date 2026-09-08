-- Birth-profile 기반의 결정론적 운세 결과를 날짜와 콘텐츠 버전별로 보존한다.
CREATE TABLE IF NOT EXISTS relationship_fortune_contents (
  fortune_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  couple_id INT NULL,
  content_date DATE NOT NULL,
  fortune_type ENUM('personal', 'relationship', 'emotional_flow') NOT NULL,
  content_version VARCHAR(32) NOT NULL,
  provider VARCHAR(64) NOT NULL,
  model VARCHAR(128) NULL,
  prompt_version VARCHAR(32) NOT NULL,
  context_version VARCHAR(32) NOT NULL,
  status ENUM('available', 'fallback') NOT NULL DEFAULT 'fallback',
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_fortune_user (user_id, content_date, fortune_type, content_version),
  UNIQUE KEY uq_relationship_fortune_couple (couple_id, content_date, fortune_type, content_version),
  INDEX idx_relationship_fortune_user_date (user_id, content_date),
  INDEX idx_relationship_fortune_couple_date (couple_id, content_date),
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);
