-- 사주 입력 계약과 결정론적 결과를 legacy 운세 저장소와 분리한다.
ALTER TABLE Users
  ADD COLUMN IF NOT EXISTS BirthLunarLeapMonth TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS relationship_saju_results (
  saju_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  calculation_version VARCHAR(64) NOT NULL,
  input_fingerprint CHAR(64) NOT NULL,
  mode ENUM('complete', 'limited') NOT NULL,
  status ENUM('ready', 'limited') NOT NULL,
  input_summary_json LONGTEXT NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_saju_input (user_id, calculation_version, input_fingerprint, mode),
  INDEX idx_relationship_saju_user_updated (user_id, updated_at),
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE
);
