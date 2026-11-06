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

  testWidgets('the prompt closes by itself when a new game starts', (
    tester,
  ) async {
    final socket = SocketService()
      ..userId = 'ME'
      ..presenceUsers = ['ME', 'YOU']
      ..presenceNicknames = {'YOU': '토끼'};
    addTearDown(() {
      socket
        ..restartPending = false
        ..restartWaiting = false
        ..userId = null
        ..presenceUsers = []
        ..presenceNicknames = {};
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameMenuListener(gameType: 'telepathy', child: SizedBox()),
        ),
      ),
    );
    socket.restartPending = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('한 판 더 할까요?'), findsOneWidget);

    // 서버가 `game:restart:started`를 보내면 요청 표시가 꺼진다(동시에 눌러 이미 시작된 경우).
    socket.restartPending = false;
    socket.restartWaiting = false;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('한 판 더 할까요?'), findsNothing);
    // 화면이 막히지 않는다: 열린 대화상자 경로가 없다.
    expect(find.byType(Dialog), findsNothing);
    expect(
      ModalRoute.of(tester.element(find.byType(Scaffold)))?.isCurrent,
      true,
    );

    // 다음 요청이 오면 다시 뜬다.
    socket.restartPending = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    socket.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('한 판 더 할까요?'), findsOneWidget);
    await tester.tap(find.text('다음에'));
    await tester.pumpAndSettle();
    debugPrint(
      'DBG pending=${socket.restartPending} dialogs=${find.byType(Dialog).evaluate().length}',
    );
    expect(find.text('한 판 더 할까요?'), findsNothing);
  });
}
