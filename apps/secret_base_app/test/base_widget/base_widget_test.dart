import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/features/base_widget/base_widget_data.dart';
import 'package:secret_base_app/features/base_widget/base_widget_service.dart';
import 'package:secret_base_app/features/base_widget/base_widget_store.dart';
import 'package:secret_base_app/features/home/domain/home_overview.dart';
import 'package:secret_base_app/features/two_answers/domain/two_answer.dart';

class _FakeStore implements BaseWidgetStore {
  Map<String, Object?> saved = {};
  int saves = 0;
  int clears = 0;
  @override
  Future<void> save(Map<String, Object?> values) async {
    saved = Map.of(values);
    saves++;
  }

  @override
  Future<void> clear() async {
    saved = {};
    clears++;
  }
}

HomeOverview _home({String label = '100일', int days = 12}) => HomeOverview(
  couple: HomeCoupleInfo(
    partnerName: '비밀이름',
    dDay: 321,
    startDate: '2024-01-01',
    nextAnniversary: NextAnniversary(
      label: label,
      date: '2026-12-05',
      daysUntil: days,
    ),
  ),
  todayState: const TodayState(
    date: '2026-11-23',
    status: TodayStatus.complete,
  ),
);

TwoAnswerCard _card(TwoAnswerStatus s) => TwoAnswerCard(
  id: 1,
  businessDate: '2026-11-23',
  category: 'place',
  question: '비밀 질문 본문',
  status: s,
  myBody: '내 비밀 답변',
  partnerAnswered: true,
  partnerBody: '상대 비밀 답변',
);

void main() {
  group('payload masking', () {
    test('contains only whitelisted primitive keys and no sensitive text', () {
      final data = BaseWidgetData.empty()
          .withHome(_home())
          .withTwoAnswer(_card(TwoAnswerStatus.open))
          .withUnread(3);
      final map = data.toStorage();
      expect(map['active'], true);
      expect(map['dday'], 321);
      expect(map['ann_label'], '100일');
      expect(map['ann_days'], 12);
      expect(map['qa_state'], 'open');
      expect(map['loop_open'], 1);
      expect(map['unread'], 3);
      expect(map.keys.toSet(), BaseWidgetData.storageKeys);
      final blob = map.toString();
      for (final secret in [
        '비밀이름',
        '비밀 질문 본문',
        '내 비밀 답변',
        '상대 비밀 답변',
        '2024-01-01',
      ]) {
        expect(blob.contains(secret), isFalse, reason: secret);
      }
      expect(
        map.values.every((v) => v is String || v is int || v is bool),
        isTrue,
      );
    });

    test('long anniversary labels are truncated', () {
      final map = BaseWidgetData.empty()
          .withHome(_home(label: '가' * 80))
          .toStorage();
      expect((map['ann_label'] as String).length, lessThanOrEqualTo(20));
    });

    test('unread is clamped and card states map', () {
      expect(BaseWidgetData.empty().withUnread(-4).toStorage()['unread'], 0);
      expect(BaseWidgetData.empty().withUnread(500).toStorage()['unread'], 99);
      expect(
        BaseWidgetData.empty()
            .withTwoAnswer(_card(TwoAnswerStatus.myTurn))
            .toStorage()['qa_state'],
        'my_turn',
      );
      expect(
        BaseWidgetData.empty()
            .withTwoAnswer(_card(TwoAnswerStatus.waiting))
            .toStorage()['qa_state'],
        'waiting',
      );
    });

    test('home without couple is inactive', () {
      final map = BaseWidgetData.empty().withHome(HomeOverview()).toStorage();
      expect(map['active'], false);
      expect(map['dday'], -1);
    });
  });

  group('launch links', () {
    test('map widget uris to push targets', () {
      expect(
        BaseWidgetLinks.targetFor(
          Uri.parse('secretbase://widget/notes'),
        )?.screen,
        'notes',
      );
      expect(
        BaseWidgetLinks.targetFor(
          Uri.parse('secretbase://widget/two_answers'),
        )?.screen,
        'two_answers',
      );
      expect(
        BaseWidgetLinks.targetFor(Uri.parse('secretbase://widget/home')),
        isNull,
      );
      expect(
        BaseWidgetLinks.targetFor(Uri.parse('secretbase://invite/abc')),
        isNull,
      );
      expect(BaseWidgetLinks.targetFor(null), isNull);
    });
  });

  group('service', () {
    test('pushes merged data to the store on each update', () async {
      final store = _FakeStore();
      final service = BaseWidgetService(store);
      await service.onHome(_home());
      await service.onTwoAnswer(_card(TwoAnswerStatus.waiting));
      await service.onUnread(2);
      expect(store.saves, 3);
      expect(store.saved['dday'], 321);
      expect(store.saved['qa_state'], 'waiting');
      expect(store.saved['unread'], 2);
    });

    test('skips redundant writes', () async {
      final store = _FakeStore();
      final service = BaseWidgetService(store);
      await service.onUnread(2);
      await service.onUnread(2);
      expect(store.saves, 1);
    });

    test('clear empties the store and forgets state', () async {
      final store = _FakeStore();
      final service = BaseWidgetService(store);
      await service.onHome(_home());
      await service.onUnread(5);
      await service.clear();
      expect(store.clears, 1);
      expect(store.saved, isEmpty);
      service.enable();
      await service.onUnread(1);
      expect(store.saved['dday'], -1);
      expect(store.saved['active'], false);
    });

    test('store failures never throw', () async {
      final service = BaseWidgetService(_ThrowingStore());
      await service.onUnread(1);
      await service.clear();
    });

    test('updates after clear for a logged-out user are ignored', () async {
      final store = _FakeStore();
      final service = BaseWidgetService(store);
      await service.clear();
      await service.onUnread(4);
      // 로그아웃 상태에서는 어떤 값도 위젯에 쓰지 않는다.
      expect(store.saved, isEmpty);
      service.enable();
      await service.onUnread(4);
      expect(store.saved['unread'], 4);
    });
  });
}

class _ThrowingStore implements BaseWidgetStore {
  @override
  Future<void> save(Map<String, Object?> values) async => throw StateError('x');
  @override
  Future<void> clear() async => throw StateError('x');
}
