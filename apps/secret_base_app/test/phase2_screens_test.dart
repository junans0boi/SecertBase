import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/bowling_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final socket = SocketService();
    socket.bowlingState = null;
    socket.userId = null;
  });

  testWidgets('bowling screen renders lane, score sheet and controls', (
    tester,
  ) async {
    final socket = SocketService();
    socket.userId = 'p1';
    socket.bowlingState = {
      'status': 'playing',
      'turn': 'p1',
      'rolls': {
        'p1': [5, 3],
        'p2': [10],
      },
      'scores': {'p1': 8, 'p2': 10},
      'frames': {
        'p1': [
          {'frameIndex': 1, 'r1': '5', 'r2': '3', 'r3': '', 'cumScore': '8'},
        ],
        'p2': [
          {'frameIndex': 1, 'r1': '', 'r2': 'X', 'r3': '', 'cumScore': '10'},
        ],
      },
      'lastRoll': null,
      'result': null,
    };

    await tester.pumpWidget(const MaterialApp(home: BowlingScreen()));
    await tester.pump();

    // Score sheet with classic notation from the server.
    expect(find.text('X'), findsOneWidget);
    expect(find.text('TOT'), findsOneWidget);
    // My-turn controls: direction + curve only (no lateral position slider).
    expect(find.text('방향'), findsOneWidget);
    expect(find.text('커브'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.text('공 굴리기 🎳'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  // 패널티킥 화면 테스트는 test/penalty_screen_test.dart(게임 2.0).
}
