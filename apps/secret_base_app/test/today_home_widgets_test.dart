import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/screens/home/today_card.dart';
import 'package:secret_base_app/screens/home/today_loop_viewer.dart';
import 'package:secret_base_app/v2/v2.dart';

Widget _app(Widget child) => MaterialApp(
  home: V2Theme(
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  TodayState state(TodayStatus status) => TodayState(
    date: '2026-07-29',
    status: status,
    hasPartnerMoment: status == TodayStatus.partnerWaiting,
    myMoment: status == TodayStatus.selfWaiting
        ? const TodayMoment(userId: 1, userName: '나', caption: '나의 하루')
        : null,
  );

  testWidgets('Today card exposes one contextual primary action', (
    tester,
  ) async {
    var createCount = 0;
    var openCount = 0;

    await tester.pumpWidget(
      _app(
        TodayCard(
          state: state(TodayStatus.partnerWaiting),
          partnerName: '서윤',
          onCreateMoment: () => createCount++,
          onOpenLoop: () => openCount++,
        ),
      ),
    );

    expect(find.text('서윤이 남겼어요'), findsOneWidget);
    expect(find.text('내 순간 남기기'), findsOneWidget);
    await tester.tap(find.text('내 순간 남기기'));
    expect(createCount, 1);
    expect(openCount, 0);

    await tester.pumpWidget(
      _app(
        TodayCard(
          state: state(TodayStatus.complete),
          onCreateMoment: () => createCount++,
          onOpenLoop: () => openCount++,
        ),
      ),
    );
    await tester.tap(find.text('둘이 같이 보기'));
    expect(openCount, 1);
  });

  testWidgets('self waiting card pokes the partner once and then rests', (
    tester,
  ) async {
    var pokes = 0;
    await tester.pumpWidget(
      _app(
        TodayCard(
          state: state(TodayStatus.selfWaiting),
          partnerName: '서윤',
          onCreateMoment: () {},
          onOpenLoop: () {},
          onPoke: () => pokes++,
        ),
      ),
    );

    expect(find.text('나만 남겼어요'), findsOneWidget);
    expect(find.text('서윤을 기다리는 중'), findsOneWidget);
    await tester.tap(find.text('서윤에게 콕 찌르기'));
    expect(pokes, 1);

    await tester.pumpWidget(
      _app(
        TodayCard(
          state: state(TodayStatus.selfWaiting),
          partnerName: '서윤',
          onCreateMoment: () {},
          onOpenLoop: () {},
          onPoke: () => pokes++,
          pokedToday: true,
        ),
      ),
    );
    expect(find.text('오늘은 콕 찔렀어요'), findsOneWidget);
    expect(find.text('서윤에게 콕 찌르기'), findsNothing);
  });

  testWidgets('offline card shows the saved state and no actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TodayCard(
          state: state(TodayStatus.complete),
          onCreateMoment: () {},
          onOpenLoop: () {},
          offline: true,
        ),
      ),
    );
    expect(find.text('저장된 내용'), findsOneWidget);
    expect(find.text('연결되면 같이 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('empty and viewed cards keep a single state-specific CTA', (
    tester,
  ) async {
    var createCount = 0;
    var openCount = 0;

    for (final testCase in [
      (TodayStatus.empty, '오늘의 순간 남기기'),
      (TodayStatus.viewed, '오늘의 순간 다시 보기'),
    ]) {
      await tester.pumpWidget(
        _app(
          TodayCard(
            state: state(testCase.$1),
            onCreateMoment: () => createCount++,
            onOpenLoop: () => openCount++,
          ),
        ),
      );
      expect(find.byType(V2Button), findsOneWidget);
      await tester.tap(find.text(testCase.$2));
    }

    expect(createCount, 1);
    expect(openCount, 1);
  });

  testWidgets('Today Loop viewer renders text, place and deleted tombstone', (
    tester,
  ) async {
    const today = TodayState(
      date: '2026-07-29',
      status: TodayStatus.complete,
      hasPartnerMoment: true,
      myMoment: TodayMoment(
        userId: 1,
        userName: '나',
        mediaType: 'text',
        caption: '한강 산책',
        linkedPlaceName: '한강공원',
      ),
      partnerMoment: TodayMoment(userId: 2, userName: '서윤', deleted: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: V2Theme(
          child: TodayLoopViewer(
            state: today,
            baseUrl: 'https://example.test',
            partnerName: '서윤',
            onMarkViewed: () async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('오늘의 순간'), findsOneWidget);
    expect(find.text('7월 29일 수요일'), findsOneWidget);
    expect(find.text('한강 산책'), findsOneWidget);
    expect(find.text('한강공원'), findsOneWidget);
    expect(find.text(V2Text.keepAll('서윤이 이 순간을 지웠어요')), findsOneWidget);
  });

  testWidgets('opening a completed day marks it viewed exactly once', (
    tester,
  ) async {
    var marked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: V2Theme(
          child: TodayLoopViewer(
            state: state(TodayStatus.complete),
            baseUrl: 'https://example.test',
            onMarkViewed: () async => marked++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(marked, 1);
  });
}
