import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kMainBg = Color(0xFFFAF4EA);
const kMainPaper = Color(0xFFFFFEFA);
const kMainPaperSoft = Color(0xFFF7F0E6);
const kMainLine = Color(0xFFE7DED1);
const kMainInk = Color(0xFF4D4740);
const kMainSub = Color(0xFF7C7368);
const kMainMuted = Color(0xFFB3A899);
const kMainRose = Color(0xFFE8A4A5);
const kMainRoseSoft = Color(0xFFF8E5E3);
const kMainSage = Color(0xFFA7B99A);
const kMainSageSoft = Color(0xFFEAF0E3);
const kMainSky = Color(0xFFAFC5CF);
const kMainSkySoft = Color(0xFFE7EEF2);
const kMainHoney = Color(0xFFE7CE8C);
const kMainHoneySoft = Color(0xFFF8EFD0);
const kMainPeach = Color(0xFFEAC1A7);
const kMainPeachSoft = Color(0xFFF8E8DE);

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
      child: CustomPaint(
        painter: const PaperTexturePainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFD9CEC0).withAlpha(30);
    for (double y = 8; y < size.height; y += 18) {
      for (double x = 10; x < size.width; x += 22) {
        final shift = ((x + y) % 7) * 0.18;
        canvas.drawCircle(Offset(x + shift, y), 0.7, dotPaint);
      }
    }

    final doodlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = kMainMuted.withAlpha(70);

    _drawEnvelope(
      canvas,
      doodlePaint,
      Offset(size.width * 0.12, size.height * 0.82),
      38,
    );
    _drawHeart(
      canvas,
      kMainRose.withAlpha(65),
      Offset(size.width * 0.78, size.height * 0.16),
      12,
    );
    _drawHeart(
      canvas,
      kMainSky.withAlpha(45),
      Offset(size.width * 0.2, size.height * 0.2),
      20,
    );
    _drawSprout(
      canvas,
      doodlePaint,
      Offset(size.width * 0.87, size.height * 0.72),
      30,
    );
  }

  void _drawEnvelope(Canvas canvas, Paint paint, Offset c, double w) {
    final h = w * 0.56;
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
    canvas.drawLine(rect.topLeft, c, paint);
    canvas.drawLine(rect.topRight, c, paint);
    canvas.drawLine(rect.bottomLeft, c, paint);
    canvas.drawLine(rect.bottomRight, c, paint);
  }

  void _drawHeart(Canvas canvas, Color color, Offset c, double r) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.28)
      ..cubicTo(
        c.dx,
        c.dy - r * 0.5,
        c.dx - r,
        c.dy - r * 0.42,
        c.dx - r,
        c.dy + r * 0.08,
      )
      ..cubicTo(
        c.dx - r,
        c.dy + r * 0.72,
        c.dx,
        c.dy + r * 1.1,
        c.dx,
        c.dy + r * 1.32,
      )
      ..cubicTo(
        c.dx,
        c.dy + r * 1.1,
        c.dx + r,
        c.dy + r * 0.72,
        c.dx + r,
        c.dy + r * 0.08,
      )
      ..cubicTo(
        c.dx + r,
        c.dy - r * 0.42,
        c.dx,
        c.dy - r * 0.5,
        c.dx,
        c.dy + r * 0.28,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSprout(Canvas canvas, Paint paint, Offset c, double h) {
    canvas.drawLine(c, Offset(c.dx, c.dy - h), paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - 8, c.dy - h + 7),
        width: 16,
        height: 9,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + 8, c.dy - h + 3),
        width: 16,
        height: 9,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;

  const MainCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = kMainPaper,
    this.borderColor = kMainLine,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A7F70).withAlpha(16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
    final shadow = Paint()..color = const Color(0xFFC9B9A5).withAlpha(65);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r + 7),
        width: r * 1.25,
        height: r * 0.23,
      ),
      shadow,
    );

    final body = Paint()..color = kMainPaper;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9E927F);
    canvas.drawCircle(center, r, body);
    canvas.drawCircle(center, r, outline);

    final eye = Paint()..color = kMainInk;
    canvas.drawCircle(
      Offset(center.dx - r * 0.35, center.dy - r * 0.04),
      1.9,
      eye,
    );
    canvas.drawCircle(
      Offset(center.dx + r * 0.35, center.dy - r * 0.04),
      1.9,
      eye,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 0.18),
        width: r * 0.32,
        height: r * 0.2,
      ),
      0.15,
      2.84,
      false,
      outline..strokeWidth = 1.3,
    );

    if (blushing) {
      final blush = Paint()..color = kMainRose.withAlpha(88);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx - r * 0.55, center.dy + r * 0.22),
          width: r * 0.24,
          height: r * 0.13,
        ),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + r * 0.55, center.dy + r * 0.22),
          width: r * 0.24,
          height: r * 0.13,
        ),
        blush,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) =>
      blushing != oldDelegate.blushing;
}

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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Center(child: child),
    );
  }
}
