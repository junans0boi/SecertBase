// 화투 그림 공용 팔레트와 그리기 도구.
//
// 모든 앞면 그림은 가로 [kHwatuUnitW] × 세로 [kHwatuUnitH] 단위 좌표에서
// 그린 뒤 실제 크기로 비례 확대한다. 이 파일의 함수들은 카드 id마다
// 한 번만(그림 캐시를 만들 때) 호출되므로 여기서의 Path/Paint 생성은
// 프레임마다 반복되지 않는다.

import 'dart:math' as math;
import 'dart:ui';

/// 화투 앞면 비율(가로 60 : 세로 91, 기존 PNG와 같다).
const double kHwatuAspect = 91 / 60;

/// 그림 좌표계 가로 폭.
const double kHwatuUnitW = 100;

/// 그림 좌표계 세로 높이.
const double kHwatuUnitH = kHwatuUnitW * kHwatuAspect;

/// 카드 테두리(진홍 테) 두께, 단위 좌표.
const double kHwatuRim = 3.4;

/// 전통 화투 팔레트(주홍·진홍·먹·흰색·금)에 꽃 색 몇 가지를 더한 것.
abstract final class HwatuInk {
  static const ivory = Color(0xFFF8F1E1);
  static const ivoryDeep = Color(0xFFEDE0C4);
  static const vermilion = Color(0xFFE5482E);
  static const red = Color(0xFFC0222C);
  static const crimson = Color(0xFF8C1420);
  static const crimsonDark = Color(0xFF5E0B14);
  static const ink = Color(0xFF1E1A1B);
  static const inkSoft = Color(0xFF453D3C);
  static const gold = Color(0xFFD4A23C);
  static const goldLight = Color(0xFFF1CF78);
  static const goldDark = Color(0xFF9E7424);
  static const white = Color(0xFFFFFFFF);
  static const pink = Color(0xFFF7CFCB);
  static const blush = Color(0xFFEE9A97);
  static const blue = Color(0xFF2557A6);
  static const blueLight = Color(0xFF5C8BD1);
  static const indigo = Color(0xFF2C3480);
  static const violet = Color(0xFF6B4FA3);
  static const lilac = Color(0xFF9C83CB);
  static const pine = Color(0xFF1E4A3A);
  static const jade = Color(0xFF2F7556);
  static const leaf = Color(0xFF3F8A5E);
  static const ochre = Color(0xFFC98A3A);
  static const brown = Color(0xFF6B4228);
  static const night = Color(0xFF26304A);
  static const slate = Color(0xFF3A4660);
}

Paint fillOf(Color color) => Paint()
  ..color = color
  ..isAntiAlias = true;

Paint strokeOf(Color color, double width, {StrokeCap cap = StrokeCap.round}) =>
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

Offset polar(Offset c, double r, double angle) =>
    Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));

double rad(double degrees) => degrees * math.pi / 180;

/// 점들을 지나는 Catmull-Rom 곡선을 촘촘한 점 목록으로 바꾼다.
List<Offset> smoothPoints(List<Offset> pts, {int perSegment = 10}) {
  if (pts.length < 3) return pts;
  final out = <Offset>[];
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i == 0 ? 0 : i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 < pts.length ? i + 2 : pts.length - 1];
    for (var s = 0; s < perSegment; s++) {
      final t = s / perSegment;
      final t2 = t * t;
      final t3 = t2 * t;
      out.add(
        Offset(
          0.5 *
              (2 * p1.dx +
                  (-p0.dx + p2.dx) * t +
                  (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
                  (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
          0.5 *
              (2 * p1.dy +
                  (-p0.dy + p2.dy) * t +
                  (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
                  (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
        ),
      );
    }
  }
  out.add(pts.last);
  return out;
}

/// 굵기가 [w0]에서 [w1]로 가늘어지는 붓 획(가지·줄기·꼬리)을 칠한다.
void drawBranch(
  Canvas canvas,
  List<Offset> pts,
  double w0,
  double w1,
  Color color,
) {
  final path = branchPath(pts, w0, w1);
  final paint = fillOf(color);
  canvas.drawPath(path, paint);
  final s = smoothPoints(pts);
  canvas.drawCircle(s.first, w0 / 2, paint);
  canvas.drawCircle(s.last, w1 / 2, paint);
}

Path branchPath(List<Offset> pts, double w0, double w1) {
  final s = smoothPoints(pts);
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < s.length; i++) {
    final a = s[i == 0 ? 0 : i - 1];
    final b = s[i == s.length - 1 ? i : i + 1];
    var d = b - a;
    final len = d.distance;
    d = len == 0 ? const Offset(1, 0) : d / len;
    final n = Offset(-d.dy, d.dx);
    final t = s.length == 1 ? 0.0 : i / (s.length - 1);
    final w = (w0 + (w1 - w0) * t) / 2;
    left.add(s[i] + n * w);
    right.add(s[i] - n * w);
  }
  final path = Path()..moveTo(left.first.dx, left.first.dy);
  for (final p in left.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  for (final p in right.reversed) {
    path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// 밑동 [base]에서 [angle] 방향으로 뻗은 잎. [bend]는 잎의 휨(폭 대비).
Path leafPath(
  Offset base,
  double angle,
  double length,
  double width, {
  double bend = 0,
}) {
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx);
  final tip = base + d * length + n * (bend * width);
  final mid = base + d * (length * 0.42) + n * (bend * width * 0.6);
  final c1 = mid + n * width;
  final c2 = mid - n * width;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(c2.dx, c2.dy, base.dx, base.dy)
    ..close();
}

/// 밑에서 올라오는 칼날 잎(창포·난초). [lean]만큼 끝이 옆으로 휜다.
Path bladePath(Offset base, double height, double width, double lean) {
  final tip = Offset(base.dx + lean, base.dy - height);
  final ctrl = Offset(base.dx + lean * 0.15, base.dy - height * 0.55);
  return Path()
    ..moveTo(base.dx - width / 2, base.dy)
    ..quadraticBezierTo(ctrl.dx - width * 0.5, ctrl.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(
      ctrl.dx + width * 0.5,
      ctrl.dy,
      base.dx + width / 2,
      base.dy,
    )
    ..close();
}

/// 극좌표 함수 r(θ)로 닫힌 도형을 만든다.
Path polarPath(
  Offset c,
  double Function(double theta) radius, {
  int samples = 120,
  double rotation = 0,
}) {
  final path = Path();
  for (var i = 0; i <= samples; i++) {
    final t = i / samples * 2 * math.pi;
    final p = polar(c, radius(t), t + rotation);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// 물결 테두리 원(모란 꽃잎 겹, 구름).
Path scallopPath(
  Offset c,
  double r,
  int bumps, {
  double depth = 0.14,
  double rotation = 0,
}) {
  return polarPath(
    c,
    (t) => r * (1 - depth + depth * math.cos(bumps * t / 2).abs()),
    samples: bumps * 16,
    rotation: rotation,
  );
}

/// 다섯 장 둥근 꽃잎 꽃(매화).
void drawPlum(
  Canvas canvas,
  Offset c,
  double r, {
  Color petal = HwatuInk.red,
  Color edge = HwatuInk.crimson,
  Color heart = HwatuInk.goldLight,
  double rotation = 0,
}) {
  final pr = r * 0.48;
  final edgePaint = fillOf(edge);
  final petalPaint = fillOf(petal);
  for (var i = 0; i < 5; i++) {
    final p = polar(c, r * 0.52, rotation + i * 2 * math.pi / 5 - math.pi / 2);
    canvas.drawCircle(p, pr + r * 0.07, edgePaint);
  }
  for (var i = 0; i < 5; i++) {
    final p = polar(c, r * 0.52, rotation + i * 2 * math.pi / 5 - math.pi / 2);
    canvas.drawCircle(p, pr, petalPaint);
  }
  canvas.drawCircle(c, r * 0.3, fillOf(heart));
  final dot = fillOf(edge);
  for (var i = 0; i < 5; i++) {
    canvas.drawCircle(
      polar(c, r * 0.2, rotation + i * 2 * math.pi / 5),
      r * 0.06,
      dot,
    );
  }
}

/// 끝이 갈라진 다섯 장 꽃잎(벚꽃).
void drawCherry(
  Canvas canvas,
  Offset c,
  double r, {
  Color petal = HwatuInk.white,
  Color edge = HwatuInk.blush,
  Color heart = HwatuInk.vermilion,
  double rotation = 0,
}) {
  final petalPath = Path()
    ..moveTo(0, 0)
    ..cubicTo(-0.62 * r, -0.3 * r, -0.62 * r, -0.95 * r, -0.17 * r, -r)
    ..lineTo(0, -0.8 * r)
    ..lineTo(0.17 * r, -r)
    ..cubicTo(0.62 * r, -0.95 * r, 0.62 * r, -0.3 * r, 0, 0)
    ..close();
  final edgeStroke = strokeOf(edge, r * 0.12);
  final petalFill = fillOf(petal);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(rotation);
  for (var i = 0; i < 5; i++) {
    canvas.drawPath(petalPath, edgeStroke);
    canvas.drawPath(petalPath, petalFill);
    canvas.rotate(2 * math.pi / 5);
  }
  canvas.restore();
  canvas.drawCircle(c, r * 0.2, fillOf(heart));
  final stamen = fillOf(heart);
  for (var i = 0; i < 5; i++) {
    canvas.drawCircle(
      polar(c, r * 0.38, rotation + i * 2 * math.pi / 5 + 0.6),
      r * 0.06,
      stamen,
    );
  }
}

/// 가는 꽃잎이 겹겹인 국화.
void drawMum(
  Canvas canvas,
  Offset c,
  double r, {
  Color outer = HwatuInk.goldLight,
  Color inner = HwatuInk.gold,
  Color line = HwatuInk.goldDark,
  Color heart = HwatuInk.vermilion,
}) {
  void ring(double rr, int n, Color color, double offset) {
    final petal = fillOf(color);
    final edge = strokeOf(line, r * 0.035);
    for (var i = 0; i < n; i++) {
      final a = offset + i * 2 * math.pi / n;
      final p = leafPath(c, a, rr, rr * 0.38);
      canvas.drawPath(p, petal);
      canvas.drawPath(p, edge);
    }
  }

  ring(r, 18, outer, 0);
  ring(r * 0.72, 14, inner, 0.2);
  ring(r * 0.45, 10, outer, 0.1);
  canvas.drawCircle(c, r * 0.18, fillOf(heart));
}

/// 겹겹 물결 꽃잎의 모란.
void drawPeony(
  Canvas canvas,
  Offset c,
  double r, {
  Color outer = HwatuInk.red,
  Color mid = HwatuInk.vermilion,
  Color inner = HwatuInk.crimson,
  Color heart = HwatuInk.goldLight,
}) {
  canvas.drawPath(scallopPath(c, r, 9, depth: 0.16), fillOf(outer));
  canvas.drawPath(
    scallopPath(c, r * 0.97, 9, depth: 0.16),
    strokeOf(HwatuInk.crimson, r * 0.05),
  );
  canvas.drawPath(
    scallopPath(
      c + Offset(0, -r * 0.05),
      r * 0.7,
      7,
      depth: 0.2,
      rotation: 0.3,
    ),
    fillOf(mid),
  );
  canvas.drawPath(
    scallopPath(c + Offset(0, -r * 0.08), r * 0.42, 5, depth: 0.25),
    fillOf(inner),
  );
  final dot = fillOf(heart);
  for (var i = 0; i < 6; i++) {
    canvas.drawCircle(
      polar(c + Offset(0, -r * 0.08), r * 0.16, i * math.pi / 3),
      r * 0.07,
      dot,
    );
  }
}

/// 다섯 갈래 뾰족한 단풍잎. [rotation]은 잎 끝이 향하는 방향.
Path maplePath(Offset c, double r, {double rotation = 0}) {
  return polarPath(
    c,
    (t) {
      // t=0이 잎 끝(위). 아래쪽(줄기 쪽)은 짧게.
      final bottom = (math.cos(t) * -1 + 1) / 2; // 0 위 … 1 아래
      final lobe = math.pow(math.cos(5 * t / 2).abs(), 2.2).toDouble();
      final teeth = 0.06 * math.cos(15 * t / 2).abs();
      return r * (0.38 + 0.62 * lobe + teeth) * (1 - 0.45 * bottom * bottom);
    },
    samples: 200,
    rotation: rotation - math.pi / 2,
  );
}

/// 붓 끝처럼 가는 선(풀잎, 억새, 비).
void drawStrokeLine(
  Canvas canvas,
  Offset a,
  Offset b,
  double width,
  Color color,
) {
  canvas.drawLine(a, b, strokeOf(color, width));
}

/// 홍단·청단·초단 띠(단책). [center]를 중심으로 [angle]만큼 기운다.
void drawRibbon(
  Canvas canvas,
  Offset center,
  double angle, {
  required Color color,
  required bool poem,
  double length = 64,
  double width = 15,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(angle);
  final hw = width / 2;
  final hl = length / 2;
  final body = Path()
    ..moveTo(-hw, -hl)
    ..lineTo(hw, -hl)
    ..lineTo(hw, hl)
    ..lineTo(0, hl - width * 0.35)
    ..lineTo(-hw, hl)
    ..close();
  // 그림자
  canvas.save();
  canvas.translate(1.4, 1.6);
  canvas.drawPath(body, fillOf(const Color(0x33000000)));
  canvas.restore();
  canvas.drawPath(body, fillOf(color));
  // 얇은 금 테두리와 윗단 끈
  final inset = Path()
    ..moveTo(-hw + 1.6, -hl + 5)
    ..lineTo(hw - 1.6, -hl + 5)
    ..lineTo(hw - 1.6, hl - 2.2)
    ..lineTo(0, hl - width * 0.35 - 1.8)
    ..lineTo(-hw + 1.6, hl - 2.2)
    ..close();
  canvas.drawPath(
    inset,
    strokeOf(HwatuInk.goldLight.withValues(alpha: 0.85), 0.7),
  );
  canvas.drawRect(
    Rect.fromLTRB(-hw, -hl, hw, -hl + 3.2),
    fillOf(HwatuInk.goldLight),
  );
  if (poem) {
    // 글씨 대신 시구를 닮은 금빛 획 무늬.
    final ink = strokeOf(HwatuInk.goldLight, 1.5);
    final dot = fillOf(HwatuInk.goldLight);
    var y = -hl + 10.5;
    var k = 0;
    while (y < hl - 12) {
      switch (k % 4) {
        case 0:
          canvas.drawLine(Offset(-hw * 0.4, y), Offset(hw * 0.4, y + 1), ink);
          canvas.drawLine(Offset(0, y - 2.2), Offset(0, y + 3.5), ink);
        case 1:
          canvas.drawCircle(Offset(-hw * 0.18, y), 1.1, dot);
          canvas.drawLine(
            Offset(hw * 0.05, y - 2),
            Offset(hw * 0.32, y + 2.4),
            ink,
          );
        case 2:
          canvas.drawLine(
            Offset(-hw * 0.35, y - 1.6),
            Offset(hw * 0.35, y - 1.6),
            ink,
          );
          canvas.drawLine(
            Offset(-hw * 0.25, y + 1.8),
            Offset(hw * 0.25, y + 1.8),
            ink,
          );
        default:
          canvas.drawLine(Offset(-hw * 0.3, y + 2.4), Offset(0, y - 2.4), ink);
          canvas.drawLine(Offset(0, y - 2.4), Offset(hw * 0.32, y + 2.4), ink);
      }
      y += 8.4;
      k++;
    }
  }
  canvas.restore();
}

/// 흰 테두리를 두른 단순한 새 실루엣 날개(기러기·제비 원거리).
Path flyingBirdPath(Offset c, double span, {double lift = 0.35}) {
  final h = span / 2;
  return Path()
    ..moveTo(c.dx - h, c.dy - span * lift * 0.2)
    ..quadraticBezierTo(c.dx - h * 0.45, c.dy - span * lift, c.dx, c.dy)
    ..quadraticBezierTo(
      c.dx + h * 0.45,
      c.dy - span * lift,
      c.dx + h,
      c.dy - span * lift * 0.2,
    )
    ..quadraticBezierTo(
      c.dx + h * 0.45,
      c.dy - span * lift * 0.55,
      c.dx,
      c.dy + span * 0.12,
    )
    ..quadraticBezierTo(
      c.dx - h * 0.45,
      c.dy - span * lift * 0.55,
      c.dx - h,
      c.dy - span * lift * 0.2,
    )
    ..close();
}
