-- 동일 게임의 재시도 정산이 승자/패자별로 한 번만 기록되도록 보장한다.
-- ref_id가 NULL인 일일 보너스 등 기존 거래는 UNIQUE 제약의 대상이 아니다.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_game_ref_reason
  ON wallet_transactions (ref_id, reason);
