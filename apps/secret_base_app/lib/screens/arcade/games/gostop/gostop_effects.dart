import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';

/// 쓸: 바닥 가운데에서 퍼지는 금빛 고리. [t]는 0…1.
class GostopGoldRing extends StatelessWidget {
  final GameTheme theme;
  final double t;
  final double size;

  const GostopGoldRing({
    super.key,
    required this.theme,
    required this.t,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final k = Curves.easeOutCubic.transform(t.clamp(0, 1));
    final alpha = (1 - t).clamp(0.0, 1.0);
    return CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(theme.gold, k, alpha),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final double k;
  final double alpha;

  _RingPainter(this.color, this.k, this.alpha);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final r = size.width * 0.5 * (0.25 + 0.75 * k) * (1 - i * 0.12);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 - i * 2
          ..color = color.withValues(alpha: alpha * (0.95 - i * 0.25))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + i * 3),
      );
    }
    final spark = Paint()..color = Colors.white.withValues(alpha: alpha);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      final r = size.width * 0.5 * (0.3 + 0.7 * k);
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        2.4 * alpha + 0.4,
        spark,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.k != k || old.alpha != alpha;
}

/// "+피 1"처럼 떠올랐다가 사라지는 글자.
class GostopFloatLabel extends StatelessWidget {
  final GameTheme theme;
  final String text;
  final Color color;
  final double t;

  const GostopFloatLabel({
    super.key,
    required this.theme,
    required this.text,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final up = Curves.easeOut.transform(t.clamp(0, 1)) * 34;
    final alpha = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
    return Opacity(
      opacity: alpha.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, -up),
        child: Text(
          text,
          style: theme
              .display(size: 22, color: color, weight: FontWeight.w900)
              .copyWith(
                shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
        ),
      ),
    );
  }
}

/// 뻑 도장: 쾅 찍히며 살짝 튕긴다.
class GostopStamp extends StatelessWidget {
  final String text;
  final Color color;
  final double t;

  const GostopStamp({
    super.key,
    required this.text,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final scale = t < 0.2
        ? 2.4 - 1.4 * (t / 0.2)
        : 1.0 + 0.04 * math.sin(t * 12);
    final alpha = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    return Opacity(
      opacity: alpha.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: -0.22,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 4),
              color: Colors.black.withValues(alpha: 0.25),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1.05,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 피 뺏기 화살표: 뺏기는 쪽에서 가져가는 쪽으로 날아가는 금빛 화살.
class GostopStealArrow extends StatelessWidget {
  final Color color;
  final bool pointsUp;
  final double t;

  const GostopStealArrow({
    super.key,
    required this.color,
    required this.pointsUp,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = t < 0.2 ? t / 0.2 : (t > 0.75 ? (1 - t) / 0.25 : 1.0);
    return Opacity(
      opacity: alpha.clamp(0.0, 1.0),
      child: Icon(
        pointsUp ? Icons.north_rounded : Icons.south_rounded,
        color: color,
        size: 34,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
      ),
    );
  }
}
