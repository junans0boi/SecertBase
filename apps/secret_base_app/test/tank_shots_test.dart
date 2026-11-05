// 화면 확인용 스크린샷. 평소 CI에서는 건너뛰고, TANK_SHOTS=1일 때만
// `flutter test --update-goldens test/tank_shots_test.dart`로 PNG를 만든다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/tank_screen.dart';

import 'tank_test_support.dart';

final _enabled = Platform.environment['TANK_SHOTS'] == '1';

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required Size size,
  Future<void> Function()? after,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(debugShowCheckedModeBanner: false, home: TankScreen()),
  );
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (after != null) await after();
  await expectLater(
    find.byType(TankScreen),
    matchesGoldenFile('goldens/tank_shots/$name.png'),
  );
}

void main() {
  setUp(() {
    resetTankSocket();
    SocketService().userId = 'me';
    SocketService().presenceNicknames = {'opp': '송부사'};
  });
  tearDown(resetTankSocket);

  const phone = Size(390, 844);
  const desktop = Size(1280, 720);

  testWidgets('select', (tester) async {
    SocketService().tankState = tankTestState(phase: 'select', theme: 'desert');
    await _shot(tester, 'select_phone', size: phone);
  }, skip: !_enabled);

  for (final theme in ['meadow', 'desert', 'snow', 'moon']) {
    testWidgets('battle $theme', (tester) async {
      SocketService().tankState = tankTestState(theme: theme);
      await _shot(tester, 'battle_${theme}_phone', size: phone);
    }, skip: !_enabled);
  }

  testWidgets('battle desktop', (tester) async {
    SocketService().tankState = tankTestState(theme: 'meadow');
    await _shot(tester, 'battle_desktop', size: desktop);
  }, skip: !_enabled);

  testWidgets('overview desktop', (tester) async {
    SocketService().tankState = tankTestState(theme: 'snow', turn: 1);
    await _shot(
      tester,
      'overview_desktop',
      size: desktop,
      after: () async {
        await tester.tap(find.byTooltip('전장 전체 보기'));
        for (int i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  }, skip: !_enabled);

  for (final ms in [300, 900, 1050, 1500]) {
    testWidgets('playback $ms', (tester) async {
      final state = tankTestState(oppHp: 30);
      SocketService().tankState = state;
      await _shot(
        tester,
        'playback_${ms}ms',
        size: phone,
        after: () async {
          SocketService().tankLastShot = tankTestShot(state, damage: 40);
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          SocketService().notifyListeners();
          for (int t = 0; t < ms; t += 50) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
      );
    }, skip: !_enabled);
  }

  testWidgets('result', (tester) async {
    final state = tankTestState(oppHp: 0);
    state['phase'] = 'result';
    SocketService()
      ..tankState = state
      ..tankWinner = 'me'
      ..tankEndReason = 'ko'
      ..tankSeries = {'me': 2, 'opp': 1}
      ..tankSummary = {
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
    await _shot(tester, 'result_phone', size: phone);
  }, skip: !_enabled);
}
