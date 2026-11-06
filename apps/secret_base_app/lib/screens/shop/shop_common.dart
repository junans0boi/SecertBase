import 'package:flutter/material.dart';

import '../../v2/v2.dart';

// ── Grades ────────────────────────────────────────────────────────────────────

const gradeOrder = ['B', 'A', 'S', 'SS', 'SSS'];

/// 등급은 색 + 글자로 함께 보여 줘요 (`희귀 A`).
String gradeLabel(String grade) => switch (grade) {
  'A' => '희귀',
  'S' => '특별',
  'SS' => '전설',
  'SSS' => '신화',
  _ => '일반',
};

V2Tone gradeTone(String grade) => switch (grade) {
  'A' => V2Tone.sage,
  'S' => V2Tone.sky,
  'SS' => V2Tone.lilac,
  'SSS' => V2Tone.honey,
  _ => V2Tone.neutral,
};

Color gradeColor(String grade) => V2ToneColors.of(gradeTone(grade)).base;

/// `희귀 A` chip — the same look on the shop, the inventory and the gacha.
class GradeChip extends StatelessWidget {
  const GradeChip({super.key, required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) =>
      V2Chip(label: '${gradeLabel(grade)} $grade', tone: gradeTone(grade));
}

/// 보유 중 / 장착 중 badge. Null when the item is neither.
Widget? ownershipChip({required bool owned, required bool equipped}) {
  if (equipped) {
    return const V2Chip(label: '장착 중', tone: V2Tone.rose, icon: V2Icons.check);
  }
  if (owned) return const V2Chip(label: '보유 중', tone: V2Tone.ok);
  return null;
}

// ── Categories (shop + inventory share these) ────────────────────────────────

class ShopCategory {
  const ShopCategory(this.game, this.label, this.icon);

  /// Server `game` value; null means 전체.
  final String? game;
  final String label;
  final IconData icon;
}

const shopCategories = <ShopCategory>[
  ShopCategory(null, '전체', Icons.apps_rounded),
  ShopCategory('yut', '윷놀이', Icons.casino_rounded),
  ShopCategory('onecard', '원카드', Icons.style_rounded),
];

IconData categoryIcon(Object? game) => switch (game) {
  'yut' => Icons.casino_rounded,
  'onecard' => Icons.style_rounded,
  _ => Icons.redeem_rounded,
};

/// Chip row with the shared category filter.
class CategoryFilter extends StatelessWidget {
  const CategoryFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        for (final c in shopCategories)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: V2Chip(
              label: c.label,
              selected: selected == c.game,
              onTap: () => onChanged(c.game),
            ),
          ),
      ],
    ),
  );
}

/// Item picture: a tinted tile with the category icon (no emoji).
class ItemArt extends StatelessWidget {
  const ItemArt({
    super.key,
    required this.game,
    this.grade = 'B',
    this.size = 56,
  });

  final Object? game;
  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = V2ToneColors.of(gradeTone(grade));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(categoryIcon(game), color: t.text, size: size * 0.5),
    );
  }
}

// ── Coins ─────────────────────────────────────────────────────────────────────

/// `52300` → `52,300`.
String coinText(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// `1500` → `1.5K` — only for tight game-art price pills.
String compactCoins(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K' : '$n';

/// The one place a balance is shown. Tapping opens "코인 얻는 법".
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.balance, required this.onTap});

  final int? balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(V2Tone.honey);
    final text = balance == null ? '–' : coinText(balance!);
    return Semantics(
      button: true,
      label: '내 코인 $text. 눌러서 코인 얻는 법 보기',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(V2Radius.pill),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: V2Space.tap),
          child: Center(
            child: Container(
              key: const Key('shop_balance_card'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: t.soft,
                borderRadius: BorderRadius.circular(V2Radius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on_rounded, size: 18, color: t.base),
                  const SizedBox(width: 6),
                  Text(text, style: V2Text.bodyStrong.copyWith(color: t.text)),
                  const SizedBox(width: 2),
                  Icon(V2Icons.chevron, size: 16, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

/// 아이템 효과 수치를 읽기 좋게(0.4 → "0.4", 8.0 → "8").
String formatStatValue(num value) {
  final v = value.toDouble();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

const statLabels = {
  'coin_bonus_pct': '승리 코인 +%',
  'shop_discount_pct': '상점 할인 %',
  'daily_bonus_add': '데일리 추가 코인',
  'lose_refund_pct': '패배 환급 %',
  'yut_control_pct': '윷·모 확률 +%p',
  'yut_catch_bonus': '말 잡기 보너스 코인',
  'gacha_rate_up': '뽑기 높은 등급 확률 +%',
  'daily_bonus_cooldown': '데일리 쿨타임 감소',
  'win_streak_bonus': '연승 추가 코인',
  'onecard_draw_reduce': '+카드 1장 감소',
  'yut_mo_rate_pct': '모(5칸) 확률 +%p',
  'yut_backdo_bonus_pct': '유리한 백도 추가 던지기 %',
  'yut_win_coin_pct': '윷·모 코인 보너스(판돈 %)',
  'yut_overturn_pct': '지고 있을 때 윷·모 확률 +%p',
  'yut_backdo_shield_pct': '빽도 방어(다시 던질 확률 %)',
  'piece_catch_resist_pct': '잡힘 방어 %',
  'piece_catch_coin_bonus': '상대 잡기 추가 코인',
  'piece_safe_zone_pct': '잡힐 확률 추가 감소 %',
  'piece_group_pct': '업은 말 분리 방지 %',
  'card_shield_pct': '공격 카드 무효화 %',
  'card_lucky_draw_pct': '원하는 카드 뽑기 %',
  'card_uno_protect_pct': '원카드 선언 보호 %',
  'card_reverse_bonus': '리버스/스킵 추가 코인',
};

/// One effect row: label on the left, `+값` chip on the right.
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.statKey,
    required this.value,
    required this.grade,
  });

  final String statKey;
  final num value;
  final String grade;

  @override
  Widget build(BuildContext context) {
    final t = V2ToneColors.of(gradeTone(grade));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(statLabels[statKey] ?? statKey, style: V2Text.body),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(V2Radius.pill),
            ),
            child: Text(
              '+${formatStatValue(value)}',
              style: V2Text.label.copyWith(color: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gacha tiers ───────────────────────────────────────────────────────────────

/// 뽑기 한 단계. 가격과 확률은 서버 `gacha_tiers` 시드(0017_shop_v3.sql)와 같은
/// 값이에요. 서버가 이 값을 내려주는 API가 아직 없어서 앱에 상수로 두고, 확률
/// 시트에는 그 사실과 기준일을 밝혀요.
class GachaTier {
  const GachaTier(this.id, this.name, this.blurb, this.cost, this.odds);

  final String id;
  final String name;
  final String blurb;
  final int cost;

  /// grade → 만분율(합계 10000).
  final Map<String, int> odds;
}

const kGachaTiers = <GachaTier>[
  GachaTier('normal', '일반 뽑기', '일반 · 희귀 · 특별 등급이 나와요', 3000, {
    'B': 6000,
    'A': 3700,
    'S': 300,
  }),
  GachaTier('advanced', '고급 뽑기', '특별 · 전설 · 신화 등급이 나와요', 45000, {
    'S': 8000,
    'SS': 1800,
    'SSS': 200,
  }),
  GachaTier('rare', '레어 뽑기', '전설 · 신화 등급만 나와요', 100000, {
    'SS': 9600,
    'SSS': 400,
  }),
];

/// `6000` → `60.0%`.
String oddsPercent(int basisPoints) =>
    '${(basisPoints / 100).toStringAsFixed(1)}%';

/// Shop error reasons the server returns → plain Korean.
String shopReasonText(String? reason) => switch (reason) {
  'insufficient_coins' => '코인이 부족해요.',
  'item_not_found' => '아이템을 찾을 수 없어요.',
  'already_owned' => '이미 가진 아이템이에요.',
  'gacha_only' => '이 아이템은 뽑기에서만 얻을 수 있어요.',
  _ => '잠시 후 다시 시도해 주세요.',
};
