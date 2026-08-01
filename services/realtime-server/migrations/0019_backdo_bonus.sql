-- Shop v3: yut_backdo_shield_pct 제거 → yut_backdo_bonus_pct 추가
-- 백도→도 변환 스탯(손해) 대신 유리한 위치 백도 시 추가 던지기 확률 스탯으로 교체

-- 1단계: ENUM에 yut_backdo_bonus_pct 추가 (yut_backdo_shield_pct 유지)
ALTER TABLE item_stats
  MODIFY COLUMN stat_key ENUM(
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
    'yut_mo_rate_pct',
    'yut_backdo_shield_pct',
    'yut_backdo_bonus_pct',
    'yut_win_coin_pct',
    'yut_overturn_pct',
    'piece_catch_resist_pct',
    'piece_catch_coin_bonus',
    'piece_safe_zone_pct',
    'piece_group_pct',
    'card_shield_pct',
    'card_lucky_draw_pct',
    'card_uno_protect_pct',
    'card_reverse_bonus'
  ) NOT NULL;

-- 2단계: 기존 yut_backdo_shield_pct 행을 yut_backdo_bonus_pct로 업데이트
--   B(43): 3→5%, A(46): 6→8%, S(50): 10→10%, SS(54): 18→17%, SSS(56): 25→25%
UPDATE item_stats SET stat_key = 'yut_backdo_bonus_pct', stat_value = 5  WHERE item_id = 43 AND stat_key = 'yut_backdo_shield_pct';
UPDATE item_stats SET stat_key = 'yut_backdo_bonus_pct', stat_value = 8  WHERE item_id = 46 AND stat_key = 'yut_backdo_shield_pct';
UPDATE item_stats SET stat_key = 'yut_backdo_bonus_pct', stat_value = 10 WHERE item_id = 50 AND stat_key = 'yut_backdo_shield_pct';
UPDATE item_stats SET stat_key = 'yut_backdo_bonus_pct', stat_value = 17 WHERE item_id = 54 AND stat_key = 'yut_backdo_shield_pct';
UPDATE item_stats SET stat_key = 'yut_backdo_bonus_pct', stat_value = 25 WHERE item_id = 56 AND stat_key = 'yut_backdo_shield_pct';

-- 3단계: yut_backdo_shield_pct ENUM 값 제거 (데이터 없으므로 안전)
ALTER TABLE item_stats
  MODIFY COLUMN stat_key ENUM(
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
    'yut_mo_rate_pct',
    'yut_backdo_bonus_pct',
    'yut_win_coin_pct',
    'yut_overturn_pct',
    'piece_catch_resist_pct',
    'piece_catch_coin_bonus',
    'piece_safe_zone_pct',
    'piece_group_pct',
    'card_shield_pct',
    'card_lucky_draw_pct',
    'card_uno_protect_pct',
    'card_reverse_bonus'
  ) NOT NULL;
