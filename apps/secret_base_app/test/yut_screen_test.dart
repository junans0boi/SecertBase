// 윷놀이 2.0 화면(티켓 21): 시작 버튼 없음, 칩 → 말 → 확정, 갈림길 화살표, 결과, 360·430·데스크톱 넘침 없음.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_controller.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_models.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_sticks.dart';
import 'package:secret_base_app/screens/arcade/games/yut_screen.dart';

import 'yut_test_support.dart';

void main() {
  final socket = SocketService();
  final c = YutController.instance;
  final sent = <(String, Map<String, dynamic>?)>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({'yut_howto_v2_seen': true});
    socket.userId = yutMe;
    socket.presenceNicknames = {yutMe: '준', yutOpp: '하늘'};
    socket.profileEmojis = {yutMe: '🐻', yutOpp: '🐰'};
    socket.lobbyHost = null;
    c.debugReset();
    sent.clear();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    double width = 360,
    double height = 740,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: YutScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('no start button; the guest sees the preparing state', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugReset(syncStatus: 'no_game');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('윷판을 펴는 중…'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    expect(find.text('다시 불러오기'), findsNothing);
    await settle(tester);
  });

  testWidgets('the host only gets a reload, never a start button', (
    tester,
  ) async {
    socket.lobbyHost = yutMe;
    await pumpScreen(tester);
    c.debugReset(syncStatus: 'no_game');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('다시 불러오기'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    await settle(tester);
  });

  testWidgets(
    'my throwing turn shows the throw button and names, never codes',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(yutState());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('윷 던지기'), findsOneWidget);
      expect(find.text('나'), findsOneWidget);
      expect(find.text('하늘'), findsOneWidget);
      expect(find.textContaining('OPP-CODE'), findsNothing);
      expect(find.textContaining('ME-CODE'), findsNothing);
      expect(find.text('말 4개'), findsOneWidget);
      await settle(tester);
    },
  );

  testWidgets('chip, then piece, then one destination, then confirm', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(midGame());
    await tester.pump(const Duration(milliseconds: 600));
    // 칩: 걸(3) · 빽도(-1)
    expect(find.byKey(const ValueKey('yut_chip_3')), findsOneWidget);
    expect(find.byKey(const ValueKey('yut_chip_-1')), findsOneWidget);
    // 말을 고르기 전에는 목적지가 없다.
    expect(find.byKey(const ValueKey('yut_dest_10_f')), findsNothing);
    expect(find.text('말을 옮겨요'), findsOneWidget);
    // 대기 말을 누르면 잡는 칸 하나만 보인다.
    await tester.tap(find.byKey(const ValueKey('yut_waiting_piece')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('yut_dest_3_f')), findsOneWidget);
    expect(find.byKey(const ValueKey('yut_dest_10_f')), findsNothing);
    expect(find.byKey(const ValueKey('yut_dest_20_f')), findsNothing);
    expect(find.text('잡으러 가기'), findsOneWidget);
    // 칩을 바꾸면 선택한 말이 풀린다.
    await tester.tap(find.byKey(const ValueKey('yut_chip_-1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('yut_dest_3_f')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('yut_chip_3')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('yut_waiting_piece')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('잡으러 가기'), findsOneWidget);
    await tester.tap(find.text('잡으러 가기'));
    await tester.pump(const Duration(milliseconds: 300));
    // 확정하면 선택이 지워진다(서버 응답을 기다린다).
    expect(find.text('잡으러 가기'), findsNothing);
    expect(find.byKey(const ValueKey('yut_dest_3_f')), findsNothing);
    await settle(tester);
  });

  testWidgets('a backdo fork shows two arrows and needs a direction', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(midGame());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('yut_chip_-1')));
    await tester.pump(const Duration(milliseconds: 300));
    // 방(23)의 말을 누르면 갈림길 화살표 두 개.
    await tester.tap(find.byKey(const ValueKey('yut_token_ME-CODE_2')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('yut_dest_22_22')), findsOneWidget);
    expect(find.byKey(const ValueKey('yut_dest_25_25')), findsOneWidget);
    expect(
      find.text('여기로 옮기기'),
      findsNothing,
      reason: 'a direction must be picked',
    );
    expect(find.textContaining('갈림길이에요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('yut_dest_25_25')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('여기로 옮기기'), findsOneWidget);
    await tester.tap(find.text('여기로 옮기기'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('yut_dest_25_25')), findsNothing);
    await settle(tester);
  });

  testWidgets(
    'a throw plays the sticks, calls the result, then the chip appears',
    (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(yutState(seq: 1));
      await tester.pump(const Duration(milliseconds: 600));
      c.debugApplyState(
        yutState(
          seq: 2,
          phase: 'moving',
          pending: const [2],
          canThrow: false,
          mine: [
            yutPiece(0, 4, lastPos: 3),
            yutPiece(1, 0),
            yutPiece(2, 0),
            yutPiece(3, 0),
          ],
          legal: [
            yutMove(
              moveIndex: 0,
              steps: 2,
              pieceId: 0,
              pieceIds: [0],
              from: 4,
              to: 6,
              path: [4, 5, 6],
            ),
            yutMove(
              moveIndex: 0,
              steps: 2,
              pieceId: 1,
              pieceIds: [1],
              from: 0,
              to: 2,
              path: [0, 1, 2],
            ),
          ],
          lastAction: yutThrowAction(
            seq: 2,
            by: yutMe,
            result: 2,
            name: '개',
            sticks: const [0, 1, 0, 1],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(YutSticksStage), findsOneWidget);
      // 던지는 동안 새 칩은 숨겨져 있다.
      expect(find.byKey(const ValueKey('yut_chip_2')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('개!'), findsWidgets);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(YutSticksStage), findsNothing);
      expect(find.byKey(const ValueKey('yut_chip_2')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await settle(tester);
    },
  );

  testWidgets('a capture move shows the capture banner', (tester) async {
    await pumpScreen(tester);
    c.debugApplyState(midGame());
    await tester.pump(const Duration(milliseconds: 600));
    c.debugApplyState(
      yutState(
        seq: 15,
        currentTurn: yutMe,
        phase: 'throwing',
        mine: [
          yutPiece(0, 7, lastPos: 6),
          yutPiece(1, 7, lastPos: 6),
          yutPiece(2, 23, lastPos: 22),
          yutPiece(3, 3, lastPos: 2),
        ],
        theirs: [
          yutPiece(0, 0),
          yutPiece(1, 12, lastPos: 11),
          yutPiece(2, 0),
          yutPiece(3, 20, lastPos: 20, finished: true),
        ],
        lastAction: {
          'type': 'move',
          'by': yutMe,
          'seq': 15,
          'auto': false,
          'move': {
            'moveIndex': 0,
            'steps': 3,
            'pieceIds': [3],
            'from': 0,
            'to': 3,
            'path': [0, 1, 2, 3],
            'finish': false,
            'captured': [0],
            'capturedPlayer': yutOpp,
            'blocked': <int>[],
            'blockedAt': null,
            'stacked': false,
          },
          'discardedBackdo': 0,
          'itemEffects': <Map<String, dynamic>>[],
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('잡았다!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await settle(tester);
  });

  testWidgets('result overlay shows the winner, coin bonus and rematch', (
    tester,
  ) async {
    await pumpScreen(tester);
    c.debugApplyState(yutState(stake: 100));
    await tester.pump(const Duration(milliseconds: 400));
    c.debugApplyEnded({
      'gameId': 'g1',
      'winner': yutMe,
      'loser': yutOpp,
      'reason': 'goal',
      'stake': 100,
      'coinBonus': 20,
      'finished': {yutMe: 4, yutOpp: 2},
      'pieceCount': 4,
      'series': {
        'wins': {yutMe: 2, yutOpp: 0},
        'draws': 0,
        'games': 2,
      },
    });
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('판돈 100코인을 얻었어요'), findsOneWidget);
    expect(find.text('아이템 보너스 +20코인'), findsOneWidget);
    expect(find.text('한 판 더!'), findsOneWidget);
    await settle(tester);
  });

  testWidgets(
    'result overlay shows the real receipt: capped stake and failed settlement',
    (tester) async {
      Map<String, dynamic> ended(Map<String, dynamic> extra) => {
        'gameId': 'g1',
        'winner': yutMe,
        'loser': yutOpp,
        'reason': 'goal',
        'stake': 1000,
        'coinBonus': 100,
        'finished': {yutMe: 4, yutOpp: 2},
        'pieceCount': 4,
        ...extra,
      };
      await pumpScreen(tester);
      c.debugApplyState(yutState(stake: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      // 진 사람이 300코인밖에 없었다: 화면은 약속한 1000이 아니라 실제 300을 말한다.
      c.debugApplyEnded(
        ended({'settlement': 'capped', 'transferred': 300, 'winnerGain': 350}),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('판돈 300코인을 얻었어요'), findsOneWidget);
      expect(find.text('판돈 1000코인을 얻었어요'), findsNothing);
      expect(find.text('아이템 보너스 +50코인'), findsOneWidget);
      // 정산이 실패했다: 얻었다고 말하지 않는다.
      c.debugApplyEnded(
        ended({'settlement': 'failed', 'transferred': 0, 'winnerGain': 0}),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('코인 정산이 지연되고 있어요'), findsOneWidget);
      expect(find.textContaining('코인을 얻었어요'), findsNothing);
      expect(find.textContaining('아이템 보너스'), findsNothing);
      await settle(tester);
    },
  );

  for (final size in const [
    Size(360, 640),
    Size(360, 740),
    Size(430, 900),
    Size(1280, 800),
  ]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: no overflow', (
      tester,
    ) async {
      await pumpScreen(tester, width: size.width, height: size.height);
      c.debugApplyState(midGame(pending: const [3, -1]));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('yut_waiting_piece')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      c.debugApplyState(yutState(theirs: [yutPiece(0, 5, lastPos: 4)]));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await settle(tester);
    });
  }

  test('models read the server contract', () {
    final v = YutView.fromJson(midGame());
    expect(v.legalMoves.length, 6);
    expect(v.legalMoves[0].pieceIds, [0, 1]);
    expect(v.legalMoves.last.backdoDir, 25);
    expect(v.waitingOf(yutMe), 1);
    expect(v.finishedOf(yutOpp), 1);
    expect(yutStepName(-1), '빽도');
    expect(v.lastAction!.thrown!.sticks, [0, 1, 1, 1]);
  });
}
