// 블랙잭 2.0 화면: 휴대폰 폭(360)·데스크톱에서 넘치지 않고, 내 차례에만 조작할 수 있으며,
// 라운드 결과와 최종 결과가 뜨고, 게임 안에 시작 버튼이 없다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/blackjack/blackjack_controller.dart';
import 'package:secret_base_app/screens/arcade/games/blackjack/blackjack_game_screen.dart';
import 'package:secret_base_app/screens/arcade/games/blackjack/blackjack_rules.dart';
import 'package:secret_base_app/widgets/play_kit/play_kit.dart';

const me = 'ME-CODE-1';
const opp = 'OPP-CODE-2';

Map<String, dynamic> c(String rank, [String suit = '♠']) => {
  'rank': rank,
  'suit': suit,
};

Map<String, dynamic> state({
  String phase = 'player_turn',
  String status = 'playing',
  String? currentTurn = me,
  List<Map<String, dynamic>>? myHand,
  List<Map<String, dynamic>>? oppHand,
  Map<String, int> wins = const {me: 0, opp: 0},
  int round = 1,
  Map<String, String>? statuses,
  Map<String, dynamic>? lastRoundResult,
  Map<String, dynamic>? result,
  Map<String, bool> ready = const {me: false, opp: false},
  String gameId = 'g-1',
}) {
  final mine = myHand ?? [c('10'), c('7', '♥')];
  final theirs =
      oppHand ??
      [
        c('K', '♦'),
        {'hidden': true},
      ];
  final reveal = phase != 'player_turn';
  return {
    'gameId': gameId,
    'status': status,
    'phase': phase,
    'players': [me, opp],
    'round': round,
    'maxRounds': 5,
    'winsNeeded': 2,
    'wins': wins,
    'firstPlayer': me,
    'currentTurn': phase == 'player_turn' ? currentTurn : null,
    'turnDeadline': phase == 'player_turn' ? 2_000_030_000 : null,
    'turnMs': 30000,
    'serverNow': 2_000_000_000,
    'hands': {me: mine, opp: theirs},
    'statuses': statuses ?? {me: 'playing', opp: 'playing'},
    'scores': {
      me: blackjackScore(mine),
      if (reveal) opp: blackjackScore(theirs),
    },
    'visibleScores': {
      me: blackjackScore([mine.first, ...mine.skip(2)]),
      opp: blackjackScore([theirs.first, ...theirs.skip(2)]),
    },
    'timeouts': {me: 0, opp: 0},
    'ready': ready,
    'rounds': [
      if (lastRoundResult != null)
        {
          'round': lastRoundResult['round'],
          'winner': lastRoundResult['winner'],
          'reason': lastRoundResult['reason'],
          'scores': {me: 20, opp: 18},
        },
    ],
    'lastRoundResult': lastRoundResult,
    'result': result,
    'series': {
      'wins': {me: 3, opp: 1},
      'draws': 1,
      'games': 5,
    },
  };
}

void main() {
  setUpAll(
    () => SharedPreferences.setMockInitialValues({'how_to_blackjack_v2': true}),
  );

  final controller = BlackjackController.instance;

  setUp(() {
    final socket = SocketService();
    socket.userId = me;
    socket.presenceNicknames = {opp: '단비'};
    socket.profileEmojis = {me: '🐻', opp: '🐰'};
    controller.debugClear();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(360, 740),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: BlackjackGameScreen(autoSync: false, showHowTo: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  GamePrimaryButton primary(WidgetTester tester, String label) => tester
      .widget<GamePrimaryButton>(find.widgetWithText(GamePrimaryButton, label));

  GameSecondaryButton secondary(WidgetTester tester, String label) =>
      tester.widget<GameSecondaryButton>(
        find.widgetWithText(GameSecondaryButton, label),
      );

  for (final size in const [
    Size(360, 640),
    Size(360, 740),
    Size(430, 932),
    Size(1280, 800),
  ]) {
    testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} without '
        'overflow on my turn', (tester) async {
      controller.apply(
        state(
          myHand: [c('10'), c('2', '♥'), c('3', '♣'), c('A', '♦'), c('2')],
          oppHand: [
            c('5', '♦'),
            {'hidden': true},
            c('2'),
            c('3', '♥'),
          ],
        ),
      );
      await pumpScreen(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('히트'), findsOneWidget);
      expect(find.text('스탠드'), findsOneWidget);
      expect(find.text('10+?'), findsOneWidget, reason: '공개 합 + ?');
      await finish(tester);
    });
  }

  testWidgets('hit and stand are enabled only on my turn', (tester) async {
    controller.apply(state(currentTurn: me));
    await pumpScreen(tester);
    expect(primary(tester, '히트').onPressed, isNotNull);
    expect(secondary(tester, '스탠드').onPressed, isNotNull);
    expect(find.text('내 차례 — 히트 또는 스탠드'), findsOneWidget);
    expect(find.byType(TurnTimerRing), findsOneWidget);

    controller.apply(state(currentTurn: opp));
    await tester.pump(const Duration(milliseconds: 300));
    expect(primary(tester, '히트').onPressed, isNull);
    expect(secondary(tester, '스탠드').onPressed, isNull);
    expect(find.text('단비님이 고르는 중…'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('on 21 only stand is allowed', (tester) async {
    controller.apply(state(myHand: [c('10'), c('5'), c('6')]));
    await pumpScreen(tester);
    expect(primary(tester, '히트').onPressed, isNull);
    expect(secondary(tester, '스탠드').onPressed, isNotNull);
    expect(find.text('21! 스탠드로 지켜요'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('no in-game start button and no raw user codes on screen', (
    tester,
  ) async {
    controller.apply(state());
    await pumpScreen(tester);
    expect(find.textContaining('시작'), findsNothing);
    expect(find.textContaining('CODE'), findsNothing);
    expect(find.text('단비'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('shows a preparing state until the server state arrives', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.text('판을 준비하는 중…'), findsOneWidget);
    expect(find.text('히트'), findsNothing);
    await finish(tester);
  });

  testWidgets('round result reveals the hole card, then the ready panel', (
    tester,
  ) async {
    controller.apply(state(currentTurn: opp));
    await pumpScreen(tester);
    controller.apply(
      state(
        phase: 'round_result',
        oppHand: [c('K', '♦'), c('8', '♣')],
        myHand: [c('10'), c('Q', '♥')],
        statuses: {me: 'stand', opp: 'stand'},
        wins: {me: 1, opp: 0},
        lastRoundResult: {'round': 1, 'winner': me, 'reason': 'score'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('이번 라운드 승리!'), findsNothing, reason: '공개 연출 먼저');
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('이번 라운드 승리!'), findsOneWidget);
    expect(find.text('다음 라운드'), findsOneWidget);
    expect(primary(tester, '다음 라운드').onPressed, isNotNull);
    expect(find.text('18'), findsOneWidget, reason: '상대 합 공개');
    expect(find.text('히트'), findsNothing);
    expect(tester.takeException(), isNull);

    controller.apply(
      state(
        phase: 'round_result',
        oppHand: [c('K', '♦'), c('8', '♣')],
        myHand: [c('10'), c('Q', '♥')],
        statuses: {me: 'stand', opp: 'stand'},
        wins: {me: 1, opp: 0},
        lastRoundResult: {'round': 1, 'winner': me, 'reason': 'score'},
        ready: {me: true, opp: false},
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('상대를 기다리는 중…'), findsOneWidget);
    expect(primary(tester, '상대를 기다리는 중…').onPressed, isNull);
    await finish(tester);
  });

  testWidgets('final result overlay shows series and a rematch button', (
    tester,
  ) async {
    controller.apply(state(currentTurn: opp, round: 3));
    await pumpScreen(tester);
    controller.apply(
      state(
        phase: 'finished',
        status: 'finished',
        round: 3,
        oppHand: [c('K', '♦'), c('6', '♣'), c('9')],
        statuses: {me: 'stand', opp: 'bust'},
        wins: {me: 2, opp: 1},
        lastRoundResult: {'round': 3, 'winner': me, 'reason': 'bust'},
        result: {'winner': me, 'loser': opp, 'reason': 'wins'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameResultOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.byType(GameResultOverlay), findsOneWidget);
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('한 판 더!'), findsOneWidget);
    expect(find.text('이번 방 전적'), findsOneWidget);
    expect(find.text('라운드 2 : 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('a forfeit shows the result at once', (tester) async {
    controller.apply(
      state(
        phase: 'finished',
        status: 'finished',
        oppHand: [c('K', '♦'), c('6', '♣')],
        result: {'winner': opp, 'loser': me, 'reason': 'timeout'},
      ),
    );
    await pumpScreen(tester);
    expect(find.byType(GameResultOverlay), findsOneWidget);
    expect(find.text('시간을 세 번 넘겨 기권했어요'), findsOneWidget);
    await finish(tester);
  });

  test('score helper matches the server rules', () {
    expect(blackjackScore([c('A'), c('K')]), 21);
    expect(blackjackScore([c('A'), c('A'), c('9')]), 21);
    expect(
      blackjackScore([
        c('K'),
        {'hidden': true},
      ]),
      10,
    );
    expect(isNaturalBlackjack([c('A'), c('Q')]), isTrue);
    expect(isNaturalBlackjack([c('7'), c('7'), c('7')]), isFalse);
  });
}
