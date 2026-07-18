import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/main_design.dart';

class HeartOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const HeartOverlay({super.key, required this.onComplete});

  @override
  State<HeartOverlay> createState() => _HeartOverlayState();
}

class _HeartOverlayState extends State<HeartOverlay>
    with TickerProviderStateMixin {
  static const _count = 9;
  late final AnimationController _ctrl;
  late final List<_HeartConfig> _configs;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _configs = List.generate(_count, (i) => _HeartConfig(i, rng));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          // Semi-transparent backdrop
          Container(color: const Color(0x1A000000)),
          // Floating hearts
          ...List.generate(_count, (i) {
            final cfg = _configs[i];
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                final t = _ctrl.value;
                if (t < cfg.startT || t > cfg.endT) {
                  return const SizedBox.shrink();
                }
                final progress = (t - cfg.startT) / (cfg.endT - cfg.startT);
                final y = Curves.easeOut.transform(progress) * cfg.rise;
                final opacity = progress < 0.15
                    ? progress / 0.15
                    : progress > 0.7
                    ? 1.0 - (progress - 0.7) / 0.3
                    : 1.0;
                final scale = progress < 0.12
                    ? 0.4 + (progress / 0.12) * 0.8
                    : 1.0 + math.sin(progress * math.pi) * 0.15;
                return Positioned(
                  left: size.width / 2 + cfg.xOffset - cfg.heartSize / 2,
                  bottom: size.height * 0.28 + y,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: cfg.heartSize,
                        color: cfg.color,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // Center label
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                final fade = _ctrl.value < 0.15
                    ? _ctrl.value / 0.15
                    : _ctrl.value > 0.75
                    ? 1.0 - (_ctrl.value - 0.75) / 0.25
                    : 1.0;
                return Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 64,
                        color: kMainRose,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          '하트를 받았어요',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: kMainRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartConfig {
  final double xOffset;
  final double heartSize;
  final double rise;
  final double startT;
  final double endT;
  final Color color;

  _HeartConfig(int i, math.Random rng)
    : xOffset = (i % 2 == 0 ? -1.0 : 1.0) * (15.0 + rng.nextDouble() * 100.0),
      heartSize = 22.0 + rng.nextDouble() * 28.0,
      rise = 200.0 + rng.nextDouble() * 160.0,
      startT = (i / 9.0) * 0.55,
      endT = (i / 9.0) * 0.55 + 0.55,
      color = _heartColors[i % _heartColors.length];

  static const _heartColors = [
    kMainRose,
    kMainPeach,
    Color(0xFFB06478),
    kMainRose,
    kMainHoney,
    kMainRose,
    Color(0xFFB06478),
    kMainPeach,
    kMainRose,
  ];
}
