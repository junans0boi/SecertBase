// 초보자용 고스톱 안내 모듈.
//
// 서버가 보낸 공개 상태를 설명·추천 정보로 변환한다. 게임 규칙을
// 실행하거나 상태를 변경하지 않으므로 화면과 독립적으로 테스트할 수 있다.

class GostopCardInfo {
  final String title;
  final String description;

  const GostopCardInfo({required this.title, required this.description});
}

class GostopAdvice {
  final String headline;
  final String detail;
  final String scoreProgress;
  final String nextScoreHint;
  final String? recommendedCardId;

  const GostopAdvice({
    required this.headline,
    required this.detail,
    required this.scoreProgress,
    required this.nextScoreHint,
    this.recommendedCardId,
  });
}

const _plantNames = <int, String>{
  1: '송학',
  2: '매화',
  3: '벚꽃',
  4: '등나무',
  5: '창포',
  6: '모란',
  7: '싸리',
  8: '억새',
  9: '국화',
  10: '단풍',
  11: '오동',
  12: '비',
};

const _typeNames = <String, String>{
  'bright': '광',
  'animal': '열끗',
  'ribbon': '띠',
  'junk': '피',
};

GostopCardInfo describeGostopCard(Map<String, dynamic> card) {
  final month = _asInt(card['month']);
  final plant = _plantNames[month] ?? '화투';
  final type = _typeNames[card['type']] ?? '카드';
  final subtype = card['subtype'];
  final suffix = subtype == 'rain'
      ? ' · 비광'
      : subtype == 'red'
      ? ' · 홍단'
      : subtype == 'blue'
      ? ' · 청단'
      : subtype == 'double'
      ? ' · 쌍피'
      : '';

  final description = switch (card['type']) {
    'bright' => '광은 3장을 모으면 광 점수가 생깁니다. 비광은 광 1장으로 계산돼요.',
    'animal' => '열끗은 5장부터 점수입니다. 2·4·8월 열끗을 모으면 고도리 +5점이에요.',
    'ribbon' => '띠는 5장부터 점수입니다. 홍단·청단 세트를 모으면 +3점이에요.',
    'junk' => subtype == 'double' ? '쌍피는 피 2장으로 계산됩니다.' : '피는 10장부터 점수입니다.',
    _ => '같은 월 카드와 만나면 가져올 수 있습니다.',
  };

  return GostopCardInfo(
    title: '$month월 $plant · $type$suffix',
    description: description,
  );
}

GostopAdvice buildGostopAdvice(Map<String, dynamic> state, String viewerId) {
  final phase = state['phase']?.toString() ?? 'playing';
  final score = _scoreFor(state, viewerId);
  final progress = '$score / 7점';
  final hint = score >= 7 ? '고/스톱을 선택할 수 있어요.' : '7점까지 ${7 - score}점 남았어요.';

  if (phase == 'shake_choice') {
    final owner = state['shakePlayerId']?.toString();
    return GostopAdvice(
      headline: owner == viewerId ? '흔들기 여부를 선택하세요' : '상대가 흔들기 여부를 선택 중이에요',
      detail: owner == viewerId
          ? '같은 월 3장이 있으면 흔들기를 선언해 배수 ×2를 얻을 수 있어요.'
          : '상대의 선택이 끝나면 게임이 시작됩니다.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  if (phase == 'deck_choice') {
    return GostopAdvice(
      headline: '따닥! 가져올 카드를 선택하세요',
      detail: '같은 월 카드 중 하나를 눌러 덱 카드와 함께 가져오세요.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  if (phase == 'go_stop_choice') {
    return GostopAdvice(
      headline: '고/스톱 선택',
      detail: '현재 $score점입니다. 스톱하면 지금 점수로 끝나고, 고를 하면 계속하지만 역전 위험이 있어요.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  if (phase == 'nageori') {
    return GostopAdvice(
      headline: '나가리 — 다음 판으로 넘어갑니다',
      detail: '양쪽 모두 기준 점수에 도달하지 못해 다음 판에 배수가 이월됩니다.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  final players = _stringList(state['players']);
  final currentIndex = _asInt(state['currentPlayerIdx']);
  final isMyTurn =
      players.isEmpty ||
      (currentIndex >= 0 &&
          currentIndex < players.length &&
          players[currentIndex] == viewerId);
  if (!isMyTurn) {
    return GostopAdvice(
      headline: '상대 턴을 지켜보세요',
      detail: '상대가 카드를 내고 덱을 뒤집으면 점수와 획득 카드가 업데이트됩니다.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  final hand = _cards(
    state['hands'] is Map ? (state['hands'] as Map)[viewerId] : null,
  );
  final field = _cards(state['field']);
  final recommendation = _recommendCard(hand, field);
  final events = _stringList(state['lastEvents']);
  final eventDetail = _eventDetail(events);
  if (eventDetail != null) {
    return GostopAdvice(
      headline: eventDetail.$1,
      detail: eventDetail.$2,
      scoreProgress: progress,
      nextScoreHint: hint,
      recommendedCardId: recommendation.$1,
    );
  }

  if (recommendation.$1 == null) {
    return GostopAdvice(
      headline: '카드를 선택하세요',
      detail: '카드를 길게 누르면 카드 설명을 볼 수 있어요.',
      scoreProgress: progress,
      nextScoreHint: hint,
    );
  }

  return GostopAdvice(
    headline: '추천: ${recommendation.$2}월 카드',
    detail: recommendation.$3,
    scoreProgress: progress,
    nextScoreHint: hint,
    recommendedCardId: recommendation.$1,
  );
}

int _scoreFor(Map<String, dynamic> state, String viewerId) {
  final scores = state['scores'];
  if (scores is! Map) return 0;
  final score = scores[viewerId];
  if (score is! Map) return 0;
  return _asInt(score['total']);
}

List<Map<String, dynamic>> _cards(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((card) => Map<String, dynamic>.from(card))
      .where((card) => card['id'] != 'back')
      .toList();
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((value) => '$value').toList();
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

(String?, int, String) _recommendCard(
  List<Map<String, dynamic>> hand,
  List<Map<String, dynamic>> field,
) {
  if (hand.isEmpty) return (null, 0, '낼 수 있는 손패가 없습니다.');
  Map<String, dynamic>? best;
  var bestMatches = -1;
  for (final card in hand) {
    final month = _asInt(card['month']);
    final matches = field
        .where((fieldCard) => _asInt(fieldCard['month']) == month)
        .length;
    if (matches > bestMatches) {
      best = card;
      bestMatches = matches;
    }
  }
  final month = _asInt(best?['month']);
  final detail = bestMatches > 0
      ? '바닥의 $month월 카드 $bestMatches장을 가져올 수 있어요.'
      : '$month월 카드를 바닥에 놓고, 이어서 덱 카드를 확인해요.';
  return (best?['id']?.toString(), month, detail);
}

(String, String)? _eventDetail(List<String> events) {
  if (events.contains('ssok')) {
    return ('쪽!', '낸 카드와 덱에서 나온 같은 월 카드를 함께 가져왔어요.');
  }
  if (events.contains('ppeok')) {
    return ('뻑!', '같은 월 카드가 세 장 바닥에 남았어요. 다음에 가져갈 기회를 노려보세요.');
  }
  if (events.contains('ddadak')) {
    return ('따닥!', '같은 월 카드 중 하나를 골라 덱 카드와 함께 가져왔어요.');
  }
  if (events.contains('pansseuri')) {
    return ('판쓸이!', '바닥의 카드를 모두 가져와 보너스를 얻었어요.');
  }
  if (events.contains('bomb')) {
    return ('폭탄!', '같은 월 손패 세 장으로 바닥 카드까지 한 번에 가져왔어요.');
  }
  if (events.contains('chongtong')) {
    return ('총통!', '같은 월 네 장을 처음부터 모아 즉시 승리했어요.');
  }
  return null;
}
