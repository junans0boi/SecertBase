// 로비 옵션: 방장은 고르고, 상대는 방장이 고른 값을 읽기 전용으로 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';
import 'package:secret_base_app/screens/arcade/lobby_options.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  Future<SocketService> pumpLobby(
    WidgetTester tester, {
    required String gameType,
    required bool host,
    Map<String, Object> options = const {},
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final socket = SocketService();
    void join(String type) {
      socket.userId = host ? 'ME' : 'YOU';
      socket.lobbyGameType = type;
      socket.lobbyHost = 'ME';
      socket.lobbyPlayers = ['ME', 'YOU'];
      socket.lobbyOptions = options;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      socket.notifyListeners();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: GameLobbyScreen(
          gameType: gameType,
          title: '패널티킥',
          description: '테스트',
          emoji: '⚽',
          color: Colors.teal,
          backgroundColor: Colors.teal.shade50,
          gameScreen: const SizedBox(),
          onJoinLobby: join,
        ),
      ),
    );
    await tester.pump();
    return socket;
  }

  test('client option list mirrors the server defaults', () {
    // 서버 lobby-options.js의 기본값과 같아야 한다(첫 번째 선택지가 기본값).
    expect(lobbyOptionsFor('penalty').single.defaultValue, 3);
    expect(lobbyOptionsFor('pirate').single.defaultValue, 8);
    expect(lobbyOptionsFor('uno').single.defaultValue, 'go_wild');
    expect(lobbyOptionsFor('blackjack'), isEmpty);
  });

  testWidgets('host sees the penalty cell choice and can switch to 6', (
    tester,
  ) async {
    final socket = await pumpLobby(tester, gameType: 'penalty', host: true);
    expect(find.text('골대 칸'), findsOneWidget);
    expect(find.text('방장이 선택'), findsOneWidget);
    await tester.tap(find.text('6칸'));
    await tester.pump();
    expect(socket.lobbyOptions['cells'], 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partner sees the host choice read-only', (tester) async {
    final socket = await pumpLobby(
      tester,
      gameType: 'penalty',
      host: false,
      options: {'cells': 6},
    );
    expect(find.text('방장이 고른 설정'), findsOneWidget);
    await tester.tap(find.text('3칸'));
    await tester.pump();
    expect(socket.lobbyOptions['cells'], 6, reason: '상대는 바꿀 수 없다');
  });

  testWidgets('games without options show no picker', (tester) async {
    await pumpLobby(tester, gameType: 'blackjack', host: true);
    expect(find.byType(LobbyOptionPicker), findsNothing);
  });
}
