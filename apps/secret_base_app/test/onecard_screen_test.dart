// 원카드 2.0 화면(티켓 20): 지금 색, 시작 버튼 없음, 360 폭 손패, 외치기/잡기, 기권 문구.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/onecard/onecard_cards.dart';
import 'package:secret_base_app/screens/arcade/games/onecard/onecard_controller.dart';
import 'package:secret_base_app/screens/arcade/games/onecard/onecard_hand.dart';
import 'package:secret_base_app/screens/arcade/games/onecard/onecard_models.dart';
import 'package:secret_base_app/screens/arcade/games/uno_screen.dart';

const me = 'ME-CODE';
const opp = 'OPP-CODE';

Map<String, dynamic> card(String? color, String value, [String suffix = 'a']) =>
    {'id': '${color ?? 'wild'}-$value-$suffix', 'color': color, 'value': value};

List<Map<String, dynamic>> hand(int n) => [
  for (var i = 0; i < n; i++)
    card(
      const ['red', 'yellow', 'green', 'blue'][i % 4],
      '${(i * 3) % 10}',
      'h$i',
    ),
];

Map<String, dynamic> state({
  List<Map<String, dynamic>>? myHand,
  int oppCount = 7,
  String currentPlayer = me,
  Map<String, dynamic>? top,
  String? declaredColor,
  String? unoCallNeeded,
  List<String>? playable,
  int seq = 3,
}) {
  final h = myHand ?? hand(7);
  final topCard = top ?? card('red', '7', 't');
  return {
    'gameId': 'g1',
    'mode': 'go_wild',
    'players': [me, opp],
    'currentPlayer': currentPlayer,
    'topCard': topCard,
    'recentDiscards': [card('blue', '7', 'u'), topCard],
    'declaredColor': declaredColor,
    'currentColor': declaredColor ?? topCard['color'],
    'drawStack': 0,
    'handCount': {me: h.length, opp: oppCount},
    'hand': h,
    'deckCount': 80,
    'unoCallNeeded': unoCallNeeded,
    'drawnCardId': null,
    'playable': playable ?? [h.first['id']],
    'canChallenge': false,
    'turnDeadline': DateTime.now().millisecondsSinceEpoch + 15000,
    'turnMs': 20000,
    'serverNow': DateTime.now().millisecondsSinceEpoch,
    'equippedItems': <String, dynamic>{},
    'stake': 0,
    'series': {
      'wins': {me: 1, opp: 0},
      'draws': 0,
      'games': 1,
    },
    'seq': seq,
    'lastAction': {'type': 'pass', 'by': opp, 'seq': seq},
  };
}

void main() {
  final socket = SocketService();
  final c = OneCardController.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({'onecard_howto_v2_seen': true});
    socket.userId = me;
    socket.presenceNicknames = {me: '준', opp: '하늘'};
    socket.profileEmojis = {me: '🐻', opp: '🐰'};
    socket.lobbyHost = null;
    c.debugReset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 360,
    double height = 760,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: UnoScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets(
    'no start button for anyone; the guest sees the preparing state',
    (tester) async {
      await pumpScreen(tester);
      c.debugReset(syncStatus: 'no_game');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('방장이 판을 준비하는 중…'), findsOneWidget);
      expect(find.textContaining('시작'), findsNothing);
      expect(find.text('다시 불러오기'), findsNothing);
      await settle(tester);
    },
  );

  testWidgets('the host only gets a reload (sync), never a start button', (
    tester,
  ) async {
    socket.lobbyHost = me;
    await pumpScreen(tester);
    c.debugReset(syncStatus: 'no_game');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('방장이 판을 준비하는 중…'), findsOneWidget);
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    await settle(tester);
  });

  testWidgets('current color chip shows the top card color', (tester) async {
    await pumpScreen(tester);
    c.debugApplyState(state(top: card('blue', '4', 't')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('지금 색'), findsOneWidget);
    expect(find.text('스카이'), findsWidgets);
    expect(find.text('하늘'), findsOneWidget, reason: 'nickname, never the code');
    expect(find.textContaining('OPP-CODE'), findsNothing);
    await settle(tester);
  });

  testWidgets('a wild on the pile shows the declared color and is tinted', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(
      state(top: card(null, 'wild', 't'), declaredColor: 'green'),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('세이지'), findsWidgets);
    final tinted = tester
        .widgetList<OneCardFace>(find.byType(OneCardFace))
        .where((f) => f.card.isWild);
    expect(tinted.single.tintColor, 'green');
    await settle(tester);
  });

  for (final (count, h) in [(7, 700.0), (15, 700.0), (20, 640.0)]) {
    testWidgets(
      '360x${h.toInt()} with $count cards: hand fits without overflow',
      (tester) async {
        await pumpScreen(tester, height: h);
        c.debugApplyState(state(myHand: hand(count), oppCount: count));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        for (final face
            in find
                .descendant(
                  of: find.byType(OneCardHandFan),
                  matching: find.byType(OneCardFace),
                )
                .evaluate()) {
          final box = face.renderObject! as RenderBox;
          final corners = [
            Offset.zero,
            box.size.topRight(Offset.zero),
            box.size.bottomLeft(Offset.zero),
            box.size.bottomRight(Offset.zero),
          ].map(box.localToGlobal);
          for (final p in corners) {
            expect(p.dx, inInclusiveRange(0, 360), reason: 'card inside 360px');
          }
        }
        expect(
          find.descendant(
            of: find.byType(OneCardHandFan),
            matching: find.byType(OneCardFace),
          ),
          findsNWidgets(count),
        );
        await settle(tester);
      },
    );
  }

  testWidgets('call and catch are separate buttons with their own states', (
    tester,
  ) async {
    await pumpScreen(tester);
    Semantics semanticsOf(String label) => tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      ),
    );

    c.debugApplyState(state(unoCallNeeded: null));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('원카드!'), findsOneWidget);
    expect(find.text('잡기!'), findsOneWidget);
    expect(semanticsOf('원카드 외치기').properties.enabled, isFalse);
    expect(semanticsOf('원카드를 안 외친 상대 잡기').properties.enabled, isFalse);

    c.debugApplyState(state(myHand: hand(1), unoCallNeeded: me, seq: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(semanticsOf('원카드 외치기').properties.enabled, isTrue);
    expect(semanticsOf('원카드를 안 외친 상대 잡기').properties.enabled, isFalse);

    c.debugApplyState(
      state(oppCount: 1, unoCallNeeded: opp, currentPlayer: me, seq: 5),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(semanticsOf('원카드 외치기').properties.enabled, isFalse);
    expect(semanticsOf('원카드를 안 외친 상대 잡기').properties.enabled, isTrue);
    expect(find.text('1장 남음'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('forfeit result says so, with remaining hands and series', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(state());
    await tester.pump(const Duration(milliseconds: 300));
    c.debugApplyEnded({
      'gameId': 'g1',
      'winner': opp,
      'loser': me,
      'reason': 'forfeit',
      'hands': {me: hand(5), opp: hand(2)},
      'series': {
        'wins': {me: 1, opp: 1},
        'draws': 0,
        'games': 2,
      },
      'stake': 300,
    });
    await settle(tester);
    expect(find.text('기권패'), findsOneWidget);
    expect(find.textContaining('시간 초과가 이어져 기권패'), findsOneWidget);
    expect(find.textContaining('남은 손패'), findsNWidgets(2));
    expect(find.text('판돈 300코인을 잃었어요'), findsOneWidget);
    expect(find.text('한 판 더!'), findsOneWidget);
    expect(find.text('이번 방 전적'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('deal, play, draw, catch and challenge animations run cleanly', (
    tester,
  ) async {
    await pumpScreen(tester, height: 640);
    final dealt = state(seq: 0)..['lastAction'] = {'type': 'deal', 'seq': 0};
    c.debugApplyState(dealt);
    await settle(tester);
    expect(tester.takeException(), isNull);
    final steps = <Map<String, dynamic>>[
      {
        'type': 'play',
        'by': opp,
        'cards': [card(null, 'wild_draw4', 'x')],
        'effect': 'draw4',
        'declaredColor': 'yellow',
        'colorChanged': true,
      },
      {
        'type': 'draw',
        'by': me,
        'count': 4,
        'penalty': true,
        'cardIds': ['red-0-h0'],
      },
      {
        'type': 'play',
        'by': me,
        'cards': [card('red', 'skip', 's'), card('red', 'discard_all', 'd')],
        'effect': 'discard_all',
      },
      {'type': 'call', 'by': opp},
      {'type': 'catch', 'by': me, 'target': opp, 'count': 2},
      {
        'type': 'challenge',
        'by': me,
        'success': false,
        'drawnPlayer': me,
        'drawnCount': 6,
      },
      {'type': 'draw', 'by': opp, 'count': 1, 'auto': true},
    ];
    for (var i = 0; i < steps.length; i++) {
      final next = state(seq: i + 1, declaredColor: 'yellow');
      next['lastAction'] = {...steps[i], 'seq': i + 1};
      c.debugApplyState(next);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: steps[i]['type']);
    }
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  test('card faces use symbols and Korean only', () {
    for (final v in [
      'skip',
      'reverse',
      'draw2',
      'wild_draw4',
      'wild',
      'discard_all',
    ]) {
      final c = OneCard(
        id: v,
        color: v.startsWith('wild') ? null : 'red',
        value: v,
      );
      expect(RegExp(r'[A-Za-z]').hasMatch(c.symbol), isFalse, reason: v);
      expect(RegExp(r'[A-Za-z]').hasMatch(c.label), isFalse, reason: v);
    }
  });
}
