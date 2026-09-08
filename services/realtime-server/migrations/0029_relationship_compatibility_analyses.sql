-- 현재 개인검사 요약과 커플검사 결과를 조합한 공유 궁합 분석을 저장한다.
CREATE TABLE IF NOT EXISTS relationship_compatibility_analyses (
  analysis_id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  analysis_code VARCHAR(64) NOT NULL,
  analysis_version VARCHAR(32) NOT NULL,
  user1_attachment_result_id INT NOT NULL,
  user2_attachment_result_id INT NOT NULL,
  conflict_couple_result_id INT NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_compatibility_source
    (couple_id, analysis_code, analysis_version,
     user1_attachment_result_id, user2_attachment_result_id, conflict_couple_result_id),
  INDEX idx_relationship_compatibility_current (couple_id, analysis_code, analysis_id),
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE,
  FOREIGN KEY (user1_attachment_result_id) REFERENCES relationship_assessment_results(result_id) ON DELETE CASCADE,
  FOREIGN KEY (user2_attachment_result_id) REFERENCES relationship_assessment_results(result_id) ON DELETE CASCADE,
  FOREIGN KEY (conflict_couple_result_id) REFERENCES relationship_couple_assessment_results(couple_result_id) ON DELETE CASCADE
);
