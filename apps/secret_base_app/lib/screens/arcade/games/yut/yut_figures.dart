import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';
import 'yut_palette.dart';

/// 말 그림 명세: 캐릭터 전신(홍길동·미호·놀부). 말 스킨은 폐지되어 캐릭터 그림만 쓴다.
@immutable
class YutFigureSpec {
  final String character;

  const YutFigureSpec({required this.character});
}

/// 등급별 테두리 색.
Color yutGradeColor(String grade) => switch (grade) {
  'SSS' => const Color(0xFFFF5FA8),
  'SS' => const Color(0xFFA56BFF),
  'S' => const Color(0xFFE5B22E),
  'A' => const Color(0xFFB9C4D2),
  _ => Colors.white,
};

/// 판 위·플레이어 카드·결과 화면에서 같은 모습으로 서 있는 말.
/// 팀은 발밑 색 원판과 부드러운 그림자로 구분하고, 그림 자체는 바꾸지 않는다.
/// 위젯 바닥 가운데에서 [anchorFromBottom]만큼 위가 발 디딘 곳(칸 중심)이다.
class YutFigure extends StatelessWidget {
  final double height;
  final Color team;
  final YutFigureSpec spec;
  final int count;
  final bool selected;
  final bool glow;
  final bool dimmed;

  /// 0..1을 반복하는 공용 애니메이션(까딱까딱·반짝임). 없으면 정지.
  final Animation<double>? idle;

  /// 여러 말이 같이 까딱거리지 않게 시작 위상을 어긋나게 한다(0..1).
  final double phase;
  final bool badge;

  const YutFigure({
    super.key,
    required this.height,
    required this.team,
    required this.spec,
    this.count = 1,
    this.selected = false,
    this.glow = false,
    this.dimmed = false,
    this.idle,
    this.phase = 0,
    this.badge = true,
  });

  double get width => height * 0.86;
  double get anchorFromBottom => height * 0.075;

  @override
  Widget build(BuildContext context) {
    final body = idle == null
        ? _build(context, 0)
        : AnimatedBuilder(
            animation: idle!,
            builder: (context, _) =>
                _build(context, (idle!.value + phase) % 1.0),
          );
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: SizedBox(width: width, height: height, child: body),
    );
  }

  Widget _build(BuildContext context, double t) {
    final h = height;
    final baseH = h * 0.15;
    final baseW = h * 0.64;
    final figH = h * 0.86;
    final bob = math.sin(t * math.pi * 2) * h * 0.012;
    final stacked = math.min(count, 3);

    Widget figure(int i) {
      final dx = stacked == 1 ? 0.0 : (i - (stacked - 1) / 2) * h * 0.2;
      final dy = (stacked - 1 - i) * -h * 0.015;
      return Positioned(
        left: (width - h * 0.8) / 2 + dx,
        bottom: baseH * 0.4 + dy - bob * (i.isEven ? 1 : -1),
        width: h * 0.8,
        height: figH,
        child: _CharacterImage(character: spec.character),
      );
    }

    final pal = YutPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 부드러운 타원 그림자 + 팀 색 가는 고리(그림은 그대로, 팀은 발밑에서만 구분).
        Positioned(
          left: (width - baseW) / 2,
          bottom: 0,
          width: baseW,
          height: baseH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(baseW, baseH)),
              color: team.withValues(alpha: 0.16),
              border: Border.all(
                color: selected ? Colors.white : team,
                width: selected ? 2.6 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: pal.shadow,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
                if (selected || glow)
                  BoxShadow(
                    color: team.withValues(alpha: selected ? 0.75 : 0.5),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < stacked; i++) figure(i),
        if (badge && count > 1)
          Positioned(
            right: -h * 0.04,
            top: h * 0.0,
            child: Container(
              constraints: BoxConstraints(
                minWidth: h * 0.34,
                minHeight: h * 0.3,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pal.acc,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.6),
                boxShadow: [
                  BoxShadow(color: pal.acc2, offset: const Offset(0, 2)),
                ],
              ),
              child: Text(
                '×$count',
                style: pal.display(size: 14, color: pal.onAcc, height: 1.1),
              ),
            ),
          ),
      ],
    );
  }
}

class _CharacterImage extends StatelessWidget {
  final String character;

  const _CharacterImage({required this.character});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      yutCharacterAsset(character),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          (yutCharacterNames[character] ?? '말').characters.first,
          style: GoogleFonts.jua(fontSize: 22, color: const Color(0xFF263A2A)),
        ),
      ),
    );
  }
}

/// 로비 아바타 원 안에 고른 캐릭터의 얼굴(머리 부분)을 보여 준다.
class YutCharacterAvatar extends StatelessWidget {
  final String character;
  final double size;

  const YutCharacterAvatar({
    super.key,
    required this.character,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final aspect = yutCharacterAspect(character);
    // 전신 그림의 위쪽(머리·상체)만 원 안에 맞춘다.
    final w = size * 1.12;
    final h = w / aspect;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: w,
          maxWidth: w,
          minHeight: h,
          maxHeight: h,
          child: Transform.translate(
            offset: Offset(0, size * 0.02),
            child: Image.asset(
              yutCharacterAsset(character),
              width: w,
              height: h,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
