// 5–8월: 난초(창포), 모란, 홍싸리, 공산.

import 'dart:math' as math;
import 'dart:ui';

import '../hwatu_deck.dart';
import '../hwatu_kit.dart';
import 'hwatu_spring.dart' show paintRibbonFor;

const _w = kHwatuUnitW;
const _h = kHwatuUnitH;

// ── 5월 난초(창포) ─────────────────────────────────────────────

/// 창포 꽃: 아래로 처진 꽃잎 셋 + 선 꽃잎 셋.
void _iris(Canvas canvas, Offset c, double r) {
  final outline = strokeOf(HwatuInk.ink, 0.6);
  for (final a in [-120.0, -60.0, -90.0]) {
    final p = leafPath(c, rad(a), r * 0.85, r * 0.42);
    canvas.drawPath(p, fillOf(HwatuInk.lilac));
    canvas.drawPath(p, outline);
  }
  for (final a in [150.0, 30.0, 90.0]) {
    final p = leafPath(c, rad(a), r, r * 0.62, bend: a == 90 ? 0 : 0.2);
    canvas.drawPath(p, fillOf(HwatuInk.indigo));
    canvas.drawPath(p, outline);
    canvas.drawPath(
      leafPath(polar(c, r * 0.18, rad(a)), rad(a), r * 0.42, r * 0.18),
      fillOf(HwatuInk.goldLight),
    );
    canvas.drawLine(
      polar(c, r * 0.55, rad(a)),
      polar(c, r * 0.85, rad(a)),
      strokeOf(HwatuInk.white.withValues(alpha: 0.65), r * 0.05),
    );
  }
  canvas.drawCircle(c, r * 0.12, fillOf(HwatuInk.violet));
}

void _irisClump(Canvas canvas, Offset base, double s, {bool flowers = true}) {
  final blades = <(double, double, double)>[
    // (x 오프셋, 높이, 기울기)
    (-16, 70, -22),
    (-8, 92, -8),
    (0, 104, 6),
    (8, 86, 18),
    (16, 66, 28),
    (-22, 50, -30),
    (22, 54, 34),
  ];
  for (final (i, b) in blades.indexed) {
    final p = bladePath(
      base + Offset(b.$1 * s, 0),
      b.$2 * s,
      7 * s,
      b.$3 * s,
    );
    canvas.drawPath(p, fillOf(i.isEven ? HwatuInk.pine : HwatuInk.jade));
    canvas.drawPath(p, strokeOf(HwatuInk.ink, 0.5));
  }
  if (!flowers) return;
  final stalk = strokeOf(HwatuInk.pine, 2 * s);
  final heads = [
    base + Offset(-17 * s, -76 * s),
    base + Offset(18 * s, -62 * s),
    base + Offset(2 * s, -102 * s),
  ];
  for (final hd in heads) {
    canvas.drawLine(base + Offset((hd.dx - base.dx) * 0.4, -10 * s), hd, stalk);
  }
  for (final (i, hd) in heads.indexed) {
    _iris(canvas, hd, (i == 2 ? 13.5 : 15) * s);
  }
}

/// 물 위의 널다리(지그재그 판자).
void _plankBridge(Canvas canvas) {
  // 물결
  final water = strokeOf(HwatuInk.blueLight.withValues(alpha: 0.55), 1.2);
  for (var y = 112.0; y < _h; y += 8) {
    final p = Path()..moveTo(0, y);
    for (var x = 0.0; x < _w; x += 12) {
      p.quadraticBezierTo(x + 3, y - 2.5, x + 6, y);
      p.quadraticBezierTo(x + 9, y + 2.5, x + 12, y);
    }
    canvas.drawPath(p, water);
  }
  void plank(List<Offset> quad) {
    final p = Path()..addPolygon(quad, true);
    canvas.drawPath(p, fillOf(HwatuInk.ochre));
    final grain = strokeOf(HwatuInk.brown.withValues(alpha: 0.6), 0.7);
    for (var t = 0.25; t < 1; t += 0.25) {
      canvas.drawLine(
        Offset.lerp(quad[0], quad[3], t)!,
        Offset.lerp(quad[1], quad[2], t)!,
        grain,
      );
    }
    canvas.drawPath(p, strokeOf(HwatuInk.brown, 1));
  }

  // 기둥
  final post = fillOf(HwatuInk.brown);
  for (final x in [10.0, 46.0, 54.0, 90.0]) {
    canvas.drawRect(Rect.fromLTWH(x - 2, 118, 4, 22), post);
  }
  plank(const [Offset(-4, 104), Offset(52, 130), Offset(56, 120), Offset(0, 94)]);
  plank(const [Offset(46, 130), Offset(104, 104), Offset(104, 94), Offset(42, 120)]);
}

void paintMonth5(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _irisClump(canvas, const Offset(52, 118), 0.85);
      _plankBridge(canvas);
    case HwatuType.ribbon:
      _irisClump(canvas, const Offset(50, 150), 1);
      paintRibbonFor(canvas, spec, const Offset(66, 84), rad(14), length: 58);
    case HwatuType.bright:
    case HwatuType.junk:
      _irisClump(canvas, const Offset(50, 150), 1);
  }
}

// ── 6월 모란 ───────────────────────────────────────────────────

void _peonyLeaves(Canvas canvas, Offset c, double angle, double s) {
  final fill = fillOf(HwatuInk.pine);
  final vein = strokeOf(HwatuInk.leaf, 0.7);
  for (final da in [-38.0, 0.0, 38.0]) {
    final a = angle + rad(da);
    final len = (da == 0 ? 20 : 15) * s;
    final p = leafPath(c, a, len, len * 0.62);
    canvas.drawPath(p, fill);
    canvas.drawLine(c, polar(c, len * 0.85, a), vein);
  }
}

void _peonyPlant(Canvas canvas, {required Offset flower, double r = 22}) {
  final stem = strokeOf(HwatuInk.pine, 2.4);
  canvas.drawLine(flower + Offset(0, r * 0.6), const Offset(50, 152), stem);
  canvas.drawLine(const Offset(50, 136), const Offset(22, 118), stem);
  canvas.drawLine(const Offset(50, 128), const Offset(82, 112), stem);
  _peonyLeaves(canvas, const Offset(22, 120), rad(-150), 1.1);
  _peonyLeaves(canvas, const Offset(82, 114), rad(-30), 1.1);
  _peonyLeaves(canvas, const Offset(50, 138), rad(160), 1);
  _peonyLeaves(canvas, const Offset(50, 132), rad(20), 1);
  _peonyLeaves(canvas, flower + Offset(-r * 0.8, r * 0.6), rad(-170), 0.9);
  _peonyLeaves(canvas, flower + Offset(r * 0.8, r * 0.6), rad(-10), 0.9);
  drawPeony(canvas, flower, r);
  // 꽃봉오리
  final bud = flower + Offset(r * 1.15, -r * 0.9);
  canvas.drawLine(flower + Offset(r * 0.6, -r * 0.2), bud, stem);
  canvas.drawCircle(bud, 5.5, fillOf(HwatuInk.red));
  canvas.drawPath(leafPath(bud + const Offset(0, 4), rad(-60), 8, 5), fillOf(HwatuInk.pine));
  canvas.drawPath(leafPath(bud + const Offset(0, 4), rad(-120), 8, 5), fillOf(HwatuInk.pine));
}

void _butterfly(Canvas canvas, Offset c, double s, double tilt) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(tilt);
  canvas.scale(s);
  final outline = strokeOf(HwatuInk.ink, 0.9);
  for (final side in [-1.0, 1.0]) {
    final fore = Path()
      ..moveTo(0, -2)
      ..cubicTo(side * 6, -16, side * 20, -18, side * 22, -10)
      ..cubicTo(side * 22, -2, side * 10, 2, 0, 1)
      ..close();
    canvas.drawPath(fore, fillOf(HwatuInk.goldLight));
    canvas.drawPath(fore, outline);
    canvas.drawCircle(Offset(side * 15, -10), 3, fillOf(HwatuInk.vermilion));
    canvas.drawCircle(Offset(side * 15, -10), 1.2, fillOf(HwatuInk.ink));
    final edge = Path()
      ..moveTo(side * 18, -16)
      ..cubicTo(side * 21, -15, side * 23, -12, side * 22, -9)
      ..lineTo(side * 19, -10)
      ..close();
    canvas.drawPath(edge, fillOf(HwatuInk.ink));
    final hind = Path()
      ..moveTo(0, 1)
      ..cubicTo(side * 12, 2, side * 16, 10, side * 10, 15)
      ..cubicTo(side * 6, 17, side * 2, 10, 0, 3)
      ..close();
    canvas.drawPath(hind, fillOf(HwatuInk.vermilion));
    canvas.drawPath(hind, outline);
    canvas.drawCircle(Offset(side * 9, 9), 1.6, fillOf(HwatuInk.goldLight));
  }
  canvas.drawPath(
    leafPath(const Offset(0, -6), rad(90), 18, 3.4),
    fillOf(HwatuInk.ink),
  );
  final ant = strokeOf(HwatuInk.ink, 0.8);
  canvas.drawLine(const Offset(0, -5), const Offset(-5, -14), ant);
  canvas.drawLine(const Offset(0, -5), const Offset(5, -14), ant);
  canvas.drawCircle(const Offset(-5, -14), 1, fillOf(HwatuInk.ink));
  canvas.drawCircle(const Offset(5, -14), 1, fillOf(HwatuInk.ink));
  canvas.restore();
}

void paintMonth6(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _peonyPlant(canvas, flower: const Offset(50, 98), r: 20);
      _butterfly(canvas, const Offset(66, 34), 1.15, rad(14));
      _butterfly(canvas, const Offset(34, 62), 0.85, rad(-18));
    case HwatuType.ribbon:
      _peonyPlant(canvas, flower: const Offset(46, 94), r: 21);
      paintRibbonFor(canvas, spec, const Offset(70, 52), rad(12), length: 60);
    case HwatuType.bright:
    case HwatuType.junk:
      _peonyPlant(canvas, flower: const Offset(50, 74), r: 24);
  }
}

// ── 7월 홍싸리 ─────────────────────────────────────────────────

void _bushClover(Canvas canvas, {double height = 1, bool dense = true}) {
  final stems = <List<Offset>>[
    [const Offset(76, 152), Offset(70, 150 - 60 * height), Offset(30, 150 - 108 * height), Offset(8, 150 - 116 * height)],
    [const Offset(80, 152), Offset(86, 150 - 50 * height), Offset(78, 150 - 98 * height), Offset(58, 150 - 128 * height)],
    [const Offset(70, 152), Offset(52, 150 - 40 * height), Offset(18, 150 - 60 * height), Offset(4, 150 - 56 * height)],
    if (dense) [const Offset(84, 152), Offset(96, 150 - 70 * height), Offset(98, 150 - 96 * height)],
  ];
  for (final (i, stem) in stems.indexed) {
    drawBranch(canvas, stem, 2.4, 1, HwatuInk.crimson);
    final pts = smoothPoints(stem);
    for (var k = 4; k < pts.length - 1; k += 3) {
      final dir = pts[k + 1] - pts[k - 1];
      final a = math.atan2(dir.dy, dir.dx);
      final side = (k ~/ 3).isEven ? 1.0 : -1.0;
      final base = pts[k];
      // 세 잎
      final leafA = a + side * rad(70);
      for (final d in [-0.5, 0.0, 0.5]) {
        canvas.drawPath(
          leafPath(base, leafA + d, d == 0 ? 6.5 : 5, 3.2),
          fillOf(d == 0 ? HwatuInk.ink : HwatuInk.inkSoft),
        );
      }
      // 꽃(작은 붉은 콩꽃)
      final fa = a - side * rad(60);
      final f = polar(base, 3.2, fa);
      canvas.drawPath(leafPath(f, fa, 5.5, 3.6), fillOf(HwatuInk.red));
      canvas.drawPath(
        leafPath(polar(f, 1.2, fa), fa + 0.5, 4, 2.6),
        fillOf(HwatuInk.vermilion),
      );
    }
    // 끝의 꽃 봉우리
    final tip = pts.last;
    canvas.drawCircle(tip, 2.3, fillOf(HwatuInk.red));
    if (i == 0) canvas.drawCircle(tip + const Offset(-3, 2), 1.6, fillOf(HwatuInk.vermilion));
  }
}

/// 달리는 멧돼지(왼쪽으로).
void _boar(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  const hide = Color(0xFF3B2A22);
  const belly = Color(0xFF7A5A3E);
  final outline = strokeOf(HwatuInk.ink, 0.9);
  // 다리(뒤쪽 먼저)
  final legFar = fillOf(HwatuInk.ink);
  canvas.drawPath(leafPath(const Offset(14, 6), rad(60), 16, 6), legFar);
  canvas.drawPath(leafPath(const Offset(-12, 6), rad(140), 16, 6), legFar);
  // 몸통
  final body = Path()
    ..moveTo(-24, -2)
    ..cubicTo(-22, -16, 0, -22, 18, -16)
    ..cubicTo(30, -12, 32, 4, 24, 10)
    ..cubicTo(12, 15, -10, 14, -20, 8)
    ..close();
  canvas.drawPath(body, fillOf(hide));
  canvas.drawPath(
    Path()
      ..moveTo(-18, 6)
      ..cubicTo(-6, 12, 10, 12, 22, 8)
      ..cubicTo(10, 6, -6, 4, -18, 6)
      ..close(),
    fillOf(belly),
  );
  canvas.drawPath(body, outline);
  // 등 갈기
  final bristle = strokeOf(HwatuInk.ink, 1.2);
  for (var x = -16.0; x < 22; x += 4) {
    final y = -16 - 4 * math.sin((x + 16) / 38 * math.pi);
    canvas.drawLine(Offset(x, y + 3), Offset(x + 2.5, y - 2.5), bristle);
  }
  final shine = strokeOf(HwatuInk.goldLight.withValues(alpha: 0.6), 0.8);
  canvas.drawArc(
    const Rect.fromLTWH(-10, -14, 26, 14),
    rad(200),
    rad(120),
    false,
    shine,
  );
  // 앞다리
  final leg = fillOf(hide);
  canvas.drawPath(leafPath(const Offset(-14, 4), rad(115), 18, 7), leg);
  canvas.drawPath(leafPath(const Offset(18, 4), rad(40), 18, 7), leg);
  // 머리
  final head = Path()
    ..moveTo(-20, -12)
    ..cubicTo(-28, -12, -38, -4, -42, 2)
    ..lineTo(-40, 8)
    ..cubicTo(-32, 8, -24, 6, -18, 4)
    ..close();
  canvas.drawPath(head, fillOf(hide));
  canvas.drawPath(head, outline);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(-41.5, 5), width: 4, height: 7),
    fillOf(belly),
  );
  // 엄니
  canvas.drawPath(
    Path()
      ..moveTo(-36, 6)
      ..quadraticBezierTo(-37, 0, -33, -2)
      ..quadraticBezierTo(-34, 2, -33, 6)
      ..close(),
    fillOf(HwatuInk.white),
  );
  // 귀, 눈
  canvas.drawPath(
    Path()
      ..moveTo(-22, -12)
      ..lineTo(-20, -20)
      ..lineTo(-16, -12)
      ..close(),
    fillOf(HwatuInk.ink),
  );
  canvas.drawCircle(const Offset(-29, -5), 1.6, fillOf(HwatuInk.goldLight));
  canvas.drawCircle(const Offset(-29, -5), 0.8, fillOf(HwatuInk.ink));
  // 꼬리
  canvas.drawPath(
    Path()
      ..moveTo(28, -6)
      ..quadraticBezierTo(36, -10, 33, -2)
      ..quadraticBezierTo(31, 2, 35, 1),
    strokeOf(HwatuInk.ink, 1.2),
  );
  canvas.restore();
}

void paintMonth7(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _bushClover(canvas, height: 0.85, dense: false);
      _boar(canvas, const Offset(57, 108), 1.12);
    case HwatuType.ribbon:
      _bushClover(canvas);
      paintRibbonFor(canvas, spec, const Offset(50, 78), rad(-10), length: 60);
    case HwatuType.bright:
    case HwatuType.junk:
      _bushClover(canvas);
  }
}

// ── 8월 공산 ───────────────────────────────────────────────────

void _hill(Canvas canvas, {required double top, Color color = HwatuInk.ink}) {
  final hill = Path()
    ..moveTo(-2, top + 12)
    ..cubicTo(20, top - 8, 70, top - 10, 104, top + 6)
    ..lineTo(104, _h + 2)
    ..lineTo(-2, _h + 2)
    ..close();
  canvas.drawPath(hill, fillOf(color));
  // 억새 잎결
  final blade = strokeOf(const Color(0xFF6E6A63), 0.8);
  final rnd = math.Random(8);
  for (var i = 0; i < 26; i++) {
    final x = 4 + i * 3.6 + rnd.nextDouble() * 2;
    final y0 = top + 18 + rnd.nextDouble() * 50;
    final p = Path()
      ..moveTo(x, y0 + 20)
      ..quadraticBezierTo(x + 2, y0 + 6, x + 6 + rnd.nextDouble() * 4, y0);
    canvas.drawPath(p, blade);
  }
  // 능선 위 억새 이삭
  final plume = strokeOf(HwatuInk.ivoryDeep, 1.1);
  final plumeFill = fillOf(HwatuInk.ivoryDeep);
  for (final x in [10.0, 24.0, 40.0, 58.0, 74.0, 90.0]) {
    final yTop = top - 1 + (x - 50).abs() * 0.05;
    final base = Offset(x, yTop + 8);
    final tip = Offset(x + 5, yTop - 7);
    canvas.drawLine(base, tip, plume);
    canvas.drawPath(leafPath(tip, rad(-60), 7, 3), plumeFill);
  }
}

/// 능선 위로 솟은 억새 줄기와 이삭(피 카드).
void _pampasStalks(Canvas canvas, {required double top}) {
  final stalk = strokeOf(HwatuInk.inkSoft, 1.1);
  final feather = strokeOf(HwatuInk.inkSoft, 0.9);
  for (final (x, height, lean) in const [
    (16.0, 46.0, 10.0),
    (34.0, 62.0, 14.0),
    (54.0, 50.0, 18.0),
    (72.0, 70.0, 12.0),
    (88.0, 40.0, 8.0),
  ]) {
    final base = Offset(x, top + 10);
    final tip = Offset(x + lean, top - height);
    final ctrl = Offset(x + lean * 0.1, top - height * 0.5);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
      stalk,
    );
    // 이삭: 끝에서 아래로 늘어진 깃털 획
    for (var i = 0; i < 6; i++) {
      final t = i / 6;
      final p = Offset.lerp(tip, ctrl, t * 0.5)!;
      final len = 10 - i * 0.9;
      canvas.drawLine(p, p + Offset(len * 0.9, len * 0.5), feather);
      canvas.drawLine(p, p + Offset(-len * 0.3, len * 0.7), feather);
    }
  }
}

void _geese(Canvas canvas) {
  for (final (c, s) in const [
    (Offset(66, 32), 1.0),
    (Offset(44, 50), 0.9),
    (Offset(80, 60), 0.8),
  ]) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(s);
    // 날개
    final wing = Path()
      ..moveTo(-2, 0)
      ..cubicTo(-10, -10, -22, -14, -30, -12)
      ..cubicTo(-20, -6, -12, 0, -6, 4)
      ..close();
    final wing2 = Path()
      ..moveTo(2, 0)
      ..cubicTo(6, -12, 14, -20, 22, -22)
      ..cubicTo(18, -12, 12, -2, 6, 4)
      ..close();
    canvas.drawPath(wing2, fillOf(HwatuInk.inkSoft));
    // 몸
    final body = Path()
      ..moveTo(-16, 4)
      ..cubicTo(-6, -2, 10, -2, 16, 4)
      ..cubicTo(8, 9, -8, 9, -16, 4)
      ..close();
    canvas.drawPath(body, fillOf(HwatuInk.ink));
    canvas.drawPath(wing, fillOf(HwatuInk.ink));
    canvas.drawLine(
      const Offset(-14, 4),
      const Offset(-24, 1),
      strokeOf(HwatuInk.ink, 2.4),
    );
    canvas.drawCircle(const Offset(-25, 1), 2.6, fillOf(HwatuInk.ink));
    canvas.drawCircle(const Offset(-25.4, 2.2), 1, fillOf(HwatuInk.white));
    canvas.drawPath(
      Path()
        ..moveTo(-27, 0)
        ..lineTo(-31, 1.6)
        ..lineTo(-27, 2.4)
        ..close(),
      fillOf(HwatuInk.goldDark),
    );
    canvas.restore();
  }
}

void paintMonth8(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.bright:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w, _h),
        Paint()
          ..shader = Gradient.linear(const Offset(0, 0), const Offset(0, 100), [
            HwatuInk.crimson,
            HwatuInk.vermilion,
          ]),
      );
      const moon = Offset(52, 58);
      canvas.drawCircle(moon, 31, fillOf(HwatuInk.goldLight.withValues(alpha: 0.35)));
      canvas.drawCircle(moon, 27, fillOf(HwatuInk.ivory));
      canvas.drawCircle(moon + const Offset(7, 6), 6, fillOf(HwatuInk.ivoryDeep));
      canvas.drawCircle(moon + const Offset(-9, -8), 3.5, fillOf(HwatuInk.ivoryDeep));
      _hill(canvas, top: 92);
    case HwatuType.animal:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w, 100),
        Paint()
          ..shader = Gradient.linear(const Offset(0, 0), const Offset(0, 100), [
            const Color(0xFFF6D9B8),
            HwatuInk.ivory,
          ]),
      );
      _geese(canvas);
      _hill(canvas, top: 96);
    case HwatuType.ribbon:
    case HwatuType.junk:
      _pampasStalks(canvas, top: 84);
      _hill(canvas, top: 84);
  }
}
