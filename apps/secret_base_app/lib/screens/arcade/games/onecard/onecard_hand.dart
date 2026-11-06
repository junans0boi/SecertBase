import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onecard_cards.dart';
import 'onecard_models.dart';
import 'onecard_ui.dart';

/// 카드 폭: 장수가 많을수록 조금 작게(폭 360~430에서 7~20장). 목업은 70.
double oneCardHandWidth(int count, double maxWidth) {
  final base = count <= 8
      ? 70.0
      : count <= 12
      ? 62.0
      : 54.0;
  return math.min(base, maxWidth / 4.2);
}

/// 손패 부채(목업 그대로): 카드는 한 장씩 3.2도, 가운데에서 멀수록 조금 내려가고,
/// 낼 수 있는 카드는 흰 헤어라인과 함께 들리고, 못 내는 카드는 어둡게 가린다.
class OneCardHandFan extends StatelessWidget {
  final List<OneCard> cards;
  final Set<String> playable;
  final Set<String> fresh;
  final bool active;
  final int revealCount;
  final ValueChanged<OneCard>? onTap;

  const OneCardHandFan({
    super.key,
    required this.cards,
    this.playable = const {},
    this.fresh = const {},
    this.active = false,
    this.revealCount = 1 << 20,
    this.onTap,
  });

  static const double lift = 20;

  /// 부채 전체 높이(카드 + 들림 여유). 가장자리 카드는 아래로 조금 더 내려간다.
  static double heightFor(double cw) => cw * kOneCardAspect + lift + 6;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cards.length;
        final maxW = constraints.maxWidth;
        final cw = oneCardHandWidth(n, maxW);
        final ch = cw * kOneCardAspect;
        final half = (n - 1) / 2;
        // 가장자리 카드가 너무 눕지 않게: 장수가 많으면 각도·낙차를 줄인다.
        final spread = n <= 1 ? 0.0 : math.min(3.2, 12 / half);
        final arc = n <= 1 ? 0.0 : math.min(2.2, 16 / (half * half));
        final maxAngle = half * spread * math.pi / 180;
        // 기울어진 가장자리 카드의 위쪽 모서리까지 화면 안에 들어오게 간격을 정한다.
        final reach =
            cw / 2 * math.cos(maxAngle) + 1.6 * ch * math.sin(maxAngle);
        final step = n <= 1
            ? 0.0
            : math.min(52 * cw / 70, (maxW / 2 - 2 - reach) / half);
        return SizedBox(
          width: maxW,
          height: heightFor(cw),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                _positioned(
                  i: i,
                  k: i - half,
                  cx: maxW / 2,
                  step: step,
                  cw: cw,
                  spread: spread,
                  arc: arc,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned({
    required int i,
    required double k,
    required double cx,
    required double step,
    required double cw,
    required double spread,
    required double arc,
  }) {
    final card = cards[i];
    final canPlay = active && playable.contains(card.id);
    final isFresh = fresh.contains(card.id);
    final shown = i < revealCount;
    final dy = k * k * arc - (canPlay ? lift : 0);
    return AnimatedPositioned(
      key: ValueKey(card.id),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: cx - cw / 2 + k * step,
      bottom: -dy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: shown ? 1 : 0,
        child: Transform.rotate(
          angle: k * spread * math.pi / 180,
          alignment: const Alignment(0, 2.2),
          child: Semantics(
            button: canPlay,
            enabled: canPlay,
            label: '${card.label}${canPlay ? ', 낼 수 있음' : ''}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap == null ? null : () => onTap!(card),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  OneCardFace(
                    card: card,
                    width: cw,
                    dimmed: active && !canPlay,
                    shadows: canPlay
                        ? OneCardShadows.lift
                        : OneCardShadows.rest,
                  ),
                  if (isFresh)
                    Positioned(
                      top: -8,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: OneCardUi.vio,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: OneCardUi.bg, width: 2),
                        ),
                        child: Text(
                          '새 카드',
                          style: OneCardUi.sans(
                            size: 10,
                            color: Colors.white,
                            weight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 상대 손패: 겹친 뒷면 작은 부채(120x52 영역, 카드 폭 26).
class OneCardOpponentFan extends StatelessWidget {
  final int count;
  final String skin;
  final double cardWidth;
  final int revealCount;

  const OneCardOpponentFan({
    super.key,
    required this.count,
    this.skin = 'base',
    this.cardWidth = 26,
    this.revealCount = 1 << 20,
  });

  @override
  Widget build(BuildContext context) {
    final shown = math.min(count, math.min(revealCount, 16));
    final cw = cardWidth;
    const boxW = 120.0;
    final half = (shown - 1) / 2;
    final step = shown <= 1
        ? 0.0
        : math.min(10.0, (boxW - cw - 8) / (shown - 1));
    return Semantics(
      label: '상대 손패 $count장',
      child: SizedBox(
        width: boxW,
        height: 52,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < shown; i++)
              Positioned(
                left: boxW / 2 - cw / 2 + (i - half) * step,
                top: (i - half) * (i - half) * 0.9,
                child: Transform.rotate(
                  angle: (i - half) * 4 * math.pi / 180,
                  child: OneCardBack(
                    width: cw,
                    skin: skin,
                    shadows: OneCardShadows.fan,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
