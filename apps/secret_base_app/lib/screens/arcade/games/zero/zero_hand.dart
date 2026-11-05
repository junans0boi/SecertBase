import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 마술사의 흰 쇼 장갑(손바닥이 보이고 위를 향함). [fingers]는 0~5이고 소수면 다음
/// 손가락이 그만큼 펴진다(카운트업 애니메이션용). 펴는 순서: 검지 → 중지 → 약지 →
/// 새끼 → 엄지. 장갑은 늘 흰색이고, 커프스 띠와 가장자리 림 라이트만 [trim]
/// (플레이어 색)으로 물든다. [sparkle]이 0~1로 흐르면 장갑에 반짝임이 지나간다.
class ZeroHand extends StatelessWidget {
  final double fingers;
  final Color trim;
  final bool mirrored;
  final double size;
  final bool dim;
  final double sparkle;

  const ZeroHand({
    super.key,
    required this.fingers,
    required this.trim,
    this.mirrored = false,
    this.size = 120,
    this.dim = false,
    this.sparkle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * ZeroHandPainter.aspect,
      height: size,
      child: CustomPaint(
        painter: ZeroHandPainter(
          fingers: fingers,
          trim: trim,
          mirrored: mirrored,
          dim: dim,
          sparkle: sparkle,
        ),
      ),
    );
  }
}

/// 손가락 하나의 치수(장갑 좌표계: 가로 100, 세로 116).
class _FingerSpec {
  final Offset base;
  final double width;
  final double length;
  final double spread;
  final double fold;

  const _FingerSpec(this.base, this.width, this.length, this.spread, this.fold);
}

class ZeroHandPainter extends CustomPainter {
  final double fingers;
  final Color trim;
  final bool mirrored;
  final bool dim;
  final double sparkle;

  ZeroHandPainter({
    required this.fingers,
    required this.trim,
    this.mirrored = false,
    this.dim = false,
    this.sparkle = 0,
  });

  /// 가로 / 세로.
  static const double aspect = 0.86;
  static const double _uw = 100;
  static const double _uh = _uw / aspect;

  static const _outline = Color(0xFF34142F);
  static const _ink = Color(0xFF5A3A62);
  static const _shade = Color(0xFF7D6A93);
  static const _gold = Color(0xFFF4C46A);

  // 검지, 중지, 약지, 새끼. 중지가 가장 길고 새끼가 가장 짧다.
  static const _specs = [
    _FingerSpec(Offset(35.4, 50.5), 11.2, 33.5, -0.16, 12.5),
    _FingerSpec(Offset(46.6, 47.8), 11.6, 37.5, -0.05, 13.5),
    _FingerSpec(Offset(57.6, 49.4), 10.8, 34.5, 0.08, 12),
    _FingerSpec(Offset(67.6, 54.0), 9.4, 27.0, 0.22, 8.5),
  ];
  static const _curlLength = 6.5;
  // 엄지 뿌리: 접히면 손바닥을 가로질러 검지·중지 끝을 덮고, 펴면 옆으로 선다.
  static const _thumbPivotCurled = Offset(30.5, 69.5);
  static const _thumbPivotOpen = Offset(31.5, 77);
  static const _thumbCurled = 1.36;
  static const _thumbOpen = -0.58;
  static final _thenar = Rect.fromCenter(
    center: const Offset(29.5, 77.5),
    width: 21,
    height: 32,
  );

  double _ext(int i) => (fingers - i).clamp(0.0, 1.0);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// [base]에서 [angle](세로 기준, 시계 방향)만큼 기울인 좌표계.
  static Float64List _frame(Offset base, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      base.dx, base.dy, 0, 1,
    ]);
  }

  /// 위를 향한 끝이 둥근 테이퍼 캡슐(로컬 좌표, 뿌리 = 원점).
  static Path _taper(
    double len,
    double rb,
    double rt, {
    double back = 6,
    bool closed = true,
  }) {
    final p = Path()
      ..moveTo(-rb, back)
      ..lineTo(-rt, -(len - rt))
      ..arcToPoint(Offset(rt, -(len - rt)), radius: Radius.circular(rt))
      ..lineTo(rb, back);
    if (closed) p.close();
    return p;
  }

  /// 엄지(로컬 좌표, 뿌리 = 원점): 바깥쪽 관절이 살짝 불룩하고 끝으로 갈수록 가늘다.
  static Path _thumbShape(double len) {
    const rb = 6.4;
    const rt = 5.1;
    return Path()
      ..moveTo(-rb, 0)
      ..cubicTo(-rb - 0.9, -len * 0.4, -rt - 1.1, -len * 0.68, -rt, -(len - rt))
      ..arcToPoint(Offset(rt, -(len - rt)), radius: const Radius.circular(rt))
      ..cubicTo(rt + 0.1, -len * 0.62, rb - 1.4, -len * 0.3, rb, 0)
      ..close();
  }

  static Paint _blur(Color c, double sigma) => Paint()
    ..color = c
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  static Paint _line(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  /// 도형 안쪽, [offset] 반대편 가장자리에 부드러운 그늘을 깐다.
  static void _innerShade(
    Canvas canvas,
    Path shape,
    Offset offset,
    Color color,
    double sigma,
  ) {
    canvas.save();
    canvas.clipPath(shape);
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addRect(shape.getBounds().inflate(24)),
      shape.shift(offset),
    );
    canvas.drawPath(
      ring,
      sigma > 0 ? _blur(color, sigma) : (Paint()..color = color),
    );
    canvas.restore();
  }

  static void _dashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double on,
    double off,
  ) {
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + on, m.length)), paint);
        d += on + off;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _uw;
    if (s <= 0) return;
    final small = size.width < 64;

    canvas.save();
    if (mirrored) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (dim) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = const Color(0x8CFFFFFF),
      );
    }
    canvas.scale(s);

    final outlineW = math.max(small ? 3.4 : 2.0, 1.2 / s);
    final innerW = outlineW * (small ? 0.62 : 0.55);
    final glove = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.7, -1),
        end: Alignment(0.8, 1),
        colors: [Color(0xFFFFFFFF), Color(0xFFF6F1F6), Color(0xFFDCD3E2)],
        stops: [0, 0.5, 1],
      ).createShader(const Rect.fromLTWH(0, 0, _uw, _uh));
    final outline = _line(_outline, outlineW);

    // ── 손가락 기하.
    final thumbE = Curves.easeOutBack.transform(_ext(4));
    final spreadK = 0.6 + 0.4 * thumbE.clamp(0.0, 1.0);
    final angles = <double>[];
    final lengths = <double>[];
    final exts = <double>[];
    final fingerPaths = <Path>[];
    for (int i = 0; i < 4; i++) {
      final f = _specs[i];
      final e = Curves.easeOutBack.transform(_ext(i));
      final a = f.spread * spreadK * e.clamp(0.0, 1.0);
      final len = _lerp(_curlLength, f.length, e);
      exts.add(e);
      angles.add(a);
      lengths.add(len);
      fingerPaths.add(
        _taper(
          len,
          f.width / 2,
          f.width / 2 * 0.86,
        ).transform(_frame(f.base, a)),
      );
    }

    // ── 손바닥: 검지 바깥선과 새끼 바깥선을 매끄럽게 이어 받는다.
    Offset onSide(int i, double back, double side) {
      final f = _specs[i];
      final a = angles[i];
      final down = Offset(-math.sin(a), math.cos(a));
      final right = Offset(math.cos(a), math.sin(a));
      return f.base + down * back + right * (side * f.width / 2);
    }

    final ql = onSide(0, 3, -1);
    final qr = onSide(3, 3, 1);
    final dl = Offset(-math.sin(angles[0]), math.cos(angles[0]));
    final dr = Offset(-math.sin(angles[3]), math.cos(angles[3]));
    final palm = Path()
      ..moveTo(ql.dx, ql.dy)
      ..lineTo(_specs[1].base.dx, _specs[1].base.dy + 2)
      ..lineTo(_specs[2].base.dx, _specs[2].base.dy + 2)
      ..lineTo(qr.dx, qr.dy)
      ..cubicTo(qr.dx + dr.dx * 10, qr.dy + dr.dy * 10, 72.5, 80, 68.5, 91)
      ..quadraticBezierTo(51.5, 93, 34.5, 91)
      ..cubicTo(
        24.5,
        85,
        ql.dx + dl.dx * 16 - 2.5,
        ql.dy + dl.dy * 16,
        ql.dx,
        ql.dy,
      )
      ..close();

    Path silhouette = palm;
    for (final p in fingerPaths) {
      silhouette = Path.combine(PathOperation.union, silhouette, p);
    }

    // ── 엄지.
    final thumbAngle = _lerp(_thumbCurled, _thumbOpen, thumbE);
    final thumbLen =
        _lerp(30, 36, thumbE) * (1 - 0.3 * math.sin(math.pi * _ext(4)));
    final thumbPivot = Offset.lerp(
      _thumbPivotCurled,
      _thumbPivotOpen,
      thumbE.clamp(0.0, 1.0),
    )!;
    final thumb = _thumbShape(
      thumbLen,
    ).transform(_frame(thumbPivot, thumbAngle));
    final thenar = Path.combine(
      PathOperation.intersect,
      palm,
      Path()..addOval(_thenar),
    );

    // ── 커프스.
    final cuff = Path()
      ..moveTo(34.5, 92)
      ..lineTo(68.5, 92)
      ..cubicTo(70.5, 99, 73.5, 104, 75.5, 108.5)
      ..quadraticBezierTo(51.5, 116.5, 27.5, 108.5)
      ..cubicTo(29.5, 104, 32.5, 99, 34.5, 92)
      ..close();
    final band = RRect.fromLTRBR(
      31.5,
      86.5,
      71.5,
      94.5,
      const Radius.circular(2.8),
    );

    // 1) 플레이어 색 후광(림 라이트의 바깥쪽 번짐).
    if (!small) {
      final all = Path.combine(PathOperation.union, silhouette, thumb)
        ..addPath(cuff, Offset.zero);
      canvas.drawPath(all, _blur(trim.withValues(alpha: 0.32), 6));
    }

    // 2) 커프스 몸통(손목 아래, 바깥으로 살짝 벌어짐).
    canvas.drawPath(cuff, glove);
    _innerShade(
      canvas,
      cuff,
      const Offset(-3, -2),
      _shade.withValues(alpha: 0.4),
      small ? 0 : 2.4,
    );
    if (!small) {
      final hem = Path()
        ..moveTo(29.8, 106.2)
        ..quadraticBezierTo(51.5, 113.3, 73.2, 106.2);
      _dashed(canvas, hem, _line(_ink.withValues(alpha: 0.5), 0.8), 1.8, 1.4);
      for (final x in const [44.0, 59.0]) {
        canvas.drawLine(
          Offset(x, 97),
          Offset(x + (x - 51.5) * 0.25, 108),
          _line(_shade.withValues(alpha: 0.28), 0.9),
        );
      }
    }
    canvas.drawPath(cuff, outline);

    // 3) 장갑 실루엣(손바닥 + 네 손가락) 채우기와 입체 그늘.
    canvas.drawPath(silhouette, glove);
    // 오목한 손바닥 가운데.
    canvas.save();
    canvas.clipPath(silhouette);
    canvas.drawCircle(
      const Offset(54, 73),
      19,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _shade.withValues(alpha: 0.14),
                _shade.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: const Offset(54, 73), radius: 19),
            ),
    );
    canvas.restore();
    _innerShade(
      canvas,
      silhouette,
      const Offset(-3.2, -2.6),
      _shade.withValues(alpha: 0.42),
      small ? 0 : 2.6,
    );
    if (!small) {
      // 뒤에서 들어오는 플레이어 색 림 라이트(오른쪽 가장자리).
      _innerShade(
        canvas,
        silhouette,
        const Offset(-1.6, 0.4),
        trim.withValues(alpha: 0.75),
        0.9,
      );
    }

    // 4) 손가락 뿌리의 앰비언트 오클루전.
    if (!small) {
      canvas.save();
      canvas.clipPath(silhouette);
      for (int i = 0; i < 4; i++) {
        final e = exts[i].clamp(0.0, 1.0);
        if (e <= 0.05) continue;
        final f = _specs[i];
        canvas.drawOval(
          Rect.fromCenter(
            center: f.base + const Offset(0, 3.5),
            width: f.width * 1.05,
            height: 5,
          ),
          _blur(_shade.withValues(alpha: 0.16 * e), 2),
        );
      }
      for (int i = 0; i < 3; i++) {
        final e = math.min(exts[i], exts[i + 1]).clamp(0.0, 1.0);
        if (e <= 0.05) continue;
        final mid = Offset.lerp(onSide(i, -1, 1), onSide(i + 1, -1, -1), 0.5)!;
        canvas.drawCircle(
          mid,
          2.2,
          _blur(_outline.withValues(alpha: 0.28 * e), 1.4),
        );
      }
      canvas.restore();
    }

    // 5) 손바닥의 바늘땀 솔기 세 줄.
    if (!small) {
      canvas.save();
      canvas.clipPath(silhouette);
      const seams = [
        [Offset(43.2, 60), Offset(43.4, 73), Offset(45.4, 85)],
        [Offset(52.6, 59), Offset(52.4, 72), Offset(52.4, 86)],
        [Offset(61.8, 61), Offset(61.4, 73), Offset(59.4, 85)],
      ];
      for (final seam in seams) {
        final p = Path()
          ..moveTo(seam[0].dx, seam[0].dy)
          ..quadraticBezierTo(seam[1].dx, seam[1].dy, seam[2].dx, seam[2].dy);
        canvas.drawPath(
          p.shift(const Offset(0.7, 0)),
          _line(Colors.white, 1.1),
        );
        canvas.drawPath(p, _line(_shade.withValues(alpha: 0.32), 1.3));
        _dashed(
          canvas,
          p.shift(const Offset(-1.3, 0)),
          _line(_ink.withValues(alpha: 0.55), 0.7),
          1.6,
          1.3,
        );
      }
      canvas.restore();
    }

    // 6) 펴진 손가락: 사이 선, 마디 주름, 손가락마다 하이라이트 하나.
    for (int i = 0; i < 4; i++) {
      final e = exts[i];
      if (e <= 0.02) continue;
      final f = _specs[i];
      final m = _frame(f.base, angles[i]);
      final rb = f.width / 2;
      final len = lengths[i];
      final k = e.clamp(0.0, 1.0);
      canvas.drawPath(
        _taper(len, rb, rb * 0.86, back: 1.5, closed: false).transform(m),
        _line(_outline.withValues(alpha: k), innerW),
      );
      if (!small && len > 18) {
        for (final at in const [0.36, 0.64]) {
          final y = -len * at;
          canvas.drawPath(
            (Path()
                  ..moveTo(-rb * 0.5, y)
                  ..quadraticBezierTo(0, y + 1.2, rb * 0.5, y))
                .transform(m),
            _line(_shade.withValues(alpha: 0.4 * k), 0.8),
          );
        }
      }
      final hl = Path()
        ..moveTo(-rb * 0.42, -(len - rb * 1.15))
        ..lineTo(-rb * 0.5, -math.max(len * 0.32, 3.0));
      canvas.drawPath(
        hl.transform(m),
        _line(Colors.white.withValues(alpha: 0.95 * k), rb * 0.36)
          ..maskFilter = small
              ? null
              : const MaskFilter.blur(BlurStyle.normal, 0.5),
      );
    }

    // 7) 접힌 손가락: 손바닥 위로 내려온 마디(주먹 앞면).
    for (int i = 0; i < 4; i++) {
      final e = exts[i].clamp(0.0, 1.0);
      final alpha = (1 - e / 0.55).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      final f = _specs[i];
      final m = _frame(f.base, angles[i]);
      final hw = f.width / 2 * 0.96;
      final len = lengths[i];
      final depth = f.fold * (1 - e);
      final fold =
          (Path()..addRRect(
                RRect.fromLTRBR(-hw, -len, hw, depth, Radius.circular(hw)),
              ))
              .transform(m);
      canvas.saveLayer(
        silhouette.getBounds().inflate(4),
        Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
      );
      if (!small) {
        canvas.save();
        canvas.clipPath(silhouette);
        canvas.drawPath(
          fold.shift(const Offset(0.6, 2)),
          _blur(_outline.withValues(alpha: 0.3), 1.6),
        );
        canvas.restore();
      }
      canvas.drawPath(fold, glove);
      _innerShade(
        canvas,
        fold,
        const Offset(-2.2, -2.2),
        _shade.withValues(alpha: 0.38),
        small ? 0 : 1.6,
      );
      // 둘째 마디 주름.
      final cy = -len + (len + depth) * 0.56;
      canvas.drawPath(
        (Path()
              ..moveTo(-hw * 0.55, cy)
              ..quadraticBezierTo(0, cy + 1.6, hw * 0.55, cy))
            .transform(m),
        _line(_ink.withValues(alpha: 0.55), small ? innerW * 0.8 : 0.9),
      );
      // 첫째 마디(주먹 윗면)의 하이라이트.
      canvas.drawPath(
        (Path()
              ..moveTo(-hw * 0.5, -len + 3.2)
              ..quadraticBezierTo(-hw * 0.1, -len + 1.6, hw * 0.25, -len + 2))
            .transform(m),
        _line(Colors.white, small ? 1.6 : 1.5),
      );
      canvas.drawPath(fold, _line(_outline, innerW));
      canvas.restore();
    }

    // 8) 실루엣 외곽선(굵기 일정).
    canvas.drawPath(silhouette, outline);

    // 9) 엄지: 그림자 → 채우기 → 그늘 → 하이라이트 → 외곽선.
    if (!small) {
      canvas.save();
      canvas.clipPath(silhouette);
      canvas.drawPath(
        thumb.shift(const Offset(0.8, 2.4)),
        _blur(_outline.withValues(alpha: 0.32), 1.8),
      );
      canvas.restore();
    }
    canvas.drawPath(thumb, glove);
    _innerShade(
      canvas,
      thumb,
      const Offset(-2.4, -2.4),
      _shade.withValues(alpha: 0.4),
      small ? 0 : 1.8,
    );
    if (!small) {
      _innerShade(
        canvas,
        thumb,
        const Offset(-1.4, 0.4),
        trim.withValues(alpha: 0.6 * thumbE.clamp(0.0, 1.0)),
        0.8,
      );
    }
    {
      final m = _frame(thumbPivot, thumbAngle);
      canvas.drawPath(
        (Path()
              ..moveTo(-2.4, -(thumbLen - 6.2))
              ..lineTo(-3, -(thumbLen * 0.45)))
            .transform(m),
        _line(Colors.white, 2.2)
          ..maskFilter = small
              ? null
              : const MaskFilter.blur(BlurStyle.normal, 0.5),
      );
    }
    canvas.drawPath(
      thumb,
      _line(_outline, _lerp(innerW * 1.3, outlineW, thumbE.clamp(0.0, 1.0))),
    );

    // 10) 엄지 두덩: 엄지 뿌리를 덮고, 바깥선과 생명선 주름을 다시 긋는다.
    canvas.drawPath(thenar, glove);
    _innerShade(
      canvas,
      thenar,
      const Offset(-2.6, -2.2),
      _shade.withValues(alpha: 0.32),
      small ? 0 : 2,
    );
    canvas.save();
    canvas.clipRect(_thenar.inflate(outlineW));
    canvas.drawPath(palm, outline);
    canvas.restore();
    canvas.save();
    canvas.clipPath(palm);
    canvas.drawPath(
      Path()..addArc(_thenar, -0.55, 1.75),
      _line(_ink.withValues(alpha: 0.7), innerW),
    );
    canvas.restore();

    // 11) 손목의 커프스 띠: 플레이어 색 + 가는 금색 파이핑.
    canvas.drawRRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(trim, Colors.white, 0.45)!,
            trim,
            Color.lerp(trim, Colors.black, 0.28)!,
          ],
        ).createShader(band.outerRect),
    );
    canvas.drawLine(
      const Offset(33, 88.3),
      const Offset(70, 88.3),
      _line(_gold, small ? 1.6 : 1.2),
    );
    canvas.drawLine(
      const Offset(33, 92.8),
      const Offset(70, 92.8),
      _line(_gold, small ? 1.6 : 1.2),
    );
    if (!small) {
      canvas.drawLine(
        const Offset(36, 89.9),
        const Offset(56, 89.9),
        _line(Colors.white.withValues(alpha: 0.55), 0.9),
      );
    }
    canvas.drawRRect(band, outline);

    // 12) 득점 반짝임: 장갑 위를 지나가는 광택 + 별 네 개.
    if (sparkle > 0 && sparkle < 1) {
      _paintSparkle(
        canvas,
        Path.combine(PathOperation.union, silhouette, thumb),
      );
    }

    if (dim) canvas.restore();
    canvas.restore();
  }

  void _paintSparkle(Canvas canvas, Path glovePath) {
    final t = sparkle;
    final sheen = math.sin(math.pi * t);
    canvas.save();
    canvas.clipPath(glovePath);
    final x = _lerp(-20, 120, Curves.easeInOut.transform(t));
    final bandPath = Path()
      ..moveTo(x - 6, 0)
      ..lineTo(x + 8, 0)
      ..lineTo(x - 22, _uh)
      ..lineTo(x - 36, _uh)
      ..close();
    canvas.drawPath(
      bandPath,
      _blur(Colors.white.withValues(alpha: 0.75 * sheen), 3),
    );
    canvas.restore();

    const stars = [
      (Offset(16, 30), 7.0),
      (Offset(85, 18), 8.5),
      (Offset(90, 58), 6.0),
      (Offset(11, 64), 5.0),
    ];
    for (int i = 0; i < stars.length; i++) {
      final local = ((t - i * 0.1) / 0.6).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final k = math.sin(math.pi * local);
      final (c, r0) = stars[i];
      final r = r0 * k;
      final star = Path();
      for (int j = 0; j < 8; j++) {
        final a = j * math.pi / 4 + local * 0.8;
        final rr = j.isEven ? r : r * 0.28;
        final p = c + Offset(math.sin(a), -math.cos(a)) * rr;
        j == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
      }
      star.close();
      canvas.drawPath(star, _blur(_gold.withValues(alpha: 0.8 * k), 2.4));
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFF3CF));
      canvas.drawCircle(c, r * 0.18, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant ZeroHandPainter old) =>
      old.fingers != fingers ||
      old.trim != trim ||
      old.mirrored != mirrored ||
      old.dim != dim ||
      old.sparkle != sparkle;
}
