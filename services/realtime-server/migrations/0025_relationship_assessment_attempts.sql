-- 개인검사 시도와 문항별 임시 응답을 저장한다.
CREATE TABLE IF NOT EXISTS relationship_assessment_attempts (
  attempt_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  version_id INT NOT NULL,
  status ENUM('in_progress', 'completed', 'abandoned') NOT NULL DEFAULT 'in_progress',
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  completed_at DATETIME NULL,
  INDEX idx_relationship_attempt_user_version (user_id, version_id, status, attempt_id),
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (version_id) REFERENCES relationship_assessment_versions(version_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS relationship_assessment_attempt_answers (
  attempt_id INT NOT NULL,
  question_id INT NOT NULL,
  answer_value TINYINT NOT NULL,
  saved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (attempt_id, question_id),
  FOREIGN KEY (attempt_id) REFERENCES relationship_assessment_attempts(attempt_id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES relationship_assessment_questions(question_id) ON DELETE CASCADE
);
