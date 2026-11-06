// 텔레파시 2.0 화면: 시작 버튼 없이 서버 판을 기다리고, 휴대폰 폭에 맞고, A/B 카드를 눌러 고르면
// 서버에 pick을 보내며, 공개 때 두 카드가 뒤집혀 통함/엇갈림이 나오고, 결과에 문제별 선택이 보인다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';
import 'package:secret_base_app/screens/arcade/games/telepathy/telepathy_controller.dart';
import 'package:secret_base_app/screens/arcade/games/telepathy/telepathy_models.dart';
import 'package:secret_base_app/screens/arcade/games/telepathy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> question({
  String id = 'food-001',
  String a = '짜장면',
  String b = '짬뽕',
  String ea = '🥢',
  String eb = '🌶️',
}) => {
  'id': id,
  'cat': 'food',
  'a': a,
  'b': b,
  'emojiA': ea,
  'emojiB': eb,
  'spicy': false,
};

Map<String, dynamic> record({
  int round = 1,
  String pa = 'A',
  String? pb = 'A',
  int streak = 1,
  int score = 1,
  Map<String, dynamic>? q,
}) {
  final matched = pa == pb && pb != null;
  return {
    'round': round,
    'question': q ?? question(),
    'picks': {'A': pa, 'B': pb},
    'matched': matched,
    'outcome': matched ? 'match' : (pb == null ? 'timeout' : 'miss'),
    'streak': matched ? streak : 0,
    'score': score,
  };
}

Map<String, dynamic> tState({
  int round = 1,
  int rounds = 10,
  String status = 'playing',
  Map<String, bool> picked = const {'A': false, 'B': false},
  List<Map<String, dynamic>> history = const [],
  Map<String, dynamic>? result,
  String gameId = 'g1',
  Map<String, dynamic>? q,
  String? myPick,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return {
    'gameId': gameId,
    'gameType': 'telepathy',
    'status': status,
    'players': ['A', 'B'],
    'round': round,
    'rounds': rounds,
    'spicy': false,
    'question': status == 'playing' ? (q ?? question()) : null,
    'picked': picked,
    'timeouts': {'A': 0, 'B': 0},
    'turnDeadline': status == 'playing' ? now + 15000 : null,
    'turnMs': 15000,
    'revealUntil': null,
    'revealMs': 3500,
    'score': history.where((h) => h['matched'] == true).length,
    'streak': 0,
    'bestStreak': 0,
    'serverNow': now,
    'lastRound': history.isEmpty ? null : history.last,
    'history': history,
    'result': result,
    'series': {
      'games': 0,
      'matches': 0,
      'questions': 0,
      'ratio': 0,
      'bestStreak': 0,
      'bestMatches': 0,
    },
    'myPick': ?myPick,
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'howto_telepathy_v2': true});
    final socket = SocketService();
    socket.userId = 'A';
    socket.presenceNicknames = {'B': '준호'};
    socket.profileEmojis = {'A': '🐰', 'B': '🐻'};
  });

  tearDown(() {
    TelepathyController.instance.clearForTest();
    final socket = SocketService();
    socket.userId = null;
    socket.presenceNicknames = {};
    socket.profileEmojis = {};
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(360, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TelepathyScreen()));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('waits for the server game without a start button', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('판을 준비하는 중'), findsOneWidget);
    expect(find.textContaining('시작'), findsNothing);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  for (final size in const [
    Size(360, 640),
    Size(360, 760),
    Size(430, 900),
    Size(1000, 700),
  ]) {
    testWidgets('picking screen fits ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      TelepathyController.instance.applyState(
        tState(
          q: question(a: '가나다라마바사아자차카타파하', b: '아주 긴 선택지를 가진 보기예요'),
        ),
      );
      await pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('1/10번째'), findsOneWidget);
      expect(find.text('마음이 끌리는 쪽을 눌러 주세요'), findsOneWidget);
      expect(find.bySemanticsLabel('선택지 A, 가나다라마바사아자차카타파하'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(find.text('준호'), findsWidgets);
      expect(
        find.text('A'),
        findsOneWidget,
        reason: 'card letter only, no raw code',
      );
      for (final card in ['A', 'B']) {
        final r = tester.getRect(find.bySemanticsLabel(RegExp('선택지 $card')));
        expect(r.height, greaterThanOrEqualTo(44));
      }
      await finish(tester);
    });
  }

  testWidgets('tapping a card sends pick with round and game id and marks it', (
    tester,
  ) async {
    TelepathyController.instance.applyState(tState());
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('선택지 B, 짬뽕'));
    await tester.pump(const Duration(milliseconds: 300));
    final c = TelepathyController.instance;
    expect(c.myPick, 'B');
    expect(c.myPickRound, 1);
    expect(find.text('내 선택'), findsOneWidget);
    expect(find.text('상대가 고르는 중이에요…'), findsOneWidget);
    expect(find.text('골랐어요'), findsOneWidget);
    // 두 번 눌러도 다시 고를 수 없다.
    await tester.tap(find.bySemanticsLabel('선택지 A, 짜장면'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.myPick, 'B');
    await finish(tester);
  });

  testWidgets(
    'the partner pick is shown as chosen without revealing the side',
    (tester) async {
      TelepathyController.instance.applyState(
        tState(picked: const {'A': false, 'B': true}),
      );
      await pump(tester);
      expect(find.text('골랐어요'), findsOneWidget);
      expect(find.text('내 선택'), findsNothing);
      await finish(tester);
    },
  );

  testWidgets(
    'a matching reveal flips both cards, shows the verdict and the streak',
    (tester) async {
      final c = TelepathyController.instance;
      c.applyState(tState());
      await pump(tester);
      c.applyState(
        tState(
          round: 2,
          q: question(id: 'food-002', a: '피자', b: '햄버거', ea: '🍕', eb: '🍔'),
          history: [record(round: 1, pa: 'B', pb: 'B', streak: 3, score: 3)],
        ),
      );
      await tester.pump();
      // 연출 중에는 방금 푼 문제가 계속 보인다.
      expect(find.bySemanticsLabel('선택지 B, 짬뽕'), findsOneWidget);
      expect(find.text('두 사람의 선택을 공개해요…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('🔥 3연속'), findsOneWidget);
      expect(find.text('통했어요! 3문제 연속이에요'), findsOneWidget);
      expect(find.bySemanticsLabel('🐰이(가) 고른 쪽'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 500));
      // 다음 문제.
      expect(find.bySemanticsLabel('선택지 A, 피자'), findsOneWidget);
      expect(find.text('2/10번째'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  testWidgets('a miss and a timeout are worded differently', (tester) async {
    final c = TelepathyController.instance;
    c.applyState(tState());
    await pump(tester);
    c.applyState(
      tState(
        round: 2,
        history: [record(round: 1, pa: 'A', pb: 'B', score: 0)],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('엇갈림'), findsOneWidget);
    expect(find.text('이번엔 엇갈렸어요. 다음엔 통할 거예요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2400));
    c.applyState(
      tState(
        round: 3,
        history: [
          record(round: 1, pa: 'A', pb: 'B', score: 0),
          record(round: 2, pa: 'A', pb: null, score: 0),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('시간 초과'), findsOneWidget);
    expect(find.text('시간이 지나 이번 문제는 넘어가요'), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'a game that is already in progress does not replay old reveals',
    (tester) async {
      TelepathyController.instance.applyState(
        tState(
          round: 4,
          history: [
            record(round: 1),
            record(round: 2, pa: 'A', pb: 'B', score: 1),
            record(round: 3, score: 2),
          ],
        ),
      );
      await pump(tester);
      expect(find.text('두 사람의 선택을 공개해요…'), findsNothing);
      expect(find.text('4/10번째'), findsOneWidget);
      expect(find.text('통한 2'), findsOneWidget);
      await finish(tester);
    },
  );

  testWidgets(
    'the result shows the tier, matches, best streak and each question',
    (tester) async {
      final c = TelepathyController.instance;
      final history = [
        record(round: 1, pa: 'A', pb: 'A', streak: 1, score: 1),
        record(
          round: 2,
          pa: 'A',
          pb: 'B',
          score: 1,
          q: question(
            id: 'date-001',
            a: '집 데이트',
            b: '밖 데이트',
            ea: '🏠',
            eb: '🌆',
          ),
        ),
      ];
      c.applyState(tState(rounds: 2));
      await pump(tester);
      final done = tState(
        status: 'finished',
        rounds: 2,
        round: 2,
        history: history,
        result: {
          'reason': 'complete',
          'awayPlayer': null,
          'matches': 1,
          'total': 2,
          'played': 2,
          'bestStreak': 1,
          'tier': {'id': 'learning', 'label': '알아가는 중'},
        },
      );
      done['series'] = {
        'games': 2,
        'matches': 11,
        'questions': 15,
        'ratio': 73,
        'bestStreak': 5,
        'bestMatches': 8,
      };
      c.applyState(done);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('알아가는 중'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('🔥 1'), findsOneWidget);
      expect(find.textContaining('짜장면'), findsWidgets);
      expect(find.textContaining('나 짜장면'), findsOneWidget);
      expect(find.textContaining('준호 밖 데이트'), findsOneWidget);
      expect(find.text('이번 방 2판 · 통한 비율 73% · 최고 연속 5'), findsOneWidget);
      expect(find.text('한 판 더!'), findsOneWidget);
      expect(find.textContaining('승리'), findsNothing);
      expect(tester.takeException(), isNull);
      await finish(tester);
    },
  );

  test('state parsing keeps unknown picks as timeouts', () {
    final s = TelepathyState.fromMap(
      tState(history: [record(round: 1, pa: 'A', pb: null)]),
    );
    expect(s.history.single.picks['B'], isNull);
    expect(s.history.single.timedOut, isTrue);
    expect(s.question?.emojiOf('B'), '🌶️');
    expect(s.opponentOf('A'), 'B');
  });
}
