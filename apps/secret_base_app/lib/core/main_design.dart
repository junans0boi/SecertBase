import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Neutral ───────────────────────────────────────────────────────
const kMainBg        = Color(0xFFFFFFFF);
const kMainPaper     = Color(0xFFFFFFFF);
const kMainPaperSoft = Color(0xFFF7F7FA);
const kMainLine      = Color(0xFFEBEBF0);
const kMainInk       = Color(0xFF1E1E2E);
const kMainSub       = Color(0xFF5A5A78);
const kMainMuted     = Color(0xFFABABBC);

// ─── Accent ────────────────────────────────────────────────────────
const kMainRose      = Color(0xFFFF7B9C);
const kMainRoseSoft  = Color(0xFFFFF0F5);
const kMainSage      = Color(0xFF5EBF8A);
const kMainSageSoft  = Color(0xFFEEFAF4);
const kMainSky       = Color(0xFF5AAAD8);
const kMainSkySoft   = Color(0xFFEBF5FF);
const kMainHoney     = Color(0xFFFFC234);
const kMainHoneySoft = Color(0xFFFFF8E6);
const kMainPeach     = Color(0xFFFF9B71);
const kMainPeachSoft = Color(0xFFFFF4EE);

// ─── Gradients ─────────────────────────────────────────────────────
const kRoseGrad = LinearGradient(
  colors: [Color(0xFFFF7B9C), Color(0xFFFF9B71)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSkyGrad = LinearGradient(
  colors: [Color(0xFF5AAAD8), Color(0xFF7BC8F0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSageGrad = LinearGradient(
  colors: [Color(0xFF5EBF8A), Color(0xFF7CDAAB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Typography ────────────────────────────────────────────────────
TextStyle mainTitle({
  double size = 28,
  Color color = kMainInk,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 0,
}) {
  return GoogleFonts.gaegu(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.08,
  );
}

TextStyle mainBody({
  double size = 13,
  Color color = kMainSub,
  FontWeight weight = FontWeight.w400,
  double height = 1.45,
}) {
  return GoogleFonts.notoSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
    height: height,
  );
}

// ─── Layout ────────────────────────────────────────────────────────
class CozyPage extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const CozyPage({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kMainBg,
      child: Padding(padding: padding, child: child),
    );
  }
}

class MainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final Gradient? gradient;

  const MainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.radius = 22,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? kMainPaper) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF000000).withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class IconBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color backgroundColor;
  final double size;

  const IconBadge({
    super.key,
    required this.child,
    required this.color,
    required this.backgroundColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Center(child: child),
    );
  }
}

// Keep DoodleBadge as alias for backward compat
class DoodleBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color backgroundColor;
  final double size;

  const DoodleBadge({
    super.key,
    required this.child,
    required this.color,
    required this.backgroundColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return IconBadge(
      color: color,
      backgroundColor: backgroundColor,
      size: size,
      child: child,
    );
  }
}

class CozyMascot extends StatelessWidget {
  final double size;
  final bool blushing;

  const CozyMascot({super.key, this.size = 96, this.blushing = true});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MascotPainter(blushing: blushing),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final bool blushing;
  const _MascotPainter({required this.blushing});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.32;

    final body = Paint()..color = kMainPaper;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = kMainMuted;
    canvas.drawCircle(center, r, body);
    canvas.drawCircle(center, r, outline);

    final eye = Paint()..color = kMainInk;
    canvas.drawCircle(Offset(center.dx - r * 0.35, center.dy - r * 0.04), 1.9, eye);
    canvas.drawCircle(Offset(center.dx + r * 0.35, center.dy - r * 0.04), 1.9, eye);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * 0.18), width: r * 0.32, height: r * 0.2),
      0.15, 2.84, false, outline..strokeWidth = 1.3,
    );

    if (blushing) {
      final blush = Paint()..color = kMainRose.withAlpha(88);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx - r * 0.55, center.dy + r * 0.22), width: r * 0.24, height: r * 0.13), blush);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx + r * 0.55, center.dy + r * 0.22), width: r * 0.24, height: r * 0.13), blush);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) => blushing != oldDelegate.blushing;
}
