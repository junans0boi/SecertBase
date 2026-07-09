import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Neutral ───────────────────────────────────────────────────────
const kMainBg = Color(0xFFFFFBFD);
const kMainPaper = Color(0xFFFFFFFF);
const kMainPaperSoft = Color(0xFFFFF5F8);
const kMainLine = Color(0xFFF3DCE6);
const kMainInk = Color(0xFF1E1E2E);
const kMainSub = Color(0xFF5A5A78);
const kMainMuted = Color(0xFFABABBC);

// ─── Accent ────────────────────────────────────────────────────────
const kMainRose = Color(0xFFFF6F9F);
const kMainRoseSoft = Color(0xFFFFEEF5);
const kMainSage = Color(0xFF55BF8A);
const kMainSageSoft = Color(0xFFECFAF4);
const kMainSky = Color(0xFF55A9DE);
const kMainSkySoft = Color(0xFFECF7FF);
const kMainHoney = Color(0xFFFFBE32);
const kMainHoneySoft = Color(0xFFFFF7DF);
const kMainPeach = Color(0xFFFF9670);
const kMainPeachSoft = Color(0xFFFFF1EC);
const kMainLilac = Color(0xFF9D83FF);
const kMainLilacSoft = Color(0xFFF4F0FF);

// ─── Gradients ─────────────────────────────────────────────────────
const kRoseGrad = LinearGradient(
  colors: [Color(0xFFFF6F9F), Color(0xFFFF9670)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSkyGrad = LinearGradient(
  colors: [Color(0xFF55A9DE), Color(0xFF80D5F6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSageGrad = LinearGradient(
  colors: [Color(0xFF55BF8A), Color(0xFF7CDAAB)],
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
            color: kMainRose.withAlpha(16),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
    final halo = Paint()..color = kMainRoseSoft;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = kMainMuted;
    canvas.drawCircle(center, r * 1.22, halo);
    canvas.drawCircle(center, r, body);
    canvas.drawCircle(center, r, outline);

    final ear = Paint()..color = kMainPaper;
    canvas.drawCircle(
      Offset(center.dx - r * 0.72, center.dy - r * 0.52),
      r * 0.22,
      ear,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.72, center.dy - r * 0.52),
      r * 0.22,
      ear,
    );
    canvas.drawCircle(
      Offset(center.dx - r * 0.72, center.dy - r * 0.52),
      r * 0.22,
      outline,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.72, center.dy - r * 0.52),
      r * 0.22,
      outline,
    );

    final eye = Paint()..color = kMainInk;
    canvas.drawCircle(
      Offset(center.dx - r * 0.35, center.dy - r * 0.04),
      2.0,
      eye,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.35, center.dy - r * 0.04),
      2.0,
      eye,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 0.18),
        width: r * 0.34,
        height: r * 0.22,
      ),
      0.15,
      2.84,
      false,
      outline..strokeWidth = 1.35,
    );

    if (blushing) {
      final blush = Paint()..color = kMainRose.withAlpha(88);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx - r * 0.55, center.dy + r * 0.22),
          width: r * 0.26,
          height: r * 0.14,
        ),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + r * 0.55, center.dy + r * 0.22),
          width: r * 0.26,
          height: r * 0.14,
        ),
        blush,
      );
    }

    final sparkle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = kMainHoney;
    final s = r * 0.18;
    final sparkleCenter = Offset(center.dx + r * 0.9, center.dy - r * 0.95);
    canvas.drawLine(
      Offset(sparkleCenter.dx, sparkleCenter.dy - s),
      Offset(sparkleCenter.dx, sparkleCenter.dy + s),
      sparkle,
    );
    canvas.drawLine(
      Offset(sparkleCenter.dx - s, sparkleCenter.dy),
      Offset(sparkleCenter.dx + s, sparkleCenter.dy),
      sparkle,
    );
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      blushing != oldDelegate.blushing;
}
