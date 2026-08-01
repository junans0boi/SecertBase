-- Shop v3: owned_items quantity column + 12 new stat keys + gacha v2 infrastructure

-- 1. owned_items: quantity 컬럼 추가 (합성 시스템 인프라)
--    중복 아이템은 새 행 대신 quantity++ 방식으로 처리
ALTER TABLE owned_items
  ADD COLUMN IF NOT EXISTS quantity INT NOT NULL DEFAULT 1;

-- 2. item_stats.stat_key ENUM 확장 (10개 → 22개)
--    MariaDB: MODIFY COLUMN으로 전체 ENUM 재정의
ALTER TABLE item_stats
  MODIFY COLUMN stat_key ENUM(
    -- 기존 10개 (순서 유지)
    'yut_control_pct',
    'coin_bonus_pct',
    'shop_discount_pct',
    'daily_bonus_add',
    'lose_refund_pct',
    'onecard_draw_reduce',
    'yut_catch_bonus',
    'gacha_rate_up',
    'daily_bonus_cooldown',
    'win_streak_bonus',
    -- 윷(yut_yut) 전용 4개
    'yut_mo_rate_pct',
    'yut_backdo_shield_pct',
    'yut_win_coin_pct',
    'yut_overturn_pct',
    -- 말(yut_piece) 전용 4개
    'piece_catch_resist_pct',
    'piece_catch_coin_bonus',
    'piece_safe_zone_pct',
    'piece_group_pct',
    -- 원카드(onecard_cardback) 전용 4개
    'card_shield_pct',
    'card_lucky_draw_pct',
    'card_uno_protect_pct',
    'card_reverse_bonus'
  ) NOT NULL;

-- 3. gacha_tiers 참조 테이블 (가챠 티어 설정을 DB로 관리)
CREATE TABLE IF NOT EXISTS gacha_tiers (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  tier        ENUM('normal','advanced','rare') NOT NULL,
  game        VARCHAR(20) NOT NULL COMMENT 'yut|onecard',
  grade       ENUM('B','A','S','SS','SSS') NOT NULL,
  weight      INT NOT NULL DEFAULT 0 COMMENT '가중치 (합계 10000)',
  cost        INT NOT NULL DEFAULT 0 COMMENT '금화 비용',
  UNIQUE KEY uq_tier_game_grade (tier, game, grade)
);

-- 윷놀이 가챠 확률 시드 (weight 합계 10000 = 100%)
INSERT INTO gacha_tiers (tier, game, grade, weight, cost) VALUES
  ('normal',   'yut', 'B',   6000, 3000),
  ('normal',   'yut', 'A',   3700, 3000),
  ('normal',   'yut', 'S',    300, 3000),
  ('advanced', 'yut', 'S',   8000, 45000),
  ('advanced', 'yut', 'SS',  1800, 45000),
  ('advanced', 'yut', 'SSS',  200, 45000),
  ('rare',     'yut', 'SS',  9600, 100000),
  ('rare',     'yut', 'SSS',  400, 100000)
ON DUPLICATE KEY UPDATE weight = VALUES(weight), cost = VALUES(cost);

-- 원카드 가챠 확률 시드
INSERT INTO gacha_tiers (tier, game, grade, weight, cost) VALUES
  ('normal',   'onecard', 'B',   6000, 3000),
  ('normal',   'onecard', 'A',   3700, 3000),
  ('normal',   'onecard', 'S',    300, 3000),
  ('advanced', 'onecard', 'S',   8000, 45000),
  ('advanced', 'onecard', 'SS',  1800, 45000),
  ('advanced', 'onecard', 'SSS',  200, 45000),
  ('rare',     'onecard', 'SS',  9600, 100000),
  ('rare',     'onecard', 'SSS',  400, 100000)
ON DUPLICATE KEY UPDATE weight = VALUES(weight), cost = VALUES(cost);
