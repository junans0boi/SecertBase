import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_models.dart';

/// 경기장 한 장면의 좌표계. 골대 칸·공 비행·키퍼 다이브가 모두 같은 칸 중심을 쓴다.
class PitchGeometry {
  final Size size;
  final int cells;
  late final Rect goal;
  late final double standsBottom;
  late final Offset spot;
  late final Offset kickerStart;
  late final Offset kickerAtBall;
  late final Offset keeperHome;
  late final double keeperR;
  late final double kickerR;

  PitchGeometry(this.size, this.cells) {
    final w = size.width;
    final h = size.height;
    standsBottom = h * 0.30;
    final gw = math.min(w * 0.82, h * 1.55);
    final gh = math.min(gw * 0.42, h * 0.40);
    final bottom = h * 0.53;
    goal = Rect.fromLTRB(w / 2 - gw / 2, bottom - gh, w / 2 + gw / 2, bottom);
    keeperR = math.max(10, gh * 0.2);
    kickerR = keeperR * 1.3;
    spot = Offset(w / 2, h * 0.80);
    kickerAtBall = Offset(w / 2 - kickerR * 1.25, h * 0.80 - kickerR * 0.4);
    kickerStart = Offset(
      w / 2 - kickerR * 3.4,
      math.min(h - kickerR * 1.6, h * 0.93),
    );
    keeperHome = Offset(goal.center.dx, goal.bottom - keeperR * 1.35);
  }

  int get rows => cells == 6 ? 2 : 1;

  Rect zoneRect(int cell) {
    final col = penaltyCol(cell);
    final row = penaltyRow(cells, cell);
    final cw = goal.width / 3;
    final ch = goal.height / rows;
    return Rect.fromLTWH(goal.left + col * cw, goal.top + row * ch, cw, ch);
  }

  /// 공이 닿는 점: 3칸이면 골대 높이의 가운데보다 조금 위, 6칸이면 칸 중심.
  Offset target(int cell) {
    final r = zoneRect(cell);
    if (cells == 6) return r.center;
    return Offset(r.center.dx, goal.top + goal.height * 0.42);
  }
}

/// 마스코트 한 명의 모습.
class MascotLook {
  final String emoji;
  final Color color;

  const MascotLook({required this.emoji, required this.color});
}

/// 골대·관중석·잔디·마스코트를 그리고, 골대 위에 탭할 칸을 깐다.
/// [progress](0→1)가 돌면 [playback] 킥을 재생한다(걷기→킥→비행→다이브→반응).
class PenaltyPitch extends StatelessWidget {
  final GameTheme theme;
  final int cells;
  final MascotLook kicker;
  final MascotLook keeper;
  final PenaltyRound? playback;
  final Animation<double> progress;
  final Animation<double> idle;
  final int? selected;
  final bool zonesEnabled;
  final Color selectColor;
  final bool iAmKicker;
  final ValueChanged<int>? onZoneTap;
  final VoidCallback? onSkip;

  const PenaltyPitch({
    super.key,
    required this.theme,
    required this.cells,
    required this.kicker,
    required this.keeper,
    required this.progress,
    required this.idle,
    required this.selectColor,
    required this.iAmKicker,
    this.playback,
    this.selected,
    this.zonesEnabled = false,
    this.onZoneTap,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final g = PitchGeometry(size, cells);
        final playing = playback != null;
        return Stack(
          key: const Key('penalty_pitch'),
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PitchPainter(
                    geometry: g,
                    theme: theme,
                    kicker: kicker,
                    keeper: keeper,
                    playback: playback,
                    progress: progress,
                    idle: idle,
                  ),
                ),
              ),
            ),
            if (!playing)
              for (int c = 0; c < cells; c++)
                Positioned.fromRect(
                  rect: g.zoneRect(c).deflate(2.5),
                  child: _Zone(
                    key: Key('penalty_zone_$c'),
                    label: penaltyCellName(cells, c),
                    selected: selected == c,
                    enabled: zonesEnabled,
                    color: selectColor,
                    iAmKicker: iAmKicker,
                    onTap: zonesEnabled ? () => onZoneTap?.call(c) : null,
                  ),
                ),
            if (playing)
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: '연출 건너뛰기',
                  child: GestureDetector(
                    key: const Key('penalty_skip'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkip,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Zone extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final bool iAmKicker;
  final VoidCallback? onTap;

  const _Zone({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.iAmKicker,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$label 칸',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? color.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: enabled ? 0.07 : 0),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: enabled ? 0.55 : 0.0),
              width: selected ? 2.6 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.65),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Center(
                  child: AnimatedScale(
                    scale: selected ? 1 : 0.6,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Text(
                      iAmKicker ? '⚽' : '🧤',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// 연출 구간(0~1, 전체 2초).
const _walkEnd = 0.24;
const _kickAt = 0.26;
const _flightEnd = 0.71; // 0.26→0.71 = 0.9초 비행
const _diveStart = 0.30;
const _diveEnd = 0.6;

/// 공이 골대에 닿는 순간(소리·반응 타이밍을 화면과 맞춘다).
const kPenaltyImpactAt = _flightEnd;
const kPenaltyKickAt = _kickAt;

class _PitchPainter extends CustomPainter {
  final PitchGeometry geometry;
  final GameTheme theme;
  final MascotLook kicker;
  final MascotLook keeper;
  final PenaltyRound? playback;
  final Animation<double> progress;
  final Animation<double> idle;

  _PitchPainter({
    required this.geometry,
    required this.theme,
    required this.kicker,
    required this.keeper,
    required this.playback,
    required this.progress,
    required this.idle,
  }) : super(repaint: Listenable.merge([progress, idle]));

  static final Map<String, TextPainter> _emojiCache = {};

  double get t => playback == null ? 0 : progress.value;

  double _seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
    );
    _sky(canvas, size);
    _stands(canvas, size);
    _grass(canvas, size);
    _lines(canvas, size);
    _goal(canvas);
    _keeper(canvas);
    _ballAndKicker(canvas, size);
    canvas.restore();
    // 금빛 테두리.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.8),
        const Radius.circular(24),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = theme.gold.withValues(alpha: 0.75),
    );
  }

  void _sky(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, geometry.standsBottom + 4);
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9E80), Color(0xFFFFC59E), Color(0xFFFFE3B8)],
        ).createShader(r),
    );
    // 노을 해와 빛 번짐.
    final sun = Offset(size.width * 0.8, geometry.standsBottom * 0.42);
    canvas.drawCircle(
      sun,
      size.width * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xAAFFF4CF), const Color(0x00FFF4CF)],
        ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.32)),
    );
    canvas.drawCircle(
      sun,
      size.width * 0.06,
      Paint()..color = const Color(0xFFFFF1C9),
    );
  }

  void _stands(Canvas canvas, Size size) {
    final top = geometry.standsBottom * 0.38;
    final bottom = geometry.standsBottom + 6;
    final r = Rect.fromLTRB(0, top, size.width, bottom);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        r,
        topLeft: const Radius.circular(30),
        topRight: const Radius.circular(30),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB58BB8), Color(0xFFE6A4A8)],
        ).createShader(r),
    );
    // 관중 보케: 작은 동그라미 머리들이 반짝이고, 골이면 들썩인다.
    final reaction = playback == null
        ? 0.0
        : _seg(_flightEnd, 1.0) * (playback!.isGoal ? 1 : 0.4);
    final rnd = math.Random(5);
    const colors = [
      Color(0xFFFFFFFF),
      Color(0xFFFFE08A),
      Color(0xFFFFB3C6),
      Color(0xFFA8E6FF),
      Color(0xFFB9F3D6),
    ];
    final phase = idle.value * math.pi * 2;
    final rows = 4;
    for (int row = 0; row < rows; row++) {
      final y = top + 10 + (bottom - top - 18) * row / (rows - 1);
      final step = 11.0 + row * 1.5;
      for (double x = 4; x < size.width; x += step) {
        final k = rnd.nextDouble();
        final bounce =
            reaction * math.sin(phase * 3 + k * 9) * 3.2 * (1 - row * 0.15);
        final twinkle = 0.45 + 0.35 * math.sin(phase + k * 12);
        canvas.drawCircle(
          Offset(x + k * 4, y - bounce.abs()),
          2.2 + row * 0.5 + k,
          Paint()
            ..color = colors[(k * colors.length).floor() % colors.length]
                .withValues(alpha: twinkle),
        );
      }
    }
    // 카메라 플래시(골 순간).
    if (reaction > 0 && playback!.isGoal) {
      final flash = Paint()
        ..color = Colors.white.withValues(alpha: (1 - reaction) * 0.9);
      final fr = math.Random(9);
      for (int i = 0; i < 9; i++) {
        canvas.drawCircle(
          Offset(
            fr.nextDouble() * size.width,
            top + fr.nextDouble() * (bottom - top),
          ),
          2 + fr.nextDouble() * 3,
          flash,
        );
      }
    }
    // 경기장 조명 두 개.
    for (final x in [size.width * 0.08, size.width * 0.92]) {
      final c = Offset(x, top - 4);
      canvas.drawCircle(
        c,
        34,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0x99FFFFFF), const Color(0x00FFFFFF)],
          ).createShader(Rect.fromCircle(center: c, radius: 34)),
      );
    }
  }

  void _grass(Canvas canvas, Size size) {
    final top = geometry.standsBottom;
    final r = Rect.fromLTRB(0, top, size.width, size.height);
    canvas.drawRect(r, Paint()..color = const Color(0xFF79C978));
    const n = 8;
    for (int i = 0; i < n; i++) {
      double f(int k) => math.pow(k / n, 1.35).toDouble();
      final y0 = top + (size.height - top) * f(i);
      final y1 = top + (size.height - top) * f(i + 1);
      if (i.isOdd) {
        canvas.drawRect(
          Rect.fromLTRB(0, y0, size.width, y1),
          Paint()..color = const Color(0xFF8BD688),
        );
      }
    }
    // 노을빛 번짐 + 잔디 광택.
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x66FFD9A8),
            const Color(0x00FFD9A8),
            const Color(0x14000000),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(r),
    );
  }

  void _lines(Canvas canvas, Size size) {
    final g = geometry;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawLine(
      Offset(0, g.goal.bottom),
      Offset(size.width, g.goal.bottom),
      p,
    );
    // 골 에어리어(원근 사다리꼴).
    final small = Path()
      ..moveTo(g.goal.left - g.goal.width * 0.1, g.goal.bottom)
      ..lineTo(g.goal.left - g.goal.width * 0.18, g.goal.bottom + 26)
      ..lineTo(g.goal.right + g.goal.width * 0.18, g.goal.bottom + 26)
      ..lineTo(g.goal.right + g.goal.width * 0.1, g.goal.bottom);
    canvas.drawPath(small, p);
    final big = Path()
      ..moveTo(size.width * 0.02, g.goal.bottom)
      ..lineTo(-size.width * 0.06, size.height * 0.94)
      ..moveTo(size.width * 0.98, g.goal.bottom)
      ..lineTo(size.width * 1.06, size.height * 0.94);
    canvas.drawPath(big, p);
    canvas.drawCircle(g.spot, 3.2, Paint()..color = Colors.white);
  }

  void _goal(Canvas canvas) {
    final g = geometry;
    final goal = g.goal;
    // 골대 안쪽 그늘.
    canvas.drawRect(
      goal,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x40FFFFFF), const Color(0x22000000)],
        ).createShader(goal),
    );
    // 그물: 공이 들어가면 출렁인다.
    final pb = playback;
    final ripple = pb != null && pb.isGoal ? _seg(_flightEnd, 1.0) : 0.0;
    final impact = pb == null ? goal.center : g.target(pb.kickerDir);
    Offset bend(Offset p) {
      if (ripple <= 0 || ripple >= 1) return p;
      final d = (p - impact).distance;
      final fall = math.exp(-d / (goal.width * 0.22));
      final wave = math.sin(ripple * math.pi * 4 - d * 0.05) * (1 - ripple);
      final dir = d == 0 ? Offset.zero : (p - impact) / d;
      return p + dir * (9 * fall * wave) + Offset(0, -4 * fall * wave);
    }

    final net = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: 0.55);
    const cols = 16;
    const rows = 7;
    for (int i = 1; i < cols; i++) {
      final path = Path();
      for (int j = 0; j <= rows; j++) {
        final p = bend(
          Offset(
            goal.left + goal.width * i / cols,
            goal.top + goal.height * j / rows,
          ),
        );
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, net);
    }
    for (int j = 1; j < rows; j++) {
      final path = Path();
      for (int i = 0; i <= cols; i++) {
        final p = bend(
          Offset(
            goal.left + goal.width * i / cols,
            goal.top + goal.height * j / rows,
          ),
        );
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, net);
    }
    // 6칸이면 위·아래 경계를 살짝 보여 준다.
    final guide = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.35);
    for (int c = 1; c < 3; c++) {
      final x = goal.left + goal.width * c / 3;
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), guide);
    }
    if (g.cells == 6) {
      canvas.drawLine(
        Offset(goal.left, goal.center.dy),
        Offset(goal.right, goal.center.dy),
        guide,
      );
    }
    // 골대(둥근 흰 기둥 + 그림자).
    final postW = math.max(4.0, goal.width * 0.022);
    final frame = Path()
      ..moveTo(goal.left, goal.bottom)
      ..lineTo(goal.left, goal.top)
      ..lineTo(goal.right, goal.top)
      ..lineTo(goal.right, goal.bottom);
    canvas.drawPath(
      frame.shift(const Offset(2, 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = postW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0x33000000),
    );
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = postW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  void _keeper(Canvas canvas) {
    final g = geometry;
    final pb = playback;
    var pos = g.keeperHome;
    var angle = 0.0;
    var stretch = 0.0;
    final breathe = math.sin(idle.value * math.pi * 2);
    if (pb != null) {
      final d = Curves.easeOutCubic.transform(_seg(_diveStart, _diveEnd));
      final target = g.target(pb.keeperDir);
      final col = penaltyCol(pb.keeperDir);
      final dest = Offset(
        target.dx,
        math.min(target.dy + g.keeperR * 0.4, g.keeperHome.dy),
      );
      // 가운데로 뛰면 위로 폴짝, 옆이면 몸을 눕히며 날아간다.
      final hop = col == 1 ? -math.sin(d * math.pi) * g.keeperR * 0.6 : 0.0;
      pos = Offset.lerp(g.keeperHome, dest, d)! + Offset(0, hop);
      angle = (col - 1) * 1.05 * d;
      stretch = d;
    } else {
      // 제자리에서 좌우로 살랑.
      pos = pos + Offset(breathe * g.keeperR * 0.15, 0);
    }
    // 그림자.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, g.goal.bottom - 2),
        width: g.keeperR * 2.2,
        height: g.keeperR * 0.45,
      ),
      Paint()..color = const Color(0x2A000000),
    );
    _mascot(
      canvas,
      pos,
      g.keeperR,
      keeper,
      angle: angle,
      gloves: true,
      armsUp: 0.6 + 0.4 * stretch,
      bob: pb == null ? breathe * 1.2 : 0,
    );
  }

  void _ballAndKicker(Canvas canvas, Size size) {
    final g = geometry;
    final pb = playback;
    final breathe = math.sin(idle.value * math.pi * 2);
    // 키커: 걸어와서 찬다.
    final walk = Curves.easeInOut.transform(_seg(0, _walkEnd));
    final kickerPos = pb == null
        ? g.kickerAtBall
        : Offset.lerp(g.kickerStart, g.kickerAtBall, walk)!;
    final stepBob = pb != null && walk < 1
        ? -math.sin(walk * math.pi * 6).abs() * g.kickerR * 0.18
        : 0.0;
    final swing = pb == null
        ? 0.0
        : math.sin(_seg(_walkEnd - 0.02, _kickAt + 0.06) * math.pi);

    // 공 위치.
    Offset ball = g.spot + Offset(0, -g.kickerR * 0.12);
    var ballR = g.kickerR * 0.34;
    var ballShadowY = g.spot.dy + 2;
    var spin = 0.0;
    if (pb != null) {
      final f = Curves.easeOutCubic.transform(_seg(_kickAt, _flightEnd));
      final target = g.target(pb.kickerDir);
      final start = ball;
      final arc = -math.sin(f * math.pi) * g.goal.height * 0.35;
      ball = Offset.lerp(start, target, f)! + Offset(0, arc);
      ballR = g.kickerR * 0.34 * (1 - 0.55 * f);
      ballShadowY = g.spot.dy + (g.goal.bottom - g.spot.dy) * f;
      spin = f * 9;
      if (!pb.isGoal && t > _flightEnd) {
        // 막히면 튕겨 나온다.
        final b = Curves.easeOut.transform(_seg(_flightEnd, 0.92));
        final away = (target.dx - g.goal.center.dx).sign;
        ball =
            target +
            Offset(
              (away == 0 ? 1 : away) * g.goal.width * 0.18 * b,
              (g.goal.bottom + 18 - target.dy) * b - math.sin(b * math.pi) * 18,
            );
        ballR = g.kickerR * 0.34 * (0.45 + 0.15 * b);
        ballShadowY = g.goal.bottom + 18 * b;
        spin = 9 + b * 6;
      }
    }

    // 공 그림자.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ball.dx, ballShadowY),
        width: ballR * 2.0,
        height: ballR * 0.55,
      ),
      Paint()..color = const Color(0x30000000),
    );
    final ballInGoal = pb != null && t >= _kickAt;
    // 공이 멀리 날아가면 키커보다 뒤에 있으니 먼저 그린다.
    if (ballInGoal) _ball(canvas, ball, ballR, spin);
    // 키커 그림자 + 몸.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(kickerPos.dx, kickerPos.dy + g.kickerR * 1.55),
        width: g.kickerR * 2.1,
        height: g.kickerR * 0.5,
      ),
      Paint()..color = const Color(0x2E000000),
    );
    _mascot(
      canvas,
      kickerPos + Offset(0, stepBob),
      g.kickerR,
      kicker,
      kick: swing,
      bob: pb == null ? breathe * 1.4 : 0,
    );
    if (!ballInGoal) _ball(canvas, ball, ballR, spin);
  }

  void _ball(Canvas canvas, Offset c, double r, double spin) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFE4E8EE)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    final patch = Paint()..color = const Color(0xFF3A3F55);
    final pent = Path();
    for (int i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5;
      final p = Offset(math.cos(a), math.sin(a)) * r * 0.36;
      i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
    }
    pent.close();
    canvas.drawPath(pent, patch);
    for (int i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 5 + math.pi / 5;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * r * 0.82,
        r * 0.17,
        patch,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, r * 0.08)
        ..color = const Color(0x553A3F55),
    );
  }

  /// 둥근 몸 + 유니폼 + 얼굴(프로필 이모지) 마스코트. [center]는 머리 중심.
  void _mascot(
    Canvas canvas,
    Offset center,
    double r,
    MascotLook look, {
    double angle = 0,
    bool gloves = false,
    double armsUp = 0,
    double kick = 0,
    double bob = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy + bob);
    canvas.rotate(angle);
    final uniform = look.color;
    final dark = Color.lerp(uniform, Colors.black, 0.22)!;
    final light = Color.lerp(uniform, Colors.white, 0.35)!;
    // 다리(흰 반바지 + 동글 신발). 차는 다리는 앞으로 뻗는다.
    final legPaint = Paint()..color = Colors.white;
    final shoe = Paint()..color = const Color(0xFF4A3B52);
    for (final side in [-1.0, 1.0]) {
      final kicking = side > 0 && kick > 0;
      final foot = kicking
          ? Offset(side * r * (0.4 + kick * 0.6), r * (1.85 - kick * 0.35))
          : Offset(side * r * 0.36, r * 1.9);
      canvas.drawLine(
        Offset(side * r * 0.3, r * 1.25),
        foot,
        legPaint
          ..strokeWidth = r * 0.3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: foot + Offset(side * r * 0.06, r * 0.08),
          width: r * 0.48,
          height: r * 0.3,
        ),
        shoe,
      );
    }
    // 팔.
    final armPaint = Paint()
      ..color = uniform
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * r * 0.62, r * 0.62);
      final hand = Offset(
        side * r * (0.95 + armsUp * 0.25),
        r * (1.05 - armsUp * 1.05),
      );
      canvas.drawLine(shoulder, hand, armPaint);
      if (gloves) {
        canvas.drawCircle(hand, r * 0.26, Paint()..color = Colors.white);
        canvas.drawCircle(
          hand,
          r * 0.26,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07
            ..color = theme.gold,
        );
      } else {
        canvas.drawCircle(
          hand,
          r * 0.15,
          Paint()..color = const Color(0xFFFFE2C6),
        );
      }
    }
    // 몸통(둥근 유니폼).
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, r * 0.9),
        width: r * 1.45,
        height: r * 1.0,
      ),
      Radius.circular(r * 0.5),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, uniform, dark],
          stops: const [0, 0.55, 1],
        ).createShader(body.outerRect),
    );
    // 흰 V 칼라 + 가슴 별.
    final collar = Path()
      ..moveTo(-r * 0.22, r * 0.42)
      ..lineTo(0, r * 0.66)
      ..lineTo(r * 0.22, r * 0.42);
    canvas.drawPath(
      collar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(r * 0.36, r * 0.86),
      r * 0.09,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    // 얼굴: 흰 원 + 유니폼 색 테 + 프로필 이모지.
    canvas.drawCircle(
      Offset.zero,
      r * 0.82,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = uniform,
    );
    final tp = _emoji(look.emoji.isEmpty ? '🙂' : look.emoji, r * 1.05);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  TextPainter _emoji(String emoji, double size) {
    final key = '$emoji@${size.toStringAsFixed(1)}';
    final hit = _emojiCache[key];
    if (hit != null) return hit;
    if (_emojiCache.length > 40) _emojiCache.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: size, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _emojiCache[key] = tp;
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.playback != playback ||
      old.geometry.size != geometry.size ||
      old.geometry.cells != geometry.cells ||
      old.kicker.emoji != kicker.emoji ||
      old.keeper.emoji != keeper.emoji ||
      old.kicker.color != kicker.color ||
      old.keeper.color != keeper.color;
}
