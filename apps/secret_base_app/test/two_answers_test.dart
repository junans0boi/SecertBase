import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_base_app/features/two_answers/application/two_answers_events.dart';
import 'package:secret_base_app/features/two_answers/data/two_answers_repository.dart';
import 'package:secret_base_app/features/two_answers/domain/two_answer.dart';
import 'package:secret_base_app/features/two_answers/presentation/two_answers_card.dart';
import 'package:secret_base_app/features/two_answers/presentation/two_answers_history_screen.dart';
import 'package:secret_base_app/features/two_answers/presentation/two_answers_screen.dart';
import 'package:secret_base_app/v2/v2.dart';

TwoAnswerCard _card(
  TwoAnswerStatus status, {
  String? mine,
  bool partnerAnswered = false,
  String? partner,
  int streak = 0,
}) => TwoAnswerCard(
  id: 7,
  businessDate: '2026-11-23',
  category: 'daily',
  question: '오늘 하루 중 가장 편했던 순간은?',
  status: status,
  myBody: mine,
  partnerAnswered: partnerAnswered,
  partnerBody: partner,
  streak: streak,
);

class _FakeRepo implements TwoAnswersRepository {
  _FakeRepo(this.current);
  TwoAnswerCard current;
  TwoAnswerCard? afterAnswer;
  final submitted = <String>[];
  int momentSaves = 0;
  List<TwoAnswerCard> missedCards = [];
  List<TwoAnswerCard> historyCards = [];
  final lateAnswers = <String>[];

  @override
  Future<TwoAnswerCard> today() async => current;

  @override
  Future<TwoAnswerCard> answerToday(String body) async {
    submitted.add(body);
    current = afterAnswer ?? _card(TwoAnswerStatus.waiting, mine: body);
    return current;
  }

  @override
  Future<TwoAnswerHistoryPage> history({int? cursor}) async =>
      TwoAnswerHistoryPage(items: historyCards);

  @override
  Future<List<TwoAnswerCard>> missed() async => missedCards;

  @override
  Future<TwoAnswerCard> answerLate(int id, String body) async {
    lateAnswers.add(body);
    missedCards = [];
    return _card(TwoAnswerStatus.waiting, mine: body);
  }

  @override
  Future<void> saveAsMoment(TwoAnswerCard card) async => momentSaves++;
}

Widget _wrap(Widget child) => MaterialApp(home: V2Theme(child: child));

final _q = find.text(V2Text.keepAll('오늘 하루 중 가장 편했던 순간은?'));

void main() {
  group('home card', () {
    Future<void> pump(WidgetTester tester, TwoAnswerCard card) => tester
        .pumpWidget(_wrap(Scaffold(body: TwoAnswersHomeCard(card: card))));

    testWidgets('my turn', (tester) async {
      await pump(tester, _card(TwoAnswerStatus.myTurn));
      expect(find.text('마주 열기'), findsOneWidget);
      expect(find.text('내 차례예요'), findsOneWidget);
    });

    testWidgets(
      'my turn with a partner who already answered says so without the text',
      (tester) async {
        await pump(
          tester,
          _card(TwoAnswerStatus.myTurn, partnerAnswered: true),
        );
        expect(
          find.text(V2Text.keepAll('상대가 먼저 답했어요. 나도 답하면 열려요')),
          findsOneWidget,
        );
      },
    );

    testWidgets('waiting for the partner', (tester) async {
      await pump(tester, _card(TwoAnswerStatus.waiting, mine: '내 답'));
      expect(find.text('상대를 기다리는 중이에요'), findsOneWidget);
    });

    testWidgets('open shows the streak and invites to look together', (
      tester,
    ) async {
      await pump(
        tester,
        _card(TwoAnswerStatus.open, mine: 'a', partner: 'b', streak: 3),
      );
      expect(find.text('봉인이 풀렸어요'), findsOneWidget);
      expect(find.text('3일 연속'), findsOneWidget);
    });

    testWidgets('a broken streak shows no streak text at all', (tester) async {
      await pump(tester, _card(TwoAnswerStatus.myTurn));
      expect(find.textContaining('연속'), findsNothing);
    });
  });

  group('live refresh', () {
    testWidgets(
      'the waiting side sees the seal open when the partner answers (socket event)',
      (tester) async {
        VoidCallback? fire;
        var unsubscribed = false;
        final repo = _FakeRepo(_card(TwoAnswerStatus.waiting, mine: '내 답'));
        await tester.pumpWidget(
          _wrap(
            TwoAnswersScreen(
              repository: repo,
              events: (cb) {
                fire = cb;
                return () => unsubscribed = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('상대 답변'), findsNothing);

        repo.current = _card(
          TwoAnswerStatus.open,
          mine: '내 답',
          partner: '상대의 비밀',
          partnerAnswered: true,
        );
        fire!();
        await tester.pumpAndSettle();
        expect(find.text('상대의 비밀'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        expect(unsubscribed, isTrue);
      },
    );

    testWidgets('returning to the foreground refetches the home card', (
      tester,
    ) async {
      var fetches = 0;
      await tester.pumpWidget(
        _wrap(
          TwoAnswersRefresher(
            events: (_) => () {},
            onRefresh: () => fetches++,
            child: const SizedBox(),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(fetches, 1);
    });
  });

  group('answer screen', () {
    testWidgets(
      'submitting an answer moves to waiting and keeps partner hidden',
      (tester) async {
        final repo = _FakeRepo(
          _card(TwoAnswerStatus.myTurn, partnerAnswered: true),
        );
        await tester.pumpWidget(_wrap(TwoAnswersScreen(repository: repo)));
        await tester.pumpAndSettle();
        expect(_q, findsOneWidget);

        await tester.enterText(find.byType(TextField), '퇴근길 바람');
        await tester.tap(find.text('답변 보내기'));
        await tester.pumpAndSettle();

        expect(repo.submitted, ['퇴근길 바람']);
        expect(find.textContaining('상대가 답하면 봉인이 풀려요'), findsOneWidget);
        expect(find.text('상대 답변'), findsNothing);
      },
    );

    testWidgets(
      'after both answered the seal opens and then shows the partner answer',
      (tester) async {
        final repo =
            _FakeRepo(_card(TwoAnswerStatus.myTurn, partnerAnswered: true))
              ..afterAnswer = _card(
                TwoAnswerStatus.open,
                mine: '퇴근길 바람',
                partner: '따뜻한 국물',
                partnerAnswered: true,
              );
        await tester.pumpWidget(_wrap(TwoAnswersScreen(repository: repo)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '퇴근길 바람');
        await tester.tap(find.text('답변 보내기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 연출 중에는 봉인만 보이고 상대 답변은 아직 없다.
        expect(find.byKey(const ValueKey('two-answers-seal')), findsOneWidget);
        expect(find.text('따뜻한 국물'), findsNothing);

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('two-answers-seal')), findsNothing);
        expect(find.text('따뜻한 국물'), findsOneWidget);
        expect(find.text('퇴근길 바람'), findsOneWidget);
      },
    );

    testWidgets('an already open card can be saved as a MomentLoop record', (
      tester,
    ) async {
      final repo = _FakeRepo(
        _card(TwoAnswerStatus.open, mine: 'a', partner: 'b'),
      );
      await tester.pumpWidget(_wrap(TwoAnswersScreen(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('우리의 기록으로 남기기'));
      await tester.pumpAndSettle();
      expect(repo.momentSaves, 1);
    });

    testWidgets('load failure offers a retry', (tester) async {
      final repo = _ThrowingRepo();
      await tester.pumpWidget(_wrap(TwoAnswersScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 질문을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 불러오기'), findsOneWidget);
    });
  });

  group('history', () {
    testWidgets(
      'lists opened cards and lets me answer a missed one without pressure',
      (tester) async {
        final repo = _FakeRepo(_card(TwoAnswerStatus.myTurn))
          ..historyCards = [
            _card(TwoAnswerStatus.open, mine: '내 옛답', partner: '상대 옛답'),
          ]
          ..missedCards = [_card(TwoAnswerStatus.myTurn)];
        await tester.pumpWidget(
          _wrap(TwoAnswersHistoryScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('내 옛답'), findsOneWidget);
        expect(find.textContaining('상대 옛답'), findsOneWidget);
        expect(find.text('아직 답하지 않은 질문'), findsOneWidget);
        expect(find.textContaining('놓쳤'), findsNothing);

        await tester.tap(_q.first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '늦은 답');
        await tester.tap(find.text('답변 보내기'));
        await tester.pumpAndSettle();
        expect(repo.lateAnswers, ['늦은 답']);
      },
    );
  });

  group('HTTP repository', () {
    test('parses today and never invents a partner body', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': true,
            'today': {
              'id': 3,
              'business_date': '2026-11-23',
              'category': 'place',
              'question': '질문',
              'status': 'my_turn',
              'my_answer': null,
              'partner_answered': true,
              'partner_answer': null,
              'streak': 2,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = HttpTwoAnswersRepository(
        baseUrl: 'https://example.test',
        token: 'tok',
        client: client,
      );
      final card = await repo.today();
      expect(seen.url.path, '/api/two-answers/today');
      expect(seen.headers['Authorization'], 'Bearer tok');
      expect(card.status, TwoAnswerStatus.myTurn);
      expect(card.partnerAnswered, isTrue);
      expect(card.partnerBody, isNull);
      expect(card.streak, 2);
    });

    test('maps server reasons to exceptions', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'ok': false, 'reason': 'already_open'}),
          409,
        ),
      );
      final repo = HttpTwoAnswersRepository(
        baseUrl: 'https://example.test',
        token: 't',
        client: client,
      );
      expect(
        repo.answerToday('x'),
        throwsA(
          isA<TwoAnswersException>().having(
            (e) => e.reason,
            'reason',
            'already_open',
          ),
        ),
      );
    });
  });
}

class _ThrowingRepo extends _FakeRepo {
  _ThrowingRepo() : super(_card(TwoAnswerStatus.myTurn));
  @override
  Future<TwoAnswerCard> today() async => throw const TwoAnswersException('x');
}
