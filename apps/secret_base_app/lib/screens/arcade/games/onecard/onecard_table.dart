import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'onecard_cards.dart';
import 'onecard_models.dart';

/// 가운데 판: 뽑을 더미, 버린 더미(와일드는 고른 색으로 물듦), "지금 색" 칩, 쌓인 벌칙 배지.
class OneCardTable extends StatelessWidget {
  final GameTheme theme;
  final GlobalKey deckKey;
  final GlobalKey discardKey;
  final OneCard? topCard;
  final List<OneCard> recentDiscards;
  final String? currentColor;
  final String? declaredColor;
  final int drawStack;
  final int deckCount;
  final String deckSkin;
  final bool canDraw;
  final VoidCallback? onDraw;
  final String mode;

  const OneCardTable({
    super.key,
    required this.theme,
    required this.deckKey,
    required this.discardKey,
    required this.topCard,
    required this.recentDiscards,
    required this.currentColor,
    required this.declaredColor,
    required this.drawStack,
    required this.deckCount,
    required this.deckSkin,
    required this.canDraw,
    required this.onDraw,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = math.min(
          74.0,
          math.min(constraints.maxWidth / 4.6, constraints.maxHeight / 2.3),
        );
        final ch = cw * kOneCardAspect;
        final under = recentDiscards.length > 1
            ? recentDiscards.sublist(
                math.max(0, recentDiscards.length - 3),
                recentDiscards.length - 1,
              )
            : const <OneCard>[];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 뽑을 더미
                Semantics(
                  button: canDraw,
                  label: canDraw
                      ? (drawStack > 0 ? '벌칙 $drawStack장 받기' : '한 장 뽑기')
                      : '뽑을 더미 $deckCount장',
                  child: GestureDetector(
                    onTap: canDraw ? onDraw : null,
                    child: SizedBox(
                      key: deckKey,
                      width: cw + 10,
                      height: ch + 10,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Positioned(
                              left: i * 2.5,
                              top: 6 - i * 2.5,
                              child: OneCardBack(width: cw, skin: deckSkin),
                            ),
                          if (canDraw)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: _PulseRing(color: t.gold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: cw * 0.42),
                // 버린 더미
                SizedBox(
                  key: discardKey,
                  width: cw + 16,
                  height: ch + 12,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < under.length; i++)
                        Transform.rotate(
                          angle: (i.isEven ? -1 : 1) * (0.14 + i * 0.05),
                          child: OneCardFace(
                            card: under[i],
                            width: cw,
                            dimmed: true,
                          ),
                        ),
                      if (topCard != null)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: OneCardFace(
                            key: ValueKey('${topCard!.id}:$declaredColor'),
                            card: topCard!,
                            width: cw,
                            tintColor: topCard!.isWild ? declaredColor : null,
                          ),
                        ),
                      if (drawStack > 0)
                        Positioned(
                          top: -10,
                          right: -14,
                          child: _StackBadge(count: drawStack),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CurrentColorChip(
                  color: currentColor,
                  declared: declaredColor != null,
                ),
                GameChip(theme: t, label: '남은 더미 $deckCount장', color: t.subInk),
                GameChip(
                  theme: t,
                  label: mode == 'classic' ? '클래식' : '고와일드',
                  color: t.accent,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StackBadge extends StatefulWidget {
  final int count;
  const _StackBadge({required this.count});

  @override
  State<_StackBadge> createState() => _StackBadgeState();
}

class _StackBadgeState extends State<_StackBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '쌓인 벌칙 ${widget.count}장',
      child: ScaleTransition(
        scale: Tween(
          begin: 0.94,
          end: 1.08,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A8A), Color(0xFFC2185B)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE8C27A), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x88FF4F7A), blurRadius: 14),
            ],
          ),
          child: Text(
            '+${widget.count}',
            style: GameTheme.salon.display(size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(
                alpha: 0.55 * (1 - (_c.value - 0.5).abs() * 2),
              ),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
