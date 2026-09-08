-- 제출된 검사 시도의 결정론적 점수와 고정 템플릿 결과를 저장한다.
CREATE TABLE IF NOT EXISTS relationship_assessment_results (
  result_id INT AUTO_INCREMENT PRIMARY KEY,
  attempt_id INT NOT NULL UNIQUE,
  user_id INT NOT NULL,
  version_id INT NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_relationship_result_user_version (user_id, version_id, result_id),
  FOREIGN KEY (attempt_id) REFERENCES relationship_assessment_attempts(attempt_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (version_id) REFERENCES relationship_assessment_versions(version_id) ON DELETE CASCADE
);
