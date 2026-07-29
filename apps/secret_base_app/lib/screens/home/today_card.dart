import 'package:flutter/material.dart';

import '../../core/main_design.dart';
import '../../core/today_api.dart';

class TodayCard extends StatelessWidget {
  final TodayState state;
  final VoidCallback onCreateMoment;
  final VoidCallback onOpenLoop;

  const TodayCard({
    super.key,
    required this.state,
    required this.onCreateMoment,
    required this.onOpenLoop,
  });

  @override
  Widget build(BuildContext context) {
    final (
      :title,
      :subtitle,
      :actionLabel,
      :icon,
      :onPressed,
    ) = switch (state.status) {
      TodayStatus.empty => (
        title: '오늘의 순간을 남겨볼까요?',
        subtitle: '사진, 짧은 영상 또는 한 문장이면 충분해요',
        actionLabel: '오늘의 순간 남기기',
        icon: Icons.add_photo_alternate_outlined,
        onPressed: onCreateMoment,
      ),
      TodayStatus.partnerWaiting => (
        title: '상대가 오늘의 순간을 남겼어요',
        subtitle: '내 순간을 남기면 둘의 오늘이 함께 열려요',
        actionLabel: '내 순간 남기기',
        icon: Icons.lock_outline_rounded,
        onPressed: onCreateMoment,
      ),
      TodayStatus.selfWaiting => (
        title: '내 오늘의 순간을 남겼어요',
        subtitle: '상대의 순간을 기다리고 있어요',
        actionLabel: '내 순간 보기',
        icon: Icons.hourglass_top_rounded,
        onPressed: onOpenLoop,
      ),
      TodayStatus.complete => (
        title: '둘의 오늘의 루프가 완성됐어요',
        subtitle: '같은 하루를 서로 어떻게 기억했는지 확인해보세요',
        actionLabel: '오늘의 루프 열기',
        icon: Icons.auto_stories_rounded,
        onPressed: onOpenLoop,
      ),
      TodayStatus.viewed => (
        title: '오늘의 루프를 다시 볼까요?',
        subtitle: '오늘 남긴 두 사람의 순간이 여기 있어요',
        actionLabel: '오늘의 루프 다시 보기',
        icon: Icons.replay_rounded,
        onPressed: onOpenLoop,
      ),
    };
    final ownCaption = state.status == TodayStatus.selfWaiting
        ? state.myMoment?.caption
        : null;

    return MainCard(
      gradient: kSkyGrad,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                '오늘의 루프',
                style: mainBody(
                  size: 13,
                  color: Colors.white,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: mainTitle(size: 24, color: Colors.white)),
          const SizedBox(height: 5),
          Text(subtitle, style: mainBody(size: 13, color: Colors.white)),
          if (ownCaption != null && ownCaption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                ownCaption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mainBody(
                  size: 13,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kMainSky,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: Text(
                actionLabel,
                style: mainBody(color: kMainSky, weight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
