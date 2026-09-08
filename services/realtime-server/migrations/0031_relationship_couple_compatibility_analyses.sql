-- 커플검사 shared result별 궁합 분석을 독립적으로 저장한다.
CREATE TABLE IF NOT EXISTS relationship_couple_compatibility_analyses (
  analysis_id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  analysis_code VARCHAR(64) NOT NULL,
  analysis_version VARCHAR(32) NOT NULL,
  source_couple_result_id INT NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_couple_compatibility_source
    (couple_id, analysis_code, analysis_version, source_couple_result_id),
  INDEX idx_relationship_couple_compatibility_current
    (couple_id, analysis_code, analysis_id),
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE,
  FOREIGN KEY (source_couple_result_id)
    REFERENCES relationship_couple_assessment_results(couple_result_id) ON DELETE CASCADE
);
