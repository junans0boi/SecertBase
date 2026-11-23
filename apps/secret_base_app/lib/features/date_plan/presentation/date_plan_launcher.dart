import 'package:flutter/material.dart';

import '../../../core/auth_service.dart';
import '../data/date_plan_repository.dart';
import '../domain/date_plan.dart';
import 'date_plan_editor_screen.dart';

/// 지도 핀 상세의 "이 날 가요": 핀을 연결한 새 계획 편집 화면을 연다.
/// 저장하면 만든 [DatePlan]을, 취소하면 null을 돌려준다.
Future<DatePlan?> openDatePlanFromPin(
  BuildContext context, {
  required int pinId,
  required String pinTitle,
  DatePlanRepository? repository,
}) async {
  final repo =
      repository ??
      () {
        final auth = AuthService();
        final token = auth.token;
        if (token == null) return null;
        return HttpDatePlanRepository(baseUrl: auth.baseUrl, token: token);
      }();
  if (repo == null) return null;
  final result = await Navigator.of(context).push<Object>(
    MaterialPageRoute(
      builder: (_) => DatePlanEditorScreen(
        repository: repo,
        pinId: pinId,
        pinTitle: pinTitle,
      ),
    ),
  );
  return result is DatePlan ? result : null;
}
