import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onecard_cards.dart';
import 'onecard_models.dart';

/// 카드 폭: 장수가 많을수록 조금 작게(폭 360~430에서 7~20장).
double oneCardHandWidth(int count, double maxWidth) {
  final base = count <= 8
      ? 66.0
      : count <= 12
      ? 60.0
      : 54.0;
  return math.min(base, maxWidth / 4.2);
}

/// 손패 부채. 겹침 간격을 폭에 맞춰 자동으로 줄이고, 낼 수 있는 카드는 살짝 들리며,
/// 방금 뽑은 카드는 NEW 빛이 돈다.
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

  static const double lift = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cards.length;
        final maxW = constraints.maxWidth;
        final cw = oneCardHandWidth(n, maxW);
        final ch = cw * kOneCardAspect;
        final maxAngle = math.min(0.2, 0.026 * n);
        // 기울어진 양 끝 카드가 화면 밖으로 나가지 않게 여유를 둔다.
        final pad = ch * math.sin(maxAngle) + 4;
        final usable = maxW - pad * 2;
        final step = n <= 1
            ? 0.0
            : math.min(cw * 0.64, (usable - cw) / (n - 1));
        final total = cw + step * math.max(0, n - 1);
        final left0 = (maxW - total) / 2;
        final arc = math.min(12.0, 1.2 * n);
        return SizedBox(
          width: maxW,
          height: ch + lift + arc + 6,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < n; i++)
                _positioned(
                  i: i,
                  n: n,
                  left: left0 + i * step,
                  cw: cw,
                  maxAngle: maxAngle,
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
    required int n,
    required double left,
    required double cw,
    required double maxAngle,
    required double arc,
  }) {
    final card = cards[i];
    final t = n <= 1 ? 0.0 : (i / (n - 1)) * 2 - 1;
    final canPlay = active && playable.contains(card.id);
    final isFresh = fresh.contains(card.id);
    final shown = i < revealCount;
    return AnimatedPositioned(
      key: ValueKey(card.id),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: left,
      top: lift + t * t * arc - (canPlay ? lift : 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: shown ? 1 : 0,
        child: Transform.rotate(
          angle: t * maxAngle,
          alignment: Alignment.bottomCenter,
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
                  if (canPlay || isFresh)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cw * 0.13),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isFresh
                                          ? const Color(0xFFFFE08A)
                                          : const Color(0xFFE8C27A))
                                      .withValues(alpha: isFresh ? 0.9 : 0.55),
                              blurRadius: isFresh ? 18 : 12,
                              spreadRadius: isFresh ? 2 : 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  OneCardFace(
                    card: card,
                    width: cw,
                    dimmed: active && !canPlay,
                  ),
                  if (isFresh)
                    Positioned(
                      top: -7,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE9A8), Color(0xFFE8B84A)],
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          '새 카드',
                          style: GoogleFonts.notoSans(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3A1A08),
                            height: 1.1,
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

/// 상대 손패: 겹친 뒷면 부채.
class OneCardOpponentFan extends StatelessWidget {
  final int count;
  final String skin;
  final double cardWidth;
  final int revealCount;

  const OneCardOpponentFan({
    super.key,
    required this.count,
    this.skin = 'base',
    this.cardWidth = 34,
    this.revealCount = 1 << 20,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shown = math.min(count, math.min(revealCount, 16));
        final cw = cardWidth;
        final ch = cw * kOneCardAspect;
        final maxW = math.min(constraints.maxWidth, 260.0);
        final step = shown <= 1
            ? 0.0
            : math.min(cw * 0.5, (maxW - cw) / (shown - 1));
        final total = cw + step * math.max(0, shown - 1);
        return Semantics(
          label: '상대 손패 $count장',
          child: SizedBox(
            width: math.max(total, cw),
            height: ch + 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < shown; i++)
                  Positioned(
                    left: i * step,
                    top:
                        4 +
                        (shown <= 1
                            ? 0
                            : math.pow((i / (shown - 1)) * 2 - 1, 2) * 4),
                    child: Transform.rotate(
                      angle: shown <= 1
                          ? 0
                          : -((i / (shown - 1)) * 2 - 1) * 0.12,
                      alignment: Alignment.topCenter,
                      child: OneCardBack(width: cw, skin: skin),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
