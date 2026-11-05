import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 색종이 한 번 터뜨리기. [trigger]가 바뀔 때마다 다시 재생한다. 한 레이어로 그려 가볍다.
class ConfettiBurst extends StatefulWidget {
  final Object? trigger;
  final List<Color> colors;
  final int count;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    required this.trigger,
    required this.colors,
    this.count = 70,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  List<_Piece> _pieces = const [];

  @override
  void initState() {
    super.initState();
    if (widget.trigger != null) _fire();
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger) _fire();
  }

  void _fire() {
    final rnd = math.Random();
    _pieces = List.generate(widget.count, (i) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      final speed = 0.55 + rnd.nextDouble() * 0.7;
      return _Piece(
        x0: 0.5 + (rnd.nextDouble() - 0.5) * 0.2,
        vx: math.cos(angle) * speed * 0.6,
        vy: math.sin(angle) * speed * 1.25,
        spin: (rnd.nextDouble() - 0.5) * 14,
        color: widget.colors[i % widget.colors.length],
        w: 5 + rnd.nextDouble() * 5,
        h: 8 + rnd.nextDouble() * 6,
      );
    });
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => _c.isAnimating
            ? CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_pieces, _c.value),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Piece {
  final double x0, vx, vy, spin, w, h;
  final Color color;

  const _Piece({
    required this.x0,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.w,
    required this.h,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final p in pieces) {
      final x = (p.x0 + p.vx * t) * size.width;
      final y = size.height * 0.62 + (p.vy * t + 1.6 * t * t) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.w,
            height: p.h * (0.6 + 0.4 * math.cos(p.spin * t * 2).abs()),
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
