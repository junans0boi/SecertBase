import 'package:flutter/material.dart';

/// 원카드 카드 한 장(서버 `{ id, color, value }`). color는 red|yellow|green|blue|null(와일드).
@immutable
class OneCard {
  final String id;
  final String? color;
  final String value;

  const OneCard({required this.id, required this.color, required this.value});

  static OneCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final value = raw['value'];
    if (id is! String || value is! String) return null;
    final color = raw['color'];
    return OneCard(id: id, color: color is String ? color : null, value: value);
  }

  static List<OneCard> listFrom(Object? raw) => raw is List
      ? raw.map(OneCard.fromJson).whereType<OneCard>().toList()
      : const [];

  bool get isWild => value == 'wild' || value == 'wild_draw4';
  bool get isNumber => int.tryParse(value) != null;

  /// 화면에 그리는 기호. 영어 글자는 쓰지 않는다(Q54).
  String get symbol => switch (value) {
    'skip' => '⊘',
    'reverse' => '⇄',
    'draw2' => '+2',
    'wild_draw4' => '+4',
    'wild' => '◐',
    'discard_all' => '모두',
    _ => value,
  };

  /// 접근성·안내용 한국어 이름.
  String get label {
    final kind = switch (value) {
      'skip' => '건너뛰기',
      'reverse' => '방향 바꾸기',
      'draw2' => '두 장 더하기',
      'wild_draw4' => '네 장 더하기 색 바꾸기',
      'wild' => '색 바꾸기',
      'discard_all' => '같은 색 모두 내기',
      _ => '숫자 $value',
    };
    return color == null ? kind : '${OneCardColors.name(color)} $kind';
  }

  /// 손패 정렬 순서: 색(로즈·허니·세이지·스카이·와일드) → 숫자 → 기능.
  int get sortKey {
    final c = OneCardColors.order.indexOf(color ?? '');
    final v = isNumber
        ? int.parse(value)
        : 10 +
              const [
                'skip',
                'reverse',
                'draw2',
                'discard_all',
                'wild',
                'wild_draw4',
              ].indexOf(value);
    return (c < 0 ? 9 : c) * 100 + v;
  }
}

/// 보석 톤 4색(로즈·허니·스카이·세이지). 서버 색 이름(red/yellow/blue/green)을 이 색으로 그린다.
class OneCardColors {
  OneCardColors._();

  static const order = ['red', 'yellow', 'green', 'blue'];

  static const rose = Color(0xFFD94A72);
  static const honey = Color(0xFFE2A430);
  static const sky = Color(0xFF3F8FD9);
  static const sage = Color(0xFF3FA37C);

  static Color of(String? color) => switch (color) {
    'red' => rose,
    'yellow' => honey,
    'blue' => sky,
    'green' => sage,
    _ => const Color(0xFF2A1640),
  };

  /// 같은 색의 밝은 면(그라데이션 위쪽).
  static Color light(String? color) =>
      Color.lerp(of(color), Colors.white, 0.32)!;

  /// 같은 색의 깊은 면(그라데이션 아래쪽).
  static Color deep(String? color) =>
      Color.lerp(of(color), const Color(0xFF12061C), 0.38)!;

  static String name(String? color) => switch (color) {
    'red' => '로즈',
    'yellow' => '허니',
    'blue' => '스카이',
    'green' => '세이지',
    _ => '',
  };
}

/// 방금 일어난 일(서버 `lastAction`). 연출·소리의 근거.
@immutable
class OneCardAction {
  final int seq;
  final String type; // deal|play|draw|pass|call|catch|challenge
  final String? by;
  final List<OneCard> cards;
  final String? effect; // skip|reverse|draw2|draw4|wild|discard_all
  final String? declaredColor;
  final bool colorChanged;
  final int count;
  final bool penalty;
  final bool auto;
  final String? target;
  final bool protectedCatch;
  final bool success;
  final String? drawnPlayer;
  final int drawnCount;
  final List<String> cardIds;

  const OneCardAction({
    required this.seq,
    required this.type,
    this.by,
    this.cards = const [],
    this.effect,
    this.declaredColor,
    this.colorChanged = false,
    this.count = 0,
    this.penalty = false,
    this.auto = false,
    this.target,
    this.protectedCatch = false,
    this.success = false,
    this.drawnPlayer,
    this.drawnCount = 0,
    this.cardIds = const [],
  });

  static OneCardAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final ids = raw['cardIds'];
    return OneCardAction(
      seq: (raw['seq'] as num?)?.toInt() ?? 0,
      type: raw['type'] as String? ?? '',
      by: raw['by'] as String?,
      cards: OneCard.listFrom(raw['cards']),
      effect: raw['effect'] as String?,
      declaredColor: raw['declaredColor'] as String?,
      colorChanged: raw['colorChanged'] == true,
      count: (raw['count'] as num?)?.toInt() ?? 0,
      penalty: raw['penalty'] == true,
      auto: raw['auto'] == true,
      target: raw['target'] as String?,
      protectedCatch: raw['protected'] == true,
      success: raw['success'] == true,
      drawnPlayer: raw['drawnPlayer'] as String?,
      drawnCount: (raw['drawnCount'] as num?)?.toInt() ?? 0,
      cardIds: ids is List ? ids.whereType<String>().toList() : const [],
    );
  }
}

/// 한 사람에게 보이는 판(서버 `game:uno:state`).
@immutable
class OneCardView {
  final String? gameId;
  final String mode;
  final List<String> players;
  final String? currentPlayer;
  final OneCard? topCard;
  final List<OneCard> recentDiscards;
  final String? declaredColor;
  final String? currentColor;
  final int drawStack;
  final String? drawStackType;
  final Map<String, int> handCount;
  final List<OneCard> hand;
  final int deckCount;
  final String? unoCallNeeded;
  final String? drawnCardId;
  final Set<String> playable;
  final bool canChallenge;
  final int? turnDeadline;
  final int turnMs;
  final int? serverNow;
  final Map<String, Map<String, dynamic>> equippedItems;
  final int stake;
  final Map<String, dynamic>? series;
  final int seq;
  final OneCardAction? lastAction;
  final DateTime receivedAt;

  const OneCardView({
    required this.gameId,
    required this.mode,
    required this.players,
    required this.currentPlayer,
    required this.topCard,
    required this.recentDiscards,
    required this.declaredColor,
    required this.currentColor,
    required this.drawStack,
    required this.drawStackType,
    required this.handCount,
    required this.hand,
    required this.deckCount,
    required this.unoCallNeeded,
    required this.drawnCardId,
    required this.playable,
    required this.canChallenge,
    required this.turnDeadline,
    required this.turnMs,
    required this.serverNow,
    required this.equippedItems,
    required this.stake,
    required this.series,
    required this.seq,
    required this.lastAction,
    required this.receivedAt,
  });

  factory OneCardView.fromJson(Map<String, dynamic> m, {DateTime? receivedAt}) {
    final counts = <String, int>{};
    final rawCounts = m['handCount'];
    if (rawCounts is Map) {
      rawCounts.forEach((k, v) => counts['$k'] = (v as num?)?.toInt() ?? 0);
    }
    final items = <String, Map<String, dynamic>>{};
    final rawItems = m['equippedItems'];
    if (rawItems is Map) {
      rawItems.forEach((k, v) {
        if (v is Map) items['$k'] = Map<String, dynamic>.from(v);
      });
    }
    final players = m['players'];
    final playable = m['playable'];
    final series = m['series'];
    return OneCardView(
      gameId: m['gameId'] as String?,
      mode: m['mode'] as String? ?? 'go_wild',
      players: players is List
          ? players.map((e) => '$e').toList()
          : counts.keys.toList(),
      currentPlayer: m['currentPlayer'] as String? ?? m['turn'] as String?,
      topCard: OneCard.fromJson(m['topCard']),
      recentDiscards: OneCard.listFrom(m['recentDiscards']),
      declaredColor: m['declaredColor'] as String?,
      currentColor: m['currentColor'] as String?,
      drawStack: (m['drawStack'] as num?)?.toInt() ?? 0,
      drawStackType: m['drawStackType'] as String?,
      handCount: counts,
      hand: OneCard.listFrom(m['hand']),
      deckCount: (m['deckCount'] as num?)?.toInt() ?? 0,
      unoCallNeeded: m['unoCallNeeded'] as String?,
      drawnCardId: m['drawnCardId'] as String?,
      playable: playable is List
          ? playable.whereType<String>().toSet()
          : const <String>{},
      canChallenge: m['canChallenge'] == true,
      turnDeadline: (m['turnDeadline'] as num?)?.toInt(),
      turnMs: (m['turnMs'] as num?)?.toInt() ?? 20000,
      serverNow: (m['serverNow'] as num?)?.toInt(),
      equippedItems: items,
      stake: (m['stake'] as num?)?.toInt() ?? 0,
      series: series is Map ? Map<String, dynamic>.from(series) : null,
      seq: (m['seq'] as num?)?.toInt() ?? 0,
      lastAction: OneCardAction.fromJson(m['lastAction']),
      receivedAt: receivedAt ?? DateTime.now(),
    );
  }

  String? opponentOf(String? me) => players
      .where((p) => p != me)
      .cast<String?>()
      .firstWhere((_) => true, orElse: () => null);

  int countOf(String? player) => player == null ? 0 : (handCount[player] ?? 0);
}

/// 판이 끝난 결과(서버 `game:uno:ended`).
@immutable
class OneCardResult {
  final String? gameId;
  final String? winner;
  final String? loser;
  final String reason; // empty_hand | forfeit
  final Map<String, List<OneCard>> hands;
  final Map<String, dynamic>? series;
  final int stake;

  const OneCardResult({
    required this.gameId,
    required this.winner,
    required this.loser,
    required this.reason,
    required this.hands,
    required this.series,
    required this.stake,
  });

  bool get forfeit => reason == 'forfeit';

  factory OneCardResult.fromJson(Map<String, dynamic> m) {
    final hands = <String, List<OneCard>>{};
    final rawHands = m['hands'];
    if (rawHands is Map) {
      rawHands.forEach((k, v) => hands['$k'] = OneCard.listFrom(v));
    }
    final series = m['series'];
    return OneCardResult(
      gameId: m['gameId'] as String?,
      winner: m['winner'] as String?,
      loser: m['loser'] as String?,
      reason: m['reason'] as String? ?? 'empty_hand',
      hands: hands,
      series: series is Map ? Map<String, dynamic>.from(series) : null,
      stake: (m['stake'] as num?)?.toInt() ?? 0,
    );
  }
}
