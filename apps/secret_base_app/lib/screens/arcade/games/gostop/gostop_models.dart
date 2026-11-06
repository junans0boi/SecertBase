import '../../../../core/gostop_coach.dart';

/// 서버가 보내는 화투 한 장. 종류는 광·열끗·띠·피, 세부 종류는 비광·홍단·청단·쌍피.
class HCard {
  final String id;
  final int month;
  final String type; // bright | animal | ribbon | junk
  final String? subtype; // rain | red | blue | double

  const HCard({
    required this.id,
    required this.month,
    required this.type,
    this.subtype,
  });

  factory HCard.fromJson(Map<String, dynamic> j) => HCard(
    id: '${j['id']}',
    month: _int(j['month']),
    type: '${j['type'] ?? 'junk'}',
    subtype: j['subtype'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'type': type,
    'subtype': subtype,
  };

  CoachCard get coach => CoachCard(id, month, type, subtype);

  bool get isDoubleJunk => subtype == 'double';
  bool get isBright => type == 'bright';
  bool get isAnimal => type == 'animal';
  bool get isRibbon => type == 'ribbon';
  bool get isJunk => type == 'junk';

  /// 내 손패 정렬: 월 순, 같은 월이면 광 > 열끗 > 띠 > 피.
  int get sortKey =>
      month * 10 +
      const {'bright': 0, 'animal': 1, 'ribbon': 2, 'junk': 3}[type]!;

  @override
  bool operator ==(Object other) => other is HCard && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

List<HCard> cardsOf(dynamic raw) => raw is List
    ? [
        for (final c in raw)
          if (c is Map) HCard.fromJson(Map<String, dynamic>.from(c)),
      ]
    : const [];

Map<String, int> _intMap(dynamic raw) => raw is Map
    ? {for (final e in raw.entries) '${e.key}': _int(e.value)}
    : const {};

/// 한 사람의 딴 패 점수 요약.
class HScore {
  final int total;
  final int gwangCount;
  final int animCount;
  final int ribCount;
  final int piTotal;
  final int gwangScore;
  final int animScore;
  final int ribScore;
  final int godoriScore;
  final int hongdanBonus;
  final int cheongdanBonus;
  final int chodanBonus;
  final bool hasRain;

  const HScore({
    this.total = 0,
    this.gwangCount = 0,
    this.animCount = 0,
    this.ribCount = 0,
    this.piTotal = 0,
    this.gwangScore = 0,
    this.animScore = 0,
    this.ribScore = 0,
    this.godoriScore = 0,
    this.hongdanBonus = 0,
    this.cheongdanBonus = 0,
    this.chodanBonus = 0,
    this.hasRain = false,
  });

  factory HScore.fromJson(dynamic raw) {
    if (raw is! Map) return const HScore();
    return HScore(
      total: _int(raw['total']),
      gwangCount: _int(raw['gwangCount']),
      animCount: _int(raw['animCount']),
      ribCount: _int(raw['ribCount']),
      piTotal: _int(raw['piTotal']),
      gwangScore: _int(raw['gwangScore']),
      animScore: _int(raw['animScore']),
      ribScore: _int(raw['ribScore']),
      godoriScore: _int(raw['godoriScore']),
      hongdanBonus: _int(raw['hongdanBonus']),
      cheongdanBonus: _int(raw['cheongdanBonus']),
      chodanBonus: _int(raw['chodanBonus']),
      hasRain: raw['hasRain'] == true,
    );
  }
}

/// 점수에 곱해지는 배수 하나(고·흔들기·폭탄·피박·광박·고박).
class HMultiplier {
  final String code;
  final int count;
  final int factor;

  const HMultiplier(this.code, this.count, this.factor);

  factory HMultiplier.fromJson(Map<String, dynamic> j) =>
      HMultiplier('${j['code']}', _int(j['count']), _int(j['factor']));

  String get label => switch (code) {
    'go' => '$count고',
    'shake' => count > 1 ? '흔들기 $count번' : '흔들기',
    'bomb' => count > 1 ? '폭탄 $count번' : '폭탄',
    'pibak' => '피박',
    'gwangbak' => '광박',
    'gobak' => '고박',
    _ => code,
  };
}

/// "지금 스톱하면" 예상 정산(점수 + 배수 + 금액).
class HProjection {
  final int base;
  final int goPoints;
  final int total;
  final List<HMultiplier> multipliers;
  final int multiplier;
  final int amount;

  const HProjection({
    this.base = 0,
    this.goPoints = 0,
    this.total = 0,
    this.multipliers = const [],
    this.multiplier = 1,
    this.amount = 0,
  });

  factory HProjection.fromJson(dynamic raw) {
    if (raw is! Map) return const HProjection();
    final pts = raw['points'] is Map ? raw['points'] as Map : const {};
    return HProjection(
      base: _int(pts['base']),
      goPoints: _int(pts['go']),
      total: _int(pts['total']),
      multipliers: [
        for (final m in (raw['multipliers'] as List? ?? const []))
          if (m is Map) HMultiplier.fromJson(Map<String, dynamic>.from(m)),
      ],
      multiplier: _int(raw['multiplier']) == 0 ? 1 : _int(raw['multiplier']),
      amount: _int(raw['amount']),
    );
  }
}

/// 바로 직전 한 턴의 요약 — 연출·소리의 근거.
class HTurn {
  final String kind;
  final int seq;
  final String? by;
  final bool auto;
  final HCard? played;
  final HCard? flipped;
  final List<HCard> captured;
  final List<HCard> stolen;
  final List<HCard> shown;
  final List<String> events;
  final String? mode;
  final List<String> pairWith;

  const HTurn({
    required this.kind,
    required this.seq,
    this.by,
    this.auto = false,
    this.played,
    this.flipped,
    this.captured = const [],
    this.stolen = const [],
    this.shown = const [],
    this.events = const [],
    this.mode,
    this.pairWith = const [],
  });

  static HTurn? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    return HTurn(
      kind: '${j['kind']}',
      seq: _int(j['seq']),
      by: j['by'] as String?,
      auto: j['auto'] == true,
      played: j['played'] is Map
          ? HCard.fromJson(Map<String, dynamic>.from(j['played'] as Map))
          : null,
      flipped: j['flipped'] is Map
          ? HCard.fromJson(Map<String, dynamic>.from(j['flipped'] as Map))
          : null,
      captured: cardsOf(j['captured']),
      stolen: cardsOf(j['stolen']),
      shown: cardsOf(j['shown']),
      events: [for (final e in (j['events'] as List? ?? const [])) '$e'],
      mode: j['mode'] as String?,
      pairWith: [for (final e in (j['pairWith'] as List? ?? const [])) '$e'],
    );
  }

  bool has(String event) => events.contains(event);
}

class HPending {
  final String kind; // hand | deck
  final HCard card;
  final List<HCard> options;

  const HPending(this.kind, this.card, this.options);

  static HPending? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return HPending(
      '${raw['kind']}',
      HCard.fromJson(Map<String, dynamic>.from(raw['card'] as Map)),
      cardsOf(raw['options']),
    );
  }
}

/// 서버 영수증(`game:gostop:ended.receipt`). 합계 = 실제로 옮겨진 코인.
class HReceipt {
  final String reason;
  final String? winner;
  final String? loser;
  final int base;
  final int goPoints;
  final int total;
  final List<HMultiplier> multipliers;
  final int multiplier;
  final int perPointBet;
  final int amount;
  final int transferred;
  final String settlement;
  final bool auto;
  final HScore winnerScore;
  final HScore loserScore;

  const HReceipt({
    required this.reason,
    this.winner,
    this.loser,
    this.base = 0,
    this.goPoints = 0,
    this.total = 0,
    this.multipliers = const [],
    this.multiplier = 1,
    this.perPointBet = 0,
    this.amount = 0,
    this.transferred = 0,
    this.settlement = 'none',
    this.auto = false,
    this.winnerScore = const HScore(),
    this.loserScore = const HScore(),
  });

  factory HReceipt.fromJson(Map<String, dynamic> j) {
    final p = HProjection.fromJson(j);
    return HReceipt(
      reason: '${j['reason']}',
      winner: j['winner'] as String?,
      loser: j['loser'] as String?,
      base: p.base,
      goPoints: p.goPoints,
      total: p.total,
      multipliers: p.multipliers,
      multiplier: p.multiplier,
      perPointBet: _int(j['perPointBet']),
      amount: p.amount,
      transferred: _int(j['transferred']),
      settlement: '${j['settlement'] ?? 'none'}',
      auto: j['auto'] == true,
      winnerScore: HScore.fromJson(j['winnerScore']),
      loserScore: HScore.fromJson(j['loserScore']),
    );
  }

  bool get capped => settlement == 'capped' || transferred < amount;
}

/// 끝난 판 알림(`game:gostop:ended`).
class HResult {
  final String gameId;
  final String reason;
  final String? winner;
  final String? loser;
  final HReceipt receipt;
  final Map<String, List<HCard>> captures;
  final Map<String, dynamic>? series;

  const HResult({
    required this.gameId,
    required this.reason,
    required this.winner,
    required this.loser,
    required this.receipt,
    required this.captures,
    required this.series,
  });

  factory HResult.fromJson(Map<String, dynamic> j) {
    final caps = j['captures'] is Map ? j['captures'] as Map : const {};
    return HResult(
      gameId: '${j['gameId'] ?? ''}',
      reason: '${j['reason'] ?? ''}',
      winner: j['winner'] as String?,
      loser: j['loser'] as String?,
      receipt: HReceipt.fromJson(
        Map<String, dynamic>.from((j['receipt'] as Map?) ?? const {}),
      ),
      captures: {for (final e in caps.entries) '${e.key}': cardsOf(e.value)},
      series: j['series'] is Map
          ? Map<String, dynamic>.from(j['series'] as Map)
          : null,
    );
  }
}

/// 한 사람용 판 상태(`game:gostop:state`).
class GostopView {
  final Map<String, dynamic> raw;
  final String? gameId;
  final int seq;
  final String phase;
  final List<String> players;
  final String? starter;
  final String? current;
  final int perPointBet;
  final List<HCard> hand;
  final Map<String, int> handCount;
  final int deckCount;
  final List<HCard> field;
  final Map<String, List<HCard>> captures;
  final Map<String, HScore> scores;
  final Map<String, int> goCount;
  final Map<String, int> goScore;
  final Map<String, List<int>> shakes;
  final Map<String, int> bombs;
  final Map<String, int> dotan;
  final Map<int, String> ppeok;
  final HPending? pending;
  final List<String> redeals;
  final String? chongtongPlayer;
  final int? chongtongMonth;
  final List<int> shakeable;
  final List<int> bombable;
  final bool hasMoves;
  final Map<String, dynamic>? coach;
  final Map<String, HProjection> projection;
  final HProjection? stopNow;
  final HProjection? afterGo;
  final HTurn? lastTurn;
  final num? turnDeadline;
  final int turnMs;
  final num? serverNow;
  final Map<String, int> autoStreak;
  final Map<String, dynamic>? series;
  final DateTime receivedAt;

  GostopView._({
    required this.raw,
    required this.gameId,
    required this.seq,
    required this.phase,
    required this.players,
    required this.starter,
    required this.current,
    required this.perPointBet,
    required this.hand,
    required this.handCount,
    required this.deckCount,
    required this.field,
    required this.captures,
    required this.scores,
    required this.goCount,
    required this.goScore,
    required this.shakes,
    required this.bombs,
    required this.dotan,
    required this.ppeok,
    required this.pending,
    required this.redeals,
    required this.chongtongPlayer,
    required this.chongtongMonth,
    required this.shakeable,
    required this.bombable,
    required this.hasMoves,
    required this.coach,
    required this.projection,
    required this.stopNow,
    required this.afterGo,
    required this.lastTurn,
    required this.turnDeadline,
    required this.turnMs,
    required this.serverNow,
    required this.autoStreak,
    required this.series,
    required this.receivedAt,
  });

  factory GostopView.fromJson(Map<String, dynamic> j) {
    final moves = j['moves'] is Map ? j['moves'] as Map : null;
    final ct = j['chongtong'] is Map ? j['chongtong'] as Map : null;
    final preview = j['goPreview'] is Map ? j['goPreview'] as Map : null;
    final caps = j['captures'] is Map ? j['captures'] as Map : const {};
    final scores = j['scores'] is Map ? j['scores'] as Map : const {};
    final shakes = j['shakes'] is Map ? j['shakes'] as Map : const {};
    final ppeok = j['ppeok'] is Map ? j['ppeok'] as Map : const {};
    final projection = j['projection'] is Map
        ? j['projection'] as Map
        : const {};
    return GostopView._(
      raw: j,
      gameId: j['gameId'] as String?,
      seq: _int(j['seq']),
      phase: '${j['phase']}',
      players: [for (final p in (j['players'] as List? ?? const [])) '$p'],
      starter: j['starter'] as String?,
      current: j['current'] as String?,
      perPointBet: _int(j['perPointBet']),
      hand: cardsOf(j['hand']),
      handCount: _intMap(j['handCount']),
      deckCount: _int(j['deckCount']),
      field: cardsOf(j['field']),
      captures: {for (final e in caps.entries) '${e.key}': cardsOf(e.value)},
      scores: {
        for (final e in scores.entries) '${e.key}': HScore.fromJson(e.value),
      },
      goCount: _intMap(j['goCount']),
      goScore: _intMap(j['goScore']),
      shakes: {
        for (final e in shakes.entries)
          '${e.key}': [for (final m in (e.value as List? ?? const [])) _int(m)],
      },
      bombs: _intMap(j['bombs']),
      dotan: _intMap(j['dotan']),
      ppeok: {for (final e in ppeok.entries) _int(e.key): '${e.value}'},
      pending: HPending.fromJson(j['pending']),
      redeals: [for (final r in (j['redeals'] as List? ?? const [])) '$r'],
      chongtongPlayer: ct?['player'] as String?,
      chongtongMonth: ct?['month'] == null ? null : _int(ct?['month']),
      shakeable: [
        for (final m in (moves?['shakeable'] as List? ?? const [])) _int(m),
      ],
      bombable: [
        for (final m in (moves?['bombable'] as List? ?? const [])) _int(m),
      ],
      hasMoves: moves != null,
      coach: j['coach'] is Map
          ? Map<String, dynamic>.from(j['coach'] as Map)
          : null,
      projection: {
        for (final e in projection.entries)
          '${e.key}': HProjection.fromJson(e.value),
      },
      stopNow: preview == null
          ? null
          : HProjection.fromJson(preview['stopNow']),
      afterGo: preview == null
          ? null
          : HProjection.fromJson(preview['afterGo']),
      lastTurn: HTurn.fromJson(j['lastTurn']),
      turnDeadline: j['turnDeadline'] as num?,
      turnMs: _int(j['turnMs']) == 0 ? 25000 : _int(j['turnMs']),
      serverNow: j['serverNow'] as num?,
      autoStreak: _intMap(j['autoStreak']),
      series: j['series'] is Map
          ? Map<String, dynamic>.from(j['series'] as Map)
          : null,
      receivedAt: DateTime.now(),
    );
  }

  String? opponentOf(String? me) =>
      players.firstWhere((p) => p != me, orElse: () => '').isEmpty
      ? null
      : players.firstWhere((p) => p != me);

  bool get ended => phase == 'finished' || phase == 'nagari';

  List<HCard> capturesOf(String? p) => captures[p] ?? const [];

  HScore scoreOf(String? p) => scores[p] ?? const HScore();

  int goOf(String? p) => goCount[p] ?? 0;

  HProjection projectionOf(String? p) => projection[p] ?? const HProjection();

  /// 코치가 추천한 손패 id(없으면 null).
  String? get coachCardId {
    final id = coach?['cardId'];
    return coach?['type'] == 'play' && id is String ? id : null;
  }

  /// 코치 용도의 옛 형식 상태(gostop_coach.dart)로 바꿔 준다.
  GostopCoachInput coachInput(String me) => GostopCoachInput(
    phase: phase,
    isMyTurn: current == me,
    myScore: scoreOf(me).total,
    hand: [for (final c in hand) c.coach],
    field: [for (final c in field) c.coach],
    coach: coach,
    lastEvents: lastTurn?.events ?? const [],
    pendingKind: pending?.kind,
    shakeable: shakeable,
    bombable: bombable,
    dotan: dotan[me] ?? 0,
  );
}
