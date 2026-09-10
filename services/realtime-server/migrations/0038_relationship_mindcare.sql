-- 마음관리 guided chat은 기존 관계 상담과 분리된 개인 비공개 세션이다.
CREATE TABLE IF NOT EXISTS relationship_mindcare_sessions (
  session_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  owner_user_id INT NOT NULL,
  content_version VARCHAR(32) NOT NULL,
  status ENUM('active', 'safety_pending', 'safety_support', 'completed', 'archived') NOT NULL DEFAULT 'active',
  current_state VARCHAR(64) NOT NULL,
  step_index INT NOT NULL DEFAULT 0,
  user_response_count INT NOT NULL DEFAULT 0,
  state_json JSON NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  last_message_at DATETIME NULL,
  INDEX idx_relationship_mindcare_owner (owner_user_id, status, updated_at),
  FOREIGN KEY (owner_user_id) REFERENCES Users(UserId) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relationship_mindcare_messages (
  message_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id BIGINT NOT NULL,
  sequence_no INT NOT NULL,
  role ENUM('user', 'assistant') NOT NULL,
  input_type ENUM('choice', 'text', 'safety') NULL,
  choice_key VARCHAR(64) NULL,
  risk_candidate VARCHAR(64) NULL,
  content TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_mindcare_sequence (session_id, sequence_no),
  INDEX idx_relationship_mindcare_messages_session (session_id, message_id),
  FOREIGN KEY (session_id) REFERENCES relationship_mindcare_sessions(session_id) ON DELETE CASCADE
);
