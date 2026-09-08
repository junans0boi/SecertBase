-- 결정론적 핵심 결과와 별도로 선택적 자연어 설명 생성을 추적한다.
CREATE TABLE IF NOT EXISTS relationship_explanation_generations (
  generation_id INT AUTO_INCREMENT PRIMARY KEY,
  requester_user_id INT NULL,
  couple_id INT NULL,
  scope_type ENUM('personal_assessment', 'compatibility') NOT NULL,
  source_key VARCHAR(160) NOT NULL,
  status ENUM('pending', 'available', 'fallback', 'failed') NOT NULL DEFAULT 'pending',
  provider VARCHAR(64) NOT NULL,
  model VARCHAR(128) NULL,
  prompt_version VARCHAR(32) NOT NULL,
  context_version VARCHAR(32) NOT NULL,
  input_json LONGTEXT NOT NULL,
  explanation_text LONGTEXT NULL,
  error_code VARCHAR(64) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  INDEX idx_relationship_explanation_source (scope_type, source_key, generation_id),
  INDEX idx_relationship_explanation_couple (couple_id, scope_type, source_key, generation_id),
  FOREIGN KEY (requester_user_id) REFERENCES Users(UserId) ON DELETE SET NULL,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);
