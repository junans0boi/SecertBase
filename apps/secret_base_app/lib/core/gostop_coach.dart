// 초보자용 고스톱 안내 모듈.
//
// 서버가 보낸 공개 상태를 설명·추천 정보로 변환한다. 게임 규칙을 실행하거나
// 상태를 변경하지 않으므로 화면과 독립적으로 테스트할 수 있다.
// 추천 수 자체는 서버(`state.coach`)가 계산해 보낸다 — 마감 때 서버가 두는 자동 수와 같은 수다.

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

/// 코치가 보는 카드(월·종류만).
class CoachCard {
  final String id;
  final int month;
  final String type;
  final String? subtype;

  const CoachCard(this.id, this.month, this.type, [this.subtype]);
}

/// 코치에게 넘기는 현재 상황. 화면 모델에서 만들어 준다.
class GostopCoachInput {
  final String phase;
  final bool isMyTurn;
  final int myScore;
  final List<CoachCard> hand;
  final List<CoachCard> field;
  final Map<String, dynamic>? coach;
  final List<String> lastEvents;
  final String? pendingKind;
  final List<int> shakeable;
  final List<int> bombable;
  final int dotan;

  const GostopCoachInput({
    required this.phase,
    required this.isMyTurn,
    required this.myScore,
    this.hand = const [],
    this.field = const [],
    this.coach,
    this.lastEvents = const [],
    this.pendingKind,
    this.shakeable = const [],
    this.bombable = const [],
    this.dotan = 0,
  });
}

const kGostopPlantNames = <int, String>{
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

const kGostopTypeNames = <String, String>{
  'bright': '광',
  'animal': '열끗',
  'ribbon': '띠',
  'junk': '피',
};

/// 한 턴에 일어난 일 이름(토스트·도장·안내에 쓴다).
const kGostopEventLabels = <String, String>{
  'jjok': '쪽!',
  'ppeok': '뻑!',
  'ppeok_take': '뻑 가져오기!',
  'ttadak': '따닥!',
  'sseul': '쓸!',
  'bomb': '폭탄!',
  'shake': '흔들기!',
  'go': '고!',
  'chongtong': '총통!',
  'auto_stop': '스톱!',
  'stop': '스톱!',
};

GostopCardInfo describeGostopCard(Map<String, dynamic> card) {
  final month = _asInt(card['month']);
  final plant = kGostopPlantNames[month] ?? '화투';
  final type = kGostopTypeNames[card['type']] ?? '카드';
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
    'bright' =>
      subtype == 'rain'
          ? '광은 3장부터 점수예요. 비광이 끼면 3광이 3점이 아니라 2점이에요.'
          : '광은 3장을 모으면 3점이에요. 4광은 4점, 5광은 15점!',
    'animal' =>
      card['month'] == 9
          ? '국화 열끗(국진)은 열끗으로만 세요. 5장부터 점수, 2·4·8월을 모으면 고도리 +5점이에요.'
          : '열끗은 5장부터 점수예요. 2·4·8월 열끗을 모으면 고도리 +5점이에요.',
    'ribbon' => '띠는 5장부터 점수예요. 홍단·청단·초단 세 장을 모으면 +3점이에요.',
    'junk' =>
      subtype == 'double'
          ? '쌍피는 피 2장으로 계산돼요.'
          : '피는 10장부터 점수예요. 쪽·쓸이 나면 상대 피를 뺏어 와요.',
    _ => '같은 월 카드와 만나면 가져올 수 있어요.',
  };

  return GostopCardInfo(
    title: '$month월 $plant · $type$suffix',
    description: description,
  );
}

/// "홍단 1장 남음"처럼 곧 점수가 나는 묶음을 남은 장수가 적은 순으로 알려 준다.
List<String> nearMissHints(List<CoachCard> captures, {int max = 3}) {
  final hints = <(int, String)>[];
  int have(Iterable<int> months, bool Function(CoachCard) test) =>
      months.where((m) => captures.any((c) => c.month == m && test(c))).length;

  void set(String name, Iterable<int> months, bool Function(CoachCard) test) {
    final got = have(months, test);
    final rem = months.length - got;
    if (got >= 1 && rem >= 1 && rem <= 2) hints.add((rem, '$name $rem장 남음'));
  }

  set('홍단', const [1, 2, 3], (c) => c.type == 'ribbon' && c.subtype == 'red');
  set('청단', const [6, 9, 10], (c) => c.type == 'ribbon' && c.subtype == 'blue');
  set('초단', const [4, 5, 7], (c) => c.type == 'ribbon' && c.subtype == null);
  set('고도리', const [2, 4, 8], (c) => c.type == 'animal');

  final brights = captures.where((c) => c.type == 'bright').length;
  if (brights >= 1 && brights < 3) {
    final rem = 3 - brights;
    if (rem <= 2) hints.add((rem, '광 $rem장이면 3광'));
  }
  final ribbons = captures.where((c) => c.type == 'ribbon').length;
  if (ribbons >= 3 && ribbons < 5) {
    hints.add((5 - ribbons, '띠 ${5 - ribbons}장이면 1점'));
  }
  final animals = captures.where((c) => c.type == 'animal').length;
  if (animals >= 3 && animals < 5) {
    hints.add((5 - animals, '열끗 ${5 - animals}장이면 1점'));
  }
  final pi = captures.fold<int>(
    0,
    (s, c) => s + (c.type == 'junk' ? (c.subtype == 'double' ? 2 : 1) : 0),
  );
  if (pi >= 7 && pi < 10) hints.add((10 - pi, '피 ${10 - pi}장이면 1점'));

  hints.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final h in hints.take(max)) h.$2];
}

GostopAdvice buildGostopAdvice(GostopCoachInput s) {
  final score = s.myScore;
  final progress = '$score / 7점';
  final hint = score >= 7 ? '고/스톱을 고를 수 있어요.' : '7점까지 ${7 - score}점 남았어요.';
  GostopAdvice advice(String headline, String detail, {String? card}) =>
      GostopAdvice(
        headline: headline,
        detail: detail,
        scoreProgress: progress,
        nextScoreHint: hint,
        recommendedCardId: card,
      );

  switch (s.phase) {
    case 'chongtong':
      return advice(
        s.isMyTurn ? '총통이에요!' : '상대가 총통을 고르는 중이에요',
        s.isMyTurn
            ? '같은 월 네 장으로 10점을 받고 바로 이길 수 있어요. 받지 않고 그냥 칠 수도 있어요.'
            : '상대의 선택이 끝나면 게임이 시작돼요.',
      );
    case 'choice':
      return advice(
        s.isMyTurn ? '가져올 패를 고르세요' : '상대가 패를 고르는 중이에요',
        s.pendingKind == 'deck'
            ? '뒤집은 패와 같은 월이 바닥에 두 장 있어요. 하나를 눌러 가져오세요.'
            : '낸 패와 같은 월이 바닥에 두 장 있어요. 하나를 눌러 가져오세요.',
      );
    case 'go_stop':
      return advice(
        s.isMyTurn ? '고 or 스톱?' : '상대가 고/스톱을 고르는 중이에요',
        s.isMyTurn
            ? '지금 $score점이에요. 스톱하면 지금 끝나고, 고를 하면 점수와 배수가 커지지만 역전될 수 있어요.'
            : '상대가 정하면 이어집니다.',
      );
    case 'finished':
    case 'nagari':
      return advice('판이 끝났어요', '정산 내역을 확인하세요.');
  }

  if (!s.isMyTurn) {
    return advice('상대 차례예요', '상대가 패를 내고 더미를 뒤집으면 딴 패와 점수가 바뀌어요.');
  }

  final eventDetail = _eventDetail(s.lastEvents);
  final move = s.coach;
  final rawCard = move?['cardId'];
  final cardId = move?['type'] == 'play' && rawCard is String ? rawCard : null;
  if (move?['type'] == 'bomb') {
    return advice(
      '폭탄을 낼 수 있어요',
      '같은 월 손패 3장으로 바닥 1장까지 가져오고 상대 피 1장을 뺏어요. 이기면 ×2!',
    );
  }
  if (move?['type'] == 'dotan') {
    return advice('도탄이에요', '손패 없이 더미만 뒤집어요. 눌러서 뒤집으세요.');
  }
  if (s.shakeable.isNotEmpty) {
    return advice(
      '${s.shakeable.first}월 흔들기 가능',
      '같은 월 3장을 보여 주고 낼 때 "흔들기"를 켜면 이기면 ×2예요.',
      card: cardId,
    );
  }
  if (eventDetail != null) {
    return advice(eventDetail.$1, eventDetail.$2, card: cardId);
  }
  if (cardId == null) return advice('패를 선택하세요', '패를 길게 누르면 설명을 볼 수 있어요.');
  final card = s.hand.firstWhere(
    (c) => c.id == cardId,
    orElse: () => s.hand.first,
  );
  final matches = s.field.where((c) => c.month == card.month).length;
  return advice(
    '추천: ${card.month}월 패',
    matches > 0
        ? '바닥의 ${card.month}월 패 $matches장을 가져올 수 있어요.'
        : '${card.month}월 패를 바닥에 놓고, 이어서 더미를 확인해요.',
    card: cardId,
  );
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

(String, String)? _eventDetail(List<String> events) {
  if (events.contains('jjok')) {
    return ('쪽!', '낸 패와 더미에서 나온 같은 월 패를 함께 가져오고, 상대 피 1장을 뺏었어요.');
  }
  if (events.contains('ppeok_take')) {
    return ('뻑 가져오기!', '바닥에 쌓인 뻑을 가져오고, 상대 피 1장을 뺏었어요.');
  }
  if (events.contains('ppeok')) {
    return ('뻑!', '같은 월 세 장이 바닥에 남았어요. 다음에 가져갈 기회를 노려 보세요.');
  }
  if (events.contains('ttadak')) {
    return ('따닥!', '같은 월 네 장을 모두 가져오고, 상대 피 1장을 뺏었어요.');
  }
  if (events.contains('sseul')) {
    return ('쓸!', '바닥을 모두 비워서 상대 피 1장을 뺏었어요.');
  }
  if (events.contains('bomb')) {
    return ('폭탄!', '같은 월 손패 세 장으로 바닥 패까지 가져오고, 상대 피 1장을 뺏었어요.');
  }
  return null;
}
