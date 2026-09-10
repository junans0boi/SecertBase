import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/relationship/fortune_screen.dart';
import 'package:secret_base_app/screens/home/home_screen.dart';
import 'package:secret_base_app/screens/relationship/saju_screen.dart';
import 'package:secret_base_app/screens/relationship/tarot_screen.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';

void main() {
  testWidgets('home quick actions expose the requested relationship entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen(onNavigate: (_) {})),
      ),
    );

    expect(find.text('비밀 지도'), findsOneWidget);
    expect(find.text('비밀기지'), findsOneWidget);
    expect(find.text('운세'), findsOneWidget);
    expect(find.text('타로'), findsOneWidget);
    expect(find.text('사주'), findsOneWidget);

    expect(find.text('오늘 기록'), findsNothing);
    expect(find.text('함께 놀기'), findsNothing);
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
