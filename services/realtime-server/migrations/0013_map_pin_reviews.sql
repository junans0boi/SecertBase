-- 비밀장소 리뷰 테이블
-- 커플이 함께 방문한 장소에 리뷰와 전용 사진을 남길 수 있다
CREATE TABLE IF NOT EXISTS map_pin_reviews (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  map_pin_id  INT         NOT NULL,
  user_id     INT         NOT NULL,
  couple_id   INT         NOT NULL,
  user_code   VARCHAR(50) NULL,
  content     TEXT        NULL,
  media_url   TEXT        NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_reviews_pin    (map_pin_id),
  INDEX idx_reviews_couple (couple_id),
  INDEX idx_reviews_user   (user_id)
);
