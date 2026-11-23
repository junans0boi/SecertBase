import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/features/date_plan/data/date_plan_repository.dart';
import 'package:secret_base_app/features/date_plan/domain/date_plan.dart';
import 'package:secret_base_app/features/date_plan/presentation/date_plan_editor_screen.dart';
import 'package:secret_base_app/features/date_plan/presentation/date_plan_format.dart';
import 'package:secret_base_app/features/date_plan/presentation/date_plan_home_card.dart';
import 'package:secret_base_app/features/date_plan/presentation/date_plans_screen.dart';
import 'package:secret_base_app/features/home/application/home_controller.dart';
import 'package:secret_base_app/features/home/data/home_overview_repository.dart';
import 'package:secret_base_app/features/home/domain/home_overview.dart';
import 'package:secret_base_app/screens/home/home_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

final _today = DateTime(2026, 11, 23);

DatePlan _plan({
  int id = 1,
  String date = '2026-11-26',
  String? time = '18:30',
  String title = '카페 가요',
  bool mine = true,
  bool completed = false,
  int? pinId,
  String? pinTitle,
  DatePlanAfterglow? afterglow,
}) => DatePlan(
  id: id,
  planDate: date,
  planTime: time,
  title: title,
  mine: mine,
  completed: completed,
  pinId: pinId,
  pinTitle: pinTitle,
  afterglow: afterglow,
);

class _FakeRepo implements DatePlanRepository {
  List<DatePlan> upcoming = [];
  List<DatePlan> past = [];
  final created = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  final removed = <int>[];
  final completedIds = <int>[];
  DatePlanAfterglow? completionGlow;
  Object? completeError;

  @override
  Future<DatePlanPage> list({required bool upcoming, String? cursor}) async =>
      DatePlanPage(plans: upcoming ? this.upcoming : past);

  @override
  Future<DatePlan> create({
    required String planDate,
    String? planTime,
    required String title,
    String? memo,
    int? pinId,
  }) async {
    created.add({
      'date': planDate,
      'time': planTime,
      'title': title,
      'memo': memo,
      'pin': pinId,
    });
    return _plan(date: planDate, title: title, pinId: pinId);
  }

  @override
  Future<DatePlan> update(
    int id, {
    String? planDate,
    String? planTime,
    bool clearTime = false,
    String? title,
    String? memo,
  }) async {
    updated.add({'id': id, 'title': title, 'clearTime': clearTime});
    return _plan(id: id, title: title ?? '');
  }

  @override
  Future<void> remove(int id) async => removed.add(id);

  @override
  Future<DatePlanCompletion> complete(int id) async {
    if (completeError != null) throw completeError!;
    completedIds.add(id);
    return DatePlanCompletion(
      plan: _plan(id: id, completed: true, afterglow: completionGlow),
      afterglow: completionGlow,
    );
  }
}

Widget _wrap(Widget child) => MaterialApp(home: V2Theme(child: child));

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('model', () {
    test('parses a server plan without coordinates', () {
      final plan = DatePlan.fromJson({
        'id': 3,
        'plan_date': '2026-12-24',
        'plan_time': '18:30',
        'title': '카페',
        'memo': null,
        'mine': true,
        'completed': true,
        'pin': {'id': 9, 'title': '성수 카페'},
        'afterglow': {'map_pin_id': 9, 'state': 'needs_visit'},
      });
      expect(plan.pinId, 9);
      expect(plan.pinTitle, '성수 카페');
      expect(plan.afterglow!.needsVisit, isTrue);
      expect(plan.daysUntil(DateTime(2026, 12, 20)), 4);
      expect(_plan(date: '2026-11-23').canComplete(_today), isTrue);
      expect(_plan(date: '2026-11-24').canComplete(_today), isFalse);
      expect(
        _plan(date: '2026-11-20', completed: true).canComplete(_today),
        isFalse,
      );
    });

    test('distance labels', () {
      expect(datePlanDistance(_plan(date: '2026-11-23'), _today), '오늘');
      expect(datePlanDistance(_plan(date: '2026-11-26'), _today), 'D-3');
      expect(datePlanDistance(_plan(date: '2026-11-20'), _today), '3일 지남');
    });
  });

  group('http repository', () {
    test('create sends only the plan fields and parses the reply', () async {
      late http.Request seen;
      final repo = HttpDatePlanRepository(
        baseUrl: 'https://x.test',
        token: 't',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'ok': true,
              'plan': {
                'id': 1,
                'plan_date': '2026-12-24',
                'title': '카페',
                'mine': true,
                'completed': false,
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final plan = await repo.create(
        planDate: '2026-12-24',
        title: '카페',
        pinId: 4,
      );
      expect(plan.id, 1);
      expect(seen.url.path, '/api/date-plans');
      final body = jsonDecode(seen.body) as Map;
      expect(body['map_pin_id'], 4);
      expect(body.containsKey('user_id'), isFalse);
      expect(seen.headers['Authorization'], 'Bearer t');
    });

    test('server rejection becomes DatePlanException(reason)', () async {
      final repo = HttpDatePlanRepository(
        baseUrl: 'https://x.test',
        token: 't',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'ok': false, 'reason': 'plan_author_required'}),
            403,
          ),
        ),
      );
      expect(
        repo.remove(1),
        throwsA(
          isA<DatePlanException>().having(
            (e) => e.reason,
            'reason',
            'plan_author_required',
          ),
        ),
      );
    });
  });

  group('home card', () {
    testWidgets('shows the next plan with its place', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: DatePlanHomeCard(
              next: _plan(pinTitle: '성수 카페'),
              today: _today,
            ),
          ),
        ),
      );
      expect(find.textContaining('D-3'), findsOneWidget);
      expect(find.textContaining(V2Text.keepAll('성수 카페')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('date-plan-card-anniversary')),
        findsNothing,
      );
    });

    testWidgets('shows a same-day anniversary together', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: DatePlanHomeCard(
              next: _plan(),
              today: _today,
              anniversaryLabel: '100일',
            ),
          ),
        ),
      );
      expect(find.text('같은 날 · 100일'), findsOneWidget);
    });

    testWidgets('empty state invites a first plan', (tester) async {
      await tester.pumpWidget(
        _wrap(Scaffold(body: DatePlanHomeCard(next: null, today: _today))),
      );
      expect(find.textContaining('정해 볼까요'), findsOneWidget);
    });
  });

  group('home screen integration', () {
    testWidgets('home shows the upcoming plan card', (tester) async {
      _tall(tester);
      final repo = _FakeRepo()..upcoming = [_plan(title: '한강 산책')];
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            onNavigate: (_) {},
            controller: HomeController(_FakeHomeRepo()),
            notificationsBlocked: () async => false,
            claimableRewards: () async => 0,
            fortuneSeen: () async => true,
            fortuneHeadline: () async => null,
            datePlanRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('date-plan-card')), findsOneWidget);
      expect(find.textContaining(V2Text.keepAll('한강 산책')), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('creates a plan linked to the pin', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(
        _wrap(
          DatePlanEditorScreen(
            repository: repo,
            pinId: 9,
            pinTitle: '성수 카페',
            initialDate: DateTime(2026, 12, 24),
          ),
        ),
      );
      expect(find.byKey(const Key('date_plan_pin')), findsOneWidget);
      // 핀 제목이 제목 기본값이다.
      await tester.enterText(
        find.byKey(const Key('date_plan_title')),
        '성수 카페 가요',
      );
      await tester.tap(find.byKey(const Key('date_plan_save')));
      await tester.pumpAndSettle();
      expect(repo.created, [
        {
          'date': '2026-12-24',
          'time': null,
          'title': '성수 카페 가요',
          'memo': null,
          'pin': 9,
        },
      ]);
    });

    testWidgets('empty title is rejected locally', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(_wrap(DatePlanEditorScreen(repository: repo)));
      await tester.tap(find.byKey(const Key('date_plan_save')));
      await tester.pump();
      expect(find.byKey(const Key('date_plan_error')), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('only the author sees delete, and delete asks first', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(
        _wrap(DatePlanEditorScreen(repository: repo, plan: _plan(mine: false))),
      );
      expect(find.byKey(const Key('date_plan_delete')), findsNothing);

      await tester.pumpWidget(
        _wrap(DatePlanEditorScreen(repository: repo, plan: _plan(id: 5))),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('date_plan_delete')));
      await tester.tap(find.byKey(const Key('date_plan_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date_plan_delete_confirm')));
      await tester.pumpAndSettle();
      expect(repo.removed, [5]);
    });
  });

  group('list and completion flow', () {
    Widget screen(_FakeRepo repo, List<DatePlanAfterglow> opened) => _wrap(
      DatePlansScreen(
        repository: repo,
        now: () => _today,
        anniversaries: const {'2026-11-26': '100일'},
        onOpenAfterglow: (glow) async => opened.add(glow),
      ),
    );

    testWidgets('lists upcoming/past and shows same-day anniversary', (
      tester,
    ) async {
      _tall(tester);
      final repo = _FakeRepo()
        ..upcoming = [_plan(id: 1)]
        ..past = [_plan(id: 2, date: '2026-11-10', title: '지난 데이트')];
      await tester.pumpWidget(screen(repo, []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('date_plan_item_1')), findsOneWidget);
      expect(find.byKey(const Key('date_plan_item_2')), findsOneWidget);
      expect(find.byKey(const Key('date_plan_anniversary_1')), findsOneWidget);
      // 아직 오지 않은 계획에는 "다녀왔어요"가 없다.
      expect(find.byKey(const Key('date_plan_complete_1')), findsNothing);
      expect(find.byKey(const Key('date_plan_complete_2')), findsOneWidget);
    });

    testWidgets('다녀왔어요 completes then opens the afterglow', (tester) async {
      _tall(tester);
      final repo = _FakeRepo()
        ..past = [_plan(id: 2, date: '2026-11-10', pinId: 9, pinTitle: '성수 카페')]
        ..completionGlow = const DatePlanAfterglow(
          pinId: 9,
          state: 'needs_visit',
        );
      final opened = <DatePlanAfterglow>[];
      await tester.pumpWidget(screen(repo, opened));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date_plan_complete_2')));
      await tester.pumpAndSettle();
      expect(repo.completedIds, [2]);
      expect(opened.single.pinId, 9);
    });

    testWidgets('a plan without a place completes without afterglow', (
      tester,
    ) async {
      _tall(tester);
      final repo = _FakeRepo()..past = [_plan(id: 2, date: '2026-11-10')];
      final opened = <DatePlanAfterglow>[];
      await tester.pumpWidget(screen(repo, opened));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date_plan_complete_2')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.byKey(const Key('date_plan_notice')), findsOneWidget);
    });

    testWidgets('completed plans link back to the afterglow', (tester) async {
      _tall(tester);
      final repo = _FakeRepo()
        ..past = [
          _plan(
            id: 2,
            date: '2026-11-10',
            completed: true,
            pinId: 9,
            pinTitle: '성수 카페',
            afterglow: const DatePlanAfterglow(pinId: 9, state: 'recorded'),
          ),
        ];
      final opened = <DatePlanAfterglow>[];
      await tester.pumpWidget(screen(repo, opened));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date_plan_afterglow_2')));
      await tester.pumpAndSettle();
      expect(opened.single.state, 'recorded');
    });

    testWidgets('server refusal shows a calm notice', (tester) async {
      _tall(tester);
      final repo = _FakeRepo()
        ..past = [_plan(id: 2, date: '2026-11-10')]
        ..completeError = const DatePlanException('plan_not_yet');
      await tester.pumpWidget(screen(repo, []));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('date_plan_complete_2')));
      await tester.pumpAndSettle();
      expect(find.text('아직 이 날이 아니에요'), findsOneWidget);
    });
  });
}

class _FakeHomeRepo extends HomeOverviewRepository {
  _FakeHomeRepo() : super.fake();

  @override
  Future<HomeOverview> fetch() async => HomeOverview(
    couple: const HomeCoupleInfo(partnerName: '서윤'),
    failedSections: {},
  );
}
