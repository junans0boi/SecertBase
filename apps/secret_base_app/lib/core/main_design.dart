import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Neutral ───────────────────────────────────────────────────────
const kMainBg        = Color(0xFFFAF7F5);
const kMainPaper     = Color(0xFFFFFFFF);
const kMainPaperSoft = Color(0xFFF7F7FA);
const kMainLine      = Color(0xFFEBEBF0);
const kMainInk       = Color(0xFF1E1E2E);
const kMainSub       = Color(0xFF5A5A78);
const kMainMuted     = Color(0xFFABABBC);

// ─── Accent ────────────────────────────────────────────────────────
const kMainRose      = Color(0xFF8C3A52);
const kMainRoseSoft  = Color(0xFFF1ECED);
const kMainSage      = Color(0xFF5E9B79);
const kMainSageSoft  = Color(0xFFEAEEEB);
const kMainSky       = Color(0xFF4C7FA0);
const kMainSkySoft   = Color(0xFFE9ECEF);
const kMainHoney     = Color(0xFFC08A3E);
const kMainHoneySoft = Color(0xFFF2EEE6);
const kMainPeach     = Color(0xFFC97A5C);
const kMainPeachSoft = Color(0xFFF1ECE9);

// ─── Gradients ─────────────────────────────────────────────────────
const kRoseGrad = LinearGradient(
  colors: [Color(0xFF5C2436), Color(0xFF8C3A52)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSkyGrad = LinearGradient(
  colors: [Color(0xFF4C7FA0), Color(0xFF6FA0BE)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSageGrad = LinearGradient(
  colors: [Color(0xFF5E9B79), Color(0xFF7CB89B)],
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
  return GoogleFonts.notoSerifKr(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.2,
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
    this.radius = 16,
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

  const CozyMascot({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MascotPainter());
  }
}

// Two interlocked rings — a quiet mark for "the two of us," not a character.
class _MascotPainter extends CustomPainter {
  const _MascotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.22;
    final offset = r * 0.62;

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..color = kMainInk;
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028
      ..color = kMainHoney;

    canvas.drawCircle(Offset(center.dx - offset, center.dy), r, ink);
    canvas.drawCircle(Offset(center.dx + offset, center.dy), r, gold);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) => false;
}
