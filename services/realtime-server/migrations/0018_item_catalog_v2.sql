-- Shop v3: Item Catalog v2 — 50개 아이템 사전 제작 (active=0)
-- 현재 active=1 아이템(IDs 10-34)은 변경하지 않음
-- IDs 40-89: 신규 아이템, 업데이트마다 2개씩 active=1로 공개

INSERT INTO shop_items (id, category, game, slot, grade, name, description, price, icon, active) VALUES
  -- ─────────────────────────────────────────────────────────────────────
  -- yut_yut B grade (4개)
  -- ─────────────────────────────────────────────────────────────────────
  (40, 'skin', 'yut', 'yut_yut', 'B',   '벚꽃 윷',    '봄의 벚꽃이 흩날리는 윷',           0, '🌸', 0),
  (41, 'skin', 'yut', 'yut_yut', 'B',   '단풍 윷',    '붉게 물든 가을 단풍의 윷',           0, '🍁', 0),
  (42, 'skin', 'yut', 'yut_yut', 'B',   '새싹 윷',    '봄의 새싹처럼 싱그러운 윷',          0, '🌱', 0),
  (43, 'skin', 'yut', 'yut_yut', 'B',   '조약돌 윷',  '강가의 매끄러운 조약돌 윷',          0, '🪨', 0),
  -- yut_yut A grade (4개)
  (44, 'skin', 'yut', 'yut_yut', 'A',   '달빛 윷',    '은은한 달빛을 담은 윷',             0, '🌙', 0),
  (45, 'skin', 'yut', 'yut_yut', 'A',   '바람 윷',    '빠른 바람처럼 날아다니는 윷',        0, '💨', 0),
  (46, 'skin', 'yut', 'yut_yut', 'A',   '눈꽃 윷',    '겨울 눈꽃 결정을 담은 윷',          0, '❄️', 0),
  (47, 'skin', 'yut', 'yut_yut', 'A',   '파도 윷',    '힘찬 파도의 기운을 담은 윷',         0, '🌊', 0),
  -- yut_yut S grade (4개)
  (48, 'skin', 'yut', 'yut_yut', 'S',   '번개 윷',    '번개처럼 강렬한 힘의 윷 (뽑기 전용)',    0, '⚡', 0),
  (49, 'skin', 'yut', 'yut_yut', 'S',   '태양 윷',    '타오르는 태양의 기운을 담은 윷 (뽑기 전용)', 0, '☀️', 0),
  (50, 'skin', 'yut', 'yut_yut', 'S',   '얼음 윷',    '차갑고 투명한 얼음의 윷 (뽑기 전용)',    0, '🧊', 0),
  (51, 'skin', 'yut', 'yut_yut', 'S',   '폭풍 윷',    '거친 폭풍의 힘을 가진 윷 (뽑기 전용)',   0, '🌪️', 0),
  -- yut_yut SS grade (3개)
  (52, 'skin', 'yut', 'yut_yut', 'SS',  '용의 윷',    '동양 용의 신비로운 힘을 가진 윷 (뽑기 전용)', 0, '🐉', 0),
  (53, 'skin', 'yut', 'yut_yut', 'SS',  '봉황 윷',    '불사조 봉황의 날개를 닮은 윷 (뽑기 전용)', 0, '🦅', 0),
  (54, 'skin', 'yut', 'yut_yut', 'SS',  '천둥 윷',    '하늘을 가르는 천둥의 윷 (뽑기 전용)',    0, '⛈️', 0),
  -- yut_yut SSS grade (3개)
  (55, 'skin', 'yut', 'yut_yut', 'SSS', '신들의 윷',  '신화 속 신들이 사용하던 전설의 윷 (뽑기 전용)', 0, '✨', 0),
  (56, 'skin', 'yut', 'yut_yut', 'SSS', '우주의 윷',  '우주의 탄생과 소멸을 담은 윷 (뽑기 전용)', 0, '🌌', 0),
  (57, 'skin', 'yut', 'yut_yut', 'SSS', '운명의 윷',  '운명을 결정짓는 전설의 윷 (뽑기 전용)',   0, '🎯', 0),

  -- ─────────────────────────────────────────────────────────────────────
  -- yut_piece B grade (4개)
  -- ─────────────────────────────────────────────────────────────────────
  (58, 'skin', 'yut', 'yut_piece', 'B',   '토끼 말',    '귀여운 토끼 모양의 말',             0, '🐰', 0),
  (59, 'skin', 'yut', 'yut_piece', 'B',   '강아지 말',  '충직한 강아지 모양의 말',            0, '🐶', 0),
  (60, 'skin', 'yut', 'yut_piece', 'B',   '고양이 말',  '영리한 고양이 모양의 말',            0, '🐱', 0),
  (61, 'skin', 'yut', 'yut_piece', 'B',   '오리 말',    '사랑스러운 오리 모양의 말',          0, '🦆', 0),
  -- yut_piece A grade (4개)
  (62, 'skin', 'yut', 'yut_piece', 'A',   '호랑이 말',  '용맹한 호랑이 모양의 말',            0, '🐯', 0),
  (63, 'skin', 'yut', 'yut_piece', 'A',   '여우 말',    '영리한 여우 모양의 말',             0, '🦊', 0),
  (64, 'skin', 'yut', 'yut_piece', 'A',   '곰 말',      '강인한 곰 모양의 말',               0, '🐻', 0),
  (65, 'skin', 'yut', 'yut_piece', 'A',   '팬더 말',    '귀여운 팬더 모양의 말',             0, '🐼', 0),
  -- yut_piece S grade (4개)
  (66, 'skin', 'yut', 'yut_piece', 'S',   '용 말',      '강력한 용 모양의 말 (뽑기 전용)',        0, '🐲', 0),
  (67, 'skin', 'yut', 'yut_piece', 'S',   '독수리 말',  '날카로운 독수리 모양의 말 (뽑기 전용)',   0, '🦅', 0),
  (68, 'skin', 'yut', 'yut_piece', 'S',   '별똥별 말',  '빠른 별똥별 모양의 말 (뽑기 전용)',      0, '💫', 0),
  (69, 'skin', 'yut', 'yut_piece', 'S',   '사자 말',    '위엄있는 사자 모양의 말 (뽑기 전용)',    0, '🦁', 0),
  -- yut_piece SS grade (3개)
  (70, 'skin', 'yut', 'yut_piece', 'SS',  '불사조 말',  '다시 태어나는 불사조 말 (뽑기 전용)',    0, '🔥', 0),
  (71, 'skin', 'yut', 'yut_piece', 'SS',  '용왕 말',    '용왕의 기운을 가진 전설의 말 (뽑기 전용)', 0, '👑', 0),
  (72, 'skin', 'yut', 'yut_piece', 'SS',  '무지개 말',  '일곱 빛깔 무지개 말 (뽑기 전용)',       0, '🌈', 0),
  -- yut_piece SSS grade (3개)
  (73, 'skin', 'yut', 'yut_piece', 'SSS', '신수 말',    '신화 속 신성한 짐승 말 (뽑기 전용)',     0, '⚡', 0),
  (74, 'skin', 'yut', 'yut_piece', 'SSS', '은하수 말',  '은하수를 달리는 전설의 말 (뽑기 전용)',   0, '🌌', 0),
  (75, 'skin', 'yut', 'yut_piece', 'SSS', '천상의 말',  '천상계에서 내려온 말 (뽑기 전용)',       0, '✨', 0),

  -- ─────────────────────────────────────────────────────────────────────
  -- onecard_cardback B grade (3개)
  -- ─────────────────────────────────────────────────────────────────────
  (76, 'skin', 'onecard', 'onecard_cardback', 'B',   '안개 카드',     '신비로운 안개를 담은 카드',       0, '🌫️', 0),
  (77, 'skin', 'onecard', 'onecard_cardback', 'B',   '새벽 카드',     '이른 새벽의 고요함을 담은 카드',   0, '🌅', 0),
  (78, 'skin', 'onecard', 'onecard_cardback', 'B',   '이슬 카드',     '풀잎 위의 이슬을 담은 카드',      0, '💧', 0),
  -- onecard_cardback A grade (3개)
  (79, 'skin', 'onecard', 'onecard_cardback', 'A',   '노을 카드',     '붉게 물든 노을을 담은 카드',      0, '🌇', 0),
  (80, 'skin', 'onecard', 'onecard_cardback', 'A',   '달밤 카드',     '달빛 가득한 밤을 담은 카드',      0, '🌙', 0),
  (81, 'skin', 'onecard', 'onecard_cardback', 'A',   '단풍 카드',     '가을 단풍의 아름다움을 담은 카드', 0, '🍁', 0),
  -- onecard_cardback S grade (3개)
  (82, 'skin', 'onecard', 'onecard_cardback', 'S',   '오로라 카드',   '북극의 오로라를 담은 카드 (뽑기 전용)',    0, '🌌', 0),
  (83, 'skin', 'onecard', 'onecard_cardback', 'S',   '반딧불 카드',   '여름밤 반딧불을 담은 카드 (뽑기 전용)',    0, '✨', 0),
  (84, 'skin', 'onecard', 'onecard_cardback', 'S',   '폭포 카드',     '웅장한 폭포를 담은 카드 (뽑기 전용)',     0, '💦', 0),
  -- onecard_cardback SS grade (3개)
  (85, 'skin', 'onecard', 'onecard_cardback', 'SS',  '별자리 카드',   '밤하늘 별자리를 담은 카드 (뽑기 전용)',    0, '⭐', 0),
  (86, 'skin', 'onecard', 'onecard_cardback', 'SS',  '불꽃놀이 카드', '화려한 불꽃놀이를 담은 카드 (뽑기 전용)', 0, '🎆', 0),
  (87, 'skin', 'onecard', 'onecard_cardback', 'SS',  '영원 카드',     '영원한 사랑을 담은 카드 (뽑기 전용)',     0, '♾️', 0),
  -- onecard_cardback SSS grade (2개)
  (88, 'skin', 'onecard', 'onecard_cardback', 'SSS', '운명의 카드',   '운명의 실로 연결된 두 사람의 카드 (뽑기 전용)', 0, '🎴', 0),
  (89, 'skin', 'onecard', 'onecard_cardback', 'SSS', '우주 커플 카드','우주 어디서든 함께인 커플 카드 (뽑기 전용)',   0, '💑', 0)

ON DUPLICATE KEY UPDATE
  game=VALUES(game), slot=VALUES(slot), grade=VALUES(grade),
  name=VALUES(name), description=VALUES(description), price=VALUES(price),
  icon=VALUES(icon), active=VALUES(active);

-- ─────────────────────────────────────────────────────────────────────
-- item_stats 시드
-- ─────────────────────────────────────────────────────────────────────
INSERT INTO item_stats (item_id, stat_key, stat_value) VALUES
  -- ── yut_yut B ──────────────────────────────────────────────────────
  (40, 'yut_win_coin_pct',      3),   -- 벚꽃: 윷/모마다 코인+3%
  (41, 'yut_win_coin_pct',      4),   -- 단풍: 윷/모마다 코인+4%
  (42, 'coin_bonus_pct',        2),   -- 새싹: 게임 보상+2%
  (43, 'yut_backdo_shield_pct', 3),   -- 조약돌: 뒤도→도 변환 3%

  -- ── yut_yut A ──────────────────────────────────────────────────────
  (44, 'yut_control_pct',       5),   -- 달빛
  (44, 'yut_win_coin_pct',      4),
  (45, 'yut_control_pct',       6),   -- 바람
  (45, 'coin_bonus_pct',        4),
  (46, 'yut_backdo_shield_pct', 6),   -- 눈꽃
  (46, 'yut_win_coin_pct',      5),
  (47, 'yut_mo_rate_pct',       5),   -- 파도
  (47, 'coin_bonus_pct',        4),

  -- ── yut_yut S ──────────────────────────────────────────────────────
  (48, 'yut_control_pct',       9),   -- 번개
  (48, 'yut_win_coin_pct',      7),
  (48, 'coin_bonus_pct',        5),
  (49, 'yut_mo_rate_pct',       8),   -- 태양
  (49, 'yut_win_coin_pct',      8),
  (49, 'coin_bonus_pct',        5),
  (50, 'yut_backdo_shield_pct', 10),  -- 얼음
  (50, 'yut_control_pct',       7),
  (51, 'yut_overturn_pct',      9),   -- 폭풍
  (51, 'yut_control_pct',       8),
  (51, 'win_streak_bonus',    100),

  -- ── yut_yut SS ─────────────────────────────────────────────────────
  (52, 'yut_control_pct',      15),   -- 용의 윷
  (52, 'yut_mo_rate_pct',      12),
  (52, 'win_streak_bonus',    200),
  (53, 'yut_overturn_pct',     15),   -- 봉황 윷
  (53, 'yut_mo_rate_pct',      13),
  (53, 'coin_bonus_pct',       10),
  (54, 'yut_backdo_shield_pct',18),   -- 천둥 윷
  (54, 'yut_control_pct',      13),
  (54, 'yut_win_coin_pct',     12),

  -- ── yut_yut SSS ────────────────────────────────────────────────────
  (55, 'yut_control_pct',      25),   -- 신들의 윷
  (55, 'yut_mo_rate_pct',      20),
  (55, 'yut_overturn_pct',     18),
  (55, 'win_streak_bonus',    400),
  (56, 'yut_mo_rate_pct',      22),   -- 우주의 윷
  (56, 'yut_backdo_shield_pct',25),
  (56, 'coin_bonus_pct',       15),
  (56, 'gacha_rate_up',        10),
  (57, 'yut_control_pct',      22),   -- 운명의 윷
  (57, 'yut_overturn_pct',     20),
  (57, 'yut_win_coin_pct',     18),
  (57, 'win_streak_bonus',    300),

  -- ── yut_piece B ────────────────────────────────────────────────────
  (58, 'piece_catch_coin_bonus', 3),  -- 토끼
  (59, 'daily_bonus_add',      100),  -- 강아지
  (60, 'piece_catch_resist_pct', 3),  -- 고양이
  (61, 'piece_catch_coin_bonus', 4),  -- 오리

  -- ── yut_piece A ────────────────────────────────────────────────────
  (62, 'piece_catch_coin_bonus', 7),  -- 호랑이
  (62, 'yut_catch_bonus',       50),
  (63, 'piece_catch_resist_pct', 6),  -- 여우
  (63, 'piece_safe_zone_pct',    5),
  (64, 'piece_group_pct',        7),  -- 곰
  (64, 'daily_bonus_add',      150),
  (65, 'piece_safe_zone_pct',    6),  -- 팬더
  (65, 'coin_bonus_pct',         4),

  -- ── yut_piece S ────────────────────────────────────────────────────
  (66, 'piece_catch_coin_bonus', 10), -- 용 말
  (66, 'piece_catch_resist_pct',  8),
  (66, 'yut_catch_bonus',       100),
  (67, 'piece_catch_resist_pct', 10), -- 독수리 말
  (67, 'piece_safe_zone_pct',     9),
  (67, 'coin_bonus_pct',          6),
  (68, 'piece_safe_zone_pct',    12), -- 별똥별 말
  (68, 'piece_group_pct',         8),
  (68, 'daily_bonus_add',       200),
  (69, 'piece_catch_coin_bonus', 11), -- 사자 말
  (69, 'piece_group_pct',         9),
  (69, 'lose_refund_pct',         5),

  -- ── yut_piece SS ───────────────────────────────────────────────────
  (70, 'lose_refund_pct',        12), -- 불사조 말
  (70, 'piece_catch_resist_pct', 15),
  (70, 'coin_bonus_pct',         10),
  (71, 'piece_catch_coin_bonus', 18), -- 용왕 말
  (71, 'yut_catch_bonus',       200),
  (71, 'piece_group_pct',        13),
  (72, 'piece_safe_zone_pct',    18), -- 무지개 말
  (72, 'piece_catch_resist_pct', 13),
  (72, 'daily_bonus_add',       300),

  -- ── yut_piece SSS ──────────────────────────────────────────────────
  (73, 'piece_catch_resist_pct', 25), -- 신수 말
  (73, 'piece_catch_coin_bonus', 22),
  (73, 'lose_refund_pct',        15),
  (73, 'yut_catch_bonus',       300),
  (74, 'piece_safe_zone_pct',    25), -- 은하수 말
  (74, 'piece_group_pct',        22),
  (74, 'coin_bonus_pct',         15),
  (74, 'daily_bonus_add',       500),
  (75, 'piece_catch_coin_bonus', 25), -- 천상의 말
  (75, 'piece_catch_resist_pct', 20),
  (75, 'piece_group_pct',        18),
  (75, 'lose_refund_pct',        15),

  -- ── onecard_cardback B ─────────────────────────────────────────────
  (76, 'onecard_draw_reduce',     1), -- 안개 카드
  (77, 'coin_bonus_pct',          3), -- 새벽 카드
  (78, 'card_reverse_bonus',      3), -- 이슬 카드

  -- ── onecard_cardback A ─────────────────────────────────────────────
  (79, 'coin_bonus_pct',          6), -- 노을 카드
  (79, 'card_reverse_bonus',      5),
  (80, 'card_lucky_draw_pct',     6), -- 달밤 카드
  (80, 'onecard_draw_reduce',     1),
  (81, 'shop_discount_pct',       6), -- 단풍 카드
  (81, 'coin_bonus_pct',          4),

  -- ── onecard_cardback S ─────────────────────────────────────────────
  (82, 'card_shield_pct',         9), -- 오로라 카드
  (82, 'card_lucky_draw_pct',     8),
  (82, 'coin_bonus_pct',          5),
  (83, 'card_reverse_bonus',     10), -- 반딧불 카드
  (83, 'win_streak_bonus',      100),
  (83, 'coin_bonus_pct',          6),
  (84, 'card_uno_protect_pct',   10), -- 폭포 카드
  (84, 'card_lucky_draw_pct',     8),
  (84, 'onecard_draw_reduce',     2),

  -- ── onecard_cardback SS ────────────────────────────────────────────
  (85, 'card_shield_pct',        15), -- 별자리 카드
  (85, 'card_lucky_draw_pct',    13),
  (85, 'win_streak_bonus',      200),
  (86, 'card_reverse_bonus',     18), -- 불꽃놀이 카드
  (86, 'coin_bonus_pct',         12),
  (86, 'win_streak_bonus',      150),
  (87, 'card_uno_protect_pct',   18), -- 영원 카드
  (87, 'card_shield_pct',        13),
  (87, 'shop_discount_pct',      10),

  -- ── onecard_cardback SSS ───────────────────────────────────────────
  (88, 'card_shield_pct',        25), -- 운명의 카드
  (88, 'card_uno_protect_pct',   22),
  (88, 'card_lucky_draw_pct',    20),
  (88, 'win_streak_bonus',      400),
  (89, 'card_lucky_draw_pct',    25), -- 우주 커플 카드
  (89, 'card_reverse_bonus',     22),
  (89, 'coin_bonus_pct',         15),
  (89, 'shop_discount_pct',      12)

ON DUPLICATE KEY UPDATE stat_value = VALUES(stat_value);
