import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/ui/uno_board.dart';

void main() {
  Future<void> pumpBoard(
    WidgetTester tester, {
    String? lastSpecialCard,
    String? lastSpecialBy,
    int? lastSpecialAt,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: UnoBoard(
              gameId: 'active',
              currentUser: 'me',
              cardBackSkin: 'gold',
              opponentCardBackSkin: 'space',
              lastSpecialCard: lastSpecialCard,
              lastSpecialBy: lastSpecialBy,
              lastSpecialAt: lastSpecialAt,
              onNewGame: () {},
              onDrawCard: () {},
              onPlayCard: (_, _) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('draw2 uses the player card-back skin for its burst', (
    tester,
  ) async {
    await pumpBoard(tester);
    await pumpBoard(
      tester,
      lastSpecialCard: 'draw2',
      lastSpecialBy: 'me',
      lastSpecialAt: 1,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final burst = find.byKey(const ValueKey('uno_attack_skin_burst_gold'));
    expect(burst, findsOneWidget);
    expect(
      find.descendant(of: burst, matching: find.byType(UnoCardBack)),
      findsNWidgets(2),
    );
  });

  testWidgets('wild draw4 uses the opponent card-back skin for its burst', (
    tester,
  ) async {
    await pumpBoard(tester);
    await pumpBoard(
      tester,
      lastSpecialCard: 'wild_draw4',
      lastSpecialBy: 'opponent',
      lastSpecialAt: 1,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final burst = find.byKey(const ValueKey('uno_attack_skin_burst_space'));
    expect(burst, findsOneWidget);
    expect(
      find.descendant(of: burst, matching: find.byType(UnoCardBack)),
      findsNWidgets(4),
    );
  });
}
