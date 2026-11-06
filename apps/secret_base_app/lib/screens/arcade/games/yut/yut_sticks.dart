import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'yut_models.dart';
import 'yut_palette.dart';

/// 윷가락 겉모습(상점 윷 스킨마다 하나). 이름이 정확히 맞는 아이템을 먼저 찾고,
/// 모르는 이름은 아이콘, 그래도 없으면 등급으로 알맞은 모습을 고른다.
@immutable
class YutStickLook {
  final String id;

  /// 납작한 면 / 둥근 면 / 결 색.
  final Color flat;
  final Color round;
  final Color grain;

  /// 무늬(줄무늬)·빛·반짝임.
  final Color? stripe;
  final Color? glow;
  final bool sparkle;
  final bool rainbow;

  /// 얼음·수정처럼 맑은 느낌(납작한 면에 흰 하이라이트를 더한다).
  final bool glassy;

  const YutStickLook(
    this.id,
    this.flat,
    this.round,
    this.grain, {
    this.stripe,
    this.glow,
    this.sparkle = false,
    this.rainbow = false,
    this.glassy = false,
  });

  /// 겉모습을 구별하는 값(테스트가 모든 아이템이 서로 다른지 확인한다).
  String get signature =>
      '${flat.toARGB32()}-${round.toARGB32()}-${stripe?.toARGB32()}-${glow?.toARGB32()}-$sparkle-$rainbow-$glassy';

  static const base = YutStickLook(
    'base',
    Color(0xFFF1DCAE),
    Color(0xFF7B4B2A),
    Color(0xFFC9A66B),
  );

  // 이름 → 모습. 상점 윷 스킨 9종(마이그레이션 0049)마다 하나씩, 등급이 높을수록 화려하다.
  static const Map<String, YutStickLook> byName = {
    // B: 소재 그대로의 소박한 모습
    '대나무 윷': YutStickLook(
      'bamboo',
      Color(0xFFDDEFA8),
      Color(0xFF3E7A2B),
      Color(0xFF6FA84A),
      stripe: Color(0xFF2F5E20),
    ),
    '단풍 윷': YutStickLook(
      'maple',
      Color(0xFFF8D79A),
      Color(0xFFA63F1B),
      Color(0xFFD9772B),
      stripe: Color(0xFFE8892B),
    ),
    // A: 은은한 빛과 무늬
    '달빛 윷': YutStickLook(
      'moon',
      Color(0xFFF7F2CC),
      Color(0xFF34406E),
      Color(0xFF5967A0),
      glow: Color(0xFFFFF4B0),
    ),
    '옥 윷': YutStickLook(
      'jade',
      Color(0xFFD6F3E3),
      Color(0xFF2F8F63),
      Color(0xFF6CC79B),
      stripe: Color(0xFFEFFFF6),
      glow: Color(0xFF9CE6C0),
      glassy: true,
    ),
    // S: 기운이 뚜렷한 빛
    '얼음 윷': YutStickLook(
      'ice',
      Color(0xFFE6F9FF),
      Color(0xFF5DB6E4),
      Color(0xFFA9E1F8),
      glow: Color(0xFF9EE6FF),
      glassy: true,
    ),
    '번개 윷': YutStickLook(
      'lightning',
      Color(0xFFFFF7AA),
      Color(0xFF55369E),
      Color(0xFF8A62D8),
      stripe: Color(0xFFFFE23D),
      glow: Color(0xFFFFE23D),
    ),
    // SS: 불꽃·용의 반짝임
    '불꽃 윷': YutStickLook(
      'flame',
      Color(0xFFFFC27A),
      Color(0xFFA32A1C),
      Color(0xFFFF6B2B),
      stripe: Color(0xFFFFDD55),
      glow: Color(0xFFFF6A2B),
      sparkle: true,
    ),
    '용의 윷': YutStickLook(
      'dragon',
      Color(0xFFB9F2C9),
      Color(0xFF1A6B45),
      Color(0xFF3FA874),
      stripe: Color(0xFFFFD34D),
      glow: Color(0xFF44E08A),
      sparkle: true,
    ),
    // SSS: 신화 속 무지갯빛
    '신들의 윷': YutStickLook(
      'gods',
      Color(0xFFFFF3C4),
      Color(0xFFB8860B),
      Color(0xFFFFD34D),
      stripe: Color(0xFFFFFFFF),
      glow: Color(0xFFFFE680),
      sparkle: true,
      rainbow: true,
    ),
  };

  static const _byGrade = <String, YutStickLook>{
    'A': YutStickLook(
      'grade-a',
      Color(0xFFE3EDF5),
      Color(0xFF5C7893),
      Color(0xFF9DB6CC),
      glow: Color(0xFFC9D8E6),
    ),
    'S': YutStickLook(
      'grade-s',
      Color(0xFFFFE680),
      Color(0xFFB8860B),
      Color(0xFFDAA520),
      glow: Color(0xFFFFD34D),
    ),
    'SS': YutStickLook(
      'grade-ss',
      Color(0xFFDDD3FF),
      Color(0xFF4A2D9C),
      Color(0xFF8566DE),
      glow: Color(0xFFA27BFF),
      sparkle: true,
    ),
    'SSS': YutStickLook(
      'grade-sss',
      Color(0xFFFFF3C4),
      Color(0xFFB8860B),
      Color(0xFFFFD34D),
      glow: Color(0xFFFFE680),
      sparkle: true,
      rainbow: true,
    ),
  };

  /// 장착한 `yut_yut` 아이템(서버 `equippedItems`의 한 칸)에서 모습을 정한다.
  /// 모르는 이름(옛 아이템 등)은 등급으로, 그래도 모르면 기본 윷으로 — 절대 실패하지 않는다.
  static YutStickLook fromItem(Map<String, dynamic>? item) {
    if (item == null) return base;
    final hit = byName['${item['name'] ?? ''}'.trim()];
    if (hit != null) return hit;
    return _byGrade['${item['grade'] ?? ''}'] ?? base;
  }
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

/// 윷판 위에 잠깐 펼치는 민트빛 돗자리와 그 위의 윷가락 네 개.
/// 막대는 서버 `sticks`(0=납작, 1=둥근, 0번이 표시 막대)대로 멈춘다. [t]는 0..1 진행도.
class YutMat extends StatelessWidget {
  final List<int> sticks;
  final int seed;
  final YutStickLook look;
  final double t;
  final bool big;

  const YutMat({
    super.key,
    required this.sticks,
    required this.seed,
    required this.look,
    this.t = 1,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _MatPainter(YutPalette.of(context)),
        foregroundPainter: _SticksPainter(
          t: t,
          sticks: sticks,
          seed: seed,
          look: look,
          big: big,
        ),
      ),
    );
  }
}

/// 던지는 연출: 막대가 포물선으로 날아와 통나무 위에서 구르다 서버 결과대로 멈춘다.
/// 윷·모는 슬로모션(길게). 착지(≈0.86)에서 [onLanded], 끝에서 [onDone].
class YutSticksStage extends StatefulWidget {
  final YutThrow thrown;
  final int seed;
  final YutStickLook look;
  final VoidCallback? onLanded;
  final VoidCallback? onDone;
  final String? throwerName;

  /// 테스트용: 0..1 사이 값이면 그 시점에서 멈춘 모습을 그린다.
  final double? debugFreeze;

  const YutSticksStage({
    super.key,
    required this.thrown,
    required this.seed,
    this.look = YutStickLook.base,
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
    final p = YutPalette.of(context);
    final big = widget.thrown.isBig;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: '윷가락 던지기 결과, ${widget.thrown.resultName}',
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = _ctl.value;
          final appear = Curves.easeOut.transform((t / 0.1).clamp(0.0, 1.0));
          final reveal = ((t - 0.84) / 0.16).clamp(0.0, 1.0);
          // 도장 쾅: 크게 시작해 눌러 앉으며 살짝 튀어 오른다(모션 줄이기면 바로 제자리).
          final pop = reduce ? 1.0 : Curves.easeOutBack.transform(reveal);
          final stampScale = 1.55 - 0.55 * pop;
          return Opacity(
            opacity: appear,
            child: Transform.scale(
              scale:
                  (big && !reduce ? 1 + 0.03 * t : 1.0) *
                  (0.95 + 0.05 * appear),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  YutMat(
                    sticks: widget.thrown.sticks,
                    seed: widget.seed,
                    look: widget.look,
                    t: t,
                    big: big,
                  ),
                  if (widget.throwerName != null)
                    Positioned(
                      top: 10,
                      child: Text(
                        widget.throwerName == '내'
                            ? '내가 던졌어요'
                            : '${widget.throwerName}의 윷',
                        style: p.body(
                          size: 13,
                          color: p.sub,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (reveal > 0)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: reveal.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: stampScale,
                          child: _Stamp(thrown: widget.thrown),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 결과 도장: 살짝 기울어진 흰 판에 큰 글자, 아래에 알약 설명, 주위에 반짝이는 마름모.
class _Stamp extends StatelessWidget {
  final YutThrow thrown;

  const _Stamp({required this.thrown});

  String get word => thrown.nak ? '낙' : thrown.resultName;

  String get note {
    if (thrown.nak) return '말이 없어 넘어가요';
    if (thrown.bonus) return '한 번 더 던져요!';
    if (thrown.result == -1) return '한 칸 뒤로';
    return '${thrown.result}칸 가요';
  }

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.maxWidth * 0.42;
        final fontSize = word.length > 1 ? size * 0.5 : size * 0.68;
        return Align(
          alignment: const Alignment(0, -0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: -0.1,
                child: SizedBox(
                  width: size + 40,
                  height: size + 14,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _SparklePainter(p.acc)),
                      ),
                      Positioned(
                        top: 10,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: p.acc2,
                            borderRadius: BorderRadius.circular(size * 0.22),
                          ),
                        ),
                      ),
                      Container(
                        width: size,
                        height: size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.plate,
                          borderRadius: BorderRadius.circular(size * 0.22),
                          border: Border.all(color: p.acc, width: 4),
                        ),
                        child: CustomPaint(
                          painter: _DashPainter(
                            p.acc.withValues(alpha: 0.45),
                            size * 0.22,
                          ),
                          child: Center(
                            child: Text(
                              word,
                              style: p.display(
                                size: fontSize,
                                color: p.accText,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: p.acc,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(color: p.acc2, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(note, style: p.display(size: 18, color: p.onAcc)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashPainter(this.color, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(8),
      Radius.circular(radius * 0.8),
    );
    final path = Path()..addRRect(rect);
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(
          m.extractPath(d, math.min(m.length, d + 5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final o in const [
      Offset(0.02, 0.22),
      Offset(0.98, 0.34),
      Offset(0.08, 0.84),
      Offset(0.94, 0.78),
      Offset(0.5, -0.02),
    ]) {
      final c = Offset(size.width * o.dx, size.height * o.dy);
      final r = 6.0;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.6, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.6, c.dy)
          ..close(),
        paint,
      );
    }
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.08), 3, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.9), 3, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

/// 돗자리: 둥근 사각 판 + 아랫면 두께 + 옅은 격자(낮은 민트, 밤은 남색에 호박빛 격자).
class _MatPainter extends CustomPainter {
  final YutPalette p;

  _MatPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final r = s * 0.1;
    final top = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.02, s * 0.02, s * 0.96, s * 0.9),
      Radius.circular(r),
    );
    canvas.drawRRect(
      top.shift(Offset(0, s * 0.05)).inflate(s * 0.005),
      Paint()
        ..color = p.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );
    canvas.drawRRect(
      top.shift(Offset(0, s * 0.03)),
      Paint()..color = p.matEdge,
    );
    canvas.drawRRect(top, Paint()..color = p.mat);
    canvas.save();
    canvas.clipRRect(top);
    final grid = Paint()
      ..strokeWidth = 1
      ..color = p.matLine;
    for (double d = s * 0.02; d < s; d += s * 0.045) {
      canvas.drawLine(Offset(d, 0), Offset(d, s), grid);
      canvas.drawLine(Offset(0, d), Offset(s, d), grid);
    }
    canvas.restore();
    canvas.drawRRect(
      top.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: p.night ? 0.08 : 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _MatPainter old) => old.p != p;
}

class _StickMotion {
  final double endX;
  final double endY;
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
  final YutStickLook look;
  final bool big;

  _SticksPainter({
    required this.t,
    required this.sticks,
    required this.seed,
    required this.look,
    required this.big,
  });

  _StickMotion _motion(int i) {
    final r = math.Random(seed * 7919 + i * 104729 + 13);
    final slot = (i + 0.5) / 4;
    return _StickMotion(
      endX: 0.5 + (slot - 0.5) * 0.6 + (r.nextDouble() - 0.5) * 0.03,
      endY: 0.7 + (r.nextDouble() - 0.5) * 0.04,
      yawEnd: (r.nextDouble() - 0.5) * 0.45 + (i.isEven ? 0.05 : -0.05),
      yawSpin:
          (r.nextBool() ? 1 : -1) * (math.pi * (2.2 + r.nextDouble() * 1.4)),
      rollSpin: (math.pi * (big ? 7 : 5)) + math.pi * 2 * i,
      startX: 0.5 + (i - 1.5) * 0.05,
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
      final fly = (t / 0.55).clamp(0.0, 1.0);
      final fx = Curves.easeOutQuad.transform(fly);
      final start = Offset(size.width * m.startX, size.height * 1.15);
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
      states[i] = (
        pos: pos,
        z: z,
        yaw: m.yawEnd + m.yawSpin * (1 - e),
        roll: (sticks[i] == 0 ? 0.0 : math.pi) + m.rollSpin * (1 - e),
      );
    }
    order.sort((a, b) => states[a]!.z.compareTo(states[b]!.z));
    final len = size.height * 0.44;
    final thick = size.width * 0.085;
    for (final i in order) {
      final s = states[i]!;
      final shadowOffset = Offset(5 + 18 * s.z, 4 + 20 * s.z);
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
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + 6 * s.z),
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
    canvas.translate(center.dx, center.dy - 22 * z);
    canvas.rotate(yaw + math.pi / 2);
    // 스킨의 빛(착지 후에도 은은히 남는다).
    if (look.glow != null) {
      canvas.drawRRect(
        body.inflate(visible * 0.35),
        Paint()
          ..color = look.glow!.withValues(alpha: 0.32)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, visible * 0.7),
      );
    }
    final base = flatUp ? look.flat : look.round;
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
    if (c.abs() < 0.45) {
      final other = flatUp ? look.round : look.flat;
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
    final grain = Paint()
      ..color = look.grain.withValues(alpha: flatUp ? 0.35 : 0.5)
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    for (final off in [-0.28, 0.0, 0.28]) {
      canvas.drawLine(
        Offset(-len * scale * 0.44, visible * off),
        Offset(len * scale * 0.44, visible * off + (flatUp ? 0 : 1.2)),
        grain,
      );
    }
    // 스킨 무늬(줄무늬 띠).
    if (look.stripe != null && c.abs() > 0.3) {
      final stripe = Paint()
        ..color = look.stripe!.withValues(alpha: flatUp ? 0.6 : 0.5)
        ..strokeWidth = math.max(1.6, visible * 0.16)
        ..strokeCap = StrokeCap.round;
      for (final dx in [-0.3, 0.0, 0.3]) {
        canvas.drawLine(
          Offset(len * scale * dx - visible * 0.12, -visible * 0.32),
          Offset(len * scale * dx + visible * 0.12, visible * 0.32),
          stripe,
        );
      }
    }
    if (look.glassy) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -visible * 0.18),
            width: len * scale * 0.9,
            height: visible * 0.3,
          ),
          Radius.circular(visible * 0.15),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }
    if (flatUp && c.abs() > 0.5) {
      final carve = Paint()
        ..color = const Color(0x553A2A12)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (final dx in [-0.18, 0.0, 0.18]) {
        canvas.drawLine(
          Offset(len * scale * dx, -visible * 0.22),
          Offset(len * scale * dx, visible * 0.22),
          carve,
        );
      }
      if (index == 0) {
        // 표시 막대(빽도 표시): 붉은 ×.
        final mark = Paint()
          ..color = const Color(0xFFD83A2E)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        final a = visible * 0.2;
        final mx = len * scale * 0.3;
        canvas.drawLine(Offset(mx - a, -a), Offset(mx + a, a), mark);
        canvas.drawLine(Offset(mx - a, a), Offset(mx + a, -a), mark);
      }
    }
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
    // 반짝임: 윷가락 위에 작은 별이 깜빡인다(무지개 스킨은 색이 돈다).
    if (look.sparkle && t > 0.5) {
      final twinkle = (math.sin((t * 6 + index * 1.7) * math.pi)).abs();
      for (int k = 0; k < 3; k++) {
        final px = (-0.3 + 0.3 * k) * len * scale;
        final py = ((k + index) % 2 == 0 ? -1 : 1) * visible * 0.12;
        final r = visible * (0.16 + 0.18 * twinkle) * (k == 1 ? 1.2 : 0.8);
        final color = look.rainbow
            ? HSVColor.fromAHSV(
                1,
                ((t * 360) + index * 70 + k * 120) % 360,
                0.45,
                1,
              ).toColor()
            : Colors.white;
        final p = Path()
          ..moveTo(px, py - r)
          ..quadraticBezierTo(px, py, px + r, py)
          ..quadraticBezierTo(px, py, px, py + r)
          ..quadraticBezierTo(px, py, px - r, py)
          ..quadraticBezierTo(px, py, px, py - r);
        canvas.drawPath(
          p,
          Paint()..color = color.withValues(alpha: 0.55 + 0.45 * twinkle),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SticksPainter old) =>
      old.t != t || old.seed != seed || old.look.id != look.id;
}
