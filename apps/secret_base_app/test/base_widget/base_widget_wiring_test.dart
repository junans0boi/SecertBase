import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/auth_service.dart';
import 'package:secret_base_app/features/base_widget/base_widget_service.dart';
import 'package:secret_base_app/features/base_widget/base_widget_store.dart';
import 'package:secret_base_app/features/home/application/home_controller.dart';
import 'package:secret_base_app/features/home/data/home_overview_repository.dart';
import 'package:secret_base_app/features/home/domain/home_overview.dart';
import 'package:secret_base_app/features/notes/application/notes_unread.dart';
import 'package:secret_base_app/features/notes/data/notes_repository.dart';

class _Store implements BaseWidgetStore {
  Map<String, Object?> saved = {};
  int clears = 0;
  @override
  Future<void> save(Map<String, Object?> values) async =>
      saved = Map.of(values);
  @override
  Future<void> clear() async {
    saved = {};
    clears++;
  }
}

class _HomeRepo extends HomeOverviewRepository {
  _HomeRepo() : super.fake();
  @override
  Future<HomeOverview> fetch() async =>
      HomeOverview(couple: const HomeCoupleInfo(dDay: 50, partnerName: 'x'));
}

class _NotesRepo implements NotesRepository {
  @override
  Future<int> unreadCount() async => 7;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late _Store store;
  late BaseWidgetService original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = BaseWidgetService.instance;
    store = _Store();
    BaseWidgetService.instance = BaseWidgetService(store);
  });
  tearDown(() => BaseWidgetService.instance = original);

  test('home load updates the widget', () async {
    await HomeController(_HomeRepo()).load();
    await Future<void>.delayed(Duration.zero);
    expect(store.saved['dday'], 50);
    expect(store.saved['active'], true);
  });

  test('notes unread refresh updates the widget count', () async {
    await NotesUnread(repository: _NotesRepo()).refresh();
    expect(store.saved['unread'], 7);
  });

  test('push receipt runs registered refreshers', () async {
    var calls = 0;
    BaseWidgetService.instance.refreshers.add(() async => calls++);
    BaseWidgetService.instance.requestRefresh();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });

  test('logout empties widget data', () async {
    await BaseWidgetService.instance.onUnread(3);
    expect(store.saved['unread'], 3);
    await AuthService().logout();
    await Future<void>.delayed(Duration.zero);
    expect(store.clears, 1);
    expect(store.saved, isEmpty);
    // 로그아웃 뒤 늦게 도착한 갱신은 위젯에 쓰지 않는다.
    await BaseWidgetService.instance.onUnread(9);
    expect(store.saved, isEmpty);
  });
}
