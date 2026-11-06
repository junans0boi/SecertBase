/// 로비 옵션 정의: 방장이 로비에서 고르고 상대도 실시간으로 보는 게임별 설정.
/// 서버 `services/realtime-server/src/lobby-options.js`의 `LOBBY_OPTIONS`와 같아야 한다.
library;

class LobbyChoice {
  final Object value;
  final String label;
  final String description;

  const LobbyChoice(this.value, this.label, this.description);
}

class LobbyOptionDef {
  final String key;
  final String title;
  final String icon;
  final List<LobbyChoice> choices;

  const LobbyOptionDef({
    required this.key,
    required this.title,
    required this.icon,
    required this.choices,
  });

  /// 서버 기본값(첫 번째 선택지).
  Object get defaultValue => choices.first.value;

  LobbyChoice choiceFor(Object? value) =>
      choices.firstWhere((c) => c.value == value, orElse: () => choices.first);
}

const kLobbyOptions = <String, List<LobbyOptionDef>>{
  'catch': [
    LobbyOptionDef(
      key: 'rounds',
      title: '라운드 수',
      icon: '🎨',
      choices: [
        LobbyChoice(6, '보통 6', '한 사람이 세 번씩 그려요'),
        LobbyChoice(4, '짧게 4', '한 사람이 두 번씩, 금방 끝나요'),
        LobbyChoice(8, '길게 8', '한 사람이 네 번씩 느긋하게'),
      ],
    ),
  ],
  'penalty': [
    LobbyOptionDef(
      key: 'cells',
      title: '골대 칸',
      icon: '🥅',
      choices: [
        LobbyChoice(3, '3칸', '심리전 · 왼쪽·가운데·오른쪽'),
        LobbyChoice(6, '6칸', '정밀 · 위아래까지 노려요'),
      ],
    ),
  ],
  'pirate': [
    LobbyOptionDef(
      key: 'holes',
      title: '구멍 수',
      icon: '🗡️',
      choices: [
        LobbyChoice(8, '보통 8', '적당한 긴장감'),
        LobbyChoice(6, '빠른 6', '금방 터져요'),
        LobbyChoice(12, '길게 12', '오래 버티기'),
      ],
    ),
  ],
  'yut': [
    LobbyOptionDef(
      key: 'pieces',
      title: '말 개수',
      icon: '🐎',
      choices: [
        LobbyChoice(4, '4개', '정석 · 약 10분'),
        LobbyChoice(3, '3개', '조금 짧게'),
        LobbyChoice(2, '2개', '빠른 판 · 약 5분'),
      ],
    ),
  ],
  'uno': [
    LobbyOptionDef(
      key: 'mode',
      title: '규칙',
      icon: '🃏',
      choices: [
        LobbyChoice('go_wild', '고와일드', '+2·+4 이어받기, 같은 색 모두 버리기'),
        LobbyChoice('classic', '클래식', '기본 원카드 규칙'),
      ],
    ),
  ],
  'telepathy': [
    LobbyOptionDef(
      key: 'rounds',
      title: '문제 수',
      icon: '💫',
      choices: [
        LobbyChoice(10, '10문제', '딱 좋은 한 판'),
        LobbyChoice(5, '5문제', '가볍게 빨리'),
        LobbyChoice(15, '15문제', '오래오래 맞춰 봐요'),
      ],
    ),
    LobbyOptionDef(
      key: 'heat',
      title: '질문 수위',
      icon: '🌶️',
      choices: [
        LobbyChoice('mild', '순한맛', '편하게 즐기는 질문만'),
        LobbyChoice('spicy', '살짝 매운맛', '조금 짓궂은 연애 질문도'),
        LobbyChoice('nuclear', '핵폭탄 매운맛 🔞 19+', '성인 커플 전용 · 상대가 동의해야 시작'),
      ],
    ),
  ],
};

List<LobbyOptionDef> lobbyOptionsFor(String gameType) =>
    kLobbyOptions[gameType] ?? const [];
