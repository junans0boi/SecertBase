// 제로 2.0 화면: 휴대폰 폭에 맞고, 예측 칩이 내 숫자에 따라 범위가 바뀌며,
// 공개 때 "3 + 2 = 5" 계산과 판정 한 줄이 나온다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/rps_screen.dart';
import 'package:secret_base_app/screens/arcade/games/zero/zero_controller.dart';
import 'package:secret_base_app/screens/arcade/games/zero/zero_models.dart';
import 'package:secret_base_app/screens/arcade/games/zero/zero_reveal.dart';
import 'package:secret_base_app/screens/arcade/games/zero/zero_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> zeroState({
  int round = 1,
  String status = 'playing',
  bool suddenDeath = false,
  Map<String, int> scores = const {'A': 0, 'B': 0},
  Map<String, bool> submitted = const {'A': false, 'B': false},
  List<Map<String, dynamic>> history = const [],
  Map<String, dynamic>? result,
  String gameId = 'g1',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'gameId': gameId,
    'gameType': 'zero',
    'status': status,
    'players': ['A', 'B'],
    'round': round,
    'maxRounds': 5,
    'suddenDeath': suddenDeath,
    'suddenDeathRounds': 0,
    'suddenDeathCap': 5,
    'scores': scores,
    'submitted': submitted,
    'autoPicks': {'A': 0, 'B': 0},
    'turnDeadline': status == 'playing' ? now + 20000 : null,
    'turnMs': 20000,
    'serverNow': now,
    'lastRound': history.isEmpty ? null : history.last,
    'history': history,
    'result': result,
    'series': {
      'wins': {'A': 0, 'B': 0},
      'draws': 0,
      'games': 0,
    },
  };
}

Map<String, dynamic> roundRecord({
  int round = 1,
  int fa = 3,
  int fb = 2,
  int ga = 6,
  int gb = 5,
  bool suddenDeath = false,
}) {
  final total = fa + fb;
  final da = (ga - total).abs();
  final db = (gb - total).abs();
  final pa = da == 0 ? 2 : (db != 0 && da < db ? 1 : 0);
  final pb = db == 0 ? 2 : (da != 0 && db < da ? 1 : 0);
  return {
    'round': round,
    'suddenDeath': suddenDeath,
    'fingers': {'A': fa, 'B': fb},
    'guesses': {'A': ga, 'B': gb},
    'total': total,
    'distance': {'A': da, 'B': db},
    'exact': {'A': da == 0, 'B': db == 0},
    'points': {'A': pa, 'B': pb},
    'auto': {'A': false, 'B': false},
    'roundWinner': pa > pb ? 'A' : (pb > pa ? 'B' : 'draw'),
    'scores': {'A': pa, 'B': pb},
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'howto_zero_v2': true});
    final socket = SocketService();
    socket.userId = 'A';
    socket.presenceNicknames = {'B': '준호'};
    socket.profileEmojis = {'A': '🐰', 'B': '🐻'};
  });

  tearDown(() {
    ZeroController.instance.clearForTest();
    final socket = SocketService();
    socket.userId = null;
    socket.presenceNicknames = {};
    socket.profileEmojis = {};
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(360, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('waits for the server game without a start button', (
    tester,
  ) async {
    await pump(tester, const ZeroScreen());
    expect(find.text('판을 준비하는 중'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  for (final size in const [Size(360, 640), Size(360, 760), Size(430, 900)]) {
    testWidgets('picking screen fits ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      ZeroController.instance.applyState(zeroState());
      await pump(tester, const ZeroScreen(), size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('라운드 1/5'), findsOneWidget);
      expect(find.text('제출!'), findsOneWidget);
      expect(find.text('먼저 낼 손가락을 골라요'), findsOneWidget);
      for (int n = 0; n <= 5; n++) {
        expect(find.bySemanticsLabel('손가락 $n개'), findsOneWidget);
      }
      expect(find.text('준호'), findsWidgets);
      expect(find.textContaining('A'), findsNothing, reason: 'no raw codes');
      await finish(tester);
    });
  }

  testWidgets('guess chips follow my fingers: only fingers..fingers+5', (
    tester,
  ) async {
    ZeroController.instance.applyState(zeroState());
    await pump(tester, const ZeroScreen());
    await tester.tap(find.bySemanticsLabel('손가락 3개'));
    await tester.pump(const Duration(milliseconds: 300));
    for (int g = 3; g <= 8; g++) {
      expect(find.byKey(ValueKey('zero-guess-$g')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('zero-guess-2')), findsNothing);
    expect(find.byKey(const ValueKey('zero-guess-9')), findsNothing);
    expect(find.text('합계 예측 · 3 ~ 8'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('zero-guess-8')));
    await tester.pump(const Duration(milliseconds: 200));
    // 더 작은 숫자로 바꾸면 범위를 벗어난 예측(8)은 풀린다.
    await tester.tap(find.bySemanticsLabel('손가락 0개'));
    await tester.pump(const Duration(milliseconds: 300));
    for (int g = 0; g <= 5; g++) {
      expect(find.byKey(ValueKey('zero-guess-$g')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('zero-guess-6')), findsNothing);
    expect(find.byKey(const ValueKey('zero-guess-8')), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('submitting shows my summary while the partner chooses', (
    tester,
  ) async {
    ZeroController.instance.applyState(zeroState());
    await pump(tester, const ZeroScreen());
    await tester.tap(find.bySemanticsLabel('손가락 2개'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('zero-guess-4')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('제출!'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('내 손 2 · 예측 4'), findsOneWidget);
    expect(find.text('상대가 고르는 중이에요…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
    'reveal counts the hands and shows "3 + 2 = 5" with the verdict',
    (tester) async {
      final c = ZeroController.instance;
      c.applyState(zeroState());
      await pump(tester, const ZeroScreen());
      c.applyState(
        zeroState(
          round: 2,
          scores: {'A': 0, 'B': 2},
          history: [roundRecord(fa: 3, fb: 2, ga: 6, gb: 5)],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('하나~'), findsOneWidget);
      expect(find.text('3 + 2 = 5'), findsNothing);
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.text('3 + 2 = 5'), findsOneWidget);
      expect(find.text('하나~'), findsNothing);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('준호 정확히 적중! +2'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 100));
      // 연출이 끝나면 다음 라운드 선택으로 돌아온다.
      expect(find.text('3 + 2 = 5'), findsNothing);
      expect(find.text('라운드 2/5'), findsOneWidget);
      expect(find.text('제출!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('sudden death shows the last-round badge', (tester) async {
    ZeroController.instance.applyState(
      zeroState(round: 6, suddenDeath: true, scores: {'A': 3, 'B': 3}),
    );
    await pump(tester, const ZeroScreen());
    expect(find.text('마지막 한 판!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('a finished game shows the result with the series and rematch', (
    tester,
  ) async {
    ZeroController.instance.applyState(
      zeroState(
        status: 'finished',
        round: 6,
        scores: {'A': 5, 'B': 3},
        history: [roundRecord(round: 5, fa: 1, fb: 1, ga: 2, gb: 6)],
        result: {'winner': 'A', 'loser': 'B', 'draw': false, 'reason': 'score'},
      ),
    );
    await pump(tester, const ZeroScreen());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('승리!'), findsOneWidget);
    expect(find.text('5라운드 합산 5 : 3'), findsOneWidget);
    expect(find.text('한 판 더!'), findsOneWidget);
    expect(find.text('이번 방 전적'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
    'the old arcade entry RpsScreen(fixedMode: hanabagi) opens zero',
    (tester) async {
      await pump(tester, const RpsScreen(fixedMode: 'hanabagi'));
      expect(find.byType(ZeroScreen), findsOneWidget);
      expect(find.text('판을 준비하는 중'), findsOneWidget);
      await finish(tester);
    },
  );

  test('verdict line distinguishes exact, closer and same distance', () {
    String name(String? id) => id == 'A' ? '나' : '준호';
    ZeroRound r(Map<String, dynamic> m) => ZeroRound.fromMap(m)!;
    expect(
      zeroVerdict(r(roundRecord(ga: 5, gb: 7)), 'A', 'B', name),
      '나 정확히 적중! +2',
    );
    expect(
      zeroVerdict(r(roundRecord(fa: 1, fb: 3, ga: 4, gb: 4)), 'A', 'B', name),
      '둘 다 정확히 적중! 각각 +2',
    );
    expect(
      zeroVerdict(r(roundRecord(fa: 1, fb: 4, ga: 3, gb: 9)), 'A', 'B', name),
      '둘 다 빗나갔어요 · 나, 2 차이로 더 가까워요 +1',
    );
    expect(
      zeroVerdict(r(roundRecord(fa: 2, fb: 2, ga: 3, gb: 5)), 'A', 'B', name),
      '둘 다 같은 거리 · 이번엔 무득점',
    );
    expect(zeroGuessOptions(4), [4, 5, 6, 7, 8, 9]);
  });
}
