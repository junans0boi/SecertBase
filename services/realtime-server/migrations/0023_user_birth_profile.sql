-- 관계 이해 기능의 출생 프로필을 기존 사용자 데이터와 함께 확장한다.
ALTER TABLE Users
  ADD COLUMN IF NOT EXISTS BirthCalendarType ENUM('solar', 'lunar') NOT NULL DEFAULT 'solar',
  ADD COLUMN IF NOT EXISTS BirthTime TIME NULL,
  ADD COLUMN IF NOT EXISTS BirthTimezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Seoul',
  ADD COLUMN IF NOT EXISTS BirthPlace VARCHAR(255) NULL;
