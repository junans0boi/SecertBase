import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tank_camera.dart';
import 'tank_data.dart';
import 'tank_playback.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 전장 그리기. 모든 위치는 칸 좌표로 받아 TankView로 화면 픽셀로 바꾼다.
// ─────────────────────────────────────────────────────────────────────────────

/// 폭발 자국(그을음).
class TankScorch {
  final double col;
  final double radius;
  const TankScorch(this.col, this.radius);
}

/// 한 프레임을 그리는 데 필요한 모든 값.
class TankScene {
  final Map<String, dynamic> state;
  final int myIndex;
  final TankView view;

  /// 화면이 열린 뒤 흐른 시간(초): 날씨·연기·깜빡임 등.
  final double time;
  final TankPlayback? playback;

  /// 재생 유효 시간(ms).
  final double playMs;
  final double myAngle;
  final double myPower;

  /// 내 차례이고 재생 중이 아님: 조준 가이드 표시.
  final bool aiming;
  final List<Offset> preview;
  final List<Offset> lastTrace;
  final double? opponentAngle;
  final List<TankScorch> scorches;

  /// 보급 상자 id → 나타난 시각(time 기준).
  final Map<String, double> crateDrops;
  final String myName;
  final String oppName;

  /// 끌어서 조준하는 중인 손가락 위치(화면 좌표).
  final Offset? dragPoint;

  /// HUD·조작부가 가리는 위·아래 높이(미니맵·화면 밖 표시 위치 계산용).
  final double insetTop;
  final double insetBottom;

  /// 미니맵과 화면 밖 전차 표시를 그린다(전투 화면).
  final bool showGuides;

  const TankScene({
    required this.state,
    required this.myIndex,
    required this.view,
    required this.time,
    this.playback,
    this.playMs = 0,
    this.myAngle = 45,
    this.myPower = 50,
    this.aiming = false,
    this.preview = const [],
    this.lastTrace = const [],
    this.opponentAngle,
    this.scorches = const [],
    this.crateDrops = const {},
    this.myName = '나',
    this.oppName = '상대',
    this.dragPoint,
    this.insetTop = 0,
    this.insetBottom = 0,
    this.showGuides = false,
  });
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

double _hash(int i, int salt) {
  final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

double _easeOut(double k) => 1 - math.pow(1 - k.clamp(0.0, 1.0), 3).toDouble();

List<double>? tankTerrainOf(Map<String, dynamic>? state) {
  final raw = state?['terrain'] as List?;
  if (raw == null || raw.length != kTerrainW) return null;
  return [for (final v in raw) (v as num).toDouble()];
}

/// 열 [col]의 지표면 y(칸).
double tankSurfaceY(List<double> terrain, double col) {
  final c = col.round().clamp(0, kTerrainW - 1);
  return kTerrainH - terrain[c] - 0.5;
}

class TankBattlefieldPainter extends CustomPainter {
  final TankScene s;
  const TankBattlefieldPainter(this.s);

  TankView get v => s.view;

  @override
  void paint(Canvas canvas, Size size) {
    final look = tankThemeOf(s.state);
    final pb = s.playback;
    final t = s.playMs;
    final terrain = tankTerrainOf(s.state);

    double shakeX = 0, shakeY = 0;
    if (pb != null) {
      final p = pb.shakeAt(t);
      if (p > 0) {
        shakeX = math.sin(t / 17) * p * 0.6;
        shakeY = math.cos(t / 23) * p * 0.45;
      }
    }

    canvas.save();
    canvas.translate(shakeX, shakeY);
    _sky(canvas, size, look);
    _celestial(canvas, size, look);
    _clouds(canvas, size, look);
    _ridges(canvas, size, look);
    if (terrain != null) _ground(canvas, size, look, terrain);
    if (terrain != null) _crates(canvas, terrain);
    _lastTrace(canvas);
    _tanks(canvas, look, terrain);
    if (s.aiming) _aimGuide(canvas);
    if (pb != null) _playback(canvas, pb, look, terrain);
    _popups(canvas, pb);
    _weather(canvas, size, look);
    _dragGuide(canvas);
    canvas.restore();

    if (pb != null) {
      final f = pb.flashAt(t);
      if (f > 0) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: f * 0.55),
        );
      }
      _offscreenMarker(canvas, size, pb);
    }
    if (s.showGuides) {
      _edgeMarkers(canvas, size);
      if (terrain != null) _minimap(canvas, size, terrain, pb);
    }
  }

  /// 미니맵 위치(화면 좌표). 전장 위젯이 탭 판정에 쓴다.
  static Rect minimapRect(Size size, double insetTop) {
    final w = math.min(300.0, size.width - 32);
    return Rect.fromLTWH((size.width - w) / 2, insetTop - 2, w, 36);
  }

  /// 재생 중 날아가는 포탄의 칸 좌표.
  Offset? _shellHead(TankPlayback pb) {
    for (final shell in pb.shells) {
      final st = shell.stage;
      if (st >= pb.stageCount) continue;
      final flight = pb.stageFlightMs[st];
      final k = flight <= 0 ? 1.0 : (s.playMs - pb.stageStartMs[st]) / flight;
      if (k < 0 || k > 1) continue;
      final pts = shell.path;
      return pts[(k * (pts.length - 1)).round().clamp(0, pts.length - 1)];
    }
    return null;
  }

  void _minimap(Canvas canvas, Size size, List<double> h, TankPlayback? pb) {
    final rect = minimapRect(size, s.insetTop);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = const Color(0xB0101624));
    canvas.save();
    canvas.clipRRect(rr);
    final inner = rect.deflate(4);
    // 지형 실루엣(맵 상단 10행은 하늘로 잘라 높이 차가 잘 보이게 한다)
    const topRow = 10.0;
    Offset mm(double col, double row) => Offset(
      inner.left + (col + 0.5) / kTerrainW * inner.width,
      inner.top +
          ((row - topRow) / (kTerrainH - topRow)).clamp(0.0, 1.0) *
              inner.height,
    );
    final ground = Path()..moveTo(inner.left, inner.bottom);
    for (int c = 0; c < kTerrainW; c++) {
      final p = mm(c.toDouble(), kTerrainH - h[c] - 0.5);
      ground.lineTo(p.dx, p.dy);
    }
    ground
      ..lineTo(inner.right, inner.bottom)
      ..close();
    final look = tankThemeOf(s.state);
    canvas.drawPath(ground, Paint()..color = _a(look.groundTop, 0.85));
    // 지금 보이는 범위
    final viewLeft = v.left;
    final viewRight = v.left + size.width / v.scale;
    final vx0 = mm(viewLeft.clamp(-0.5, kTerrainW - 0.5), 0).dx;
    final vx1 = mm(viewRight.clamp(-0.5, kTerrainW - 0.5), 0).dx;
    canvas.drawRect(
      Rect.fromLTRB(vx0, rect.top + 1, vx1, rect.bottom - 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    // 보급 상자
    for (final raw in (s.state['crates'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final p = mm(
        (raw['col'] as num).toDouble(),
        (raw['row'] as num).toDouble(),
      );
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 4, height: 4),
        Paint()..color = TankUi.gold,
      );
    }
    // 전차
    final players = (s.state['players'] as List?) ?? const [];
    final turn = (s.state['turn'] as num?)?.toInt() ?? -1;
    for (int i = 0; i < players.length; i++) {
      final raw = players[i];
      if (raw is! Map) continue;
      final p = mm(
        (raw['col'] as num).toDouble(),
        (raw['row'] as num).toDouble(),
      );
      final color = i == s.myIndex ? TankUi.me : TankUi.enemy;
      final dead = ((raw['hp'] as num?) ?? 1) <= 0;
      if (turn == i && pb == null && !dead) {
        final pulse = 0.5 + 0.5 * math.sin(s.time * 6);
        canvas.drawCircle(p, 6 + pulse * 2, Paint()..color = _a(color, 0.3));
      }
      canvas.drawCircle(p, 4, Paint()..color = dead ? Colors.grey : color);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white,
      );
    }
    // 포탄
    if (pb != null) {
      final head = _shellHead(pb);
      if (head != null) {
        canvas.drawCircle(
          mm(head.dx, math.max(head.dy, topRow)),
          2.5,
          Paint()..color = Colors.yellowAccent,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TankUi.panelLine,
    );
  }

  /// 화면 밖에 있는 전차를 가장자리 화살표로 알려준다(방향·거리).
  void _edgeMarkers(Canvas canvas, Size size) {
    final players = (s.state['players'] as List?) ?? const [];
    final top = s.insetTop + 50;
    final bottom = size.height - s.insetBottom - 10;
    if (bottom <= top) return;
    Offset? me;
    if (s.myIndex < players.length && players[s.myIndex] is Map) {
      final m = players[s.myIndex] as Map;
      me = Offset((m['col'] as num).toDouble(), (m['row'] as num).toDouble());
    }
    for (int i = 0; i < players.length; i++) {
      final raw = players[i];
      if (raw is! Map) continue;
      final col = (raw['col'] as num).toDouble();
      final row = (raw['row'] as num).toDouble();
      final p = v.toScreen(col, row);
      // 전차가 화면 가장자리에 조금이라도 보이면 표시하지 않는다(겹침 방지).
      final half = v.scale * 2.2;
      final inside =
          p.dx >= -half &&
          p.dx <= size.width + half &&
          p.dy >= top - 40 &&
          p.dy <= bottom + v.scale;
      if (inside) continue;
      final mine = i == s.myIndex;
      final color = mine ? TankUi.me : TankUi.enemy;
      final pos = Offset(
        p.dx.clamp(30.0, size.width - 30),
        p.dy.clamp(top, bottom),
      );
      final dir = p - pos;
      final ang = dir.distance == 0 ? 0.0 : math.atan2(dir.dy, dir.dx);
      final pulse = 0.5 + 0.5 * math.sin(s.time * 5);
      canvas.drawCircle(pos, 20, Paint()..color = const Color(0xD0101624));
      canvas.drawCircle(
        pos,
        20,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _a(color, 0.6 + pulse * 0.4),
      );
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(ang);
      final arrow = Path()
        ..moveTo(26, 0)
        ..lineTo(17, -7)
        ..lineTo(17, 7)
        ..close();
      canvas.drawPath(arrow, Paint()..color = color);
      canvas.restore();
      final dist = me == null || mine ? null : (col - me.dx).abs().round();
      final label = mine ? '나' : (dist == null ? s.oppName : '${dist}m');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: label.length > 4 ? 9 : 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 36);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // ── 하늘 ───────────────────────────────────────────────────────────────────

  void _sky(Canvas canvas, Size size, TankThemeLook look) {
    final rect = Rect.fromLTWH(-30, -30, size.width + 60, size.height + 60);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          look.sky,
          const [0, 0.55, 1],
        ),
    );
    if (look.weather == TankWeather.stars) {
      final star = Paint();
      for (int i = 0; i < 90; i++) {
        final x = _hash(i, 1) * size.width;
        final y = _hash(i, 2) * size.height * 0.75;
        final tw =
            0.35 +
            0.65 * (0.5 + 0.5 * math.sin(s.time * (1 + _hash(i, 3) * 2.5) + i));
        star.color = Colors.white.withValues(alpha: tw * 0.85);
        canvas.drawCircle(Offset(x, y), 0.5 + _hash(i, 4) * 1.3, star);
      }
    }
  }

  void _celestial(Canvas canvas, Size size, TankThemeLook look) {
    final parallax = v.left * v.scale * 0.04;
    if (look.weather == TankWeather.stars) {
      // 지구
      final c = Offset(size.width * 0.8 - parallax, size.height * 0.17);
      final r = math.max(18.0, math.min(size.width, size.height) * 0.06);
      canvas.drawCircle(
        c,
        r * 1.6,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 1.6, [
            _a(const Color(0xFF5FB8FF), 0.35),
            _a(const Color(0xFF5FB8FF), 0),
          ]),
      );
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2F7FD0));
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      final land = Paint()..color = const Color(0xFF58B368);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(-r * 0.35, -r * 0.2),
          width: r * 0.9,
          height: r * 0.6,
        ),
        land,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(r * 0.4, r * 0.35),
          width: r * 0.7,
          height: r * 0.45,
        ),
        land,
      );
      canvas.drawCircle(
        c.translate(r * 0.55, r * 0.1),
        r * 1.05,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.restore();
      return;
    }
    final desert = look.weather == TankWeather.sand;
    final c = Offset(
      size.width * (desert ? 0.72 : 0.82) - parallax,
      size.height * (desert ? 0.26 : 0.15),
    );
    final r = math.max(
      16.0,
      math.min(size.width, size.height) * (desert ? 0.08 : 0.05),
    );
    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 2.6, [
          _a(look.celestial, 0.55),
          _a(look.celestial, 0),
        ]),
    );
    canvas.drawCircle(c, r, Paint()..color = look.celestial);
  }

  void _clouds(Canvas canvas, Size size, TankThemeLook look) {
    if (look.cloud.a == 0) return;
    final wind = (s.state['wind'] as num?)?.toDouble() ?? 0;
    final drift = s.time * (5 + wind.abs() * 12) * (wind < 0 ? -1 : 1);
    final paint = Paint()..color = _a(look.cloud, 0.78);
    final span = size.width + 260;
    for (int i = 0; i < 5; i++) {
      final base =
          _hash(i, 11) * span +
          drift * (0.6 + _hash(i, 12) * 0.8) -
          v.left * v.scale * 0.12;
      final x = (base % span + span) % span - 130;
      final y = size.height * (0.06 + 0.07 * (i % 3)) + _hash(i, 13) * 18;
      final w = 46 + _hash(i, 14) * 50;
      canvas.drawCircle(Offset(x, y), w * 0.32, paint);
      canvas.drawCircle(Offset(x + w * 0.3, y - w * 0.12), w * 0.36, paint);
      canvas.drawCircle(Offset(x + w * 0.62, y), w * 0.28, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - w * 0.1, y - w * 0.05, w * 0.85, w * 0.3),
          Radius.circular(w * 0.15),
        ),
        paint,
      );
    }
  }

  void _ridges(Canvas canvas, Size size, TankThemeLook look) {
    void ridge(
      Color color,
      double baseRow,
      double amp,
      double factor,
      int seed,
    ) {
      final path = Path()..moveTo(-30, size.height + 30);
      final step = math.max(6.0, size.width / 48);
      for (double x = -30; x <= size.width + 30; x += step) {
        final wx = v.left * factor + x / v.scale;
        final row =
            baseRow -
            amp *
                (0.6 * math.sin(wx * 0.11 + seed) +
                    0.4 * math.sin(wx * 0.047 + seed * 2.3));
        // 세로 위치도 시차를 주어 멀리 있는 느낌을 낸다.
        final y =
            (row - v.top * factor) * v.scale +
            (1 - factor) * (size.height * 0.08);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width + 30, size.height + 30)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    ridge(_a(look.far, 0.9), 15, 3.2, 0.35, 3);
    ridge(_a(look.near, 0.95), 19, 2.6, 0.6, 7);
  }

  // ── 지형 ───────────────────────────────────────────────────────────────────

  Path _surfacePath(Size size, List<double> h) {
    Offset pt(int col) => v.toScreen(col.toDouble(), kTerrainH - h[col] - 0.5);
    final path = Path();
    final p0 = pt(0);
    path.moveTo(-40, p0.dy);
    path.lineTo(p0.dx, p0.dy);
    for (int i = 0; i < kTerrainW - 1; i++) {
      final a = pt(i);
      final b = pt(i + 1);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      if (i == 0) {
        path.lineTo(mid.dx, mid.dy);
      } else {
        path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      }
    }
    final last = pt(kTerrainW - 1);
    path.lineTo(last.dx, last.dy);
    path.lineTo(size.width + 40, last.dy);
    return path;
  }

  void _ground(Canvas canvas, Size size, TankThemeLook look, List<double> h) {
    final surface = _surfacePath(size, h);
    final fill = Path.from(surface)
      ..lineTo(size.width + 40, size.height + 40)
      ..lineTo(-40, size.height + 40)
      ..close();

    double minTop = double.infinity;
    for (int i = 0; i < kTerrainW; i++) {
      minTop = math.min(minTop, kTerrainH - h[i] - 0.5);
    }
    final topY = v.toScreen(0, minTop).dy;
    final bottomY = math.max(topY + 1, v.toScreen(0, kTerrainH.toDouble()).dy);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, topY), Offset(0, bottomY), [
          look.ground,
          look.groundDeep,
        ]),
    );

    canvas.save();
    canvas.clipPath(fill);
    // 표토층
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = v.scale * 2.6
        ..color = look.groundTop,
    );
    // 지층 무늬
    for (final depth in const [3.6, 7.5, 12.0]) {
      canvas.drawPath(
        surface.shift(Offset(0, depth * v.scale)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, v.scale * 0.22)
          ..color = _a(look.groundDeep, 0.28),
      );
    }
    // 돌멩이
    final rock = Paint()..color = _a(look.groundDeep, 0.35);
    final colStart = math.max(0, v.left.floor() - 1);
    final colEnd = math.min(
      kTerrainW - 1,
      (v.left + size.width / v.scale).ceil() + 1,
    );
    for (int c = colStart; c <= colEnd; c++) {
      if (_hash(c, 21) > 0.35) continue;
      final depth = 2.5 + _hash(c, 22) * 10;
      final p = v.toScreen(
        c + _hash(c, 23) - 0.5,
        kTerrainH - h[c] - 0.5 + depth,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: v.scale * (0.5 + _hash(c, 24) * 0.7),
          height: v.scale * (0.3 + _hash(c, 25) * 0.4),
        ),
        rock,
      );
    }
    // 그을음
    for (final sc in s.scorches) {
      final c = v.toScreen(sc.col, tankSurfaceY(h, sc.col));
      final r = sc.radius * v.scale * 1.1;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            Colors.black.withValues(alpha: 0.42),
            Colors.black.withValues(alpha: 0),
          ]),
      );
    }
    canvas.restore();

    // 지표면 테두리
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, v.scale * 0.5)
        ..strokeJoin = StrokeJoin.round
        ..color = look.surface,
    );
    _surfaceDecor(canvas, look, h, colStart, colEnd);
  }

  void _surfaceDecor(
    Canvas canvas,
    TankThemeLook look,
    List<double> h,
    int colStart,
    int colEnd,
  ) {
    final u = v.scale;
    switch (look.weather) {
      case TankWeather.leaves:
        final blade = Paint()
          ..strokeWidth = math.max(1.0, u * 0.14)
          ..strokeCap = StrokeCap.round;
        for (int c = colStart; c <= colEnd; c++) {
          final base = v.toScreen(c.toDouble(), kTerrainH - h[c] - 0.5);
          for (int k = 0; k < 3; k++) {
            final x =
                base.dx +
                (k - 1) * u * 0.3 +
                (_hash(c * 3 + k, 31) - 0.5) * u * 0.2;
            final len = u * (0.45 + _hash(c * 3 + k, 32) * 0.6);
            final sway = math.sin(s.time * 2 + c * 0.7 + k) * u * 0.12;
            blade.color = k == 1 ? const Color(0xFF4E8F2E) : look.surface;
            canvas.drawLine(
              Offset(x, base.dy),
              Offset(x + sway + (k - 1) * u * 0.15, base.dy - len),
              blade,
            );
          }
          if (_hash(c, 33) > 0.88) {
            canvas.drawCircle(
              base.translate(0, -u * 0.7),
              math.max(1.5, u * 0.18),
              Paint()
                ..color = _hash(c, 34) > 0.5
                    ? const Color(0xFFFF8FB1)
                    : const Color(0xFFFFE066),
            );
          }
        }
        break;
      case TankWeather.sand:
        final ripple = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, u * 0.12)
          ..color = _a(look.groundDeep, 0.25);
        for (int c = colStart; c <= colEnd; c += 2) {
          final base = v.toScreen(c.toDouble(), kTerrainH - h[c] - 0.5 + 0.9);
          canvas.drawArc(
            Rect.fromCenter(center: base, width: u * 1.4, height: u * 0.5),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            ripple,
          );
        }
        break;
      case TankWeather.snow:
        final sparkle = Paint()..strokeWidth = 1;
        for (int c = colStart; c <= colEnd; c++) {
          if (_hash(c, 41) > 0.3) continue;
          final tw = 0.5 + 0.5 * math.sin(s.time * 3 + c);
          sparkle.color = Colors.white.withValues(alpha: tw);
          final p = v.toScreen(c.toDouble(), kTerrainH - h[c] - 0.5 - 0.1);
          final r = math.max(1.5, u * 0.22) * tw;
          canvas.drawLine(p.translate(-r, 0), p.translate(r, 0), sparkle);
          canvas.drawLine(p.translate(0, -r), p.translate(0, r), sparkle);
        }
        break;
      case TankWeather.stars:
        for (int c = colStart; c <= colEnd; c++) {
          if (_hash(c, 51) > 0.12) continue;
          final p = v.toScreen(c.toDouble(), kTerrainH - h[c] - 0.5 + 0.9);
          final rect = Rect.fromCenter(
            center: p,
            width: u * (1.2 + _hash(c, 52)),
            height: u * 0.5,
          );
          canvas.drawOval(rect, Paint()..color = _a(look.groundDeep, 0.5));
          canvas.drawArc(
            rect,
            0,
            math.pi,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, u * 0.1)
              ..color = _a(look.surface, 0.6),
          );
        }
        break;
    }
  }

  // ── 보급 상자 ──────────────────────────────────────────────────────────────

  void _crates(Canvas canvas, List<double> h) {
    final u = v.scale;
    for (final raw in (s.state['crates'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final col = (raw['col'] as num).toDouble();
      final row = (raw['row'] as num).toDouble();
      // 서버의 보급 상자 id는 'c1' 같은 문자열이다.
      final id = raw['id']?.toString() ?? '';
      final appear = s.crateDrops[id];
      double fall = 0;
      double canopyAlpha = 0;
      double sway = 0;
      if (appear != null) {
        final k = ((s.time - appear) / 1.4).clamp(0.0, 1.0);
        fall = (1 - _easeOut(k)) * 22;
        sway = math.sin((s.time - appear) * 5) * (1 - k) * 0.35;
        canopyAlpha = k < 1
            ? 1
            : (1 - ((s.time - appear - 1.4) / 0.5)).clamp(0.0, 1.0);
      }
      final bottom = v.toScreen(col, row + 0.5 - fall);
      canvas.save();
      canvas.translate(bottom.dx, bottom.dy);
      canvas.rotate(sway);
      final w = u * 2.0;
      final hh = u * 1.6;
      if (canopyAlpha > 0) {
        final canopy = Rect.fromCenter(
          center: Offset(0, -hh - u * 2.4),
          width: w * 2.1,
          height: u * 2.2,
        );
        canvas.drawArc(
          canopy,
          math.pi,
          math.pi,
          true,
          Paint()..color = _a(const Color(0xFFFF6F91), canopyAlpha * 0.95),
        );
        canvas.drawArc(
          canopy.deflate(canopy.width * 0.3),
          math.pi,
          math.pi,
          true,
          Paint()..color = _a(Colors.white, canopyAlpha * 0.6),
        );
        final cord = Paint()
          ..color = _a(Colors.white, canopyAlpha * 0.8)
          ..strokeWidth = 1;
        canvas.drawLine(canopy.centerLeft, Offset(-w / 2, -hh), cord);
        canvas.drawLine(canopy.centerRight, Offset(w / 2, -hh), cord);
      } else {
        // 착지한 상자는 금빛으로 은은하게 빛난다.
        final pulse = 0.5 + 0.5 * math.sin(s.time * 4 + id.hashCode % 7);
        canvas.drawCircle(
          Offset(0, -hh / 2),
          w * 0.9,
          Paint()
            ..shader = ui.Gradient.radial(Offset(0, -hh / 2), w * 0.9, [
              _a(TankUi.gold, 0.35 * pulse),
              _a(TankUi.gold, 0),
            ]),
        );
      }
      final box = Rect.fromLTWH(-w / 2, -hh, w, hh);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(u * 0.2)),
        Paint()..color = const Color(0xFFC98A3C),
      );
      final plank = Paint()
        ..color = const Color(0xFF8A5A1E)
        ..strokeWidth = math.max(1.0, u * 0.14);
      canvas.drawLine(box.topLeft, box.bottomRight, plank);
      canvas.drawLine(box.topRight, box.bottomLeft, plank);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(u * 0.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, u * 0.16)
          ..color = const Color(0xFF6B4415),
      );
      canvas.restore();
    }
  }

  // ── 전차 ───────────────────────────────────────────────────────────────────

  void _tanks(Canvas canvas, TankThemeLook look, List<double>? terrain) {
    final players = (s.state['players'] as List?) ?? const [];
    final pb = s.playback;
    final turn = (s.state['turn'] as num?)?.toInt() ?? 0;
    final aimingPhase = s.state['phase'] == 'aiming';
    for (int i = 0; i < players.length; i++) {
      final raw = players[i];
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final col = (p['col'] as num).toDouble();
      final row = (p['row'] as num).toDouble();
      final mine = i == s.myIndex;
      final hp = (p['hp'] as num?)?.toInt() ?? 0;
      final maxHp = math.max(1, (p['maxHp'] as num?)?.toInt() ?? 100);
      final destroyed = hp <= 0;
      final facingRight = p['facingRight'] == true;
      double angle = mine
          ? s.myAngle
          : (s.opponentAngle ?? (facingRight ? 45.0 : 135.0));

      double flash = 0;
      double knock = 0;
      double recoil = 0;
      if (pb != null) {
        for (final hit in pb.hits) {
          if (hit.target != i) continue;
          final dt = s.playMs - pb.boomStart(hit.stage);
          if (dt >= 0 && dt < 220) {
            flash = math.max(flash, 1 - dt / 220);
            final boom = pb.booms.firstWhere(
              (b) => b.stage == hit.stage,
              orElse: () => TankBoom(col, row, 1, 0, TankBoomKind.blast),
            );
            final dir = col >= boom.col ? 1.0 : -1.0;
            knock = dir * math.sin(dt / 220 * math.pi) * 0.5;
          }
        }
        if (pb.shooter == i) {
          angle = pb.angle;
          if (s.playMs < 260) recoil = 1 - s.playMs / 260;
        }
      }

      final base = v.toScreen(col + knock, row + 0.5);
      if (destroyed) _wreckSmoke(canvas, base);
      paintTank(
        canvas,
        base: base,
        u: v.scale,
        cls: p['tankClass'] as String?,
        team: mine ? TankUi.me : TankUi.enemy,
        angle: destroyed ? (facingRight ? -12.0 : 192.0) : angle,
        recoil: recoil,
        flash: flash,
        destroyed: destroyed,
        shield: (p['buffs'] as Map?)?['shield'] == true,
        powered: (p['buffs'] as Map?)?['power'] == true,
        time: s.time,
      );
      _tag(
        canvas,
        base,
        name: mine ? s.myName : s.oppName,
        team: mine ? TankUi.me : TankUi.enemy,
        ratio: hp / maxHp,
        active: aimingPhase && turn == i && pb == null,
        mine: mine,
      );
    }
  }

  void _wreckSmoke(Canvas canvas, Offset base) {
    final u = v.scale;
    for (int i = 0; i < 7; i++) {
      final phase = (s.time * 0.32 + i / 7) % 1.0;
      final p = base.translate(
        math.sin(phase * 5 + i) * u * 0.7,
        -(1.6 + phase * 8) * u,
      );
      canvas.drawCircle(
        p,
        (0.6 + phase * 1.8) * u,
        Paint()..color = _a(const Color(0xFF3C3C46), (1 - phase) * 0.5),
      );
    }
    final ember = 0.5 + 0.5 * math.sin(s.time * 9);
    canvas.drawCircle(
      base.translate(0, -u * 1.2),
      u * 0.9,
      Paint()
        ..shader = ui.Gradient.radial(base.translate(0, -u * 1.2), u * 0.9, [
          _a(const Color(0xFFFF7A2F), 0.55 * ember),
          _a(const Color(0xFFFF7A2F), 0),
        ]),
    );
  }

  void _tag(
    Canvas canvas,
    Offset base, {
    required String name,
    required Color team,
    required double ratio,
    required bool active,
    required bool mine,
  }) {
    final u = v.scale;
    final y = base.dy - u * 4.4 - 18;
    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 90);
    final w = math.max(44.0, tp.width + 14);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(base.dx, y), width: w, height: 24),
      const Radius.circular(7),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xC0101624));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.6 : 1
        ..color = _a(team, active ? 1 : 0.55),
    );
    tp.paint(canvas, Offset(base.dx - tp.width / 2, y - 10));
    // HP 미니 바
    final barW = w - 10;
    final bar = Rect.fromLTWH(base.dx - barW / 2, y + 5, barW, 3.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final r = ratio.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bar.left, bar.top, bar.width * r, bar.height),
        const Radius.circular(2),
      ),
      Paint()
        ..color = r > 0.5
            ? TankUi.me
            : r > 0.25
            ? TankUi.gold
            : TankUi.danger,
    );
    if (active) {
      final bob = math.sin(s.time * 6) * 3;
      final tip = Offset(base.dx, y - 16 + bob);
      final marker = Path()
        ..moveTo(tip.dx - 6, tip.dy - 7)
        ..lineTo(tip.dx + 6, tip.dy - 7)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(marker, Paint()..color = team);
    }
  }

  // ── 조준 ───────────────────────────────────────────────────────────────────

  Offset? _myTurret() {
    final players = (s.state['players'] as List?) ?? const [];
    if (s.myIndex >= players.length) return null;
    final p = players[s.myIndex];
    if (p is! Map) return null;
    final col = (p['col'] as num).toDouble();
    final row = (p['row'] as num).toDouble();
    return v.toScreen(col, row + 0.5 - 1.9);
  }

  void _lastTrace(Canvas canvas) {
    if (s.lastTrace.length < 2) return;
    final p = Paint()..color = Colors.white.withValues(alpha: 0.26);
    for (int i = 0; i < s.lastTrace.length; i += 3) {
      final pt = v.toScreen(s.lastTrace[i].dx, s.lastTrace[i].dy);
      canvas.drawCircle(pt, math.max(1.0, v.scale * 0.13), p);
    }
  }

  void _aimGuide(Canvas canvas) {
    final pts = s.preview;
    if (pts.length >= 2) {
      final shadow = Paint()..color = Colors.black.withValues(alpha: 0.25);
      final dot = Paint();
      for (int i = 1; i < pts.length; i += 2) {
        final fade = 1.0 - (i / pts.length) * 0.8;
        final pt = v.toScreen(pts[i].dx, pts[i].dy);
        final r = math.max(1.8, v.scale * 0.24) * (0.7 + fade * 0.5);
        canvas.drawCircle(pt.translate(0.8, 1), r, shadow);
        dot.color = Colors.white.withValues(alpha: 0.9 * fade);
        canvas.drawCircle(pt, r, dot);
      }
    }
    // 각도·파워 표시
    final turret = _myTurret();
    if (turret == null) return;
    final rad = -s.myAngle * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    final len = v.scale * (3 + s.myPower / 100 * 5);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _a(TankUi.me, 0.55);
    canvas.drawArc(
      Rect.fromCircle(center: turret, radius: v.scale * 3.2),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.drawArc(
      Rect.fromCircle(center: turret, radius: v.scale * 3.2),
      0,
      rad,
      false,
      arc,
    );
    final end = turret + dir * len;
    canvas.drawLine(
      turret + dir * (v.scale * 2.4),
      end,
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(turret, end, [
          _a(TankUi.gold, 0.2),
          TankUi.gold,
        ]),
    );
    final head = Path()
      ..moveTo(end.dx + dir.dx * 7, end.dy + dir.dy * 7)
      ..lineTo(end.dx - dir.dy * 5, end.dy + dir.dx * 5)
      ..lineTo(end.dx + dir.dy * 5, end.dy - dir.dx * 5)
      ..close();
    canvas.drawPath(head, Paint()..color = TankUi.gold);
  }

  void _dragGuide(Canvas canvas) {
    final d = s.dragPoint;
    final turret = _myTurret();
    if (d == null || turret == null) return;
    canvas.drawLine(
      turret,
      d,
      Paint()
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      d,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TankUi.gold,
    );
    canvas.drawCircle(d, 4, Paint()..color = TankUi.gold);
  }

  // ── 재생: 발사·포탄·폭발 ───────────────────────────────────────────────────

  void _playback(
    Canvas canvas,
    TankPlayback pb,
    TankThemeLook look,
    List<double>? terrain,
  ) {
    final t = s.playMs;
    final u = v.scale;
    final players = (s.state['players'] as List?) ?? const [];

    // 포구 섬광과 연기
    if (pb.shooter < players.length && players[pb.shooter] is Map) {
      final p = players[pb.shooter] as Map;
      final base = v.toScreen(
        (p['col'] as num).toDouble(),
        (p['row'] as num).toDouble() + 0.5,
      );
      final cls = p['tankClass'] as String?;
      final rad = -pb.angle * math.pi / 180;
      final dir = Offset(math.cos(rad), math.sin(rad));
      final tip =
          base + tankTurretOffset(cls) * u + dir * (tankBarrelLength(cls) * u);
      if (t < 160) {
        final k = t / 160;
        final r = u * (1.2 + k * 1.4);
        canvas.drawCircle(
          tip,
          r * 1.6,
          Paint()
            ..shader = ui.Gradient.radial(
              tip,
              r * 1.6,
              [
                _a(Colors.white, 1 - k),
                _a(const Color(0xFFFFC94A), (1 - k) * 0.8),
                _a(const Color(0xFFFF7A2F), 0),
              ],
              const [0, 0.4, 1],
            ),
        );
        final star = Path();
        for (int i = 0; i < 10; i++) {
          final a = rad + i * math.pi / 5;
          final rr = i.isEven ? r * 1.7 : r * 0.6;
          final pt = tip + Offset(math.cos(a), math.sin(a)) * rr;
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(
          star,
          Paint()..color = _a(const Color(0xFFFFF3C4), 1 - k),
        );
      }
      if (t < 1000) {
        final k = t / 1000;
        for (int i = 0; i < 5; i++) {
          final spread = (i - 2) * 0.35;
          final d = Offset(math.cos(rad + spread), math.sin(rad + spread));
          final pt =
              tip +
              d * (u * (0.8 + k * 3 * (0.6 + _hash(i, 61) * 0.6))) +
              Offset(0, -k * u * 1.5);
          canvas.drawCircle(
            pt,
            u * (0.5 + k * 1.1),
            Paint()..color = _a(const Color(0xFFE6E6EE), (1 - k) * 0.55),
          );
        }
      }
    }

    // 포탄
    for (final shell in pb.shells) {
      final st = shell.stage;
      if (st >= pb.stageCount) continue;
      final start = pb.stageStartMs[st];
      final flight = pb.stageFlightMs[st];
      final k = flight <= 0 ? 1.0 : (t - start) / flight;
      if (k < 0 || k > 1) continue;
      _shell(canvas, shell, k, u);
    }

    // 폭발
    for (final b in pb.booms) {
      final bt = t - pb.boomAt(b);
      if (bt < 0) continue;
      _boom(canvas, b, bt, u, look);
    }
  }

  void _shell(Canvas canvas, TankShellTrack shell, double k, double u) {
    final pts = shell.path;
    final head = (k * (pts.length - 1)).round().clamp(0, pts.length - 1);
    final hp = v.toScreen(pts[head].dx, pts[head].dy);
    final prev = pts[math.max(0, head - 1)];
    final dirW = pts[head] - prev;
    final ang = dirW.distance == 0 ? 0.0 : math.atan2(dirW.dy, dirW.dx);
    final weapon = shell.stage > 0 && shell.weapon == 'cluster'
        ? 'bomblet'
        : shell.weapon;

    final (Color trail, Color core, double size, int len) = switch (weapon) {
      'heavy' => (const Color(0xFFFF5A2A), const Color(0xFF2B1A12), 0.6, 18),
      'triple' || 'shotgun' => (const Color(0xFFFFD27A), Colors.white, 0.3, 8),
      'cluster' => (const Color(0xFFB0B8C4), const Color(0xFF5D6670), 0.5, 14),
      'bomblet' => (const Color(0xFFFFB04A), const Color(0xFF30343A), 0.3, 7),
      'teleport' => (TankUi.purple, Colors.white, 0.45, 16),
      'quake' => (const Color(0xFFD7B98A), const Color(0xFF6D4C2F), 0.62, 18),
      'drill' => (const Color(0xFFB8C4CC), const Color(0xFFE6ECF0), 0.45, 10),
      'wall' => (const Color(0xFF9CCC65), const Color(0xFF6D4C2F), 0.5, 12),
      _ => (const Color(0xFFFF9A3D), const Color(0xFFFFF59D), 0.42, 13),
    };

    for (int i = math.max(0, head - len); i < head; i++) {
      final f = 1.0 - (head - i) / len;
      final p = v.toScreen(pts[i].dx, pts[i].dy);
      final jitter = weapon == 'teleport'
          ? Offset(
              (_hash(i, 71) - 0.5) * u * 0.8,
              (_hash(i, 72) - 0.5) * u * 0.8,
            )
          : Offset.zero;
      canvas.drawCircle(
        p + jitter,
        math.max(1.0, u * size * (0.3 + f * 0.7)),
        Paint()..color = _a(trail, 0.6 * f),
      );
    }

    final r = math.max(2.5, u * size);
    if (weapon == 'drill') {
      canvas.save();
      canvas.translate(hp.dx, hp.dy);
      canvas.rotate(ang);
      final cone = Path()
        ..moveTo(r * 1.8, 0)
        ..lineTo(-r * 0.9, -r * 0.8)
        ..lineTo(-r * 0.9, r * 0.8)
        ..close();
      canvas.drawPath(cone, Paint()..color = core);
      final spiral = Paint()
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7A8890);
      for (int i = 0; i < 3; i++) {
        final x = -r * 0.5 + i * r * 0.6 + (s.time * 40 % (r * 0.6));
        canvas.drawLine(
          Offset(x, -r * 0.6),
          Offset(x + r * 0.3, r * 0.6),
          spiral,
        );
      }
      canvas.restore();
      return;
    }
    canvas.drawCircle(
      hp,
      r * 2.4,
      Paint()
        ..shader = ui.Gradient.radial(hp, r * 2.4, [
          _a(trail, 0.55),
          _a(trail, 0),
        ]),
    );
    if (weapon == 'quake') {
      final ring = (s.time * 3) % 1.0;
      canvas.drawCircle(
        hp,
        r * (1.2 + ring * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _a(trail, 1 - ring),
      );
    }
    canvas.drawCircle(hp, r, Paint()..color = core);
    if (weapon == 'cluster') {
      canvas.drawCircle(
        hp + Offset(math.cos(ang), math.sin(ang)) * r * 0.7,
        r * 0.45,
        Paint()..color = const Color(0xFFFF4D4D),
      );
    } else if (weapon != 'heavy' && weapon != 'quake' && weapon != 'bomblet') {
      canvas.drawCircle(hp, r * 0.45, Paint()..color = Colors.white);
    }
  }

  void _boom(
    Canvas canvas,
    TankBoom b,
    double bt,
    double u,
    TankThemeLook look,
  ) {
    final c = v.toScreen(b.col, b.row);
    final r = b.radius * u;
    switch (b.kind) {
      case TankBoomKind.split:
        if (bt > 260) return;
        final k = bt / 260;
        canvas.drawCircle(
          c,
          u * (0.6 + k * 1.6),
          Paint()..color = _a(const Color(0xFFFFF3C4), 1 - k),
        );
        return;
      case TankBoomKind.teleport:
        if (bt > 700) return;
        final k = bt / 700;
        canvas.drawCircle(
          c,
          r * (1.6 - k * 1.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - k) + 1
            ..color = _a(TankUi.purple, 1 - k),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: c.translate(0, -u * 6),
            width: u * 1.6 * (1 - k),
            height: u * 12,
          ),
          Paint()
            ..shader = ui.Gradient.linear(c.translate(0, -u * 12), c, [
              _a(TankUi.purple, 0),
              _a(Colors.white, 0.8 * (1 - k)),
            ]),
        );
        for (int i = 0; i < 12; i++) {
          final a = i * math.pi / 6 + k * 2;
          final d = r * (0.4 + k * 1.4);
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * d,
            math.max(1.2, u * 0.2) * (1 - k),
            Paint()..color = _a(Colors.white, 1 - k),
          );
        }
        return;
      case TankBoomKind.mound:
        if (bt > 900) return;
        final k = bt / 900;
        for (int i = 0; i < 14; i++) {
          final x = (_hash(i, 81) - 0.5) * r * 2.2;
          final rise = (0.3 + _hash(i, 82)) * u * 6 * _easeOut(k);
          canvas.drawCircle(
            c.translate(x, -rise),
            u * (0.5 + _hash(i, 83) * 0.8) * (1 + k),
            Paint()..color = _a(const Color(0xFFB08A5A), (1 - k) * 0.7),
          );
        }
        return;
      case TankBoomKind.blast:
      case TankBoomKind.quake:
      case TankBoomKind.drill:
      case TankBoomKind.ko:
        break;
    }

    final big = b.kind == TankBoomKind.ko || b.kind == TankBoomKind.quake;
    final dur = big ? 1000.0 : 650.0;
    final smokeDur = big ? 2200.0 : 1500.0;

    // 연기(가장 오래 남는다)
    if (bt < smokeDur) {
      final k = bt / smokeDur;
      final n = big ? 10 : 7;
      for (int i = 0; i < n; i++) {
        final a = _hash(i + b.stage * 13, 91) * math.pi * 2;
        final d = r * (0.3 + _hash(i, 92) * 0.7) * (0.6 + k);
        final pt =
            c + Offset(math.cos(a) * d, math.sin(a) * d * 0.5 - k * u * 4);
        canvas.drawCircle(
          pt,
          r * (0.35 + k * 0.6),
          Paint()..color = _a(const Color(0xFF4A4A55), (1 - k) * 0.45),
        );
      }
    }
    if (bt > dur) return;
    final k = bt / dur;
    final e = _easeOut(k);

    // 지진탄: 땅을 따라 퍼지는 충격파
    if (b.kind == TankBoomKind.quake) {
      for (int i = 0; i < 2; i++) {
        final kk = (k - i * 0.15).clamp(0.0, 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: c,
            width: r * (1 + kk * 5),
            height: r * (0.25 + kk * 0.6),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.8 * (1 - kk)
            ..color = _a(const Color(0xFFE8D2A6), (1 - kk) * 0.8),
        );
      }
    }

    // 섬광
    if (bt < 90) {
      canvas.drawCircle(
        c,
        r * 0.9,
        Paint()..color = _a(Colors.white, 1 - bt / 90),
      );
    }
    // 불덩이
    final fr = r * (0.55 + e * 1.25);
    canvas.drawCircle(
      c,
      fr,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          fr,
          [
            _a(const Color(0xFFFFFDE7), 1 - k),
            _a(const Color(0xFFFFD54F), (1 - k) * 0.95),
            _a(const Color(0xFFFF7043), (1 - k) * 0.85),
            _a(const Color(0xFFB71C1C), 0),
          ],
          const [0, 0.25, 0.6, 1],
        ),
    );
    if (b.kind == TankBoomKind.ko) {
      // 연쇄 폭발
      for (int i = 0; i < 3; i++) {
        final kk = ((bt - 140 - i * 120) / 500).clamp(0.0, 1.0);
        if (kk <= 0 || kk >= 1) continue;
        final cc = c + Offset((i - 1) * r * 0.5, -r * 0.3 * i);
        canvas.drawCircle(
          cc,
          r * 0.5 * (0.5 + kk),
          Paint()..color = _a(const Color(0xFFFFB74D), (1 - kk) * 0.9),
        );
      }
    }
    // 충격파 고리
    canvas.drawCircle(
      c,
      r * (0.6 + e * 2.3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, u * 0.5 * (1 - k))
        ..color = Colors.white.withValues(alpha: (1 - k) * 0.6),
    );
    // 파편(포물선)
    final count = big ? 26 : (b.kind == TankBoomKind.drill ? 22 : 16);
    final sec = bt / 1000;
    for (int i = 0; i < count; i++) {
      final seed = i + b.stage * 31 + b.col.round();
      final up = b.kind == TankBoomKind.drill ? 0.5 : 0.0;
      final a =
          -math.pi * (0.1 + _hash(seed, 101) * 0.8) -
          up * (_hash(seed, 104) - 0.5);
      final speed = (6 + _hash(seed, 102) * 10) * (b.radius / 4 + 0.4);
      final vx = math.cos(a) * speed;
      final vy = math.sin(a) * speed;
      final pos = Offset(
        b.col + vx * sec,
        b.row + vy * sec + 0.5 * 26 * sec * sec,
      );
      final metal = b.kind == TankBoomKind.ko && i.isEven;
      canvas.drawCircle(
        v.toScreen(pos.dx, pos.dy),
        math.max(1.2, u * (0.15 + _hash(seed, 103) * 0.22)),
        Paint()
          ..color = _a(
            metal
                ? const Color(0xFF2B2B33)
                : (i % 3 == 0 ? look.groundDeep : look.groundTop),
            1 - k,
          ),
      );
    }
    // 불티(드릴·격파)
    if (b.kind == TankBoomKind.drill || b.kind == TankBoomKind.ko) {
      final spark = Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 10; i++) {
        final a = -math.pi * _hash(i, 111);
        final d = r * (0.5 + e * 2) * (0.6 + _hash(i, 112) * 0.6);
        final p0 = c + Offset(math.cos(a), math.sin(a)) * d;
        final p1 = c + Offset(math.cos(a), math.sin(a)) * (d + u * 0.9);
        spark.color = _a(const Color(0xFFFFE082), 1 - k);
        canvas.drawLine(p0, p1, spark);
      }
    }
  }

  // ── 팝업 ───────────────────────────────────────────────────────────────────

  void _popups(Canvas canvas, TankPlayback? pb) {
    if (pb == null) return;
    final players = (s.state['players'] as List?) ?? const [];
    for (final popup in pb.popups) {
      final at = pb.boomStart(popup.stage) + popup.delayMs;
      final k = (s.playMs - at) / 1300;
      if (k < 0 || k > 1) continue;
      Offset anchor;
      if (popup.target >= 0 &&
          popup.target < players.length &&
          players[popup.target] is Map) {
        final p = players[popup.target] as Map;
        anchor = v
            .toScreen(
              (p['col'] as num).toDouble(),
              (p['row'] as num).toDouble() + 0.5,
            )
            .translate(0, -v.scale * 4.4 - 46);
      } else {
        anchor = v.toScreen(popup.col, popup.row);
      }
      final scale = k < 0.12 ? 1.45 - (k / 0.12) * 0.45 : 1.0;
      final alpha = k < 0.65 ? 1.0 : 1 - (k - 0.65) / 0.35;
      final fontSize = popup.size * scale;
      final stroke = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = Colors.black.withValues(alpha: 0.65 * alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fill = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: _a(popup.color, alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(
        anchor.dx - fill.width / 2,
        anchor.dy - 30 * _easeOut(k) - fill.height / 2,
      );
      stroke.paint(canvas, pos);
      fill.paint(canvas, pos);
    }
  }

  // ── 날씨 ───────────────────────────────────────────────────────────────────

  void _weather(Canvas canvas, Size size, TankThemeLook look) {
    final wind = (s.state['wind'] as num?)?.toDouble() ?? 0;
    final w = size.width;
    final h = size.height;
    final time = s.time;
    switch (look.weather) {
      case TankWeather.snow:
        final flake = Paint();
        for (int i = 0; i < 80; i++) {
          final speed = 22 + _hash(i, 121) * 30;
          final y = (_hash(i, 122) * h + time * speed) % (h + 10) - 5;
          final x =
              ((_hash(i, 123) * w +
                              time * wind * 34 +
                              math.sin(time * 1.3 + i) * 10) %
                          (w + 20) +
                      (w + 20)) %
                  (w + 20) -
              10;
          flake.color = Colors.white.withValues(
            alpha: 0.55 + _hash(i, 124) * 0.4,
          );
          canvas.drawCircle(Offset(x, y), 1 + _hash(i, 125) * 1.8, flake);
        }
        break;
      case TankWeather.sand:
        final dir = wind < 0 ? -1.0 : 1.0;
        final streak = Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        for (int i = 0; i < 45; i++) {
          final speed = 70 + wind.abs() * 90 + _hash(i, 131) * 60;
          final x =
              ((_hash(i, 132) * w + time * speed * dir) % (w + 40) + (w + 40)) %
                  (w + 40) -
              20;
          final y = h * (0.25 + _hash(i, 133) * 0.7);
          final len = 8 + _hash(i, 134) * 18;
          streak.color = _a(
            const Color(0xFFFFF1D6),
            0.18 + _hash(i, 135) * 0.2,
          );
          canvas.drawLine(Offset(x, y), Offset(x - len * dir, y), streak);
        }
        break;
      case TankWeather.leaves:
        for (int i = 0; i < 12; i++) {
          final speedX = 18 + wind * 40 + _hash(i, 141) * 12;
          final speedY = 14 + _hash(i, 142) * 16;
          final x =
              ((_hash(i, 143) * w + time * speedX) % (w + 40) + (w + 40)) %
                  (w + 40) -
              20;
          final y = (_hash(i, 144) * h + time * speedY) % (h + 20) - 10;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(time * (1 + _hash(i, 145) * 2) + i);
          canvas.drawOval(
            const Rect.fromLTWH(-4, -2, 8, 4),
            Paint()
              ..color = i.isEven
                  ? const Color(0xCCFFB7C5)
                  : const Color(0xCC9BD65A),
          );
          canvas.restore();
        }
        break;
      case TankWeather.stars:
        final phase = time % 9.0;
        if (phase < 0.9) {
          final k = phase / 0.9;
          final start = Offset(w * (0.15 + (time ~/ 9 % 3) * 0.2), h * 0.08);
          final head = start + Offset(w * 0.35 * k, h * 0.18 * k);
          canvas.drawLine(
            head - Offset(w * 0.08, h * 0.04),
            head,
            Paint()
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..shader = ui.Gradient.linear(
                head - Offset(w * 0.08, h * 0.04),
                head,
                [_a(Colors.white, 0), _a(Colors.white, 1 - k)],
              ),
          );
        }
        break;
    }
  }

  /// 포탄이 화면 위로 벗어나면 위쪽 가장자리에 화살표로 위치를 알려준다.
  void _offscreenMarker(Canvas canvas, Size size, TankPlayback pb) {
    for (final shell in pb.shells) {
      final st = shell.stage;
      if (st >= pb.stageCount) continue;
      final flight = pb.stageFlightMs[st];
      final k = flight <= 0 ? 1.0 : (s.playMs - pb.stageStartMs[st]) / flight;
      if (k < 0 || k > 1) continue;
      final pts = shell.path;
      final head = (k * (pts.length - 1)).round().clamp(0, pts.length - 1);
      final p = v.toScreen(pts[head].dx, pts[head].dy);
      if (p.dy >= 6) continue;
      final x = p.dx.clamp(14.0, size.width - 14);
      final marker = Path()
        ..moveTo(x, 4)
        ..lineTo(x - 7, 15)
        ..lineTo(x + 7, 15)
        ..close();
      canvas.drawPath(marker, Paint()..color = TankUi.gold);
      return;
    }
  }

  @override
  bool shouldRepaint(TankBattlefieldPainter old) => true;
}

// ── 전차 그리기(선택 화면에서도 쓴다) ─────────────────────────────────────────

/// 포탑 회전축의 위치(전차 바닥 중심 기준, 칸 단위).
Offset tankTurretOffset(String? cls) => switch (cls) {
  'rhino' => const Offset(0, -2.25),
  'falcon' => const Offset(0, -1.65),
  'turtle' => const Offset(0, -1.95),
  _ => const Offset(0, -1.9),
};

double tankBarrelLength(String? cls) => switch (cls) {
  'rhino' => 2.6,
  'falcon' => 2.9,
  'turtle' => 2.0,
  _ => 2.4,
};

/// [base]: 전차 바닥 중심(화면 좌표). [u]: 한 칸의 픽셀 크기.
/// [angle]: 포신 각도(0=오른쪽, 90=위, 180=왼쪽).
void paintTank(
  Canvas canvas, {
  required Offset base,
  required double u,
  required String? cls,
  required Color team,
  required double angle,
  double recoil = 0,
  double flash = 0,
  bool destroyed = false,
  bool shield = false,
  bool powered = false,
  double time = 0,
}) {
  final facingRight = angle <= 90 || angle > 270;
  final main = destroyed
      ? Color.lerp(team, const Color(0xFF34343A), 0.8)!
      : team;
  final dark = Color.lerp(main, Colors.black, 0.45)!;
  final light = Color.lerp(main, Colors.white, 0.3)!;
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.09
    ..strokeJoin = StrokeJoin.round
    ..color = Color.lerp(main, Colors.black, 0.6)!;

  final width = switch (cls) {
    'rhino' => 4.3,
    'falcon' => 3.4,
    _ => 3.7,
  };

  if (powered && !destroyed) {
    final g = base.translate(0, -u * 1.0);
    canvas.drawCircle(
      g,
      u * 3,
      Paint()
        ..shader = ui.Gradient.radial(g, u * 3, [
          _a(const Color(0xFFFF7A2F), 0.4 + 0.15 * math.sin(time * 6)),
          _a(const Color(0xFFFF7A2F), 0),
        ]),
    );
  }

  if (flash > 0) {
    canvas.saveLayer(
      Rect.fromCenter(
        center: base.translate(0, -u * 2),
        width: u * 12,
        height: u * 8,
      ),
      Paint()
        ..colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: flash.clamp(0.0, 1.0) * 0.85),
          BlendMode.srcATop,
        ),
    );
  }

  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.scale(u, u);

  // 그림자
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(0, 0.05),
      width: width + 1.0,
      height: 0.45,
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.25),
  );

  canvas.save();
  if (!facingRight) canvas.scale(-1, 1);

  // 궤도
  final trackRect = Rect.fromLTRB(-width / 2 - 0.3, -0.8, width / 2 + 0.3, 0);
  canvas.drawRRect(
    RRect.fromRectAndRadius(trackRect, const Radius.circular(0.4)),
    Paint()..color = const Color(0xFF2A2C33),
  );
  final wheels = (width / 0.85).floor();
  final wheelPaint = Paint()..color = const Color(0xFF5A5E68);
  final hubPaint = Paint()..color = const Color(0xFF9AA0AA);
  for (int i = 0; i < wheels; i++) {
    final x = -width / 2 + 0.15 + i * (width - 0.3) / math.max(1, wheels - 1);
    canvas.drawCircle(Offset(x, -0.4), 0.27, wheelPaint);
    canvas.drawCircle(Offset(x, -0.4), 0.1, hubPaint);
  }

  // 차체
  final hullTop = switch (cls) {
    'rhino' => -1.7,
    'falcon' => -1.25,
    _ => -1.45,
  };
  final hull = Path();
  switch (cls) {
    case 'falcon':
      hull
        ..moveTo(-width / 2, -0.75)
        ..lineTo(width / 2 + 0.25, -0.75)
        ..lineTo(width / 2 - 0.5, hullTop)
        ..lineTo(-width / 2 + 0.2, hullTop - 0.05)
        ..close();
      break;
    case 'rhino':
      hull
        ..moveTo(-width / 2 - 0.1, -0.7)
        ..lineTo(width / 2 + 0.1, -0.7)
        ..lineTo(width / 2 - 0.25, hullTop)
        ..lineTo(-width / 2 + 0.35, hullTop)
        ..close();
      break;
    default:
      hull
        ..moveTo(-width / 2, -0.72)
        ..lineTo(width / 2, -0.72)
        ..lineTo(width / 2 - 0.4, hullTop)
        ..lineTo(-width / 2 + 0.5, hullTop)
        ..close();
  }
  canvas.drawPath(
    hull,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, hullTop),
        const Offset(0, -0.7),
        [light, main, dark],
        const [0, 0.45, 1],
      ),
  );
  canvas.drawPath(hull, outline);

  // 장갑 덧판·장식
  switch (cls) {
    case 'rhino':
      final skirt = RRect.fromRectAndRadius(
        Rect.fromLTRB(-width / 2 - 0.2, -1.0, width / 2 + 0.15, -0.55),
        const Radius.circular(0.12),
      );
      canvas.drawRRect(skirt, Paint()..color = dark);
      final rivet = Paint()..color = light;
      for (int i = 0; i < 5; i++) {
        canvas.drawCircle(
          Offset(-width / 2 + 0.2 + i * (width - 0.4) / 4, -0.78),
          0.07,
          rivet,
        );
      }
      break;
    case 'falcon':
      final fin = Path()
        ..moveTo(-width / 2 + 0.25, hullTop)
        ..lineTo(-width / 2 - 0.2, hullTop - 0.85)
        ..lineTo(-width / 2 + 0.85, hullTop)
        ..close();
      canvas.drawPath(fin, Paint()..color = dark);
      canvas.drawLine(
        Offset(-width / 2 + 0.6, -1.0),
        Offset(width / 2 - 0.6, -1.0),
        Paint()
          ..strokeWidth = 0.1
          ..color = Colors.white.withValues(alpha: destroyed ? 0.1 : 0.6),
      );
      break;
    case 'mole':
      final drill = Path()
        ..moveTo(width / 2 - 0.1, -1.35)
        ..lineTo(width / 2 + 1.25, -1.0)
        ..lineTo(width / 2 - 0.1, -0.7)
        ..close();
      canvas.drawPath(drill, Paint()..color = const Color(0xFFB8C0C8));
      final groove = Paint()
        ..strokeWidth = 0.07
        ..color = const Color(0xFF6E7880);
      for (int i = 0; i < 3; i++) {
        final x = width / 2 + 0.15 + i * 0.32;
        canvas.drawLine(
          Offset(x, -1.28 + i * 0.08),
          Offset(x + 0.12, -0.8 - i * 0.03),
          groove,
        );
      }
      break;
    default:
      break;
  }

  // 마크
  canvas.drawCircle(
    Offset(-width * 0.12, (hullTop - 0.7) / 2),
    0.24,
    Paint()..color = Colors.white.withValues(alpha: destroyed ? 0.15 : 0.85),
  );
  canvas.drawCircle(
    Offset(-width * 0.12, (hullTop - 0.7) / 2),
    0.13,
    Paint()..color = destroyed ? dark : team,
  );
  canvas.restore(); // 좌우 반전 끝

  // 포신(실제 각도로)
  final pivot = tankTurretOffset(cls);
  final rad = -angle * math.pi / 180;
  final dir = Offset(math.cos(rad), math.sin(rad));
  final len = tankBarrelLength(cls);
  final bw = switch (cls) {
    'rhino' => 0.42,
    'falcon' => 0.26,
    'turtle' => 0.36,
    _ => 0.32,
  };
  final start = pivot - dir * (recoil * 0.5);
  canvas.save();
  canvas.translate(start.dx, start.dy);
  canvas.rotate(rad);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -bw / 2, len, bw),
      Radius.circular(bw / 2),
    ),
    Paint()..color = dark,
  );
  canvas.drawRect(
    Rect.fromLTWH(len - 0.35, -bw * 0.75, 0.35, bw * 1.5),
    Paint()..color = Color.lerp(dark, Colors.black, 0.3)!,
  );
  canvas.restore();

  // 포탑
  canvas.save();
  if (!facingRight) canvas.scale(-1, 1);
  switch (cls) {
    case 'rhino':
      final turret = RRect.fromRectAndRadius(
        Rect.fromLTRB(-1.25, -2.75, 1.05, hullTop + 0.05),
        const Radius.circular(0.3),
      );
      canvas.drawRRect(
        turret,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, -2.75),
            Offset(0, hullTop),
            [light, main],
          ),
      );
      canvas.drawRRect(turret, outline);
      canvas.drawRect(
        const Rect.fromLTRB(-0.9, -2.55, -0.3, -2.35),
        Paint()..color = dark,
      );
      break;
    case 'falcon':
      final turret = Rect.fromCenter(
        center: const Offset(0, -1.6),
        width: 1.6,
        height: 0.75,
      );
      canvas.drawOval(turret, Paint()..color = light);
      canvas.drawOval(turret, outline);
      break;
    case 'turtle':
      final dome = Rect.fromCenter(
        center: Offset(0, hullTop + 0.05),
        width: width - 0.6,
        height: 2.2,
      );
      canvas.drawArc(
        dome,
        math.pi,
        math.pi,
        true,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, hullTop - 1.1),
            Offset(0, hullTop),
            [light, main],
          ),
      );
      final hex = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..color = dark.withValues(alpha: 0.7);
      for (int i = -1; i <= 1; i++) {
        canvas.drawCircle(Offset(i * 0.75, hullTop - 0.45), 0.3, hex);
      }
      canvas.drawArc(dome, math.pi, math.pi, true, outline);
      break;
    default:
      final turret = Rect.fromCenter(
        center: const Offset(-0.1, -1.85),
        width: 1.7,
        height: 1.0,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(turret, const Radius.circular(0.45)),
        Paint()..color = light,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(turret, const Radius.circular(0.45)),
        outline,
      );
  }
  canvas.restore();

  canvas.restore(); // translate/scale

  if (flash > 0) canvas.restore();

  if (shield && !destroyed) {
    final c = base.translate(0, -u * 1.3);
    final pulse = 0.5 + 0.5 * math.sin(time * 4);
    canvas.drawCircle(
      c,
      u * 3.0,
      Paint()..color = _a(TankUi.cyan, 0.1 + pulse * 0.08),
    );
    canvas.drawCircle(
      c,
      u * 3.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _a(TankUi.cyan, 0.55 + pulse * 0.3),
    );
  }
}
