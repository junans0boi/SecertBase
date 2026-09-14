import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/app_theme.dart';
import 'package:secret_base_app/screens/home_shell.dart';

void main() {
  testWidgets('bottom navigation exposes five labelled destinations in order', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    );
    await tester.pump();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 0);
    expect(
      navigation.destinations.cast<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      ['홈', 'MomentLoop', '지도', '놀이', '더보기'],
    );
    for (final label in ['홈', 'MomentLoop', '지도', '놀이', '더보기']) {
      expect(find.bySemanticsLabel(RegExp(label)), findsWidgets);
    }
    semantics.dispose();
  });

  testWidgets('bottom navigation switches to each primary surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    );
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.text('MomentLoop'));
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('MomentLoop'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('지도'));
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('우리 지도'), findsOneWidget);

    await tester.tap(find.text('놀이'));
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    expect(find.text('둘이서 놀기'), findsOneWidget);

    await tester.tap(find.text('더보기'));
    await tester.pump();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
    expect(find.text('전체'), findsOneWidget);
  });
}
