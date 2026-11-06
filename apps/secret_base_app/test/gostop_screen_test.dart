// 고스톱 2.0 화면(티켓 24): 360·430 폭 넘침 없음, 손패 10장, 들고 확정, 고/스톱 패널,
// 두 장 선택, 총통, 딴 패 묶음·뻑 도장, 점수판, 정산 영수증(합계 = 실제 코인).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/gostop/gostop_controller.dart';
import 'package:secret_base_app/screens/arcade/games/gostop/gostop_card.dart';
import 'package:secret_base_app/screens/arcade/games/gostop/gostop_models.dart';
import 'package:secret_base_app/screens/arcade/games/gostop_screen.dart';

const me = 'ME-CODE';
const opp = 'OPP-CODE';

Map<String, dynamic> card(
  String id,
  int month,
  String type, [
  String? subtype,
]) => {'id': id, 'month': month, 'type': type, 'subtype': subtype};

final hand10 = [
  card('m1_bright', 1, 'bright'),
  card('m2_animal', 2, 'animal'),
  card('m3_ribbon', 3, 'ribbon', 'red'),
  card('m4_junk_1', 4, 'junk'),
  card('m5_junk_1', 5, 'junk'),
  card('m6_animal', 6, 'animal'),
  card('m7_junk_1', 7, 'junk'),
  card('m8_junk_1', 8, 'junk'),
  card('m9_ribbon', 9, 'ribbon', 'blue'),
  card('m11_junk_d', 11, 'junk', 'double'),
];

Map<String, dynamic> score(int total, {int gwang = 0, int pi = 0}) => {
  'total': total,
  'gwangCount': gwang,
  'animCount': 0,
  'ribCount': 0,
  'piTotal': pi,
  'gwangScore': gwang >= 3 ? 3 : 0,
};

Map<String, dynamic> projection({
  int base = 0,
  int go = 0,
  List<Map<String, dynamic>> mult = const [],
  int amount = 0,
}) {
  final m = mult.fold<int>(1, (a, x) => a * (x['factor'] as int));
  return {
    'points': {'base': base, 'go': go, 'total': base + go},
    'multipliers': mult,
    'multiplier': m,
    'amount': amount,
  };
}

Map<String, dynamic> state({
  String phase = 'playing',
  String current = me,
  List<Map<String, dynamic>>? hand,
  List<Map<String, dynamic>>? field,
  Map<String, dynamic>? ppeok,
  Map<String, List<Map<String, dynamic>>>? captures,
  Map<String, dynamic>? scores,
  Map<String, dynamic>? projections,
  Map<String, dynamic>? goPreview,
  Map<String, dynamic>? pending,
  Map<String, dynamic>? chongtong,
  List<int> shakeable = const [],
  List<int> bombable = const [],
  Map<String, dynamic>? coach,
  Map<String, dynamic>? goCount,
  int perPointBet = 100,
  int seq = 1,
  String gameId = 'g1',
  Map<String, dynamic>? lastTurn,
}) {
  final h = hand ?? hand10;
  return {
    'version': 2,
    'gameId': gameId,
    'seq': seq,
    'turn': 1,
    'phase': phase,
    'players': [me, opp],
    'starter': me,
    'current': current,
    'perPointBet': perPointBet,
    'hand': h,
    'handCount': {me: h.length, opp: 10},
    'deckCount': 20,
    'field':
        field ??
        [
          card('m4_junk_2', 4, 'junk'),
          card('m5_animal', 5, 'animal'),
          card('m8_bright', 8, 'bright'),
          card('m12_junk_d', 12, 'junk', 'double'),
        ],
    'captures':
        captures ??
        {
          me: [card('m1_animal', 1, 'ribbon', 'red')],
          opp: [
            card('m3_bright', 3, 'bright'),
            card('m11_bright', 11, 'bright'),
            card('m1_junk_1', 1, 'junk'),
            card('m2_junk_1', 2, 'junk'),
            card('m11_junk_d', 11, 'junk', 'double'),
          ],
        },
    'scores': scores ?? {me: score(0), opp: score(0, gwang: 2, pi: 3)},
    'dotan': {me: 0, opp: 0},
    'goCount': goCount ?? {me: 0, opp: 0},
    'goScore': {me: 0, opp: 0},
    'shakes': {me: <int>[], opp: <int>[]},
    'bombs': {me: 0, opp: 0},
    'ppeok': ppeok ?? <String, dynamic>{},
    'pending': pending,
    'chongtong': chongtong,
    'redeals': <String>[],
    'lastTurn': lastTurn ?? {'kind': 'deal', 'seq': seq, 'events': <String>[]},
    'moves': phase == 'playing' && current == me
        ? {'shakeable': shakeable, 'bombable': bombable, 'dotan': 0}
        : null,
    'coach':
        coach ??
        (phase == 'playing' && current == me
            ? {'type': 'play', 'cardId': 'm1_bright'}
            : null),
    'projection': projections ?? {me: projection(), opp: projection()},
    'goPreview': goPreview,
    'result': null,
    'turnDeadline': DateTime.now().millisecondsSinceEpoch + 20000,
    'turnMs': 25000,
    'serverNow': DateTime.now().millisecondsSinceEpoch,
    'autoStreak': <String, dynamic>{},
    'series': {
      'wins': {me: 1, opp: 0},
      'draws': 0,
      'games': 1,
    },
  };
}

void main() {
  final socket = SocketService();
  final c = GostopController.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({'gostop_howto_v2_seen': true});
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
    await tester.pumpWidget(const MaterialApp(home: GostopScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester, {int ms = 4000}) async {
    for (var i = 0; i < ms / 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('no start button; the guest sees the preparing state', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugReset(syncStatus: 'no_game');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('판을 준비하는 중…'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    expect(find.text('다시 불러오기'), findsNothing);
    await settle(tester, ms: 8000);
  });

  testWidgets('the host only gets a reload, never a start button', (
    tester,
  ) async {
    socket.lobbyHost = me;
    await pumpScreen(tester);
    c.debugReset(syncStatus: 'no_game');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    await settle(tester, ms: 8000);
  });

  for (final size in [
    const Size(360, 760),
    const Size(430, 900),
    const Size(360, 640),
    const Size(1000, 800),
  ]) {
    testWidgets(
      'table fits ${size.width.toInt()}x${size.height.toInt()} with a full 10-card hand',
      (tester) async {
        await pumpScreen(tester, width: size.width, height: size.height);
        c.debugApplyState(
          state(
            ppeok: {'3': me},
            field: [
              card('m3_junk_1', 3, 'junk'),
              card('m3_ribbon', 3, 'ribbon', 'red'),
              card('m3_junk_2', 3, 'junk'),
              card('m8_bright', 8, 'bright'),
              card('m4_junk_2', 4, 'junk'),
              card('m4_animal', 4, 'animal'),
            ],
            scores: {me: score(7, gwang: 3), opp: score(0, gwang: 2, pi: 5)},
            projections: {
              me: projection(
                base: 3,
                mult: [
                  {'code': 'gwangbak', 'count': 1, 'factor': 2},
                ],
                amount: 600,
              ),
              opp: projection(),
            },
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is GostopCard &&
                w.width == GostopCardSize.hand.width &&
                w.card != null,
          ),
          findsNWidgets(10),
        );
        expect(find.text('뻑'), findsOneWidget);
        expect(find.text('하늘'), findsWidgets, reason: '닉네임, 코드가 아님');
        expect(find.textContaining('OPP-CODE'), findsNothing);
        expect(find.textContaining('ME-CODE'), findsNothing);
        expect(find.text('×2'), findsWidgets);
        expect(find.text('지금 스톱 +600코인'), findsOneWidget);
      },
    );
  }

  testWidgets('captures are grouped 광/열끗/띠/피 with counts; 쌍피 counts as two', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(state());
    await settle(tester);
    expect(find.text('광 2'), findsOneWidget);
    expect(find.text('피 4'), findsOneWidget, reason: '1 + 1 + 쌍피 2');
    expect(find.text('띠 1'), findsOneWidget);
    expect(find.text('열끗 0'), findsWidgets);
    expect(find.text('홍단 2장 남음'), findsOneWidget);
  });

  testWidgets(
    'lift then confirm: the first tap lifts, the label changes, the second tap plays',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(state());
      await settle(tester);
      expect(find.text('패를 눌러 들어 보세요'), findsOneWidget);
      final cards = find.byWidgetPredicate(
        (w) =>
            w is GostopCard &&
            w.width == GostopCardSize.hand.width &&
            w.card?.id == 'm4_junk_1',
      );
      await tester.tap(cards.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('4월 패 내기'), findsOneWidget);
      await tester.tap(cards.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text('패를 눌러 들어 보세요'),
        findsOneWidget,
        reason: 'played → selection cleared',
      );
    },
  );

  testWidgets(
    'a three-of-a-month card offers the 흔들기 toggle, a bomb month offers 폭탄',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(state(shakeable: [4], bombable: [5]));
      await settle(tester);
      expect(find.text('5월 폭탄'), findsOneWidget);
      final card4 = find.byWidgetPredicate(
        (w) =>
            w is GostopCard &&
            w.width == GostopCardSize.hand.width &&
            w.card?.id == 'm4_junk_1',
      );
      await tester.tap(card4.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('4월 흔들기 ×2'), findsOneWidget);
    },
  );

  testWidgets(
    'go/stop panel: full screen, now vs after go, opponent threat, no engine text',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(
        state(
          phase: 'go_stop',
          scores: {me: score(8, gwang: 3), opp: score(2, gwang: 2, pi: 6)},
          goCount: {me: 1, opp: 0},
          goPreview: {
            'stopNow': projection(
              base: 8,
              go: 1,
              mult: [
                {'code': 'gwangbak', 'count': 1, 'factor': 2},
              ],
              amount: 1800,
            ),
            'afterGo': projection(
              base: 9,
              go: 2,
              mult: [
                {'code': 'gwangbak', 'count': 1, 'factor': 2},
              ],
              amount: 2200,
            ),
          },
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('go-stop-panel')), findsOneWidget);
      expect(find.text('고 할까요, 스톱 할까요?'), findsOneWidget);
      expect(find.text('1,800코인'), findsOneWidget);
      expect(find.text('2,200코인 ↑'), findsOneWidget);
      expect(find.text('2고 하면'), findsOneWidget);
      expect(find.textContaining('고박'), findsOneWidget);
      expect(find.text('스톱'), findsOneWidget);
      expect(find.text('고!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('go/stop panel fits 360x640', (tester) async {
    await pumpScreen(tester, height: 640);
    c.debugApplyState(
      state(
        phase: 'go_stop',
        scores: {me: score(8, gwang: 3), opp: score(2, gwang: 2, pi: 6)},
        goPreview: {
          'stopNow': projection(base: 8, go: 0, amount: 800),
          'afterGo': projection(base: 9, go: 1, amount: 1000),
        },
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('go-stop-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the opponent deciding go/stop shows no panel for me', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(state(phase: 'go_stop', current: opp));
    await settle(tester);
    expect(find.byKey(const ValueKey('go-stop-panel')), findsNothing);
    expect(find.textContaining('고/스톱을 고르는 중'), findsOneWidget);
  });

  testWidgets(
    'two-match choice sheet shows both field cards and the card being played',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(
        state(
          phase: 'choice',
          field: [card('m8_bright', 8, 'bright'), card('m8_junk_1', 8, 'junk')],
          pending: {
            'kind': 'hand',
            'card': card('m8_junk_2', 8, 'junk'),
            'options': [
              card('m8_bright', 8, 'bright'),
              card('m8_junk_1', 8, 'junk'),
            ],
          },
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('choice-panel')), findsOneWidget);
      expect(find.text('가져올 패를 고르세요'), findsOneWidget);
      expect(find.text('광'), findsWidgets);
      expect(find.text('내는 패'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('총통 panel is private to its holder and declinable', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(
      state(
        phase: 'chongtong',
        hand: [
          card('m5_animal', 5, 'animal'),
          card('m5_ribbon', 5, 'ribbon'),
          card('m5_junk_1', 5, 'junk'),
          card('m5_junk_2', 5, 'junk'),
          ...hand10.where((h) => h['month'] != 5).take(6),
        ],
        chongtong: {'player': me, 'month': 5},
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('chongtong-panel')), findsOneWidget);
    expect(find.text('총통 선언! (10점)'), findsOneWidget);
    expect(find.text('그냥 치기'), findsOneWidget);
    expect(find.textContaining('+1,000코인'), findsOneWidget);
  });

  testWidgets(
    'settlement receipt: breakdown multiplies out and the total equals the coins that moved',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(state(phase: 'finished', current: me));
      c.debugApplyEnded({
        'gameId': 'g1',
        'reason': 'stop',
        'winner': me,
        'loser': opp,
        'receipt': {
          'reason': 'stop',
          'winner': me,
          'loser': opp,
          'points': {'base': 7, 'go': 2, 'total': 9},
          'multipliers': [
            {'code': 'pibak', 'count': 1, 'factor': 2},
            {'code': 'gwangbak', 'count': 1, 'factor': 2},
          ],
          'multiplier': 4,
          'perPointBet': 100,
          'amount': 3600,
          'transferred': 3600,
          'settlement': 'settled',
          'winnerScore': {
            'total': 7,
            'gwangCount': 3,
            'gwangScore': 3,
            'piTotal': 0,
            'animScore': 0,
            'ribScore': 0,
          },
          'loserScore': {'total': 0},
        },
        'captures': {me: <dynamic>[], opp: <dynamic>[]},
        'series': {
          'wins': {me: 1, opp: 0},
          'draws': 0,
          'games': 1,
        },
      });
      await settle(tester, ms: 6000);
      expect(find.byKey(const ValueKey('receipt')), findsOneWidget);
      expect(find.text('9점'), findsOneWidget);
      expect(find.text('×4'), findsWidgets);
      expect(find.text('9점 × 4 × 100'), findsOneWidget);
      expect(find.text('3,600코인'), findsOneWidget);
      expect(
        find.text('+3,600코인'),
        findsOneWidget,
        reason: 'the real transfer',
      );
      expect(find.text('피박'), findsOneWidget);
      expect(find.text('광박'), findsOneWidget);
      expect(find.textContaining('OPP-CODE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a capped settlement explains why fewer coins moved; losers see a minus',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(state(phase: 'finished', current: opp));
      c.debugApplyEnded({
        'gameId': 'g1',
        'reason': 'stop',
        'winner': opp,
        'loser': me,
        'receipt': {
          'reason': 'stop',
          'winner': opp,
          'loser': me,
          'points': {'base': 7, 'go': 0, 'total': 7},
          'multipliers': <dynamic>[],
          'multiplier': 1,
          'perPointBet': 500,
          'amount': 3500,
          'transferred': 1200,
          'settlement': 'capped',
          'winnerScore': {'total': 7},
          'loserScore': {'total': 0},
        },
        'captures': {me: <dynamic>[], opp: <dynamic>[]},
      });
      await settle(tester, ms: 6000);
      expect(find.text('-1,200코인'), findsOneWidget);
      expect(find.textContaining('코인이 모자라 1,200코인만'), findsOneWidget);
    },
  );

  testWidgets(
    'a failed settlement says so and does not claim the loser was short of coins',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(state(phase: 'finished', current: opp));
      c.debugApplyEnded({
        'gameId': 'g1',
        'reason': 'stop',
        'winner': opp,
        'loser': me,
        'receipt': {
          'reason': 'stop',
          'winner': opp,
          'loser': me,
          'points': {'base': 7, 'go': 0, 'total': 7},
          'multipliers': <dynamic>[],
          'multiplier': 1,
          'perPointBet': 500,
          'amount': 3500,
          'transferred': 0,
          'settlement': 'failed',
          'winnerScore': {'total': 7},
          'loserScore': {'total': 0},
        },
        'captures': {me: <dynamic>[], opp: <dynamic>[]},
      });
      await settle(tester, ms: 6000);
      expect(find.textContaining('코인 정산이 지연되고 있어요'), findsOneWidget);
      expect(find.textContaining('코인이 모자라'), findsNothing);
    },
  );

  testWidgets('나가리 receipt moves no coins', (tester) async {
    await pumpScreen(tester);
    c.debugApplyState(state(phase: 'nagari', current: me));
    c.debugApplyEnded({
      'gameId': 'g1',
      'reason': 'nagari',
      'winner': null,
      'loser': null,
      'receipt': {
        'reason': 'nagari',
        'winner': null,
        'points': {'total': 0},
        'multipliers': <dynamic>[],
        'multiplier': 1,
        'amount': 0,
        'transferred': 0,
        'settlement': 'none',
      },
      'captures': {me: <dynamic>[], opp: <dynamic>[]},
    });
    await settle(tester, ms: 6000);
    expect(find.text('나가리'), findsOneWidget);
    expect(find.textContaining('코인은 오가지 않았어요'), findsOneWidget);
  });

  test('models parse the server view (typed cards, projection, last turn)', () {
    final v = GostopView.fromJson(
      state(
        lastTurn: {
          'kind': 'play',
          'seq': 3,
          'by': opp,
          'played': card('m4_junk_1', 4, 'junk'),
          'flipped': card('m4_junk_2', 4, 'junk'),
          'captured': [card('m4_junk_1', 4, 'junk')],
          'stolen': [],
          'events': ['jjok'],
        },
        projections: {
          me: projection(
            base: 7,
            mult: [
              {'code': 'shake', 'count': 2, 'factor': 4},
            ],
            amount: 2800,
          ),
          opp: projection(),
        },
      ),
    );
    expect(v.hand.length, 10);
    expect(v.lastTurn?.has('jjok'), isTrue);
    expect(v.lastTurn?.played?.month, 4);
    expect(v.projectionOf(me).multiplier, 4);
    expect(v.projectionOf(me).multipliers.first.label, '흔들기 2번');
    expect(v.opponentOf(me), opp);
    expect(v.coachCardId, 'm1_bright');
  });
}
