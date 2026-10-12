-- FCM device tokens (multiple devices per user) and per-type notification prefs.

CREATE TABLE IF NOT EXISTS device_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  platform VARCHAR(16) NOT NULL,
  token VARCHAR(512) NOT NULL,
  app_version VARCHAR(32) NULL,
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_device_token (token),
  INDEX idx_device_tokens_user (user_id, revoked_at)
);

CREATE TABLE IF NOT EXISTS notification_prefs (
  user_id INT PRIMARY KEY,
  partner_moment TINYINT(1) NOT NULL DEFAULT 1,
  today_loop TINYINT(1) NOT NULL DEFAULT 1,
  game_invite TINYINT(1) NOT NULL DEFAULT 1,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
