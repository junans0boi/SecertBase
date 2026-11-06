// 블랙잭·도둑잡기 로비: 시안대로 규칙·참가자·시작 버튼을 보여 주고, 방장만 시작할 수 있다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';
import 'package:secret_base_app/widgets/play_kit/modern_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpLobby(
    WidgetTester tester, {
    required String gameType,
    required bool host,
    List<String> players = const ['ME', 'YOU'],
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final socket = SocketService();
    void join(String type) {
      socket.userId = host ? 'ME' : 'YOU';
      socket.lobbyGameType = type;
      socket.lobbyHost = 'ME';
      socket.lobbyPlayers = players;
      socket.presenceNicknames = {'YOU': '서윤'};
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      socket.notifyListeners();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: GameLobbyScreen(
          gameType: gameType,
          title: '테스트',
          description: '테스트',
          emoji: '🃏',
          color: Colors.teal,
          backgroundColor: Colors.teal.shade50,
          gameScreen: const SizedBox(),
          onJoinLobby: join,
        ),
      ),
    );
    await tester.pump();
  }

  ModButton startButton(WidgetTester tester) =>
      tester.widget<ModButton>(find.byType(ModButton));

  testWidgets(
    'blackjack lobby shows the rules summary and lets the host start',
    (tester) async {
      await pumpLobby(tester, gameType: 'blackjack', host: true);
      expect(find.text('블랙잭 1:1'), findsOneWidget);
      expect(find.text('먼저 2승'), findsOneWidget);
      expect(find.text('최대 5라운드'), findsOneWidget);
      expect(find.text('30초'), findsOneWidget);
      expect(find.text('방장 · 준비 완료'), findsOneWidget);
      expect(find.text('서윤'), findsOneWidget);
      expect(find.text('게임 시작'), findsOneWidget);
      expect(startButton(tester).onPressed, isNotNull);
      expect(find.textContaining('USER'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('oldmaid lobby has its own rules and waits for a partner', (
    tester,
  ) async {
    await pumpLobby(
      tester,
      gameType: 'oldmaid',
      host: true,
      players: const ['ME'],
    );
    expect(find.text('도둑잡기'), findsWidgets);
    expect(find.text('25초'), findsOneWidget);
    expect(find.text('52장 + 조커 1장'), findsOneWidget);
    expect(find.text('상대방을 기다리는 중'), findsOneWidget);
    expect(startButton(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a guest cannot start the game', (tester) async {
    await pumpLobby(tester, gameType: 'blackjack', host: false);
    expect(startButton(tester).onPressed, isNull);
    expect(find.text('방장이 시작하길 기다려요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lobby fits a tall desktop window too', (tester) async {
    await pumpLobby(
      tester,
      gameType: 'oldmaid',
      host: true,
      size: const Size(1280, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
