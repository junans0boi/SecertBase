-- Shop v2: game-specific categories, grade system, item stats, equip slots

-- 1. Extend shop_items
ALTER TABLE shop_items
  ADD COLUMN IF NOT EXISTS game    VARCHAR(20)                              COMMENT 'onecard|yut|tank|catch|null=global',
  ADD COLUMN IF NOT EXISTS slot    VARCHAR(30)                              COMMENT 'onecard_cardback|yut_yut|yut_piece|...',
  ADD COLUMN IF NOT EXISTS grade   ENUM('B','A','S','SS','SSS') DEFAULT 'B' COMMENT 'B/A=coin purchase, S/SS/SSS=gacha/mission';

-- 2. Per-item stat rows (10 fixed stat keys)
CREATE TABLE IF NOT EXISTS item_stats (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  item_id  INT NOT NULL,
  stat_key ENUM(
    'yut_control_pct',
    'coin_bonus_pct',
    'shop_discount_pct',
    'daily_bonus_add',
    'lose_refund_pct',
    'onecard_draw_reduce',
    'yut_catch_bonus',
    'gacha_rate_up',
    'daily_bonus_cooldown',
    'win_streak_bonus'
  ) NOT NULL,
  stat_value DECIMAL(8,2) NOT NULL DEFAULT 0,
  FOREIGN KEY (item_id) REFERENCES shop_items(id) ON DELETE CASCADE,
  UNIQUE KEY uq_item_stat (item_id, stat_key)
);

-- 3. owned_items에 user_id 추가 (스킨은 개인 소유; 기존 couple_id 보존)
ALTER TABLE owned_items
  ADD COLUMN IF NOT EXISTS user_id INT NULL AFTER couple_id,
  ADD INDEX IF NOT EXISTS idx_owned_user (user_id);

-- 4. Equip slots per user (one item per slot)
CREATE TABLE IF NOT EXISTS equipped_items (
  id         BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id    INT         NOT NULL,
  slot       VARCHAR(30) NOT NULL,
  item_id    INT         NOT NULL,
  equipped_at DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES Users(UserId) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES shop_items(id),
  UNIQUE KEY uq_user_slot (user_id, slot)
);

-- 4. Seed catalog — B/A grade (coin-purchasable), S/SS/SSS stubs (gacha later)

-- 원카드: 카드뒷면 스킨
INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active) VALUES
  (10, 'skin', 'onecard', 'onecard_cardback', 'B',   '벚꽃 카드뒷면',   '부드러운 벚꽃 패턴 카드',     1500, '🌸', 1),
  (11, 'skin', 'onecard', 'onecard_cardback', 'A',   '우주 카드뒷면',   '신비로운 우주 패턴 카드',     2500, '🌌', 1),
  (12, 'skin', 'onecard', 'onecard_cardback', 'A',   '하트 카드뒷면',   '커플 감성 하트 패턴 카드',    3000, '❤️', 1),
  (13, 'skin', 'onecard', 'onecard_cardback', 'S',   '황금 카드뒷면',   '빛나는 황금빛 카드 (뽑기 전용)', 0,  '✨', 1),
  (14, 'skin', 'onecard', 'onecard_cardback', 'SS',  '무지개 카드뒷면', '레인보우 홀로그램 카드 (뽑기 전용)', 0, '🌈', 1),
  (15, 'skin', 'onecard', 'onecard_cardback', 'SSS', '커플 카드뒷면',   '우리만의 특별한 커플 카드 (뽑기 전용)', 0, '💑', 1)
ON DUPLICATE KEY UPDATE
  game=VALUES(game), slot=VALUES(slot), grade=VALUES(grade),
  name=VALUES(name), description=VALUES(description), price=VALUES(price), icon=VALUES(icon);

-- 윷놀이: 윷 스킨
INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active) VALUES
  (20, 'skin', 'yut', 'yut_yut', 'B',   '대나무 윷',     '자연 감성 대나무 윷',          1500, '🎋', 1),
  (21, 'skin', 'yut', 'yut_yut', 'A',   '황금 윷',       '황금빛 윷 (+윷/모 확률)',       2500, '🏅', 1),
  (22, 'skin', 'yut', 'yut_yut', 'S',   '크리스탈 윷',   '영롱한 크리스탈 윷 (뽑기 전용)', 0,  '💎', 1),
  (23, 'skin', 'yut', 'yut_yut', 'SS',  '불꽃 윷',       '타오르는 불꽃 윷 (뽑기 전용)',  0,   '🔥', 1),
  (24, 'skin', 'yut', 'yut_yut', 'SSS', '전설의 윷',     '전설 등급 윷 (뽑기 전용)',      0,   '⚡', 1)
ON DUPLICATE KEY UPDATE
  game=VALUES(game), slot=VALUES(slot), grade=VALUES(grade),
  name=VALUES(name), description=VALUES(description), price=VALUES(price), icon=VALUES(icon);

-- 윷놀이: 말 스킨
INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active) VALUES
  (30, 'skin', 'yut', 'yut_piece', 'B',   '동물 말',       '귀여운 동물 모양 말',           1500, '🐾', 1),
  (31, 'skin', 'yut', 'yut_piece', 'A',   '음식 말',       '맛있는 음식 모양 말',           2000, '🍡', 1),
  (32, 'skin', 'yut', 'yut_piece', 'S',   '별 말',         '빛나는 별 모양 말 (뽑기 전용)', 0,   '⭐', 1),
  (33, 'skin', 'yut', 'yut_piece', 'SS',  '왕관 말',       '왕관 모양 말 (뽑기 전용)',      0,   '👑', 1),
  (34, 'skin', 'yut', 'yut_piece', 'SSS', '커플 말',       '커플 캐릭터 말 (뽑기 전용)',    0,   '💞', 1)
ON DUPLICATE KEY UPDATE
  game=VALUES(game), slot=VALUES(slot), grade=VALUES(grade),
  name=VALUES(name), description=VALUES(description), price=VALUES(price), icon=VALUES(icon);

-- 5. Seed item_stats for B/A grade items

-- 원카드 카드뒷면 스탯
INSERT INTO item_stats (item_id, stat_key, stat_value) VALUES
  (10, 'coin_bonus_pct',    3),   -- 벚꽃 B
  (11, 'coin_bonus_pct',    5),   -- 우주 A
  (12, 'shop_discount_pct', 5),   -- 하트 A
  (13, 'coin_bonus_pct',    8),   -- 황금 S
  (13, 'shop_discount_pct', 5),
  (14, 'coin_bonus_pct',   12),   -- 무지개 SS
  (14, 'shop_discount_pct', 8),
  (14, 'win_streak_bonus',  50),
  (15, 'coin_bonus_pct',   15),   -- 커플 SSS
  (15, 'shop_discount_pct',10),
  (15, 'win_streak_bonus', 100)
ON DUPLICATE KEY UPDATE stat_value = VALUES(stat_value);

-- 윷 스탯
INSERT INTO item_stats (item_id, stat_key, stat_value) VALUES
  (20, 'yut_control_pct',  2),    -- 대나무 B
  (21, 'yut_control_pct',  4),    -- 황금 A
  (21, 'coin_bonus_pct',   2),
  (22, 'yut_control_pct',  7),    -- 크리스탈 S
  (22, 'coin_bonus_pct',   3),
  (23, 'yut_control_pct', 10),    -- 불꽃 SS
  (23, 'coin_bonus_pct',   5),
  (23, 'win_streak_bonus', 30),
  (24, 'yut_control_pct', 15),    -- 전설 SSS
  (24, 'coin_bonus_pct',   8),
  (24, 'win_streak_bonus', 80)
ON DUPLICATE KEY UPDATE stat_value = VALUES(stat_value);

-- 말 스탯
INSERT INTO item_stats (item_id, stat_key, stat_value) VALUES
  (30, 'daily_bonus_add',  100),  -- 동물 B
  (31, 'daily_bonus_add',  150),  -- 음식 A
  (31, 'yut_catch_bonus',   50),
  (32, 'daily_bonus_add',  200),  -- 별 S
  (32, 'yut_catch_bonus',  100),
  (33, 'daily_bonus_add',  300),  -- 왕관 SS
  (33, 'yut_catch_bonus',  150),
  (33, 'lose_refund_pct',    5),
  (34, 'daily_bonus_add',  500),  -- 커플 SSS
  (34, 'yut_catch_bonus',  200),
  (34, 'lose_refund_pct',   10)
ON DUPLICATE KEY UPDATE stat_value = VALUES(stat_value);
