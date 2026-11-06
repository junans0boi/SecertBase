import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';

/// 윷가락 색(상점 윷 스킨별): 납작한 면 / 둥근 면 / 결.
class YutStickPalette {
  final Color flat;
  final Color round;
  final Color grain;

  const YutStickPalette(this.flat, this.round, this.grain);

  static YutStickPalette of(String skin) => switch (skin) {
    'bamboo' => const YutStickPalette(
      Color(0xFFD7E8A8),
      Color(0xFF4F7A2B),
      Color(0xFF7BA04A),
    ),
    'gold' => const YutStickPalette(
      Color(0xFFFFE27A),
      Color(0xFFB8860B),
      Color(0xFFDAA520),
    ),
    'crystal' => const YutStickPalette(
      Color(0xFFCFEAF2),
      Color(0xFF3B6591),
      Color(0xFF6E96C0),
    ),
    'fire' => const YutStickPalette(
      Color(0xFFFFB066),
      Color(0xFFA32A1C),
      Color(0xFFE2692B),
    ),
    'legend' => const YutStickPalette(
      Color(0xFFE2BDEB),
      Color(0xFF5A1D8F),
      Color(0xFF9C5CC0),
    ),
    'cherry' => const YutStickPalette(
      Color(0xFFFFD6DF),
      Color(0xFFC2305F),
      Color(0xFFE56C92),
    ),
    'stone' => const YutStickPalette(
      Color(0xFFCFCFCF),
      Color(0xFF4A4A4A),
      Color(0xFF7A7A7A),
    ),
    'autumn' => const YutStickPalette(
      Color(0xFFF2C98A),
      Color(0xFF9A3B1A),
      Color(0xFFC7662B),
    ),
    'wave' => const YutStickPalette(
      Color(0xFFCFE9F5),
      Color(0xFF1F5E8C),
      Color(0xFF4F93BD),
    ),
    'wind' => const YutStickPalette(
      Color(0xFFE3F0EC),
      Color(0xFF4F8576),
      Color(0xFF86B8A9),
    ),
    'storm' => const YutStickPalette(
      Color(0xFFD8D4E4),
      Color(0xFF3F3A5E),
      Color(0xFF706A99),
    ),
    // 기본: 박달나무 — 납작한 면은 말간 속살, 둥근 면은 짙은 껍질.
    _ => const YutStickPalette(
      Color(0xFFF1DCAE),
      Color(0xFF7B4B2A),
      Color(0xFFC9A66B),
    ),
  };
}

/// 윷 결과를 알리는 말("윷이야!" 등).
String yutCallout(YutThrow t) {
  if (t.nak) return '낙이에요';
  return switch (t.result) {
    4 => '윷이야!',
    5 => '모야!',
    -1 => '빽도!',
    _ => '${t.resultName}!',
  };
}

/// 멍석(짚자리) 위로 윷가락 네 개가 포물선을 그리며 떨어져 구르다 서버 `sticks`대로 멈춘다.
/// 윷·모는 슬로모션(길게)으로 보여 준다. 착지(≈0.86)에서 [onLanded], 끝에서 [onDone].
class YutSticksStage extends StatefulWidget {
  final YutThrow thrown;

  /// 같은 던지기를 같은 모양으로 그리기 위한 값(서버 seq).
  final int seed;
  final String skin;
  final VoidCallback? onLanded;
  final VoidCallback? onDone;
  final String? throwerName;

  /// 테스트용: 0..1 사이 값이면 그 시점에서 멈춘 모습을 그린다.
  final double? debugFreeze;

  const YutSticksStage({
    super.key,
    required this.thrown,
    required this.seed,
    this.skin = 'base',
    this.onLanded,
    this.onDone,
    this.throwerName,
    this.debugFreeze,
  });

  static Duration durationFor(YutThrow t) =>
      Duration(milliseconds: t.isBig ? 3000 : 1700);

  @override
  State<YutSticksStage> createState() => _YutSticksStageState();
}

class _YutSticksStageState extends State<YutSticksStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: YutSticksStage.durationFor(widget.thrown),
  );
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    if (widget.debugFreeze != null) {
      _ctl.value = widget.debugFreeze!;
      return;
    }
    _ctl.addListener(() {
      if (!_landed && _ctl.value >= 0.86) {
        _landed = true;
        widget.onLanded?.call();
      }
    });
    _ctl.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = widget.thrown.isBig;
    final label = yutCallout(widget.thrown);
    final labelColor = switch (widget.thrown.result) {
      4 => Obangsaek.red,
      5 => Obangsaek.blue,
      _ => Obangsaek.black,
    };
    return Semantics(
      label: '윷가락 던지기 결과, ${widget.thrown.resultName}',
      child: AspectRatio(
        aspectRatio: 1.8,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) {
            final t = _ctl.value;
            final zoom = big ? 1 + 0.06 * Curves.easeOut.transform(t) : 1.0;
            final reveal = ((t - 0.86) / 0.14).clamp(0.0, 1.0);
            return Transform.scale(
              scale: zoom,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _MatPainter(),
                    foregroundPainter: _SticksPainter(
                      t: t,
                      sticks: widget.thrown.sticks,
                      seed: widget.seed,
                      palette: YutStickPalette.of(widget.skin),
                      big: big,
                    ),
                  ),
                  if (widget.throwerName != null)
                    Positioned(
                      left: 14,
                      top: 10,
                      child: Text(
                        widget.throwerName == '내'
                            ? '내 윷'
                            : '${widget.throwerName}의 윷',
                        style: GoogleFonts.notoSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF5B4620),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    child: Opacity(
                      opacity: reveal,
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * Curves.easeOutBack.transform(reveal),
                        child: Center(
                          child: _InkLabel(text: label, color: labelColor),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InkLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _InkLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.nanumBrushScript(
      fontSize: 46,
      color: color,
      height: 1.0,
    );
    return Stack(
      children: [
        // 먹이 번진 듯한 옅은 그림자.
        Text(
          text,
          style: style.copyWith(
            color: Colors.black.withValues(alpha: 0.18),
            shadows: const [Shadow(blurRadius: 8, color: Color(0x33000000))],
          ),
        ),
        Text(text, style: style),
      ],
    );
  }
}

/// 멍석: 짚을 엮은 바탕 + 둘레 띠.
class _MatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      rr.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDBF76), Color(0xFFC9A55B)],
        ).createShader(rect),
    );
    // 가로 짚 가닥(결이 다른 선 여러 겹).
    final rnd = math.Random(8);
    final strand = Paint()..strokeCap = StrokeCap.round;
    for (double y = 3; y < size.height; y += 3.2) {
      strand
        ..strokeWidth = 1.1 + rnd.nextDouble() * 0.9
        ..color = (rnd.nextBool()
            ? const Color(0x228A6A2A)
            : const Color(0x2CFFF1C4));
      final jitter = rnd.nextDouble() * 1.4;
      canvas.drawLine(
        Offset(0, y + jitter),
        Offset(size.width, y - jitter),
        strand,
      );
    }
    // 세로 엮음 매듭.
    final knot = Paint()
      ..color = const Color(0x40704F1E)
      ..strokeWidth = 2.2;
    for (double x = 22; x < size.width; x += 34) {
      for (double y = 6; y < size.height; y += 12) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5), knot);
      }
    }
    // 가장자리 안쪽 그림자.
    canvas.drawRRect(
      rr.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0x22000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
    // 둘레 띠(짙은 짚단 + 꿰맨 자국).
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF8A6A32),
    );
    final stitch = Paint()
      ..color = const Color(0xFFF1DEA6)
      ..strokeWidth = 1.2;
    for (double x = 14; x < size.width - 10; x += 12) {
      canvas.drawLine(Offset(x, 6), Offset(x + 5, 6), stitch);
      canvas.drawLine(
        Offset(x, size.height - 6),
        Offset(x + 5, size.height - 6),
        stitch,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StickMotion {
  final double endX; // 0..1 of width
  final double endY; // 0..1 of height
  final double yawEnd;
  final double yawSpin;
  final double rollSpin;
  final double startX;
  final double hang;

  _StickMotion({
    required this.endX,
    required this.endY,
    required this.yawEnd,
    required this.yawSpin,
    required this.rollSpin,
    required this.startX,
    required this.hang,
  });
}

class _SticksPainter extends CustomPainter {
  final double t;
  final List<int> sticks;
  final int seed;
  final YutStickPalette palette;
  final bool big;

  _SticksPainter({
    required this.t,
    required this.sticks,
    required this.seed,
    required this.palette,
    required this.big,
  });

  /// 윷가락 i의 움직임 매개변수(seed로 고정).
  _StickMotion _motion(int i) {
    final r = math.Random(seed * 7919 + i * 104729 + 13);
    final slot = (i + 0.5) / 4;
    return _StickMotion(
      endX: 0.5 + (slot - 0.5) * 0.78 + (r.nextDouble() - 0.5) * 0.03,
      endY: 0.62 + (r.nextDouble() - 0.5) * 0.06,
      yawEnd: (r.nextDouble() - 0.5) * 0.5 + (i.isEven ? 0.06 : -0.06),
      yawSpin:
          (r.nextBool() ? 1 : -1) * (math.pi * (2.2 + r.nextDouble() * 1.4)),
      rollSpin: (math.pi * (big ? 7 : 5)) + math.pi * 2 * i,
      startX: 0.5 + (i - 1.5) * 0.045,
      hang: 0.9 + r.nextDouble() * 0.25,
    );
  }

  static double _ease(double x) => 1 - math.pow(1 - x, 3).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final order = List.generate(4, (i) => i);
    final states = <int, ({Offset pos, double z, double yaw, double roll})>{};
    for (final i in order) {
      final m = _motion(i);
      // 0..0.55 비행(포물선), 0.55..1 구르며 튕김.
      final fly = (t / 0.55).clamp(0.0, 1.0);
      final fx = Curves.easeOutQuad.transform(fly);
      final start = Offset(size.width * m.startX, size.height * 1.12);
      final end = Offset(size.width * m.endX, size.height * m.endY);
      var pos = Offset.lerp(start, end, fx)!;
      double z;
      if (t < 0.55) {
        z = 4 * fly * (1 - fly) * m.hang;
      } else {
        final u = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
        final decay = math.pow(1 - u, 2).toDouble();
        z = 0.34 * decay * math.sin(u * math.pi * 2.6).abs();
        pos = end + Offset((1 - u) * (i.isEven ? 5 : -5) * decay, 0);
      }
      final e = _ease(t);
      final yaw = m.yawEnd + m.yawSpin * (1 - e);
      final roll = (sticks[i] == 0 ? 0.0 : math.pi) + m.rollSpin * (1 - e);
      states[i] = (pos: pos, z: z, yaw: yaw, roll: roll);
    }
    // 낮은 것부터(높이 순) 그려 겹침이 자연스럽게.
    order.sort((a, b) => states[a]!.z.compareTo(states[b]!.z));
    final len = size.height * 0.6;
    final thick = size.width * 0.072;
    for (final i in order) {
      final s = states[i]!;
      // 그림자: 높을수록 멀고 옅고 퍼진다.
      final shadowOffset = Offset(8 + 20 * s.z, 6 + 22 * s.z);
      canvas.save();
      canvas.translate(s.pos.dx + shadowOffset.dx, s.pos.dy + shadowOffset.dy);
      canvas.rotate(s.yaw + math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: len, height: thick * 0.9),
          Radius.circular(thick / 2),
        ),
        Paint()
          ..color = Colors.black.withValues(
            alpha: (0.30 - 0.16 * s.z).clamp(0.08, 0.3),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + 6 * s.z),
      );
      canvas.restore();
      _paintStick(canvas, i, s.pos, s.z, s.yaw, s.roll, len, thick);
    }
  }

  void _paintStick(
    Canvas canvas,
    int index,
    Offset center,
    double z,
    double yaw,
    double roll,
    double len,
    double thick,
  ) {
    final scale = 1 + 0.55 * z;
    final c = math.cos(roll);
    final visible = thick * scale * (0.5 + 0.5 * c.abs());
    final flatUp = c >= 0;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: len * scale, height: visible),
      Radius.circular(visible / 2),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy - 26 * z);
    // 긴 축을 세로로 두고 yaw만큼 돌린다.
    canvas.rotate(yaw + math.pi / 2);
    final base = flatUp ? palette.flat : palette.round;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: flatUp
              ? [
                  Color.lerp(base, Colors.white, 0.28)!,
                  base,
                  Color.lerp(base, Colors.black, 0.1)!,
                ]
              : [
                  Color.lerp(base, Colors.white, 0.22)!,
                  base,
                  Color.lerp(base, Colors.black, 0.4)!,
                ],
        ).createShader(body.outerRect),
    );
    // 모서리에서 보이는 반대 면 띠(굴러가는 중).
    if (c.abs() < 0.45) {
      final other = flatUp ? palette.round : palette.flat;
      final sign = math.sin(roll) >= 0 ? 1.0 : -1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -len * scale / 2 + 2,
            sign > 0 ? -visible / 2 : visible / 2 - visible * 0.28,
            len * scale - 4,
            visible * 0.28,
          ),
          Radius.circular(visible * 0.14),
        ),
        Paint()..color = other.withValues(alpha: 0.9),
      );
    }
    // 결: 둥근 면은 껍질 결, 납작한 면은 가는 나뭇결.
    final grain = Paint()
      ..color = palette.grain.withValues(alpha: flatUp ? 0.35 : 0.5)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (final off in [-0.28, 0.0, 0.28]) {
      canvas.drawLine(
        Offset(-len * scale * 0.44, visible * off),
        Offset(len * scale * 0.44, visible * off + (flatUp ? 0 : 1.2)),
        grain,
      );
    }
    if (flatUp && c.abs() > 0.5) {
      // 납작한 면: 새긴 눈금 두 줄.
      final carve = Paint()
        ..color = const Color(0x553A2A12)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (final dx in [-0.18, 0.0, 0.18]) {
        canvas.drawLine(
          Offset(len * scale * dx, -visible * 0.26),
          Offset(len * scale * dx, visible * 0.26),
          carve,
        );
      }
      if (index == 0) {
        // 표시 막대(빽도 표시): 붉은 먹으로 ×.
        final mark = Paint()
          ..color = Obangsaek.red
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        final a = visible * 0.2;
        final mx = len * scale * 0.3;
        canvas.drawLine(Offset(mx - a, -a), Offset(mx + a, a), mark);
        canvas.drawLine(Offset(mx - a, a), Offset(mx + a, -a), mark);
      }
    }
    // 윤곽(먹선)과 윗면 하이라이트.
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xCC2A1A0A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -visible * 0.22),
          width: len * scale * 0.86,
          height: visible * 0.16,
        ),
        Radius.circular(visible * 0.08),
      ),
      Paint()..color = Colors.white.withValues(alpha: flatUp ? 0.32 : 0.2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SticksPainter old) =>
      old.t != t || old.seed != seed || old.palette != palette;
}
