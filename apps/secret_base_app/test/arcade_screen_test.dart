import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/arcade_screen.dart';

void main() {
  testWidgets('arcade lobby keeps the legacy horizontal game picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('둘이서 놀기'), findsOneWidget);
    expect(find.text('게임 고르기'), findsOneWidget);
    expect(find.text('위에서 게임을 골라보세요'), findsOneWidget);
    expect(find.byKey(const Key('arcade_game_grid')), findsNothing);
  });

  testWidgets('selecting a game keeps the legacy detail action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('블랙잭').first);
    await tester.pumpAndSettle();

    expect(find.text('블랙잭'), findsWidgets);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
