import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Shimmer wrapper for loading placeholders (ds.css `.skel`). Paints a
/// moving highlight over every [V2SkeletonBox] below it; static when the
/// platform asks for reduced motion. Announces "불러오는 중이에요" once.
///
/// ```dart
/// V2Shimmer(child: Column(children: [
///   V2SkeletonBox(height: 160, radius: 20),
///   SizedBox(height: 12),
///   V2SkeletonLine(width: 180),
///   V2SkeletonLine(),
/// ]))
/// const V2SkeletonList(count: 4)   // ready-made list rows
/// const V2SkeletonCard()           // ready-made card
/// ```
class V2Shimmer extends StatefulWidget {
  const V2Shimmer({
    super.key,
    required this.child,
    this.semanticLabel = '불러오는 중이에요',
  });

  final Widget child;
  final String semanticLabel;

  @override
  State<V2Shimmer> createState() => _V2ShimmerState();
}

class _V2ShimmerState extends State<V2Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (V2Motion.reduced(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final content = ExcludeSemantics(child: widget.child);
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: V2Motion.reduced(context)
          ? content
          : AnimatedBuilder(
              animation: _c,
              child: content,
              builder: (context, child) {
                final t = _c.value * 2 - 0.5; // -0.5 .. 1.5
                return ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [p.soft2, p.soft, p.soft2],
                    stops: [
                      (t - 0.25).clamp(0.0, 1.0),
                      t.clamp(0.0, 1.0),
                      (t + 0.25).clamp(0.0, 1.0),
                    ],
                  ).createShader(rect),
                  child: child,
                );
              },
            ),
    );
  }
}

/// Rounded placeholder block. Put inside a [V2Shimmer].
class V2SkeletonBox extends StatelessWidget {
  const V2SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 10,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: V2Palette.of(context).soft2,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A 14px text line placeholder with 8px bottom gap.
class V2SkeletonLine extends StatelessWidget {
  const V2SkeletonLine({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: V2SkeletonBox(width: width, height: 14, radius: 7),
  );
}

/// Circle placeholder (avatars, icon bubbles).
class V2SkeletonCircle extends StatelessWidget {
  const V2SkeletonCircle({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) =>
      V2SkeletonBox(width: size, height: size, radius: size / 2);
}

/// Ready-made shimmering list (rows with bubble + two lines).
class V2SkeletonList extends StatelessWidget {
  const V2SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return V2Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const V2SkeletonBox(width: 36, height: 36, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: i.isEven ? 0.6 : 0.45,
                          child: const V2SkeletonBox(height: 14, radius: 7),
                        ),
                        const SizedBox(height: 8),
                        FractionallySizedBox(
                          widthFactor: i.isEven ? 0.85 : 0.7,
                          child: const V2SkeletonBox(height: 12, radius: 6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ready-made shimmering card (image block + lines).
class V2SkeletonCard extends StatelessWidget {
  const V2SkeletonCard({super.key, this.imageHeight = 160});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return V2Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          V2SkeletonBox(height: imageHeight, radius: V2Radius.card),
          const SizedBox(height: 12),
          const FractionallySizedBox(widthFactor: 0.5, child: V2SkeletonLine()),
          const FractionallySizedBox(widthFactor: 0.8, child: V2SkeletonLine()),
        ],
      ),
    );
  }
}
