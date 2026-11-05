import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/tank_screen.dart';

import 'tank_test_support.dart';

Future<void> _pumpTank(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: TankScreen()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

void _notify() {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  SocketService().notifyListeners();
}

void main() {
  setUp(() {
    resetTankSocket();
    SocketService().userId = 'me';
    SocketService().presenceNicknames = {'opp': '송부사'};
  });
  tearDown(resetTankSocket);

  testWidgets('select phase: preview a tank, then confirm to deploy', (
    tester,
  ) async {
    SocketService().tankState = tankTestState(phase: 'select');
    await _pumpTank(tester);

    expect(find.text('전차 선택'), findsOneWidget);
    for (final name in ['코뿔소', '매', '땅굴이', '거북']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('전차를 골라 주세요'), findsOneWidget);

    await tester.tap(find.text('거북'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('거북(으)로 출격!'), findsOneWidget);

    await tester.tap(find.text('거북(으)로 출격!'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('my turn: HUD, weapons, aim steppers and fire button', (
    tester,
  ) async {
    SocketService().tankState = tankTestState();
    await _pumpTank(tester);

    expect(find.text('탱크 대작전'), findsOneWidget);
    expect(find.text('발사!'), findsOneWidget);
    expect(find.text('기본탄'), findsOneWidget);
    expect(find.text('송부사'), findsOneWidget);
    expect(find.text('45°'), findsOneWidget);

    await tester.tap(find.text('대형탄'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('대형탄 · 피해 55 · 큰 폭발'), findsOneWidget);

    await tester.tap(find.byTooltip('각도 늘리기'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('46°'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opponent turn: controls wait', (tester) async {
    SocketService().tankState = tankTestState(turn: 1, suddenDeath: true);
    await _pumpTank(tester);

    expect(find.text('대기'), findsOneWidget);
    expect(find.text('상대 차례예요 · 바람과 지형을 살펴보세요'), findsOneWidget);
    expect(find.text('서든데스'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every theme renders without errors', (tester) async {
    for (final theme in ['meadow', 'desert', 'snow', 'moon']) {
      SocketService().tankState = tankTestState(theme: theme);
      _notify();
      await _pumpTank(tester, size: const Size(1280, 720));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull, reason: theme);
    }
  });

  testWidgets('a shot plays back with blast, KO and then the result', (
    tester,
  ) async {
    final state = tankTestState(oppHp: 30);
    SocketService().tankState = state;
    await _pumpTank(tester);

    SocketService().tankLastShot = tankTestShot(state, damage: 40);
    _notify();
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    final after = tankTestState(oppHp: 0);
    after['phase'] = 'result';
    SocketService()
      ..tankState = after
      ..tankWinner = 'me'
      ..tankEndReason = 'ko'
      ..tankSeries = {'me': 2, 'opp': 1}
      ..tankSummary = {
        'winner': 'me',
        'players': [
          {
            'id': 'me',
            'accuracy': 75,
            'stats': {
              'damageDealt': 120,
              'directHits': 2,
              'maxHit': 55,
              'crates': 1,
            },
          },
          {
            'id': 'opp',
            'accuracy': 40,
            'stats': {
              'damageDealt': 60,
              'directHits': 0,
              'maxHit': 30,
              'crates': 0,
            },
          },
        ],
      };
    _notify();
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('상대 전차를 격파했어요!'), findsOneWidget);
    expect(find.text('재대결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
