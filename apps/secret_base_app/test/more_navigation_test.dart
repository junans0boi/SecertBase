import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/home_shell.dart';
import 'package:secret_base_app/screens/relationship/relationship_understanding_screen.dart';
import 'package:secret_base_app/screens/secret_base/secret_base_screen.dart';
import 'package:secret_base_app/screens/settings/settings_screen.dart';

void main() {
  testWidgets('more details keep the shell navigation visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('내 공간'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 이모지'), findsOneWidget);
    expect(find.text('기념일 추가'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('more keeps every exposed row reachable through its existing route', (
    tester,
  ) async {
    final destinations = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(onNavigate: destinations.add),
      ),
    );
    await tester.pump();

    for (final label in ['내 공간', 'MomentLoop', '비밀 지도', '함께 놀기', '우리의 비밀기지', '관계 이해']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.bySemanticsLabel('MomentLoop: 우리의 순간을 기록하고 돌아봐요'),
      findsOneWidget,
    );

    await tester.tap(find.text('MomentLoop'));
    await tester.tap(find.text('비밀 지도'));
    await tester.tap(find.text('함께 놀기'));
    expect(destinations, [1, 2, 3]);

    await tester.tap(find.text('우리의 비밀기지'));
    await tester.pump();
    expect(find.byType(SecretBaseScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pump();

    await tester.ensureVisible(find.text('관계 이해'));
    await tester.pump();
    await tester.tap(find.text('관계 이해'));
    await tester.pump();
    expect(find.byType(RelationshipUnderstandingScreen), findsOneWidget);
  });
}
