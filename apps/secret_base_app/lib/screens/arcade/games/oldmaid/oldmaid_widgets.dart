import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/game_theme.dart';
import '../../../../widgets/play_kit/playing_card.dart';
import 'oldmaid_controller.dart';

/// 도둑잡기 카드 한 벌(크림 앞면 · 베리색 뒷면에 점무늬와 열쇠 구멍).
const kOldMaidStyle = CardStyle.storybook;

/// 연출 카드를 그리는 기준 폭(FittedBox로 실제 크기에 맞춘다).
const double kFxBaseWidth = 96;

/// 조커·강조 표시색(베리).
const kJokerRed = Color(0xFFA23B55);

/// 짝이 맞았을 때의 세이지색.
const kPairSage = Color(0xFF6F9A7E);

/// 앞면/뒷면을 [flip](0=뒷면, 1=앞면) 진행도로 뒤집어 보여 주는 카드.
class OldMaidFlipCard extends StatelessWidget {
  final OldMaidCard? card;
  final double width;
  final double flip;
  final bool highlight;
  final Color highlightColor;
  final String? badge;

  const OldMaidFlipCard({
    super.key,
    required this.card,
    required this.width,
    required this.flip,
    this.highlight = false,
    this.highlightColor = const Color(0xFF3B2430),
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final f = flip.clamp(0.0, 1.0);
    final showFace = card != null && f >= 0.5;
    final scaleX = math.max(0.02, (math.cos(f * math.pi)).abs());
    // 날아가는 카드는 고정 폭으로 그린 뒤 FittedBox로 늘리고 줄인다. 그래야 연출 위치와 정확히 겹친다.
    return SizedBox(
      width: width,
      height: width * 92 / 64,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scaleX, 1, 1),
        child: FittedBox(
          fit: BoxFit.fill,
          child: PlayingCard(
            suit: showFace ? card!.suit : null,
            rank: showFace ? card!.rank : null,
            faceUp: showFace,
            width: kFxBaseWidth,
            style: kOldMaidStyle,
            highlight: highlight,
            highlightColor: highlightColor,
            badge: showFace ? badge : null,
          ),
        ),
      ),
    );
  }
}

/// 버린 짝 더미: 비스듬히 겹친 카드 석 장(맨 위에 하트)과 "버린 짝 N쌍".
/// [glow]이면 짝이 막 들어간 것처럼 세이지 테두리가 둘린다.
class OldMaidDiscardStack extends StatelessWidget {
  final GameTheme theme;
  final int pairs;
  final double cardW;
  final bool glow;

  const OldMaidDiscardStack({
    super.key,
    required this.theme,
    required this.pairs,
    required this.cardW,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final h = cardW * 92 / 64;
    Widget plain(double angle) =>
        Transform.rotate(angle: angle, child: _blank(t, cardW, h, null));
    return Semantics(
      label: '버린 짝 $pairs쌍',
      excludeSemantics: true,
      child: SizedBox(
        width: 96,
        height: h + 8 + 18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: cardW,
              height: h,
              decoration: glow
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(cardW * 0.15),
                      boxShadow: [BoxShadow(color: kPairSage, spreadRadius: 2)],
                    )
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: plain(-9 * math.pi / 180)),
                  Positioned.fill(child: plain(6 * math.pi / 180)),
                  Positioned.fill(
                    child: _blank(t, cardW, h, Icons.favorite_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '버린 짝 ',
                        style: t.body(
                          size: 12.5,
                          color: t.subInk,
                          weight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(text: '$pairs', style: t.display(size: 15)),
                      TextSpan(
                        text: '쌍',
                        style: t.body(
                          size: 12.5,
                          color: t.subInk,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _blank(GameTheme t, double w, double h, IconData? icon) =>
      Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kOldMaidStyle.face,
          borderRadius: BorderRadius.circular(w * 0.15),
          border: Border.all(color: kOldMaidStyle.faceBorder!),
          boxShadow: [
            BoxShadow(
              color: t.ink.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: icon == null
            ? null
            : Icon(icon, size: w * 0.41, color: t.accent),
      );
}

/// 짝/조커 순간에 카드 위에 붙는 도장("짝!", "조커!").
class OldMaidStamp extends StatelessWidget {
  final GameTheme theme;
  final String text;
  final bool joker;

  const OldMaidStamp({
    super.key,
    required this.theme,
    required this.text,
    this.joker = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: joker ? theme.accent : kPairSage,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: theme
              .display(size: 16, color: Colors.white, weight: FontWeight.w800)
              .copyWith(height: 1.2),
        ),
      ),
    );
  }
}
