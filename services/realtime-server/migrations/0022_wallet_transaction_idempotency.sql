-- 게임 정산 재시도만 한 번 기록되도록 보장한다.
-- shop/gacha ref_id는 여러 사용자가 반복해서 공유하므로 전체 거래에는 적용하지 않는다.
-- 게임 거래가 아니면 generated column이 NULL이 되어 UNIQUE 제약에서 제외된다.
ALTER TABLE wallet_transactions
  ADD COLUMN IF NOT EXISTS game_ref_id VARCHAR(100)
    AS (IF(reason IN ('game_win', 'game_loss'), ref_id, NULL)) VIRTUAL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_game_ref_reason
  ON wallet_transactions (game_ref_id, reason);
