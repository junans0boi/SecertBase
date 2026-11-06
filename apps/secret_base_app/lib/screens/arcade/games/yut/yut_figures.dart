import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';

/// 말 그림 명세: 캐릭터 전신, 또는 상점 동물 말(이모지 + 등급).
@immutable
class YutFigureSpec {
  final String character;

  /// 상점 말 스킨(`yut_piece` 아이템). 있으면 캐릭터 대신 서 있는 동물 말을 그린다.
  final String? skinEmoji;
  final String skinGrade;
  final String? skinName;

  const YutFigureSpec({
    required this.character,
    this.skinEmoji,
    this.skinGrade = 'B',
    this.skinName,
  });

  bool get isSkin => skinEmoji != null && skinEmoji!.isNotEmpty;

  factory YutFigureSpec.of(String character, Map<String, dynamic>? pieceItem) {
    final icon = pieceItem == null ? null : '${pieceItem['icon'] ?? ''}';
    if (icon == null || icon.isEmpty) {
      return YutFigureSpec(character: character);
    }
    return YutFigureSpec(
      character: character,
      skinEmoji: icon,
      skinGrade: '${pieceItem?['grade'] ?? 'B'}',
      skinName: pieceItem?['name'] as String?,
    );
  }
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
  double get anchorFromBottom => height * 0.115;

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
    final baseH = h * 0.21;
    final baseW = h * 0.74;
    final figH = h * 0.86;
    final bob = math.sin(t * math.pi * 2) * h * 0.012;
    final stacked = math.min(count, 3);
    final tier = spec.isSkin ? spec.skinGrade : 'B';
    final rim = spec.isSkin ? yutGradeColor(tier) : Colors.white;

    Widget figure(int i) {
      final dx = stacked == 1 ? 0.0 : (i - (stacked - 1) / 2) * h * 0.2;
      final dy = (stacked - 1 - i) * -h * 0.015;
      return Positioned(
        left: (width - h * 0.8) / 2 + dx,
        bottom: baseH * 0.38 + dy - bob * (i.isEven ? 1 : -1),
        width: h * 0.8,
        height: figH,
        child: spec.isSkin
            ? _AnimalFace(emoji: spec.skinEmoji!, size: figH, tier: tier)
            : _CharacterImage(character: spec.character),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 부드러운 그림자 + 팀 색 원판.
        Positioned(
          left: (width - baseW) / 2,
          bottom: 0,
          width: baseW,
          height: baseH,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.elliptical(baseW, baseH)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(team, Colors.white, 0.35)!, team],
              ),
              border: Border.all(
                color: selected ? const Color(0xFFFFE066) : rim,
                width: selected ? 2.6 : (tier == 'B' ? 1.6 : 2.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.33),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
                if (selected || glow)
                  BoxShadow(
                    color: const Color(0xFFFFE066).withValues(alpha: 0.9),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                if (tier == 'S' || tier == 'SS' || tier == 'SSS')
                  BoxShadow(
                    color: yutGradeColor(tier).withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < stacked; i++) figure(i),
        if (tier == 'SS' || tier == 'SSS')
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SparklePainter(tier: tier, t: t),
              ),
            ),
          ),
        if (badge && count > 1)
          Positioned(
            right: -h * 0.02,
            top: h * 0.02,
            child: Container(
              constraints: BoxConstraints(
                minWidth: h * 0.34,
                minHeight: h * 0.34,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF263A2A),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                '×$count',
                style: GoogleFonts.jua(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.1,
                ),
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

/// 서 있는 동물 말: 큰 이모지 몸통 + 아래로 떨어지는 부드러운 그림자.
class _AnimalFace extends StatelessWidget {
  final String emoji;
  final double size;
  final String tier;

  const _AnimalFace({
    required this.emoji,
    required this.size,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = size * 0.72;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
            if (tier != 'B' && tier != 'A')
              Shadow(
                color: yutGradeColor(tier).withValues(alpha: 0.9),
                blurRadius: 14,
              ),
          ],
        ),
      ),
    );
  }
}

/// SS·SSS 말의 반짝이: 네 갈래 별이 돌며 깜빡인다(SSS는 무지개색).
class _SparklePainter extends CustomPainter {
  final String tier;
  final double t;

  _SparklePainter({required this.tier, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const count = 5;
    for (int i = 0; i < count; i++) {
      final phase = (t + i / count) % 1.0;
      final a = i / count * math.pi * 2 + t * math.pi * 2 * 0.5;
      final c = Offset(
        size.width / 2 + math.cos(a) * size.width * 0.42,
        size.height * 0.5 + math.sin(a * 1.3) * size.height * 0.34,
      );
      final k = math.sin(phase * math.pi);
      final color = tier == 'SSS'
          ? HSVColor.fromAHSV(
              1,
              ((phase + i * 0.2) % 1) * 360,
              0.5,
              1,
            ).toColor()
          : Colors.white;
      final r = size.width * 0.07 * (0.4 + k);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35 + 0.65 * k)
        ..style = PaintingStyle.fill;
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.t != t || old.tier != tier;
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
