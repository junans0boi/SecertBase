import '../../../features/moment_loop/domain/moment.dart';

/// Upload limits mirrored from the server (30MB, 60-second clips) so the
/// composer can reject a file before it ever reaches the upload queue.
/// Videos over 30MB are shrunk on the device first where that is supported.
const momentMaxBytes = 30 * 1024 * 1024;
const momentMaxVideo = Duration(seconds: 60);
const momentMaxMedia = 10;
const momentCaptionMax = 100;

enum MomentMediaIssue { tooLarge, tooLong }

/// Client-side check for one picked file. [duration] is null when the device
/// could not read the clip length; the server still enforces the limit.
MomentMediaIssue? momentMediaIssue({
  required bool isVideo,
  required int bytes,
  Duration? duration,
}) {
  if (bytes > momentMaxBytes) return MomentMediaIssue.tooLarge;
  if (isVideo &&
      duration != null &&
      duration > momentMaxVideo + const Duration(milliseconds: 400)) {
    return MomentMediaIssue.tooLong;
  }
  return null;
}

String momentMediaIssueLabel(MomentMediaIssue issue) => switch (issue) {
  MomentMediaIssue.tooLarge => '30MB 이하만 올릴 수 있어요',
  MomentMediaIssue.tooLong => '영상은 1분까지예요',
};

/// Server / outbox error code → reason the user can act on.
String momentFailureReason(String? code) => switch (code) {
  'media_too_large' || 'file_too_large' => '30MB 이하만 올릴 수 있어요',
  'clip_too_long' => '영상은 1분까지예요',
  'clip_duration_unreadable' => '영상 길이를 읽지 못했어요',
  'clip_conversion_failed' => '영상을 변환하지 못했어요',
  'invalid_media_type' || 'invalid_media_upload' => '올릴 수 없는 파일 형식이에요',
  'today_moment_wrong_date' ||
  'today_moment_date_required' => '오늘의 순간은 오늘 날짜로만 남길 수 있어요',
  'today_loop_locked' => '오늘의 순간이 이미 열렸어요',
  'today_loop_date_locked' ||
  'today_loop_media_locked' => '열린 오늘의 순간은 사진·날짜를 바꿀 수 없어요',
  'active_couple_required' => '연결이 끊겨서 올리지 못했어요',
  'map_pin_not_found' ||
  'invalid_map_pin' ||
  'map_pin_forbidden' => '연결한 장소를 찾지 못했어요',
  'unauthorized' || 'auth_required' => '다시 로그인해 주세요',
  'network_error' || 'timeout' => '연결이 불안정했어요',
  'caption_required' => '한 줄이나 사진을 남겨 주세요',
  _ => '잠시 후 다시 시도해 주세요',
};

/// Failures the user must fix in the composer (retrying alone won't help).
bool momentFailureNeedsEdit(String? code) => switch (code) {
  'media_too_large' ||
  'file_too_large' ||
  'clip_too_long' ||
  'clip_duration_unreadable' ||
  'clip_conversion_failed' ||
  'invalid_media_type' ||
  'invalid_media_upload' ||
  'today_moment_wrong_date' ||
  'today_moment_date_required' ||
  'today_loop_locked' ||
  'today_loop_date_locked' ||
  'today_loop_media_locked' ||
  'map_pin_not_found' ||
  'invalid_map_pin' ||
  'map_pin_forbidden' => true,
  _ => false,
};

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime mondayOf(DateTime d) {
  final day = dateOnly(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];
String weekdayFull(DateTime d) => '${_weekdays[d.weekday - 1]}요일';

/// "11월 6일 금요일"
String longDate(DateTime d) => '${d.month}월 ${d.day}일 ${weekdayFull(d)}';

/// "11월 2일 – 8일" / "10/26 – 11/1"
String weekRangeLabel(DateTime monday) {
  final end = monday.add(const Duration(days: 6));
  if (monday.month == end.month) {
    return '${monday.month}월 ${monday.day}일 – ${end.day}일';
  }
  return '${monday.month}/${monday.day} – ${end.month}/${end.day}';
}

/// Local calendar date of a moment. `taken_at` is a server DATE (no zone);
/// `captured_at` is UTC and must be converted before taking the date.
DateTime? momentDay(Moment m) {
  final taken = m.takenAt?.trim() ?? '';
  if (taken.length >= 10) {
    final parsed = DateTime.tryParse(taken.substring(0, 10));
    if (parsed != null) return parsed;
  }
  final captured = DateTime.tryParse(m.capturedAt ?? '');
  return captured == null ? null : dateOnly(captured.toLocal());
}

DateTime? momentTime(Moment m) =>
    DateTime.tryParse(m.capturedAt ?? '')?.toLocal();

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "오후 3:12"
String clockLabel(DateTime? d) {
  if (d == null) return '';
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? '오후' : '오전';
  return '$ampm $hour:${d.minute.toString().padLeft(2, '0')}';
}

/// "오늘" / "어제" / "수요일" / "11월 1일"
String relativeDay(DateTime day, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = today.difference(dateOnly(day)).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  if (diff > 1 && diff < 7) return weekdayFull(day);
  return '${day.month}월 ${day.day}일';
}

String mediaUrlFor(String baseUrl, String? mediaUrl) {
  final url = mediaUrl?.trim() ?? '';
  if (url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '$baseUrl$url';
}

String durationLabel(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

bool _hasBatchim(String word) {
  if (word.isEmpty) return false;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// Korean particle helper: josa('서윤', '이', '가') → '서윤이'.
String josa(String word, String withBatchim, String withoutBatchim) =>
    '$word${_hasBatchim(word) ? withBatchim : withoutBatchim}';

/// Moments grouped by upload session, ordered newest first.
List<List<Moment>> groupMoments(Iterable<Moment> moments) {
  final map = <String, List<Moment>>{};
  for (final m in moments) {
    map.putIfAbsent(m.sessionKey, () => []).add(m);
  }
  final groups = map.values.map((g) {
    g.sort((a, b) {
      final order = a.position.compareTo(b.position);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return g;
  }).toList();
  groups.sort((a, b) {
    final da = momentDay(a.first) ?? DateTime(0);
    final db = momentDay(b.first) ?? DateTime(0);
    final byDay = db.compareTo(da);
    if (byDay != 0) return byDay;
    final ta = momentTime(a.first) ?? DateTime(0);
    final tb = momentTime(b.first) ?? DateTime(0);
    return tb.compareTo(ta);
  });
  return groups;
}
