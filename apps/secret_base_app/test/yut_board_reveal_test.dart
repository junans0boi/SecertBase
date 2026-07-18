import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/yut_board.dart';

Widget _board({String? result, int? throwAt}) {
  return MaterialApp(
    home: Scaffold(
      body: YutBoard(
        gameId: 'g1',
        phase: 'throwing',
        turn: 'me',
        p1Pieces: const [],
        p2Pieces: const [],
        pendingMoves: const [],
        onNewGame: () {},
        onRollStartDice: () {},
        onThrow: () {},
        onMovePiece: (_, _) {},
        onMoveNewPiece: () {},
        currentUser: 'me',
        lastResultName: result,
        lastThrowAt: throwAt,
      ),
    ),
  );
}

void main() {
  testWidgets('던지기 연출이 끝나기 전에는 새 결과가 노출되지 않는다', (tester) async {
    // 이전 판 결과('도')가 이미 노출된 상태.
    await tester.pumpWidget(_board(result: '도', throwAt: 1));
    await tester.pumpAndSettle();
    expect(find.text('도'), findsOneWidget);

    // 상대의 새 던지기 결과('모')가 도착 → 1.8초 연출 시작.
    await tester.pumpWidget(_board(result: '모', throwAt: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('모'), findsNothing, reason: '연출 중 결과 스포일러 금지');

    // 연출 완료 후에는 결과가 노출된다.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();
    expect(find.text('모'), findsOneWidget);
  });
}
