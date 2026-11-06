import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'onecard_cards.dart';
import 'onecard_models.dart';
import 'onecard_ui.dart';

/// 가운데 판(390x268 격자에 목업 좌표 그대로): 뽑을 더미, 버린 더미(와일드는 고른 색으로 물듦),
/// 쌓인 벌칙 배지, "지금 색" 칩, 위쪽 안내(내 차례·공격·알림).
/// 좁거나 낮은 화면에서는 통째로 줄여 맞춘다.
class OneCardTable extends StatelessWidget {
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

  /// "내 차례" 같은 보라 알약.
  final String? banner;

  /// 공격이 쌓였을 때의 장밋빛 알약.
  final String? alert;

  /// 잠깐 뜨는 알림(밝은 알약). 항상 붙여 두고, [toastLive]일 때만 보인다.
  final Widget? toast;

  /// 알림이 떠 있는 동안은 위 둘을 가린다.
  final bool toastLive;

  /// 왼쪽 아래 구석(리액션 버튼 자리).
  final Widget? corner;

  const OneCardTable({
    super.key,
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
    this.banner,
    this.alert,
    this.toast,
    this.toastLive = false,
    this.corner,
  });

  static const double frameW = 390;
  static const double frameH = 268;

  @override
  Widget build(BuildContext context) {
    final under = recentDiscards.length > 1
        ? recentDiscards.sublist(
            math.max(0, recentDiscards.length - 3),
            recentDiscards.length - 1,
          )
        : const <OneCard>[];
    // 가장 최근 아래 카드가 목업의 "under"(-8도), 그 앞은 반대로 살짝 기울인다.
    const tilts = [(6.0, 5.0, 3.0), (-8.0, -4.0, 2.0)];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: frameW,
        height: frameH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(left: 45, top: 66, child: _Floor()),
            if (alert != null && !toastLive)
              Positioned(
                left: 0,
                right: 0,
                top: -20,
                child: Center(child: _Alert(text: alert!)),
              ),
            if (banner != null && alert == null && !toastLive)
              Positioned(
                left: 0,
                right: 0,
                top: -6,
                child: Center(child: _Banner(text: banner!)),
              ),
            // 뽑을 더미
            Positioned(
              left: 34,
              top: 62,
              child: Semantics(
                button: canDraw,
                label: canDraw
                    ? (drawStack > 0 ? '벌칙 $drawStack장 받기' : '한 장 뽑기')
                    : '뽑을 더미 $deckCount장',
                child: GestureDetector(
                  onTap: canDraw ? onDraw : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        key: deckKey,
                        width: 86,
                        height: 116,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final o in const [6.0, 3.0, 0.0])
                              Positioned(
                                left: o,
                                top: o,
                                child: OneCardBack(width: 76, skin: deckSkin),
                              ),
                            if (canDraw)
                              const Positioned.fill(
                                child: IgnorePointer(child: _PulseRing()),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '남은 더미 $deckCount장',
                        style: OneCardUi.sans(size: 12, color: OneCardUi.sub),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 버린 더미
            Positioned(
              left: 172,
              top: 36,
              child: SizedBox(
                key: discardKey,
                width: 100,
                height: 146,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < under.length; i++)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Transform.rotate(
                          angle:
                              tilts[tilts.length - under.length + i].$1 *
                              math.pi /
                              180,
                          child: Transform.translate(
                            offset: Offset(
                              tilts[tilts.length - under.length + i].$2,
                              tilts[tilts.length - under.length + i].$3,
                            ),
                            child: Opacity(
                              opacity: 0.9,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.7, 0, 0, 0, 0, //
                                  0, 0.7, 0, 0, 0, //
                                  0, 0, 0.7, 0, 0, //
                                  0, 0, 0, 1, 0,
                                ]),
                                child: OneCardFace(card: under[i], width: 84),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (topCard != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: OneCardFace(
                            key: ValueKey('${topCard!.id}:$declaredColor'),
                            card: topCard!,
                            width: 100,
                            tintColor: topCard!.isWild ? declaredColor : null,
                          ),
                        ),
                      ),
                    if (drawStack > 0)
                      Positioned(
                        left: 68,
                        top: -18,
                        child: _StackBadge(count: drawStack),
                      ),
                  ],
                ),
              ),
            ),
            if (drawStack > 0)
              Positioned(
                left: 172,
                top: 192,
                width: 100,
                child: Center(
                  child: Text(
                    '쌓인 벌칙 $drawStack장',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: OneCardUi.sans(
                      size: 12,
                      color: OneCardUi.roseSoft,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: CurrentColorChip(
                  color: currentColor,
                  declared: declaredColor != null,
                ),
              ),
            ),
            if (corner != null)
              Positioned(left: 14, bottom: -4, child: corner!),
            if (toast != null)
              Positioned(left: 0, right: 0, top: -10, child: toast!),
          ],
        ),
      ),
    );
  }
}

/// 버린 더미 아래의 은은한 바닥 빛.
class _Floor extends StatelessWidget {
  const _Floor();

  @override
  Widget build(BuildContext context) {
    // 지름 150의 원 빛을 300x150 타원으로 늘려 "closest-side" 타원과 같게 한다.
    return const IgnorePointer(
      child: SizedBox(
        width: 300,
        height: 150,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox.square(
            dimension: 150,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x4DA78BFA), Color(0x00A78BFA)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0x338E6CF2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x4DB9A2FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            style: OneCardUi.sans(
              size: 12,
              color: OneCardUi.vio2,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  final String text;
  const _Alert({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0x29D94A72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x73D94A72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            maxLines: 1,
            style: OneCardUi.sans(
              size: 13,
              color: OneCardUi.roseSoft,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 버린 더미 모서리의 쌓인 벌칙 배지(+4, +8).
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
          begin: 0.97,
          end: 1.05,
        ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: OneCardUi.rose,
            boxShadow: [
              BoxShadow(color: OneCardUi.bg, spreadRadius: 4),
              BoxShadow(
                color: Color(0x73D94A72),
                offset: Offset(0, 8),
                blurRadius: 18,
              ),
            ],
          ),
          child: Text(
            '+${widget.count}',
            style: OneCardUi.sans(
              size: 20,
              color: Colors.white,
              weight: FontWeight.w800,
              spacing: -0.02,
            ),
          ),
        ),
      ),
    );
  }
}

/// 뽑을 수 있을 때 더미를 감싸는 숨 쉬는 보랏빛 테두리.
class _PulseRing extends StatefulWidget {
  const _PulseRing();

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: OneCardUi.vio2.withValues(alpha: 0.12 + 0.2 * _c.value),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
