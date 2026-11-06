import 'dart:math' show pi, cos, sin;

import 'package:flutter/material.dart';

import 'shop_common.dart';

// ── Gacha Result Overlay (플립 카드 애니메이션) ───────────────────────────────

class GachaResultOverlay extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isNew;
  const GachaResultOverlay({
    super.key,
    required this.item,
    required this.isNew,
  });

  @override
  State<GachaResultOverlay> createState() => GachaResultOverlayState();
}

class GachaResultOverlayState extends State<GachaResultOverlay>
    with TickerProviderStateMixin {
  // Phase 1: accelerating spin (easeIn – slow start, fast end)
  late final AnimationController _spinCtrl;
  late final Animation<double> _spinAnim;
  // Phase 2: snap reveal (easeOut – fast start, decelerates to stop)
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;
  late final Animation<double> _scaleAnim;
  // Effects
  late final AnimationController _flashCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _idleCtrl;
  late final int _spinRotations;
  bool _flashTriggered = false;

  @override
  void initState() {
    super.initState();
    final grade = widget.item['grade'] as String? ?? 'B';

    _spinRotations = switch (grade) {
      'SSS' => 6,
      'SS' => 5,
      'S' => 4,
      _ => 3,
    };
    final spinMs = switch (grade) {
      'SSS' => 2000,
      'SS' => 1700,
      'S' => 1450,
      _ => 1200,
    };
    final flipMs = switch (grade) {
      'SSS' => 480,
      'SS' => 420,
      'S' => 370,
      _ => 330,
    };

    _spinCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: spinMs),
    );
    _flipCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: flipMs),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // easeIn: card slowly starts spinning, accelerates to peak velocity
    _spinAnim = CurvedAnimation(parent: _spinCtrl, curve: Curves.easeIn);
    // easeOut: snaps in fast (matching spin exit speed), decelerates to stop
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeOut);
    // elasticOut scale pop starting from the reveal midpoint
    _scaleAnim = CurvedAnimation(
      parent: _flipCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
    );

    // Flash + burst trigger exactly at reveal midpoint
    _flipCtrl.addListener(() {
      if (!_flashTriggered && _flipCtrl.value >= 0.5) {
        _flashTriggered = true;
        _flashCtrl.forward();
        _burstCtrl.forward();
      }
    });

    // Chain: spin → snap flip → idle glow
    _spinCtrl.forward().then((_) {
      _flipCtrl.forward().then((_) {
        if (['A', 'S', 'SS', 'SSS'].contains(grade)) {
          _idleCtrl.repeat(reverse: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _flipCtrl.dispose();
    _flashCtrl.dispose();
    _burstCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grade = widget.item['grade'] as String? ?? 'B';
    final gc = gradeColor(grade);
    final icon = widget.item['icon'] as String? ?? '✨';
    final name = widget.item['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _spinCtrl,
          _flipCtrl,
          _flashCtrl,
          _burstCtrl,
          _idleCtrl,
        ]),
        builder: (ctx, _) {
          final flash = _flashCtrl.value;
          final burst = _burstCtrl.value;
          final idle = _idleCtrl.value;
          final spinDone = _spinCtrl.status == AnimationStatus.completed;
          // Phase 1: spin angle (0 → rotations×2π, easeIn)
          final spinAngle = _spinAnim.value * _spinRotations * 2 * pi;
          // Phase 2: reveal angle (0 → π, easeOut)
          final flipAngle = _flipAnim.value * pi;
          final isRevealed = spinDone && _flipCtrl.value >= 0.5;

          // Flash: peaks at t=0.3, gone by t=0.85
          final rawFlash = flash < 0.3 ? flash / 0.3 : (1.0 - flash) / 0.7;
          final flashPeak = switch (grade) {
            'SSS' => 0.92,
            'SS' => 0.80,
            'S' => 0.65,
            'A' => 0.40,
            _ => 0.18,
          };

          return Stack(
            children: [
              // Effect layer
              CustomPaint(
                painter: _EffectPainter(
                  grade: grade,
                  color: gc,
                  burstT: burst,
                  idleT: idle,
                ),
                child: const SizedBox.expand(),
              ),

              // Card (spin phase → flip phase)
              Center(
                child: GestureDetector(
                  onTap: isRevealed ? () => Navigator.of(context).pop() : null,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(spinDone ? flipAngle : spinAngle),
                    child: spinDone
                        // Flip phase: switch face at midpoint
                        ? (isRevealed
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(pi),
                                  child: ScaleTransition(
                                    scale: _scaleAnim,
                                    child: _buildRevealCard(
                                      grade,
                                      gc,
                                      icon,
                                      name,
                                      idle,
                                    ),
                                  ),
                                )
                              : _buildHiddenCard(gc, _flipCtrl.value))
                        // Spin phase: always show hidden card (full glow)
                        : _buildHiddenCard(gc, 1.0),
                  ),
                ),
              ),

              // White flash
              if (isRevealed && flash > 0)
                IgnorePointer(
                  child: Container(
                    color: Colors.white.withValues(
                      alpha: (rawFlash.clamp(0.0, 1.0) * flashPeak),
                    ),
                  ),
                ),

              // Tap hint
              if (isRevealed && burst > 0.65)
                Positioned(
                  bottom: 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: ((burst - 0.65) / 0.2).clamp(0.0, 0.6),
                      child: const Text(
                        '화면을 누르면 닫혀요',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHiddenCard(Color gc, double flipProgress) {
    return Container(
      width: 220,
      height: 300,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12121E), Color(0xFF1A1A30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gc.withValues(alpha: 0.3 + flipProgress * 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: flipProgress * 0.45),
            blurRadius: 20 + flipProgress * 24,
            spreadRadius: flipProgress * 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 80,
            color: Colors.white.withValues(alpha: 0.15 + flipProgress * 0.25),
          ),
        ),
      ),
    );
  }

  Widget _buildRevealCard(
    String grade,
    Color gc,
    String icon,
    String name,
    double idle,
  ) {
    final glowRadius = switch (grade) {
      'SSS' => 42.0 + idle * 22,
      'SS' => 30.0 + idle * 16,
      'S' => 22.0 + idle * 10,
      'A' => 16.0 + idle * 6,
      _ => 16.0,
    };
    final spread = switch (grade) {
      'SSS' => 5.0 + idle * 5,
      'SS' => 3.0 + idle * 3,
      'S' => 2.0 + idle * 2,
      _ => 2.0,
    };
    // SSS: rainbow border color
    final borderColor = (grade == 'SSS')
        ? HSVColor.fromAHSV(1.0, idle * 360, 0.85, 1.0).toColor()
        : gc;

    return Container(
      width: 220,
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gc.withValues(alpha: 0.65),
            gc.withValues(alpha: 0.28),
            const Color(0xFF12121E),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.85),
          width: grade == 'SSS' ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gc.withValues(alpha: 0.55 + idle * 0.15),
            blurRadius: glowRadius,
            spreadRadius: spread,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gc.withValues(alpha: 0.6)),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: grade == 'SSS' ? 22 : 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: ['S', 'SS', 'SSS'].contains(grade)
                    ? [Shadow(color: gc, blurRadius: 10)]
                    : null,
              ),
            ),
          ),
          if (!widget.isNew) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '코인으로 교환 +500',
                style: TextStyle(fontSize: 11, color: Colors.amber),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _EffectPainter ────────────────────────────────────────────────────────────

class _EffectPainter extends CustomPainter {
  final String grade;
  final Color color;
  final double burstT; // 0→1 one-shot
  final double idleT; // 0→1 repeating

  const _EffectPainter({
    required this.grade,
    required this.color,
    required this.burstT,
    required this.idleT,
  });

  static int _pCount(String g) => switch (g) {
    'SSS' => 48,
    'SS' => 32,
    'S' => 24,
    'A' => 16,
    _ => 10,
  };
  static int _beamCount(String g) => switch (g) {
    'SSS' => 16,
    'SS' => 12,
    'S' => 8,
    _ => 0,
  };
  static int _ringCount(String g) => switch (g) {
    'SSS' => 3,
    'SS' => 2,
    'S' => 1,
    'A' => 1,
    _ => 0,
  };
  static double _speed(String g) => switch (g) {
    'SSS' => 330,
    'SS' => 280,
    'S' => 240,
    'A' => 190,
    _ => 150,
  };

  Color _hueColor(double hue, double alpha) =>
      HSVColor.fromAHSV(alpha.clamp(0.0, 1.0), hue % 360, 0.85, 1.0).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    if (burstT <= 0 && idleT <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint();

    // 1. Background radial glow (A+, idle-driven)
    if (['A', 'S', 'SS', 'SSS'].contains(grade) && idleT > 0) {
      final a = (0.12 + idleT * 0.14).clamp(0.0, 1.0);
      paint
        ..style = PaintingStyle.fill
        ..shader =
            RadialGradient(
              colors: [
                color.withValues(alpha: a),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(cx, cy),
                radius: size.width * 0.75,
              ),
            );
      canvas.drawCircle(Offset(cx, cy), size.width * 0.75, paint);
      paint.shader = null;
    }

    // 2. Rotating light beams (S+, idle-driven)
    final beams = _beamCount(grade);
    if (beams > 0 && idleT > 0) {
      final beamLen = size.width * 0.62;
      final rot = idleT * pi * 0.5; // 90° over cycle
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = grade == 'SSS' ? 2.5 : 1.8;
      for (int i = 0; i < beams; i++) {
        final a = (2 * pi * i / beams) + rot;
        final beamAlpha = (0.28 + idleT * 0.32).clamp(0.0, 1.0);
        paint.color = (grade == 'SSS')
            ? _hueColor((i / beams * 360 + idleT * 200) % 360, beamAlpha)
            : color.withValues(alpha: beamAlpha);
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * beamLen, cy + sin(a) * beamLen),
          paint,
        );
      }
    }

    // 3. Burst particles (all, burstT-driven)
    if (burstT > 0) {
      final pCount = _pCount(grade);
      final spd = _speed(grade);
      paint.style = PaintingStyle.fill;

      for (int i = 0; i < pCount; i++) {
        final a = 2 * pi * i / pCount;
        final speedMult = 0.7 + (i % 3) * 0.3;
        final t = burstT;
        final dx = cx + cos(a) * spd * speedMult * t * (1 - t * 0.35);
        final dy = cy + sin(a) * spd * speedMult * t * (1 - t * 0.35);
        final alpha = (1.0 - t * 1.05).clamp(0.0, 1.0);
        final radius = (9 * (1 + (i % 4) * 0.15) - t * 6).clamp(1.5, 12.0);

        paint.color = (grade == 'SSS')
            ? _hueColor((i / pCount * 360 + burstT * 80) % 360, alpha)
            : color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(dx, dy), radius, paint);
      }

      // Secondary white sparkles (S+)
      if (['S', 'SS', 'SSS'].contains(grade)) {
        final sCount = 38;
        final t2 = (burstT * 1.15).clamp(0.0, 1.0);
        for (int i = 0; i < sCount; i++) {
          final a = 2 * pi * i / sCount + 0.08;
          final dx = cx + cos(a) * spd * 1.5 * t2 * (1 - t2 * 0.5);
          final dy = cy + sin(a) * spd * 1.5 * t2 * (1 - t2 * 0.5);
          final alpha = (1.0 - t2 * 1.2).clamp(0.0, 1.0);
          paint.color = Colors.white.withValues(alpha: alpha * 0.7);
          canvas.drawCircle(Offset(dx, dy), 3, paint);
        }
      }
    }

    // 4. Expanding rings (A+, burstT-driven)
    final rings = _ringCount(grade);
    if (rings > 0 && burstT > 0) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      for (int r = 0; r < rings; r++) {
        final delay = r * 0.18;
        final t = (burstT - delay).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final ringR = size.width * 0.28 * t + r * 35;
        final ringA = (1.0 - t).clamp(0.0, 1.0) * 0.85;
        paint.color = (grade == 'SSS')
            ? _hueColor((r * 120.0 + idleT * 360) % 360, ringA)
            : color.withValues(alpha: ringA);
        canvas.drawCircle(Offset(cx, cy), ringR, paint);
      }
    }

    // 5. Orbiting sparkles (S+, idle-driven)
    if (['S', 'SS', 'SSS'].contains(grade) && idleT > 0) {
      final sparkCount = switch (grade) {
        'SSS' => 12,
        'SS' => 8,
        _ => 5,
      };
      final orbitR = 165.0;
      paint.style = PaintingStyle.fill;
      for (int i = 0; i < sparkCount; i++) {
        final a = 2 * pi * i / sparkCount + idleT * pi;
        final dx = cx + cos(a) * orbitR;
        final dy = cy + sin(a) * orbitR;
        final sparkAlpha = (0.35 + idleT * 0.45).clamp(0.0, 1.0);
        paint.color = (grade == 'SSS')
            ? _hueColor((i / sparkCount * 360 + idleT * 270) % 360, sparkAlpha)
            : Colors.white.withValues(alpha: sparkAlpha);
        canvas.drawCircle(Offset(dx, dy), 4.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EffectPainter old) =>
      old.burstT != burstT || old.idleT != idleT || old.color != color;
}
