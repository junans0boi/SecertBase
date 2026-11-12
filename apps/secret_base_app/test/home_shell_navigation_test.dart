import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/screens/home/home_screen.dart';
import 'package:secret_base_app/screens/home_shell.dart';
import 'package:secret_base_app/v2/v2.dart';

int _selected(WidgetTester tester) =>
    tester.widget<V2BottomTabBar>(find.byType(V2BottomTabBar)).currentIndex;

void main() {
  testWidgets(
    'offline banner appears when probe fails and clears on recovery',
    (tester) async {
      var online = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeShell(
            connectivityProbe: () async => online,
            probeInterval: const Duration(seconds: 5),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('인터넷 연결이 끊겼어요'), findsOneWidget);
      expect(find.byType(V2BottomTabBar), findsOneWidget);

      online = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.textContaining('인터넷 연결이 끊겼어요'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('bottom navigation exposes five labelled destinations in order', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();

    expect(_selected(tester), 0);
    expect(
      tester
          .widget<V2BottomTabBar>(find.byType(V2BottomTabBar))
          .items
          .map((i) => i.label),
      ['홈', '기록', '지도', '놀이', '더보기'],
    );
    for (final label in ['홈', '기록', '지도', '놀이', '더보기']) {
      expect(find.bySemanticsLabel(RegExp('^$label, 탭')), findsWidgets);
    }
    expect(find.text('MomentLoop'), findsNothing);
    semantics.dispose();
  });

  testWidgets('tabs switch and the home tab keeps its state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();
    final home = tester.state(find.byType(HomeScreen));

    for (var i = 1; i <= 4; i++) {
      await tester.tap(find.byKey(Key('v2_tab_$i')));
      await tester.pump();
      expect(_selected(tester), i);
    }

    await tester.tap(find.byKey(const Key('v2_tab_0')));
    await tester.pump();
    expect(_selected(tester), 0);
    // Same State object: the home tab was kept alive, not rebuilt.
    expect(tester.state(find.byType(HomeScreen)), same(home));
  });

  testWidgets('tab bar fits a narrow screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
