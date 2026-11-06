// 윷놀이 상점 아이템 반영(티켓 B): 동물 말 스킨 등급, 윷가락 스킨 23종, 효과 칩, 로비 캐릭터 고르기.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/game_lobby_screen.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_character_picker.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_controller.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_figures.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_models.dart';
import 'package:secret_base_app/screens/arcade/games/yut/yut_sticks.dart';
import 'package:secret_base_app/screens/arcade/games/yut_screen.dart';

import 'yut_test_support.dart';

Map<String, dynamic> item(String name, String icon, String grade) => {
  'name': name,
  'icon': icon,
  'grade': grade,
  'stats': <String, dynamic>{},
};

const zeroEffects = {
  'controlPct': 0,
  'moRatePct': 0,
  'overturnPct': 0,
  'backdoBonusPct': 0,
  'defensePct': 0,
  'winCoinPct': 0,
  'catchCoinPer': 0,
  'catchFlat': 0,
};

void main() {
  final socket = SocketService();
  final c = YutController.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({'yut_howto_v2_seen': true});
    socket.userId = yutMe;
    socket.presenceNicknames = {yutMe: '준', yutOpp: '하늘'};
    socket.profileEmojis = {yutMe: '🐻', yutOpp: '🐰'};
    socket.lobbyHost = null;
    c.debugReset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: YutScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  const skinNames = [
    '대나무 윷',
    '단풍 윷', // B
    '달빛 윷',
    '옥 윷', // A
    '얼음 윷',
    '번개 윷', // S
    '불꽃 윷',
    '용의 윷', // SS
    '신들의 윷', // SSS
  ];

  group('yut skins', () {
    test('every shop skin has its own look, distinct from the plain stick', () {
      final seen = <String, String>{YutStickLook.base.signature: '기본 윷'};
      for (final name in skinNames) {
        final look = YutStickLook.fromItem(item(name, '?', 'B'));
        expect(look.id, isNot('base'), reason: name);
        expect(
          look.id,
          isNot(startsWith('grade-')),
          reason: '$name has its own look',
        );
        final clash = seen[look.signature];
        expect(clash, isNull, reason: '$name looks like $clash');
        seen[look.signature] = name;
      }
      expect(seen.length, skinNames.length + 1);
    });

    test(
      'higher grades are flashier: SS and SSS shimmer, SSS is the rainbow one',
      () {
        YutStickLook look(String n) => YutStickLook.fromItem(item(n, '?', 'B'));
        expect(look('대나무 윷').sparkle, isFalse);
        expect(look('단풍 윷').glow, isNull);
        expect(look('불꽃 윷').sparkle, isTrue);
        expect(look('용의 윷').sparkle, isTrue);
        expect(look('신들의 윷').rainbow, isTrue);
        expect(look('용의 윷').rainbow, isFalse);
      },
    );

    test('unknown or old items fall back by grade and never crash', () {
      expect(YutStickLook.fromItem(null).id, 'base');
      expect(YutStickLook.fromItem(item('벚꽃 윷', '🌸', 'B')).id, 'base');
      expect(YutStickLook.fromItem(item('새 윷', '❓', 'A')).id, 'grade-a');
      expect(YutStickLook.fromItem(item('새 윷', '❓', 'SSS')).id, 'grade-sss');
      expect(
        YutStickLook.fromItem({'name': 7, 'icon': null, 'grade': null}).id,
        'base',
      );
    });

    test(
      'the client catalog and stat table match the server (migration + engine)',
      () {
        final root = Directory.current.parent.parent;
        final sql = File(
          '${root.path}/services/realtime-server/migrations/0049_yut_system.sql',
        ).readAsStringSync();
        final names = RegExp(
          r"\(11\d, 'skin', 'yut', 'yut_yut', '\w+',\s+'([^']+)'",
        ).allMatches(sql).map((m) => m.group(1)!).toList();
        expect(names, skinNames);
        for (final n in names) {
          expect(
            YutStickLook.byName.containsKey(n),
            isTrue,
            reason: '$n has a look',
          );
        }
        expect(YutStickLook.byName.length, names.length);
        final engine = File(
          '${root.path}/services/realtime-server/src/yut-engine.js',
        ).readAsStringSync();
        for (final e in kYutCharacterStats.entries) {
          final m = RegExp(
            '${e.key}: Object.freeze\\(\\{([^}]*)\\}\\)',
          ).firstMatch(engine);
          expect(m, isNotNull, reason: e.key);
          final server = {
            for (final p in RegExp(r'(\w+): (\d)').allMatches(m!.group(1)!))
              p.group(1)!: int.parse(p.group(2)!),
          };
          expect(server, e.value, reason: '${e.key} stats match the server');
          expect(e.value.values.reduce((a, b) => a + b), 15);
        }
      },
    );
  });

  group('characters', () {
    test('five stats each, shown in the same order as the server', () {
      expect(kYutStatDefs.map((d) => d.key), [
        'power',
        'calm',
        'guard',
        'luck',
        'momentum',
      ]);
      expect(kYutStatDefs.map((d) => d.label), [
        '던지기 힘',
        '침착',
        '방어',
        '행운',
        '기세',
      ]);
      expect(kYutCharacterStats.keys.toSet(), {
        'honggilldong',
        'miho',
        'nolbu',
      });
      expect(
        yutCharacterStatsFor('unknown').values.every((v) => v == 3),
        isTrue,
      );
    });

    test(
      'server state is read for both players, with the table as a fallback',
      () {
        final v = YutView.fromJson({
          ...yutState(),
          'characterStats': {
            yutMe: {
              'power': 3,
              'calm': 4,
              'guard': 4,
              'luck': 2,
              'momentum': 2,
            },
          },
        });
        expect(v.statsOf(yutMe)['calm'], 4);
        expect(
          v.statsOf(yutOpp),
          kYutCharacterStats['miho'],
          reason: 'falls back to the character table',
        );
      },
    );

    testWidgets(
      'the same character figure shows on the card and in the waiting area',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(yutState());
        await tester.pump(const Duration(milliseconds: 600));
        final figures = tester
            .widgetList<YutFigure>(find.byType(YutFigure))
            .toList();
        expect(
          figures.where((f) => f.spec.character == 'honggilldong').length,
          greaterThanOrEqualTo(2),
          reason: 'card + waiting group',
        );
        expect(
          figures.where((f) => f.spec.character == 'miho').length,
          greaterThanOrEqualTo(2),
        );
        await settle(tester);
      },
    );
  });

  group('screen', () {
    testWidgets(
      'cards show the character, the yut skin and the effective effects of both players',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(
          yutState(
            stake: 100,
            equipped: {
              yutMe: {'yut_yut': item('번개 윷', '⚡', 'S')},
              yutOpp: {'yut_yut': item('신들의 윷', '✨', 'SSS')},
            },
            effects: {
              yutMe: {
                ...zeroEffects,
                'controlPct': 2.1,
                'calmPct': 12,
                'defensePct': 4.5,
              },
              yutOpp: {...zeroEffects, 'controlPct': 1.2},
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.textContaining('홍길동 · 대기 4'),
          findsOneWidget,
          reason: 'the card names the character, not an animal skin',
        );
        expect(find.textContaining('번개 윷'), findsOneWidget);
        expect(find.text('윷 컨트롤 +2.1%'), findsOneWidget);
        expect(find.text('빽도 방어 12%'), findsOneWidget);
        expect(find.textContaining('신들의 윷'), findsOneWidget);
        expect(find.text('윷 컨트롤 +1.2%'), findsOneWidget);
        expect(find.text('효과'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await settle(tester);
      },
    );

    testWidgets(
      'tapping a card lists the five stats, the yut skin and every effect',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(
          yutState(
            stake: 100,
            equipped: {
              yutOpp: {'yut_yut': item('용의 윷', '🐉', 'SS')},
            },
            effects: {
              yutOpp: {
                ...zeroEffects,
                'defensePct': 7,
                'winCoinPct': 8,
                'controlPct': 0.8,
                'calmPct': 5,
              },
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.textContaining('용의 윷').first);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('하늘 장비'), findsOneWidget);
        expect(find.textContaining('미호 · 기술·행운형'), findsOneWidget);
        for (final def in kYutStatDefs) {
          expect(find.text(def.label), findsOneWidget, reason: def.label);
        }
        // 미호: 행운 5칸 모두 채워짐, 침착 2칸.
        Color? pip(String key, int i) {
          final box = tester.widget<Container>(
            find.byKey(ValueKey('yut_stat_${key}_$i')),
          );
          return (box.decoration as BoxDecoration).color;
        }

        expect(pip('luck', 5), pip('luck', 1));
        expect(pip('calm', 2), pip('calm', 1));
        expect(pip('calm', 3), isNot(pip('calm', 2)));
        expect(find.textContaining('윷 스킨: 용의 윷 (SS등급)'), findsOneWidget);
        expect(
          find.textContaining('말:'),
          findsNothing,
          reason: 'there is no piece slot any more',
        );
        expect(find.text('윷·모 코인 8%'), findsOneWidget);
        expect(find.text('잡힘 방어 7%'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);
      },
    );

    testWidgets(
      'a stale piece skin in the state is ignored and an old yut name does not crash',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(
          yutState(
            equipped: {
              yutMe: {
                'yut_piece': item('호랑이 말', '🐯', 'A'),
                'yut_yut': item('벚꽃 윷', '🌸', 'B'),
              },
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('🐯'), findsNothing);
        expect(find.textContaining('벚꽃 윷'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await settle(tester);
      },
    );

    testWidgets('free games hide coin effects', (tester) async {
      await pumpScreen(tester);
      c.debugApplyState(
        yutState(
          effects: {
            yutMe: {...zeroEffects, 'controlPct': 1, 'winCoinPct': 15},
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('윷 컨트롤 +1%'), findsOneWidget);
      expect(find.textContaining('코인'), findsNothing);
      await settle(tester);
    });
  });

  group('lobby character picker', () {
    Future<void> pumpPicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: socket,
              builder: (_, _) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: YutCharacterPicker(color: Colors.orange),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
      'each card shows its five stats; the partner pick is disabled, mine is marked',
      (tester) async {
        socket.lobbyCharacterSelections = {yutOpp: 'miho'};
        await pumpPicker(tester);
        for (final id in ['honggilldong', 'nolbu', 'miho']) {
          expect(find.byKey(ValueKey('yut_pick_$id')), findsOneWidget);
        }
        // 능력치 이름이 카드마다(3장) 보인다.
        for (final def in kYutStatDefs) {
          expect(find.text(def.label), findsNWidgets(3), reason: def.label);
        }
        expect(find.text('균형·수비형'), findsOneWidget);
        expect(find.text('상대 선택'), findsOneWidget);
        expect(find.text('고르기'), findsNWidgets(2));
        expect(find.textContaining('자동으로 정해져요'), findsOneWidget);
        socket.lobbyCharacterSelections = {yutOpp: 'miho', yutMe: 'nolbu'};
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        socket.notifyListeners();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('내 선택'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('yut_pick_miho')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(socket.lobbyCharacterSelections[yutMe], 'nolbu');
        // 놀부는 힘 5칸, 침착 1칸.
        Color? pip(String key, int i, String id) {
          final boxes = find.descendant(
            of: find.byKey(ValueKey('yut_pick_$id')),
            matching: find.byKey(ValueKey('yut_stat_${key}_$i')),
          );
          final box = tester.widget<Container>(boxes);
          return (box.decoration as BoxDecoration).color;
        }

        expect(pip('power', 5, 'nolbu'), pip('power', 1, 'nolbu'));
        expect(pip('calm', 2, 'nolbu'), isNot(pip('calm', 1, 'nolbu')));
        socket.lobbyCharacterSelections = {};
      },
    );

    testWidgets('lobby avatar circles show the picked character faces', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      socket.userId = 'ME';
      socket.lobbyGameType = 'yut';
      socket.lobbyHost = 'ME';
      socket.lobbyPlayers = ['ME', 'YOU'];
      socket.lobbyCharacterSelections = {'ME': 'honggilldong', 'YOU': 'miho'};
      await tester.pumpWidget(
        MaterialApp(
          home: GameLobbyScreen(
            gameType: 'yut',
            title: '윷놀이',
            description: '테스트',
            emoji: '🎲',
            color: Colors.orange,
            backgroundColor: Colors.orange.shade50,
            gameScreen: const SizedBox(),
            onJoinLobby: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final faces = tester
          .widgetList<YutCharacterAvatar>(find.byType(YutCharacterAvatar))
          .map((f) => f.character)
          .toList();
      expect(faces, ['honggilldong', 'miho']);
      socket.lobbyCharacterSelections = {};
      socket.lobbyGameType = null;
      socket.lobbyPlayers = [];
      await tester.pumpWidget(const SizedBox());
    });
  });

  test(
    'effect chips show effective numbers, trimmed, and hide coin effects in free games',
    () {
      const e = YutEffects(
        controlPct: 2.1,
        moRatePct: 0.9,
        backdoBonusPct: 3,
        calmPct: 12,
        defensePct: 8.5,
        winCoinPct: 15,
        catchCoinPer: 25,
        catchFlat: 120,
      );
      expect(e.chips(staked: true), [
        '윷 컨트롤 +2.1%',
        '모 확률 +0.9%',
        '빽도 보너스 3%',
        '빽도 방어 12%',
        '잡힘 방어 8.5%',
        '윷·모 코인 15%',
        '잡기 말당 +25코인',
        '잡기 +120코인',
      ]);
      expect(e.chips(staked: false).any((s) => s.contains('코인')), isFalse);
      expect(YutEffects.none.chips(staked: true), isEmpty);
    },
  );
}
