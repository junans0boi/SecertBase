import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/marble_board.dart';

Widget _board({String? gameId, String phase = 'throwing'}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 390,
        height: 844,
        child: MarbleBoard(
          gameId: gameId,
          phase: phase,
          turn: 'me',
          p1Pieces: const [
            {'id': 0, 'position': 0, 'finished': false},
          ],
          p2Pieces: const [
            {'id': 0, 'position': 12, 'finished': false},
          ],
          pendingMoves: phase == 'moving' ? const [4] : const [],
          onNewGame: () {},
          onRollStartDice: () {},
          onRoll: () {},
          onMovePiece: (_, _) {},
          onMoveNewPiece: () {},
          currentUser: 'me',
          p1UserId: 'me',
          p2UserId: 'partner',
          p1Character: 'k',
          p2Character: 'ria',
          displayName: (id) => id,
          coins: 5_000_000,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('마블 작전 시작 화면과 플레이 화면이 윷 요소 없이 렌더링된다', (
    tester,
  ) async {
    await tester.pumpWidget(_board());
    await tester.pump();

    expect(find.text('마블 작전 시작'), findsOneWidget);
    expect(find.text('실전형 윷놀이 시작'), findsNothing);

    await tester.pumpWidget(_board(gameId: 'active'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('marble_action_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('yut_action_bar')), findsNothing);
  });
}
