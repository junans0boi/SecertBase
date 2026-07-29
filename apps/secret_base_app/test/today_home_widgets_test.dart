import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/screens/home/today_card.dart';
import 'package:secret_base_app/screens/home/today_loop_viewer.dart';

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
      MaterialApp(
        home: Scaffold(
          body: TodayCard(
            state: state(TodayStatus.partnerWaiting),
            onCreateMoment: () => createCount++,
            onOpenLoop: () => openCount++,
          ),
        ),
      ),
    );

    expect(find.text('상대가 오늘의 순간을 남겼어요'), findsOneWidget);
    expect(find.text('내 순간 남기기'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.textContaining('광고'), findsNothing);
    await tester.tap(find.text('내 순간 남기기'));
    expect(createCount, 1);
    expect(openCount, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayCard(
            state: state(TodayStatus.complete),
            onCreateMoment: () => createCount++,
            onOpenLoop: () => openCount++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('오늘의 루프 열기'));
    expect(openCount, 1);
  });

  testWidgets('self waiting card shows the author moment and waiting state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayCard(
            state: state(TodayStatus.selfWaiting),
            onCreateMoment: () {},
            onOpenLoop: () {},
          ),
        ),
      ),
    );

    expect(find.text('나의 하루'), findsOneWidget);
    expect(find.text('상대의 순간을 기다리고 있어요'), findsOneWidget);
    expect(find.text('내 순간 보기'), findsOneWidget);
  });

  testWidgets('empty and viewed cards keep a single state-specific CTA', (
    tester,
  ) async {
    var createCount = 0;
    var openCount = 0;

    for (final testCase in [
      (TodayStatus.empty, '오늘의 순간 남기기'),
      (TodayStatus.viewed, '오늘의 루프 다시 보기'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayCard(
              state: state(testCase.$1),
              onCreateMoment: () => createCount++,
              onOpenLoop: () => openCount++,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
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
      partnerMoment: TodayMoment(userId: 2, userName: '상대', deleted: true),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TodayLoopViewer(state: today, baseUrl: 'https://example.test'),
      ),
    );

    expect(find.text('오늘의 루프'), findsOneWidget);
    expect(find.text('한강 산책'), findsOneWidget);
    expect(find.text('한강공원'), findsOneWidget);
    expect(find.text('삭제된 오늘의 순간이에요'), findsOneWidget);
  });
}
