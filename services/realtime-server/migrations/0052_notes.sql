-- 쪽지(Notes): 활성 Couple 안의 짧은 대화. 모든 행은 couple_id를 가진다.
-- 예약 열람(open_at) 전에는 서버가 받는 사람에게 본문·첨부를 내보내지 않는다.
CREATE TABLE IF NOT EXISTS couple_notes (
  id BIGINT NOT NULL AUTO_INCREMENT,
  couple_id INT NOT NULL,
  sender_id INT NOT NULL,
  body TEXT NOT NULL,
  media_url TEXT NULL,
  map_pin_id INT NULL,
  setlog_post_id INT NULL,
  open_at DATETIME NULL,
  delivered_at DATETIME NULL,
  read_at DATETIME NULL,
  reaction VARCHAR(16) NULL,
  deleted_at DATETIME NULL,
  client_request_id VARCHAR(64) COLLATE utf8mb4_bin NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_couple_notes_couple_id (couple_id, id),
  KEY idx_couple_notes_due (delivered_at, open_at),
  UNIQUE KEY uq_couple_notes_sender_req (sender_id, client_request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 쪽지 알림 설정(푸시 본문은 고정 문구).
ALTER TABLE notification_prefs
  ADD COLUMN IF NOT EXISTS partner_note TINYINT(1) NOT NULL DEFAULT 1;
