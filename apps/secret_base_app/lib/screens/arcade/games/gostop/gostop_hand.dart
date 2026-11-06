import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_card.dart';
import 'gostop_models.dart';

/// 내 손패 부채. 10장도 360px에 겹쳐 들어가고, 한 번 누르면 들리고(바닥에서 맞는 자리가 빛남)
/// 들린 패를 한 번 더 누르면 낸다.
class GostopHandFan extends StatelessWidget {
  final GameTheme theme;
  final List<HCard> cards;
  final String? selectedId;
  final String? recommendedId;

  /// 지금 바닥에 같은 월이 있어 먹을 수 있는 월.
  final Set<int> capturableMonths;
  final bool active;

  /// 새 판 분배 연출 중 앞에서 몇 장만 보여 줄지.
  final int revealCount;
  final ValueChanged<HCard> onTap;
  final ValueChanged<HCard>? onLongPress;
  final Set<String> hiddenIds;

  const GostopHandFan({
    super.key,
    required this.theme,
    required this.cards,
    required this.selectedId,
    required this.recommendedId,
    required this.capturableMonths,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.revealCount = 1 << 20,
    this.hiddenIds = const {},
  });

  static const double lift = 14;
  static const double _maxDrop = 8;

  @override
  Widget build(BuildContext context) {
    final w = GostopCardSize.hand.width;
    final h = gostopCardHeight(w);
    return SizedBox(
      height: h + lift + _maxDrop + 6,
      child: LayoutBuilder(
        builder: (context, box) {
          final n = cards.length;
          if (n == 0) {
            return Center(
              child: Text(
                '손패가 없어요',
                style: theme.body(size: 12, color: theme.subInk),
              ),
            );
          }
          final maxStep = w * 0.9;
          final step = n <= 1
              ? 0.0
              : math.min(maxStep, (box.maxWidth - w - 22) / (n - 1));
          final total = (n - 1) * step + w;
          final start = (box.maxWidth - total) / 2;
          final mid = (n - 1) / 2;
          Widget build(int i) {
            final c = cards[i];
            final selected = c.id == selectedId;
            final dist = i - mid;
            final angle = selected ? 0.0 : dist * 0.034;
            final drop = selected ? 0.0 : dist * dist * 0.4;
            final capturable = capturableMonths.contains(c.month);
            final recommended = c.id == recommendedId && !selected;
            return AnimatedPositioned(
              key: ValueKey('hand-${c.id}'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              left: start + i * step,
              bottom: 2 + _maxDrop + (selected ? lift : 0) - drop,
              child: Opacity(
                opacity: (i >= revealCount || hiddenIds.contains(c.id)) ? 0 : 1,
                child: Transform.rotate(
                  angle: angle,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedScale(
                    scale: selected ? 1.07 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GostopCard.sized(
                          card: c,
                          size: GostopCardSize.hand,
                          highlighted: selected,
                          dim: !active,
                          onTap: () => onTap(c),
                          onLongPress: onLongPress == null
                              ? null
                              : () => onLongPress!(c),
                        ),
                        if (active && (capturable || recommended))
                          Positioned(
                            left: 2,
                            top: -4,
                            child: IgnorePointer(
                              child: _Tag(
                                theme: theme,
                                label: recommended ? '추천' : '먹기',
                                strong: recommended,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final order = [
            for (var i = 0; i < n; i++)
              if (cards[i].id != selectedId) i,
            for (var i = 0; i < n; i++)
              if (cards[i].id == selectedId) i,
          ];
          return Stack(
            clipBehavior: Clip.none,
            children: [for (final i in order) build(i)],
          );
        },
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final bool strong;

  const _Tag({required this.theme, required this.label, required this.strong});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: strong ? theme.gold : const Color(0xFF1E6B3E),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.85),
        width: 0.8,
      ),
    ),
    child: Text(
      label,
      style: theme.body(
        size: 9,
        weight: FontWeight.w900,
        color: strong ? const Color(0xFF3A2A00) : Colors.white,
      ),
    ),
  );
}
