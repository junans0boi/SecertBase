// 재대결 요청 카드: 상대 이름으로 묻고, 수락/거절을 보낸다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/widgets/game_menu.dart';

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a rematch request shows the partner name and closes on answer', (
    tester,
  ) async {
    final socket = SocketService()
      ..userId = 'ME'
      ..presenceUsers = ['ME', 'YOU']
      ..presenceNicknames = {'YOU': '토끼'};
    addTearDown(() {
      socket
        ..restartPending = false
        ..userId = null
        ..presenceUsers = []
        ..presenceNicknames = {};
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameMenuListener(gameType: 'blackjack', child: SizedBox()),
        ),
      ),
    );
    socket.restartPending = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('한 판 더 할까요?'), findsOneWidget);
    expect(find.textContaining('토끼님이'), findsOneWidget);
    await tester.tap(find.text('다음에'));
    await tester.pumpAndSettle();
    expect(find.text('한 판 더 할까요?'), findsNothing);
  });
}
