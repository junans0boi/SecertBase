import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/bowling_screen.dart';
import 'package:secret_base_app/screens/arcade/games/penalty_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final socket = SocketService();
    socket.bowlingState = null;
    socket.penaltyState = null;
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

  testWidgets('penalty screen lets the kicker pick a goal cell by tapping', (
    tester,
  ) async {
    final socket = SocketService();
    socket.userId = 'p1';
    socket.penaltyState = {
      'status': 'playing',
      'round': 1,
      'kicker': 'p1',
      'keeper': 'p2',
      'submissions': <String, dynamic>{},
      'scores': {'p1': 0, 'p2': 0},
      'rounds': <dynamic>[],
      'result': null,
    };

    await tester.pumpWidget(const MaterialApp(home: PenaltyScreen()));
    await tester.pump();

    expect(find.text('⚽ 골대에서 노릴 코스를 탭하세요'), findsOneWidget);
    expect(find.text('코스를 먼저 선택하세요'), findsOneWidget);

    // Tap inside the goal (upper area of the pitch) to pick a cell.
    final pitch = find.byKey(const Key('penalty_pitch'));
    final rect = tester.getRect(pitch);
    await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * 0.25));
    await tester.pump();

    expect(find.text('이 코스로 슛! ⚽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
