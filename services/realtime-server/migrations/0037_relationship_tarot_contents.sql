-- 버전·날짜·범위별 하루 한 장 타로 결과를 legacy 운세와 분리한다.
CREATE TABLE IF NOT EXISTS relationship_tarot_contents (
  tarot_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  couple_id INT NULL,
  content_date DATE NOT NULL,
  catalog_version VARCHAR(64) NOT NULL,
  card_key VARCHAR(64) NOT NULL,
  result_json LONGTEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_relationship_tarot_user (user_id, content_date, catalog_version),
  UNIQUE KEY uq_relationship_tarot_couple (couple_id, content_date, catalog_version),
  INDEX idx_relationship_tarot_user_date (user_id, content_date),
  INDEX idx_relationship_tarot_couple_date (couple_id, content_date),
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (couple_id) REFERENCES Couples(CoupleId) ON DELETE CASCADE
);
