// 해적 룰렛 2.0: 구멍 수별 배치(넘침 없음), 확률 게이지, 벌칙 입력 검증, 진 사람 대기 화면.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/pirate/pirate_barrel.dart';
import 'package:secret_base_app/screens/arcade/games/pirate/pirate_controller.dart';
import 'package:secret_base_app/screens/arcade/games/pirate/pirate_game_screen.dart';
import 'package:secret_base_app/screens/arcade/games/pirate/pirate_panels.dart';
import 'package:secret_base_app/widgets/play_kit/play_kit.dart';

const me = 'ME-CODE';
const partner = 'PARTNER-CODE';

Map<String, dynamic> stateMap({
  String gameId = 'g1',
  int slots = 8,
  List<int> picked = const [],
  String phase = 'playing',
  String? currentTurn = me,
  int? bombSlot,
  String? winner,
  String? loser,
  Map<String, dynamic>? penalty,
  int seq = 0,
  String reason = 'bomb',
}) {
  final remaining = slots - picked.length;
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'gameId': gameId,
    'round': 1,
    'slots': slots,
    'pickedSlots': picked,
    'stabs': [
      for (var i = 0; i < picked.length; i++)
        {'slot': picked[i], 'by': i.isEven ? me : partner, 'auto': false},
    ],
    'players': [me, partner],
    'firstTurn': me,
    'currentTurn': phase == 'playing' ? currentTurn : null,
    'phase': phase,
    'remaining': remaining,
    'riskPct': (100 / remaining).round(),
    'turnDeadline': phase == 'playing' ? now + 15000 : null,
    'serverNow': now,
    'turnMs': 20000,
    'bombSlot': bombSlot,
    'winner': winner,
    'loser': loser,
    'reason': phase == 'playing' ? null : reason,
    'penalty': penalty,
    'seq': seq,
    'series': {
      'wins': {me: 1, partner: 2},
      'draws': 0,
      'games': 3,
    },
  };
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({'how_to_pirate_v2': true});
    final socket = SocketService();
    socket.userId = me;
    socket.presenceUsers = [me, partner];
    socket.presenceNicknames = {me: '바다', partner: '하늘'};
    socket.profileEmojis = {me: '🐳', partner: '🦜'};
  });

  setUp(() => PirateController.instance.state = null);

  Future<void> pumpScreen(
    WidgetTester tester,
    Map<String, dynamic> state, {
    Size size = const Size(360, 740),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PirateController.instance.apply(PirateState.fromMap(state));
    await tester.pumpWidget(
      const MaterialApp(home: PirateGameScreen(syncOnOpen: false)),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('hole layouts', () {
    for (final slots in [6, 8, 12]) {
      for (final size in [const Size(360, 640), const Size(430, 900)]) {
        testWidgets(
          '$slots holes fit ${size.width.toInt()}x${size.height.toInt()} with tappable, separated holes',
          (tester) async {
            await pumpScreen(
              tester,
              stateMap(slots: slots, picked: const [1]),
              size: size,
            );
            expect(tester.takeException(), isNull);
            // 꽂힌 1번 구멍은 더 누를 수 없다.
            expect(find.byKey(const ValueKey('pirate-hole-1')), findsNothing);
            final centers = <Offset>[];
            for (var i = 0; i < slots; i++) {
              if (i == 1) continue;
              final f = find.byKey(ValueKey('pirate-hole-$i'));
              expect(f, findsOneWidget);
              final rect = tester.getRect(f);
              expect(rect.width, greaterThanOrEqualTo(44));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(size.width));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
              centers.add(rect.center);
            }
            var minGap = double.infinity;
            for (var a = 0; a < centers.length; a++) {
              for (var b = a + 1; b < centers.length; b++) {
                minGap = math.min(minGap, (centers[a] - centers[b]).distance);
              }
            }
            expect(
              minGap,
              greaterThanOrEqualTo(44),
              reason: 'holes are far enough apart to tap',
            );
            expect(find.text('구멍 $slots개'), findsOneWidget);
          },
        );
      }
    }

    test(
      'rows: 6 → 3·3, 8 → 4·4, 12 → 4·4·4 and every hole is on the barrel body',
      () {
        expect(BarrelGeometry(280, 6).rows, [3, 3]);
        expect(BarrelGeometry(280, 8).rows, [4, 4]);
        expect(BarrelGeometry(280, 12).rows, [4, 4, 4]);
        for (final n in [6, 8, 12]) {
          final g = BarrelGeometry(280, n);
          expect(g.holes.length, n);
          for (final h in g.holes) {
            expect(h.center.dy, inExclusiveRange(g.topY, g.bottomY));
            expect((h.center.dx - g.cx).abs(), lessThan(g.rxAt(h.center.dy)));
          }
        }
      },
    );
  });

  testWidgets('tapping a free hole on my turn sends the pick once', (
    tester,
  ) async {
    await pumpScreen(tester, stateMap());
    await tester.tap(find.byKey(const ValueKey('pirate-hole-3')));
    await tester.pump();
    expect(PirateController.instance.sendingPick, isTrue);
    PirateController.instance.sendingPick = false;
  });

  group('risk gauge', () {
    testWidgets('shows riskPct and remaining holes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PirateRiskGauge(
              theme: GameTheme.pirateNight,
              riskPct: 33,
              remaining: 3,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('남은 구멍 3개'), findsOneWidget);
      expect(find.bySemanticsLabel('폭탄 확률 33퍼센트, 남은 구멍 3개'), findsOneWidget);
    });

    testWidgets('screen gauge follows the server riskPct', (tester) async {
      await pumpScreen(
        tester,
        stateMap(slots: 8, picked: const [0, 1, 2, 3, 4, 5]),
      );
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('남은 구멍 2개'), findsOneWidget);
    });

    test('pirate mood rises with risk', () {
      expect(pirateMoodFor(13), PirateMood.calm);
      expect(pirateMoodFor(20), PirateMood.worried);
      expect(pirateMoodFor(33), PirateMood.sweaty);
      expect(pirateMoodFor(50), PirateMood.scream);
      expect(pirateMoodFor(100), PirateMood.scream);
    });
  });

  group('penalty input', () {
    test('validation: trimmed, 1..30 characters, never empty', () {
      expect(validatePiratePenalty(''), isNotNull);
      expect(validatePiratePenalty('    '), isNotNull);
      expect(validatePiratePenalty('가' * 30), isNull);
      expect(validatePiratePenalty('가' * 31), isNotNull);
      expect(validatePiratePenalty('  노래 한 소절 '), isNull);
      expect(normalizePiratePenalty('  노래\n한   소절 '), '노래 한 소절');
      expect(kPiratePenaltyPresets.length, 10);
      for (final p in kPiratePenaltyPresets) {
        expect(validatePiratePenalty(p), isNull);
      }
    });

    testWidgets(
      'send is disabled until valid, input stops at 30, chips fill the field',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final sent = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PiratePenaltyPicker(
                  theme: GameTheme.pirateNight,
                  loserName: '하늘',
                  onSubmit: (text) {
                    sent.add(text);
                    return null;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final p in kPiratePenaltyPresets) {
          expect(find.text(p), findsOneWidget);
        }
        final send = find.byKey(const ValueKey('pirate-penalty-send'));
        await tester.tap(send);
        expect(sent, isEmpty, reason: 'empty penalty cannot be sent');

        final input = find.byKey(const ValueKey('pirate-penalty-input'));
        await tester.enterText(input, '     ');
        await tester.pump();
        await tester.tap(send);
        expect(sent, isEmpty, reason: 'spaces only cannot be sent');

        await tester.enterText(input, '가' * 35);
        await tester.pump();
        expect(tester.widget<TextField>(input).controller!.text.length, 30);

        await tester.tap(find.text('딱밤 한 대'));
        await tester.pump();
        expect(tester.widget<TextField>(input).controller!.text, '딱밤 한 대');
        await tester.tap(send);
        await tester.pump();
        expect(sent, ['딱밤 한 대']);
      },
    );

    testWidgets('winner sees the picker after a restored explosion', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateMap(
          phase: 'exploded',
          picked: const [2],
          bombSlot: 2,
          winner: me,
          loser: partner,
        ),
      );
      expect(find.text('벌칙을 정해 주세요'), findsOneWidget);
      expect(find.text('하늘에게 줄 벌칙을 고르거나 직접 적어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'live bomb stab: knife drop, explosion, then the penalty phase opens',
    (tester) async {
      await pumpScreen(tester, stateMap(gameId: 'live', slots: 6, seq: 0));
      expect(find.text('벌칙을 정해 주세요'), findsNothing);
      PirateController.instance.apply(
        PirateState.fromMap(
          stateMap(
            gameId: 'live',
            slots: 6,
            picked: const [4],
            phase: 'exploded',
            bombSlot: 4,
            winner: partner,
            loser: me,
            seq: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('하늘이 벌칙을 고르는 중…'),
        findsNothing,
        reason: 'the penalty phase waits for the explosion',
      );
      await tester.pump(const Duration(milliseconds: 400)); // 칼이 꽂히고 폭발 시작
      expect(find.text('펑!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1800)); // 폭발 끝
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('하늘이 벌칙을 고르는 중…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('loser views', () {
    testWidgets('loser waits while the winner picks', (tester) async {
      await pumpScreen(
        tester,
        stateMap(
          phase: 'exploded',
          picked: const [5],
          bombSlot: 5,
          winner: partner,
          loser: me,
        ),
      );
      expect(find.text('하늘이 벌칙을 고르는 중…'), findsOneWidget);
      expect(find.text('벌칙을 정해 주세요'), findsNothing);
      expect(find.textContaining('PARTNER-CODE'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loser gets the big penalty card with a done button', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateMap(
          phase: 'exploded',
          picked: const [5],
          bombSlot: 5,
          winner: partner,
          loser: me,
          penalty: {'text': '아이스크림 사기', 'by': partner, 'doneAt': null},
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('pirate-penalty-card')), findsOneWidget);
      expect(find.text('아이스크림 사기'), findsOneWidget);
      expect(find.byKey(const ValueKey('pirate-penalty-done')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a finished penalty opens the result with series and rematch', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        stateMap(
          phase: 'exploded',
          picked: const [5],
          bombSlot: 5,
          winner: partner,
          loser: me,
          penalty: {'text': '10분 안마', 'by': partner, 'doneAt': 1},
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('해적이 날아갔어요'), findsOneWidget);
      expect(find.text('한 판 더!'), findsOneWidget);
      expect(find.text('벌칙: 10분 안마'), findsOneWidget);
      expect(find.text('이번 방 전적'), findsOneWidget);
    });
  });

  group('controller', () {
    test('counts live stabs and explosions, not restored ones', () {
      final c = PirateController.instance;
      c.apply(PirateState.fromMap(stateMap(gameId: 'x', seq: 0)));
      final stab0 = c.stabSerial;
      final boom0 = c.explosionSerial;
      c.apply(
        PirateState.fromMap(
          stateMap(
            gameId: 'x',
            picked: const [3],
            currentTurn: partner,
            seq: 1,
          ),
        ),
      );
      expect(c.stabSerial, stab0 + 1);
      expect(c.lastStab?.slot, 3);
      c.apply(
        PirateState.fromMap(
          stateMap(
            gameId: 'x',
            picked: const [3, 4],
            phase: 'exploded',
            bombSlot: 4,
            winner: me,
            loser: partner,
            seq: 2,
          ),
        ),
      );
      expect(c.explosionSerial, boom0 + 1);
      // 다른 판이 이미 터진 채로 오면(복원) 폭발 연출은 세지 않는다.
      c.apply(
        PirateState.fromMap(
          stateMap(
            gameId: 'y',
            phase: 'exploded',
            bombSlot: 0,
            winner: me,
            loser: partner,
          ),
        ),
      );
      expect(c.explosionSerial, boom0 + 1);
      // 늦게 온 옛 상태는 무시
      c.apply(PirateState.fromMap(stateMap(gameId: 'y', seq: -1)));
      expect(c.state!.exploded, isTrue);
    });

    test('deadline covers the lobby countdown on the first turn', () {
      final s = PirateState.fromMap({
        ...stateMap(),
        'turnDeadline': 100000 + 25300,
        'serverNow': 100000,
      });
      expect(s.deadline!.total.inMilliseconds, 25300);
    });

    test('names never fall back to raw user codes', () {
      final c = PirateController.instance;
      expect(c.displayName(partner), '하늘');
      expect(c.displayName('UNKNOWN-CODE'), '상대');
    });

    test('josa follows the final consonant', () {
      expect(josaIGa('하늘'), '이');
      expect(josaIGa('바다'), '가');
      expect(josaIGa('Sam'), '이(가)');
    });
  });
}
