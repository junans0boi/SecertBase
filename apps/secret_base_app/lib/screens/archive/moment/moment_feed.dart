import 'package:flutter/material.dart';

import '../../../v2/v2.dart';

/// Placeholder while 기록 loads.
class MomentFeedSkeleton extends StatelessWidget {
  const MomentFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return V2Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var day = 0; day < 2; day++) ...[
            const V2SkeletonBox(width: 120, height: 16, radius: 8),
            const SizedBox(height: V2Space.x2),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  const Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: V2SkeletonBox(height: 100, radius: V2Radius.ctl),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: V2Space.x5),
          ],
        ],
      ),
    );
  }
}
