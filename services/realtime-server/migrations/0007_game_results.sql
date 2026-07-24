CREATE TABLE IF NOT EXISTS game_results (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  couple_id INT NOT NULL,
  game_type VARCHAR(50) NOT NULL,
  winner_user_code VARCHAR(10) NOT NULL,
  loser_user_code VARCHAR(10) NOT NULL,
  stake INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_gr_couple_type (couple_id, game_type),
  INDEX idx_gr_couple_at (couple_id, created_at)
);
