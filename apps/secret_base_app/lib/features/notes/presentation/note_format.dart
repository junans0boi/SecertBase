/// "11월 24일 오후 9:30" 형태의 짧은 시각.
String formatNoteTime(DateTime t) {
  final local = t.toLocal();
  final h = local.hour;
  final period = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.month}월 ${local.day}일 $period $h12:$mm';
}

/// "오후 3:20" 형태의 말풍선 시각.
String formatNoteClock(DateTime t) {
  final local = t.toLocal();
  final h = local.hour;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = local.minute.toString().padLeft(2, '0');
  return '${h < 12 ? '오전' : '오후'} $h12:$mm';
}

/// 날짜 구분선: "11월 23일".
String formatNoteDay(DateTime t) {
  final local = t.toLocal();
  return '${local.month}월 ${local.day}일';
}
