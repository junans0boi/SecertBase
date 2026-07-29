-- Repair catalog rows that were originally inserted through a non-UTF-8 client.
-- Keep this idempotent so every environment converges on the same Korean copy.
INSERT INTO shop_items (id, category, name, description, price, icon, active) VALUES
  (1, 'coupon',  '데이트 쿠폰',       '상대방에게 주는 특별한 약속 쿠폰', 500,  '🎟️', 1),
  (2, 'booster', '데일리 보너스 2배', '오늘 하루 데일리 보너스 2배 지급', 1000, '⚡',  1),
  (3, 'skin',    '황금 윷',           '윷놀이 말 황금 스킨',              2000, '✨',  1),
  (4, 'skin',    '꽃 테마',           '게임 배경 꽃 테마',                3000, '🌸',  1),
  (5, 'gacha',   '아이템 뽑기',       '랜덤 아이템 1개 획득',              800, '🎰',  1)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  icon = VALUES(icon);
