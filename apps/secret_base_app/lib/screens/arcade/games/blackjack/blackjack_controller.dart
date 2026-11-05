import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';
import 'blackjack_rules.dart';

/// 블랙잭 2.0 상태. 서버 `game:blackjack:updated`(보는 사람별 투영)를 그대로 들고 있고,
/// 화면은 [view]를 읽어 그린다. 계약: docs/socket-events/blackjack.md.
class BlackjackController extends GameController {
  BlackjackController._() {
    on('game:blackjack:updated', apply);
  }

  static final BlackjackController instance = BlackjackController._();

  BlackjackView? view;

  /// 히트·스탠드·준비를 보내고 다음 상태를 기다리는 중(연타 방지).
  bool pending = false;

  /// 서버 상태를 반영한다(테스트에서도 직접 부른다).
  void apply(Map<String, dynamic> data) {
    view = BlackjackView.fromMap(data, me: me, receivedAt: DateTime.now());
    pending = false;
    notifyListeners();
  }

  /// 화면이 열릴 때 현재 상태를 다시 받는다(서버가 로비 시작 때 판을 만든다).
  void sync() => emit('game:blackjack:sync');

  void hit() => _act('game:blackjack:hit');

  void stand() => _act('game:blackjack:stand');

  void nextRound() => _act('game:blackjack:next_round');

  void _act(String event) {
    if (pending) return;
    pending = true;
    notifyListeners();
    emit(event, const {}, (ack) {
      if (ack['ok'] == false && pending) {
        pending = false;
        notifyListeners();
      }
    });
  }

  /// 테스트용: 상태를 비우고 알린다.
  @visibleForTesting
  void debugClear() {
    reset();
    notifyListeners();
  }

  @override
  void reset() {
    view = null;
    pending = false;
  }
}

/// 한 번 받은 서버 상태를 화면이 쓰기 좋게 정리한 값.
class BlackjackView {
  final Map<String, dynamic> raw;
  final String? me;
  final String gameId;
  final String status;
  final String phase;
  final List<String> players;
  final int round;
  final int maxRounds;
  final int winsNeeded;
  final Map<String, int> wins;
  final String? firstPlayer;
  final String? currentTurn;
  final GameDeadline? deadline;
  final Map<String, List<Map<String, dynamic>>> hands;
  final Map<String, String> statuses;
  final Map<String, int> scores;
  final Map<String, int> visibleScores;
  final Map<String, bool> ready;
  final Map<String, dynamic>? lastRoundResult;
  final Map<String, dynamic>? result;
  final Map<String, dynamic>? series;

  const BlackjackView({
    required this.raw,
    required this.me,
    required this.gameId,
    required this.status,
    required this.phase,
    required this.players,
    required this.round,
    required this.maxRounds,
    required this.winsNeeded,
    required this.wins,
    required this.firstPlayer,
    required this.currentTurn,
    required this.deadline,
    required this.hands,
    required this.statuses,
    required this.scores,
    required this.visibleScores,
    required this.ready,
    required this.lastRoundResult,
    required this.result,
    required this.series,
  });

  factory BlackjackView.fromMap(
    Map<String, dynamic> m, {
    required String? me,
    DateTime? receivedAt,
  }) {
    Map<String, int> ints(Object? v) => {
      for (final e in ((v as Map?) ?? const {}).entries)
        '${e.key}': (e.value as num?)?.toInt() ?? 0,
    };
    final rawHands = (m['hands'] as Map?) ?? const {};
    final turnMs = (m['turnMs'] as num?)?.toInt() ?? 30000;
    return BlackjackView(
      raw: m,
      me: me,
      gameId: '${m['gameId'] ?? ''}',
      status: '${m['status'] ?? 'playing'}',
      phase: '${m['phase'] ?? 'player_turn'}',
      players: [for (final p in (m['players'] as List?) ?? const []) '$p'],
      round: (m['round'] as num?)?.toInt() ?? 1,
      maxRounds: (m['maxRounds'] as num?)?.toInt() ?? 5,
      winsNeeded: (m['winsNeeded'] as num?)?.toInt() ?? 2,
      wins: ints(m['wins']),
      firstPlayer: m['firstPlayer'] as String?,
      currentTurn: m['currentTurn'] as String?,
      deadline: GameDeadline.fromServer(
        deadlineMs: m['turnDeadline'] as num?,
        serverNowMs: m['serverNow'] as num?,
        total: Duration(milliseconds: turnMs),
        receivedAt: receivedAt,
      ),
      hands: {
        for (final e in rawHands.entries)
          '${e.key}': [
            for (final c in (e.value as List?) ?? const [])
              Map<String, dynamic>.from(c as Map),
          ],
      },
      statuses: {
        for (final e in ((m['statuses'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      scores: ints(m['scores']),
      visibleScores: ints(m['visibleScores']),
      ready: {
        for (final e in ((m['ready'] as Map?) ?? const {}).entries)
          '${e.key}': e.value == true,
      },
      lastRoundResult: (m['lastRoundResult'] as Map?)?.cast<String, dynamic>(),
      result: (m['result'] as Map?)?.cast<String, dynamic>(),
      series: (m['series'] as Map?)?.cast<String, dynamic>(),
    );
  }

  String? get opponent {
    for (final p in players) {
      if (p != me) return p;
    }
    return null;
  }

  bool get finished => status == 'finished';
  bool get playing => status == 'playing' && phase == 'player_turn';
  bool get roundOver => phase == 'round_result' || phase == 'finished';
  bool get isMyTurn => playing && currentTurn != null && currentTurn == me;

  List<Map<String, dynamic>> handOf(String? id) =>
      id == null ? const [] : (hands[id] ?? const []);

  /// 내 손의 총점(서버 값이 없으면 직접 계산).
  int myScore() => scores[me] ?? blackjackScore(handOf(me));

  int winsOf(String? id) => id == null ? 0 : (wins[id] ?? 0);

  /// 이번 라운드를 끝낸 결과가 화면에 보여야 하는가(공개 연출 대상).
  bool get showsRoundResult =>
      roundOver &&
      lastRoundResult != null &&
      (lastRoundResult!['round'] as num?)?.toInt() == round;

  bool get canHit => isMyTurn && myScore() < 21;
  bool get canStand => isMyTurn;
}
