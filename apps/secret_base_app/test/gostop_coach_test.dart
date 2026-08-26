import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/gostop_coach.dart';

void main() {
  test('초보자에게 같은 월을 맞추는 손패를 추천한다', () {
    final advice = buildGostopAdvice({
      'phase': 'playing',
      'players': ['p1', 'p2'],
      'currentPlayerIdx': 0,
      'hands': {
        'p1': [
          {'id': 'm2_ribbon', 'month': 2, 'type': 'ribbon', 'subtype': 'red'},
          {'id': 'm7_junk_1', 'month': 7, 'type': 'junk', 'subtype': null},
        ],
      },
      'field': [
        {'id': 'm2_junk_1', 'month': 2, 'type': 'junk', 'subtype': null},
      ],
      'scores': {
        'p1': {'total': 0},
      },
    }, 'p1');

    expect(advice.recommendedCardId, 'm2_ribbon');
    expect(advice.headline, contains('추천'));
    expect(advice.detail, contains('2월'));
  });

  test('7점 상태에서는 고/스톱 선택의 의미를 설명한다', () {
    final advice = buildGostopAdvice({
      'phase': 'go_stop_choice',
      'players': ['p1', 'p2'],
      'currentPlayerIdx': 0,
      'scores': {
        'p1': {'total': 8},
      },
    }, 'p1');

    expect(advice.headline, contains('고/스톱'));
    expect(advice.detail, contains('8점'));
    expect(advice.scoreProgress, '8 / 7점');
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
  });
}
