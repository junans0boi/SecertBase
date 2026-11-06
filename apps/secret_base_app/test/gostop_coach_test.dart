import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/gostop_coach.dart';

GostopCoachInput input({
  String phase = 'playing',
  bool mine = true,
  int score = 0,
  List<CoachCard> hand = const [],
  List<CoachCard> field = const [],
  Map<String, dynamic>? coach,
  List<String> events = const [],
  List<int> shakeable = const [],
}) => GostopCoachInput(
  phase: phase,
  isMyTurn: mine,
  myScore: score,
  hand: hand,
  field: field,
  coach: coach,
  lastEvents: events,
  shakeable: shakeable,
);

void main() {
  test('초보자에게 서버가 고른 손패와 이유를 알려 준다', () {
    final advice = buildGostopAdvice(
      input(
        hand: const [
          CoachCard('m2_ribbon', 2, 'ribbon', 'red'),
          CoachCard('m7_junk_1', 7, 'junk'),
        ],
        field: const [CoachCard('m2_junk_1', 2, 'junk')],
        coach: {'type': 'play', 'cardId': 'm2_ribbon'},
      ),
    );
    expect(advice.recommendedCardId, 'm2_ribbon');
    expect(advice.headline, contains('추천'));
    expect(advice.detail, contains('2월'));
  });

  test('7점 상태에서는 고/스톱의 의미를 설명한다', () {
    final advice = buildGostopAdvice(input(phase: 'go_stop', score: 8));
    expect(advice.headline, contains('고'));
    expect(advice.detail, contains('8점'));
    expect(advice.scoreProgress, '8 / 7점');
  });

  test('두 장 선택·총통·흔들기·상대 차례 안내', () {
    expect(
      buildGostopAdvice(input(phase: 'choice')).headline,
      contains('고르세요'),
    );
    expect(
      buildGostopAdvice(input(phase: 'chongtong')).headline,
      contains('총통'),
    );
    expect(
      buildGostopAdvice(input(shakeable: [4])).headline,
      contains('4월 흔들기'),
    );
    expect(buildGostopAdvice(input(mine: false)).headline, contains('상대'));
  });

  test('직전 턴 이벤트(쪽·뻑·쓸)를 쉬운 말로 설명한다', () {
    final a = buildGostopAdvice(
      input(
        events: const ['sseul'],
        hand: const [CoachCard('a', 1, 'junk')],
        coach: {'type': 'play', 'cardId': 'a'},
      ),
    );
    expect(a.headline, '쓸!');
    expect(kGostopEventLabels['ppeok'], '뻑!');
  });

  test('엔진 영문 사유나 내부 이름이 안내 문구에 나오지 않는다', () {
    for (final phase in [
      'playing',
      'choice',
      'go_stop',
      'chongtong',
      'finished',
    ]) {
      final a = buildGostopAdvice(input(phase: phase));
      for (final text in [a.headline, a.detail, a.nextScoreHint]) {
        expect(RegExp(r'[A-Za-z_]{4,}').hasMatch(text), isFalse, reason: text);
      }
    }
  });

  test('카드 상세는 월·종류·초보자용 점수 힌트를 제공한다', () {
    final info = describeGostopCard({
      'id': 'm8_animal',
      'month': 8,
      'type': 'animal',
      'subtype': null,
    });
    expect(info.title, contains('8월'));
    expect(info.title, contains('열끗'));
    expect(info.description, contains('고도리'));
    expect(
      describeGostopCard({'month': 9, 'type': 'animal'}).description,
      contains('국진'),
    );
  });

  test('곧 점수가 나는 묶음을 남은 장수 순으로 알려 준다', () {
    final hints = nearMissHints(const [
      CoachCard('m1_animal', 1, 'ribbon', 'red'),
      CoachCard('m2_ribbon', 2, 'ribbon', 'red'),
      CoachCard('m6_ribbon', 6, 'ribbon', 'blue'),
      CoachCard('m2_animal', 2, 'animal'),
      CoachCard('m4_animal', 4, 'animal'),
    ]);
    expect(hints.first, '홍단 1장 남음');
    expect(hints, contains('고도리 1장 남음'));
    expect(hints.length, lessThanOrEqualTo(3));
    expect(nearMissHints(const []), isEmpty);
  });
}
