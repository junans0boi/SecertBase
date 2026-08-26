-- 동일 사용자의 같은 거래 재시도가 한 번만 기록되도록 보장한다.
-- shop/gacha ref_id는 여러 사용자가 공유하므로 user_id를 함께 사용해야 한다.
-- ref_id가 NULL인 일일 보너스 등 기존 거래는 MariaDB UNIQUE 규칙상 제약의 대상이 아니다.
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_user_ref_reason
  ON wallet_transactions (user_id, ref_id, reason);
