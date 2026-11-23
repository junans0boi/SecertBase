import 'package:flutter/material.dart';

import '../../../screens/archive/map_screen.dart';
import '../data/date_plan_repository.dart';
import 'date_plans_screen.dart';

/// 계획 목록을 연다. "다녀왔어요"/"여운 남기기"는 기존 애프터글로우 흐름(지도 화면)으로 이어진다.
Future<void> openDatePlansScreen(
  BuildContext context, {
  required DatePlanRepository repository,
  Map<String, String> anniversaries = const {},
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (ctx) => DatePlansScreen(
      repository: repository,
      anniversaries: anniversaries,
      onOpenAfterglow: (glow) => Navigator.of(ctx).push<void>(
        MaterialPageRoute(
          builder: (_) => MapScreen(afterglowPinId: glow.pinId),
        ),
      ),
    ),
  ),
);
