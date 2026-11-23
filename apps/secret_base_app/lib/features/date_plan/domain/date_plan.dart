/// 데이트 계획: 둘이 함께 정한 날. 위시 장소(핀)에서 시작할 수 있고,
/// 다녀오면 기존 애프터글로우(우리의 여운)로 이어진다.
class DatePlanAfterglow {
  final int pinId;

  /// `needs_visit`: 아직 다녀온 곳으로 표시되지 않았다. `recorded`: 이미 여운 기록이 있다.
  final String state;

  const DatePlanAfterglow({required this.pinId, required this.state});

  bool get needsVisit => state == 'needs_visit';

  static DatePlanAfterglow? fromJson(Object? json) {
    if (json is! Map) return null;
    final pinId = int.tryParse('${json['map_pin_id']}');
    if (pinId == null) return null;
    return DatePlanAfterglow(pinId: pinId, state: '${json['state']}');
  }
}

class DatePlan {
  final int id;

  /// `YYYY-MM-DD`
  final String planDate;

  /// `HH:MM` 또는 null(하루 종일).
  final String? planTime;
  final String title;
  final String? memo;
  final bool mine;
  final bool completed;
  final int? pinId;
  final String? pinTitle;
  final DatePlanAfterglow? afterglow;

  const DatePlan({
    required this.id,
    required this.planDate,
    this.planTime,
    required this.title,
    this.memo,
    this.mine = false,
    this.completed = false,
    this.pinId,
    this.pinTitle,
    this.afterglow,
  });

  factory DatePlan.fromJson(Map<String, dynamic> json) {
    final pin = json['pin'];
    return DatePlan(
      id: int.tryParse('${json['id']}') ?? 0,
      planDate: '${json['plan_date']}',
      planTime: json['plan_time'] == null ? null : '${json['plan_time']}',
      title: '${json['title']}',
      memo: json['memo'] == null ? null : '${json['memo']}',
      mine: json['mine'] == true,
      completed: json['completed'] == true,
      pinId: pin is Map ? int.tryParse('${pin['id']}') : null,
      pinTitle: pin is Map ? '${pin['title']}' : null,
      afterglow: DatePlanAfterglow.fromJson(json['afterglow']),
    );
  }

  DateTime get date => DateTime.parse(planDate);

  /// 오늘 기준 남은 일수(오늘 0, 지난 날은 음수).
  int daysUntil(DateTime today) => DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;

  /// 오늘이거나 지났고 아직 다녀오지 않은 계획.
  bool canComplete(DateTime today) => !completed && daysUntil(today) <= 0;
}

class DatePlanPage {
  final List<DatePlan> plans;
  final String? nextCursor;

  const DatePlanPage({required this.plans, this.nextCursor});
}
