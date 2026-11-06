import 'package:flutter/material.dart';

/// 윷놀이 2.0 서버 계약(docs/socket-events/yut.md)의 클라이언트 모델.
/// 규칙은 서버가 계산한다. 화면은 `legalMoves`를 그대로 보여 준다.

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
List<int> _ints(Object? v) =>
    v is List ? v.whereType<num>().map((e) => e.toInt()).toList() : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// 던지기 결과 이름(서버 숫자: 1 도, 2 개, 3 걸, 4 윷, 5 모, -1 빽도).
String yutStepName(int steps) => switch (steps) {
  1 => '도',
  2 => '개',
  3 => '걸',
  4 => '윷',
  5 => '모',
  -1 => '빽도',
  _ => '?',
};

/// 판 위 칸 이름. 모서리와 가운데만 이름이 있다.
String? yutSquareName(int position) => switch (position) {
  5 => '모',
  10 => '뒷모',
  15 => '찌모',
  20 => '참먹이',
  23 => '방',
  _ => null,
};

@immutable
class YutPiece {
  final int id;
  final int position;
  final int lastPos;
  final bool finished;

  const YutPiece({
    required this.id,
    required this.position,
    this.lastPos = 0,
    this.finished = false,
  });

  factory YutPiece.fromJson(Object? raw) {
    final m = _map(raw);
    return YutPiece(
      id: _int(m['id']),
      position: _int(m['position']),
      lastPos: _int(m['lastPos']),
      finished: m['finished'] == true,
    );
  }

  bool get waiting => !finished && position == 0;
  bool get onBoard => !finished && position != 0;
}

@immutable
class YutThrow {
  final int result;
  final String resultName;

  /// 길이 4. 0은 납작한 면, 1은 둥근 면. 0번이 표시 막대(빽도 표시).
  final List<int> sticks;
  final bool nak;
  final bool bonus;
  final bool auto;

  const YutThrow({
    required this.result,
    required this.resultName,
    required this.sticks,
    this.nak = false,
    this.bonus = false,
    this.auto = false,
  });

  static YutThrow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = _map(raw);
    final result = _int(m['result'], 0);
    final sticks = _ints(m['sticks']);
    return YutThrow(
      result: result,
      resultName: '${m['resultName'] ?? yutStepName(result)}',
      sticks: sticks.length == 4 ? sticks : const [1, 1, 1, 1],
      nak: m['nak'] == true,
      bonus: m['bonus'] == true,
      auto: m['auto'] == true,
    );
  }

  bool get isBig => result == 4 || result == 5;
}

@immutable
class YutLegalMove {
  final int moveIndex;
  final int steps;
  final int pieceId;
  final List<int> pieceIds;
  final int? backdoDir;
  final int from;
  final int to;
  final List<int> path;
  final bool finish;
  final int captures;
  final int stacks;

  const YutLegalMove({
    required this.moveIndex,
    required this.steps,
    required this.pieceId,
    required this.pieceIds,
    required this.backdoDir,
    required this.from,
    required this.to,
    required this.path,
    required this.finish,
    required this.captures,
    required this.stacks,
  });

  factory YutLegalMove.fromJson(Object? raw) {
    final m = _map(raw);
    final dir = m['backdoDir'];
    return YutLegalMove(
      moveIndex: _int(m['moveIndex']),
      steps: _int(m['steps']),
      pieceId: _int(m['pieceId']),
      pieceIds: _ints(m['pieceIds']),
      backdoDir: dir is num ? dir.toInt() : null,
      from: _int(m['from']),
      to: _int(m['to']),
      path: _ints(m['path']),
      finish: m['finish'] == true,
      captures: _int(m['captures']),
      stacks: _int(m['stacks']),
    );
  }
}

@immutable
class YutMoveInfo {
  final int moveIndex;
  final int steps;
  final List<int> pieceIds;
  final int from;
  final int to;
  final List<int> path;
  final bool finish;
  final List<int> captured;
  final String? capturedPlayer;
  final List<int> blocked;
  final int? blockedAt;
  final bool stacked;

  const YutMoveInfo({
    required this.moveIndex,
    required this.steps,
    required this.pieceIds,
    required this.from,
    required this.to,
    required this.path,
    required this.finish,
    required this.captured,
    required this.capturedPlayer,
    required this.blocked,
    required this.blockedAt,
    required this.stacked,
  });

  static YutMoveInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = _map(raw);
    return YutMoveInfo(
      moveIndex: _int(m['moveIndex']),
      steps: _int(m['steps']),
      pieceIds: _ints(m['pieceIds']),
      from: _int(m['from']),
      to: _int(m['to']),
      path: _ints(m['path']),
      finish: m['finish'] == true,
      captured: _ints(m['captured']),
      capturedPlayer: m['capturedPlayer'] as String?,
      blocked: _ints(m['blocked']),
      blockedAt: m['blockedAt'] is num ? (m['blockedAt'] as num).toInt() : null,
      stacked: m['stacked'] == true,
    );
  }

  bool get didCapture => captured.isNotEmpty;
  bool get wasBlocked => blocked.isNotEmpty;
}

@immutable
class YutItemEffect {
  final String player;
  final String stat;
  final int amount;

  const YutItemEffect(this.player, this.stat, this.amount);

  static List<YutItemEffect> listFrom(Object? raw) => raw is List
      ? raw
            .whereType<Map>()
            .map(
              (e) => YutItemEffect(
                '${e['player'] ?? ''}',
                '${e['stat'] ?? ''}',
                _int(e['amount']),
              ),
            )
            .toList()
      : const [];
}

@immutable
class YutAction {
  final int seq;

  /// start | throw | move
  final String type;
  final String? by;
  final bool auto;
  final YutThrow? thrown;
  final YutMoveInfo? move;
  final bool turnPassed;
  final int discardedBackdo;
  final List<YutItemEffect> itemEffects;

  const YutAction({
    required this.seq,
    required this.type,
    required this.by,
    required this.auto,
    required this.thrown,
    required this.move,
    required this.turnPassed,
    required this.discardedBackdo,
    required this.itemEffects,
  });

  static YutAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = _map(raw);
    return YutAction(
      seq: _int(m['seq']),
      type: '${m['type'] ?? ''}',
      by: m['by'] as String?,
      auto: m['auto'] == true,
      thrown: YutThrow.fromJson(m['throw']),
      move: YutMoveInfo.fromJson(m['move']),
      turnPassed: m['turnPassed'] == true,
      discardedBackdo: _int(m['discardedBackdo']),
      itemEffects: YutItemEffect.listFrom(m['itemEffects']),
    );
  }
}

/// 서버 `game:yut:state` 한 장.
@immutable
class YutView {
  final String? gameId;
  final int seq;
  final List<String> players;
  final int pieceCount;
  final String? starter;
  final String phase;
  final String? currentTurn;
  final Map<String, List<YutPiece>> pieces;
  final List<int> pendingMoves;
  final bool canThrow;
  final bool hasBonusThrow;
  final int captureBonusThrows;
  final List<YutThrow> turnThrows;
  final List<YutLegalMove> legalMoves;
  final Map<String, String> characters;
  final String? bgm;
  final int stake;
  final Map<String, int> coinBonus;
  final int coinBonusCap;
  final Map<String, dynamic> equippedItems;
  final Map<String, YutEffects> effects;
  final Map<String, dynamic>? series;
  final String? winner;
  final num? turnDeadline;
  final int turnMs;
  final num? serverNow;
  final YutAction? lastAction;
  final DateTime receivedAt;

  const YutView({
    required this.gameId,
    required this.seq,
    required this.players,
    required this.pieceCount,
    required this.starter,
    required this.phase,
    required this.currentTurn,
    required this.pieces,
    required this.pendingMoves,
    required this.canThrow,
    required this.hasBonusThrow,
    required this.captureBonusThrows,
    required this.turnThrows,
    required this.legalMoves,
    required this.characters,
    required this.bgm,
    required this.stake,
    required this.coinBonus,
    required this.coinBonusCap,
    required this.equippedItems,
    required this.effects,
    required this.series,
    required this.winner,
    required this.turnDeadline,
    required this.turnMs,
    required this.serverNow,
    required this.lastAction,
    required this.receivedAt,
  });

  factory YutView.fromJson(Map<String, dynamic> m, {DateTime? receivedAt}) {
    final rawPieces = _map(m['pieces']);
    final coin = _map(m['coinBonus']);
    final series = m['series'];
    return YutView(
      gameId: m['gameId'] as String?,
      seq: _int(m['seq']),
      players: [for (final p in (m['players'] as List? ?? const [])) '$p'],
      pieceCount: _int(m['pieceCount'], 4),
      starter: m['starter'] as String?,
      phase: '${m['phase'] ?? 'throwing'}',
      currentTurn: m['currentTurn'] as String?,
      pieces: {
        for (final e in rawPieces.entries)
          e.key: [
            if (e.value is List)
              for (final p in e.value as List) YutPiece.fromJson(p),
          ],
      },
      pendingMoves: _ints(m['pendingMoves']),
      canThrow: m['canThrow'] == true,
      hasBonusThrow: m['hasBonusThrow'] == true,
      captureBonusThrows: _int(m['captureBonusThrows']),
      turnThrows: [
        if (m['turnThrows'] is List)
          for (final t in m['turnThrows'] as List) ?YutThrow.fromJson(t),
      ],
      legalMoves: [
        if (m['legalMoves'] is List)
          for (final l in m['legalMoves'] as List) YutLegalMove.fromJson(l),
      ],
      characters: {
        for (final e in _map(m['characters']).entries) e.key: '${e.value}',
      },
      bgm: m['bgm'] as String?,
      stake: _int(m['stake']),
      coinBonus: {for (final e in coin.entries) e.key: _int(e.value)},
      coinBonusCap: _int(m['coinBonusCap']),
      equippedItems: _map(m['equippedItems']),
      effects: {
        for (final e in _map(m['effects']).entries)
          e.key: YutEffects.fromJson(e.value),
      },
      series: series is Map ? Map<String, dynamic>.from(series) : null,
      winner: m['winner'] as String?,
      turnDeadline: m['turnDeadline'] as num?,
      turnMs: _int(m['turnMs'], 30000),
      serverNow: m['serverNow'] as num?,
      lastAction: YutAction.fromJson(m['lastAction']),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  String? opponentOf(String? me) {
    for (final p in players) {
      if (p != me) return p;
    }
    return null;
  }

  List<YutPiece> piecesOf(String? player) => pieces[player] ?? const [];
  int waitingOf(String? player) =>
      piecesOf(player).where((p) => p.waiting).length;
  int finishedOf(String? player) =>
      piecesOf(player).where((p) => p.finished).length;

  YutEffects effectsOf(String? player) => effects[player] ?? YutEffects.none;

  /// 장착 아이템 한 칸(`yut_piece`·`yut_yut`).
  Map<String, dynamic>? itemOf(String? player, String slot) {
    final items = equippedItems[player];
    if (items is! Map) return null;
    final item = items[slot];
    return item is Map ? Map<String, dynamic>.from(item) : null;
  }
}

/// 한 사람에게 이 판에서 실제로 적용되는 아이템 효과(서버가 상한을 적용한 값).
@immutable
class YutEffects {
  final double controlPct;
  final double moRatePct;
  final double overturnPct;
  final double backdoBonusPct;
  final double defensePct;
  final double winCoinPct;
  final int catchCoinPer;
  final int catchFlat;

  const YutEffects({
    this.controlPct = 0,
    this.moRatePct = 0,
    this.overturnPct = 0,
    this.backdoBonusPct = 0,
    this.defensePct = 0,
    this.winCoinPct = 0,
    this.catchCoinPer = 0,
    this.catchFlat = 0,
  });

  static const none = YutEffects();

  factory YutEffects.fromJson(Object? raw) {
    final m = _map(raw);
    double d(String k) => m[k] is num ? (m[k] as num).toDouble() : 0;
    return YutEffects(
      controlPct: d('controlPct'),
      moRatePct: d('moRatePct'),
      overturnPct: d('overturnPct'),
      backdoBonusPct: d('backdoBonusPct'),
      defensePct: d('defensePct'),
      winCoinPct: d('winCoinPct'),
      catchCoinPer: _int(m['catchCoinPer']),
      catchFlat: _int(m['catchFlat']),
    );
  }

  static String _n(double v) {
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  /// 화면의 "효과" 칩 문구(원시 아이템 수치가 아니라 실제 적용값).
  /// 판돈이 없는 판에서는 코인 효과를 감춘다.
  List<String> chips({required bool staked}) => [
    if (controlPct > 0) '윷 컨트롤 +${_n(controlPct)}%',
    if (moRatePct > 0) '모 확률 +${_n(moRatePct)}%',
    if (overturnPct > 0) '역전 +${_n(overturnPct)}%',
    if (backdoBonusPct > 0) '빽도 보너스 ${_n(backdoBonusPct)}%',
    if (defensePct > 0) '잡힘 방어 ${_n(defensePct)}%',
    if (staked && winCoinPct > 0) '윷·모 코인 ${_n(winCoinPct)}%',
    if (staked && catchCoinPer > 0) '잡기 말당 +$catchCoinPer코인',
    if (staked && catchFlat > 0) '잡기 +$catchFlat코인',
  ];
}

@immutable
class YutResult {
  final String gameId;
  final String winner;
  final String? loser;

  /// goal | forfeit
  final String reason;
  final int stake;
  final int coinBonus;

  /// 실제로 옮겨진 판돈(영수증). 구버전 서버는 보내지 않아 null.
  final int? transferred;

  /// 이긴 사람이 실제로 받은 코인(보너스 포함). 구버전 서버는 null.
  final int? winnerGain;

  /// none | settled | capped | already | failed (구버전 서버는 null)
  final String? settlement;
  final Map<String, int> finished;
  final int pieceCount;
  final Map<String, dynamic>? series;

  const YutResult({
    required this.gameId,
    required this.winner,
    required this.loser,
    required this.reason,
    required this.stake,
    required this.coinBonus,
    this.transferred,
    this.winnerGain,
    this.settlement,
    required this.finished,
    required this.pieceCount,
    required this.series,
  });

  factory YutResult.fromJson(Map<String, dynamic> m) {
    final series = m['series'];
    return YutResult(
      gameId: '${m['gameId'] ?? ''}',
      winner: '${m['winner'] ?? ''}',
      loser: m['loser'] as String?,
      reason: '${m['reason'] ?? 'goal'}',
      stake: _int(m['stake']),
      coinBonus: _int(m['coinBonus']),
      transferred: m['transferred'] is num ? _int(m['transferred']) : null,
      winnerGain: m['winnerGain'] is num ? _int(m['winnerGain']) : null,
      settlement: m['settlement'] as String?,
      finished: {
        for (final e in _map(m['finished']).entries) e.key: _int(e.value),
      },
      pieceCount: _int(m['pieceCount'], 4),
      series: series is Map ? Map<String, dynamic>.from(series) : null,
    );
  }

  bool get forfeit => reason == 'forfeit';

  /// 코인 정산이 실패했다(코인이 옮겨지지 않았다).
  bool get settlementFailed => settlement == 'failed';

  /// 화면에 말할 판돈: 실제로 옮겨진 코인. 영수증이 없으면 약속한 판돈.
  int get shownStake => settlementFailed ? 0 : (transferred ?? stake);

  /// 이긴 사람의 아이템 보너스(실제 받은 코인 − 판돈). 영수증이 없으면 서버가 센 보너스.
  int get shownBonus {
    if (settlementFailed) return 0;
    final gain = winnerGain;
    if (gain == null) return coinBonus;
    final extra = gain - (transferred ?? stake);
    return extra > 0 ? extra : 0;
  }
}

const yutCharacterNames = {'honggilldong': '홍길동', 'nolbu': '놀부', 'miho': '미호'};

String yutCharacterAsset(String id) => switch (id) {
  'nolbu' => 'assets/images/yut/fig_nolbu.png',
  'miho' => 'assets/images/yut/fig_miho.png',
  _ => 'assets/images/yut/fig_honggilldong.png',
};

/// 캐릭터 그림 가로/세로 비율(잘라낸 전신 그림).
double yutCharacterAspect(String id) => switch (id) {
  'nolbu' => 289 / 420,
  'miho' => 277 / 420,
  _ => 252 / 420,
};

/// 오방색(판 모서리 표시와 글자 포인트).
class Obangsaek {
  Obangsaek._();
  static const blue = Color(0xFF2F5D8A); // 청
  static const red = Color(0xFFB5412F); // 적
  static const yellow = Color(0xFFD9A441); // 황
  static const white = Color(0xFFF6F0E1); // 백
  static const black = Color(0xFF2A2623); // 흑
}
