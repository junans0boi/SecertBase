/// 제로 2.0 서버 상태(`game:zero:state`)를 읽기 쉬운 모양으로 옮긴 것.
/// 계약: docs/socket-events/zero.md
library;

const int kZeroMaxFingers = 5;

/// 내 숫자 [fingers]일 때 고를 수 있는 합계 예측(내 숫자 ~ 내 숫자 + 5).
List<int> zeroGuessOptions(int fingers) =>
    List.generate(kZeroMaxFingers + 1, (i) => fingers + i);

Map<String, int> _intMap(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', (val as num?)?.toInt() ?? 0))
    : <String, int>{};

Map<String, bool> _boolMap(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', val == true))
    : <String, bool>{};

class ZeroPick {
  final int fingers;
  final int guess;

  const ZeroPick(this.fingers, this.guess);

  static ZeroPick? fromMap(Object? v) {
    if (v is! Map) return null;
    final f = (v['fingers'] as num?)?.toInt();
    final g = (v['guess'] as num?)?.toInt();
    if (f == null || g == null) return null;
    return ZeroPick(f, g);
  }
}

/// 공개된 한 라운드.
class ZeroRound {
  final int round;
  final bool suddenDeath;
  final Map<String, int> fingers;
  final Map<String, int> guesses;
  final int total;
  final Map<String, int> distance;
  final Map<String, bool> exact;
  final Map<String, int> points;
  final Map<String, bool> auto;
  final String roundWinner; // userId 또는 'draw'
  final Map<String, int> scores;

  const ZeroRound({
    required this.round,
    required this.suddenDeath,
    required this.fingers,
    required this.guesses,
    required this.total,
    required this.distance,
    required this.exact,
    required this.points,
    required this.auto,
    required this.roundWinner,
    required this.scores,
  });

  static ZeroRound? fromMap(Object? v) {
    if (v is! Map) return null;
    return ZeroRound(
      round: (v['round'] as num?)?.toInt() ?? 0,
      suddenDeath: v['suddenDeath'] == true,
      fingers: _intMap(v['fingers']),
      guesses: _intMap(v['guesses']),
      total: (v['total'] as num?)?.toInt() ?? 0,
      distance: _intMap(v['distance']),
      exact: _boolMap(v['exact']),
      points: _intMap(v['points']),
      auto: _boolMap(v['auto']),
      roundWinner: '${v['roundWinner'] ?? 'draw'}',
      scores: _intMap(v['scores']),
    );
  }

  bool get isDraw => roundWinner == 'draw';
  bool get bothExact => exact.values.where((e) => e).length >= 2;
  bool get anyExact => exact.values.any((e) => e);
}

class ZeroResult {
  final String? winner;
  final String? loser;
  final bool draw;
  final String reason; // score | sudden_death | draw_cap | forfeit | both_away

  const ZeroResult({
    required this.winner,
    required this.loser,
    required this.draw,
    required this.reason,
  });

  static ZeroResult? fromMap(Object? v) {
    if (v is! Map) return null;
    return ZeroResult(
      winner: v['winner'] as String?,
      loser: v['loser'] as String?,
      draw: v['draw'] == true,
      reason: '${v['reason'] ?? 'score'}',
    );
  }
}

class ZeroState {
  final String gameId;
  final String status; // playing | finished
  final List<String> players;
  final int round;
  final int maxRounds;
  final bool suddenDeath;
  final int suddenDeathRounds;
  final int suddenDeathCap;
  final Map<String, int> scores;
  final Map<String, bool> submitted;
  final Map<String, int> autoPicks;
  final int? turnDeadline;
  final int turnMs;
  final int? serverNow;
  final ZeroRound? lastRound;
  final List<ZeroRound> history;
  final ZeroResult? result;
  final Map<String, dynamic>? series;
  final ZeroPick? myPick;

  const ZeroState({
    required this.gameId,
    required this.status,
    required this.players,
    required this.round,
    required this.maxRounds,
    required this.suddenDeath,
    required this.suddenDeathRounds,
    required this.suddenDeathCap,
    required this.scores,
    required this.submitted,
    required this.autoPicks,
    required this.turnDeadline,
    required this.turnMs,
    required this.serverNow,
    required this.lastRound,
    required this.history,
    required this.result,
    required this.series,
    required this.myPick,
  });

  factory ZeroState.fromMap(Map<String, dynamic> m) {
    final history = (m['history'] as List?) ?? const [];
    final series = m['series'];
    return ZeroState(
      gameId: '${m['gameId'] ?? ''}',
      status: '${m['status'] ?? 'playing'}',
      players: ((m['players'] as List?) ?? const []).map((e) => '$e').toList(),
      round: (m['round'] as num?)?.toInt() ?? 1,
      maxRounds: (m['maxRounds'] as num?)?.toInt() ?? 5,
      suddenDeath: m['suddenDeath'] == true,
      suddenDeathRounds: (m['suddenDeathRounds'] as num?)?.toInt() ?? 0,
      suddenDeathCap: (m['suddenDeathCap'] as num?)?.toInt() ?? 5,
      scores: _intMap(m['scores']),
      submitted: _boolMap(m['submitted']),
      autoPicks: _intMap(m['autoPicks']),
      turnDeadline: (m['turnDeadline'] as num?)?.toInt(),
      turnMs: (m['turnMs'] as num?)?.toInt() ?? 20000,
      serverNow: (m['serverNow'] as num?)?.toInt(),
      lastRound: ZeroRound.fromMap(m['lastRound']),
      history: history.map(ZeroRound.fromMap).whereType<ZeroRound>().toList(),
      result: ZeroResult.fromMap(m['result']),
      series: series is Map ? Map<String, dynamic>.from(series) : null,
      myPick: ZeroPick.fromMap(m['myPick']),
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
