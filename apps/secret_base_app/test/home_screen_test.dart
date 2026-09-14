import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/screens/relationship/fortune_screen.dart';
import 'package:secret_base_app/screens/home/home_screen.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';
import 'package:secret_base_app/screens/relationship/saju_screen.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';

void main() {
  testWidgets('home makes every quick action discoverable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(onNavigate: (_) {})),
      ),
    );

    for (final label in ['비밀 지도', '비밀기지', '운세', '타로', '사주']) {
      expect(find.text(label, skipOffstage: false), findsOneWidget);
    }
    expect(find.text('함께 해볼까요?'), findsOneWidget);
    expect(find.text('좌우로 밀어 더 보기'), findsOneWidget);
    expect(find.bySemanticsLabel('비밀 지도: 장소 남기기'), findsOneWidget);
    expect(
      find.bySemanticsLabel('사주: 나의 흐름', skipOffstage: false),
      findsOneWidget,
    );

    expect(find.text('오늘 기록'), findsNothing);
    expect(find.text('함께 놀기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home keeps today entry, refresh, and relationship continuation explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onNavigate: (_) {},
            relationshipStatus: RelationshipAssessmentStatus.inProgress,
          ),
        ),
      ),
    );

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh,
      isNotNull,
    );
    expect(find.text('오늘의 루프를 준비하고 있어요'), findsOneWidget);
    expect(find.text('관계 이해 이어보기'), findsOneWidget);
    expect(find.text('검사 이어가기'), findsOneWidget);
  });

  testWidgets('quick action semantics tap keeps its existing navigation target', (
    tester,
  ) async {
    var navigationTarget = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onNavigate: (target) => navigationTarget = target,
            todayStateLoader: () async => const TodayState(
              date: '2026-09-14',
              status: TodayStatus.empty,
            ),
          ),
        ),
      ),
    );

    tester.semantics.tap(
      find.semantics.byLabel('비밀 지도: 장소 남기기'),
    );
    await tester.pump();

    expect(navigationTarget, 2);
  });

  testWidgets('home shows a retry entry when Today loading fails', (tester) async {
    var attempts = 0;
    Future<TodayState> loadToday() async {
      attempts++;
      if (attempts == 1) throw StateError('unavailable');
      return const TodayState(
        date: '2026-09-14',
        status: TodayStatus.empty,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(onNavigate: (_) {}, todayStateLoader: loadToday),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('오늘의 루프를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('오늘의 순간을 남겨볼까요?'), findsOneWidget);
  });

  testWidgets('home gives a short relationship entry when no assessment is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            onNavigate: (_) {},
            relationshipStatus: RelationshipAssessmentStatus.notStarted,
          ),
        ),
      ),
    );

    expect(find.text('관계 이해 알아보기'), findsOneWidget);
    expect(find.text('관계 이해 살펴보기'), findsOneWidget);
  });

  testWidgets('relationship quick actions open their dedicated screens', (
    tester,
  ) async {
    var navigationTarget = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(onNavigate: (target) => navigationTarget = target),
        ),
      ),
    );

    await tester.tap(find.text('비밀 지도'));
    expect(navigationTarget, 2);

    await tester.tap(find.text('비밀기지'));
    await tester.pumpAndSettle();
    expect(find.byType(SecretBaseScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();

    await tester.tap(find.text('운세'));
    await tester.pumpAndSettle();
    expect(find.byType(RelationshipFortuneScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();

    await tester.tap(find.text('타로'));
    await tester.pumpAndSettle();
    expect(find.byType(TarotScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();

    await tester.tap(find.text('사주'));
    await tester.pumpAndSettle();
    expect(find.byType(SajuScreen), findsOneWidget);
  });
}
