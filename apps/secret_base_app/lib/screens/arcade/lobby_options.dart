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
      key: 'spicy',
      title: '살짝 매운맛',
      icon: '🌶️',
      choices: [
        LobbyChoice('off', '끄기', '편하게 즐기는 질문만'),
        LobbyChoice('on', '켜기', '조금 짓궂은 연애 질문도'),
      ],
    ),
  ],
};

List<LobbyOptionDef> lobbyOptionsFor(String gameType) =>
    kLobbyOptions[gameType] ?? const [];
