import '../domain/date_plan.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 12월 24일 (수) · 18:30
String datePlanWhen(DatePlan plan) {
  final d = plan.date;
  final day = '${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
  return plan.planTime == null ? day : '$day · ${plan.planTime}';
}

/// D-3 / 오늘 / 3일 지남
String datePlanDistance(DatePlan plan, DateTime today) {
  final days = plan.daysUntil(today);
  if (days == 0) return '오늘';
  return days > 0 ? 'D-$days' : '${-days}일 지남';
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
