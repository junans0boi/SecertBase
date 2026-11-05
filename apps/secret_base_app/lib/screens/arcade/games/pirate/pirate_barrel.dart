import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import 'pirate_controller.dart';

/// 통 앞면 위의 구멍 하나(화면 좌표).
@immutable
class BarrelHole {
  final int slot;
  final Offset center;

  /// 원기둥 곡면 때문에 가장자리 구멍은 가로로 눌린다(1 = 정면).
  final double squash;

  /// 원기둥 위 각도(라디안, 0 = 정면). 칼이 바깥쪽으로 기우는 방향.
  final double theta;

  const BarrelHole(this.slot, this.center, this.squash, this.theta);
}

/// 통 그림의 치수와 구멍 배치. 그리기·누르기·테스트가 같은 값을 쓴다.
class BarrelGeometry {
  final double width;
  final int slots;

  BarrelGeometry(this.width, this.slots);

  /// 원기둥을 살짝 위에서 본 기울기(가로 반지름 대비 세로 반지름).
  static const double tilt = 0.18;

  double get headSpace => width * 0.38;
  double get barrelHeight => width * 1.02;
  double get totalHeight => headSpace + barrelHeight;
  double get cx => width / 2;
  double get topY => headSpace + width * 0.075;
  double get bottomY => headSpace + barrelHeight - width * 0.085;
  double get rimRx => width * 0.40;
  double get midRx => width * 0.485;
  double get holeRadius => width * 0.05;
  double get headRadius => width * 0.15;
  Offset get headCenter => Offset(cx, topY - headRadius * 0.62);

  /// 높이 y에서 통의 가로 반지름(가운데가 불룩).
  double rxAt(double y) {
    final mid = (topY + bottomY) / 2;
    final half = (bottomY - topY) / 2;
    final k = ((y - mid) / half).clamp(-1.0, 1.0);
    return rimRx + (midRx - rimRx) * (1 - k * k);
  }

  /// 높이 y의 띠 위, 각도 theta인 점(앞쪽이 조금 아래로 내려온다).
  Offset onBand(double y, double theta) {
    final rx = rxAt(y);
    return Offset(cx + rx * math.sin(theta), y + rx * tilt * math.cos(theta));
  }

  double yAt(double fraction) => topY + (bottomY - topY) * fraction;

  /// 줄마다 구멍 수: 6 → 3·3, 8 → 4·4, 12 → 4·4·4.
  List<int> get rows => switch (slots) {
    6 => const [3, 3],
    8 => const [4, 4],
    12 => const [4, 4, 4],
    _ => _genericRows(slots),
  };

  static List<int> _genericRows(int n) {
    final perRow = n <= 8 ? (n / 2).ceil() : 4;
    final out = <int>[];
    var left = n;
    while (left > 0) {
      out.add(math.min(perRow, left));
      left -= perRow;
    }
    return out;
  }

  List<double> get rowFractions => switch (rows.length) {
    1 => const [0.5],
    2 => const [0.36, 0.64],
    3 => const [0.29, 0.5, 0.71],
    _ => List.generate(rows.length, (i) => 0.22 + 0.56 * i / (rows.length - 1)),
  };

  /// 쇠테 위치(구멍 줄과 겹치지 않게).
  List<double> get hoopFractions => rows.length == 2
      ? const [0.07, 0.17, 0.5, 0.83, 0.93]
      : const [0.07, 0.165, 0.835, 0.93];

  late final List<BarrelHole> holes = () {
    final out = <BarrelHole>[];
    var slot = 0;
    final fr = rowFractions;
    for (var r = 0; r < rows.length; r++) {
      final n = rows[r];
      final spread = n >= 4 ? 54.0 : 42.0;
      for (var i = 0; i < n; i++) {
        final deg = n == 1 ? 0.0 : -spread + 2 * spread * i / (n - 1);
        final theta = deg * math.pi / 180;
        out.add(
          BarrelHole(
            slot++,
            onBand(yAt(fr[r]), theta),
            math.max(0.62, math.cos(theta)),
            theta,
          ),
        );
      }
    }
    return out;
  }();

  /// 칼 손잡이가 향하는 방향(위쪽 + 바깥쪽).
  static Offset knifeDirection(double theta) {
    final lean = (0.42 + theta.abs() * 0.35) * (theta == 0 ? 1 : theta.sign);
    return Offset(math.sin(lean), -math.cos(lean));
  }
}

/// 해적 룰렛의 큰 통: 나무 널·쇠테·구멍(번호)·꽂힌 칼·통 위로 고개를 내민 해적.
/// 칼 떨어뜨리기·통 흔들림·위험 떨림·폭발(해적이 하늘로)을 스스로 연출한다.
class PirateBarrel extends StatefulWidget {
  final double width;
  final int slots;
  final List<int> pickedSlots;
  final int? bombSlot;
  final int riskPct;
  final bool exploded;
  final bool canPick;
  final ValueChanged<int>? onPick;

  /// 바뀌면 [lastStabSlot]에 칼을 떨어뜨린다.
  final int stabSerial;
  final int? lastStabSlot;

  /// 바뀌면(칼이 꽂힌 뒤) 폭발 연출을 한다.
  final int explosionSerial;
  final VoidCallback? onExplosionStart;
  final VoidCallback? onExplosionEnd;

  const PirateBarrel({
    super.key,
    required this.width,
    required this.slots,
    required this.pickedSlots,
    required this.riskPct,
    this.bombSlot,
    this.exploded = false,
    this.canPick = false,
    this.onPick,
    this.stabSerial = 0,
    this.lastStabSlot,
    this.explosionSerial = 0,
    this.onExplosionStart,
    this.onExplosionEnd,
  });

  @override
  State<PirateBarrel> createState() => _PirateBarrelState();
}

class _PirateBarrelState extends State<PirateBarrel>
    with TickerProviderStateMixin {
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _explode = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  int? _dropSlot;
  bool _explosionPending = false;
  bool _explosionSeen = false;
  int _stabSerial = 0;
  int _explosionSerial = 0;

  @override
  void initState() {
    super.initState();
    // 처음 그릴 때 이미 있던 칼·폭발은 연출하지 않는다.
    _stabSerial = widget.stabSerial;
    _explosionSerial = widget.explosionSerial;
    _drop.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      GameSfx.instance.play(GameSound.knifeStab);
      Future.delayed(const Duration(milliseconds: 90), () {
        if (mounted) GameSfx.instance.play(GameSound.barrelCreak, volume: 0.8);
      });
      _wobble.forward(from: 0);
      setState(() => _dropSlot = null);
      if (_explosionPending) _startExplosion();
    });
    _explode.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _explosionSeen = true);
        widget.onExplosionEnd?.call();
      }
    });
    _syncPulse();
  }

  void _syncPulse() {
    final want = !widget.exploded;
    if (want && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!want && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(covariant PirateBarrel old) {
    super.didUpdateWidget(old);
    if (widget.slots != old.slots || (!widget.exploded && old.exploded)) {
      // 새 판: 연출 상태를 비운다.
      _drop.stop();
      _explode.reset();
      _dropSlot = null;
      _explosionPending = false;
      _explosionSeen = false;
    }
    if (widget.stabSerial != _stabSerial) {
      _stabSerial = widget.stabSerial;
      if (widget.lastStabSlot != null) {
        _dropSlot = widget.lastStabSlot;
        _drop.forward(from: 0);
      }
    }
    if (widget.explosionSerial != _explosionSerial) {
      _explosionSerial = widget.explosionSerial;
      _explosionPending = true;
      if (!_drop.isAnimating) _startExplosion();
    }
    _syncPulse();
  }

  void _startExplosion() {
    _explosionPending = false;
    _explosionSeen = false;
    GameSfx.instance.play(GameSound.pirateBoom);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) GameSfx.instance.play(GameSound.pirateFly);
    });
    widget.onExplosionStart?.call();
    _explode.forward(from: 0);
  }

  @override
  void dispose() {
    _drop.dispose();
    _wobble.dispose();
    _pulse.dispose();
    _explode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geo = BarrelGeometry(widget.width, widget.slots);
    final picked = widget.pickedSlots.toSet();
    final mood = pirateMoodFor(widget.riskPct);
    return SizedBox(
      width: geo.width,
      height: geo.totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_drop, _wobble, _pulse, _explode]),
              builder: (context, _) {
                final exploding = _explode.isAnimating;
                final pirateGone =
                    widget.exploded &&
                    !exploding &&
                    !_explosionPending &&
                    (_explosionSeen || !_drop.isAnimating);
                final wobbleT = _wobble.isAnimating ? _wobble.value : 1.0;
                final trembling =
                    !widget.exploded && widget.riskPct >= 30 && !exploding;
                return CustomPaint(
                  painter: BarrelPainter(
                    geo: geo,
                    picked: picked,
                    bombSlot: widget.exploded ? widget.bombSlot : null,
                    mood: mood,
                    dropSlot: _dropSlot,
                    dropT: _drop.isAnimating ? _drop.value : null,
                    wobble:
                        math.sin(wobbleT * math.pi * 5) * (1 - wobbleT) * 0.045,
                    tremble: trembling
                        ? math.sin(_pulse.value * math.pi * 2 * 14) *
                              (widget.riskPct >= 50 ? 1.8 : 1.0)
                        : 0,
                    pulse: _pulse.value,
                    highlightFree: widget.canPick,
                    explodeT: exploding ? _explode.value : null,
                    pirateGone: pirateGone,
                  ),
                );
              },
            ),
          ),
          for (final hole in geo.holes)
            if (!picked.contains(hole.slot))
              Positioned(
                left: hole.center.dx - 23,
                top: hole.center.dy - 23,
                width: 46,
                height: 46,
                child: Semantics(
                  button: true,
                  enabled: widget.canPick,
                  label: '${hole.slot + 1}번 구멍',
                  child: GestureDetector(
                    key: ValueKey('pirate-hole-${hole.slot}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.canPick
                        ? () => widget.onPick?.call(hole.slot)
                        : null,
                  ),
                ),
              ),
          // "펑!" 글자
          AnimatedBuilder(
            animation: _explode,
            builder: (context, _) {
              if (!_explode.isAnimating) return const SizedBox.shrink();
              final t = _explode.value;
              final scale = Curves.elasticOut.transform(
                (t / 0.45).clamp(0.0, 1.0),
              );
              final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
              return Positioned(
                left: 0,
                right: 0,
                top: geo.topY - geo.width * 0.28,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.4 + scale * 0.8,
                      child: Text(
                        '펑!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: geo.width * 0.2,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFD34D),
                          shadows: const [
                            Shadow(
                              color: Color(0xFF8A2B0E),
                              blurRadius: 0,
                              offset: Offset(3, 3),
                            ),
                            Shadow(color: Color(0xAAFF6A00), blurRadius: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 통·구멍·칼·해적·폭발을 한 장에 그린다.
class BarrelPainter extends CustomPainter {
  final BarrelGeometry geo;
  final Set<int> picked;
  final int? bombSlot;
  final PirateMood mood;
  final int? dropSlot;
  final double? dropT;
  final double wobble;
  final double tremble;
  final double pulse;
  final bool highlightFree;
  final double? explodeT;
  final bool pirateGone;

  BarrelPainter({
    required this.geo,
    required this.picked,
    required this.bombSlot,
    required this.mood,
    required this.dropSlot,
    required this.dropT,
    required this.wobble,
    required this.tremble,
    required this.pulse,
    required this.highlightFree,
    required this.explodeT,
    required this.pirateGone,
  });

  static const _woodDark = Color(0xFF4A2A14);
  static const _wood = Color(0xFF8A5530);
  static const _woodLight = Color(0xFFC98A52);
  static const _iron = Color(0xFF3B3F45);
  static const _brass = Color(0xFFD9A65A);

  @override
  void paint(Canvas canvas, Size size) {
    final g = geo;
    // 갑판 위 그림자
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(g.cx, g.bottomY + g.width * 0.06),
        width: g.width * 1.05,
        height: g.width * 0.2,
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.save();
    // 흔들림: 바닥 가운데를 축으로 살짝 기울고, 위험하면 잘게 떨린다.
    canvas.translate(g.cx + tremble, g.bottomY);
    canvas.rotate(wobble);
    canvas.translate(-g.cx, -g.bottomY);

    _body(canvas);
    _hoops(canvas);
    _opening(canvas);
    if (!pirateGone && explodeT == null) {
      _pirateInBarrel(canvas);
    }
    _holes(canvas);
    _rimFront(canvas);
    if (pirateGone) _smokeWisp(canvas);
    canvas.restore();

    if (dropSlot != null && dropT != null) _droppingKnife(canvas);
    if (explodeT != null) _explosion(canvas, explodeT!);
  }

  Path _bodyPath() {
    final g = geo;
    final path = Path();
    const steps = 24;
    // 왼쪽 옆면(위→아래)
    for (var i = 0; i <= steps; i++) {
      final y = g.topY + (g.bottomY - g.topY) * i / steps;
      final p = Offset(g.cx - g.rxAt(y), y);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    // 아래 앞쪽 호(왼→오)
    for (var i = 0; i <= steps; i++) {
      final th = -math.pi / 2 + math.pi * i / steps;
      final p = g.onBand(g.bottomY, th);
      path.lineTo(p.dx, p.dy);
    }
    // 오른쪽 옆면(아래→위)
    for (var i = steps; i >= 0; i--) {
      final y = g.topY + (g.bottomY - g.topY) * i / steps;
      path.lineTo(g.cx + g.rxAt(y), y);
    }
    // 위 앞쪽 호(오→왼)
    for (var i = steps; i >= 0; i--) {
      final th = -math.pi / 2 + math.pi * i / steps;
      final p = g.onBand(g.topY, th);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  void _body(Canvas canvas) {
    final g = geo;
    final path = _bodyPath();
    final bounds = Rect.fromLTRB(
      g.cx - g.midRx,
      g.topY,
      g.cx + g.midRx,
      g.bottomY + g.midRx * BarrelGeometry.tilt,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [_woodDark, _wood, _woodLight, _wood, _woodDark],
          stops: [0, 0.22, 0.4, 0.7, 1],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(path);
    // 랜턴 빛(왼쪽 위에서 주황빛)
    canvas.drawCircle(
      Offset(g.cx - g.width * 0.32, g.topY + g.width * 0.18),
      g.width * 0.6,
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0x55FFB45C), const Color(0x00FFB45C)],
            ).createShader(
              Rect.fromCircle(
                center: Offset(g.cx - g.width * 0.32, g.topY + g.width * 0.18),
                radius: g.width * 0.6,
              ),
            ),
    );
    // 나무 널 이음새
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0x66301808);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x22301808);
    for (var deg = -78.0; deg <= 78.0; deg += 13.0) {
      final th = deg * math.pi / 180;
      final seamPath = Path();
      final grainPath = Path();
      for (var i = 0; i <= 20; i++) {
        final y = g.topY + (g.bottomY - g.topY) * i / 20;
        final p = g.onBand(y, th);
        final q = g.onBand(y, th + 0.11);
        if (i == 0) {
          seamPath.moveTo(p.dx, p.dy);
          grainPath.moveTo(q.dx, q.dy);
        } else {
          seamPath.lineTo(p.dx, p.dy);
          grainPath.lineTo(q.dx + math.sin(i * 1.7 + deg) * 0.8, q.dy);
        }
      }
      canvas.drawPath(seamPath, seam);
      canvas.drawPath(grainPath, grain);
    }
    // 젖은 나무 광택
    final sheen = Path();
    for (var i = 0; i <= 20; i++) {
      final y = g.topY + (g.bottomY - g.topY) * i / 20;
      final p = g.onBand(y, -0.42);
      i == 0 ? sheen.moveTo(p.dx, p.dy) : sheen.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      sheen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.width * 0.03
        ..color = const Color(0x22FFF1DC)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xAA2A160A),
    );
  }

  void _band(Canvas canvas, double fraction, double thickness) {
    final g = geo;
    final y = g.yAt(fraction);
    final top = Path();
    final bottom = <Offset>[];
    const steps = 28;
    for (var i = 0; i <= steps; i++) {
      final th = -math.pi / 2 + math.pi * i / steps;
      final p = g.onBand(y - thickness / 2, th);
      i == 0 ? top.moveTo(p.dx, p.dy) : top.lineTo(p.dx, p.dy);
      bottom.add(g.onBand(y + thickness / 2, th));
    }
    for (final p in bottom.reversed) {
      top.lineTo(p.dx, p.dy);
    }
    top.close();
    final rx = g.rxAt(y);
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF1E2126),
            Color(0xFF5B6168),
            Color(0xFF8D949B),
            Color(0xFF4A4F55),
            Color(0xFF1E2126),
          ],
          stops: const [0, 0.25, 0.4, 0.7, 1],
        ).createShader(Rect.fromLTRB(g.cx - rx, y - 4, g.cx + rx, y + 4)),
    );
    // 리벳
    final rivet = Paint()..color = const Color(0xFFB9BEC4);
    for (final deg in [-60.0, -20.0, 20.0, 60.0]) {
      final p = g.onBand(y, deg * math.pi / 180);
      canvas.drawCircle(p, thickness * 0.17, rivet);
    }
  }

  void _hoops(Canvas canvas) {
    final t = geo.width * 0.034;
    for (final f in geo.hoopFractions) {
      _band(canvas, f, (f == 0.5) ? t * 0.8 : t);
    }
  }

  Rect get _openingRect => Rect.fromCenter(
    center: Offset(geo.cx, geo.topY),
    width: geo.rimRx * 2,
    height: geo.rimRx * 2 * BarrelGeometry.tilt,
  );

  void _opening(Canvas canvas) {
    final r = _openingRect;
    canvas.drawOval(
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.4),
          colors: [Color(0xFF0B0603), Color(0xFF2E1A0C)],
        ).createShader(r),
    );
  }

  void _rimFront(Canvas canvas) {
    final r = _openingRect;
    canvas.drawOval(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.width * 0.028
        ..color = const Color(0xFF6B3F1F),
    );
    canvas.drawArc(
      r,
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = geo.width * 0.034
        ..shader = const LinearGradient(
          colors: [_iron, Color(0xFF8D949B), _iron],
        ).createShader(r),
    );
  }

  void _holes(Canvas canvas) {
    final g = geo;
    final r = g.holeRadius;
    for (final hole in g.holes) {
      final rect = Rect.fromCenter(
        center: hole.center,
        width: r * 2 * hole.squash,
        height: r * 2,
      );
      final isBomb = bombSlot == hole.slot;
      if (isBomb) {
        // 터진 구멍: 그을음 + 불씨
        canvas.drawCircle(
          hole.center,
          r * 2.1,
          Paint()
            ..shader =
                RadialGradient(
                  colors: const [Color(0xCC1A0A03), Color(0x001A0A03)],
                ).createShader(
                  Rect.fromCircle(center: hole.center, radius: r * 2.1),
                ),
        );
        canvas.drawOval(
          rect.inflate(2),
          Paint()
            ..shader = RadialGradient(
              colors: const [
                Color(0xFFFFD34D),
                Color(0xFFFF5A1F),
                Color(0xFF3A0E05),
              ],
              stops: const [0, 0.45, 1],
            ).createShader(rect.inflate(2)),
        );
        continue;
      }
      // 구멍 테두리(밝은 나무 결) + 깊은 안쪽
      canvas.drawOval(
        rect.inflate(2.2),
        Paint()..color = const Color(0x55FFD7A0),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.15, 0.35),
            colors: [Color(0xFF050302), Color(0xFF26150A)],
          ).createShader(rect),
      );
      if (highlightFree && !picked.contains(hole.slot)) {
        final a = 0.35 + 0.35 * math.sin(pulse * math.pi * 2);
        canvas.drawOval(
          rect.inflate(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _brass.withValues(alpha: a),
        );
      }
      // 번호(작게)
      final tp = TextPainter(
        text: TextSpan(
          text: '${hole.slot + 1}',
          style: TextStyle(
            fontSize: math.max(9.0, r * 0.68),
            fontWeight: FontWeight.w800,
            color: const Color(0xDDFFE7C2),
            shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(hole.center.dx - tp.width / 2, hole.center.dy + r + 1.5),
      );
      if (picked.contains(hole.slot) && dropSlot != hole.slot) {
        _knife(canvas, hole.center, hole.theta, inserted: true);
      }
    }
  }

  /// 칼: [tip] = 칼끝 위치. inserted면 칼날 대부분이 구멍 속에 있다.
  void _knife(
    Canvas canvas,
    Offset tip,
    double theta, {
    required bool inserted,
  }) {
    final r = geo.holeRadius;
    final dir = BarrelGeometry.knifeDirection(theta);
    final angle = math.atan2(dir.dx, -dir.dy);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle);
    // 이제 위쪽(-y)이 손잡이 방향.
    final blade = inserted ? r * 0.55 : r * 2.4;
    final bladePath = Path()
      ..moveTo(-r * 0.24, -blade)
      ..lineTo(r * 0.24, -blade)
      ..lineTo(r * 0.24, inserted ? 0 : -r * 0.5)
      ..lineTo(0, inserted ? 0 : 0)
      ..lineTo(-r * 0.24, inserted ? 0 : -r * 0.5)
      ..close();
    canvas.drawPath(
      bladePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8D949B), Color(0xFFF2F4F6), Color(0xFF9AA1A8)],
        ).createShader(Rect.fromLTRB(-r * 0.24, -blade, r * 0.24, 0)),
    );
    // 날밑(황동)
    final guard = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -blade - r * 0.12),
        width: r * 1.35,
        height: r * 0.3,
      ),
      Radius.circular(r * 0.15),
    );
    canvas.drawRRect(guard, Paint()..color = _brass);
    canvas.drawRRect(
      guard,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF7A5524),
    );
    // 손잡이(가죽 감김)
    final hTop = -blade - r * 0.27 - r * 1.75;
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTRB(-r * 0.26, hTop, r * 0.26, -blade - r * 0.27),
      Radius.circular(r * 0.2),
    );
    canvas.drawRRect(handle, Paint()..color = const Color(0xFF3A2414));
    final wrap = Paint()
      ..color = const Color(0xFF6B4226)
      ..strokeWidth = 1.1;
    for (var i = 1; i < 5; i++) {
      final y = hTop + (r * 1.75) * i / 5;
      canvas.drawLine(
        Offset(-r * 0.26, y + 1.5),
        Offset(r * 0.26, y - 1.5),
        wrap,
      );
    }
    // 끝 장식
    canvas.drawCircle(
      Offset(0, hTop - r * 0.12),
      r * 0.24,
      Paint()..color = _brass,
    );
    canvas.restore();
  }

  void _droppingKnife(Canvas canvas) {
    final hole = geo.holes.firstWhere(
      (h) => h.slot == dropSlot,
      orElse: () => geo.holes.first,
    );
    final t = Curves.easeInCubic.transform(dropT!.clamp(0.0, 1.0));
    final startY = -geo.width * 0.25;
    final tip = Offset(hole.center.dx, startY + (hole.center.dy - startY) * t);
    _knife(canvas, tip, hole.theta * t, inserted: false);
  }

  // ── 해적 ─────────────────────────────────────────────────────────────

  void _pirateInBarrel(Canvas canvas) {
    final g = geo;
    canvas.save();
    // 통 입구 앞쪽 테두리 아래는 가린다.
    final clip = Path()
      ..addRect(Rect.fromLTRB(-g.width, -g.width * 3, g.width * 2, g.topY))
      ..addOval(_openingRect);
    canvas.clipPath(clip);
    final bob = mood == PirateMood.scream
        ? math.sin(pulse * math.pi * 16) * 1.2
        : math.sin(pulse * math.pi * 2) * 1.5;
    paintPirateHead(canvas, g.headCenter.translate(0, bob), g.headRadius, mood);
    canvas.restore();
    // 테두리를 붙잡은 손
    final hand = Paint()..color = const Color(0xFFF2C29B);
    final handLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFB5835E);
    for (final s in [-1.0, 1.0]) {
      final c = Offset(
        g.cx + s * g.headRadius * 1.25,
        g.topY + g.rimRx * BarrelGeometry.tilt * 0.75,
      );
      final rect = Rect.fromCenter(
        center: c,
        width: g.headRadius * 0.62,
        height: g.headRadius * 0.42,
      );
      canvas.drawOval(rect, hand);
      canvas.drawOval(rect, handLine);
    }
  }

  void _smokeWisp(Canvas canvas) {
    final g = geo;
    for (var i = 0; i < 3; i++) {
      final t = (pulse + i / 3) % 1.0;
      final c = Offset(
        g.cx + math.sin(t * math.pi * 2 + i) * g.width * 0.04,
        g.topY - t * g.width * 0.32,
      );
      canvas.drawCircle(
        c,
        g.width * (0.04 + t * 0.05),
        Paint()..color = Color.fromRGBO(200, 196, 190, 0.35 * (1 - t)),
      );
    }
  }

  void _explosion(Canvas canvas, double t) {
    final g = geo;
    final origin = Offset(g.cx, g.topY);
    // 별 모양 폭발
    if (t < 0.6) {
      final grow = Curves.easeOutBack.transform((t / 0.22).clamp(0.0, 1.0));
      final fade = t < 0.3 ? 1.0 : 1 - (t - 0.3) / 0.3;
      for (final layer in [
        (1.0, const Color(0xFFFF6A1F)),
        (0.68, const Color(0xFFFFB03A)),
        (0.4, const Color(0xFFFFF0A8)),
      ]) {
        final radius = g.width * 0.55 * grow * layer.$1;
        final path = Path();
        const spikes = 12;
        for (var i = 0; i < spikes * 2; i++) {
          final a = math.pi * 2 * i / (spikes * 2) + t;
          final rr = i.isEven ? radius : radius * 0.55;
          final p = origin + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.8);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()..color = layer.$2.withValues(alpha: fade.clamp(0.0, 1.0)),
        );
      }
    }
    // 연기
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * (0.1 + 0.8 * i / 6);
      final d = g.width * (0.2 + 0.25 * t);
      final c = origin + Offset(math.cos(a) * d, math.sin(a) * d * 0.5);
      canvas.drawCircle(
        c,
        g.width * (0.05 + 0.08 * t),
        Paint()
          ..color = Color.fromRGBO(
            120,
            112,
            104,
            (0.55 * (1 - t)).clamp(0.0, 1.0),
          ),
      );
    }
    // 파편(나무 조각·별)
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final a = -math.pi * (0.05 + 0.9 * rnd.nextDouble());
      final speed = g.width * (0.6 + rnd.nextDouble() * 0.7);
      final p =
          origin +
          Offset(
            math.cos(a) * speed * t,
            math.sin(a) * speed * t + g.width * 1.1 * t * t,
          );
      final fade = (1 - t).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t * 9 + i);
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: g.width * 0.07,
            height: g.width * 0.022,
          ),
          Paint()..color = _wood.withValues(alpha: fade),
        );
      } else {
        _star(
          canvas,
          g.width * 0.03,
          const Color(0xFFFFE27A).withValues(alpha: fade),
        );
      }
      canvas.restore();
    }
    // 뚜껑이 튕겨 나간다
    final lidT = t.clamp(0.0, 1.0);
    final lid =
        origin +
        Offset(
          -g.width * 0.55 * lidT,
          -g.width * 1.4 * lidT + g.width * 1.2 * lidT * lidT,
        );
    canvas.save();
    canvas.translate(lid.dx, lid.dy);
    canvas.rotate(-lidT * 7);
    final lidRect = Rect.fromCenter(
      center: Offset.zero,
      width: g.rimRx * 1.3,
      height: g.rimRx * 0.32,
    );
    canvas.drawOval(
      lidRect,
      Paint()..color = _wood.withValues(alpha: (1 - lidT * 0.6)),
    );
    canvas.drawOval(
      lidRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _iron.withValues(alpha: (1 - lidT * 0.6)),
    );
    canvas.restore();
    // 해적이 하늘로 빙글빙글
    final fly = Curves.easeInQuad.transform(t.clamp(0.0, 1.0));
    final head =
        g.headCenter +
        Offset(
          math.sin(fly * math.pi * 1.2) * g.width * 0.3,
          -fly * (g.headCenter.dy + g.width * 1.4),
        );
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(fly * math.pi * 5);
    canvas.scale(1 - fly * 0.45);
    paintPirateHead(canvas, Offset.zero, g.headRadius, mood, dizzy: true);
    canvas.restore();
  }

  void _star(Canvas canvas, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + math.pi * i / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant BarrelPainter old) => true;
}

/// 해적 얼굴. [mood]가 위험할수록 겁먹고, [dizzy]면 날아가는 중(X 눈).
void paintPirateHead(
  Canvas canvas,
  Offset c,
  double r,
  PirateMood mood, {
  bool dizzy = false,
}) {
  const skin = Color(0xFFF2C29B);
  const skinShade = Color(0xFFD89C72);
  const ink = Color(0xFF2A1A12);
  // 얼굴
  final face = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        colors: [Color(0xFFFFDDBF), skin, skinShade],
        stops: [0, 0.6, 1],
      ).createShader(face),
  );
  // 볼
  final blush = Paint()..color = const Color(0x55FF7A7A);
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(-r * 0.5, r * 0.25),
      width: r * 0.36,
      height: r * 0.2,
    ),
    blush,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(r * 0.52, r * 0.25),
      width: r * 0.36,
      height: r * 0.2,
    ),
    blush,
  );
  // 두건(빨강 + 흰 점)
  final bandana = Path()
    ..moveTo(c.dx - r * 1.02, c.dy - r * 0.12)
    ..quadraticBezierTo(c.dx - r * 0.95, c.dy - r * 1.18, c.dx, c.dy - r * 1.12)
    ..quadraticBezierTo(
      c.dx + r * 0.95,
      c.dy - r * 1.18,
      c.dx + r * 1.02,
      c.dy - r * 0.12,
    )
    ..quadraticBezierTo(c.dx, c.dy - r * 0.38, c.dx - r * 1.02, c.dy - r * 0.12)
    ..close();
  canvas.drawPath(bandana, Paint()..color = const Color(0xFFC8322A));
  final dot = Paint()..color = const Color(0xEEFFF1DC);
  for (final o in [
    Offset(-r * 0.55, -r * 0.6),
    Offset(-r * 0.1, -r * 0.82),
    Offset(r * 0.38, -r * 0.7),
    Offset(r * 0.75, -r * 0.42),
    Offset(-r * 0.82, -r * 0.3),
  ]) {
    canvas.drawCircle(c + o, r * 0.07, dot);
  }
  // 매듭과 끈
  final knot = c + Offset(r * 1.0, -r * 0.3);
  canvas.drawCircle(knot, r * 0.16, Paint()..color = const Color(0xFFA82720));
  final tail = Paint()
    ..color = const Color(0xFFC8322A)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = r * 0.16;
  canvas.drawLine(knot, knot + Offset(r * 0.32, r * 0.18), tail);
  canvas.drawLine(knot, knot + Offset(r * 0.22, r * 0.4), tail);
  // 금 귀걸이
  canvas.drawCircle(
    c + Offset(-r * 0.98, r * 0.28),
    r * 0.11,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = const Color(0xFFE8C26A),
  );
  // 안대(왼쪽 눈) + 끈
  canvas.drawLine(
    c + Offset(-r * 0.95, -r * 0.42),
    c + Offset(r * 0.92, -r * 0.05),
    Paint()
      ..color = ink
      ..strokeWidth = r * 0.07,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(-r * 0.38, -r * 0.05),
      width: r * 0.46,
      height: r * 0.4,
    ),
    Paint()..color = ink,
  );
  // 오른쪽 눈
  final eye = c + Offset(r * 0.36, -r * 0.05);
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = r * 0.075;
  if (dizzy) {
    final s = r * 0.14;
    canvas.drawLine(eye + Offset(-s, -s), eye + Offset(s, s), stroke);
    canvas.drawLine(eye + Offset(-s, s), eye + Offset(s, -s), stroke);
  } else {
    switch (mood) {
      case PirateMood.calm:
        // 웃는 눈(아치)
        canvas.drawArc(
          Rect.fromCenter(
            center: eye + Offset(0, r * 0.04),
            width: r * 0.3,
            height: r * 0.24,
          ),
          math.pi,
          math.pi,
          false,
          stroke,
        );
      case PirateMood.worried:
      case PirateMood.sweaty:
      case PirateMood.scream:
        final w = mood == PirateMood.scream
            ? 0.4
            : (mood == PirateMood.sweaty ? 0.34 : 0.28);
        final eyeRect = Rect.fromCenter(
          center: eye,
          width: r * w,
          height: r * w * 1.15,
        );
        canvas.drawOval(eyeRect, Paint()..color = Colors.white);
        canvas.drawOval(
          eyeRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.03
            ..color = ink,
        );
        final pupil = mood == PirateMood.scream ? 0.06 : 0.09;
        canvas.drawCircle(
          eye + Offset(-r * 0.02, r * 0.02),
          r * pupil,
          Paint()..color = ink,
        );
    }
    // 눈썹: 걱정할수록 안쪽이 올라간다.
    final lift = switch (mood) {
      PirateMood.calm => 0.0,
      PirateMood.worried => 0.08,
      PirateMood.sweaty => 0.13,
      PirateMood.scream => 0.18,
    };
    canvas.drawLine(
      c + Offset(r * 0.18, -r * (0.3 + lift)),
      c + Offset(r * 0.56, -r * (0.32 - lift * 0.4)),
      stroke,
    );
  }
  // 콧수염
  final mustache = Paint()..color = const Color(0xFF5A3418);
  for (final s in [-1.0, 1.0]) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.22)
      ..quadraticBezierTo(
        c.dx + s * r * 0.3,
        c.dy + r * 0.12,
        c.dx + s * r * 0.55,
        c.dy + r * 0.28,
      )
      ..quadraticBezierTo(
        c.dx + s * r * 0.3,
        c.dy + r * 0.34,
        c.dx,
        c.dy + r * 0.3,
      )
      ..close();
    canvas.drawPath(path, mustache);
  }
  // 코
  canvas.drawCircle(
    c + Offset(0, r * 0.12),
    r * 0.11,
    Paint()..color = skinShade,
  );
  // 입
  final mouthC = c + Offset(0, r * 0.52);
  if (dizzy || mood == PirateMood.scream) {
    final rect = Rect.fromCenter(
      center: mouthC,
      width: r * 0.36,
      height: r * 0.34,
    );
    canvas.drawOval(rect, Paint()..color = const Color(0xFF5A1010));
    canvas.drawOval(
      Rect.fromCenter(
        center: mouthC + Offset(0, r * 0.08),
        width: r * 0.2,
        height: r * 0.12,
      ),
      Paint()..color = const Color(0xFFE86A6A),
    );
  } else {
    final path = Path();
    switch (mood) {
      case PirateMood.calm:
        path
          ..moveTo(mouthC.dx - r * 0.22, mouthC.dy - r * 0.04)
          ..quadraticBezierTo(
            mouthC.dx,
            mouthC.dy + r * 0.16,
            mouthC.dx + r * 0.22,
            mouthC.dy - r * 0.04,
          );
      case PirateMood.worried:
        path
          ..moveTo(mouthC.dx - r * 0.18, mouthC.dy + r * 0.02)
          ..quadraticBezierTo(
            mouthC.dx,
            mouthC.dy - r * 0.05,
            mouthC.dx + r * 0.18,
            mouthC.dy + r * 0.03,
          );
      case PirateMood.sweaty:
      case PirateMood.scream:
        path.moveTo(mouthC.dx - r * 0.24, mouthC.dy);
        for (var i = 1; i <= 6; i++) {
          path.lineTo(
            mouthC.dx - r * 0.24 + r * 0.08 * i,
            mouthC.dy + (i.isOdd ? -r * 0.05 : r * 0.05),
          );
        }
    }
    canvas.drawPath(path, stroke);
  }
  // 땀방울
  if (!dizzy && (mood == PirateMood.sweaty || mood == PirateMood.scream)) {
    final drop = Paint()..color = const Color(0xDD8FD3FF);
    for (final o in [Offset(r * 0.82, -r * 0.05), Offset(-r * 0.86, r * 0.1)]) {
      final p = c + o;
      final path = Path()
        ..moveTo(p.dx, p.dy - r * 0.16)
        ..quadraticBezierTo(p.dx + r * 0.11, p.dy, p.dx, p.dy + r * 0.06)
        ..quadraticBezierTo(p.dx - r * 0.11, p.dy, p.dx, p.dy - r * 0.16);
      canvas.drawPath(path, drop);
    }
  }
  // 날아가는 중: 머리 위 별
  if (dizzy) {
    final starPaint = Paint()..color = const Color(0xFFFFE27A);
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 2 + (i - 1) * 0.7;
      final p = c + Offset(math.cos(a) * r * 1.45, math.sin(a) * r * 1.3);
      canvas.drawCircle(p, r * 0.1, starPaint);
    }
  }
}
