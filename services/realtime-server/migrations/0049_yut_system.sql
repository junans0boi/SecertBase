-- 0049_yut_system.sql
-- 윷놀이 시스템 개편(티켓 27):
--   * 말(yut_piece) 스킨 폐지: 말은 캐릭터(홍길동·미호·놀부)로만 쓴다.
--   * 윷 스킨(yut_yut)을 9종으로 정리: 등급(B/A/S/SS/SSS)마다 겉모습과 효과 하나가 다르다.
--   * 예전 윷·말 아이템은 은퇴(active=0, game='yut_legacy')시키고, 가진 윷은 같은 등급 새 스킨으로 바꿔 준다.
-- 여러 번 실행해도 같은 결과(멱등)다. 소유 기록은 지우지 않는다.

-- 1. 새 윷 스킨 9종 (id 110–118). B·A는 코인 구매, S·SS·SSS는 뽑기 전용(가격 0).
INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active) VALUES
  (110, 'skin', 'yut', 'yut_yut', 'B',   '대나무 윷', '곧게 자란 대나무 윷 · 윷·모 확률이 아주 조금 올라요',        1500, '🎋', 1),
  (111, 'skin', 'yut', 'yut_yut', 'B',   '단풍 윷',   '붉게 물든 단풍 윷 · 잡힘 방어가 조금 올라요',              1500, '🍁', 1),
  (112, 'skin', 'yut', 'yut_yut', 'A',   '달빛 윷',   '은은한 달빛 윷 · 빽도가 나오면 가끔 다시 던져요',          2500, '🌙', 1),
  (113, 'skin', 'yut', 'yut_yut', 'A',   '옥 윷',     '맑은 옥빛 윷 · 윷·모를 던지면 판돈 코인이 쌓여요',         2500, '💚', 1),
  (114, 'skin', 'yut', 'yut_yut', 'S',   '얼음 윷',   '투명한 얼음 윷 · 잡힘 방어가 올라요 (뽑기 전용)',           0, '🧊', 1),
  (115, 'skin', 'yut', 'yut_yut', 'S',   '번개 윷',   '번쩍이는 번개 윷 · 윷·모 확률이 올라요 (뽑기 전용)',        0, '⚡', 1),
  (116, 'skin', 'yut', 'yut_yut', 'SS',  '불꽃 윷',   '타오르는 불꽃 윷 · 지고 있을 때 윷·모 확률이 올라요 (뽑기 전용)', 0, '🔥', 1),
  (117, 'skin', 'yut', 'yut_yut', 'SS',  '용의 윷',   '푸른 용이 감긴 윷 · 윷·모 코인 보너스가 커요 (뽑기 전용)',   0, '🐉', 1),
  (118, 'skin', 'yut', 'yut_yut', 'SSS', '신들의 윷', '신화 속 신들이 쓰던 윷 · 윷·모 확률이 가장 높이 올라요 (뽑기 전용)', 0, '✨', 1)
ON DUPLICATE KEY UPDATE
  category=VALUES(category), game=VALUES(game), slot=VALUES(slot), grade=VALUES(grade),
  name=VALUES(name), description=VALUES(description), price=VALUES(price), icon=VALUES(icon), active=VALUES(active);

-- 2. 효과: 스킨마다 하나. 값은 서버 합산 상한 안에서 캐릭터 능력치와 함께 쓰인다(yut-engine.js).
DELETE FROM item_stats WHERE item_id BETWEEN 110 AND 118;
INSERT INTO item_stats (item_id, stat_key, stat_value) VALUES
  (110, 'yut_control_pct',        0.4),  -- 대나무 B: 윷·모 확률
  (111, 'piece_catch_resist_pct', 2),    -- 단풍 B: 잡힘 방어
  (112, 'yut_backdo_shield_pct',  8),    -- 달빛 A: 빽도 방어(빽도가 나오면 다시 던질 확률 %)
  (113, 'yut_win_coin_pct',       4),    -- 옥 A: 윷·모 코인(판돈 %)
  (114, 'piece_catch_resist_pct', 4),    -- 얼음 S: 잡힘 방어
  (115, 'yut_control_pct',        0.8),  -- 번개 S: 윷·모 확률
  (116, 'yut_overturn_pct',       1),    -- 불꽃 SS: 역전(지고 있을 때 윷·모 확률)
  (117, 'yut_win_coin_pct',       8),    -- 용 SS: 윷·모 코인(판돈 %)
  (118, 'yut_control_pct',        1.2);  -- 신들 SSS: 윷·모 확률(가장 높게)

-- 3. 예전 윷 → 새 윷 대응표(같은 등급). 성격이 비슷한 것끼리 묶었다.
CREATE TABLE IF NOT EXISTS yut_skin_migration_map (
  old_id INT PRIMARY KEY,
  new_id INT NOT NULL
);
INSERT INTO yut_skin_migration_map (old_id, new_id) VALUES
  (20, 110), (21, 113), (22, 114), (23, 116), (24, 118),
  (40, 111), (41, 111), (42, 110), (43, 110),
  (44, 112), (45, 112), (46, 113), (47, 113),
  (48, 115), (49, 115), (50, 114), (51, 114),
  (52, 117), (53, 116), (54, 116),
  (55, 118), (56, 118), (57, 118)
ON DUPLICATE KEY UPDATE new_id = VALUES(new_id);

-- 4. 가진 예전 윷을 새 스킨으로 바꿔 준다(이미 가졌으면 그대로 둔다).
INSERT IGNORE INTO owned_items (user_id, item_id, quantity)
SELECT oi.user_id, m.new_id, 1
FROM owned_items oi
JOIN yut_skin_migration_map m ON m.old_id = oi.item_id
WHERE oi.user_id IS NOT NULL;

-- 5. 장착 중이던 예전 윷은 대응하는 새 스킨으로 바꾸고, 말 스킨 장착은 모두 푼다.
UPDATE equipped_items ei
JOIN yut_skin_migration_map m ON m.old_id = ei.item_id
SET ei.item_id = m.new_id
WHERE ei.slot = 'yut_yut';
DELETE FROM equipped_items WHERE slot = 'yut_piece';

-- 6. 예전 윷·말 아이템은 은퇴: 상점·도감·뽑기(game='yut')에서 빠지고, 소유 기록은 남는다.
UPDATE shop_items
SET active = 0, game = 'yut_legacy'
WHERE slot IN ('yut_yut', 'yut_piece')
  AND game = 'yut'
  AND id NOT BETWEEN 110 AND 118;

DROP TABLE IF EXISTS yut_skin_migration_map;
