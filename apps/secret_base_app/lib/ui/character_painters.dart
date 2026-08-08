import 'dart:math';
import 'package:flutter/material.dart';

// ─── 캐릭터 색상 데이터 ───────────────────────────────────────────────────────
const kSpyCharData = <String, Map<String, Object>>{
  'k':     {'skin': 0xFFC88F60, 'hair': 0xFF141420, 'outfit': 0xFF0C1B2A, 'symbol': 'K'},
  'ria':   {'skin': 0xFFE0BFAA, 'hair': 0xFF160810, 'outfit': 0xFF1E2D4A, 'symbol': 'R'},
  'luna':  {'skin': 0xFFF2D8BC, 'hair': 0xFF5B21B6, 'outfit': 0xFF5B21B6, 'symbol': 'L'},
  'rex':   {'skin': 0xFFC07840, 'hair': 0xFF6B3A12, 'outfit': 0xFF5C3010, 'symbol': 'X'},
  'zia':   {'skin': 0xFFDCCAB4, 'hair': 0xFF070C14, 'outfit': 0xFF0E7490, 'symbol': 'Z'},
  'drv':   {'skin': 0xFFDCC8A8, 'hair': 0xFF8898AA, 'outfit': 0xFFD0D8E8, 'symbol': 'V'},
  'hayun': {'skin': 0xFFC89060, 'hair': 0xFF1C1008, 'outfit': 0xFF3D5A2A, 'symbol': 'H'},
  'jake':  {'skin': 0xFFEACBA0, 'hair': 0xFF7B4A18, 'outfit': 0xFF1D3461, 'symbol': 'J'},
  'nova':  {'skin': 0xFFD4956A, 'hair': 0xFF2C1810, 'outfit': 0xFFC2410C, 'symbol': 'N'},
  'omega': {'skin': 0xFF101418, 'hair': 0xFF050810, 'outfit': 0xFF080C10, 'symbol': 'Ω'},
};

// ─── CharacterBust 위젯 ────────────────────────────────────────────────────
class CharacterBust extends StatelessWidget {
  final String character;
  final double width;
  final double height;

  const CharacterBust({
    super.key,
    required this.character,
    this.width = 44,
    this.height = 56,
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

// ─── CharacterBustPainter (상체 초상화) ────────────────────────────────────
class CharacterBustPainter extends CustomPainter {
  final String character;
  const CharacterBustPainter({required this.character});

  @override
  void paint(Canvas canvas, Size size) {
    final charData = kSpyCharData[character] ?? kSpyCharData['k']!;
    final skinColor  = Color(charData['skin']   as int);
    final hairColor  = Color(charData['hair']   as int);
    final outfitColor= Color(charData['outfit'] as int);
    final symbol     = charData['symbol'] as String;

    final cx = size.width / 2;
    final isOmega = character == 'omega';

    // 어깨/상의 (하단)
    final bodyY = size.height * 0.68;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - size.width * 0.55, bodyY, cx + size.width * 0.55, size.height + 6),
        const Radius.circular(8),
      ),
      Paint()..color = outfitColor,
    );

    final faceR     = size.width * 0.28;
    final faceCenter = Offset(cx, size.height * 0.43);

    if (isOmega) {
      // 후드 + 마스크
      canvas.drawCircle(faceCenter, faceR * 1.45, Paint()..color = hairColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: faceCenter.translate(0, faceR * 0.12),
                          width: faceR * 1.25, height: faceR * 0.9),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFF1A2030),
      );
      // 초록 눈
      final eyePaint = Paint()..color = const Color(0xFF00FF88);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - faceR * 0.3, faceCenter.dy - faceR * 0.1),
                        width: faceR * 0.34, height: faceR * 0.18),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + faceR * 0.3, faceCenter.dy - faceR * 0.1),
                        width: faceR * 0.34, height: faceR * 0.18),
        eyePaint,
      );
      return;
    }

    // 목
    canvas.drawRect(
      Rect.fromLTWH(cx - size.width * 0.07, bodyY - size.height * 0.10,
                    size.width * 0.14, size.height * 0.12),
      Paint()..color = skinColor,
    );

    // 머리카락 (얼굴 뒤)
    canvas.drawCircle(faceCenter.translate(0, -faceR * 0.08), faceR * 1.15,
                      Paint()..color = hairColor);

    // 얼굴
    canvas.drawOval(
      Rect.fromCenter(center: faceCenter, width: faceR * 2.0, height: faceR * 2.15),
      Paint()..color = skinColor,
    );

    // 눈
    final eyePaint = Paint()..color = const Color(0xFF1A1008);
    canvas.drawCircle(Offset(cx - faceR * 0.36, faceCenter.dy - faceR * 0.1), faceR * 0.12, eyePaint);
    canvas.drawCircle(Offset(cx + faceR * 0.36, faceCenter.dy - faceR * 0.1), faceR * 0.12, eyePaint);

    // 코 (작은 점)
    canvas.drawCircle(Offset(cx, faceCenter.dy + faceR * 0.07), faceR * 0.05,
                      Paint()..color = skinColor.withValues(alpha: 0.6));

    // 입
    canvas.drawArc(
      Rect.fromCenter(center: faceCenter.translate(0, faceR * 0.28),
                      width: faceR * 0.62, height: faceR * 0.38),
      0.25, pi - 0.5, false,
      Paint()
        ..color = const Color(0xFF8B3A3A)
        ..strokeWidth = faceR * 0.085
        ..style = PaintingStyle.stroke,
    );

    // 특이사항: luna는 보라 헤어 앞머리 힌트
    if (character == 'luna') {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, faceCenter.dy - faceR * 1.05),
                        width: faceR * 1.8, height: faceR * 0.7),
        0, pi, false,
        Paint()..color = hairColor,
      );
    }

    // 이니셜 배지 (좌하단)
    final badgeCenter = Offset(size.width * 0.15, size.height * 0.82);
    canvas.drawCircle(badgeCenter, 7, Paint()..color = outfitColor);
    canvas.drawCircle(badgeCenter, 7, Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: Colors.white,
          fontSize: 6.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(CharacterBustPainter old) => old.character != character;
}
