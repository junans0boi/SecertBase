import 'dart:math' as math;

import 'package:flutter/material.dart';

// 화투 카드 위젯 — 코드 기반 렌더링 (전통 화투 감성: 홍/흑/금 팔레트)
// 카드 데이터는 서버 gostop-engine.js의 {id, month, type, subtype}를 그대로 사용.
// 초보자 배려: 종류(光/열끗/단/피)를 명시적으로 표기.

const kHwatuRed = Color(0xFFB3282D); // 전통 홍
const kHwatuBlack = Color(0xFF1C1C1E);
const kHwatuGold = Color(0xFFD4A017);
const kHwatuCream = Color(0xFFF6EFDD);
const kHwatuBlue = Color(0xFF2C5F8A);

const Map<int, String> kHwatuPlantNames = {
  1: '송학',
  2: '매조',
  3: '벚꽃',
  4: '흑싸리',
  5: '난초',
  6: '모란',
  7: '홍싸리',
  8: '공산',
  9: '국화',
  10: '단풍',
  11: '오동',
  12: '비',
};

// 월별 테마 컬러 — 실제 화투의 월별 배경 톤을 흉내낸 팔레트.
const Map<int, Color> kHwatuMonthColor = {
  1: Color(0xFF2F5D3A), // 송학 — 소나무 초록
  2: Color(0xFFB33A62), // 매조 — 매화 자홍
  3: Color(0xFFE8829A), // 벚꽃 — 연분홍
  4: Color(0xFF3A3A3A), // 흑싸리 — 검정
  5: Color(0xFF5B4B8A), // 난초 — 보라
  6: Color(0xFFC23B6B), // 모란 — 진분홍
  7: Color(0xFF3F7D4A), // 홍싸리 — 초록
  8: Color(0xFF20242E), // 공산 — 짙은 남색
  9: Color(0xFFC9971C), // 국화 — 금색
  10: Color(0xFFB2451C), // 단풍 — 주황
  11: Color(0xFF5A3D7A), // 오동 — 보라
  12: Color(0xFF1E2A4A), // 비 — 남색
};

class HwatuCard extends StatelessWidget {
  final Map<String, dynamic>? card; // null 또는 id=='back' → 뒷면
  final double width;
  final bool highlighted; // 획득 가능 하이라이트 (초보자 지원)
  final bool selected;
  final VoidCallback? onTap;

  const HwatuCard({
    super.key,
    required this.card,
    this.width = 44,
    this.highlighted = false,
    this.selected = false,
    this.onTap,
  });

  bool get _isBack => card == null || card!['id'] == 'back';

  @override
  Widget build(BuildContext context) {
    final height = width * 1.55;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        height: height,
        transform: selected
            ? Matrix4.translationValues(0.0, -8.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.14),
          boxShadow: [
            if (highlighted)
              BoxShadow(
                color: kHwatuGold.withValues(alpha: 0.85),
                blurRadius: 8,
                spreadRadius: 1.5,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
          ],
        ),
        child: CustomPaint(
          painter: _isBack
              ? _HwatuBackPainter()
              : _HwatuFacePainter(
                  month: (card!['month'] as num).toInt(),
                  type: card!['type'] as String,
                  subtype: card!['subtype'] as String?,
                ),
        ),
      ),
    );
  }
}

class _HwatuBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.14),
    );
    canvas.drawRRect(r, Paint()..color = kHwatuRed);
    canvas.drawRRect(
      r,
      Paint()
        ..color = kHwatuBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // 중앙 금색 마름모 문양
    final c = Offset(size.width / 2, size.height / 2);
    final d = size.width * 0.28;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..color = kHwatuGold.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _HwatuFacePainter extends CustomPainter {
  final int month;
  final String type; // bright | animal | ribbon | junk
  final String? subtype; // rain | double | red | blue | null

  _HwatuFacePainter({
    required this.month,
    required this.type,
    required this.subtype,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.14),
    );

    // 바탕(월별 톤으로 살짝 물들임) + 테두리
    final monthColor = kHwatuMonthColor[month] ?? kHwatuBlack;
    canvas.drawRRect(r, Paint()..color = Color.lerp(kHwatuCream, monthColor, 0.12)!);
    canvas.drawRRect(
      r,
      Paint()
        ..color = kHwatuBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 월별 상징 문양(솔잎/매화/벚꽃/흑싸리 등) — 종류 배지 뒤에 깔리는 배경 그림
    _paintMonthMotif(canvas, size, month, monthColor);

    // 상단: 월 숫자 + 식물명
    _text(canvas, '$month월', Offset(w * 0.5, h * 0.13),
        size: w * 0.24, color: kHwatuBlack, bold: true);
    _text(canvas, kHwatuPlantNames[month] ?? '', Offset(w * 0.5, h * 0.28),
        size: w * 0.19, color: kHwatuBlack.withValues(alpha: 0.55));

    // 중앙: 종류별 모티프
    switch (type) {
      case 'bright':
        _paintBright(canvas, size);
        break;
      case 'animal':
        _paintAnimal(canvas, size);
        break;
      case 'ribbon':
        _paintRibbon(canvas, size);
        break;
      default:
        _paintJunk(canvas, size);
    }
  }

  // 월별 상징 배경 문양. 카드가 아주 작게(20~48px) 그려지므로 정교한 묘사
  // 대신 굵고 단순한 실루엣 몇 개 + 월 고유색으로 구분되도록 한다.
  void _paintMonthMotif(Canvas canvas, Size size, int m, Color color) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = color.withValues(alpha: 0.55);
    switch (m) {
      case 1: // 송학: 소나무 잎 부채꼴
        for (final dx in [0.16, 0.30, 0.44]) {
          final base = Offset(w * dx, h * 0.98);
          final path = Path()
            ..moveTo(base.dx, base.dy)
            ..lineTo(base.dx - w * 0.06, base.dy - h * 0.22)
            ..lineTo(base.dx + w * 0.06, base.dy - h * 0.22)
            ..close();
          canvas.drawPath(path, fill);
        }
        break;
      case 2: // 매조: 뾰족한 매화 점점이
        for (final o in [Offset(w * 0.18, h * 0.20), Offset(w * 0.32, h * 0.14), Offset(w * 0.14, h * 0.34)]) {
          _drawBlossom(canvas, o, w * 0.09, color, pointed: true);
        }
        break;
      case 3: // 벚꽃: 둥근 벚꽃 점점이
        for (final o in [Offset(w * 0.20, h * 0.18), Offset(w * 0.34, h * 0.13), Offset(w * 0.14, h * 0.30)]) {
          _drawBlossom(canvas, o, w * 0.09, color, pointed: false);
        }
        break;
      case 4: // 흑싸리: 늘어진 잎
        for (final dx in [0.20, 0.36]) {
          final path = Path()
            ..moveTo(w * dx, h * 0.06)
            ..quadraticBezierTo(w * (dx + 0.11), h * 0.20, w * dx, h * 0.36)
            ..quadraticBezierTo(w * (dx - 0.11), h * 0.20, w * dx, h * 0.06)
            ..close();
          canvas.drawPath(path, fill);
        }
        break;
      case 5: // 난초: 칼모양 잎 부채꼴
        for (final a in [-0.16, 0.0, 0.16]) {
          final path = Path()
            ..moveTo(w * 0.5 + a * w, h * 0.98)
            ..quadraticBezierTo(w * 0.5 + a * w * 2.6, h * 0.55, w * 0.5 + a * w * 0.6, h * 0.10)
            ..quadraticBezierTo(w * 0.5 + a * w * 1.3, h * 0.55, w * 0.5 + a * w, h * 0.98)
            ..close();
          canvas.drawPath(path, fill);
        }
        break;
      case 6: // 모란: 겹겹이 둥근 꽃잎
        final c = Offset(w * 0.26, h * 0.20);
        for (int i = 0; i < 6; i++) {
          final ang = i * math.pi / 3;
          canvas.drawOval(
            Rect.fromCenter(
              center: c.translate(math.cos(ang) * w * 0.08, math.sin(ang) * w * 0.08),
              width: w * 0.11,
              height: w * 0.15,
            ),
            fill,
          );
        }
        break;
      case 7: // 홍싸리: 클로버형 잎 세 장
        for (final o in [Offset(w * 0.18, h * 0.16), Offset(w * 0.32, h * 0.22), Offset(w * 0.14, h * 0.30)]) {
          canvas.drawOval(Rect.fromCenter(center: o, width: w * 0.11, height: w * 0.17), fill);
        }
        break;
      case 8: // 공산: 산 능선 실루엣
        final path = Path()
          ..moveTo(0, h * 0.98)
          ..lineTo(w * 0.20, h * 0.70)
          ..lineTo(w * 0.38, h * 0.90)
          ..lineTo(w * 0.55, h * 0.60)
          ..lineTo(w * 0.72, h * 0.85)
          ..lineTo(w, h * 0.75)
          ..lineTo(w, h * 0.98)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case 9: // 국화: 방사형 꽃잎
        final c = Offset(w * 0.26, h * 0.20);
        final stroke = Paint()
          ..color = color.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 8; i++) {
          final ang = i * math.pi / 4;
          canvas.drawLine(c, c.translate(math.cos(ang) * w * 0.15, math.sin(ang) * w * 0.15), stroke);
        }
        break;
      case 10: // 단풍: 별모양 단풍잎
        canvas.drawPath(_starPath(Offset(w * 0.26, h * 0.20), w * 0.055, w * 0.15, 5), fill);
        break;
      case 11: // 오동: 하트형 잎 두 장
        for (final o in [Offset(w * 0.20, h * 0.18), Offset(w * 0.36, h * 0.25)]) {
          canvas.drawPath(_heartPath(o, w * 0.11), fill);
        }
        break;
      case 12: // 비: 빗줄기
        final stroke = Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.028
          ..strokeCap = StrokeCap.round;
        for (final dx in [0.14, 0.28, 0.42, 0.56]) {
          canvas.drawLine(Offset(w * dx, h * 0.04), Offset(w * dx - w * 0.09, h * 0.32), stroke);
        }
        break;
    }
  }

  void _drawBlossom(Canvas canvas, Offset center, double r, Color color, {required bool pointed}) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    for (int i = 0; i < 5; i++) {
      final angle = i * (2 * math.pi / 5);
      final petalCenter = center.translate(math.cos(angle) * r, math.sin(angle) * r);
      if (pointed) {
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(petalCenter.dx - r * 0.4, petalCenter.dy)
          ..lineTo(petalCenter.dx, petalCenter.dy + r * 0.7)
          ..lineTo(petalCenter.dx + r * 0.4, petalCenter.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: petalCenter, width: r * 0.95, height: r * 0.95),
          paint,
        );
      }
    }
    canvas.drawCircle(center, r * 0.32, Paint()..color = color.withValues(alpha: 0.85));
  }

  Path _starPath(Offset center, double innerR, double outerR, int points) {
    final path = Path();
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerR : innerR;
      final angle = i * step - math.pi / 2;
      final p = center.translate(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  Path _heartPath(Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.35)
      ..cubicTo(
        center.dx - size * 1.1, center.dy - size * 0.5,
        center.dx - size * 0.5, center.dy - size * 1.1,
        center.dx, center.dy - size * 0.35,
      )
      ..cubicTo(
        center.dx + size * 0.5, center.dy - size * 1.1,
        center.dx + size * 1.1, center.dy - size * 0.5,
        center.dx, center.dy + size * 0.35,
      )
      ..close();
    return path;
  }

  void _paintBright(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.62);
    final isRain = subtype == 'rain';
    canvas.drawCircle(
      c,
      w * 0.30,
      Paint()..color = isRain ? kHwatuBlue : kHwatuGold,
    );
    canvas.drawCircle(
      c,
      w * 0.30,
      Paint()
        ..color = kHwatuBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _text(canvas, '光', c.translate(0, 0),
        size: w * 0.34, color: isRain ? Colors.white : kHwatuBlack, bold: true);
    _text(canvas, isRain ? '비광' : '광', Offset(w * 0.5, h * 0.90),
        size: w * 0.17, color: isRain ? kHwatuBlue : kHwatuGold.withValues(alpha: 0.9), bold: true);
  }

  void _paintAnimal(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.62);
    // 열끗: 홍갈색 원 + 동물 실루엣 느낌의 초승달
    canvas.drawCircle(c, w * 0.28, Paint()..color = kHwatuRed.withValues(alpha: 0.85));
    final moon = Path()
      ..addOval(Rect.fromCircle(center: c.translate(-w * 0.05, -w * 0.04), radius: w * 0.16));
    canvas.drawPath(moon, Paint()..color = kHwatuCream);
    _text(canvas, '열끗', Offset(w * 0.5, h * 0.90),
        size: w * 0.17, color: kHwatuRed, bold: true);
  }

  void _paintRibbon(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final isRed = subtype == 'red';
    final isBlue = subtype == 'blue';
    final color = isBlue ? kHwatuBlue : kHwatuRed;
    // 세로 띠
    final band = Rect.fromLTWH(w * 0.34, h * 0.40, w * 0.32, h * 0.44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(w * 0.05)),
      Paint()..color = color,
    );
    // 홍단/청단 세로 글씨
    final label = isRed
        ? '홍단'
        : isBlue
            ? '청단'
            : '단';
    final chars = label.split('');
    for (int i = 0; i < chars.length; i++) {
      _text(
        canvas,
        chars[i],
        Offset(w * 0.5, h * (0.50 + i * 0.20)),
        size: w * 0.20,
        color: Colors.white,
        bold: true,
      );
    }
  }

  void _paintJunk(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final isDouble = subtype == 'double';
    // 피: 잔잔한 잎 문양 점 3개
    final paint = Paint()..color = kHwatuRed.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(w * 0.32, h * 0.55), w * 0.09, paint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.62), w * 0.09, paint);
    canvas.drawCircle(Offset(w * 0.42, h * 0.72), w * 0.09, paint);
    _text(canvas, isDouble ? '쌍피' : '피', Offset(w * 0.5, h * 0.90),
        size: w * 0.17,
        color: isDouble ? kHwatuGold : kHwatuBlack.withValues(alpha: 0.6),
        bold: isDouble);
  }

  void _text(Canvas canvas, String s, Offset center,
      {required double size, required Color color, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _HwatuFacePainter old) =>
      old.month != month || old.type != type || old.subtype != subtype;
}
