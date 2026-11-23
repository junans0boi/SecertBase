import 'package:flutter/material.dart';

import '../../../v2/v2.dart';
import '../domain/date_plan.dart';
import 'date_plan_format.dart';

/// 홈의 "데이트 계획" 카드. 가장 가까운 계획 하나를 보여 주고,
/// 같은 날 기념일이 있으면 함께 표시한다. 계획이 없으면 만들기 안내.
class DatePlanHomeCard extends StatelessWidget {
  final DatePlan? next;
  final DateTime today;
  final String? anniversaryLabel;
  final VoidCallback? onTap;

  const DatePlanHomeCard({
    super.key,
    required this.next,
    required this.today,
    this.anniversaryLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final plan = next;
    final headline = plan == null
        ? '함께 갈 날을 정해 볼까요?'
        : '${datePlanDistance(plan, today)} · ${V2Text.keepAll(plan.title)}';
    final sub = plan == null
        ? '위시 장소에서 "이 날 가요"로 시작할 수 있어요'
        : [
            datePlanWhen(plan),
            if (plan.pinTitle != null) plan.pinTitle!,
          ].join(' · ');
    return V2Card(
      key: const ValueKey('date-plan-card'),
      variant: V2CardVariant.soft,
      onTap: onTap,
      semanticLabel: '데이트 계획, $headline',
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(V2Radius.ctl),
            ),
            child: Icon(V2Icons.event, color: p.primary, size: 22),
          ),
          const SizedBox(width: V2Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('데이트 계획', style: V2Text.cap.copyWith(color: p.sub)),
                const SizedBox(height: 2),
                Text(headline, style: V2Text.bodyStrong.copyWith(color: p.ink)),
                const SizedBox(height: 2),
                Text(
                  V2Text.keepAll(sub),
                  style: V2Text.cap.copyWith(color: p.sub),
                ),
                if (plan != null && anniversaryLabel != null)
                  Text(
                    '같은 날 · $anniversaryLabel',
                    key: const ValueKey('date-plan-card-anniversary'),
                    style: V2Text.cap.copyWith(color: p.primary),
                  ),
              ],
            ),
          ),
          Icon(V2Icons.chevron, color: p.sub, size: 20),
        ],
      ),
    );
  }
}
