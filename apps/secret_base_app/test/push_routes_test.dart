import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/core/today_api.dart';
import 'package:secret_base_app/core/push/push_today_route.dart';
import 'package:secret_base_app/core/push/push_game_route.dart';
import 'package:secret_base_app/screens/home/today_loop_viewer.dart';
import 'package:secret_base_app/screens/arcade/games/uno_screen.dart';
import 'package:secret_base_app/widgets/game_session_presence.dart';

void main() {
  testWidgets('Today Loop push loads actual state and opens the viewer', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = TodayApi(
      baseUrl: 'http://x.test',
      token: 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'ok': true,
            'date': '2026-10-12',
            'status': 'complete',
            'hasPartnerMoment': true,
            'myMoment': {'user_id': 1, 'caption': '우리의 실제 기록'},
            'partnerMoment': {'user_id': 2, 'caption': '둘이 남긴 순간'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: PushTodayRoute(api: api)));
    await tester.pumpAndSettle();
    expect(requests.single.url.path, '/api/retention/today');
    expect(find.byType(TodayLoopViewer), findsOneWidget);
    expect(find.text('우리의 실제 기록'), findsOneWidget);
    expect(find.text('둘이 남긴 순간'), findsOneWidget);
  });

  test('game invitation uses the actual game and presence context', () {
    final lobby = pushGameLobby('uno')!;
    expect(lobby.gameType, 'uno');
    expect(lobby.title, '원카드');
    expect(lobby.gameScreen, isA<GameSessionPresence>());
    final presence = lobby.gameScreen as GameSessionPresence;
    expect(presence.gameType, 'uno');
    expect(presence.child, isA<UnoScreen>());
    expect(pushGameLobby('unknown-game'), isNull);
  });
}
