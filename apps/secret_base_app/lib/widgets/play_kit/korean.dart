/// 이름 뒤에 붙일 조사를 받침에 맞춰 고른다. 한글로 끝나지 않으면 "이(가)"처럼 둘 다 적는다.
/// 예: josa('민지', '이', '가') → '가', josa('준환', '이', '가') → '이'.
String josa(String word, String withFinal, String withoutFinal) {
  final w = word.trimRight();
  if (w.isEmpty) return '$withFinal($withoutFinal)';
  final code = w.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return '$withFinal($withoutFinal)';
  return (code - 0xAC00) % 28 == 0 ? withoutFinal : withFinal;
}
