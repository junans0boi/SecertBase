import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/dice_screen.dart';

void main() {
  tearDown(() {
    SocketService().lastDice = null;
  });

  testWidgets('renders the perspective cube and pip result', (tester) async {
    SocketService().lastDice = 4;

    await tester.pumpWidget(const MaterialApp(home: DiceScreen()));
    await tester.pump();

    expect(find.byKey(const ValueKey('dice_3d_cube')), findsOneWidget);
    expect(find.text('결과  '), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roll button starts the cube animation', (tester) async {
    SocketService().lastDice = null;

    await tester.pumpWidget(const MaterialApp(home: DiceScreen()));
    await tester.tap(find.text('굴리기'));
    await tester.pump();

    expect(find.text('굴리는 중...'), findsOneWidget);
    expect(find.byKey(const ValueKey('dice_3d_cube')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
