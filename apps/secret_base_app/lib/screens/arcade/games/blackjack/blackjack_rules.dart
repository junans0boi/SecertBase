/// 블랙잭 화면이 쓰는 규칙 도우미(서버 엔진과 같은 계산).
library;

/// 카드 합. A는 11, 넘치면 1. 가려진 카드(`hidden`)는 세지 않는다.
int blackjackScore(Iterable<Map<String, dynamic>> hand) {
  var score = 0;
  var aces = 0;
  for (final card in hand) {
    if (card['hidden'] == true) continue;
    final rank = '${card['rank'] ?? ''}';
    if (rank.isEmpty) continue;
    if (rank == 'A') {
      aces++;
      score += 11;
    } else if (rank == 'J' || rank == 'Q' || rank == 'K') {
      score += 10;
    } else {
      score += int.tryParse(rank) ?? 0;
    }
  }
  while (score > 21 && aces > 0) {
    score -= 10;
    aces--;
  }
  return score;
}

/// 처음 받은 두 장이 21(블랙잭).
bool isNaturalBlackjack(List<Map<String, dynamic>> hand) =>
    hand.length == 2 &&
    hand.every((c) => c['hidden'] != true) &&
    blackjackScore(hand) == 21;

/// 라운드 결과 사유 문구.
String roundReasonText(String? reason, {required bool iWon}) =>
    switch (reason) {
      'bust' => iWon ? '상대가 21을 넘었어요' : '21을 넘어 버렸어요',
      'blackjack' => iWon ? '블랙잭! 처음 두 장이 21' : '상대의 블랙잭!',
      'score' => iWon ? '21에 더 가까웠어요' : '상대가 21에 더 가까웠어요',
      _ => '두 사람의 합이 같아요',
    };

/// 판 결과 사유 문구.
String matchReasonText(String? reason, {required bool iWon}) =>
    switch (reason) {
      'timeout' => iWon ? '상대가 시간을 세 번 넘겼어요' : '시간을 세 번 넘겨 기권했어요',
      'afk' => iWon ? '상대가 자리를 비웠어요' : '오래 자리를 비워 기권했어요',
      'max_rounds' => iWon ? '5라운드를 마치고 승수가 더 많았어요' : '5라운드를 마치고 상대 승수가 더 많았어요',
      _ => iWon ? '먼저 2승을 거뒀어요' : '상대가 먼저 2승을 거뒀어요',
    };

const blackjackHowTo = [
  '카드 합을 21에 가깝게! 21을 넘으면 바로 그 라운드를 져요.',
  '처음 두 장 중 한 장은 상대에게 보이고, 한 장은 숨겨져요. 히트로 받은 카드는 모두 공개돼요.',
  '상대 점수는 "공개된 합 + ?"로만 보여요. 숨은 카드는 라운드가 끝날 때 뒤집혀요.',
  '처음 두 장이 21이면 블랙잭! 일반 21보다 강해요.',
  '먼저 2승하면 승리. 5라운드가 끝나면 승수가 많은 쪽이 이겨요. 진 사람이 다음 라운드에서 나중에 골라요.',
  '내 차례는 30초. 시간이 지나면 자동으로 스탠드해요.',
];
