-- 상담 원문은 private 세션 소유자에게만 노출한다. 현재 운영 정책상 DB 운영자는 원문을 볼 수 있다.
CREATE TABLE IF NOT EXISTS relationship_counseling_sessions (
  session_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  scope_type ENUM('private', 'shared') NOT NULL,
  owner_user_id INT NULL,
  couple_id INT NULL,
  title VARCHAR(160) NOT NULL DEFAULT '관계 대화',
  status ENUM('active', 'archived') NOT NULL DEFAULT 'active',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_message_at DATETIME NULL,
  INDEX idx_relationship_counseling_private (scope_type, owner_user_id, updated_at),
  INDEX idx_relationship_counseling_shared (scope_type, couple_id, updated_at),
  FOREIGN KEY (owner_user_id) REFERENCES Users(UserId) ON DELETE SET NULL,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relationship_counseling_messages (
  message_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT NOT NULL,
  sequence_no INT NOT NULL,
  role ENUM('user', 'assistant', 'system') NOT NULL,
  author_user_id INT NULL,
  content LONGTEXT NOT NULL,
  provider VARCHAR(64) NULL,
  model VARCHAR(128) NULL,
  prompt_version VARCHAR(32) NULL,
  context_version VARCHAR(32) NULL,
  generation_status ENUM('available', 'fallback', 'failed') NULL,
  error_code VARCHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_counseling_sequence (session_id, sequence_no),
  INDEX idx_relationship_counseling_messages_session (session_id, message_id),
  FOREIGN KEY (session_id) REFERENCES relationship_counseling_sessions(session_id) ON DELETE CASCADE,
  FOREIGN KEY (author_user_id) REFERENCES Users(UserId) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS relationship_shareable_insights (
  insight_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  private_session_id BIGINT NOT NULL,
  creator_user_id INT NOT NULL,
  couple_id INT NOT NULL,
  insight_text TEXT NOT NULL,
  status ENUM('approved', 'revoked') NOT NULL DEFAULT 'approved',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME NULL,
  INDEX idx_relationship_shareable_insights_couple (couple_id, status, created_at),
  INDEX idx_relationship_shareable_insights_creator (creator_user_id, status, created_at),
  FOREIGN KEY (private_session_id) REFERENCES relationship_counseling_sessions(session_id) ON DELETE CASCADE,
  FOREIGN KEY (creator_user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);
