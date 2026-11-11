import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/features/home/application/home_controller.dart';
import 'package:secret_base_app/features/home/data/home_overview_repository.dart';
import 'package:secret_base_app/features/home/domain/home_overview.dart';
import 'package:secret_base_app/screens/archive/moment_loop_screen.dart';
import 'package:secret_base_app/screens/auth/partner_screen.dart';
import 'package:secret_base_app/screens/home/home_format.dart';
import 'package:secret_base_app/screens/home/home_screen.dart';
import 'package:secret_base_app/screens/home/today_poke.dart';
import 'package:secret_base_app/v2/v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepo extends HomeOverviewRepository {
  _FakeRepo(this.next) : super.fake();
  Future<HomeOverview> Function() next;
  int fetches = 0;

  @override
  Future<HomeOverview> fetch() {
    fetches++;
    return next();
  }
}

String _day(DateTime d) => isoDay(d);

HomeOverview _overview({
  TodayStatus status = TodayStatus.empty,
  DateTime? start,
  bool noStart = false,
  bool todayFailed = false,
  HomeMemoryCard? memory,
}) {
  final s = noStart
      ? null
      : (start ?? today().subtract(const Duration(days: 411)));
  return HomeOverview(
    couple: HomeCoupleInfo(
      partnerName: '서윤',
      dDay: s == null ? null : dPlus(s),
      startDate: s == null ? null : _day(s),
    ),
    memoryCard: memory,
    memoryCardTotal: memory == null ? 0 : 1,
    todayState: todayFailed
        ? null
        : TodayState(date: _day(today()), status: status),
    failedSections: {if (todayFailed) HomeSection.today},
  );
}

Widget _home(
  _FakeRepo repo, {
  ValueChanged<int>? onNavigate,
  TodayPoke? poke,
  Future<void> Function(DateTime)? saveStartDate,
  Future<bool> Function()? blocked,
  bool fortuneSeen = false,
}) => MaterialApp(
  home: HomeScreen(
    onNavigate: onNavigate ?? (_) {},
    controller: HomeController(repo),
    notificationsBlocked: blocked ?? () async => false,
    claimableRewards: () async => 2,
    poke: poke,
    saveStartDate: saveStartDate,
    fortuneSeen: () async => fortuneSeen,
    fortuneHeadline: () async => '차분히 쌓아 가는 하루',
  ),
);

Finder _together(int days) => find.text('함께한 지 $days일', findRichText: true);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home: date, 함께한 날, next day, one focus card, quiet rows', (
    tester,
  ) async {
    _tall(tester);
    final repo = _FakeRepo(() async => _overview());
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text(monthDayWeekday(DateTime.now())), findsOneWidget);
    expect(_together(412), findsOneWidget);
    expect(find.textContaining('500일까지'), findsOneWidget);
    // One primary CTA for the day.
    expect(find.text('오늘의 순간 남기기'), findsOneWidget);
    expect(find.text('지금 할 일'), findsOneWidget);
    // Quiet rows; the old four shortcut tiles moved to 더보기.
    expect(find.text('오늘의 운세'), findsOneWidget);
    expect(find.text('아직 안 봤어요 · 한 줄 열어 보기'), findsOneWidget);
    expect(find.text('지난 순간'), findsOneWidget);
    expect(find.text(V2Text.keepAll('비밀기지')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after the moment, the fortune becomes the one thing to do', (
    tester,
  ) async {
    _tall(tester);
    final repo = _FakeRepo(() async => _overview(status: TodayStatus.complete));
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('오늘의 운세가\n도착했어요'), findsOneWidget);
    expect(find.text('열어 보기'), findsOneWidget);
    expect(find.text('둘 다 남겼어요 · 크게 보기'), findsOneWidget);

    await tester.tap(find.text('나중에'));
    await tester.pump();
    expect(find.text('✓ 오늘 할 일 끝'), findsOneWidget);
  });

  testWidgets('with everything done the card shows both moments', (
    tester,
  ) async {
    _tall(tester);
    final repo = _FakeRepo(() async => _overview(status: TodayStatus.complete));
    await tester.pumpWidget(_home(repo, fortuneSeen: true));
    await tester.pump();
    await tester.pump();

    expect(find.text('✓ 오늘 할 일 끝'), findsOneWidget);
    expect(find.text('차분히 쌓아 가는 하루'), findsOneWidget);
  });

  testWidgets('empty-day CTA opens the 기록 composer', (tester) async {
    _tall(tester);
    final repo = _FakeRepo(() async => _overview());
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('오늘의 순간 남기기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MomentLoopScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing start date asks for the first day and saves it', (
    tester,
  ) async {
    _tall(tester);
    DateTime? saved;
    final repo = _FakeRepo(() async => _overview(noStart: true));
    await tester.pumpWidget(_home(repo, saveStartDate: (d) async => saved = d));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('우리의 첫날을'), findsWidgets);
    await tester.tap(find.text('첫날 정하기').first);
    await tester.pumpAndSettle();
    expect(find.text('우리의 첫날은 언제인가요?'), findsOneWidget);
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(saved, today());
    expect(repo.fetches, greaterThanOrEqualTo(2));
  });

  testWidgets('today failure only breaks the today card and can retry', (
    tester,
  ) async {
    _tall(tester);
    var failing = true;
    final repo = _FakeRepo(() async => _overview(todayFailed: failing));
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('오늘의 순간을 불러오지 못했어요'), findsOneWidget);
    expect(_together(412), findsOneWidget);
    expect(find.text('지난 순간'), findsOneWidget);

    failing = false;
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('오늘의 순간을 불러오지 못했어요'), findsNothing);
    expect(find.text('오늘의 순간 남기기'), findsOneWidget);
  });

  testWidgets('a failed first load shows a full retry state', (tester) async {
    var calls = 0;
    final repo = _FakeRepo(() async {
      calls++;
      if (calls == 1) throw StateError('down');
      return _overview();
    });
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('홈을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    await tester.pump();
    expect(find.text('홈을 불러오지 못했어요'), findsNothing);
  });

  testWidgets('loading shows a skeleton instead of a spinner', (tester) async {
    final repo = _FakeRepo(
      () => Future.delayed(const Duration(seconds: 5), _overview),
    );
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    expect(find.byType(V2Shimmer), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unpaired home offers connecting', (tester) async {
    final repo = _FakeRepo(() async => HomeOverview());
    await tester.pumpWidget(_home(repo));
    await tester.pump();
    await tester.pump();

    expect(find.text('아직 연결되지 않았어요'), findsOneWidget);
    await tester.tap(find.text('연결하러 가기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PartnerScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('지난 순간 goes to the 기록 tab', (tester) async {
    _tall(tester);
    int? tab;
    final repo = _FakeRepo(() async => _overview());
    await tester.pumpWidget(_home(repo, onNavigate: (i) => tab = i));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('지난 순간'));
    await tester.pump();
    expect(tab, 1);
  });

  testWidgets('notification-denied banner and first-use checklist show', (
    tester,
  ) async {
    _tall(tester);
    final repo = _FakeRepo(
      () async => _overview(start: today(), status: TodayStatus.selfWaiting),
    );
    await tester.pumpWidget(_home(repo, blocked: () async => true));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('알림이 꺼져 있어요'), findsOneWidget);
    expect(find.text('시작해 볼까요?'), findsOneWidget);
    expect(_together(1), findsOneWidget);
  });

  testWidgets('poke is sent once a day and then rests', (tester) async {
    _tall(tester);
    var sent = 0;
    final poke = TodayPoke(
      send: () async {
        sent++;
        return true;
      },
    );
    final repo = _FakeRepo(
      () async => _overview(status: TodayStatus.selfWaiting),
    );
    await tester.pumpWidget(_home(repo, poke: poke, fortuneSeen: true));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('서윤에게 콕 찌르기'));
    await tester.pump();
    await tester.pump();
    expect(sent, 1);
    expect(find.text('오늘은 콕 찔렀어요'), findsOneWidget);
    expect(await poke.send(), PokeOutcome.alreadyToday);
    expect(sent, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
