import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';

/// 카드 한 장(내 손패이거나 내가 이미 아는 카드).
@immutable
class OldMaidCard {
  final String id;
  final String rank;
  final String suit;
  final bool isJoker;

  const OldMaidCard({
    required this.id,
    required this.rank,
    required this.suit,
    this.isJoker = false,
  });

  static OldMaidCard? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString();
    final rank = raw['rank']?.toString();
    if (id == null || rank == null) return null;
    return OldMaidCard(
      id: id,
      rank: rank,
      suit: raw['suit']?.toString() ?? '',
      isJoker: raw['isJoker'] == true || rank.toUpperCase() == 'JOKER',
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'rank': rank, 'suit': suit};

  /// 정렬 순서: A, 2…10, J, Q, K, 조커(맨 오른쪽).
  int get order => isJoker ? 99 : (_rankOrder[rank] ?? 50);

  /// 화면 문구용 이름: "하트 7", "조커".
  String get label {
    if (isJoker) return '조커';
    final suitName = switch (suitFrom(suit)) {
      Suit.spade => '스페이드',
      Suit.heart => '하트',
      Suit.diamond => '다이아',
      Suit.club => '클로버',
      null => '',
    };
    return suitName.isEmpty ? rank : '$suitName $rank';
  }

  /// 목적격 조사(을/를)까지 붙인 이름: "하트 7을", "스페이드 K를", "조커를".
  String get labelObject => '$label${objectParticle(isJoker ? '조커' : rank)}';
}

const _rankOrder = {
  'A': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  '10': 10,
  'J': 11,
  'Q': 12,
  'K': 13,
};

/// 카드 숫자를 읽었을 때 받침이 있는지(삼·육·칠·팔·십)로 을/를을 고른다.
String objectParticle(String word) {
  const withFinal = {'3', '6', '7', '8', '10'};
  if (_rankOrder.containsKey(word)) return withFinal.contains(word) ? '을' : '를';
  return _hasFinal(word) ? '을' : '를';
}

/// 주격 조사 이/가.
String subjectParticle(String word) => _hasFinal(word) ? '이' : '가';

bool _hasFinal(String word) {
  if (word.isEmpty) return false;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// 최근 기록 한 줄(공개 정보: 누가, 짝이었는지, 짝이면 랭크).
@immutable
class OldMaidLogEntry {
  final String by;
  final bool paired;
  final String? rank;
  final int at;

  const OldMaidLogEntry({
    required this.by,
    required this.paired,
    required this.rank,
    required this.at,
  });
}

/// 내 시점의 뽑기 결과(`game:oldmaid:drawn`).
@immutable
class OldMaidDraw {
  final int seq;
  final String role; // drawer | victim | spectator
  final String by;
  final String from;
  final int slot;
  final OldMaidCard? card;
  final OldMaidCard? matched;
  final bool paired;
  final String? pairedRank;
  final bool jokerMoved;
  final bool auto;
  final bool finished;

  /// 이 뽑기 직전의 내 손패(정렬 전)와 상대 손패 수. 연출의 출발 위치 계산에 쓴다.
  final List<OldMaidCard> handBefore;
  final int oppCountBefore;

  const OldMaidDraw({
    required this.seq,
    required this.role,
    required this.by,
    required this.from,
    required this.slot,
    required this.card,
    required this.matched,
    required this.paired,
    required this.pairedRank,
    required this.jokerMoved,
    required this.auto,
    required this.finished,
    required this.handBefore,
    required this.oppCountBefore,
  });

  bool get isDrawer => role == 'drawer';
  bool get isVictim => role == 'victim';
}

/// 도둑잡기 2.0 상태. 서버 `game:oldmaid:state`/`drawn`을 받아 화면에 맞게 정리한다.
class OldMaidController extends GameController {
  OldMaidController._() {
    on('game:oldmaid:state', handleState);
    on('game:oldmaid:drawn', handleDrawn);
  }

  static final OldMaidController instance = OldMaidController._();

  static const gameType = 'oldmaid';

  String? gameId;
  String status = 'none';
  List<String> players = const [];
  String? turn;
  String? firstTurn;
  List<OldMaidCard> myHand = const [];
  int oppCount = 0;
  List<String> discards = const [];
  List<OldMaidLogEntry> log = const [];
  Map<String, dynamic>? result;
  Map<String, dynamic>? series;
  GameDeadline? deadline;
  int drawCount = 0;
  Map<String, int> timeouts = const {};

  /// 판이 끝났을 때 공개되는 상대 손패(조커).
  List<OldMaidCard> oppRevealed = const [];

  OldMaidDraw? lastDraw;
  int drawSeq = 0;

  /// 내가 마지막으로 뽑아 손에 남은 카드(NEW 표시). 다음 뽑기 때까지 유지.
  String? newCardId;
  bool sending = false;

  /// 거부 사유 등 짧은 안내.
  String? notice;
  int noticeSeq = 0;

  bool get hasGame => gameId != null;
  bool get playing => status == 'playing';
  bool get finished => status == 'finished';
  bool get myTurn => playing && turn != null && turn == me;

  String? get opponent {
    for (final p in players) {
      if (p != me) return p;
    }
    return socket.partnerId;
  }

  String? get winner => result?['winner'] as String?;
  String? get loser => result?['loser'] as String?;
  String get resultReason => result?['reason']?.toString() ?? 'joker';

  /// 랭크순 정렬, 조커는 맨 오른쪽. 서버 순서(섞임)는 화면에 드러나지 않는다.
  static List<OldMaidCard> sortHand(Iterable<OldMaidCard> hand) {
    final list = List<OldMaidCard>.of(hand);
    list.sort((a, b) {
      final o = a.order.compareTo(b.order);
      return o != 0 ? o : a.suit.compareTo(b.suit);
    });
    return list;
  }

  List<OldMaidCard> get sortedHand => sortHand(myHand);

  /// 화면에 쓸 이름. 서버가 닉네임을 모르면 사용자 코드 대신 '나'/'상대'.
  String displayName(String? userId) {
    if (userId == null) return '상대';
    final name = nameOf(userId);
    if (name.isEmpty || name == userId) return userId == me ? '나' : '상대';
    return name;
  }

  void sync() => emit('game:oldmaid:sync');

  /// 상대 손패 [slot]번째 카드를 뽑는다(서버에는 위치 별칭만 보낸다).
  void draw(int slot) {
    if (!myTurn || sending) return;
    sending = true;
    notifyListeners();
    emit('game:oldmaid:draw', {'slot': slot, 'gameId': ?gameId}, (ack) {
      sending = false;
      if (ack['ok'] != true) {
        final reason = ack['reason']?.toString();
        notice = switch (reason) {
          'not_your_turn' => '지금은 상대 차례예요',
          'game_over' => '이미 끝난 판이에요',
          'stale_game' || 'invalid_slot' => '카드가 바뀌었어요. 다시 골라 주세요',
          'no_game' => '판을 찾지 못했어요',
          _ => '카드를 뽑지 못했어요. 다시 눌러 주세요',
        };
        noticeSeq++;
        sync();
      }
      notifyListeners();
    });
  }

  @visibleForTesting
  void handleState(Map<String, dynamic> data) {
    final id = data['gameId']?.toString();
    if (id != gameId) {
      // 새 판(첫 판 또는 재대결): 지난 판의 연출·표시를 지운다.
      lastDraw = null;
      newCardId = null;
      sending = false;
      if (gameId != null) socket.restartWaiting = false;
    }
    gameId = id;
    status = data['status']?.toString() ?? 'playing';
    players = [for (final p in (data['players'] as List? ?? const [])) '$p'];
    turn = data['turn'] as String?;
    firstTurn = data['firstTurn'] as String?;
    final hands = (data['hands'] as Map?) ?? const {};
    final counts = (data['handCounts'] as Map?) ?? const {};
    final mine = me;
    final opp = opponent;
    myHand = [
      for (final c in (hands[mine] as List? ?? const []))
        ?OldMaidCard.fromMap(c),
    ];
    oppCount =
        (counts[opp] as num?)?.toInt() ?? (hands[opp] as List?)?.length ?? 0;
    oppRevealed = [
      for (final c in (hands[opp] as List? ?? const []))
        ?OldMaidCard.fromMap(c),
    ];
    if (newCardId != null && !myHand.any((c) => c.id == newCardId)) {
      newCardId = null;
    }
    discards = [for (final r in (data['discards'] as List? ?? const [])) '$r'];
    log = [
      for (final e in (data['log'] as List? ?? const []))
        if (e is Map)
          OldMaidLogEntry(
            by: '${e['by']}',
            paired: e['paired'] == true,
            rank: e['rank']?.toString(),
            at: (e['at'] as num?)?.toInt() ?? 0,
          ),
    ];
    result = data['result'] is Map
        ? Map<String, dynamic>.from(data['result'] as Map)
        : null;
    series = data['series'] is Map
        ? Map<String, dynamic>.from(data['series'] as Map)
        : null;
    drawCount = (data['drawCount'] as num?)?.toInt() ?? 0;
    timeouts = {
      for (final e in ((data['timeouts'] as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num?)?.toInt() ?? 0,
    };
    final turnMs = (data['turnMs'] as num?)?.toInt() ?? 25000;
    deadline = playing
        ? GameDeadline.fromServer(
            deadlineMs: data['turnDeadline'] as num?,
            serverNowMs: data['serverNow'] as num?,
            // 첫 차례·뽑기 연출 시간이 더해진 마감도 링이 넘치지 않게 조금 여유를 둔다.
            total: Duration(milliseconds: turnMs + 8000),
          )
        : null;
    notifyListeners();
  }

  @visibleForTesting
  void handleDrawn(Map<String, dynamic> data) {
    final id = data['gameId']?.toString();
    if (id != null && gameId != null && id != gameId) return;
    final role = data['role']?.toString() ?? 'spectator';
    final card = OldMaidCard.fromMap(data['card']);
    final paired = data['paired'] == true;
    lastDraw = OldMaidDraw(
      seq: ++drawSeq,
      role: role,
      by: '${data['by']}',
      from: '${data['from']}',
      slot: (data['slot'] as num?)?.toInt() ?? 0,
      card: card,
      matched: OldMaidCard.fromMap(data['matched']),
      paired: paired,
      pairedRank: data['pairedRank']?.toString(),
      jokerMoved: data['jokerMoved'] == true,
      auto: data['auto'] == true,
      finished: data['finished'] == true,
      handBefore: List.of(myHand),
      oppCountBefore: oppCount,
    );
    if (role == 'drawer') {
      sending = false;
      newCardId = paired ? null : card?.id;
    }
    notifyListeners();
  }

  /// 뽑기 결과 문구. 뽑은 쪽과 뺏긴 쪽이 서로 다르게 읽는다.
  String? drawMessage([OldMaidDraw? d]) {
    final draw = d ?? lastDraw;
    final card = draw?.card;
    if (draw == null || card == null) return null;
    if (draw.isDrawer) {
      final head = draw.auto ? '시간이 다 돼서 ' : '';
      if (draw.jokerMoved) return '$head앗, 조커를 뽑았어요!';
      if (draw.paired) return '$head${card.labelObject} 뽑았어요 · ${card.rank} 짝!';
      return '$head${card.labelObject} 뽑았어요';
    }
    if (draw.isVictim) {
      final who = displayName(draw.by);
      if (draw.jokerMoved) return '조커를 $who에게 넘겼어요!';
      final tail = draw.paired ? ' · $who${subjectParticle(who)} 짝을 맞췄어요' : '';
      return '${card.labelObject} 뺏겼어요$tail';
    }
    return null;
  }

  /// 최근 기록 한 줄: "나 · 7 짝!", "민지 · 한 장 뽑음".
  String logLine(OldMaidLogEntry e) {
    final who = e.by == me ? '나' : displayName(e.by);
    return e.paired ? '$who · ${e.rank} 짝!' : '$who · 한 장 뽑음';
  }

  @override
  void reset() {
    gameId = null;
    status = 'none';
    players = const [];
    turn = null;
    firstTurn = null;
    myHand = const [];
    oppCount = 0;
    oppRevealed = const [];
    discards = const [];
    log = const [];
    result = null;
    series = null;
    deadline = null;
    drawCount = 0;
    timeouts = const {};
    lastDraw = null;
    newCardId = null;
    sending = false;
    notice = null;
  }

  @visibleForTesting
  void resetForTest() {
    reset();
    notifyListeners();
  }
}
