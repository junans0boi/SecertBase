import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Soft gradient photo stand-in (ds.css `.ph-img`). Never fake faces —
/// shows an optional icon over a warm pastel gradient chosen by [seed].
///
/// ```dart
/// V2PhotoPlaceholder(seed: record.id, aspectRatio: 1)
/// V2PhotoPlaceholder(icon: V2Icons.image, radius: 12)
/// ```
class V2PhotoPlaceholder extends StatelessWidget {
  const V2PhotoPlaceholder({
    super.key,
    this.seed,
    this.icon,
    this.aspectRatio,
    this.radius = V2Radius.ctl,
    this.semanticLabel,
  });

  final Object? seed;
  final IconData? icon;

  /// Null = fill the parent constraints.
  final double? aspectRatio;
  final double radius;

  /// Null = decorative (hidden from screen readers).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        gradient: V2Gradients.placeholder(seed),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: icon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                icon,
                size: 32,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
    );
    if (aspectRatio != null) {
      box = AspectRatio(aspectRatio: aspectRatio!, child: box);
    }
    return semanticLabel == null
        ? ExcludeSemantics(child: box)
        : Semantics(image: true, label: semanticLabel, child: box);
  }
}

/// 88px rounded "art" tile used at the top of empty/error states
/// (ds.css `.state .art`).
///
/// ```dart
/// V2Art(icon: V2Icons.camera)
/// V2Art(icon: V2Icons.offline, tone: V2Tone.sky)
/// ```
class V2Art extends StatelessWidget {
  const V2Art({
    super.key,
    required this.icon,
    this.tone = V2Tone.rose,
    this.size = 88,
  });

  final IconData icon;
  final V2Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.dark ? p.soft : t.soft,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(
          icon,
          size: size * 0.42,
          color: p.dark ? p.primary : t.base,
        ),
      ),
    );
  }
}

/// Built-in vector scenes for empty states.
enum V2Scene {
  /// Two soft hearts — 기록이 아직 없어요.
  hearts,

  /// Two figures side by side — 연결 전 / 우리.
  couple,

  /// Folded map with a pin — 장소가 아직 없어요.
  map,

  /// Photo frame with sun and hills — 사진.
  photo,

  /// Cloud with a slash — 오프라인.
  offline,

  /// Envelope — 알림·편지.
  letter,

  /// Calendar page — 기념일.
  calendar,
}

/// Simple painted pastel scene (≈160×120) for empty states. Decorative.
///
/// ```dart
/// V2EmptyState(illustration: const V2SceneIllustration(V2Scene.map), ...)
/// ```
class V2SceneIllustration extends StatelessWidget {
  const V2SceneIllustration(this.scene, {super.key, this.width = 160});

  final V2Scene scene;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: width * 0.75,
        child: CustomPaint(painter: _ScenePainter(scene, dark: p.dark)),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, {required this.dark});

  final V2Scene scene;
  final bool dark;

  static const _rose = V2Colors.rose;
  static const _roseDeep = V2Colors.rose600;
  static const _peach = V2Colors.peach;
  static const _lilac = V2Colors.lilac;
  static const _sky = V2Colors.sky;
  static const _sage = V2Colors.sage;
  static const _honey = V2Colors.honey;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final u = w / 160; // design unit

    // Backdrop blob: blush → peach → lilac.
    final blobRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.55),
      width: w * 0.92,
      height: h * 0.82,
    );
    final blob = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF3A2433), Color(0xFF2D2650)]
            : const [Color(0xFFFFE6EE), Color(0xFFFFEDE4), Color(0xFFEFE9FF)],
      ).createShader(blobRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(blobRect, Radius.circular(h * 0.4)),
      blob,
    );

    // Sparkles.
    final sparkle = Paint()..color = _honey.withValues(alpha: 0.9);
    _star(canvas, Offset(w * 0.16, h * 0.22), 5 * u, sparkle);
    _star(canvas, Offset(w * 0.86, h * 0.3), 4 * u, sparkle);
    canvas.drawCircle(
      Offset(w * 0.8, h * 0.14),
      2.4 * u,
      Paint()..color = _lilac.withValues(alpha: 0.8),
    );

    final c = Offset(w / 2, h * 0.56);
    switch (scene) {
      case V2Scene.hearts:
        _heart(canvas, c.translate(-14 * u, 2 * u), 30 * u, _rose);
        _heart(
          canvas,
          c.translate(18 * u, -8 * u),
          22 * u,
          _peach.withValues(alpha: 0.95),
        );
      case V2Scene.couple:
        _figure(canvas, c.translate(-18 * u, 6 * u), 22 * u, _rose);
        _figure(canvas, c.translate(18 * u, 6 * u), 22 * u, _sky);
        _heart(canvas, c.translate(0, -30 * u), 12 * u, _roseDeep);
      case V2Scene.map:
        final map = Path()
          ..moveTo(c.dx - 40 * u, c.dy - 18 * u)
          ..lineTo(c.dx - 14 * u, c.dy - 26 * u)
          ..lineTo(c.dx + 14 * u, c.dy - 18 * u)
          ..lineTo(c.dx + 40 * u, c.dy - 26 * u)
          ..lineTo(c.dx + 40 * u, c.dy + 22 * u)
          ..lineTo(c.dx + 14 * u, c.dy + 30 * u)
          ..lineTo(c.dx - 14 * u, c.dy + 22 * u)
          ..lineTo(c.dx - 40 * u, c.dy + 30 * u)
          ..close();
        canvas.drawPath(map, Paint()..color = Colors.white);
        canvas.drawPath(
          map,
          Paint()
            ..color = _sage.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * u
            ..strokeJoin = StrokeJoin.round,
        );
        final fold = Paint()
          ..color = _sage.withValues(alpha: 0.35)
          ..strokeWidth = 1.6 * u;
        canvas.drawLine(
          Offset(c.dx - 14 * u, c.dy - 26 * u),
          Offset(c.dx - 14 * u, c.dy + 22 * u),
          fold,
        );
        canvas.drawLine(
          Offset(c.dx + 14 * u, c.dy - 18 * u),
          Offset(c.dx + 14 * u, c.dy + 30 * u),
          fold,
        );
        _pin(canvas, c.translate(2 * u, -6 * u), 16 * u, _roseDeep);
      case V2Scene.photo:
        final frame = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 76 * u, height: 58 * u),
          Radius.circular(10 * u),
        );
        canvas.drawRRect(frame, Paint()..color = Colors.white);
        canvas.save();
        canvas.clipRRect(frame.deflate(5 * u));
        canvas.drawRect(
          frame.outerRect,
          Paint()..color = const Color(0xFFFFE3EB),
        );
        canvas.drawCircle(
          c.translate(16 * u, -12 * u),
          7 * u,
          Paint()..color = _honey,
        );
        final hills = Path()
          ..moveTo(c.dx - 40 * u, c.dy + 30 * u)
          ..quadraticBezierTo(c.dx - 18 * u, c.dy - 8 * u, c.dx, c.dy + 14 * u)
          ..quadraticBezierTo(
            c.dx + 18 * u,
            c.dy - 2 * u,
            c.dx + 40 * u,
            c.dy + 30 * u,
          )
          ..close();
        canvas.drawPath(hills, Paint()..color = _rose.withValues(alpha: 0.8));
        canvas.restore();
      case V2Scene.offline:
        _cloud(canvas, c, 34 * u, Colors.white);
        canvas.drawLine(
          c.translate(-22 * u, -20 * u),
          c.translate(22 * u, 20 * u),
          Paint()
            ..color = _sky
            ..strokeWidth = 4 * u
            ..strokeCap = StrokeCap.round,
        );
      case V2Scene.letter:
        final r = Rect.fromCenter(center: c, width: 74 * u, height: 50 * u);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(8 * u)),
          Paint()..color = Colors.white,
        );
        final flap = Path()
          ..moveTo(r.left + 4 * u, r.top + 4 * u)
          ..lineTo(r.center.dx, r.center.dy + 4 * u)
          ..lineTo(r.right - 4 * u, r.top + 4 * u);
        canvas.drawPath(
          flap,
          Paint()
            ..color = _lilac
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * u
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
        _heart(canvas, r.center.translate(0, 10 * u), 12 * u, _rose);
      case V2Scene.calendar:
        final r = Rect.fromCenter(center: c, width: 64 * u, height: 60 * u);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(10 * u)),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(r.left, r.top, r.width, 16 * u),
            topLeft: Radius.circular(10 * u),
            topRight: Radius.circular(10 * u),
          ),
          Paint()..color = _rose,
        );
        _heart(canvas, r.center.translate(0, 8 * u), 18 * u, _roseDeep);
    }
  }

  void _heart(Canvas canvas, Offset center, double size, Color color) {
    final s = size;
    final path = Path()
      ..moveTo(center.dx, center.dy + s * 0.35)
      ..cubicTo(
        center.dx - s * 0.9,
        center.dy - s * 0.2,
        center.dx - s * 0.45,
        center.dy - s * 0.85,
        center.dx,
        center.dy - s * 0.4,
      )
      ..cubicTo(
        center.dx + s * 0.45,
        center.dy - s * 0.85,
        center.dx + s * 0.9,
        center.dy - s * 0.2,
        center.dx,
        center.dy + s * 0.35,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _figure(Canvas canvas, Offset base, double s, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(base.translate(0, -s * 0.9), s * 0.38, paint);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: base.translate(0, s * 0.25),
          width: s * 1.15,
          height: s * 1.1,
        ),
        topLeft: Radius.circular(s * 0.55),
        topRight: Radius.circular(s * 0.55),
        bottomLeft: Radius.circular(s * 0.15),
        bottomRight: Radius.circular(s * 0.15),
      ),
      paint,
    );
  }

  void _pin(Canvas canvas, Offset tip, double s, Color color) {
    final head = tip.translate(0, -s * 1.1);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        head.dx - s,
        head.dy + s * 0.2,
        head.dx - s * 0.62,
        head.dy - s * 0.3,
      )
      ..arcToPoint(
        Offset(head.dx + s * 0.62, head.dy - s * 0.3),
        radius: Radius.circular(s * 0.7),
      )
      ..quadraticBezierTo(head.dx + s, head.dy + s * 0.2, tip.dx, tip.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(
      head.translate(0, -s * 0.15),
      s * 0.28,
      Paint()..color = Colors.white,
    );
  }

  void _cloud(Canvas canvas, Offset c, double s, Color color) {
    final paint = Paint()..color = color;
    canvas.drawCircle(c.translate(-s * 0.5, s * 0.1), s * 0.45, paint);
    canvas.drawCircle(c.translate(s * 0.1, -s * 0.2), s * 0.6, paint);
    canvas.drawCircle(c.translate(s * 0.65, s * 0.15), s * 0.4, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(c.dx - s * 0.95, c.dy, c.dx + s * 1.05, c.dy + s * 0.55),
        Radius.circular(s * 0.3),
      ),
      paint,
    );
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.35;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.scene != scene || old.dark != dark;
}
