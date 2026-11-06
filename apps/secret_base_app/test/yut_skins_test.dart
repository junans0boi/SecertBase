// 윷놀이 상점 아이템 반영(티켓 B): 동물 말 스킨 등급, 윷가락 스킨 23종, 효과 칩, 로비 캐릭터 고르기.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
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

  group('stick skins', () {
    test('every catalog yut skin has its own look', () {
      const catalog = [
        '벚꽃 윷', '단풍 윷', '새싹 윷', '조약돌 윷', // B
        '달빛 윷', '바람 윷', '눈꽃 윷', '파도 윷', // A
        '번개 윷', '태양 윷', '얼음 윷', '폭풍 윷', // S
        '용의 윷', '봉황 윷', '천둥 윷', // SS
        '신들의 윷', '우주의 윷', '운명의 윷', // SSS
        '대나무 윷', '황금 윷', '크리스탈 윷', '불꽃 윷', '전설의 윷', // 예전 5종
      ];
      final seen = <String, String>{};
      for (final name in catalog) {
        final look = YutStickLook.fromItem(item(name, '?', 'B'));
        expect(look.id, isNot('base'), reason: name);
        final clash = seen[look.signature];
        expect(clash, isNull, reason: '$name looks like $clash');
        seen[look.signature] = name;
      }
      expect(seen.length, catalog.length);
    });

    test(
      'unknown names fall back to the icon, then the grade, then the plain stick',
      () {
        expect(YutStickLook.fromItem(null).id, 'base');
        expect(YutStickLook.fromItem(item('새 윷', '🌸', 'B')).id, 'icon-cherry');
        expect(YutStickLook.fromItem(item('새 윷', '❓', 'SSS')).id, 'grade-sss');
        expect(YutStickLook.fromItem(item('새 윷', '❓', 'A')).id, 'grade-a');
        expect(YutStickLook.fromItem(item('새 윷', '❓', 'B')).id, 'base');
        expect(
          YutStickLook.fromItem({'name': 7, 'icon': null, 'grade': null}).id,
          'base',
        );
      },
    );
  });

  group('piece skins', () {
    test(
      'a piece item replaces the character figure; no item keeps the character',
      () {
        final plain = YutFigureSpec.of('miho', null);
        expect(plain.isSkin, isFalse);
        final tiger = YutFigureSpec.of('miho', item('호랑이 말', '🐯', 'A'));
        expect(tiger.isSkin, isTrue);
        expect(tiger.skinEmoji, '🐯');
        expect(tiger.skinGrade, 'A');
        expect(yutGradeColor('A'), isNot(yutGradeColor('S')));
        expect(yutGradeColor('SS'), isNot(yutGradeColor('SSS')));
      },
    );

    testWidgets('tiers B to SSS render as standing figures on a base disc', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final g in ['B', 'A', 'S', 'SS', 'SSS'])
                  YutFigure(
                    key: ValueKey('fig_$g'),
                    height: 90,
                    team: Colors.blue,
                    spec: YutFigureSpec(
                      character: 'miho',
                      skinEmoji: '🐯',
                      skinGrade: g,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      for (final g in ['B', 'A', 'S', 'SS', 'SSS']) {
        expect(find.byKey(ValueKey('fig_$g')), findsOneWidget);
      }
      expect(find.text('🐯'), findsNWidgets(5));
    });
  });

  group('screen', () {
    testWidgets(
      'both cards show the equipped skins and effective effect chips',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(
          yutState(
            stake: 100,
            equipped: {
              yutMe: {
                'yut_piece': item('호랑이 말', '🐯', 'A'),
                'yut_yut': item('번개 윷', '⚡', 'S'),
              },
              yutOpp: {
                'yut_piece': item('은하수 말', '🌌', 'SSS'),
                'yut_yut': item('우주의 윷', '🌌', 'SSS'),
              },
            },
            effects: {
              yutMe: {
                ...zeroEffects,
                'controlPct': 2.1,
                'defensePct': 10,
                'winCoinPct': 10,
              },
              yutOpp: {...zeroEffects, 'moRatePct': 3},
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        // 내 카드: 동물 말 이름 + 윷 이름 + 서버가 상한을 적용한 효과.
        expect(find.textContaining('호랑이 말 · 대기 4'), findsOneWidget);
        expect(find.textContaining('번개 윷'), findsOneWidget);
        expect(find.text('윷 컨트롤 +2.1%'), findsOneWidget);
        expect(find.text('잡힘 방어 10%'), findsOneWidget);
        expect(find.text('윷·모 코인 10%'), findsOneWidget);
        // 상대 카드도 같은 정보를 보여 준다.
        expect(find.textContaining('은하수 말 · 대기 4'), findsOneWidget);
        expect(find.textContaining('우주의 윷'), findsOneWidget);
        expect(find.text('모 확률 +3%'), findsOneWidget);
        expect(find.text('효과'), findsNWidgets(2));
        // 말 스킨은 카드의 서 있는 말과 대기 말로 나타난다.
        expect(find.text('🐯'), findsWidgets);
        expect(find.text('🌌'), findsWidgets);
        expect(tester.takeException(), isNull);
        await settle(tester);
      },
    );

    testWidgets(
      'free games hide coin effects and no equipment shows no effect chips',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(
          yutState(
            equipped: {
              yutMe: {'yut_yut': item('황금 윷', '🏅', 'A')},
            },
            effects: {
              yutMe: {...zeroEffects, 'controlPct': 1, 'winCoinPct': 15},
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('윷 컨트롤 +1%'), findsOneWidget);
        expect(find.textContaining('코인'), findsNothing);
        expect(
          find.text('효과'),
          findsOneWidget,
          reason: 'only the side with effects',
        );
        await settle(tester);
      },
    );

    testWidgets('tapping a card lists the equipment and the applied effects', (
      tester,
    ) async {
      await pumpScreen(tester);
      c.debugApplyState(
        yutState(
          equipped: {
            yutOpp: {'yut_piece': item('용 말', '🐲', 'S')},
          },
          effects: {
            yutOpp: {...zeroEffects, 'defensePct': 7},
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.textContaining('용 말 · 대기'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('하늘 장비'), findsOneWidget);
      expect(find.textContaining('말: 용 말 (S등급)'), findsOneWidget);
      expect(find.textContaining('윷: 기본'), findsOneWidget);
      expect(find.text('이 판에 적용되는 효과'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
    });

    testWidgets(
      'the same character figure shows on the card and in the waiting area',
      (tester) async {
        await pumpScreen(tester);
        c.debugApplyState(yutState());
        await tester.pump(const Duration(milliseconds: 600));
        final figures = tester
            .widgetList<YutFigure>(find.byType(YutFigure))
            .toList();
        final mine = figures.where(
          (f) => f.spec.character == 'honggilldong' && !f.spec.isSkin,
        );
        expect(
          mine.length,
          greaterThanOrEqualTo(2),
          reason: 'card + waiting group',
        );
        final theirs = figures.where(
          (f) => f.spec.character == 'miho' && !f.spec.isSkin,
        );
        expect(theirs.length, greaterThanOrEqualTo(2));
        await settle(tester);
      },
    );
  });

  group('lobby character picker', () {
    Future<void> pumpPicker(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: socket,
              builder: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: YutCharacterPicker(color: Colors.orange),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
      'three characters; the partner pick is disabled, mine is marked',
      (tester) async {
        socket.lobbyCharacterSelections = {yutOpp: 'miho'};
        await pumpPicker(tester);
        expect(
          find.byKey(const ValueKey('yut_pick_honggilldong')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('yut_pick_nolbu')), findsOneWidget);
        expect(find.byKey(const ValueKey('yut_pick_miho')), findsOneWidget);
        expect(find.text('상대 선택'), findsOneWidget);
        expect(find.text('고르기'), findsNWidgets(2));
        expect(find.textContaining('자동으로 정해져요'), findsOneWidget);
        socket.lobbyCharacterSelections = {yutOpp: 'miho', yutMe: 'nolbu'};
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        socket.notifyListeners();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('내 선택'), findsOneWidget);
        expect(find.text('상대 선택'), findsOneWidget);
        expect(find.textContaining('겹치지 않아요'), findsOneWidget);
        // 상대가 고른 카드는 눌러도 내 선택이 바뀌지 않는다.
        await tester.tap(find.byKey(const ValueKey('yut_pick_miho')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(socket.lobbyCharacterSelections[yutMe], 'nolbu');
        socket.lobbyCharacterSelections = {};
      },
    );
  });

  test(
    'effect chips show effective numbers, trimmed, and hide coin effects in free games',
    () {
      const e = YutEffects(
        controlPct: 2.1,
        moRatePct: 0.9,
        backdoBonusPct: 3,
        defensePct: 10,
        winCoinPct: 15,
        catchCoinPer: 25,
        catchFlat: 120,
      );
      expect(e.chips(staked: true), [
        '윷 컨트롤 +2.1%',
        '모 확률 +0.9%',
        '빽도 보너스 3%',
        '잡힘 방어 10%',
        '윷·모 코인 15%',
        '잡기 말당 +25코인',
        '잡기 +120코인',
      ]);
      expect(e.chips(staked: false).any((s) => s.contains('코인')), isFalse);
      expect(YutEffects.none.chips(staked: true), isEmpty);
    },
  );
}
