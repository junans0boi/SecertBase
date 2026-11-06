/// Small Korean formatting helpers shared by 홈 and 비밀기지 screens.
library;

const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
const _weekdaysShort = ['월', '화', '수', '목', '금', '토', '일'];

/// Attaches a particle that depends on the final consonant of [word]:
/// `josa('서윤', '이', '가')` → 서윤이, `josa('민지', '이', '가')` → 민지가.
String josa(String word, String withBatchim, String withoutBatchim) {
  if (word.isEmpty) return withoutBatchim;
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '$word$withoutBatchim';
  final hasBatchim = (code - 0xAC00) % 28 != 0;
  return '$word${hasBatchim ? withBatchim : withoutBatchim}';
}

/// Local calendar day (time stripped).
DateTime dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime today() => dayOf(DateTime.now());

/// Parses `YYYY-MM-DD` (or a longer ISO string) into a local day.
DateTime? parseDay(String? value) {
  if (value == null || value.length < 10) return null;
  final parsed = DateTime.tryParse(value.substring(0, 10));
  return parsed == null ? null : dayOf(parsed);
}

String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 2025.9.21 (일)
String dotDateWithWeekday(DateTime d) =>
    '${d.year}.${d.month}.${d.day} (${_weekdaysShort[d.weekday - 1]})';

/// 2025.9.21
String dotDate(DateTime d) => '${d.year}.${d.month}.${d.day}';

/// 2026년 12월 25일 (금)
String longDateWithWeekday(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdaysShort[d.weekday - 1]})';

/// 11월 6일 금요일
String monthDayWeekday(DateTime d) =>
    '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}';

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// 오전 8:40 from an ISO timestamp, or null.
String? clockLabel(String? iso) {
  if (iso == null) return null;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return null;
  final t = parsed.isUtc ? parsed.toLocal() : parsed;
  final h = t.hour;
  final period = h < 12 ? '오전' : '오후';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  return '$period $hour12:${t.minute.toString().padLeft(2, '0')}';
}

/// D+n as the server counts it (start day is day 1).
int dPlus(DateTime start, [DateTime? on]) =>
    dayOf(on ?? DateTime.now()).difference(dayOf(start)).inDays + 1;

/// "D-23" / "오늘" / "D+3" (past) for a target day.
String dDayLabel(int daysUntil) {
  if (daysUntil == 0) return '오늘';
  if (daysUntil > 0) return 'D-$daysUntil';
  return 'D+${-daysUntil}';
}

/// One automatic milestone derived from the couple's first day.
class AutoMilestone {
  const AutoMilestone(this.label, this.date);
  final String label;
  final DateTime date;

  int get daysUntil => date.difference(today()).inDays;
}

/// 100일, 200일, 300일, 1주년, 500일, 2주년, 1000일 ... up to 10주년.
/// n일 counts the first day as day 1 (100일 = start + 99), n주년 is the same
/// calendar date n years later.
List<AutoMilestone> autoMilestones(DateTime start) {
  final first = dayOf(start);
  final list = <AutoMilestone>[
    for (final n in const [100, 200, 300, 500, 1000, 1500, 2000, 3000])
      AutoMilestone('$n일', first.add(Duration(days: n - 1))),
    for (var y = 1; y <= 10; y++)
      AutoMilestone('$y주년', DateTime(first.year + y, first.month, first.day)),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return list;
}

/// The nearest upcoming (today included) automatic milestone.
AutoMilestone? nextAutoMilestone(DateTime start) {
  for (final m in autoMilestones(start)) {
    if (m.daysUntil >= 0) return m;
  }
  return null;
}

/// Days until the next occurrence of a yearly date (today = 0).
int daysUntilYearly(DateTime date, [DateTime? from]) {
  final t = dayOf(from ?? DateTime.now());
  var next = DateTime(t.year, date.month, date.day);
  if (next.isBefore(t)) next = DateTime(t.year + 1, date.month, date.day);
  return next.difference(t).inDays;
}

/// The next occurrence of a yearly date (today included).
DateTime nextYearly(DateTime date, [DateTime? from]) {
  final t = dayOf(from ?? DateTime.now());
  var next = DateTime(t.year, date.month, date.day);
  if (next.isBefore(t)) next = DateTime(t.year + 1, date.month, date.day);
  return next;
}
