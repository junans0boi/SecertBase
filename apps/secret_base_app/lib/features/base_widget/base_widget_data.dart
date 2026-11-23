import '../../core/push/push_target.dart';
import '../../core/today_api.dart';
import '../home/domain/home_overview.dart';
import '../two_answers/domain/two_answer.dart';

/// 홈 화면 위젯(기지 위젯)에 내보내는 값. 잠금 화면에서도 보이므로
/// 숫자·상태 코드·짧은 기념일 이름만 담는다. 쪽지 본문, 마주 열기 질문·답변,
/// 사진, 장소, 파트너 이름은 이 클래스에 들어올 수 없다.
class BaseWidgetData {
  static const _labelMax = 20;
  static const _unreadMax = 99;

  /// 위젯 저장소에 쓰는 키 전체(화이트리스트). Kotlin 쪽과 같은 이름을 쓴다.
  static const storageKeys = {
    'active',
    'dday',
    'ann_label',
    'ann_days',
    'qa_state',
    'loop_open',
    'unread',
    'as_of',
  };

  final bool active;
  final int? dDay;
  final String? anniversaryLabel;
  final int? anniversaryDays;

  /// my_turn | waiting | open | unknown
  final String qaState;

  /// 오늘의 루프 공개 여부. 모르면 null.
  final bool? loopOpen;
  final int unread;

  const BaseWidgetData({
    this.active = false,
    this.dDay,
    this.anniversaryLabel,
    this.anniversaryDays,
    this.qaState = 'unknown',
    this.loopOpen,
    this.unread = 0,
  });

  factory BaseWidgetData.empty() => const BaseWidgetData();

  BaseWidgetData _copy({
    bool? active,
    int? dDay,
    String? anniversaryLabel,
    int? anniversaryDays,
    String? qaState,
    bool? loopOpen,
    int? unread,
    bool resetCouple = false,
  }) => BaseWidgetData(
    active: active ?? this.active,
    dDay: resetCouple ? dDay : (dDay ?? this.dDay),
    anniversaryLabel: resetCouple
        ? anniversaryLabel
        : (anniversaryLabel ?? this.anniversaryLabel),
    anniversaryDays: resetCouple
        ? anniversaryDays
        : (anniversaryDays ?? this.anniversaryDays),
    qaState: qaState ?? this.qaState,
    loopOpen: loopOpen ?? this.loopOpen,
    unread: unread ?? this.unread,
  );

  BaseWidgetData withHome(HomeOverview overview) {
    final couple = overview.couple;
    final today = overview.todayState;
    final loop = today == null
        ? loopOpen
        : today.status == TodayStatus.complete ||
              today.status == TodayStatus.viewed;
    if (couple == null) {
      // 커플 섹션을 못 불러온 것과 연결이 없는 것은 구분되지 않으므로,
      // 홈이 실패한 경우(failedSections)에는 이전 값을 유지한다.
      if (overview.failedSections.contains(HomeSection.couple)) {
        return _copy(loopOpen: loop);
      }
      return _copy(
        active: false,
        resetCouple: true,
        loopOpen: loop,
        qaState: 'unknown',
      );
    }
    final next = couple.nextAnniversary;
    final label = next?.label.trim();
    return _copy(
      active: true,
      resetCouple: true,
      dDay: couple.dDay,
      anniversaryLabel: label == null || label.isEmpty
          ? null
          : (label.length > _labelMax ? label.substring(0, _labelMax) : label),
      anniversaryDays: next?.daysUntil,
      loopOpen: loop,
    );
  }

  BaseWidgetData withTwoAnswer(TwoAnswerCard card) => _copy(
    qaState: switch (card.status) {
      TwoAnswerStatus.myTurn => 'my_turn',
      TwoAnswerStatus.waiting => 'waiting',
      TwoAnswerStatus.open => 'open',
    },
  );

  BaseWidgetData withUnread(int count) =>
      _copy(unread: count.clamp(0, _unreadMax));

  /// [now]는 값을 기록한 날. 위젯이 앱을 열지 않은 날에도 D-day를 이어서 센다.
  Map<String, Object?> toStorage({DateTime? now}) {
    final d = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'as_of': '${d.year}-${two(d.month)}-${two(d.day)}',
      'active': active,
      'dday': dDay ?? -1,
      'ann_label': anniversaryLabel ?? '',
      'ann_days': anniversaryDays ?? -1,
      'qa_state': qaState,
      'loop_open': switch (loopOpen) {
        true => 1,
        false => 0,
        null => -1,
      },
      'unread': unread,
    };
  }
}

/// 위젯 탭이 보내는 `secretbase://widget/<대상>` 링크를 앱 안의 화면으로 바꾼다.
/// 기존 알림 탭과 같은 [PushTarget] 경로를 재사용한다.
abstract final class BaseWidgetLinks {
  static const scheme = 'secretbase';
  static const host = 'widget';

  static PushTarget? targetFor(Uri? uri) {
    if (uri == null || uri.scheme != scheme || uri.host != host) return null;
    final path = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (path) {
      'notes' => const PushTarget(screen: 'notes'),
      'two_answers' => const PushTarget(screen: 'two_answers'),
      _ => null,
    };
  }
}
