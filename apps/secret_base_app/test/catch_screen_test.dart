// 그림 맞히기 2.0 화면: 휴대폰 폭에서 넘치지 않고, 보드는 4:3으로 고정되며 키보드에도 줄지 않고,
// 도구 상태·한 손가락 그리기·점 찍기·획 묶음 전송·되돌리기·전체 지우기 확인·결과 갤러리를 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/catch/catch_controller.dart';
import 'package:secret_base_app/screens/arcade/games/catch/catch_input.dart';
import 'package:secret_base_app/screens/arcade/games/catch/catch_models.dart';
import 'package:secret_base_app/screens/arcade/games/catch/catch_paint.dart';
import 'package:secret_base_app/screens/arcade/games/catch_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> catchState({
  int round = 1,
  String drawer = 'A',
  String phase = 'drawing',
  String status = 'playing',
  String word = '고양이',
  List<String>? hint,
  Map<String, int> scores = const {'A': 0, 'B': 0},
  List<Map<String, dynamic>> history = const [],
  List<Map<String, dynamic>> gallery = const [],
  Map<String, dynamic>? result,
  String gameId = 'g1',
  bool secret = true,
  bool canHint = true,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final me = SocketService().userId;
  final revealed = phase != 'drawing' || status == 'finished';
  return {
    'gameId': gameId,
    'gameType': 'catch',
    'status': status,
    'phase': phase,
    'players': ['A', 'B'],
    'round': round,
    'maxRounds': 6,
    'drawer': drawer,
    'category': '동물',
    'wordLen': word.characters.length,
    'difficulty': 1,
    'hint': hint ?? List.filled(word.characters.length, ''),
    'canHint': canHint,
    'directHint': false,
    if (revealed || (secret && drawer == me)) 'word': word,
    'roundStartsAt': now,
    'turnDeadline': phase == 'drawing' ? now + 60000 : null,
    'roundMs': 60000,
    'revealUntil': phase == 'reveal' ? now + 6000 : null,
    'revealMs': 6000,
    'scores': scores,
    'guesses': <Map<String, dynamic>>[],
    'history': history,
    'result': result,
    'series': {
      'wins': {'A': 1, 'B': 0},
      'draws': 0,
      'games': 1,
    },
    'serverNow': now,
    if (gallery.isNotEmpty) 'gallery': gallery,
  };
}

Map<String, dynamic> record(
  int round, {
  String word = '고양이',
  String outcome = 'correct',
  String drawer = 'A',
  String? guesser = 'B',
}) => {
  'round': round,
  'drawer': drawer,
  'word': word,
  'category': '동물',
  'outcome': outcome,
  'guesser': outcome == 'correct' ? guesser : null,
  'points': {
    'A': outcome == 'correct' ? 2 : 0,
    'B': outcome == 'correct' ? 5 : 0,
  },
  'timeLeftMs': 30000,
  'usedHint': false,
  'scores': {'A': 2, 'B': 5},
};

Map<String, dynamic> strokeMap(
  String id, {
  int color = 3,
  String tool = 'pen',
}) => {
  'id': id,
  'tool': tool,
  'color': color,
  'w': 0.016,
  'pts': [
    [0.1, 0.1],
    [0.4, 0.3],
    [0.7, 0.6],
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'howto_catch_v2': true});
    final socket = SocketService();
    socket.userId = 'A';
    socket.presenceNicknames = {'A': '민지', 'B': '준호'};
    socket.profileEmojis = {'A': '🐰', 'B': '🐻'};
  });

  tearDown(() {
    CatchController.instance.clearForTest();
    final socket = SocketService();
    socket.userId = null;
    socket.presenceNicknames = {};
    socket.profileEmojis = {};
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(360, 760),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CatchScreen()));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Rect paperRect(WidgetTester tester) =>
      tester.getRect(find.byKey(const ValueKey('catch-strokes')));

  testWidgets('waits for the server game without a start button', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('스케치북을 펼치는 중…'), findsOneWidget);
    expect(find.textContaining('게임 시작'), findsNothing);
    expect(find.textContaining('시작하기'), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  for (final size in const [
    Size(360, 640),
    Size(360, 780),
    Size(430, 932),
    Size(1280, 800),
  ]) {
    testWidgets(
      'drawer screen fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        CatchController.instance.applyState(catchState());
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
        // 4:3 고정.
        final paper = paperRect(tester);
        expect(paper.width / paper.height, closeTo(4 / 3, 0.01));
        expect(find.byKey(const ValueKey('catch-sketchbook')), findsOneWidget);
        // 12색 팔레트, 모두 44px 이상.
        for (var i = 0; i < 12; i++) {
          final r = tester.getRect(find.byKey(ValueKey('swatch-$i')));
          expect(r.height, greaterThanOrEqualTo(43.9), reason: 'swatch $i');
          expect(r.width, greaterThanOrEqualTo(43.9), reason: 'swatch $i');
        }
        // 제시어는 그리는 사람에게 보인다.
        expect(find.bySemanticsLabel('제시어 고양이'), findsOneWidget);
        expect(find.text('나 (나)'), findsOneWidget);
        expect(find.text('준호'), findsOneWidget);
        expect(find.textContaining('A'), findsNothing, reason: 'no raw codes');
        expect(find.textContaining('게임 시작'), findsNothing);
        await finish(tester);
      },
    );

    testWidgets(
      'guesser screen fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        CatchController.instance.applyState(
          catchState(drawer: 'B', hint: ['', '양', '']),
        );
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
        final paper = paperRect(tester);
        expect(paper.width / paper.height, closeTo(4 / 3, 0.01));
        expect(find.byKey(const ValueKey('catch-guess-field')), findsOneWidget);
        expect(find.bySemanticsLabel('3글자, 열린 글자 양'), findsOneWidget);
        expect(find.text('고양이'), findsNothing, reason: 'the word stays secret');
        expect(find.byKey(const ValueKey('swatch-0')), findsNothing);
        await finish(tester);
      },
    );
  }

  testWidgets('the board keeps its size when the keyboard opens', (
    tester,
  ) async {
    CatchController.instance.applyState(catchState(drawer: 'B'));
    await pump(tester, size: const Size(360, 740));
    final before = paperRect(tester);
    final inputBefore = tester.getRect(
      find.byKey(const ValueKey('catch-guess-field')),
    );
    await finish(tester);

    await pump(tester, size: const Size(360, 740), keyboard: 320);
    final after = paperRect(tester);
    expect(after.size, before.size, reason: 'the board must not shrink');
    expect(after.topLeft, before.topLeft);
    final inputAfter = tester.getRect(
      find.byKey(const ValueKey('catch-guess-field')),
    );
    expect(inputAfter.bottom, lessThanOrEqualTo(740 - 320));
    expect(
      inputAfter.top,
      lessThan(inputBefore.top),
      reason: 'the input floats above the keyboard',
    );
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
    'tool state: eraser, colour, size and the colour tap returning to the pencil',
    (tester) async {
      CatchController.instance.applyState(catchState());
      await pump(tester);
      Finder selected(String key) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Container),
      );
      expect(selected('tool-pen'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('tool-eraser')));
      await tester.pump(const Duration(milliseconds: 200));
      // 지우개일 때는 색 칸에 선택 표시(체크)가 없다.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.tap(find.byKey(const ValueKey('swatch-4')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byIcon(Icons.check_rounded),
        findsOneWidget,
        reason: 'colour tap = back to the pencil',
      );
      await tester.tap(find.byKey(const ValueKey('tool-marker')));
      await tester.tap(find.byKey(const ValueKey('size-2')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'a tap leaves a dot, a drag a line, and the second finger is ignored',
    (tester) async {
      CatchController.instance.applyState(catchState());
      await pump(tester);
      final model = CatchController.instance.canvas;
      final paper = paperRect(tester);

      await tester.tapAt(paper.center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(model.strokes.length, 1);
      expect(model.strokes.first.isDot, true, reason: 'tap = dot');
      expect(model.strokes.first.open, false);

      final g1 = await tester.startGesture(
        paper.topLeft + const Offset(30, 30),
      );
      final g2 = await tester.startGesture(
        paper.topLeft + const Offset(200, 120),
      );
      await g1.moveTo(paper.topLeft + const Offset(60, 50));
      await g2.moveTo(paper.topLeft + const Offset(240, 150));
      await g1.moveTo(paper.topLeft + const Offset(110, 90));
      await g1.up();
      await g2.up();
      await tester.pump(const Duration(milliseconds: 80));
      expect(model.strokes.length, 2, reason: 'one pointer only');
      expect(model.strokes.last.pts.length, greaterThanOrEqualTo(3));
      expect(model.strokes.last.tool, CatchTool.pen);
      expect(CatchController.instance.undoStack.length, 2);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('undo removes the last stroke; clear-all asks first', (
    tester,
  ) async {
    CatchController.instance.applyState(catchState());
    await pump(tester);
    final model = CatchController.instance.canvas;
    final paper = paperRect(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(paper.topLeft + Offset(40.0 + i * 60, 60));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(model.strokes.length, 3);
    await tester.tap(find.byKey(const ValueKey('catch-undo')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(model.strokes.length, 2);
    // 연결이 없는 테스트라 보낸 요청이 안내 막대를 띄운다. 사라질 때까지 기다린다.
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('catch-clear')));
    await tester.pumpAndSettle();
    expect(find.text('그림을 모두 지울까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(model.strokes.length, 2, reason: 'cancel keeps the drawing');
    expect(find.text('그림을 모두 지울까요?'), findsNothing, reason: 'dialog closed');

    await tester.tap(find.byKey(const ValueKey('catch-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catch-clear-confirm')));
    await tester.pumpAndSettle();
    expect(model.strokes, isEmpty);
    expect(CatchController.instance.undoStack, isEmpty);
    await finish(tester);
  });

  testWidgets('the guesser cannot draw and sees the partner strokes live', (
    tester,
  ) async {
    CatchController.instance.applyState(catchState(drawer: 'B'));
    await pump(tester);
    final model = CatchController.instance.canvas;
    final paper = paperRect(tester);
    await tester.dragFrom(paper.center, const Offset(60, 20));
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.strokes, isEmpty, reason: 'only the drawer can draw');
    expect(find.text('준호님이 그리는 중…'), findsOneWidget);

    CatchController.instance.applyRemoteStroke({
      'round': 1,
      'id': 'r1',
      'seq': 0,
      'tool': 'pen',
      'color': 1,
      'w': 0.016,
      'pts': [
        [0.1, 0.1],
        [0.2, 0.2],
      ],
      'end': false,
    });
    CatchController.instance.applyRemoteStroke({
      'round': 1,
      'id': 'r1',
      'seq': 1,
      'tool': 'pen',
      'color': 1,
      'w': 0.016,
      'pts': [
        [0.3, 0.3],
      ],
      'end': true,
    });
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.strokes.length, 1);
    expect(model.strokes.first.pts.length, 3);
    expect(model.strokes.first.open, false);
    expect(find.text('준호님이 그리는 중…'), findsNothing);
    await finish(tester);
  });

  testWidgets('guess bubbles show for both players, the drawer included', (
    tester,
  ) async {
    CatchController.instance.applyState(catchState());
    await pump(tester);
    CatchController.instance.applyGuess({
      'id': 'x1',
      'round': 1,
      'userId': 'B',
      'text': '강아지',
      'verdict': 'wrong',
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('강아지'), findsOneWidget);
    CatchController.instance.applyGuess({
      'id': 'x2',
      'round': 1,
      'userId': 'B',
      'text': '고양',
      'verdict': 'close',
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('고양'), findsOneWidget);
    expect(find.text('아까워요!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('고양'), findsNothing, reason: 'bubbles fade away');
    await finish(tester);
  });

  testWidgets('reveal shows the word, the stamp and the points', (
    tester,
  ) async {
    CatchController.instance.applyState(
      catchState(drawer: 'B', phase: 'reveal', scores: {'A': 2, 'B': 5}),
    );
    CatchController.instance.applyRoundResult({
      ...record(1, drawer: 'B', guesser: 'A'),
      'points': {'A': 5, 'B': 2},
      'last': false,
      'revealUntil': DateTime.now().millisecondsSinceEpoch + 6000,
      'serverNow': DateTime.now().millisecondsSinceEpoch,
    });
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('정답!'), findsWidgets);
    expect(find.text('정답은 “고양이”'), findsOneWidget);
    expect(find.text('나 +5'), findsOneWidget);
    expect(find.bySemanticsLabel('제시어 고양이'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'result gallery fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        final items = [
          for (var i = 1; i <= 6; i++)
            {
              ...record(
                i,
                word: i.isEven ? '사과나무' : '고양이',
                outcome: i == 3 ? 'timeout' : 'correct',
              ),
              'strokes': [strokeMap('s$i', color: i)],
            },
        ];
        CatchController.instance.applyState(
          catchState(
            status: 'finished',
            phase: 'over',
            scores: {'A': 12, 'B': 15},
            history: [for (var i = 1; i <= 6; i++) record(i)],
            gallery: items,
            result: {
              'winner': 'B',
              'loser': 'A',
              'draw': false,
              'reason': 'score',
              'scores': {'A': 12, 'B': 15},
            },
          ),
        );
        await pump(tester, size: size);
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        expect(find.text('아쉬운 패배'), findsOneWidget);
        expect(find.text('오늘의 그림'), findsOneWidget);
        expect(find.byKey(const ValueKey('catch-rematch')), findsOneWidget);
        expect(find.text('1. 고양이'), findsOneWidget);
        await finish(tester);
      },
    );
  }

  test(
    'batcher: 33ms batches, instant flush on release, a tap is one end batch',
    () async {
      final batches = <StrokeBatch>[];
      final b = StrokeBatcher(onBatch: batches.add);
      b.start(
        't1',
        tool: CatchTool.pen,
        color: 3,
        w: 0.016,
        first: const Offset(0.1, 0.1),
      );
      b.add(const Offset(0.2, 0.2));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(batches.isNotEmpty, true);
      expect(batches.first.seq, 0);
      expect(batches.first.end, false);
      expect(batches.first.pts.length, 2);
      b.add(const Offset(0.3, 0.3));
      b.end();
      final last = batches.last;
      expect(last.end, true, reason: 'release flushes immediately');
      expect(last.pts.last, const Offset(0.3, 0.3));
      expect(b.active, false);

      batches.clear();
      b.start(
        't2',
        tool: CatchTool.eraser,
        color: 5,
        w: 0.03,
        first: const Offset(0.5, 0.5),
      );
      b.end();
      expect(batches.length, 1);
      expect(batches.single.end, true);
      expect(batches.single.pts, [const Offset(0.5, 0.5)]);
      final payload = batches.single.toPayload(2);
      expect(payload['color'], 0, reason: 'an eraser has no colour');
      expect(payload['round'], 2);
      expect(payload['tool'], 'eraser');

      batches.clear();
      b.start(
        't3',
        tool: CatchTool.pen,
        color: 1,
        w: 0.008,
        first: const Offset(0, 0),
      );
      for (var i = 1; i < 170; i++) {
        b.add(Offset(i / 200, 0.5));
      }
      b.end();
      expect(batches.map((e) => e.pts.length), [80, 80, 10]);
      expect(batches.map((e) => e.end), [false, false, true]);
      expect(batches.map((e) => e.seq), [0, 1, 2]);
    },
  );

  test('both screens draw with the same colour and width', () {
    // 옛 버그: 회색이 상대 화면에서 흰색, 지우개 굵기가 달랐다.
    for (final tool in CatchTool.values) {
      final mine = CatchStroke(id: 'a', tool: tool, color: 1, w: 0.03)
        ..add(const Offset(0.5, 0.5));
      final theirs = CatchStroke.fromMap({...mine.toMap()});
      expect(theirs.color, mine.color);
      expect(theirs.strokeWidth, mine.strokeWidth);
    }
    expect(kCatchPalette.length, 12);
    expect(kCatchPalette[1].color, isNot(const Color(0xFFFFFFFF)));
    expect(kCatchPalette.map((e) => e.color).toSet().length, 12);
    expect(
      catchWidthFactor(CatchTool.eraser),
      greaterThan(catchWidthFactor(CatchTool.pen)),
    );
  });

  test(
    'the cached picture keeps finished strokes and follows undo, clear and replay',
    () {
      final m = CatchCanvasModel();
      addTearDown(m.dispose);
      for (var i = 0; i < 5; i++) {
        final s = CatchStroke(
          id: 's$i',
          tool: CatchTool.pen,
          color: 0,
          w: 0.016,
        )..add(Offset(i / 10, 0.2));
        m.begin(s);
      }
      expect(m.bakedCount, 0);
      expect(m.picture, isNull);
      m.finish('s0');
      expect(m.bakedCount, 1);
      m.finish('s2');
      expect(m.bakedCount, 1, reason: 'order is kept: s1 is still open');
      m.finish('s1');
      expect(m.bakedCount, 3);
      expect(m.picture, isNotNull);
      expect(m.live.length, 2);
      m.remove('s0');
      expect(m.strokes.length, 4);
      expect(m.bakedCount, 2);
      m.replaceAll([CatchStroke.fromMap(strokeMap('r1'))]);
      expect(m.strokes.length, 1);
      expect(m.bakedCount, 1);
      m.clear();
      expect(m.picture, isNull);
      expect(m.isEmpty, true);
      // 24번 넘게 이어 구워도 문제없다.
      for (var i = 0; i < 60; i++) {
        m.begin(
          CatchStroke(id: 'x$i', tool: CatchTool.marker, color: 2, w: 0.03)
            ..add(Offset(0.1, i / 100)),
        );
        m.finish('x$i');
      }
      expect(m.bakedCount, 60);
    },
  );

  test(
    'controller: round change clears the board, guesses are rate limited, replay restores',
    () {
      final c = CatchController.instance;
      c.applyState(catchState());
      c.applyRemoteStroke({
        ...strokeMap('q1'),
        'round': 1,
        'seq': 0,
        'end': true,
      });
      expect(c.canvas.strokes.length, 1);
      c.applyRemoteStroke({
        ...strokeMap('q2'),
        'round': 9,
        'seq': 0,
        'end': true,
      });
      expect(c.canvas.strokes.length, 1, reason: 'other rounds are ignored');
      c.applyRemoteStroke({
        ...strokeMap('q3'),
        'round': 1,
        'seq': 4,
        'end': false,
      });
      expect(
        c.canvas.strokes.length,
        1,
        reason: 'a batch without its start waits for the replay',
      );

      c.applyReplay({
        'round': 1,
        'strokes': [strokeMap('p1'), strokeMap('p2', tool: 'eraser')],
      });
      expect(c.canvas.strokes.map((s) => s.id), ['p1', 'p2']);
      c.applyRemoteUndo({'round': 1, 'id': 'p1'});
      expect(c.canvas.strokes.map((s) => s.id), ['p2']);
      c.applyRemoteClear({'round': 1});
      expect(c.canvas.isEmpty, true);

      c.applyState(catchState(drawer: 'B'));
      expect(c.guess('고양이', now: DateTime(2026)), true);
      expect(
        c.guess(
          '또',
          now: DateTime(2026).add(const Duration(milliseconds: 300)),
        ),
        false,
      );
      expect(
        c.guess(
          '또',
          now: DateTime(2026).add(const Duration(milliseconds: 800)),
        ),
        true,
      );
      expect(c.guess('  ', now: DateTime(2027)), false);

      c.applyRemoteStroke({
        ...strokeMap('z'),
        'round': 1,
        'seq': 0,
        'end': true,
      });
      c.applyState(catchState(drawer: 'B', round: 2));
      expect(
        c.canvas.isEmpty,
        true,
        reason: 'a new round starts on a clean page',
      );
      expect(c.undoStack, isEmpty);
    },
  );

  test(
    'controller: only the drawer undoes, at most 20 strokes are remembered',
    () {
      final c = CatchController.instance;
      c.applyState(catchState());
      expect(c.canUndo, false);
      for (var i = 0; i < 25; i++) {
        c.canvas.begin(
          CatchStroke(id: 'u$i', tool: CatchTool.pen, color: 0, w: 0.016)
            ..add(const Offset(0.1, 0.1)),
        );
        c.canvas.finish('u$i');
        c.strokeDone('u$i');
      }
      expect(c.undoStack.length, kCatchUndoLimit);
      expect(c.undoStack.first, 'u5');
      c.applyState(catchState(drawer: 'B'));
      expect(c.canUndo, false, reason: 'the guesser has nothing to undo');
    },
  );
}
