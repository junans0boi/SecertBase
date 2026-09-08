-- 두 사람의 완료 결과를 조합한 공유 결과를 저장한다.
-- source attempt id는 재검사 시 어떤 동일 버전 조합에서 생성됐는지 추적하기 위한 내부 값이다.
CREATE TABLE IF NOT EXISTS relationship_couple_assessment_results (
  couple_result_id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  version_id INT NOT NULL,
  user1_attempt_id INT NOT NULL,
  user2_attempt_id INT NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_couple_result_source
    (couple_id, version_id, user1_attempt_id, user2_attempt_id),
  INDEX idx_relationship_couple_result_current (couple_id, version_id, couple_result_id),
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE,
  FOREIGN KEY (version_id) REFERENCES relationship_assessment_versions(version_id) ON DELETE CASCADE,
  FOREIGN KEY (user1_attempt_id) REFERENCES relationship_assessment_attempts(attempt_id) ON DELETE CASCADE,
  FOREIGN KEY (user2_attempt_id) REFERENCES relationship_assessment_attempts(attempt_id) ON DELETE CASCADE
);
