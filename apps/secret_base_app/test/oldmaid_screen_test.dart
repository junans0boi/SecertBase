// 도둑잡기 2.0 화면: 360px 한 화면, 뽑은 쪽/뺏긴 쪽 문구, 조커, 결과.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/oldmaid/oldmaid_controller.dart';
import 'package:secret_base_app/screens/arcade/games/oldmaid_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const me = 'ME-code';
const opp = 'OPP-code';
const ranks = [
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];
const suits = ['♠', '♥', '♦', '♣'];

Map<String, dynamic> card(String id, String rank, [String suit = '♠']) => {
  'id': id,
  'rank': rank,
  'suit': suit,
  'isJoker': rank == 'JOKER',
};

List<Map<String, dynamic>> hand(int n, {bool joker = false}) => [
  for (var i = 0; i < n - (joker ? 1 : 0); i++)
    card('c$i', ranks[i % 13], suits[(i ~/ 13) % 4]),
  if (joker) card('card_joker', 'JOKER', '🃏'),
];

Map<String, dynamic> state({
  List<Map<String, dynamic>>? mine,
  int oppCount = 10,
  String turn = me,
  String status = 'playing',
  String gameId = 'g1',
  Map<String, dynamic>? result,
  List<String> discards = const ['3', 'Q'],
  List<Map<String, dynamic>> log = const [],
  int drawCount = 4,
}) {
  final my = mine ?? hand(9);
  return {
    'gameId': gameId,
    'status': status,
    'players': [me, opp],
    'turn': status == 'playing' ? turn : null,
    'firstTurn': me,
    'hands': {
      me: my,
      opp: status == 'finished'
          ? [card('card_joker', 'JOKER', '🃏')]
          : [
              for (var i = 0; i < oppCount; i++) {'id': 'slot-$i'},
            ],
    },
    'handCounts': {me: my.length, opp: oppCount},
    'discards': discards,
    'discardedPairsCount': discards.length,
    'log': log,
    'drawCount': drawCount,
    'timeouts': {me: 0, opp: 0},
    'result': result,
    'series': {
      'wins': {me: 1, opp: 0},
      'draws': 0,
      'games': 1,
    },
    'turnDeadline': status == 'playing'
        ? DateTime.now().millisecondsSinceEpoch + 20000
        : null,
    'turnMs': 25000,
    'serverNow': DateTime.now().millisecondsSinceEpoch,
  };
}

Map<String, dynamic> drawn({
  required String role,
  required Map<String, dynamic> card,
  bool paired = false,
  Map<String, dynamic>? matched,
  bool auto = false,
  int slot = 2,
}) => {
  'gameId': 'g1',
  'role': role,
  'by': role == 'drawer' ? me : opp,
  'from': role == 'drawer' ? opp : me,
  'slot': slot,
  'card': card,
  'matched': matched,
  'paired': paired,
  'pairedRank': paired ? card['rank'] : null,
  'jokerMoved': card['rank'] == 'JOKER',
  'auto': auto,
  'handSize': 8,
  'drawCount': 5,
  'finished': false,
  'at': 1,
};

void main() {
  final c = OldMaidController.instance;
  final socket = SocketService();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'howto_oldmaid_v2': true,
      'game_sfx_muted': true,
    });
    socket.userId = me;
    socket.presenceNicknames = {opp: '민지'};
    socket.profileEmojis = {me: '🐰', opp: '🦊'};
    socket.restartWaiting = false;
    c.resetForTest();
  });

  tearDown(() {
    c.resetForTest();
    socket.userId = null;
    socket.presenceNicknames = {};
    socket.profileEmojis = {};
    socket.restartWaiting = false;
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(360, 740),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: OldMaidScreen()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 연출(나눠 주기·뽑기)을 끝까지 돌린다. 반복 애니메이션(찻잔 김) 때문에 settle은 쓰지 않는다.
  Future<void> run(WidgetTester tester, [int ms = 2400]) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  testWidgets('shows the preparing state until the server sends the game', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('판을 준비하는 중…'), findsOneWidget);
    expect(find.text('시작'), findsNothing);
  });

  for (final n in [15, 20]) {
    testWidgets('fits 360x740 on one screen with $n cards in my hand', (
      tester,
    ) async {
      await open(tester);
      c.handleState(state(mine: hand(n, joker: true), oppCount: n - 1));
      await run(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      // 내 손패: 랭크순, 조커 맨 오른쪽, 모두 화면 안.
      final sorted = OldMaidController.sortHand(c.myHand);
      expect(sorted.last.isJoker, isTrue);
      final first = rectOf(tester, 'om-my-${sorted.first.id}');
      final last = rectOf(tester, 'om-my-${sorted.last.id}');
      expect(first.left, greaterThanOrEqualTo(0));
      expect(last.right, lessThanOrEqualTo(360));
      expect(last.bottom, lessThanOrEqualTo(740));
      expect(last.left, greaterThan(first.left));
      // 상대 부채꼴도 한 줄.
      final o0 = rectOf(tester, 'om-opp-0');
      final oLast = rectOf(tester, 'om-opp-${n - 2}');
      expect(o0.left, greaterThanOrEqualTo(0));
      expect(oLast.right, lessThanOrEqualTo(360));
      expect(o0.bottom, lessThan(first.top), reason: '상대 손이 내 손 위에 있다');
      expect(find.text('카드 $n장'), findsOneWidget);
      expect(find.text('2쌍'), findsOneWidget);
      expect(find.textContaining('code'), findsNothing, reason: '사용자 코드 노출 금지');
    });
  }

  testWidgets('tap picks a card, then the confirm button appears', (
    tester,
  ) async {
    await open(tester);
    c.handleState(state(oppCount: 8));
    await run(tester);
    expect(find.text('상대 카드 한 장을 골라요'), findsOneWidget);
    expect(find.text('이 카드 뽑기'), findsNothing);
    await tester.tapAt(rectOf(tester, 'om-opp-3').center);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('이 카드 뽑기'), findsOneWidget);
    expect(find.text('한 번 더 누르거나 아래 버튼으로 뽑아요'), findsOneWidget);
  });

  testWidgets(
    'drawer sees the drawn card and the pair; never the victim text',
    (tester) async {
      await open(tester);
      c.handleState(state(mine: [card('m7', '7', '♦'), card('mk', 'K')]));
      await run(tester);
      c.handleDrawn(
        drawn(
          role: 'drawer',
          card: card('x7', '7', '♥'),
          paired: true,
          matched: card('m7', '7', '♦'),
        ),
      );
      c.handleState(
        state(
          mine: [card('mk', 'K')],
          turn: opp,
          oppCount: 9,
          discards: ['3', 'Q', '7'],
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('하트 7을 뽑았어요 · 7 짝!'), findsOneWidget);
      expect(find.textContaining('뺏겼어요'), findsNothing);
      expect(find.byKey(const ValueKey('om-fx-matched')), findsOneWidget);
      await run(tester);
      expect(find.text('3쌍'), findsOneWidget);
      expect(find.byKey(const ValueKey('om-fx-drawn')), findsNothing);
      expect(find.text('민지가 내 카드를 고르는 중…'), findsOneWidget);
    },
  );

  testWidgets('drawer without a pair gets the card into the hand with NEW', (
    tester,
  ) async {
    await open(tester);
    c.handleState(state(mine: [card('m2', '2')]));
    await run(tester);
    c.handleDrawn(drawn(role: 'drawer', card: card('xk', 'K', '♣')));
    c.handleState(
      state(
        mine: [card('m2', '2'), card('xk', 'K', '♣')],
        turn: opp,
        oppCount: 9,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('클로버 K를 뽑았어요'), findsOneWidget);
    // 날아오는 동안 손패에는 아직 없다.
    expect(find.byKey(const ValueKey('om-my-xk')), findsNothing);
    await run(tester);
    expect(find.byKey(const ValueKey('om-my-xk')), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
  });

  testWidgets('victim sees which own card was taken, not a pair message', (
    tester,
  ) async {
    await open(tester);
    c.handleState(
      state(mine: [card('m7', '7', '♥'), card('m9', '9')], turn: opp),
    );
    await run(tester);
    c.handleDrawn(
      drawn(role: 'victim', card: card('m7', '7', '♥'), paired: true),
    );
    c.handleState(state(mine: [card('m9', '9')], turn: me, oppCount: 9));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('하트 7을 뺏겼어요 · 민지가 짝을 맞췄어요'), findsOneWidget);
    expect(find.textContaining('뽑았어요'), findsNothing);
    expect(find.byKey(const ValueKey('om-fx-taken')), findsOneWidget);
    await run(tester);
    expect(find.byKey(const ValueKey('om-my-m7')), findsNothing);

    c.handleDrawn(drawn(role: 'victim', card: card('m9', '9')));
    c.handleState(state(mine: const [], turn: me, oppCount: 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('스페이드 9를 뺏겼어요'), findsOneWidget);
    await run(tester);
  });

  testWidgets(
    'drawing the joker grins with a warning, passing it is a relief',
    (tester) async {
      await open(tester);
      c.handleState(state(mine: [card('m2', '2')]));
      await run(tester);
      c.handleDrawn(
        drawn(role: 'drawer', card: card('card_joker', 'JOKER', '🃏')),
      );
      c.handleState(
        state(
          mine: [card('m2', '2'), card('card_joker', 'JOKER', '🃏')],
          turn: opp,
          oppCount: 9,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('앗, 조커를 뽑았어요!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('조커!'), findsOneWidget);
      await run(tester);
      expect(find.byKey(const ValueKey('om-my-card_joker')), findsOneWidget);
      expect(tester.takeException(), isNull);

      c.handleDrawn(
        drawn(role: 'victim', card: card('card_joker', 'JOKER', '🃏')),
      );
      c.handleState(state(mine: [card('m2', '2')], turn: me, oppCount: 10));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('조커를 민지에게 넘겼어요!'), findsOneWidget);
      await run(tester);
    },
  );

  testWidgets('auto draws say the timer chose the card', (tester) async {
    await open(tester);
    c.handleState(state(mine: [card('m2', '2')]));
    await run(tester);
    c.handleDrawn(
      drawn(role: 'drawer', card: card('x4', '4', '♦'), auto: true),
    );
    c.handleState(
      state(mine: [card('m2', '2'), card('x4', '4', '♦')], turn: opp),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('시간이 다 돼서 다이아 4를 뽑았어요'), findsOneWidget);
    await run(tester);
  });

  testWidgets('result overlay: win, series and a consented rematch', (
    tester,
  ) async {
    await open(tester);
    c.handleState(
      state(
        status: 'finished',
        mine: const [],
        oppCount: 1,
        result: {'winner': me, 'loser': opp, 'reason': 'joker'},
      ),
    );
    await run(tester, 1200);
    expect(find.text('조커를 피했어요!'), findsOneWidget);
    expect(find.text('마지막 조커는 민지에게 남았어요'), findsOneWidget);
    expect(find.text('이번 방 전적'), findsOneWidget);
    expect(find.text('조커: 민지'), findsOneWidget);
    await tester.tap(find.text('한 판 더!'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(socket.restartWaiting, isTrue);
    expect(find.text('상대의 수락을 기다리는 중…'), findsOneWidget);

    // 재대결이 성사되면 새 판이 오고 결과가 사라진다.
    c.handleState(state(gameId: 'g2', drawCount: 0));
    await run(tester);
    expect(socket.restartWaiting, isFalse);
    expect(find.text('조커를 피했어요!'), findsNothing);
  });

  testWidgets('result overlay: losing with the joker', (tester) async {
    await open(tester);
    c.handleState(
      state(
        status: 'finished',
        mine: [card('card_joker', 'JOKER', '🃏')],
        oppCount: 0,
        result: {'winner': opp, 'loser': me, 'reason': 'joker'},
      ),
    );
    await run(tester, 1200);
    expect(find.text('조커가 내 손에…'), findsOneWidget);
    expect(find.text('마지막까지 조커를 들고 있었어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('controller sorts by rank with the joker last and words particles', () {
    final sorted = OldMaidController.sortHand([
      const OldMaidCard(id: 'j', rank: 'JOKER', suit: '🃏', isJoker: true),
      const OldMaidCard(id: 'k', rank: 'K', suit: '♠'),
      const OldMaidCard(id: 'a', rank: 'A', suit: '♥'),
      const OldMaidCard(id: '10', rank: '10', suit: '♦'),
      const OldMaidCard(id: '2', rank: '2', suit: '♣'),
    ]);
    expect(sorted.map((c) => c.id), ['a', '2', '10', 'k', 'j']);
    expect(sorted[2].labelObject, '다이아 10을');
    expect(sorted[3].labelObject, '스페이드 K를');
    expect(sorted.last.labelObject, '조커를');
  });
}
