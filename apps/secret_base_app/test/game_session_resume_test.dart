// game_session_resume_test.dart
//
// Widget seam: GameLobbyScreen receives a resumed ack via the injectable
// onJoinLobby callback and must navigate directly to the game screen
// without a countdown or host new-game call.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';

void main() {
  testWidgets(
    'GameLobbyScreen navigates to game screen immediately on resumed result',
    (tester) async {
      final socket = SocketService();

      // Simulate the server returning { ok: true, status: 'resumed', gameType: 'yut' }
      // by injecting a callback that sets lobbyResumedGameType.
      void simulateResume(String gameType) {
        socket.lobbyResumedGameType = gameType;
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        socket.notifyListeners();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: GameLobbyScreen(
            gameType: 'yut',
            title: '윷놀이',
            description: '테스트',
            emoji: '🎲',
            color: Colors.orange,
            backgroundColor: Colors.orange.shade50,
            gameScreen: const Text('game-screen-sentinel'),
            onJoinLobby: simulateResume,
          ),
        ),
      );

      // Trigger addPostFrameCallback (which calls onJoinLobby → simulateResume)
      await tester.pump();
      // Allow _onSocket to fire from notifyListeners and Navigator.pushReplacement to settle
      await tester.pumpAndSettle();

      expect(
        find.text('game-screen-sentinel'),
        findsOneWidget,
        reason: 'game screen must appear immediately on resume without countdown',
      );
      expect(
        find.text('게임 시작!'),
        findsNothing,
        reason: 'countdown overlay must not appear on resume',
      );
    },
  );

  testWidgets(
    'GameLobbyScreen shows lobby UI when not resumed',
    (tester) async {
      // null onJoinLobby → defaults to SocketService.joinGameLobby (no-op without a real socket)
      await tester.pumpWidget(
        MaterialApp(
          home: GameLobbyScreen(
            gameType: 'yut',
            title: '윷놀이',
            description: '테스트',
            emoji: '🎲',
            color: Colors.orange,
            backgroundColor: Colors.orange.shade50,
            gameScreen: const Text('game-screen-sentinel'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('game-screen-sentinel'), findsNothing,
          reason: 'game screen must not appear without a server resume signal');
      expect(find.text('윷놀이'), findsOneWidget,
          reason: 'lobby screen should be visible while waiting');
    },
  );
}
