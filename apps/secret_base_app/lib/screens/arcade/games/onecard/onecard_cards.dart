import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onecard_models.dart';

/// 카드 크기 비율(가로:세로 = 1:1.45).
const double kOneCardAspect = 1.45;

/// 원카드 앞면. 보석 톤 4색과 기호(⊘ ⇄ +2 +4 ◐ "모두")만 쓰고 영어 글자는 없다.
/// 기호는 글꼴이 늦게 와도 네모로 보이지 않게 직접 그린다(00-analysis C1).
class OneCardFace extends StatelessWidget {
  final OneCard card;
  final double width;

  /// 버린 더미 위 와일드: 고른 색으로 물든다(Q53).
  final String? tintColor;
  final bool dimmed;

  const OneCardFace({
    super.key,
    required this.card,
    this.width = 60,
    this.tintColor,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * kOneCardAspect;
    final colored = card.color != null;
    final paint = colored ? card.color : tintColor;
    final base = OneCardColors.of(paint);
    final radius = BorderRadius.circular(w * 0.13);
    return Semantics(
      label: card.label,
      child: SizedBox(
        width: w,
        height: h,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: const Color(0xFFFFF8EC),
            border: Border.all(
              color: const Color(0xFFE8C27A),
              width: math.max(1, w * 0.018),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: w * 0.1,
                offset: Offset(0, w * 0.04),
              ),
              if (tintColor != null && !colored)
                BoxShadow(
                  color: base.withValues(alpha: 0.75),
                  blurRadius: w * 0.3,
                  spreadRadius: w * 0.02,
                ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(w * 0.055),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.09),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: paint == null
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF3B1C55), Color(0xFF190A27)],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                OneCardColors.light(paint),
                                base,
                                OneCardColors.deep(paint),
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                    ),
                  ),
                  // 가운데 비스듬한 타원(보석의 반사광).
                  Center(
                    child: Transform.rotate(
                      angle: -0.42,
                      child: Container(
                        width: w * 0.78,
                        height: h * 0.62,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(w * 0.39, h * 0.31),
                          ),
                          color: Colors.white.withValues(
                            alpha: colored ? 0.94 : 0.12,
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFFE8C27A,
                            ).withValues(alpha: colored ? 0.55 : 0.8),
                            width: math.max(0.8, w * 0.012),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: _CardSymbol(
                      card: card,
                      size: w * 0.5,
                      color: colored ? base : Colors.white,
                      tint: paint,
                    ),
                  ),
                  Positioned(
                    left: w * 0.04,
                    top: w * 0.02,
                    child: _CardSymbol(
                      card: card,
                      size: w * 0.2,
                      color: Colors.white,
                      tint: paint,
                      corner: true,
                    ),
                  ),
                  Positioned(
                    right: w * 0.04,
                    bottom: w * 0.02,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: _CardSymbol(
                        card: card,
                        size: w * 0.2,
                        color: Colors.white,
                        tint: paint,
                        corner: true,
                      ),
                    ),
                  ),
                  if (dimmed)
                    ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardSymbol extends StatelessWidget {
  final OneCard card;
  final double size;
  final Color color;
  final String? tint;
  final bool corner;

  const _CardSymbol({
    required this.card,
    required this.size,
    required this.color,
    required this.tint,
    this.corner = false,
  });

  TextStyle _text(double fontSize) => GoogleFonts.gowunBatang(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1,
    shadows: [
      Shadow(
        color: Colors.black.withValues(alpha: corner ? 0.35 : 0.15),
        blurRadius: 2,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    switch (card.value) {
      case 'skip':
        return CustomPaint(
          size: Size.square(size * 0.9),
          painter: _SkipPainter(color),
        );
      case 'reverse':
        return CustomPaint(
          size: Size.square(size * 0.95),
          painter: _ReversePainter(color),
        );
      case 'wild':
        return CustomPaint(
          size: Size.square(size * (corner ? 0.85 : 1.05)),
          painter: _WildWheelPainter(tint: tint),
        );
      case 'wild_draw4':
        if (corner) return Text('+4', style: _text(size * 0.7));
        return SizedBox.square(
          dimension: size * 1.1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size * 1.05),
                painter: _WildWheelPainter(tint: tint),
              ),
              Text(
                '+4',
                style: _text(size * 0.52).copyWith(
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ],
          ),
        );
      case 'draw2':
        return Text('+2', style: _text(size * (corner ? 0.7 : 0.72)));
      case 'discard_all':
        return Text(
          '모두',
          style: GoogleFonts.notoSans(
            fontSize: size * (corner ? 0.42 : 0.42),
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        );
      default:
        return Text(card.value, style: _text(size * (corner ? 0.78 : 0.95)));
    }
  }
}

/// ⊘ 건너뛰기: 원 + 사선.
class _SkipPainter extends CustomPainter {
  final Color color;
  _SkipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r * 0.8, p);
    final d = r * 0.8 * math.cos(math.pi / 4);
    canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), p);
  }

  @override
  bool shouldRepaint(covariant _SkipPainter old) => old.color != color;
}

/// ⇄ 방향 바꾸기: 위아래로 엇갈린 두 화살표.
class _ReversePainter extends CustomPainter {
  final Color color;
  _ReversePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // 위: 왼→오
    canvas.drawLine(Offset(w * 0.12, h * 0.34), Offset(w * 0.86, h * 0.34), p);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.66, h * 0.16)
        ..lineTo(w * 0.88, h * 0.34)
        ..lineTo(w * 0.66, h * 0.52),
      p,
    );
    // 아래: 오→왼
    canvas.drawLine(Offset(w * 0.88, h * 0.68), Offset(w * 0.14, h * 0.68), p);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.34, h * 0.5)
        ..lineTo(w * 0.12, h * 0.68)
        ..lineTo(w * 0.34, h * 0.86),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _ReversePainter old) => old.color != color;
}

/// ◐ 색 바꾸기: 4색 보석 바퀴. [tint]가 있으면 그 색이 반을 차지한다.
class _WildWheelPainter extends CustomPainter {
  final String? tint;
  _WildWheelPainter({this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r * 0.92);
    if (tint != null) {
      canvas.drawArc(
        rect,
        math.pi / 2,
        math.pi,
        true,
        Paint()..color = OneCardColors.of(tint),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi,
        true,
        Paint()..color = OneCardColors.light(tint),
      );
    } else {
      const colors = ['red', 'yellow', 'green', 'blue'];
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
          rect,
          -math.pi / 2 + i * math.pi / 2,
          math.pi / 2,
          true,
          Paint()..color = OneCardColors.of(colors[i]),
        );
      }
    }
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0xFFFFF3D6),
    );
    canvas.drawCircle(
      c,
      r * 0.2,
      Paint()..color = const Color(0xFFFFF3D6).withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _WildWheelPainter old) => old.tint != tint;
}

/// 카드 뒷면. 상점 아이템(원카드 카드 뒷면) 스킨 표를 그대로 쓴다.
class OneCardBack extends StatelessWidget {
  final double width;
  final String skin;

  const OneCardBack({super.key, this.width = 60, this.skin = 'base'});

  /// 스킨 id → (그라데이션, 아이콘). 상점 아이템 아이콘에서 고른다([skinFromItem]).
  static const skins = <String, (List<Color>, String)>{
    'cherry_blossom': ([Color(0xFFFFB7D5), Color(0xFFFF6F9F)], '🌸'),
    'space': ([Color(0xFF1A1A3E), Color(0xFF0D0D24)], '🌌'),
    'heart': ([Color(0xFFFF4444), Color(0xFFCC0000)], '❤️'),
    'gold': ([Color(0xFFFFD700), Color(0xFFB8860B)], '✨'),
    'rainbow': ([Color(0xFFFF6B6B), Color(0xFF6B6BFF)], '🌈'),
    'couple_card': ([Color(0xFFFF8FAB), Color(0xFFB983FF)], '💑'),
    'fog': ([Color(0xFFD0D8E4), Color(0xFF8FA3B1)], '🌫️'),
    'sunset': ([Color(0xFFFF7F50), Color(0xFFFF4500)], '🌅'),
    'water': ([Color(0xFF00B4DB), Color(0xFF0083B0)], '💧'),
    'night': ([Color(0xFF1A1A2E), Color(0xFF16213E)], '🌙'),
    'autumn': ([Color(0xFFE65C00), Color(0xFFF9D423)], '🍁'),
    'aurora': ([Color(0xFF0F2027), Color(0xFF203A43)], '🌌'),
    'firefly': ([Color(0xFF0D1B2A), Color(0xFF1B4332)], '✨'),
    'stardust': ([Color(0xFF1C1C3C), Color(0xFF2D2D5E)], '⭐'),
    'fireworks': ([Color(0xFF0D0D0D), Color(0xFF1A0033)], '🎆'),
    'eternity': ([Color(0xFF1A0038), Color(0xFF2D0057)], '♾️'),
    'fate': ([Color(0xFF7B0000), Color(0xFFB8860B)], '🎴'),
  };

  /// 장착 아이템(`equippedItems[user].onecard_cardback`의 icon·grade) → 스킨 id.
  static String skinFromItem(Map<String, dynamic>? item) {
    if (item == null) return 'base';
    final icon = item['icon'] as String? ?? '';
    final grade = item['grade'] as String? ?? 'B';
    return switch (icon) {
      '🌫️' => 'fog',
      '🌅' || '🌇' => 'sunset',
      '💧' || '💦' => 'water',
      '🌙' => 'night',
      '🍁' => 'autumn',
      '🌌' => 'aurora',
      '✨' => 'firefly',
      '⭐' => 'stardust',
      '🎆' => 'fireworks',
      '♾️' => 'eternity',
      '🎴' => 'fate',
      '💑' => 'couple_card',
      '🌸' || '🌺' => 'cherry_blossom',
      '❤️' || '💕' => 'heart',
      '🌈' => 'rainbow',
      _ => switch (grade) {
        'SSS' => 'rainbow',
        'SS' => 'eternity',
        'S' => 'aurora',
        'A' => 'stardust',
        _ => 'base',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = w * kOneCardAspect;
    final entry = skins[skin];
    return Semantics(
      label: '뒷면 카드',
      child: Container(
        width: w,
        height: h,
        padding: EdgeInsets.all(w * 0.05),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(w * 0.13),
          border: Border.all(
            color: const Color(0xFFE8C27A),
            width: math.max(1, w * 0.018),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: w * 0.08,
              offset: Offset(0, w * 0.035),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.09),
          child: CustomPaint(
            painter: _BackPainter(
              colors: entry?.$1 ?? const [Color(0xFF5B2A7E), Color(0xFF2A1240)],
            ),
            child: Center(
              child: entry != null
                  ? Text(entry.$2, style: TextStyle(fontSize: w * 0.36))
                  : Container(
                      width: w * 0.46,
                      height: w * 0.46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE8C27A),
                          width: math.max(1, w * 0.025),
                        ),
                        color: const Color(0xFF2A1240),
                      ),
                      child: Text(
                        '원',
                        style: GoogleFonts.gowunBatang(
                          fontSize: w * 0.22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFE8C27A),
                          height: 1,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  final List<Color> colors;
  _BackPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
    // 금박 마름모 격자.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, size.width * 0.012)
      ..color = const Color(0x55E8C27A);
    final s = size.width / 4;
    for (double x = -size.height; x < size.width + size.height; x += s) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(size.width * 0.07),
        Radius.circular(size.width * 0.07),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, size.width * 0.02)
        ..color = const Color(0xAAE8C27A),
    );
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) => old.colors != colors;
}

/// 항상 보이는 "지금 색" 보석 칩(Q53).
class CurrentColorChip extends StatelessWidget {
  final String? color;
  final bool declared;

  const CurrentColorChip({
    super.key,
    required this.color,
    this.declared = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = OneCardColors.of(color);
    final name = OneCardColors.name(color);
    return Semantics(
      label: '지금 색 $name${declared ? ', 색 바꾸기로 정해짐' : ''}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1C0C2B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.9), width: 1.6),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  colors: [
                    OneCardColors.light(color),
                    c,
                    OneCardColors.deep(color),
                  ],
                ),
                border: Border.all(color: const Color(0xFFE8C27A), width: 1.2),
              ),
            ),
            const SizedBox(width: 7),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 색',
                  style: GoogleFonts.notoSans(
                    fontSize: 9.5,
                    color: const Color(0xCCE6D6F0),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  name.isEmpty ? '-' : name,
                  style: GoogleFonts.notoSans(
                    fontSize: 13.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
