import 'package:flutter/material.dart';

// 실제 화투 앞면 비율(첨부 원본 60×91).
const kHwatuCardHeightRatio = 91 / 60;

const kHwatuRed = Color(0xFFB3282D);
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

String hwatuCardAssetPath(String cardId) {
  return 'assets/images/hwatu/$cardId.png';
}

String _semanticLabel(Map<String, dynamic>? card) {
  if (card == null || card['id'] == 'back') return '화투 뒷면';
  final month = (card['month'] as num?)?.toInt();
  final plant = kHwatuPlantNames[month] ?? '';
  const typeNames = {'bright': '광', 'animal': '열끗', 'ribbon': '띠', 'junk': '피'};
  final type = typeNames[card['type']] ?? '';
  return '$month월 $plant $type';
}

class HwatuCard extends StatelessWidget {
  final Map<String, dynamic>? card; // null 또는 id=='back' → 뒷면
  final double width;
  final bool highlighted;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HwatuCard({
    super.key,
    required this.card,
    this.width = 44,
    this.highlighted = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  bool get _isBack => card == null || card!['id'] == 'back';

  @override
  Widget build(BuildContext context) {
    final height = width * kHwatuCardHeightRatio;
    return Semantics(
      button: onTap != null || onLongPress != null,
      label: _semanticLabel(card),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: height,
          transform: selected
              ? Matrix4.translationValues(0.0, -8.0, 0.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.06),
            boxShadow: [
              if (highlighted)
                BoxShadow(
                  color: kHwatuGold.withValues(alpha: 0.9),
                  blurRadius: 9,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.06),
            child: _isBack ? const _HwatuBack() : _buildFace(),
          ),
        ),
      ),
    );
  }

  Widget _buildFace() {
    final id = card!['id'] as String;
    return Image.asset(
      hwatuCardAssetPath(id),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => ColoredBox(
        color: kHwatuCream,
        child: Center(
          child: Text(
            '${card!['month']}월',
            style: TextStyle(
              color: kHwatuBlack,
              fontSize: width * 0.22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _HwatuBack extends StatelessWidget {
  const _HwatuBack();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HwatuBackPainter());
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

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.28;
    final diamond = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
