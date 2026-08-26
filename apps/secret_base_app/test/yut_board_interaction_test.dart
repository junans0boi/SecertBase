import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/yut_board.dart';

void main() {
  testWidgets('도착 예정지 가이드를 탭하면 선택한 말이 이동 요청된다', (tester) async {
    int? movedPieceId;
    int? movedMoveIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YutBoard(
            gameId: 'interaction-test',
            phase: 'moving',
            turn: 'me',
            p1Pieces: const [
              {'position': 0},
              {'position': 0},
              {'position': 0},
              {'position': 0},
            ],
            p2Pieces: const [
              {'position': 0},
              {'position': 0},
              {'position': 0},
              {'position': 0},
            ],
            pendingMoves: const [3],
            onNewGame: () {},
            onRollStartDice: () {},
            onThrow: () {},
            onMovePiece: (pieceId, moveIndex, {int? backdoDir}) {
              movedPieceId = pieceId;
              movedMoveIndex = moveIndex;
            },
            onMoveNewPiece: () {},
            currentUser: 'me',
            p1UserId: 'me',
            p2UserId: 'partner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('yut_my_profile_piece_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('걸'));
    await tester.pump();

    expect(movedPieceId, 0);
    expect(movedMoveIndex, 0);
  });

  testWidgets('가이드가 나타나는 애니메이션 중에도 도착 예정지 탭을 놓치지 않는다', (tester) async {
    var moved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YutBoard(
            gameId: 'interaction-animation-test',
            phase: 'moving',
            turn: 'me',
            p1Pieces: const [
              {'position': 0},
              {'position': 0},
              {'position': 0},
              {'position': 0},
            ],
            p2Pieces: const [],
            pendingMoves: const [3],
            onNewGame: () {},
            onRollStartDice: () {},
            onThrow: () {},
            onMovePiece: (_, _, {int? backdoDir}) => moved = true,
            onMoveNewPiece: () {},
            currentUser: 'me',
            p1UserId: 'me',
            p2UserId: 'partner',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('yut_my_profile_piece_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('yut_move_guide_0_3_')));

    expect(moved, isTrue);
  });
}
