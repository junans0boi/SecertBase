// 가위바위보 화면 회귀: 제로를 떼어 낸 뒤에도 모드 선택과 3판선승 진행 화면이 그대로다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/rps_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    final socket = SocketService();
    socket.userId = null;
    socket.rpsMode = null;
    socket.rpsActive = false;
    socket.rpsPlayers = [];
    socket.rpsScores = {};
    socket.lobbyHost = null;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('classic rps shows the three modes to the host', (tester) async {
    SocketService().userId = 'A';
    await pump(tester, const RpsScreen());
    expect(find.text('게임 모드를 골라요'), findsOneWidget);
    expect(find.text('단판 가위바위보'), findsOneWidget);
    expect(find.text('가위바위보 3판선승'), findsOneWidget);
    expect(find.text('묵찌빠'), findsOneWidget);
    expect(find.textContaining('제로'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a running best-of-three shows the hand choices', (tester) async {
    final socket = SocketService();
    socket.userId = 'A';
    socket.rpsMode = 'rps3';
    socket.rpsActive = true;
    socket.rpsPlayers = ['A', 'B'];
    socket.rpsScores = {'A': 1, 'B': 0};
    await pump(tester, const RpsScreen());
    expect(find.text('바위'), findsOneWidget);
    expect(find.text('가위'), findsOneWidget);
    expect(find.text('보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
