// 패널티킥 2.0 화면: 3칸·6칸 고르기, 확정 버튼 상태, 상대 킥 기록, 첫 판 안내, 360px.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/penalty/penalty_controller.dart';
import 'package:secret_base_app/screens/arcade/games/penalty/penalty_controls.dart';
import 'package:secret_base_app/screens/arcade/games/penalty_screen.dart';
import 'package:secret_base_app/widgets/play_kit/play_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> stateMap({
  int cells = 3,
  String kicker = 'me',
  String keeper = 'op',
  List<Map<String, dynamic>> rounds = const [],
  Map<String, dynamic> submissions = const {},
  String status = 'playing',
  Map<String, dynamic>? result,
  String gameId = 'g1',
  int? round,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'gameId': gameId,
    'status': status,
    'cells': cells,
    'players': ['me', 'op'],
    'firstKicker': 'me',
    'round': round ?? rounds.length + 1,
    'kicker': kicker,
    'keeper': keeper,
    'submissions': submissions,
    'scores': {
      'me': rounds.where((r) => r['kicker'] == 'me' && r['isGoal']).length,
      'op': rounds.where((r) => r['kicker'] == 'op' && r['isGoal']).length,
    },
    'rounds': rounds,
    'suddenDeath': false,
    'autoPicks': {'me': 0, 'op': 0},
    'turnDeadline': status == 'playing' ? now + 15000 : null,
    'serverNow': now,
    'series': {
      'wins': {'me': 0, 'op': 0},
      'draws': 0,
      'games': 0,
    },
    'result': result,
  };
}

Map<String, dynamic> kick(String kicker, int dir, int keeperDir) => {
  'round': 1,
  'kicker': kicker,
  'keeper': kicker == 'me' ? 'op' : 'me',
  'kickerDir': dir,
  'keeperDir': keeperDir,
  'isGoal': dir != keeperDir,
  'autoKicker': false,
  'autoKeeper': false,
};

void main() {
  final c = PenaltyController.instance;

  setUp(() {
    resetHowToRequests();
    SharedPreferences.setMockInitialValues({'penalty_tutorial_seen': true});
    final socket = SocketService();
    socket.userId = 'me';
    socket.profileEmojis = {'me': '🐻', 'op': '🐰'};
    socket.presenceNicknames = {'op': '토끼'};
    c.state = null;
    c.submitting = false;
  });

  tearDown(() {
    c.state = null;
    final socket = SocketService();
    socket.userId = null;
    socket.profileEmojis = {};
    socket.presenceNicknames = {};
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PenaltyScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  PenaltyShootButton confirm(WidgetTester tester) => tester
      .widget<PenaltyShootButton>(find.byKey(const Key('penalty_confirm')));

  testWidgets(
    'without a state it shows the preparing message, no start button',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('판을 준비하는 중…'), findsOneWidget);
      expect(find.textContaining('시작'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '3 cells: three goal zones and three buttons, tap selects, confirm says 슛!',
    (tester) async {
      c.applyState(stateMap());
      await pumpScreen(tester);

      for (int i = 0; i < 3; i++) {
        expect(find.byKey(Key('penalty_zone_$i')), findsOneWidget);
        expect(find.byKey(Key('penalty_button_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('penalty_zone_3')), findsNothing);
      expect(find.text('왼쪽'), findsOneWidget);
      expect(find.text('가운데'), findsOneWidget);
      expect(find.text('오른쪽'), findsOneWidget);
      expect(find.text('내가 찰 차례! 어디로 찰까요?'), findsOneWidget);
      expect(find.text('승부차기 1번째 · 내가 찰 차례'), findsOneWidget);
      expect(confirm(tester).onPressed, isNull, reason: 'nothing selected yet');
      expect(confirm(tester).label, '찰 곳을 골라요');

      await tester.tap(find.byKey(const Key('penalty_button_2')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(confirm(tester).onPressed, isNotNull);
      expect(confirm(tester).label, '슛!');
      expect(
        tester.getSemantics(find.byKey(const Key('penalty_zone_2'))),
        isSemantics(isSelected: true),
        reason: 'the goal zone mirrors the button selection',
      );

      // 골대 칸을 눌러도 같은 선택이 된다.
      await tester.tap(find.byKey(const Key('penalty_zone_0')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.getSemantics(find.byKey(const Key('penalty_button_0'))),
        isSemantics(isSelected: true),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('6 cells as keeper: six zones, 3x2 buttons, confirm says 막기!', (
    tester,
  ) async {
    c.applyState(stateMap(cells: 6, kicker: 'op', keeper: 'me'));
    await pumpScreen(tester);

    for (int i = 0; i < 6; i++) {
      expect(find.byKey(Key('penalty_zone_$i')), findsOneWidget);
      expect(find.byKey(Key('penalty_button_$i')), findsOneWidget);
    }
    // 아래 줄 버튼은 위 줄 버튼보다 아래에 있다.
    expect(
      tester.getCenter(find.byKey(const Key('penalty_button_4'))).dy,
      greaterThan(
        tester.getCenter(find.byKey(const Key('penalty_button_1'))).dy,
      ),
    );
    expect(find.text('가운데 아래'), findsOneWidget);
    expect(find.text('내가 막을 차례! 어디를 막을까요?'), findsOneWidget);
    expect(find.text('승부차기 1번째 · 토끼가 찰 차례'), findsOneWidget);

    await tester.tap(find.byKey(const Key('penalty_zone_4')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(confirm(tester).label, '막기!');
    expect(confirm(tester).onPressed, isNotNull);
    expect(
      tester.getSemantics(find.byKey(const Key('penalty_button_4'))),
      isSemantics(isSelected: true),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('after submitting the controls lock and wait for the opponent', (
    tester,
  ) async {
    c.applyState(stateMap(submissions: {'me': true}));
    await pumpScreen(tester);
    expect(confirm(tester).onPressed, isNull);
    expect(confirm(tester).label, '상대를 기다리는 중…');
    expect(find.text('골랐어요! 상대를 기다리는 중…'), findsOneWidget);

    c.applyState(stateMap(submissions: {'op': true}));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('penalty_opp_ready')), findsOneWidget);
    expect(find.byKey(const Key('penalty_timer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the opponent\'s recent kicks are shown with their favourite spot',
    (tester) async {
      c.applyState(
        stateMap(
          rounds: [
            kick('me', 0, 1),
            kick('op', 2, 0),
            kick('me', 1, 1),
            kick('op', 2, 2),
            kick('me', 2, 0),
            kick('op', 0, 1),
          ],
          kicker: 'me',
        ),
      );
      await pumpScreen(tester);
      expect(find.text('상대 최근 킥'), findsOneWidget);
      for (int i = 0; i < 3; i++) {
        expect(find.byKey(Key('penalty_history_kick_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('penalty_history_kick_3')), findsNothing);
      expect(find.text('자주 찬 곳: 오른쪽'), findsOneWidget);
      // 실명 대신 닉네임, 사용자 코드는 보이지 않는다.
      expect(find.text('토끼'), findsOneWidget);
      expect(find.textContaining('op'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the chosen cell is cleared after each kick, even within the same round',
    (tester) async {
      // The server counts a kick pair as one round, so the second kick keeps the round number.
      c.applyState(stateMap(round: 1));
      await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('penalty_zone_2')));
      await tester.pump();
      expect(confirm(tester).onPressed, isNotNull);
      c.applyState(
        stateMap(
          round: 1,
          rounds: [kick('me', 2, 0)],
          kicker: 'op',
          keeper: 'me',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('penalty_skip')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        confirm(tester).onPressed,
        isNull,
        reason: 'the keeper must choose again',
      );
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('a new kick plays back and can be skipped by tapping', (
    tester,
  ) async {
    c.applyState(stateMap());
    await pumpScreen(tester);
    c.applyState(
      stateMap(rounds: [kick('me', 0, 2)], kicker: 'op', keeper: 'me'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('penalty_skip')), findsOneWidget);
    expect(find.byKey(const Key('penalty_zone_0')), findsNothing);
    // 공이 골대에 닿으면 중계 자막이 뜬다.
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('골!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('penalty_skip')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('penalty_skip')), findsNothing);
    expect(find.text('내가 막을 차례! 어디를 막을까요?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the finished game shows the result overlay with rematch', (
    tester,
  ) async {
    c.applyState(
      stateMap(
        status: 'finished',
        rounds: [kick('me', 0, 1), kick('op', 0, 0)],
        result: {'winner': 'me', 'reason': 'score'},
      ),
    );
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('penalty_result')), findsOneWidget);
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('한 판 더!'), findsOneWidget);

    c.applyState(
      stateMap(
        status: 'finished',
        gameId: 'g2',
        rounds: [kick('me', 0, 0), kick('op', 0, 0)],
        result: {'winner': 'draw', 'reason': 'draw'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('무승부'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the how-to shows once on the first visit and is saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    c.applyState(stateMap());
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('패널티킥 하는 법'), findsOneWidget);
    await tester.tap(find.text('알겠어요'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('패널티킥 하는 법'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('penalty_tutorial_seen'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('패널티킥 하는 법'), findsNothing);

    // 도움말 버튼으로는 언제든 다시 본다.
    await tester.tap(find.byTooltip('규칙 보기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('패널티킥 하는 법'), findsOneWidget);
  });

  for (final cells in [3, 6]) {
    testWidgets('$cells cells fit a 360x640 phone without overflow', (
      tester,
    ) async {
      c.applyState(
        stateMap(
          cells: cells,
          rounds: [
            for (int i = 0; i < 10; i++) kick(i.isEven ? 'me' : 'op', 1, 1),
          ],
        ),
      );
      await pumpScreen(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final pitch = tester.getRect(find.byKey(const Key('penalty_pitch')));
      expect(pitch.height, greaterThan(150));
      expect(pitch.right, lessThanOrEqualTo(360));
    });
  }

  testWidgets('fits a wide desktop window', (tester) async {
    c.applyState(stateMap(cells: 6));
    await pumpScreen(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('penalty_pitch'))).width,
      lessThanOrEqualTo(520),
    );
  });
}
