-- 알림 확대: 기념일 D-1, 마주 열기 상대 답변 도착. 기본 켜짐.
ALTER TABLE notification_prefs
  ADD COLUMN IF NOT EXISTS anniversary_eve TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS two_answers_waiting TINYINT(1) NOT NULL DEFAULT 1;
