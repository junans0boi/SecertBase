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
  11: '비',
  12: '오동',
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

    // 바탕 + 테두리
    canvas.drawRRect(r, Paint()..color = kHwatuCream);
    canvas.drawRRect(
      r,
      Paint()
        ..color = kHwatuBlack
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

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
