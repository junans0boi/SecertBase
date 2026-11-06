import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_card.dart';
import 'gostop_models.dart';

/// 바닥: 열두 달 자리(1~6월 윗줄, 7~12월 아랫줄)에 같은 월 패를 쌓아 두고, 왼쪽에 더미를 둔다.
/// 뻑으로 쌓인 월에는 도장이 찍힌다.
class GostopField extends StatelessWidget {
  final GameTheme theme;
  final List<HCard> field;

  /// 뻑 더미: 월 → 만든 사람.
  final Map<int, String> ppeok;
  final String? me;

  /// 내가 들어 올린 패의 월(같은 월 자리가 빛난다).
  final int? highlightMonth;
  final Set<String> hiddenIds;
  final Map<int, GlobalKey> slotKeys;
  final GlobalKey pileKey;
  final int deckCount;

  /// 두 장 선택 단계에서 고를 수 있는 패.
  final Set<String> choiceIds;
  final ValueChanged<HCard>? onTapCard;

  /// 도탄처럼 더미를 눌러 뒤집어야 할 때.
  final bool pileActive;
  final VoidCallback? onTapPile;

  const GostopField({
    super.key,
    required this.theme,
    required this.field,
    required this.ppeok,
    required this.me,
    required this.highlightMonth,
    required this.hiddenIds,
    required this.slotKeys,
    required this.pileKey,
    required this.deckCount,
    this.choiceIds = const {},
    this.onTapCard,
    this.pileActive = false,
    this.onTapPile,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.surfaceBorder.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Pile(
            theme: t,
            pileKey: pileKey,
            count: deckCount,
            active: pileActive,
            onTap: onTapPile,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  [1, 2, 3, 4, 5, 6],
                  [7, 8, 9, 10, 11, 12],
                ])
                  Row(
                    children: [
                      for (final m in row)
                        Expanded(
                          child: _Slot(
                            theme: t,
                            month: m,
                            slotKey: slotKeys[m]!,
                            cards: [
                              for (final c in field)
                                if (c.month == m) c,
                            ],
                            ppeok: ppeok[m],
                            me: me,
                            highlight: highlightMonth == m,
                            hiddenIds: hiddenIds,
                            choiceIds: choiceIds,
                            onTapCard: onTapCard,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final GameTheme theme;
  final int month;
  final GlobalKey slotKey;
  final List<HCard> cards;
  final String? ppeok;
  final String? me;
  final bool highlight;
  final Set<String> hiddenIds;
  final Set<String> choiceIds;
  final ValueChanged<HCard>? onTapCard;

  const _Slot({
    required this.theme,
    required this.month,
    required this.slotKey,
    required this.cards,
    required this.ppeok,
    required this.me,
    required this.highlight,
    required this.hiddenIds,
    required this.choiceIds,
    required this.onTapCard,
  });

  static const _dx = 4.0;
  static const _dy = 6.0;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = GostopCardSize.field.width;
    final h = gostopCardHeight(w);
    return Container(
      key: slotKey,
      height: h + 3 * _dy + 12,
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlight ? t.gold.withValues(alpha: 0.16) : Colors.transparent,
        border: Border.all(
          color: highlight
              ? t.gold.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: cards.isEmpty ? 0.07 : 0.0),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final dx = ((box.maxWidth - w) / 3).clamp(1.5, _dx);
          final left =
              ((box.maxWidth - w - (cards.length - 1).clamp(0, 3) * dx) / 2)
                  .clamp(0.0, 20.0);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 3,
                top: 1,
                child: Text(
                  '$month월',
                  style: t.body(
                    size: 8.5,
                    weight: FontWeight.w800,
                    color: Colors.white.withValues(
                      alpha: cards.isEmpty ? 0.26 : 0.5,
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < cards.length; i++)
                Positioned(
                  left: left + i.clamp(0, 3) * dx,
                  top: 11 + i.clamp(0, 3) * _dy,
                  child: Opacity(
                    opacity: hiddenIds.contains(cards[i].id) ? 0 : 1,
                    child: GostopCard(
                      key: ValueKey('field-${cards[i].id}'),
                      card: cards[i],
                      width: w,
                      highlighted: choiceIds.contains(cards[i].id),
                      dim:
                          choiceIds.isNotEmpty &&
                          !choiceIds.contains(cards[i].id),
                      onTap: onTapCard == null
                          ? null
                          : () => onTapCard!(cards[i]),
                    ),
                  ),
                ),
              if (ppeok != null && cards.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _PpeokStamp(theme: t, mine: ppeok == me),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 뻑 더미에 찍는 붉은 도장. 누가 만들었는지 색으로 안다(내 것은 초록 테두리).
class _PpeokStamp extends StatelessWidget {
  final GameTheme theme;
  final bool mine;

  const _PpeokStamp({required this.theme, required this.mine});

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.2,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFB3282D),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: mine ? theme.me : Colors.white, width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3)],
      ),
      child: Text(
        '뻑',
        style: theme.body(
          size: 10.5,
          weight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _Pile extends StatelessWidget {
  final GameTheme theme;
  final GlobalKey pileKey;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  const _Pile({
    required this.theme,
    required this.pileKey,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = GostopCardSize.field.width;
    return Semantics(
      button: onTap != null,
      label: '더미 $count장${active ? ', 눌러서 뒤집기' : ''}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: gostopCardHeight(w) + 22,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (var i = 2; i >= 0; i--)
                if (count > i)
                  Positioned(
                    left: 4.0 + i * 1.6,
                    top: 6.0 - i * 1.6,
                    child: GostopCard(
                      key: i == 0 ? pileKey : null,
                      card: null,
                      width: w,
                      highlighted: active && i == 0,
                    ),
                  ),
              if (count == 0)
                Positioned(
                  left: 4,
                  top: 6,
                  child: SizedBox(
                    key: pileKey,
                    width: w,
                    height: gostopCardHeight(w),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(9),
                    border: active ? Border.all(color: t.gold) : null,
                  ),
                  child: Text(
                    active ? '뒤집기' : '$count',
                    style: t.body(
                      size: 10.5,
                      weight: FontWeight.w900,
                      color: active ? t.gold : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
