// 9–12월: 국화, 단풍, 오동, 비.

import 'dart:math' as math;
import 'dart:ui';

import '../hwatu_deck.dart';
import '../hwatu_kit.dart';
import 'hwatu_spring.dart' show paintRibbonFor;

const _w = kHwatuUnitW;
const _h = kHwatuUnitH;

// ── 9월 국화 ───────────────────────────────────────────────────

void _mumPlant(Canvas canvas, List<(Offset, double)> flowers) {
  final stem = strokeOf(HwatuInk.pine, 2.2);
  for (final (c, _) in flowers) {
    final base = Offset(48 + (c.dx - 50) * 0.3, 152);
    final mid = Offset((c.dx + base.dx) / 2 + 4, (c.dy + base.dy) / 2);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, c.dx, c.dy),
      stem,
    );
    // 줄기 잎
    for (final t in [0.35, 0.62]) {
      final p = Offset.lerp(base, c, t)!;
      final side = t < 0.5 ? -1 : 1;
      _mumLeaf(canvas, p + Offset(side * 7.0, -2), 7.5, side * rad(70));
    }
  }
  for (final (c, r) in flowers) {
    drawMum(canvas, c, r);
  }
}

/// 둥근 세 갈래 국화 잎.
void _mumLeaf(Canvas canvas, Offset c, double r, double rotation) {
  final leaf = polarPath(
    c,
    (t) => r * (0.6 + 0.4 * math.cos(1.5 * t).abs()),
    rotation: rotation - math.pi / 2,
  );
  canvas.drawPath(leaf, fillOf(HwatuInk.jade));
  canvas.drawPath(leaf, strokeOf(HwatuInk.pine, 0.8));
  canvas.drawLine(
    c,
    polar(c, r * 0.8, rotation - math.pi / 2),
    strokeOf(HwatuInk.pine, 0.7),
  );
}

/// 붉은 옻칠 술잔(받침 포함). 글씨 대신 금빛 문양.
void _sakeCup(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  // 받침
  final foot = Path()
    ..moveTo(-9, 10)
    ..lineTo(9, 10)
    ..lineTo(13, 18)
    ..lineTo(-13, 18)
    ..close();
  canvas.drawPath(foot, fillOf(HwatuInk.crimson));
  canvas.drawPath(foot, strokeOf(HwatuInk.gold, 0.9));
  // 잔 몸
  final bowl = Path()
    ..moveTo(-26, -6)
    ..cubicTo(-24, 8, -10, 13, 0, 13)
    ..cubicTo(10, 13, 24, 8, 26, -6)
    ..close();
  canvas.drawPath(bowl, fillOf(HwatuInk.red));
  canvas.drawPath(bowl, strokeOf(HwatuInk.crimsonDark, 0.9));
  // 잔 안쪽(위에서 본 타원)
  final rim = Rect.fromCenter(
    center: const Offset(0, -6),
    width: 52,
    height: 14,
  );
  canvas.drawOval(rim, fillOf(HwatuInk.vermilion));
  canvas.drawOval(rim, strokeOf(HwatuInk.goldLight, 1.4));
  canvas.drawOval(rim.deflate(4), fillOf(HwatuInk.red));
  // 금빛 문양(壽 대신 둥근 꽃 문장)
  canvas.drawCircle(const Offset(0, 4), 5.5, fillOf(HwatuInk.gold));
  for (var i = 0; i < 8; i++) {
    canvas.drawCircle(
      polar(const Offset(0, 4), 4.4, i * math.pi / 4),
      1.6,
      fillOf(HwatuInk.gold),
    );
  }
  canvas.drawCircle(const Offset(0, 4), 2.4, fillOf(HwatuInk.red));
  canvas.drawCircle(const Offset(0, 4), 1, fillOf(HwatuInk.goldLight));
  // 하이라이트
  canvas.drawArc(
    const Rect.fromLTWH(-22, -6, 18, 16),
    rad(110),
    rad(60),
    false,
    strokeOf(HwatuInk.white.withValues(alpha: 0.55), 1.4),
  );
  canvas.restore();
}

void paintMonth9(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _mumPlant(canvas, const [
        (Offset(30, 46), 14),
        (Offset(70, 36), 13),
        (Offset(52, 70), 15),
      ]);
      _sakeCup(canvas, const Offset(50, 118), 1.25);
    case HwatuType.ribbon:
      _mumPlant(canvas, const [
        (Offset(30, 52), 14),
        (Offset(72, 40), 13),
        (Offset(56, 98), 16),
      ]);
      paintRibbonFor(canvas, spec, const Offset(46, 82), rad(-10), length: 58);
    case HwatuType.bright:
    case HwatuType.junk:
      _mumPlant(canvas, const [
        (Offset(34, 52), 16),
        (Offset(70, 70), 15),
        (Offset(44, 100), 17),
      ]);
  }
}

// ── 10월 단풍 ──────────────────────────────────────────────────

void _mapleBranches(
  Canvas canvas,
  List<(Offset, double, double, Color)> leaves,
) {
  final bark = HwatuInk.ink;
  drawBranch(
    canvas,
    const [Offset(104, 10), Offset(70, 30), Offset(40, 36), Offset(10, 60)],
    4,
    1.6,
    bark,
  );
  drawBranch(
    canvas,
    const [Offset(62, 32), Offset(56, 56), Offset(70, 80)],
    2.4,
    1.2,
    bark,
  );
  for (final (c, r, rot, color) in leaves) {
    final p = maplePath(c, r, rotation: rot);
    canvas.drawPath(p, fillOf(color));
    canvas.drawPath(
      p,
      strokeOf(HwatuInk.crimsonDark.withValues(alpha: 0.7), 0.6),
    );
    final vein = strokeOf(HwatuInk.crimsonDark.withValues(alpha: 0.45), 0.5);
    for (final a in [-72.0, -36.0, 0.0, 36.0, 72.0]) {
      canvas.drawLine(c, polar(c, r * 0.7, rot - math.pi / 2 + rad(a)), vein);
    }
  }
}

const _mapleTop = <(Offset, double, double, Color)>[
  (Offset(14, 62), 11, 0.4, HwatuInk.red),
  (Offset(34, 40), 12, -0.3, HwatuInk.vermilion),
  (Offset(56, 22), 11, 0.2, HwatuInk.gold),
  (Offset(80, 30), 12, -0.2, HwatuInk.red),
  (Offset(70, 82), 11, 0.5, HwatuInk.vermilion),
  (Offset(52, 58), 9, -0.5, HwatuInk.crimson),
  (Offset(94, 12), 9, 0.3, HwatuInk.vermilion),
];

const _mapleFull = <(Offset, double, double, Color)>[
  ..._mapleTop,
  (Offset(26, 98), 13, -0.4, HwatuInk.red),
  (Offset(66, 112), 14, 0.3, HwatuInk.vermilion),
  (Offset(36, 134), 12, 0.6, HwatuInk.gold),
  (Offset(80, 140), 11, -0.3, HwatuInk.crimson),
];

/// 서 있는 사슴(왼쪽을 본다).
void _deer(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  const coat = HwatuInk.ochre;
  const shade = Color(0xFF9C6428);
  final outline = strokeOf(HwatuInk.brown, 0.9);
  final legPaint = strokeOf(shade, 3);
  final hoof = strokeOf(HwatuInk.ink, 3);
  // 뒤쪽 다리
  for (final l in const [
    (Offset(-12, 6), Offset(-16, 34)),
    (Offset(14, 6), Offset(20, 34)),
  ]) {
    canvas.drawLine(l.$1, l.$2, legPaint);
    canvas.drawLine(l.$2, l.$2 + const Offset(0, 2), hoof);
  }
  // 몸
  final body = Path()
    ..moveTo(-20, -2)
    ..cubicTo(-18, -12, 12, -14, 22, -6)
    ..cubicTo(26, 0, 22, 10, 14, 10)
    ..cubicTo(2, 12, -14, 12, -18, 6)
    ..close();
  canvas.drawPath(body, fillOf(coat));
  canvas.drawPath(body, outline);
  // 흰 점
  final spot = fillOf(HwatuInk.ivory);
  for (final p in const [
    Offset(-8, -6),
    Offset(0, -8),
    Offset(8, -7),
    Offset(15, -4),
    Offset(-4, -2),
    Offset(4, -3),
    Offset(11, 0),
  ]) {
    canvas.drawCircle(p, 1.4, spot);
  }
  // 꼬리
  canvas.drawPath(
    leafPath(const Offset(22, -6), rad(-30), 6, 4),
    fillOf(HwatuInk.white),
  );
  // 앞쪽 다리
  final legNear = strokeOf(coat, 3.4);
  for (final l in const [
    (Offset(-14, 6), Offset(-10, 35)),
    (Offset(16, 6), Offset(12, 35)),
  ]) {
    canvas.drawLine(l.$1, l.$2, legNear);
    canvas.drawLine(l.$2, l.$2 + const Offset(0, 2), hoof);
  }
  // 목
  drawBranch(
    canvas,
    const [Offset(-14, -2), Offset(-18, -14), Offset(-20, -26)],
    10,
    6.5,
    coat,
  );
  // 머리
  final head = Path()
    ..moveTo(-16, -30)
    ..cubicTo(-18, -36, -26, -36, -30, -32)
    ..lineTo(-36, -26)
    ..cubicTo(-34, -23, -28, -23, -22, -24)
    ..close();
  canvas.drawPath(head, fillOf(coat));
  canvas.drawPath(head, outline);
  canvas.drawCircle(const Offset(-35.5, -26), 1.4, fillOf(HwatuInk.ink));
  canvas.drawCircle(const Offset(-25, -30.5), 1.3, fillOf(HwatuInk.ink));
  canvas.drawPath(
    leafPath(const Offset(-19, -32), rad(-30), 8, 4),
    fillOf(shade),
  );
  // 뿔
  final antler = strokeOf(HwatuInk.brown, 1.6);
  canvas.drawPath(
    Path()
      ..moveTo(-22, -34)
      ..quadraticBezierTo(-24, -44, -18, -52)
      ..moveTo(-23, -42)
      ..lineTo(-30, -48)
      ..moveTo(-20, -48)
      ..lineTo(-14, -52)
      ..moveTo(-19, -35)
      ..quadraticBezierTo(-14, -42, -10, -46)
      ..moveTo(-15, -40)
      ..lineTo(-9, -39),
    antler,
  );
  canvas.restore();
}

void paintMonth10(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.animal:
      _mapleBranches(canvas, _mapleTop);
      _deer(canvas, const Offset(56, 110), 1.2);
    case HwatuType.ribbon:
      _mapleBranches(canvas, _mapleFull);
      paintRibbonFor(canvas, spec, const Offset(52, 92), rad(8), length: 60);
    case HwatuType.bright:
    case HwatuType.junk:
      _mapleBranches(canvas, _mapleFull);
  }
}

// ── 11월 오동 ──────────────────────────────────────────────────

Path _paulowniaLeaf(Offset base, double angle, double r) {
  // 넓은 하트 모양 잎: base는 잎자루 쪽, angle 방향으로 펼쳐진다.
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx);
  Offset p(double a, double b) => base + d * (a * r) + n * (b * r);
  // 넓은 잎몸 + 양옆 얕은 갈래 + 뾰족한 끝
  final path = Path()..moveTo(base.dx, base.dy);
  void cubic(Offset c1, Offset c2, Offset e) =>
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
  cubic(p(-0.35, 0.7), p(0.25, 1.35), p(0.95, 1.1));
  cubic(p(1.25, 1.0), p(1.55, 0.6), p(1.95, 0));
  cubic(p(1.55, -0.6), p(1.25, -1.0), p(0.95, -1.1));
  cubic(p(0.25, -1.35), p(-0.35, -0.7), base);
  return path..close();
}

void _paulowniaLeaves(
  Canvas canvas, {
  required Color leaf,
  Color light = const Color(0xFF3E3735),
  Color vein = const Color(0xFF7A716B),
  Color edge = HwatuInk.ivory,
}) {
  final leaves = <(Offset, double, double)>[
    (const Offset(45, 136), rad(160), 21),
    (const Offset(55, 136), rad(20), 21),
    (const Offset(44, 128), rad(-148), 22),
    (const Offset(56, 128), rad(-32), 22),
    (const Offset(50, 124), rad(-90), 19),
  ];
  final stem = strokeOf(HwatuInk.ink, 2.6);
  for (final (b, _, _) in leaves) {
    canvas.drawLine(const Offset(50, 152), b, stem);
  }
  for (final (b, a, r) in leaves) {
    final p = _paulowniaLeaf(b, a, r);
    canvas.drawPath(p, fillOf(leaf));
    // 평면 일러스트식 두 톤: 잎맥 한쪽을 밝게.
    canvas.save();
    canvas.clipPath(p);
    final d = Offset(math.cos(a), math.sin(a));
    final n = Offset(-d.dy, d.dx);
    final far = d * (r * 3);
    canvas.drawPath(
      Path()
        ..moveTo(b.dx - far.dx, b.dy - far.dy)
        ..lineTo(b.dx + far.dx, b.dy + far.dy)
        ..lineTo(b.dx + far.dx + n.dx * r * 3, b.dy + far.dy + n.dy * r * 3)
        ..lineTo(b.dx - far.dx + n.dx * r * 3, b.dy - far.dy + n.dy * r * 3)
        ..close(),
      fillOf(light),
    );
    canvas.restore();
    canvas.drawPath(p, strokeOf(edge, 1.2));
    final v = strokeOf(vein, 0.8);
    canvas.drawLine(b, polar(b, r * 1.8, a), v);
    for (final t in [0.5, 0.9, 1.3]) {
      final m = polar(b, r * t, a);
      canvas.drawLine(m, polar(m, r * (0.62 - t * 0.2), a - 0.8), v);
      canvas.drawLine(m, polar(m, r * (0.62 - t * 0.2), a + 0.8), v);
    }
  }
}

void _paulowniaFlowers(
  Canvas canvas,
  Offset base,
  double height, {
  Color bloom = HwatuInk.lilac,
  Color edge = HwatuInk.violet,
}) {
  final top = base - Offset(0, height);
  canvas.drawLine(base, top, strokeOf(HwatuInk.ink, 2.4));
  const tiers = 6;
  for (var i = 0; i < tiers; i++) {
    final t = i / (tiers - 1);
    final y = base.dy - height * (0.22 + 0.72 * t);
    final spread = 14 * (1 - t) + 4;
    for (final side in [-1.0, 1.0]) {
      final c = Offset(base.dx + side * spread, y);
      canvas.drawLine(Offset(base.dx, y + 3), c, strokeOf(HwatuInk.ink, 1));
      final bell = leafPath(c, rad(90 + side * 25), 9, 8);
      canvas.drawPath(bell, fillOf(bloom));
      canvas.drawPath(bell, strokeOf(edge, 0.8));
      canvas.drawCircle(
        c + const Offset(0, 1.5),
        1.5,
        fillOf(HwatuInk.goldLight),
      );
    }
  }
  final crown = leafPath(top + const Offset(0, 6), rad(-90), 10, 8);
  canvas.drawPath(crown, fillOf(bloom));
  canvas.drawPath(crown, strokeOf(edge, 0.8));
}

/// 봉황: 머리·목·날개·긴 꼬리깃.
void _phoenix(Canvas canvas) {
  // 꼬리깃(세 가닥)
  final plumes = <(List<Offset>, Color)>[
    (
      const [Offset(52, 58), Offset(78, 74), Offset(70, 104), Offset(92, 122)],
      HwatuInk.vermilion,
    ),
    (
      const [Offset(50, 62), Offset(64, 86), Offset(50, 112), Offset(64, 134)],
      HwatuInk.gold,
    ),
    (const [Offset(56, 54), Offset(90, 58), Offset(96, 84)], HwatuInk.jade),
  ];
  for (final (pts, color) in plumes) {
    drawBranch(canvas, pts, 7, 2, color);
    canvas.drawPath(branchPath(pts, 7, 2), strokeOf(HwatuInk.ink, 0.6));
    final end = smoothPoints(pts).last;
    canvas.drawCircle(end, 4.2, fillOf(HwatuInk.indigo));
    canvas.drawCircle(end, 4.2, strokeOf(HwatuInk.goldLight, 1));
    canvas.drawCircle(end, 1.6, fillOf(HwatuInk.goldLight));
  }
  // 날개: 깃털 부채
  final wingBase = const Offset(50, 54);
  final colors = [
    HwatuInk.jade,
    HwatuInk.gold,
    HwatuInk.vermilion,
    HwatuInk.indigo,
  ];
  for (var i = 0; i < 7; i++) {
    final a = rad(-80 + i * 14.0);
    final p = leafPath(wingBase, a, 32 - i * 1.8, 9);
    canvas.drawPath(p, fillOf(colors[i % colors.length]));
    canvas.drawPath(p, strokeOf(HwatuInk.ink, 0.6));
  }
  for (var i = 0; i < 6; i++) {
    final a = rad(-74 + i * 14.0);
    final p = leafPath(wingBase, a, 18, 7);
    canvas.drawPath(p, fillOf(HwatuInk.goldLight));
    canvas.drawPath(p, strokeOf(HwatuInk.goldDark, 0.6));
  }
  // 목
  final neck = [
    const Offset(50, 60),
    const Offset(40, 46),
    const Offset(42, 30),
    const Offset(34, 20),
  ];
  drawBranch(canvas, neck, 13, 7, HwatuInk.vermilion);
  final scale = strokeOf(HwatuInk.goldLight, 0.8);
  final pts = smoothPoints(neck);
  for (var k = 2; k < pts.length - 2; k += 2) {
    canvas.drawArc(
      Rect.fromCircle(center: pts[k], radius: 3),
      rad(20),
      rad(140),
      false,
      scale,
    );
  }
  // 머리
  const head = Offset(32, 18);
  canvas.drawCircle(head, 6.5, fillOf(HwatuInk.vermilion));
  canvas.drawCircle(head, 6.5, strokeOf(HwatuInk.ink, 0.7));
  canvas.drawPath(
    Path()
      ..moveTo(26.5, 15)
      ..lineTo(18, 19)
      ..lineTo(26.5, 21)
      ..close(),
    fillOf(HwatuInk.gold),
  );
  canvas.drawPath(
    leafPath(const Offset(28, 22), rad(110), 9, 5),
    fillOf(HwatuInk.red),
  );
  canvas.drawCircle(const Offset(31, 16), 2, fillOf(HwatuInk.white));
  canvas.drawCircle(const Offset(30.6, 16), 1.1, fillOf(HwatuInk.ink));
  // 볏
  for (final (a, l) in const [(-120.0, 12.0), (-95.0, 14.0), (-70.0, 11.0)]) {
    final end = polar(const Offset(34, 12), l, rad(a));
    canvas.drawLine(const Offset(34, 12), end, strokeOf(HwatuInk.ink, 0.9));
    canvas.drawCircle(end, 1.8, fillOf(HwatuInk.goldLight));
    canvas.drawCircle(end, 1.8, strokeOf(HwatuInk.ink, 0.5));
  }
}

void paintMonth11(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.bright:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w, _h),
        Paint()
          ..shader = Gradient.radial(const Offset(40, 50), 70, [
            const Color(0xFFFBE3BE),
            HwatuInk.ivory,
          ]),
      );
      _phoenix(canvas);
      _paulowniaLeaves(canvas, leaf: HwatuInk.ink);
    case HwatuType.animal:
    case HwatuType.ribbon:
    case HwatuType.junk:
      if (spec.isDouble) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, _w, _h),
          Paint()
            ..shader = Gradient.linear(
              const Offset(0, 0),
              const Offset(0, _h),
              [HwatuInk.ivory, const Color(0xFFF3C978), HwatuInk.vermilion],
              const [0, 0.5, 1],
            ),
        );
        _paulowniaFlowers(
          canvas,
          const Offset(50, 92),
          64,
          bloom: HwatuInk.white,
          edge: HwatuInk.goldDark,
        );
        _paulowniaLeaves(canvas, leaf: HwatuInk.ink, edge: HwatuInk.goldLight);
      } else {
        _paulowniaFlowers(canvas, const Offset(50, 92), 66);
        _paulowniaLeaves(canvas, leaf: HwatuInk.ink);
      }
  }
}

// ── 12월 비 ────────────────────────────────────────────────────

void _willow(
  Canvas canvas, {
  Color color = HwatuInk.pine,
  double reach = 1,
  double left = 30,
}) {
  final strands = <List<Offset>>[
    for (var i = 0; i < 6; i++)
      [
        Offset(left + i * 13, -4),
        Offset(left + i * 13 + 8, 30 * reach),
        Offset(left + i * 13 + 2 - i * 1.5, (62 + (i % 3) * 18) * reach),
      ],
  ];
  for (final s in strands) {
    drawBranch(canvas, s, 1.8, 0.8, color);
    final pts = smoothPoints(s);
    for (var k = 2; k < pts.length - 1; k += 2) {
      final dir = pts[k + 1] - pts[k - 1];
      final a = math.atan2(dir.dy, dir.dx);
      final side = k % 4 == 0 ? 1 : -1;
      canvas.drawPath(leafPath(pts[k], a + side * 0.5, 8, 2.6), fillOf(color));
    }
  }
}

void _rain(Canvas canvas, Color color, {double top = 0}) {
  final p = strokeOf(color, 0.9);
  final rnd = math.Random(12);
  for (var i = 0; i < 22; i++) {
    final x = rnd.nextDouble() * 110 - 5;
    final y = top + rnd.nextDouble() * (_h - top);
    canvas.drawLine(Offset(x, y), Offset(x - 3, y + 11), p);
  }
}

/// 우산 쓴 사람(단순 실루엣) + 개구리.
void _umbrellaFigure(Canvas canvas) {
  // 몸(먹색 도포)
  final robe = Path()
    ..moveTo(40, 86)
    ..cubicTo(34, 104, 28, 124, 24, 138)
    ..lineTo(62, 138)
    ..cubicTo(60, 120, 58, 102, 54, 86)
    ..close();
  canvas.drawPath(robe, fillOf(HwatuInk.ink));
  canvas.drawPath(
    Path()
      ..moveTo(47, 88)
      ..lineTo(43, 110)
      ..lineTo(51, 110)
      ..close(),
    fillOf(HwatuInk.white),
  );
  canvas.drawRect(
    const Rect.fromLTWH(26, 130, 35, 3),
    fillOf(HwatuInk.vermilion),
  );
  // 얼굴
  canvas.drawCircle(const Offset(47, 80), 6, fillOf(HwatuInk.ivoryDeep));
  // 우산
  const hub = Offset(50, 54);
  final canopy = Path()
    ..moveTo(18, 68)
    ..quadraticBezierTo(22, 40, 50, 34)
    ..quadraticBezierTo(80, 38, 86, 64)
    ..quadraticBezierTo(70, 60, 52, 66)
    ..quadraticBezierTo(34, 62, 18, 68)
    ..close();
  canvas.drawPath(canopy, fillOf(HwatuInk.vermilion));
  final rib = strokeOf(HwatuInk.crimson, 1);
  for (final end in const [
    Offset(18, 68),
    Offset(34, 64),
    Offset(52, 66),
    Offset(70, 62),
    Offset(86, 64),
  ]) {
    canvas.drawLine(const Offset(50, 35), end, rib);
  }
  canvas.drawPath(canopy, strokeOf(HwatuInk.crimsonDark, 1.2));
  canvas.drawLine(hub, const Offset(50, 98), strokeOf(HwatuInk.brown, 1.8));
  canvas.drawCircle(const Offset(50, 34), 2, fillOf(HwatuInk.ink));
  // 손
  canvas.drawCircle(const Offset(50, 92), 2.6, fillOf(HwatuInk.ivoryDeep));
  // 개울과 개구리
  final water = strokeOf(HwatuInk.blueLight, 1.4);
  for (final y in [142.0, 148.0]) {
    final p = Path()..moveTo(0, y);
    for (var x = 0.0; x < _w; x += 14) {
      p.quadraticBezierTo(x + 7, y - 3, x + 14, y);
    }
    canvas.drawPath(p, water);
  }
  const frog = Offset(80, 132);
  canvas.drawOval(
    Rect.fromCenter(center: frog, width: 14, height: 9),
    fillOf(HwatuInk.jade),
  );
  canvas.drawCircle(frog + const Offset(-5, -4), 2.4, fillOf(HwatuInk.jade));
  canvas.drawCircle(
    frog + const Offset(-5, -4.5),
    1,
    fillOf(HwatuInk.goldLight),
  );
}

/// 날아가는 제비(왼쪽으로).
void _swallow(Canvas canvas, Offset c, double s) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(s);
  const back = Color(0xFF1F2A4A);
  // 날개
  final upper = Path()
    ..moveTo(-2, -2)
    ..cubicTo(4, -14, 18, -26, 34, -30)
    ..cubicTo(24, -18, 16, -6, 8, 2)
    ..close();
  final lower = Path()
    ..moveTo(-4, 2)
    ..cubicTo(-2, 12, 6, 24, 18, 32)
    ..cubicTo(14, 20, 10, 10, 6, 2)
    ..close();
  canvas.drawPath(lower, fillOf(back));
  // 갈라진 꼬리
  final tail = Path()
    ..moveTo(10, 0)
    ..lineTo(34, 4)
    ..lineTo(18, 4)
    ..lineTo(32, 12)
    ..lineTo(8, 5)
    ..close();
  canvas.drawPath(tail, fillOf(back));
  // 몸
  final body = Path()
    ..moveTo(-16, 0)
    ..cubicTo(-8, -7, 6, -5, 14, 1)
    ..cubicTo(6, 6, -8, 6, -16, 0)
    ..close();
  canvas.drawPath(body, fillOf(back));
  canvas.drawPath(
    Path()
      ..moveTo(-12, 1.5)
      ..cubicTo(-4, 6, 6, 5, 12, 2)
      ..cubicTo(4, 3, -4, 3, -12, 1.5)
      ..close(),
    fillOf(HwatuInk.white),
  );
  canvas.drawPath(upper, fillOf(back));
  canvas.drawPath(
    upper,
    strokeOf(HwatuInk.blueLight.withValues(alpha: 0.5), 0.6),
  );
  // 머리
  canvas.drawCircle(const Offset(-16, -1), 4.4, fillOf(back));
  canvas.drawCircle(const Offset(-18.5, 1.5), 2.2, fillOf(HwatuInk.vermilion));
  canvas.drawCircle(const Offset(-17, -2.4), 0.9, fillOf(HwatuInk.white));
  canvas.drawPath(
    Path()
      ..moveTo(-20, -1.6)
      ..lineTo(-24, 0)
      ..lineTo(-20, 0.8)
      ..close(),
    fillOf(HwatuInk.ink),
  );
  canvas.restore();
}

/// 쌍피: 진홍 하늘에 먹빛 버들, 흰 번개.
void _stormDouble(Canvas canvas) {
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _w, _h),
    Paint()
      ..shader = Gradient.linear(const Offset(0, 0), const Offset(0, _h), [
        HwatuInk.crimsonDark,
        HwatuInk.red,
      ]),
  );
  _willow(canvas, color: HwatuInk.ink, reach: 1.25, left: 24);
  final bolt = Path()
    ..moveTo(64, 34)
    ..lineTo(46, 72)
    ..lineTo(58, 72)
    ..lineTo(40, 112)
    ..lineTo(70, 64)
    ..lineTo(58, 64)
    ..lineTo(74, 34)
    ..close();
  canvas.drawPath(bolt, fillOf(HwatuInk.goldLight));
  canvas.drawPath(bolt, strokeOf(HwatuInk.white, 1));
  // 먹구름
  for (final (c, r) in const [
    (Offset(14, 132), 16.0),
    (Offset(40, 142), 18.0),
    (Offset(70, 136), 17.0),
    (Offset(94, 144), 15.0),
  ]) {
    canvas.drawPath(scallopPath(c, r, 8, depth: 0.12), fillOf(HwatuInk.ink));
  }
  _rain(canvas, HwatuInk.white.withValues(alpha: 0.35));
}

void paintMonth12(Canvas canvas, HwatuCardSpec spec) {
  switch (spec.type) {
    case HwatuType.bright:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, _w, _h),
        Paint()
          ..shader = Gradient.linear(const Offset(0, 0), const Offset(0, _h), [
            HwatuInk.night,
            HwatuInk.slate,
          ]),
      );
      _rain(canvas, HwatuInk.white.withValues(alpha: 0.4));
      _willow(canvas, color: HwatuInk.leaf, reach: 0.75, left: 58);
      _umbrellaFigure(canvas);
    case HwatuType.animal:
      _rain(canvas, HwatuInk.blueLight.withValues(alpha: 0.5));
      _willow(canvas, reach: 1.1, left: 20);
      _swallow(canvas, const Offset(52, 108), 1.35);
    case HwatuType.ribbon:
      _rain(canvas, HwatuInk.blueLight.withValues(alpha: 0.5));
      _willow(canvas, reach: 1.25, left: 20);
      paintRibbonFor(canvas, spec, const Offset(54, 96), rad(-6), length: 60);
    case HwatuType.junk:
      _stormDouble(canvas);
  }
}
