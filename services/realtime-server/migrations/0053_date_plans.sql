-- 데이트 계획: Couple 공유 일정. 위시 지도 핀에서 시작하고, 다녀오면 기존 애프터글로우로 닫힌다.
-- 좌표·주소는 저장하지 않는다(핀 id만 연결). 모든 행은 couple_id를 가진다.
CREATE TABLE IF NOT EXISTS date_plans (
  id BIGINT NOT NULL AUTO_INCREMENT,
  couple_id INT NOT NULL,
  created_by INT NOT NULL,
  plan_date DATE NOT NULL,
  plan_time TIME NULL,
  title VARCHAR(80) NOT NULL,
  memo VARCHAR(500) NULL,
  map_pin_id INT NULL,
  completed_at DATETIME NULL,
  completed_by INT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_date_plans_couple_date (couple_id, plan_date),
  KEY idx_date_plans_pin (map_pin_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
