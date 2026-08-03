import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/yut_board.dart';

Future<void> _pumpBoard(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: YutBoard(
          gameId: 'layout-test',
          phase: 'moving',
          turn: 'me',
          p1Pieces: const [
            {'position': 0},
            {'position': 6},
            {'position': 12},
            {'position': 0},
          ],
          p2Pieces: const [
            {'position': 0},
            {'position': 3},
            {'position': 3},
            {'position': 0},
          ],
          pendingMoves: const [3],
          onNewGame: () {},
          onRollStartDice: () {},
          onThrow: () {},
          onMovePiece: (_, _, {int? backdoDir}) {},
          onMoveNewPiece: () {},
          currentUser: 'me',
          p1UserId: 'me',
          p2UserId: 'partner',
          p1Character: 'honggilldong',
          p2Character: 'miho',
          displayName: (id) => id == 'me' ? '웃놀이마스터' : '송부사',
          coins: 50000,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('주요 화면 크기에서 보드 UI가 넘치지 않는다', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final size in const [
      Size(360, 640),
      Size(390, 844),
      Size(1024, 768),
    ]) {
      await _pumpBoard(tester, size);
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width}x${size.height} 레이아웃',
      );
    }
  });

  testWidgets('390x844에서 보드는 입체적인 넓은 원근과 게임 노드 오버레이를 사용한다', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpBoard(tester, const Size(390, 844));

    final boardFinder = find.byKey(const ValueKey('yut_board_surface'));
    final board = tester.getSize(boardFinder);
    final boardRect = tester.getRect(boardFinder);
    final opponentCard = tester.getRect(
      find.byKey(const ValueKey('yut_opponent_profile')),
    );
    final myCard = tester.getRect(find.byKey(const ValueKey('yut_my_profile')));
    final actionBar = tester.getRect(
      find.byKey(const ValueKey('yut_action_bar')),
    );

    expect(board.width, greaterThanOrEqualTo(374));
    expect(board.width / board.height, greaterThanOrEqualTo(1.35));
    expect(boardRect.top, greaterThanOrEqualTo(220));
    final boardArt = tester.widget<Image>(
      find.byKey(const ValueKey('yut_board_art')),
    );
    expect(
      (boardArt.image as AssetImage).assetName,
      'assets/images/yut/yut_board_3d_rail_v2_chroma.png',
    );
    expect(find.byKey(const ValueKey('yut_board_nodes')), findsOneWidget);
    expect(opponentCard.width, lessThanOrEqualTo(176));
    expect(myCard.width, lessThanOrEqualTo(176));
    expect(opponentCard.height, lessThanOrEqualTo(88));
    expect(myCard.height, lessThanOrEqualTo(88));
    expect(opponentCard.top, lessThan(board.height * 0.42));
    expect(myCard.bottom, lessThanOrEqualTo(actionBar.top));
    expect(actionBar.height, inInclusiveRange(118, 175));

    final remaining = tester.getRect(
      find.byKey(const ValueKey('yut_my_profile_remaining')),
    );
    final avatar = tester.getRect(
      find.byKey(const ValueKey('yut_my_profile_avatar')),
    );
    final identity = tester.getRect(
      find.byKey(const ValueKey('yut_my_profile_identity')),
    );
    expect(remaining.center.dx, lessThan(avatar.center.dx));
    expect(identity.top, greaterThanOrEqualTo(avatar.bottom));
    for (var pieceId = 0; pieceId < 4; pieceId++) {
      expect(
        find.byKey(ValueKey('yut_my_profile_piece_$pieceId')),
        findsOneWidget,
      );
    }
  });

  testWidgets('보드 위 말은 이미지에서 측정한 레일 중심 좌표에 놓인다', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpBoard(tester, const Size(390, 844));

    final boardRect = tester.getRect(
      find.byKey(const ValueKey('yut_board_surface')),
    );
    for (final target in const [
      ('p1_1', Offset(0.6538, 0.1710)),
      ('p2_1', Offset(0.7772, 0.4066)),
    ]) {
      final pieceCenter = tester.getCenter(find.byKey(ValueKey(target.$1)));
      final expectedCenter = Offset(
        boardRect.left + (boardRect.width * target.$2.dx),
        boardRect.top + (boardRect.height * target.$2.dy),
      );
      expect(
        (pieceCenter - expectedCenter).distance,
        lessThanOrEqualTo(1),
        reason: '${target.$1} 말이 레일 중심에서 벗어남',
      );
    }
  });

  testWidgets('5칸 레일 보드 렌더링이 유지된다', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpBoard(tester, const Size(390, 844));

    await expectLater(
      find.byKey(const ValueKey('yut_board_surface')),
      matchesGoldenFile('goldens/yut_board_5_step_rail.png'),
    );
  });
}
