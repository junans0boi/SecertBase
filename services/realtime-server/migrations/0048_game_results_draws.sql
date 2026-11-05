-- 무승부 판을 기록하고(승자/패자 없음), 같은 판이 두 번 기록되지 않도록 한다.
-- game_id는 판마다 서버가 부여하는 식별자이며, 과거 행은 NULL로 남아 UNIQUE에서 제외된다.
ALTER TABLE game_results
  MODIFY COLUMN winner_user_code VARCHAR(10) NULL,
  MODIFY COLUMN loser_user_code VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS is_draw TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS player_a_code VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS player_b_code VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS game_id VARCHAR(64) NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_game_results_game_id ON game_results (game_id);
