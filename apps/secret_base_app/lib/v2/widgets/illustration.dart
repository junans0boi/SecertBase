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
        child: CustomPaint(
          painter: _ScenePainter(scene, dark: p.dark, palette: p),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, {required this.dark, required this.palette});

  final V2Scene scene;
  final bool dark;
  final V2Palette palette;

  static Color get _rose => V2Colors.rose;
  static Color get _roseDeep => V2Colors.rose600;
  static Color get _peach => V2Colors.peach;
  static Color get _lilac => V2Colors.lilac;
  static Color get _sky => V2Colors.sky;
  static Color get _sage => V2Colors.sage;
  static Color get _honey => V2Colors.honey;

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
      old.scene != scene || old.dark != dark || old.palette != palette;
}

/// Night-sky tent hero artwork for the home screen (mockup `.hm-ill`, a
/// 390×204 viewBox pinned to the bottom-right and sliced to cover). Draws
/// only the artwork; put it in a [Stack] over the pastel hero gradient.
///
/// ```dart
/// Stack(children: [const Positioned.fill(child: V2HeroIllustration()), ...])
/// ```
class V2HeroIllustration extends StatelessWidget {
  const V2HeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _HeroPainter(V2Palette.of(context)),
        size: Size.infinite,
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter(this.palette);

  final V2Palette palette;

  static const _w = 390.0;
  static const _h = 204.0;
  static const _pole = Color(0xFFB07A8F);
  static const _gold = Color(0xFFFFD76A);

  bool get _isBlossom => identical(palette, V2Palettes.blossom);
  Color get _hillFar => _isBlossom
      ? const Color(0xFFFFCADD)
      : Color.lerp(palette.primarySoft, palette.point, .18)!;
  Color get _hillNear => _isBlossom
      ? const Color(0xFFFFB2CB)
      : Color.lerp(palette.primarySoft, palette.point, .4)!;
  Color get _stripe => _isBlossom
      ? const Color(0xFFFF8FB3)
      : palette.point.withValues(alpha: .8);
  Color get _accent => _isBlossom ? V2Palettes.blossom.primary : palette.point;
  Color get _poleC => _isBlossom ? _pole : palette.control;

  @override
  void paint(Canvas canvas, Size size) {
    // preserveAspectRatio="xMaxYMax slice"
    final s = math.max(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate(size.width - _w * s, size.height - _h * s);
    canvas.scale(s);

    Paint fill(Color c, [double o = 1]) =>
        Paint()..color = c.withValues(alpha: o);
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    // crescent moon
    final moon = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(296, 69), radius: 17)),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(301.5, 67), radius: 16)),
    );
    canvas.drawPath(moon, fill(_gold, .9));

    void star(double cx, double cy, double r, double o) {
      final k = r * .3;
      final p = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + k, cy - k)
        ..lineTo(cx + r, cy)
        ..lineTo(cx + k, cy + k)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - k, cy + k)
        ..lineTo(cx - r, cy)
        ..lineTo(cx - k, cy - k)
        ..close();
      canvas.drawPath(p, fill(Colors.white, o));
    }

    star(246, 70, 4.5, .9);
    star(330, 118, 3, .8);
    star(214, 112, 3, .7);
    star(370, 60, 3, .8);

    // rolling hills
    canvas.drawPath(
      Path()
        ..moveTo(0, 168)
        ..quadraticBezierTo(90, 138, 190, 160)
        ..quadraticBezierTo(290, 182, 390, 146)
        ..lineTo(390, _h)
        ..lineTo(0, _h)
        ..close(),
      fill(_hillFar),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 190)
        ..quadraticBezierTo(120, 164, 230, 184)
        ..quadraticBezierTo(340, 204, 390, 174)
        ..lineTo(390, _h)
        ..lineTo(0, _h)
        ..close(),
      fill(_hillNear),
    );

    // string lights
    canvas.drawLine(
      const Offset(196, 152),
      const Offset(196, 180),
      stroke(_poleC, 3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(196, 152)
        ..quadraticBezierTo(238, 172, 280, 124),
      stroke(_poleC, 1.6),
    );
    canvas.drawCircle(const Offset(217, 157), 3.4, fill(_gold));
    canvas.drawCircle(const Offset(238, 154), 3.4, fill(Colors.white));
    canvas.drawCircle(const Offset(259, 143), 3.4, fill(_gold));

    // tent
    canvas.drawPath(
      Path()
        ..moveTo(238, 180)
        ..lineTo(280, 120)
        ..lineTo(322, 180)
        ..close(),
      fill(Colors.white),
    );
    canvas.drawPath(
      Path()
        ..moveTo(280, 120)
        ..lineTo(266, 180)
        ..lineTo(294, 180)
        ..close(),
      fill(_stripe),
    );
    canvas.drawLine(
      const Offset(280, 120),
      const Offset(280, 106),
      stroke(_poleC, 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(280, 106)
        ..lineTo(291, 110)
        ..lineTo(280, 114)
        ..close(),
      fill(_accent),
    );

    // couple
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(344, 188), width: 64, height: 10),
      fill(Colors.white, .85),
    );
    void person(double x, Color c) {
      canvas.drawCircle(Offset(x, 162.5), 6.5, fill(c));
      canvas.drawPath(
        Path()
          ..moveTo(x - 10, 188)
          ..cubicTo(x - 10, 172, x - 6, 164, x, 164)
          ..cubicTo(x + 6, 164, x + 10, 172, x + 10, 188)
          ..close(),
        fill(c),
      );
    }

    person(334, _isBlossom ? const Color(0xFF5B4A8A) : palette.partner);
    person(350, _isBlossom ? V2Palettes.blossom.primary : palette.me);

    void heart(double x, double y, double k, Color c, double o) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(k);
      canvas.drawPath(
        Path()
          ..moveTo(0, 5)
          ..cubicTo(-8, -1, -7, -8, -2, -8)
          ..cubicTo(0, -8, 0, -6, 0, -6)
          ..cubicTo(0, -6, 0, -8, 2, -8)
          ..cubicTo(7, -8, 8, -1, 0, 5)
          ..close(),
        fill(c, o),
      );
      canvas.restore();
    }

    heart(342, 140, 1.15, _accent, .9);
    heart(366, 128, .7, _stripe, .8);
    heart(318, 124, .55, Colors.white, .9);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.palette != palette;
}
