-- 0050_auth_consents_password_reset.sql
-- 2.0 로그인 영역:
--   * 동의 이력(user_consents): 약관·개인정보·만 14세·마케팅 동의를 버전·시각과 함께 남긴다(추가 전용).
--   * 가입 마무리 시각(Users.SignupCompletedAt): Google 신규 가입자는 닉네임·생일·동의를 마칠 때까지 NULL.
--     기존 계정은 컬럼 기본값(추가 시각)으로 채워져 "가입 완료"로 본다.
--   * 비밀번호 재설정 코드(password_reset_tokens): 코드·링크 토큰은 해시만 저장한다.
-- 여러 번 실행해도 같은 결과(멱등)다.

CREATE TABLE IF NOT EXISTS user_consents (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  consent_type VARCHAR(32) NOT NULL,
  version VARCHAR(32) NOT NULL,
  agreed TINYINT(1) NOT NULL,
  source VARCHAR(32) NOT NULL,
  agreed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_user_consents_user_type (user_id, consent_type, agreed_at)
);

ALTER TABLE Users
  ADD COLUMN IF NOT EXISTS SignupCompletedAt DATETIME NULL DEFAULT CURRENT_TIMESTAMP;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  code_hash CHAR(64) NOT NULL,
  link_hash CHAR(64) NOT NULL,
  attempts INT NOT NULL DEFAULT 0,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_password_reset_link (link_hash),
  INDEX idx_password_reset_user (user_id, used_at, expires_at)
);
