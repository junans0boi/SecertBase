/// 텔레파시 2.0 서버 상태(`game:telepathy:state`)를 읽기 쉬운 모양으로 옮긴 것.
/// 계약: docs/socket-events/telepathy.md
library;

Map<String, int> _intMap(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', (val as num?)?.toInt() ?? 0))
    : <String, int>{};

Map<String, bool> _boolMap(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', val == true))
    : <String, bool>{};

/// 분야 id → 화면에 쓰는 이름.
const Map<String, String> kTelepathyCategoryLabels = {
  'light': '가벼운 취향',
  'food': '음식·야식',
  'date': '데이트',
  'travel': '여행',
  'daily': '일상·생활습관',
  'romance': '연애·로맨스',
  'whatif': '만약에',
  'spicy': '살짝 매운맛',
};

class TelepathyQuestion {
  final String id;
  final String cat;
  final String a;
  final String b;
  final String emojiA;
  final String emojiB;
  final bool spicy;

  const TelepathyQuestion({
    required this.id,
    required this.cat,
    required this.a,
    required this.b,
    required this.emojiA,
    required this.emojiB,
    this.spicy = false,
  });

  static TelepathyQuestion? fromMap(Object? v) {
    if (v is! Map) return null;
    final a = v['a'];
    final b = v['b'];
    if (a is! String || b is! String) return null;
    return TelepathyQuestion(
      id: '${v['id'] ?? ''}',
      cat: '${v['cat'] ?? ''}',
      a: a,
      b: b,
      emojiA: '${v['emojiA'] ?? '✨'}',
      emojiB: '${v['emojiB'] ?? '✨'}',
      spicy: v['spicy'] == true,
    );
  }

  String get categoryLabel => kTelepathyCategoryLabels[cat] ?? '밸런스';
  String textOf(String choice) => choice == 'A' ? a : b;
  String emojiOf(String choice) => choice == 'A' ? emojiA : emojiB;
}

/// 공개된 한 문제.
class TelepathyRound {
  final int round;
  final TelepathyQuestion question;
  final Map<String, String?> picks; // userId → 'A' | 'B' | null(시간 초과)
  final bool matched;
  final String outcome; // match | miss | timeout
  final int streak;
  final int score;

  const TelepathyRound({
    required this.round,
    required this.question,
    required this.picks,
    required this.matched,
    required this.outcome,
    required this.streak,
    required this.score,
  });

  static TelepathyRound? fromMap(Object? v) {
    if (v is! Map) return null;
    final q = TelepathyQuestion.fromMap(v['question']);
    if (q == null) return null;
    final raw = v['picks'];
    return TelepathyRound(
      round: (v['round'] as num?)?.toInt() ?? 0,
      question: q,
      picks: raw is Map
          ? raw.map(
              (k, val) =>
                  MapEntry('$k', val == 'A' || val == 'B' ? '$val' : null),
            )
          : <String, String?>{},
      matched: v['matched'] == true,
      outcome: '${v['outcome'] ?? 'miss'}',
      streak: (v['streak'] as num?)?.toInt() ?? 0,
      score: (v['score'] as num?)?.toInt() ?? 0,
    );
  }

  bool get timedOut => outcome == 'timeout';
}

class TelepathyTier {
  final String id;
  final String label;

  const TelepathyTier(this.id, this.label);

  static TelepathyTier fromMap(Object? v) => v is Map
      ? TelepathyTier('${v['id'] ?? 'learning'}', '${v['label'] ?? ''}')
      : const TelepathyTier('learning', '알아가는 중');
}

class TelepathyResult {
  final String reason; // complete | both_away | away
  final String? awayPlayer;
  final int matches;
  final int total;
  final int played;
  final int bestStreak;
  final TelepathyTier tier;

  const TelepathyResult({
    required this.reason,
    required this.awayPlayer,
    required this.matches,
    required this.total,
    required this.played,
    required this.bestStreak,
    required this.tier,
  });

  static TelepathyResult? fromMap(Object? v) {
    if (v is! Map) return null;
    return TelepathyResult(
      reason: '${v['reason'] ?? 'complete'}',
      awayPlayer: v['awayPlayer'] as String?,
      matches: (v['matches'] as num?)?.toInt() ?? 0,
      total: (v['total'] as num?)?.toInt() ?? 0,
      played: (v['played'] as num?)?.toInt() ?? 0,
      bestStreak: (v['bestStreak'] as num?)?.toInt() ?? 0,
      tier: TelepathyTier.fromMap(v['tier']),
    );
  }

  bool get complete => reason == 'complete';
}

/// 방 시리즈(승패 없음): 판 수·통한 비율·최고 연속.
class TelepathySeries {
  final int games;
  final int matches;
  final int questions;
  final int ratio;
  final int bestStreak;
  final int bestMatches;

  const TelepathySeries({
    this.games = 0,
    this.matches = 0,
    this.questions = 0,
    this.ratio = 0,
    this.bestStreak = 0,
    this.bestMatches = 0,
  });

  static TelepathySeries? fromMap(Object? v) {
    if (v is! Map) return null;
    int n(String k) => (v[k] as num?)?.toInt() ?? 0;
    return TelepathySeries(
      games: n('games'),
      matches: n('matches'),
      questions: n('questions'),
      ratio: n('ratio'),
      bestStreak: n('bestStreak'),
      bestMatches: n('bestMatches'),
    );
  }
}

class TelepathyState {
  final String gameId;
  final String status; // playing | finished
  final List<String> players;
  final int round;
  final int rounds;
  final bool spicy;
  final TelepathyQuestion? question;
  final Map<String, bool> picked;
  final Map<String, int> timeouts;
  final int? turnDeadline;
  final int turnMs;
  final int? revealUntil;
  final int revealMs;
  final int score;
  final int streak;
  final int bestStreak;
  final int? serverNow;
  final TelepathyRound? lastRound;
  final List<TelepathyRound> history;
  final TelepathyResult? result;
  final TelepathySeries? series;
  final String? myPick;

  const TelepathyState({
    required this.gameId,
    required this.status,
    required this.players,
    required this.round,
    required this.rounds,
    required this.spicy,
    required this.question,
    required this.picked,
    required this.timeouts,
    required this.turnDeadline,
    required this.turnMs,
    required this.revealUntil,
    required this.revealMs,
    required this.score,
    required this.streak,
    required this.bestStreak,
    required this.serverNow,
    required this.lastRound,
    required this.history,
    required this.result,
    required this.series,
    required this.myPick,
  });

  factory TelepathyState.fromMap(Map<String, dynamic> m) {
    final history = (m['history'] as List?) ?? const [];
    final mine = m['myPick'];
    return TelepathyState(
      gameId: '${m['gameId'] ?? ''}',
      status: '${m['status'] ?? 'playing'}',
      players: ((m['players'] as List?) ?? const []).map((e) => '$e').toList(),
      round: (m['round'] as num?)?.toInt() ?? 1,
      rounds: (m['rounds'] as num?)?.toInt() ?? 10,
      spicy: m['spicy'] == true,
      question: TelepathyQuestion.fromMap(m['question']),
      picked: _boolMap(m['picked']),
      timeouts: _intMap(m['timeouts']),
      turnDeadline: (m['turnDeadline'] as num?)?.toInt(),
      turnMs: (m['turnMs'] as num?)?.toInt() ?? 15000,
      revealUntil: (m['revealUntil'] as num?)?.toInt(),
      revealMs: (m['revealMs'] as num?)?.toInt() ?? 3500,
      score: (m['score'] as num?)?.toInt() ?? 0,
      streak: (m['streak'] as num?)?.toInt() ?? 0,
      bestStreak: (m['bestStreak'] as num?)?.toInt() ?? 0,
      serverNow: (m['serverNow'] as num?)?.toInt(),
      lastRound: TelepathyRound.fromMap(m['lastRound']),
      history: history
          .map(TelepathyRound.fromMap)
          .whereType<TelepathyRound>()
          .toList(),
      result: TelepathyResult.fromMap(m['result']),
      series: TelepathySeries.fromMap(m['series']),
      myPick: mine == 'A' || mine == 'B' ? '$mine' : null,
    );
  }

  bool get playing => status == 'playing';
  bool get finished => status == 'finished';

  String? opponentOf(String? me) {
    for (final p in players) {
      if (p != me) return p;
    }
    return null;
  }
}
