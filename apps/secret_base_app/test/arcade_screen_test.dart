import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/arcade_screen.dart';

void main() {
  testWidgets("놀이: attendance, today's pick, all games as tiles", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('놀이'), findsOneWidget);
    expect(find.text('오늘 출석하고 500코인 받기'), findsOneWidget);
    expect(find.textContaining('오늘의 추천'), findsOneWidget);
    expect(find.text('전체 게임'), findsOneWidget);
    expect(find.byKey(const Key('arcade_game_tiles')), findsOneWidget);
  });

  testWidgets('a game opens its sheet with records and 시작하기', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SocketService().isConnected = false;

    await tester.pumpWidget(const MaterialApp(home: ArcadeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arcade_game_blackjack')));
    await tester.pumpAndSettle();

    expect(find.text('블랙잭'), findsWidgets);
    expect(find.text('승률'), findsOneWidget);
    expect(find.text('시작하기'), findsWidgets);
    expect(find.text('상대방 연결을 확인하고 있어요'), findsWidgets);
  });
}
