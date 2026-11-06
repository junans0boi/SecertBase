// 1–4월: 송학, 매조, 벚꽃, 흑싸리.

import 'dart:math' as math;
import 'dart:ui';

import '../hwatu_deck.dart';
import '../hwatu_kit.dart';

const _w = kHwatuUnitW;
const _h = kHwatuUnitH;

Color ribbonColor(HwatuRibbon kind) =>
    kind == HwatuRibbon.cheong ? HwatuInk.blue : HwatuInk.red;

/// 카드의 띠를 그린다(띠 카드가 아니면 아무것도 안 함).
void paintRibbonFor(
  Canvas canvas,
  HwatuCardSpec spec,
  Offset center,
  double angle, {
  double length = 64,
  double width = 15,
}) {
  final kind = spec.ribbon;
  if (kind == null) return;
  drawRibbon(
    canvas,
    center,
    angle,
    color: ribbonColor(kind),
    poem: kind != HwatuRibbon.cho,
    length: length,
    width: width,
  );
}

// ── 1월 송학 ───────────────────────────────────────────────────

/// 부채꼴 솔잎 덩이. [base]에서 위로 퍼진다.
void _pineTuft(
  Canvas canvas,
  Offset base,
  double r, {
  double from = -165,
  double to = -15,
  Color color = HwatuInk.pine,
  Color needle = HwatuInk.jade,
}) {
  final path = Path()..moveTo(base.dx, base.dy);
  final rim = <Offset>[];
  var i = 0;
  for (var a = from; a <= to + 0.01; a += 4.5) {
    final rr = i.isEven ? r : r * 0.86;
    final p = polar(base, rr, rad(a));
    rim.add(p);
    path.lineTo(p.dx, p.dy);
    i++;
  }
  path.close();
  canvas.drawPath(path, fillOf(color));
  final line = strokeOf(needle, math.max(0.45, r * 0.02));
  for (var k = 0; k < rim.length; k += 2) {
    final p = rim[k];
    canvas.drawLine(
      Offset.lerp(base, p, 0.28)!,
      Offset.lerp(base, p, 0.93)!,
      line,
    );
  }
  canvas.drawPath(path, strokeOf(HwatuInk.ink, 0.6));
}

void _pineGround(Canvas canvas) {
  _pineTuft(canvas, const Offset(14, 152), 34, from: -150, to: -20);
  _pineTuft(canvas, const Offset(84, 154), 38, from: -160, to: -30);
  _pineTuft(canvas, const Offset(50, 158), 30, from: -165, to: -15);
}

void _redCraneSun(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(
    c,
    r + 2.2,
    fillOf(HwatuInk.goldLight.withValues(alpha: 0.5)),
  );
  canvas.drawCircle(c, r, fillOf(HwatuInk.vermilion));
  canvas.drawCircle(c, r * 0.82, fillOf(HwatuInk.red.withValues(alpha: 0.35)));
}

/// 서 있는 두루미(오른쪽을 본다). [c]는 몸통 중심.
void _crane(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  final outline = strokeOf(HwatuInk.inkSoft, 0.9);
  final ink = fillOf(HwatuInk.ink);
  final white = fillOf(HwatuInk.white);
  // 다리
  final leg = strokeOf(HwatuInk.ink, 1.6);
  canvas.drawLine(const Offset(-1, 8), const Offset(-4, 38), leg);
  canvas.drawLine(const Offset(5, 8), const Offset(9, 38), leg);
  canvas.drawLine(const Offset(-4, 38), const Offset(-10, 40), leg);
  canvas.drawLine(const Offset(9, 38), const Offset(15, 40), leg);
  // 검은 꽁지깃
  for (final a in [150.0, 165.0, 180.0]) {
    canvas.drawPath(
      leafPath(const Offset(-10, 2), rad(a), 22, 8, bend: 0.3),
      ink,
    );
  }
  // 몸통
  final body = Path()
    ..moveTo(-16, 3)
    ..cubicTo(-14, -9, 4, -14, 16, -8)
    ..cubicTo(19, -2, 12, 10, 0, 11)
    ..cubicTo(-8, 11, -15, 9, -16, 3)
    ..close();
  canvas.drawPath(body, white);
  canvas.drawPath(body, outline);
  // 접은 날개
  final wing = leafPath(const Offset(14, -6), rad(172), 30, 13, bend: -0.35);
  canvas.drawPath(wing, white);
  canvas.drawPath(wing, outline);
  final feather = strokeOf(HwatuInk.inkSoft, 0.7);
  for (var i = 0; i < 4; i++) {
    final x = 4.0 - i * 5.5;
    canvas.drawLine(
      Offset(x, -6.5 + i * 0.4),
      Offset(x - 5, -1 + i * 0.6),
      feather,
    );
  }
  // 목: 흰 아래 목 + 검은 윗목
  final neck = [
    const Offset(12, -7),
    const Offset(18, -18),
    const Offset(15, -30),
    const Offset(20, -42),
  ];
  drawBranch(canvas, neck, 7.5, 5.5, HwatuInk.white);
  canvas.drawPath(branchPath(neck, 7.5, 5.5), outline);
  drawBranch(
    canvas,
    const [Offset(17.6, -24), Offset(15.6, -32), Offset(20, -42)],
    5.8,
    5,
    HwatuInk.ink,
  );
  // 머리
  canvas.drawCircle(const Offset(21, -44), 4.4, white);
  canvas.drawCircle(const Offset(21, -44), 4.4, outline);
  canvas.drawPath(
    Path()
      ..moveTo(18, -42)
      ..quadraticBezierTo(21, -40, 25, -42.5)
      ..lineTo(24, -40)
      ..quadraticBezierTo(20, -38.5, 17.5, -40.5)
      ..close(),
    ink,
  );
  canvas.drawCircle(const Offset(20.5, -47.2), 2.3, fillOf(HwatuInk.red));
  // 부리
  canvas.drawPath(
    Path()
      ..moveTo(24.5, -45.3)
      ..lineTo(36, -42.6)
      ..lineTo(24.8, -42.4)
      ..close(),
    fillOf(HwatuInk.goldDark),
  );
  canvas.drawCircle(const Offset(22.2, -44.6), 0.8, ink);
  canvas.restore();
}

void paintMonth1(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.bright:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w, _h),
        Paint()
          ..shader = Gradient.linear(const Offset(0, 0), const Offset(0, _h), [
            const Color(0xFFFBE7CF),
            HwatuInk.ivory,
          ]),
      );
      _redCraneSun(canvas, const Offset(64, 42), 25);
      _crane(canvas, const Offset(40, 96), 1.05);
      _pineGround(canvas);
    case HwatuType.ribbon:
      _pineTrunk(canvas);
      paintRibbonFor(canvas, spec, const Offset(62, 64), rad(14));
      _pineGround(canvas);
    case HwatuType.animal:
    case HwatuType.junk:
      _pineTrunk(canvas);
      _pineGround(canvas);
  }
}

void _pineTrunk(Canvas canvas) {
  drawBranch(
    canvas,
    const [Offset(30, 150), Offset(36, 112), Offset(58, 84), Offset(70, 52)],
    8,
    3.5,
    HwatuInk.brown,
  );
  drawBranch(
    canvas,
    const [Offset(44, 100), Offset(28, 86), Offset(22, 70)],
    3.6,
    2,
    HwatuInk.brown,
  );
  _pineTuft(canvas, const Offset(70, 56), 22, from: -175, to: -5);
  _pineTuft(canvas, const Offset(22, 74), 18, from: -170, to: -10);
  _pineTuft(canvas, const Offset(84, 92), 16, from: -160, to: -20);
}

// ── 2월 매조 ───────────────────────────────────────────────────

void _plumBranch(Canvas canvas, {bool withBird = false}) {
  final bark = HwatuInk.ink;
  drawBranch(
    canvas,
    const [
      Offset(10, 150),
      Offset(24, 122),
      Offset(46, 104),
      Offset(40, 78),
      Offset(66, 52),
      Offset(90, 40),
    ],
    7,
    2.4,
    bark,
  );
  drawBranch(
    canvas,
    const [Offset(44, 102), Offset(70, 98), Offset(88, 84)],
    3.6,
    1.6,
    bark,
  );
  drawBranch(
    canvas,
    const [Offset(42, 82), Offset(26, 64), Offset(30, 50)],
    3,
    1.4,
    bark,
  );
  final flowers = <(Offset, double, double)>[
    (const Offset(26, 120), 7.5, 0.2),
    (const Offset(50, 96), 8, 0.6),
    (const Offset(73, 97), 7, 0.1),
    (const Offset(88, 82), 6.5, 0.9),
    (const Offset(38, 76), 7, 0.4),
    (const Offset(28, 52), 6.5, 0.3),
    (const Offset(66, 52), 7.5, 0.8),
    (const Offset(88, 40), 6.5, 0.5),
  ];
  for (final (i, f) in flowers.indexed) {
    if (withBird && (i == 6)) continue;
    drawPlum(canvas, f.$1, f.$2, rotation: f.$3);
  }
  // 꽃봉오리
  final bud = fillOf(HwatuInk.red);
  final budEdge = strokeOf(HwatuInk.crimson, 0.6);
  for (final b in const [
    Offset(14, 136),
    Offset(60, 104),
    Offset(54, 64),
    Offset(78, 46),
    Offset(33, 60),
  ]) {
    canvas.drawCircle(b, 2.6, bud);
    canvas.drawCircle(b, 2.6, budEdge);
  }
}

/// 가지에 앉은 꾀꼬리(왼쪽을 본다).
void _warbler(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  const olive = Color(0xFF6E7D2A);
  const body = Color(0xFFD9C24A);
  final outline = strokeOf(HwatuInk.ink, 0.8);
  // 꼬리
  final tail = leafPath(const Offset(9, 3), rad(28), 18, 7);
  canvas.drawPath(tail, fillOf(olive));
  canvas.drawPath(tail, outline);
  // 몸
  final torso = Path()
    ..moveTo(-12, -4)
    ..cubicTo(-12, -14, 8, -14, 13, -2)
    ..cubicTo(14, 6, 2, 11, -6, 8)
    ..cubicTo(-11, 6, -12, 2, -12, -4)
    ..close();
  canvas.drawPath(torso, fillOf(body));
  canvas.drawPath(torso, outline);
  // 날개
  final wing = leafPath(const Offset(-4, -4), rad(12), 19, 9, bend: 0.25);
  canvas.drawPath(wing, fillOf(olive));
  canvas.drawPath(wing, outline);
  final f = strokeOf(HwatuInk.ink, 0.6);
  canvas.drawLine(const Offset(4, -3), const Offset(12, 0), f);
  canvas.drawLine(const Offset(2, 0), const Offset(10, 3), f);
  // 머리
  canvas.drawCircle(const Offset(-11, -9), 6.2, fillOf(body));
  canvas.drawCircle(const Offset(-11, -9), 6.2, outline);
  canvas.drawCircle(const Offset(-13, -10), 1.9, fillOf(HwatuInk.white));
  canvas.drawCircle(const Offset(-13.3, -10), 1.1, fillOf(HwatuInk.ink));
  canvas.drawPath(
    Path()
      ..moveTo(-16.5, -10.5)
      ..lineTo(-22, -8.2)
      ..lineTo(-16.2, -7.4)
      ..close(),
    fillOf(HwatuInk.ink),
  );
  // 발
  final foot = strokeOf(HwatuInk.ink, 1.1);
  canvas.drawLine(const Offset(-3, 8), const Offset(-4, 12.5), foot);
  canvas.drawLine(const Offset(2, 8), const Offset(2, 12.5), foot);
  canvas.restore();
}

void paintMonth2(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _plumBranch(canvas, withBird: true);
      _warbler(canvas, const Offset(60, 40), 1.45);
    case HwatuType.ribbon:
      _plumBranch(canvas);
      paintRibbonFor(canvas, spec, const Offset(62, 76), rad(-12));
    case HwatuType.bright:
    case HwatuType.junk:
      _plumBranch(canvas);
  }
}

// ── 3월 벚꽃 ───────────────────────────────────────────────────

void _cherryTree(Canvas canvas, {required double groundY}) {
  final bark = HwatuInk.ink;
  drawBranch(
    canvas,
    [
      Offset(92, groundY),
      Offset(78, groundY - 26),
      const Offset(60, 52),
      const Offset(30, 30),
    ],
    7,
    2.5,
    bark,
  );
  drawBranch(
    canvas,
    [Offset(74, groundY - 34), const Offset(50, 80), const Offset(24, 76)],
    3.4,
    1.6,
    bark,
  );
  drawBranch(
    canvas,
    const [Offset(62, 54), Offset(80, 30), Offset(88, 14)],
    3,
    1.4,
    bark,
  );
  final clusters = <Offset>[
    const Offset(30, 30),
    const Offset(86, 18),
    const Offset(58, 50),
    const Offset(26, 76),
    const Offset(52, 82),
    if (groundY > 120) const Offset(76, 104),
    if (groundY > 120) const Offset(42, 116),
  ];
  for (final (i, c) in clusters.indexed) {
    _blossomCluster(canvas, c, 1 + (i % 2) * 0.1, seed: i);
  }
}

void _blossomCluster(Canvas canvas, Offset c, double s, {int seed = 0}) {
  final offsets = <Offset>[
    const Offset(-7, -3),
    const Offset(6, -6),
    const Offset(1, 6),
    const Offset(-10, 8),
    const Offset(11, 5),
  ];
  for (var i = 0; i < offsets.length; i++) {
    final o = offsets[(i + seed) % offsets.length];
    final pink = (i + seed).isEven;
    drawCherry(
      canvas,
      c + o * s,
      6.6 * s,
      petal: pink ? HwatuInk.pink : HwatuInk.white,
      edge: pink ? HwatuInk.vermilion : HwatuInk.blush,
      rotation: 0.4 * i + seed,
    );
  }
}

void _curtain(Canvas canvas) {
  const top = 92.0;
  const rect = Rect.fromLTRB(0, top, _w, _h);
  canvas.drawRect(rect, fillOf(HwatuInk.red));
  // 주름
  final fold = fillOf(HwatuInk.crimson.withValues(alpha: 0.55));
  for (var x = 6.0; x < _w; x += 14) {
    canvas.drawRect(Rect.fromLTWH(x, top, 4, _h - top), fold);
  }
  // 금 띠 두 줄 + 벚꽃 문장
  for (final y in [top + 18, top + 40]) {
    canvas.drawRect(Rect.fromLTWH(0, y, _w, 7), fillOf(HwatuInk.gold));
    canvas.drawRect(
      Rect.fromLTWH(0, y + 1.2, _w, 4.6),
      fillOf(HwatuInk.crimsonDark),
    );
    for (var x = 8.0; x < _w; x += 14) {
      canvas.drawCircle(Offset(x, y + 3.5), 1.6, fillOf(HwatuInk.goldLight));
    }
  }
  for (final x in [26.0, 74.0]) {
    canvas.drawCircle(Offset(x, top + 30), 6.5, fillOf(HwatuInk.white));
    drawCherry(
      canvas,
      Offset(x, top + 30),
      5.6,
      petal: HwatuInk.white,
      edge: HwatuInk.crimson,
      heart: HwatuInk.red,
    );
  }
  // 위쪽 휘장(물결 드림)
  final valance = Path()..moveTo(0, top - 4);
  for (var x = 0.0; x < _w; x += 20) {
    valance.quadraticBezierTo(x + 10, top + 12, x + 20, top - 4);
  }
  valance
    ..lineTo(_w, top - 8)
    ..lineTo(0, top - 8)
    ..close();
  canvas.drawPath(valance, fillOf(HwatuInk.ink));
  canvas.drawPath(valance, strokeOf(HwatuInk.gold, 1.2));
  // 매듭 술
  for (var x = 0.0; x <= _w; x += 20) {
    canvas.drawLine(
      Offset(x, top - 4),
      Offset(x, top + 8),
      strokeOf(HwatuInk.gold, 1.4),
    );
    canvas.drawCircle(Offset(x, top + 9), 2, fillOf(HwatuInk.goldLight));
  }
}

void paintMonth3(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.bright:
      _cherryTree(canvas, groundY: 96);
      _curtain(canvas);
    case HwatuType.ribbon:
      _cherryTree(canvas, groundY: 150);
      paintRibbonFor(canvas, spec, const Offset(46, 100), rad(10));
    case HwatuType.animal:
    case HwatuType.junk:
      _cherryTree(canvas, groundY: 150);
      // 흩날리는 꽃잎
      final petal = fillOf(HwatuInk.pink);
      for (final p in const [
        Offset(20, 134),
        Offset(36, 146),
        Offset(58, 136),
        Offset(14, 106),
      ]) {
        canvas.drawPath(leafPath(p, rad(-30), 5, 3.2), petal);
      }
  }
}

// ── 4월 흑싸리 ─────────────────────────────────────────────────

void _wisteria(Canvas canvas, {double reach = 1}) {
  final stems = <List<Offset>>[
    [const Offset(8, -2), const Offset(16, 30), Offset(12, 70 * reach)],
    [const Offset(34, -2), const Offset(40, 40), Offset(34, 96 * reach)],
    [const Offset(64, -2), const Offset(60, 34), Offset(66, 80 * reach)],
    [const Offset(92, -2), const Offset(86, 44), Offset(90, 110 * reach)],
  ];
  for (final (i, stem) in stems.indexed) {
    drawBranch(canvas, stem, 3.2, 1.4, HwatuInk.ink);
    final pts = smoothPoints(stem);
    // 잎: 줄기를 따라 좌우로 엇갈린 먹빛 잎
    for (var k = 2; k < pts.length - 1; k += 2) {
      final p = pts[k];
      final side = (k ~/ 2).isEven ? 1 : -1;
      final dir = (pts[k + 1] - pts[k - 1]);
      final a = math.atan2(dir.dy, dir.dx) + side * rad(50);
      canvas.drawPath(
        leafPath(p, a, 12, 7, bend: side * 0.2),
        fillOf(HwatuInk.ink),
      );
    }
    // 끝의 꽃송이: 아래로 작아지는 점들
    final tip = pts.last;
    for (var j = 0; j < 7; j++) {
      final y = tip.dy + j * 3.6;
      final x = tip.dx + math.sin(j * 0.9 + i) * 1.6;
      final r = 3.6 - j * 0.36;
      canvas.drawCircle(
        Offset(x, y),
        r,
        fillOf(j.isEven ? HwatuInk.ink : HwatuInk.vermilion),
      );
    }
  }
}

/// 날아가는 두견새(왼쪽으로).
void _cuckoo(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  const grey = Color(0xFF4A4E5A);
  final outline = strokeOf(HwatuInk.ink, 0.8);
  // 뒷날개
  final back = Path()
    ..moveTo(-2, -2)
    ..cubicTo(4, -20, 18, -28, 30, -30)
    ..cubicTo(22, -20, 16, -10, 8, 0)
    ..close();
  canvas.drawPath(back, fillOf(HwatuInk.ink));
  // 꼬리
  final tail = Path()
    ..moveTo(10, 2)
    ..lineTo(34, 8)
    ..lineTo(32, 13)
    ..lineTo(9, 7)
    ..close();
  canvas.drawPath(tail, fillOf(grey));
  canvas.drawPath(tail, outline);
  // 몸
  final body = Path()
    ..moveTo(-18, -2)
    ..cubicTo(-10, -9, 6, -6, 14, 2)
    ..cubicTo(4, 9, -10, 8, -18, -2)
    ..close();
  canvas.drawPath(body, fillOf(HwatuInk.white));
  canvas.drawPath(body, outline);
  final bar = strokeOf(HwatuInk.inkSoft, 0.7);
  for (var x = -8.0; x < 10; x += 3.6) {
    canvas.drawLine(Offset(x, 1.5), Offset(x + 1.6, 5), bar);
  }
  // 앞날개
  final wing = Path()
    ..moveTo(-6, -3)
    ..cubicTo(-4, -22, 4, -34, 12, -40)
    ..cubicTo(14, -26, 10, -12, 6, -2)
    ..close();
  canvas.drawPath(wing, fillOf(grey));
  canvas.drawPath(wing, outline);
  final f = strokeOf(HwatuInk.white.withValues(alpha: 0.5), 0.7);
  canvas.drawLine(const Offset(-1, -8), const Offset(8, -32), f);
  canvas.drawLine(const Offset(3, -6), const Offset(10, -24), f);
  // 머리
  canvas.drawCircle(const Offset(-18, -4), 5.4, fillOf(grey));
  canvas.drawCircle(const Offset(-18, -4), 5.4, outline);
  canvas.drawCircle(const Offset(-19.5, -5), 1.6, fillOf(HwatuInk.goldLight));
  canvas.drawCircle(const Offset(-19.5, -5), 0.8, fillOf(HwatuInk.ink));
  canvas.drawPath(
    Path()
      ..moveTo(-22.6, -5.5)
      ..lineTo(-29, -3.4)
      ..lineTo(-22.4, -2.4)
      ..close(),
    fillOf(HwatuInk.gold),
  );
  canvas.restore();
}

void paintMonth4(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _wisteria(canvas, reach: 0.62);
      // 붉은 초승달
      final moon = Path()
        ..addOval(Rect.fromCircle(center: const Offset(80, 100), radius: 13))
        ..addOval(Rect.fromCircle(center: const Offset(86, 96), radius: 10.5))
        ..fillType = PathFillType.evenOdd;
      canvas.save();
      canvas.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(80, 100), radius: 13)),
      );
      canvas.drawPath(moon, fillOf(HwatuInk.vermilion));
      canvas.restore();
      _cuckoo(canvas, const Offset(46, 126), 1.2);
    case HwatuType.ribbon:
      _wisteria(canvas, reach: 1.05);
      paintRibbonFor(canvas, spec, const Offset(52, 100), rad(-8));
    case HwatuType.bright:
    case HwatuType.junk:
      _wisteria(canvas, reach: 1.15);
  }
}
