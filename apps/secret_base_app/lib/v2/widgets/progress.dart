import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Circular progress ring with optional center content.
///
/// ```dart
/// V2ProgressRing(value: 0.7, semanticLabel: '오늘 기록 70%',
///     center: Text('70%', style: V2Text.head))
/// ```
class V2ProgressRing extends StatelessWidget {
  const V2ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 6,
    this.color,
    this.trackColor,
    this.center,
    this.semanticLabel,
  });

  /// 0..1
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? center;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: V2Motion.of(context, V2Motion.slow),
        curve: V2Motion.curve,
        builder: (context, t, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              t,
              stroke,
              color ?? p.primary,
              trackColor ?? p.soft2,
            ),
            child: center == null
                ? null
                : Center(child: ExcludeSemantics(child: center!)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// 8px rounded progress bar (ds.css `.bar`).
///
/// ```dart
/// V2ProgressBar(value: 3 / 5, semanticLabel: '5단계 중 3단계')
/// ```
class V2ProgressBar extends StatelessWidget {
  const V2ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semanticLabel,
  });

  final double value;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: p.soft2)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: v),
                duration: V2Motion.of(context, V2Motion.slow),
                curve: V2Motion.curve,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color ?? p.primary,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
