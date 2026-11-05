import 'package:flutter/foundation.dart';

/// 정규 킥 수(한 사람당).
const kPenaltyKicksPerPlayer = 5;

/// 한 번 고르는 시간(서버 `PENALTY_TURN_MS`와 같다).
const kPenaltyTurn = Duration(seconds: 20);

/// 칸 이름. 3칸: 왼·가운데·오른, 6칸: 위 3칸(0~2) + 아래 3칸(3~5).
String penaltyCellName(int cells, int cell) {
  const cols = ['왼쪽', '가운데', '오른쪽'];
  if (cells == 6) {
    final col = cols[cell % 3];
    return cell < 3 ? '$col 위' : '$col 아래';
  }
  return cols[cell.clamp(0, 2)];
}

/// 칸의 열(0~2)과 행(0 위, 1 아래 — 3칸이면 늘 0).
int penaltyCol(int cell) => cell % 3;
int penaltyRow(int cells, int cell) => cells == 6 && cell >= 3 ? 1 : 0;

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

@immutable
class PenaltyRound {
  final int round;
  final String kicker;
  final String keeper;
  final int kickerDir;
  final int keeperDir;
  final bool isGoal;
  final bool autoKicker;
  final bool autoKeeper;

  const PenaltyRound({
    required this.round,
    required this.kicker,
    required this.keeper,
    required this.kickerDir,
    required this.keeperDir,
    required this.isGoal,
    this.autoKicker = false,
    this.autoKeeper = false,
  });

  factory PenaltyRound.fromMap(Map map) => PenaltyRound(
    round: _int(map['round'], 1),
    kicker: '${map['kicker'] ?? ''}',
    keeper: '${map['keeper'] ?? ''}',
    kickerDir: _int(map['kickerDir']),
    keeperDir: _int(map['keeperDir']),
    isGoal: map['isGoal'] == true,
    autoKicker: map['autoKicker'] == true,
    autoKeeper: map['autoKeeper'] == true,
  );
}

@immutable
class PenaltyResult {
  /// 이긴 사람 id, 무승부면 null.
  final String? winner;
  final String? loser;

  /// score · draw · forfeit · abandoned
  final String reason;

  const PenaltyResult({this.winner, this.loser, required this.reason});

  bool get isDraw => winner == null;

  factory PenaltyResult.fromMap(Map map) {
    final w = map['winner'];
    return PenaltyResult(
      winner: w == null || w == 'draw' ? null : '$w',
      loser: map['loser'] == null ? null : '${map['loser']}',
      reason: '${map['reason'] ?? (w == 'draw' ? 'draw' : 'score')}',
    );
  }
}

/// 서버 `game:penalty:state`의 공개 상태.
@immutable
class PenaltyState {
  final String? gameId;
  final bool finished;
  final int cells;
  final List<String> players;
  final String? firstKicker;
  final int round;
  final String kicker;
  final String keeper;
  final Set<String> submitted;
  final Map<String, int> scores;
  final List<PenaltyRound> rounds;
  final bool suddenDeath;
  final Map<String, int> autoPicks;
  final int? turnDeadlineMs;
  final int? serverNowMs;
  final Map<String, dynamic>? series;
  final PenaltyResult? result;

  const PenaltyState({
    this.gameId,
    this.finished = false,
    this.cells = 3,
    this.players = const [],
    this.firstKicker,
    this.round = 1,
    required this.kicker,
    required this.keeper,
    this.submitted = const {},
    this.scores = const {},
    this.rounds = const [],
    this.suddenDeath = false,
    this.autoPicks = const {},
    this.turnDeadlineMs,
    this.serverNowMs,
    this.series,
    this.result,
  });

  factory PenaltyState.fromMap(Map map) {
    final cells = _int(map['cells'], 3) == 6 ? 6 : 3;
    final scores = <String, int>{};
    (map['scores'] as Map?)?.forEach((k, v) => scores['$k'] = _int(v));
    final autoPicks = <String, int>{};
    (map['autoPicks'] as Map?)?.forEach((k, v) => autoPicks['$k'] = _int(v));
    final submitted = <String>{};
    (map['submissions'] as Map?)?.forEach((k, v) {
      if (v != null && v != false) submitted.add('$k');
    });
    final players = ((map['players'] as List?) ?? scores.keys.toList())
        .map((p) => '$p')
        .toList();
    final rawResult = map['result'];
    final rawSeries = map['series'];
    return PenaltyState(
      gameId: map['gameId'] as String?,
      finished: map['status'] == 'finished',
      cells: cells,
      players: players,
      firstKicker: map['firstKicker'] as String?,
      round: _int(map['round'], 1),
      kicker: '${map['kicker'] ?? ''}',
      keeper: '${map['keeper'] ?? ''}',
      submitted: submitted,
      scores: scores,
      rounds: ((map['rounds'] as List?) ?? const [])
          .whereType<Map>()
          .map(PenaltyRound.fromMap)
          .toList(),
      suddenDeath: map['suddenDeath'] == true,
      autoPicks: autoPicks,
      turnDeadlineMs: (map['turnDeadline'] as num?)?.toInt(),
      serverNowMs: (map['serverNow'] as num?)?.toInt(),
      series: rawSeries is Map ? Map<String, dynamic>.from(rawSeries) : null,
      result: rawResult is Map ? PenaltyResult.fromMap(rawResult) : null,
    );
  }

  bool get playing => !finished;

  int scoreOf(String? id) => id == null ? 0 : (scores[id] ?? 0);

  /// [id]가 찬 킥(오래된 것부터).
  List<PenaltyRound> kicksBy(String? id) =>
      rounds.where((r) => r.kicker == id).toList();

  /// 정규 5킥이 끝나 서든데스로 들어갔는지(지금 차는 킥 기준).
  bool get inSuddenDeath =>
      suddenDeath || rounds.length >= kPenaltyKicksPerPlayer * 2;

  /// 지금 차는 킥이 서든데스 몇 번째 쌍인지(1부터). 정규 킥이면 0.
  int get suddenDeathPair {
    final regulation = kPenaltyKicksPerPlayer * 2;
    if (rounds.length < regulation) return 0;
    return (rounds.length - regulation) ~/ 2 + 1;
  }

  /// [id]가 몇 번째 킥을 찰 차례인지(1부터, 정규 기준).
  int kickNumberOf(String id) => kicksBy(id).length + 1;
}
