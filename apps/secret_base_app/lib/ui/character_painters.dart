import 'dart:math';
import 'package:flutter/material.dart';
import '../core/marble_characters.dart';

// ─── CharacterBust 위젯 ────────────────────────────────────────────────────
class CharacterBust extends StatelessWidget {
  final String character;
  final double width;
  final double height;

  const CharacterBust({
    super.key,
    required this.character,
    this.width = 48,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: CharacterBustPainter(character: character),
      ),
    );
  }
}

// ─── CharacterBustPainter ─────────────────────────────────────────────────
class CharacterBustPainter extends CustomPainter {
  final String character;
  const CharacterBustPainter({required this.character});

  @override
  void paint(Canvas canvas, Size size) {
    final char = marbleCharById(character) ?? kMarbleCharacters.first;
    final cx   = size.width / 2;

    if (char.hairStyle == 'hood') {
      _drawOmega(canvas, size, cx, char);
      return;
    }

    _drawBody(canvas, size, cx, char);
    _drawHairBack(canvas, size, cx, char);
    _drawFace(canvas, size, cx, char);
    _drawHairFront(canvas, size, cx, char);
    _drawEyes(canvas, size, cx, char);
    _drawNose(canvas, size, cx, char);
    _drawMouth(canvas, size, cx, char);
    _drawSpecial(canvas, size, cx, char);
    _drawGradeBadge(canvas, size, cx, char);
  }

  // ── 어깨/상의 ────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final bodyY = size.height * 0.68;
    final outfitColor = char.outfitColor;

    // 어깨 패드
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - size.width * 0.58, bodyY,
                      cx + size.width * 0.58, size.height + 8),
        const Radius.circular(10),
      ),
      Paint()..color = outfitColor,
    );

    // 칼라/목 주변 하이라이트
    final collarPaint = Paint()
      ..color = _lighten(outfitColor, 0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, bodyY),
        width: size.width * 0.38,
        height: size.height * 0.14,
      ),
      pi, pi, false, collarPaint,
    );

    // 목
    canvas.drawRect(
      Rect.fromLTWH(cx - size.width * 0.07, bodyY - size.height * 0.11,
                    size.width * 0.14, size.height * 0.13),
      Paint()..color = char.skinColor,
    );
  }

  // ── 머리카락 (뒷부분 — 얼굴 아래) ────────────────────────────────────────
  void _drawHairBack(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    final hair       = Paint()..color = char.hairColor;

    switch (char.hairStyle) {
      case 'bob':
        // 다크 밥컷: 얼굴보다 약간 넓고 낮게
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, faceR * 0.15),
                          width: faceR * 2.55, height: faceR * 2.6),
          hair,
        );
      case 'long':
        // 롱헤어: 아래까지 늘어짐
        final path = Path()
          ..moveTo(cx - faceR * 1.25, faceCenter.dy - faceR * 0.8)
          ..quadraticBezierTo(cx - faceR * 1.4, size.height,
                              cx - faceR * 0.9, size.height)
          ..lineTo(cx + faceR * 0.9, size.height)
          ..quadraticBezierTo(cx + faceR * 1.4, size.height,
                              cx + faceR * 1.25, faceCenter.dy - faceR * 0.8)
          ..close();
        canvas.drawPath(path, hair);
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.05),
                          width: faceR * 2.55, height: faceR * 2.5),
          hair,
        );
      case 'silver':
        // 은발: 올백 스타일
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.12),
                          width: faceR * 2.45, height: faceR * 2.4),
          hair,
        );
      case 'spiky':
        // 스파이키: 뾰족 + 블루 한 가닥
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.1),
                          width: faceR * 2.45, height: faceR * 2.45),
          hair,
        );
      default: // short, medium
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.08),
                          width: faceR * 2.4, height: faceR * 2.3),
          hair,
        );
    }
  }

  // ── 얼굴 ─────────────────────────────────────────────────────────────────
  void _drawFace(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;

    // 볼 그라디언트 효과 (블러 원)
    canvas.drawOval(
      Rect.fromCenter(center: faceCenter, width: faceR * 2.0, height: faceR * 2.2),
      Paint()..color = char.skinColor,
    );

    // 볼 홍조
    final blushPaint = Paint()
      ..color = const Color(0xFFFF9999).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(cx - faceR * 0.55, faceCenter.dy + faceR * 0.22),
                      faceR * 0.27, blushPaint);
    canvas.drawCircle(Offset(cx + faceR * 0.55, faceCenter.dy + faceR * 0.22),
                      faceR * 0.27, blushPaint);
  }

  // ── 머리카락 (앞부분 — 얼굴 위) ───────────────────────────────────────────
  void _drawHairFront(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    final hair       = Paint()..color = char.hairColor;

    switch (char.hairStyle) {
      case 'bob':
        // 앞머리 일직선 뱅
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(cx - faceR * 1.3, 0,
                                      cx + faceR * 1.3, faceCenter.dy - faceR * 0.6));
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.6),
                          width: faceR * 2.55, height: faceR * 1.3),
          hair,
        );
        canvas.restore();
      case 'long':
        // 긴 앞머리 사이드 파트
        final bangPath = Path()
          ..moveTo(cx - faceR * 1.0, faceCenter.dy - faceR * 1.1)
          ..quadraticBezierTo(cx - faceR * 0.2, faceCenter.dy - faceR * 0.5,
                              cx + faceR * 0.5, faceCenter.dy - faceR * 0.7)
          ..quadraticBezierTo(cx + faceR * 1.1, faceCenter.dy - faceR * 1.0,
                              cx + faceR * 1.0, faceCenter.dy - faceR * 1.2)
          ..close();
        canvas.drawPath(bangPath, hair);
      case 'silver':
        // 올백 앞머리 없음 (단 가르마 라인)
        final part = Paint()
          ..color = _lighten(char.hairColor, 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(cx, faceCenter.dy - faceR * 1.15),
          Offset(cx - faceR * 0.4, faceCenter.dy - faceR * 0.8),
          part,
        );
      case 'spiky':
        // 뾰족한 앞머리 + 파란 메쉬
        final spikeCount = 5;
        for (int i = 0; i < spikeCount; i++) {
          final angle = (pi * 0.7) + (i / (spikeCount - 1)) * (pi * (-0.4));
          final baseX  = cx + cos(angle) * faceR * 1.0;
          final baseY  = faceCenter.dy + sin(angle) * faceR * 1.0;
          final tipX   = cx + cos(angle) * faceR * 1.5;
          final tipY   = faceCenter.dy + sin(angle) * faceR * 1.55;
          final sp = Paint()..color = i == 2 ? const Color(0xFF3B82F6) : char.hairColor;
          canvas.drawPath(
            Path()
              ..moveTo(baseX - 4, baseY)
              ..lineTo(tipX, tipY)
              ..lineTo(baseX + 4, baseY)
              ..close(),
            sp,
          );
        }
      default: // short/medium
        // 라운드 앞머리
        final bangClip = Rect.fromLTRB(cx - faceR * 1.2, 0,
                                       cx + faceR * 1.2, faceCenter.dy - faceR * 0.55);
        canvas.save();
        canvas.clipRect(bangClip);
        canvas.drawOval(
          Rect.fromCenter(center: faceCenter.translate(0, -faceR * 0.7),
                          width: faceR * 2.35, height: faceR * 1.2),
          hair,
        );
        canvas.restore();
    }
  }

  // ── 눈 ───────────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    final eyeColor   = char.eyeColor ?? const Color(0xFF2B1A0E);

    // 눈 흰자
    final eyeWhite = Paint()..color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - faceR * 0.36, faceCenter.dy - faceR * 0.07),
                      width: faceR * 0.38, height: faceR * 0.28),
      eyeWhite,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + faceR * 0.36, faceCenter.dy - faceR * 0.07),
                      width: faceR * 0.38, height: faceR * 0.28),
      eyeWhite,
    );

    // 홍채
    canvas.drawCircle(
      Offset(cx - faceR * 0.36, faceCenter.dy - faceR * 0.07),
      faceR * 0.12,
      Paint()..color = eyeColor,
    );
    canvas.drawCircle(
      Offset(cx + faceR * 0.36, faceCenter.dy - faceR * 0.07),
      faceR * 0.12,
      Paint()..color = eyeColor,
    );

    // 반짝이 포인트
    canvas.drawCircle(
      Offset(cx - faceR * 0.33, faceCenter.dy - faceR * 0.11),
      faceR * 0.042,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx + faceR * 0.39, faceCenter.dy - faceR * 0.11),
      faceR * 0.042,
      Paint()..color = Colors.white,
    );

    // 속눈썹 라인
    final lash = Paint()
      ..color = const Color(0xFF2B1A0E)
      ..strokeWidth = faceR * 0.065
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - faceR * 0.36, faceCenter.dy - faceR * 0.07),
                      width: faceR * 0.38, height: faceR * 0.28),
      pi, pi, false, lash,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + faceR * 0.36, faceCenter.dy - faceR * 0.07),
                      width: faceR * 0.38, height: faceR * 0.28),
      pi, pi, false, lash,
    );
  }

  // ── 코 ───────────────────────────────────────────────────────────────────
  void _drawNose(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    canvas.drawCircle(
      Offset(cx, faceCenter.dy + faceR * 0.1),
      faceR * 0.06,
      Paint()..color = char.skinColor.withValues(alpha: 0.55),
    );
  }

  // ── 입 ───────────────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    canvas.drawArc(
      Rect.fromCenter(
        center: faceCenter.translate(0, faceR * 0.3),
        width: faceR * 0.62, height: faceR * 0.38,
      ),
      0.3, pi - 0.6, false,
      Paint()
        ..color = const Color(0xFF8B3A3A)
        ..strokeWidth = faceR * 0.08
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── 악세서리/특수 ─────────────────────────────────────────────────────────
  void _drawSpecial(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;
    final bodyY      = size.height * 0.68;

    switch (char.special) {
      case 'tie':
        _drawTie(canvas, cx, bodyY, size, char.outfitColor);
      case 'pin':
        // 크림슨 핀 (우측 머리)
        canvas.drawCircle(
          Offset(cx + faceR * 0.85, faceCenter.dy - faceR * 0.65),
          faceR * 0.13,
          Paint()..color = const Color(0xFFDC2626),
        );
        canvas.drawCircle(
          Offset(cx + faceR * 0.85, faceCenter.dy - faceR * 0.65),
          faceR * 0.13,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      case 'coat':
        // 흰 실험복 라펠
        final lapel = Paint()..color = const Color(0xFFF1F5F9);
        canvas.drawPath(
          Path()
            ..moveTo(cx - faceR * 0.3, bodyY - 2)
            ..lineTo(cx - faceR * 0.05, bodyY + 12)
            ..lineTo(cx + faceR * 0.05, bodyY + 12)
            ..lineTo(cx + faceR * 0.3, bodyY - 2)
            ..close(),
          lapel,
        );
      case 'goggles':
        // 고글 이마 위
        final goggleY = faceCenter.dy - faceR * 0.95;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, goggleY),
                            width: faceR * 1.6, height: faceR * 0.36),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF78350F),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx - faceR * 0.35, goggleY),
                          width: faceR * 0.5, height: faceR * 0.3),
          Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.7),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + faceR * 0.35, goggleY),
                          width: faceR * 0.5, height: faceR * 0.3),
          Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.7),
        );
      case 'anchor':
        // 닻 배지 (가슴)
        final anchorPaint = Paint()
          ..color = const Color(0xFFFFD700)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final ac = Offset(cx, bodyY + 14);
        canvas.drawCircle(ac, 5, anchorPaint);
        canvas.drawLine(Offset(ac.dx, ac.dy - 5), Offset(ac.dx, ac.dy + 5), anchorPaint);
        canvas.drawLine(Offset(ac.dx - 4, ac.dy + 3), Offset(ac.dx + 4, ac.dy + 3), anchorPaint);
    }
  }

  void _drawTie(Canvas canvas, double cx, double bodyY, Size size, Color outfitColor) {
    final tieColor = const Color(0xFFDC2626); // 빨간 넥타이
    final path = Path()
      ..moveTo(cx - 4, bodyY - 4)
      ..lineTo(cx + 4, bodyY - 4)
      ..lineTo(cx + 3, bodyY + 8)
      ..lineTo(cx + 5, bodyY + 18)
      ..lineTo(cx, bodyY + 24)
      ..lineTo(cx - 5, bodyY + 18)
      ..lineTo(cx - 3, bodyY + 8)
      ..close();
    canvas.drawPath(path, Paint()..color = tieColor);
    canvas.drawLine(
      Offset(cx, bodyY + 4), Offset(cx, bodyY + 15),
      Paint()..color = _darken(tieColor, 0.2)..strokeWidth = 1,
    );
  }

  // ── 등급 배지 ────────────────────────────────────────────────────────────
  void _drawGradeBadge(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    final badgeCenter = Offset(size.width * 0.15, size.height * 0.80);
    final gradeColor  = _gradeColor(char.grade);

    canvas.drawCircle(badgeCenter, 8,
        Paint()..color = gradeColor);
    canvas.drawCircle(badgeCenter, 8,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    final tp = TextPainter(
      text: TextSpan(
        text: char.grade,
        style: TextStyle(
          color: Colors.white,
          fontSize: char.grade.length > 1 ? 5.5 : 7,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  // ── 오메가 (전신 후드 + 마스크) ──────────────────────────────────────────
  void _drawOmega(Canvas canvas, Size size, double cx, MarbleCharacter char) {
    // 어깨/상의
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - size.width * 0.58, size.height * 0.68,
                      cx + size.width * 0.58, size.height + 8),
        const Radius.circular(10),
      ),
      Paint()..color = char.outfitColor,
    );

    final faceCenter = Offset(cx, size.height * 0.40);
    final faceR      = size.width * 0.28;

    // 후드 외곽
    canvas.drawCircle(faceCenter, faceR * 1.5, Paint()..color = char.hairColor);

    // 마스크 내부
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: faceCenter.translate(0, faceR * 0.1),
                        width: faceR * 1.3, height: faceR * 0.95),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1A2030),
    );

    // 마스크 통기구
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, faceCenter.dy + faceR * 0.3 + i * 5),
            width: faceR * 0.8, height: 2,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF2D3A4A),
      );
    }

    // 초록 발광 눈
    final glowPaint = Paint()
      ..color = const Color(0xFF00FF88).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - faceR * 0.3, faceCenter.dy - faceR * 0.1),
                      width: faceR * 0.38, height: faceR * 0.2),
      glowPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + faceR * 0.3, faceCenter.dy - faceR * 0.1),
                      width: faceR * 0.38, height: faceR * 0.2),
      glowPaint,
    );
    final eyePaint = Paint()..color = const Color(0xFF00FF88);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - faceR * 0.3, faceCenter.dy - faceR * 0.1),
                      width: faceR * 0.32, height: faceR * 0.16),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + faceR * 0.3, faceCenter.dy - faceR * 0.1),
                      width: faceR * 0.32, height: faceR * 0.16),
      eyePaint,
    );

    // Ω 이니셜 (마스크 하단)
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Ω',
        style: TextStyle(color: Color(0xFF00FF88), fontSize: 8, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, faceCenter.dy + faceR * 0.25));
  }

  // ── 색상 유틸 ─────────────────────────────────────────────────────────────
  static Color _lighten(Color c, double amount) {
    final hsl  = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl  = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _gradeColor(String grade) => switch (grade) {
    'SS'  => const Color(0xFFFF4500),
    'SSS' => const Color(0xFF00FF88),
    'S'   => const Color(0xFFE91E63),
    'A'   => const Color(0xFF7C4DFF),
    _     => const Color(0xFF546E7A),
  };

  @override
  bool shouldRepaint(CharacterBustPainter old) => old.character != character;
}
