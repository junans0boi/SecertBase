import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';

/// 폭탄 확률 게이지: 남은 구멍 기준 %. 위험하면 하트비트처럼 뛴다.
class PirateRiskGauge extends StatefulWidget {
  final GameTheme theme;
  final int riskPct;
  final int remaining;

  const PirateRiskGauge({
    super.key,
    required this.theme,
    required this.riskPct,
    required this.remaining,
  });

  /// 이 값 이상이면 심장 박동 연출.
  static const int highRisk = 33;

  @override
  State<PirateRiskGauge> createState() => _PirateRiskGaugeState();
}

class _PirateRiskGaugeState extends State<PirateRiskGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  @override
  void initState() {
    super.initState();
    _syncBeat();
  }

  @override
  void didUpdateWidget(covariant PirateRiskGauge old) {
    super.didUpdateWidget(old);
    _syncBeat();
  }

  void _syncBeat() {
    final high = widget.riskPct >= PirateRiskGauge.highRisk;
    if (high && !_beat.isAnimating) {
      _beat.repeat();
    } else if (!high && _beat.isAnimating) {
      _beat.stop();
      _beat.value = 0;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  Color _color(int pct) {
    if (pct >= 50) return const Color(0xFFFF4D3D);
    if (pct >= 30) return const Color(0xFFFF8A2A);
    if (pct >= 20) return const Color(0xFFF2B33D);
    return const Color(0xFF9BD27A);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final pct = widget.riskPct.clamp(0, 100);
    final color = _color(pct);
    return Semantics(
      label: '폭탄 확률 $pct퍼센트, 남은 구멍 ${widget.remaining}개',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _beat,
              builder: (context, child) {
                final v = _beat.value;
                // 두 번 뛰는 심장 박동
                final kick =
                    math.max(0.0, math.sin(v * math.pi * 2)) * 0.18 +
                    math.max(0.0, math.sin(v * math.pi * 2 - 1.1)) * 0.1;
                return Transform.scale(scale: 1 + kick, child: child);
              },
              child: const Text('💣', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('폭탄 확률', style: t.body(size: 12, color: t.subInk)),
                      const Spacer(),
                      Text(
                        '남은 구멍 ${widget.remaining}개',
                        style: t.body(size: 11.5, color: t.subInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: t.ink.withValues(alpha: 0.12)),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct / 100,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.lerp(color, Colors.white, 0.25)!,
                                    color,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Text(
                '$pct%',
                key: ValueKey(pct),
                style: t.display(size: 26, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
