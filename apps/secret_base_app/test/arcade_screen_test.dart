import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/arcade_screen.dart';

void main() {
  testWidgets('arcade lobby exposes the full game catalog before selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('arcade_game_grid')), findsOneWidget);
    expect(find.text('15개 게임을 둘이서 골라보세요. 선택하면 시작 방법이 나타나요.'), findsOneWidget);
    expect(find.byKey(const Key('arcade_empty_selection')), findsOneWidget);
    expect(find.text('게임 선택 → 시작하기 → 상대방과 함께 플레이'), findsOneWidget);
    expect(find.byKey(const ValueKey('arcade_game_blackjack')), findsOneWidget);
    expect(find.byKey(const ValueKey('arcade_game_gostop')), findsOneWidget);
  });

  testWidgets('selecting a game reveals one primary start action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arcade_game_dice')));
    await tester.pumpAndSettle();

    expect(find.text('주사위'), findsWidgets);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
