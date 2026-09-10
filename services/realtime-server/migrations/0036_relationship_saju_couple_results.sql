-- Couple 범위 사주 요약을 개인 명식 저장소와 분리한다.
CREATE TABLE IF NOT EXISTS relationship_saju_couple_results (
  saju_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  calculation_version VARCHAR(64) NOT NULL,
  input_fingerprint CHAR(64) NOT NULL,
  mode ENUM('complete', 'limited') NOT NULL,
  status ENUM('ready', 'limited') NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_saju_couple_input (couple_id, calculation_version, input_fingerprint, mode),
  INDEX idx_relationship_saju_couple_updated (couple_id, updated_at),
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);
