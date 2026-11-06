import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'yut_models.dart';

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

  // 이름 → 모습. 0018 카탈로그 18종 + 예전 5종.
  static const Map<String, YutStickLook> byName = {
    // B
    '벚꽃 윷': YutStickLook(
      'cherry',
      Color(0xFFFFE3EA),
      Color(0xFFD9577F),
      Color(0xFFF08AA8),
      stripe: Color(0xFFFFFFFF),
    ),
    '단풍 윷': YutStickLook(
      'maple',
      Color(0xFFF8D79A),
      Color(0xFFA63F1B),
      Color(0xFFD9772B),
      stripe: Color(0xFFE8892B),
    ),
    '새싹 윷': YutStickLook(
      'sprout',
      Color(0xFFE2F4B6),
      Color(0xFF4F8F2B),
      Color(0xFF86C14A),
      stripe: Color(0xFFB6E36B),
    ),
    '조약돌 윷': YutStickLook(
      'pebble',
      Color(0xFFDAD7CF),
      Color(0xFF55534E),
      Color(0xFF8A877F),
    ),
    '대나무 윷': YutStickLook(
      'bamboo',
      Color(0xFFDDEFA8),
      Color(0xFF3E7A2B),
      Color(0xFF6FA84A),
      stripe: Color(0xFF2F5E20),
    ),
    // A
    '달빛 윷': YutStickLook(
      'moon',
      Color(0xFFF7F2CC),
      Color(0xFF34406E),
      Color(0xFF5967A0),
      glow: Color(0xFFFFF4B0),
    ),
    '바람 윷': YutStickLook(
      'wind',
      Color(0xFFE8F8F4),
      Color(0xFF4E9E96),
      Color(0xFF86CBC2),
      stripe: Color(0xFFFFFFFF),
      glow: Color(0xFFBDEFE6),
    ),
    '눈꽃 윷': YutStickLook(
      'snow',
      Color(0xFFF6FBFF),
      Color(0xFF8FC1E6),
      Color(0xFFC9E4F6),
      sparkle: true,
    ),
    '파도 윷': YutStickLook(
      'wave',
      Color(0xFFD2ECFC),
      Color(0xFF1E6AA6),
      Color(0xFF4F9AD0),
      stripe: Color(0xFF8FD0F5),
    ),
    '황금 윷': YutStickLook(
      'gold',
      Color(0xFFFFE680),
      Color(0xFFB8860B),
      Color(0xFFDAA520),
      glow: Color(0xFFFFD34D),
    ),
    // S
    '번개 윷': YutStickLook(
      'lightning',
      Color(0xFFFFF7AA),
      Color(0xFF55369E),
      Color(0xFF8A62D8),
      stripe: Color(0xFFFFE23D),
      glow: Color(0xFFFFE23D),
    ),
    '태양 윷': YutStickLook(
      'sun',
      Color(0xFFFFE470),
      Color(0xFFE0701C),
      Color(0xFFFFA23C),
      glow: Color(0xFFFFA21F),
      sparkle: true,
    ),
    '얼음 윷': YutStickLook(
      'ice',
      Color(0xFFE6F9FF),
      Color(0xFF5DB6E4),
      Color(0xFFA9E1F8),
      glow: Color(0xFF9EE6FF),
      glassy: true,
    ),
    '폭풍 윷': YutStickLook(
      'storm',
      Color(0xFFCBD1E2),
      Color(0xFF353C66),
      Color(0xFF5F69A0),
      stripe: Color(0xFF7FE0FF),
      glow: Color(0xFF6C7BD6),
    ),
    '크리스탈 윷': YutStickLook(
      'crystal',
      Color(0xFFD7F0F7),
      Color(0xFF3B6FA1),
      Color(0xFF7AA9D2),
      glow: Color(0xFF8ED1FF),
      glassy: true,
    ),
    // SS
    '용의 윷': YutStickLook(
      'dragon',
      Color(0xFFB9F2C9),
      Color(0xFF1A6B45),
      Color(0xFF3FA874),
      stripe: Color(0xFFFFD34D),
      glow: Color(0xFF44E08A),
      sparkle: true,
    ),
    '봉황 윷': YutStickLook(
      'phoenix',
      Color(0xFFFFD4A8),
      Color(0xFFC2341F),
      Color(0xFFF2762B),
      stripe: Color(0xFFFFD34D),
      glow: Color(0xFFFF8A3D),
      sparkle: true,
    ),
    '천둥 윷': YutStickLook(
      'thunder',
      Color(0xFFDDD3FF),
      Color(0xFF4A2D9C),
      Color(0xFF8566DE),
      stripe: Color(0xFFFFE23D),
      glow: Color(0xFFA27BFF),
      sparkle: true,
    ),
    '불꽃 윷': YutStickLook(
      'flame',
      Color(0xFFFFC27A),
      Color(0xFFA32A1C),
      Color(0xFFFF6B2B),
      stripe: Color(0xFFFFDD55),
      glow: Color(0xFFFF6A2B),
      sparkle: true,
    ),
    // SSS
    '신들의 윷': YutStickLook(
      'gods',
      Color(0xFFFFF3C4),
      Color(0xFFB8860B),
      Color(0xFFFFD34D),
      glow: Color(0xFFFFE680),
      sparkle: true,
      rainbow: true,
    ),
    '우주의 윷': YutStickLook(
      'cosmos',
      Color(0xFF6A58B8),
      Color(0xFF130E30),
      Color(0xFF3C2F80),
      stripe: Color(0xFFB9A8FF),
      glow: Color(0xFF8E7BFF),
      sparkle: true,
      rainbow: true,
    ),
    '운명의 윷': YutStickLook(
      'destiny',
      Color(0xFFFFD8EA),
      Color(0xFF8E1B58),
      Color(0xFFE05AA0),
      stripe: Color(0xFFFFD34D),
      glow: Color(0xFFFF7BC0),
      sparkle: true,
      rainbow: true,
    ),
    '전설의 윷': YutStickLook(
      'legend',
      Color(0xFFE8C8F5),
      Color(0xFF5A1D8F),
      Color(0xFFA066D6),
      glow: Color(0xFFD08BFF),
      sparkle: true,
      rainbow: true,
    ),
  };

  // 이름을 몰라도 아이콘으로 고르는 예비 모습.
  static const Map<String, YutStickLook> _byIcon = {
    '🌸': YutStickLook(
      'icon-cherry',
      Color(0xFFFFE3EA),
      Color(0xFFD9577F),
      Color(0xFFF08AA8),
    ),
    '🍁': YutStickLook(
      'icon-maple',
      Color(0xFFF8D79A),
      Color(0xFFA63F1B),
      Color(0xFFD9772B),
    ),
    '🌱': YutStickLook(
      'icon-sprout',
      Color(0xFFE2F4B6),
      Color(0xFF4F8F2B),
      Color(0xFF86C14A),
    ),
    '🪨': YutStickLook(
      'icon-stone',
      Color(0xFFDAD7CF),
      Color(0xFF55534E),
      Color(0xFF8A877F),
    ),
    '🌙': YutStickLook(
      'icon-moon',
      Color(0xFFF7F2CC),
      Color(0xFF34406E),
      Color(0xFF5967A0),
      glow: Color(0xFFFFF4B0),
    ),
    '💨': YutStickLook(
      'icon-wind',
      Color(0xFFE8F8F4),
      Color(0xFF4E9E96),
      Color(0xFF86CBC2),
    ),
    '❄️': YutStickLook(
      'icon-snow',
      Color(0xFFF6FBFF),
      Color(0xFF8FC1E6),
      Color(0xFFC9E4F6),
      sparkle: true,
    ),
    '🌊': YutStickLook(
      'icon-wave',
      Color(0xFFD2ECFC),
      Color(0xFF1E6AA6),
      Color(0xFF4F9AD0),
    ),
    '⚡': YutStickLook(
      'icon-bolt',
      Color(0xFFFFF7AA),
      Color(0xFF55369E),
      Color(0xFF8A62D8),
      glow: Color(0xFFFFE23D),
    ),
    '☀️': YutStickLook(
      'icon-sun',
      Color(0xFFFFE470),
      Color(0xFFE0701C),
      Color(0xFFFFA23C),
      glow: Color(0xFFFFA21F),
    ),
    '🧊': YutStickLook(
      'icon-ice',
      Color(0xFFE6F9FF),
      Color(0xFF5DB6E4),
      Color(0xFFA9E1F8),
      glassy: true,
    ),
    '🌪️': YutStickLook(
      'icon-storm',
      Color(0xFFCBD1E2),
      Color(0xFF353C66),
      Color(0xFF5F69A0),
    ),
    '🐉': YutStickLook(
      'icon-dragon',
      Color(0xFFB9F2C9),
      Color(0xFF1A6B45),
      Color(0xFF3FA874),
      glow: Color(0xFF44E08A),
    ),
    '🦅': YutStickLook(
      'icon-phoenix',
      Color(0xFFFFD4A8),
      Color(0xFFC2341F),
      Color(0xFFF2762B),
      glow: Color(0xFFFF8A3D),
    ),
    '⛈️': YutStickLook(
      'icon-thunder',
      Color(0xFFDDD3FF),
      Color(0xFF4A2D9C),
      Color(0xFF8566DE),
      glow: Color(0xFFA27BFF),
    ),
    '✨': YutStickLook(
      'icon-gods',
      Color(0xFFFFF3C4),
      Color(0xFFB8860B),
      Color(0xFFFFD34D),
      sparkle: true,
      rainbow: true,
    ),
    '🌌': YutStickLook(
      'icon-cosmos',
      Color(0xFF6A58B8),
      Color(0xFF130E30),
      Color(0xFF3C2F80),
      sparkle: true,
      rainbow: true,
    ),
    '🎯': YutStickLook(
      'icon-destiny',
      Color(0xFFFFD8EA),
      Color(0xFF8E1B58),
      Color(0xFFE05AA0),
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
  static YutStickLook fromItem(Map<String, dynamic>? item) {
    if (item == null) return base;
    final byNameHit = byName['${item['name'] ?? ''}'.trim()];
    if (byNameHit != null) return byNameHit;
    final byIconHit = _byIcon['${item['icon'] ?? ''}'];
    if (byIconHit != null) return byIconHit;
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

/// 둥근 통나무 단면(윷판 옆 던지는 자리)과 그 위의 윷가락 네 개.
/// 막대는 서버 `sticks`(0=납작, 1=둥근, 0번이 표시 막대)대로 멈춘다. [t]는 0..1 진행도.
class YutSlab extends StatelessWidget {
  final List<int> sticks;
  final int seed;
  final YutStickLook look;
  final double t;
  final bool big;

  const YutSlab({
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
        painter: _SlabPainter(),
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
    final big = widget.thrown.isBig;
    final label = yutCallout(widget.thrown);
    final labelColor = switch (widget.thrown.result) {
      4 => const Color(0xFFE5534B),
      5 => const Color(0xFF2F82DE),
      _ => const Color(0xFF263A2A),
    };
    return Semantics(
      label: '윷가락 던지기 결과, ${widget.thrown.resultName}',
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = _ctl.value;
          final zoom = big ? 1 + 0.05 * Curves.easeOut.transform(t) : 1.0;
          final reveal = ((t - 0.86) / 0.14).clamp(0.0, 1.0);
          return Transform.scale(
            scale: zoom,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                YutSlab(
                  sticks: widget.thrown.sticks,
                  seed: widget.seed,
                  look: widget.look,
                  t: t,
                  big: big,
                ),
                if (widget.throwerName != null)
                  Positioned(
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        widget.throwerName == '내'
                            ? '내가 던져요'
                            : '${widget.throwerName}의 윷',
                        style: GoogleFonts.notoSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: -6,
                  child: Opacity(
                    opacity: reveal,
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * Curves.easeOutBack.transform(reveal),
                      child: _CalloutLabel(text: label, color: labelColor),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 흰 테두리가 둘린 통통한 결과 글자("윷이야!").
class _CalloutLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _CalloutLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final fill = GoogleFonts.jua(fontSize: 40, color: color, height: 1.0);
    final outline = fill.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    return Stack(
      children: [
        Text(text, style: outline),
        Text(text, style: fill),
      ],
    );
  }
}

/// 통나무 단면: 옆면 두께 + 나이테 + 껍질 테두리 + 바닥 그림자.
class _SlabPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final top = Rect.fromLTWH(s * 0.04, s * 0.05, s * 0.92, s * 0.78);
    final side = top.shift(Offset(0, s * 0.075));
    // 바닥 그림자.
    canvas.drawOval(
      side.inflate(s * 0.02).shift(Offset(0, s * 0.03)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.035),
    );
    // 옆면(껍질).
    canvas.drawOval(
      side,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8A5A2E), Color(0xFF5C3A1C)],
        ).createShader(side),
    );
    final bark = Paint()
      ..color = const Color(0x553A2210)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (double a = 0.15; a < math.pi; a += 0.28) {
      final x = top.center.dx + math.cos(a) * top.width / 2 * 0.98;
      canvas.drawLine(
        Offset(x, top.center.dy + math.sin(a) * top.height / 2),
        Offset(x, top.center.dy + math.sin(a) * top.height / 2 + s * 0.07),
        bark,
      );
    }
    // 윗면(속살).
    canvas.drawOval(
      top,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFFF2D49A), Color(0xFFDDB070)],
        ).createShader(top),
    );
    canvas.drawOval(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = const Color(0xFF8A5A2E),
    );
    // 나이테.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int i = 1; i <= 7; i++) {
      final k = i / 8;
      ring.color = const Color(
        0xFF9A6A38,
      ).withValues(alpha: i.isEven ? 0.28 : 0.16);
      canvas.drawOval(
        Rect.fromCenter(
          center: top.center.translate(s * 0.012 * (4 - i) / 4, 0),
          width: top.width * k,
          height: top.height * k,
        ),
        ring,
      );
    }
    // 갈라진 결 두 줄.
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3
      ..color = const Color(0x553A2210);
    canvas.drawLine(
      top.center,
      top.center.translate(top.width * 0.34, -top.height * 0.1),
      crack,
    );
    canvas.drawLine(
      top.center.translate(-top.width * 0.05, top.height * 0.04),
      top.center.translate(-top.width * 0.3, top.height * 0.22),
      crack,
    );
    // 윗면 하이라이트.
    canvas.drawOval(
      Rect.fromLTWH(
        top.left + top.width * 0.12,
        top.top + top.height * 0.08,
        top.width * 0.4,
        top.height * 0.16,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      endY: 0.46 + (r.nextDouble() - 0.5) * 0.05,
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
    final len = size.height * 0.56;
    final thick = size.width * 0.092;
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
