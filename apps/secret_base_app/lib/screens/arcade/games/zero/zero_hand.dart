import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 손가락 수를 보여 주는 만화풍 손(위를 향함). [fingers]는 0~5이고 소수면 다음 손가락이
/// 그만큼 펴진다(카운트업 애니메이션용). 펴는 순서: 검지 → 중지 → 약지 → 새끼 → 엄지.
class ZeroHand extends StatelessWidget {
  final double fingers;
  final Color sleeve;
  final bool mirrored;
  final double size;
  final bool dim;

  const ZeroHand({
    super.key,
    required this.fingers,
    required this.sleeve,
    this.mirrored = false,
    this.size = 120,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.86,
      height: size,
      child: CustomPaint(
        painter: ZeroHandPainter(
          fingers: fingers,
          sleeve: sleeve,
          mirrored: mirrored,
          dim: dim,
        ),
      ),
    );
  }
}

class ZeroHandPainter extends CustomPainter {
  final double fingers;
  final Color sleeve;
  final bool mirrored;
  final bool dim;

  ZeroHandPainter({
    required this.fingers,
    required this.sleeve,
    this.mirrored = false,
    this.dim = false,
  });

  static const _skin = Color(0xFFFFDDB8);
  static const _skinShade = Color(0xFFF0B489);
  static const _outline = Color(0xFF4A1F33);
  static const _nail = Color(0xFFFFEEDD);

  double _ext(int i) => (fingers - i).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (mirrored) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (dim) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.026)
      ..strokeJoin = StrokeJoin.round
      ..color = _outline;
    final skin = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_skin, _skinShade],
      ).createShader(Offset.zero & size);

    // 그림자.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.97),
        width: w * 0.7,
        height: h * 0.05,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // 소매.
    final cuff = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.2, h * 0.8, w * 0.8, h * 0.97),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      cuff,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(sleeve, Colors.white, 0.25)!, sleeve],
        ).createShader(cuff.outerRect),
    );
    canvas.drawRRect(cuff, stroke);
    canvas.drawLine(
      Offset(w * 0.22, h * 0.85),
      Offset(w * 0.78, h * 0.85),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = w * 0.02,
    );

    // 손가락 4개(검지·중지·약지·새끼). 손바닥보다 먼저 그려 뿌리를 덮는다.
    const centers = [0.30, 0.435, 0.57, 0.70];
    const tops = [0.15, 0.08, 0.13, 0.23];
    final fw = w * 0.125;
    final baseY = h * 0.5;
    final foldTop = h * 0.4;
    for (int i = 0; i < 4; i++) {
      final e = Curves.easeOutBack.transform(_ext(i));
      final top = foldTop + (h * tops[i] - foldTop) * e;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          w * centers[i] - fw / 2,
          top,
          w * centers[i] + fw / 2,
          baseY + h * 0.08,
        ),
        Radius.circular(fw / 2),
      );
      canvas.drawRRect(r, skin);
      canvas.drawRRect(r, stroke);
      if (e > 0.6) {
        final nail = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * centers[i] - fw * 0.28,
            top + fw * 0.18,
            fw * 0.56,
            fw * 0.5,
          ),
          Radius.circular(fw * 0.22),
        );
        canvas.drawRRect(
          nail,
          Paint()..color = _nail.withValues(alpha: (e - 0.6) / 0.4),
        );
      }
    }

    // 손바닥.
    final palm = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.22, h * 0.45, w * 0.78, h * 0.84),
      Radius.circular(w * 0.15),
    );
    canvas.drawRRect(palm, skin);
    canvas.drawRRect(palm, stroke);

    // 접힌 손가락 마디.
    for (int i = 0; i < 4; i++) {
      final e = _ext(i);
      if (e >= 0.5) continue;
      final knuckle = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * centers[i], h * 0.5),
          width: fw * 0.95,
          height: h * 0.1,
        ),
        Radius.circular(fw * 0.4),
      );
      canvas.drawRRect(knuckle, Paint()..color = _skin);
      canvas.drawRRect(knuckle, stroke..strokeWidth = math.max(1, w * 0.018));
      stroke.strokeWidth = math.max(1.2, w * 0.026);
    }

    // 엄지: 접히면 손바닥을 가로지르고, 펴면 왼쪽 위로 선다.
    final te = Curves.easeOutBack.transform(_ext(4));
    final base = Offset(w * 0.27, h * 0.74);
    final angle = -0.25 + (-2.25 - -0.25) * te;
    final len = w * (0.34 + 0.04 * te);
    final thick = w * 0.14;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    final thumb = RRect.fromRectAndRadius(
      Rect.fromLTWH(-thick * 0.3, -thick / 2, len, thick),
      Radius.circular(thick / 2),
    );
    canvas.drawRRect(thumb, Paint()..color = _skin);
    canvas.drawRRect(thumb, stroke);
    if (te > 0.6) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            len - thick * 0.3 - thick * 0.62,
            -thick * 0.25,
            thick * 0.5,
            thick * 0.5,
          ),
          Radius.circular(thick * 0.2),
        ),
        Paint()..color = _nail.withValues(alpha: (te - 0.6) / 0.4),
      );
    }
    canvas.restore();

    // 손바닥 주름 한 줄.
    canvas.drawArc(
      Rect.fromLTWH(w * 0.42, h * 0.6, w * 0.28, h * 0.14),
      0.2,
      1.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.014)
        ..color = _outline.withValues(alpha: 0.35),
    );

    if (dim) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ZeroHandPainter old) =>
      old.fingers != fingers ||
      old.sleeve != sleeve ||
      old.mirrored != mirrored ||
      old.dim != dim;
}
