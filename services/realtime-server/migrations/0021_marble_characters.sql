-- 0021_marble_characters.sql
-- 마블 작전 캐릭터 시스템: shop_items에 character_id 추가 + 10종 캐릭터 아이템 + 유저 기본 장착

-- 1. shop_items.category ENUM에 'character' 추가
ALTER TABLE shop_items
  MODIFY COLUMN category ENUM('skin','booster','gacha','coupon','character') NOT NULL;

-- 2. shop_items에 character_id 컬럼 추가
ALTER TABLE shop_items
  ADD COLUMN IF NOT EXISTS character_id VARCHAR(20) NULL
  COMMENT 'marble 캐릭터 ID (k, ria, luna, rex, zia, drv, hayun, jake, nova, omega)';

-- 3. 마블 캐릭터 아이템 삽입
--    IDs 100-109: marble_character_m/f 슬롯
--    기본 (active=1, price=0): 케이(100), 리아(101)
--    상점 (active=0): 나머지 8종 — 업데이트마다 활성화
INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active, character_id) VALUES
  (100, 'character', 'marble', 'marble_character_m', 'B',   '케이',     '마블 작전 기본 에이전트 (남)', 0,    '🕵️',    1, 'k'),
  (101, 'character', 'marble', 'marble_character_f', 'B',   '리아',     '마블 작전 기본 에이전트 (여)', 0,    '🕵️‍♀️', 1, 'ria'),
  (102, 'character', 'marble', 'marble_character_f', 'A',   '루나',     '에이전트 루나 — 보라 파워',   2000, '🌙',    0, 'luna'),
  (103, 'character', 'marble', 'marble_character_m', 'A',   '렉스',     '에이전트 렉스 — 야전 전문가', 2000, '💪',    0, 'rex'),
  (104, 'character', 'marble', 'marble_character_f', 'A',   '지아',     '에이전트 지아 — 첩보의 달인', 2000, '🦋',    0, 'zia'),
  (105, 'character', 'marble', 'marble_character_m', 'S',   '닥터V',    '에이전트 닥터V — 과학 천재',  3500, '🔬',    0, 'drv'),
  (106, 'character', 'marble', 'marble_character_f', 'S',   '하윤',     '에이전트 하윤 — 숲의 사냥꾼', 3500, '🌿',    0, 'hayun'),
  (107, 'character', 'marble', 'marble_character_m', 'S',   '제이크',   '에이전트 제이크 — 해군 특수대',3500, '⚓',    0, 'jake'),
  (108, 'character', 'marble', 'marble_character_f', 'SS',  '노바',     '에이전트 노바 — 폭발 전문가', 5000, '💥',    0, 'nova'),
  (109, 'character', 'marble', 'marble_character_m', 'SSS', '오메가',   '에이전트 오메가 — 정체불명',  0,    '⬛',    0, 'omega')
ON DUPLICATE KEY UPDATE
  character_id = VALUES(character_id),
  category     = VALUES(category),
  name         = VALUES(name),
  description  = VALUES(description),
  active       = VALUES(active);

-- 4. 기존 모든 유저에게 기본 캐릭터 소유권 부여
INSERT IGNORE INTO owned_items (user_id, item_id)
SELECT UserId, 100 FROM Users;

INSERT IGNORE INTO owned_items (user_id, item_id)
SELECT UserId, 101 FROM Users;

-- 5. 기존 모든 유저에게 기본 캐릭터 장착
INSERT IGNORE INTO equipped_items (user_id, slot, item_id)
SELECT UserId, 'marble_character_m', 100 FROM Users;

INSERT IGNORE INTO equipped_items (user_id, slot, item_id)
SELECT UserId, 'marble_character_f', 101 FROM Users;
