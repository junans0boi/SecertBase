/// "11월 24일 오후 9:30" 형태의 짧은 시각.
String formatNoteTime(DateTime t) {
  final local = t.toLocal();
  final h = local.hour;
  final period = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.month}월 ${local.day}일 $period $h12:$mm';
}
