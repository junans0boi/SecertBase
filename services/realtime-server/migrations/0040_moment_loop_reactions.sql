-- MomentLoop reaction/session fields previously created lazily by request handlers.

ALTER TABLE setlog_posts
  ADD COLUMN IF NOT EXISTS session_id VARCHAR(64) NULL,
  ADD INDEX IF NOT EXISTS idx_setlog_session (session_id);

CREATE TABLE IF NOT EXISTS setlog_reactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  session_id VARCHAR(64) NOT NULL,
  user_id INT NOT NULL,
  emoji VARCHAR(8) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_reaction (couple_id, session_id, user_id),
  INDEX idx_reaction_session (couple_id, session_id)
);
