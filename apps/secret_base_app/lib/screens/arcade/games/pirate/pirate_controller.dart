import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';

/// 받침에 맞춘 조사 "이/가". 한글이 아니면 "이(가)".
String josaIGa(String name) {
  if (name.isEmpty) return '이(가)';
  final code = name.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return '이(가)';
  return (code - 0xAC00) % 28 == 0 ? '가' : '이';
}

/// 폭탄 확률에 따른 해적 표정 4단계(여유 → 걱정 → 땀 → 비명).
enum PirateMood { calm, worried, sweaty, scream }

PirateMood pirateMoodFor(int riskPct) {
  if (riskPct >= 50) return PirateMood.scream;
  if (riskPct >= 30) return PirateMood.sweaty;
  if (riskPct >= 20) return PirateMood.worried;
  return PirateMood.calm;
}

@immutable
class PirateStab {
  final int slot;
  final String by;
  final bool auto;

  const PirateStab({required this.slot, required this.by, this.auto = false});
}

/// 서버 `game:pirate:state`를 옮긴 것. 두 사람이 같은 상태를 본다.
@immutable
class PirateState {
  final String gameId;
  final int round;
  final int slots;
  final List<int> pickedSlots;
  final List<PirateStab> stabs;
  final List<String> players;
  final String? firstTurn;
  final String? currentTurn;
  final String phase;
  final int remaining;
  final int riskPct;
  final GameDeadline? deadline;
  final int? bombSlot;
  final String? winner;
  final String? loser;
  final String? reason;
  final int seq;
  final Map<String, dynamic>? series;

  const PirateState({
    required this.gameId,
    required this.round,
    required this.slots,
    required this.pickedSlots,
    required this.stabs,
    required this.players,
    required this.firstTurn,
    required this.currentTurn,
    required this.phase,
    required this.remaining,
    required this.riskPct,
    required this.deadline,
    required this.bombSlot,
    required this.winner,
    required this.loser,
    required this.reason,
    required this.seq,
    required this.series,
  });

  bool get playing => phase == 'playing';
  bool get exploded => phase == 'exploded';

  static int _int(Object? v, int fallback) => (v as num?)?.toInt() ?? fallback;

  factory PirateState.fromMap(Map<String, dynamic> m, {DateTime? receivedAt}) {
    final slots = _int(m['slots'], 8);
    final picked = (m['pickedSlots'] as List? ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    final stabs = (m['stabs'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => PirateStab(
            slot: _int(e['slot'], -1),
            by: '${e['by']}',
            auto: e['auto'] == true,
          ),
        )
        .toList();
    final remaining = _int(m['remaining'], slots - picked.length);
    final turnMs = _int(m['turnMs'], 20000);
    final deadlineMs = m['turnDeadline'] as num?;
    final serverNow = m['serverNow'] as num?;
    GameDeadline? deadline;
    if (deadlineMs != null) {
      final left = serverNow == null
          ? turnMs
          : (deadlineMs - serverNow).toInt().clamp(0, 1 << 30);
      deadline = GameDeadline.fromServer(
        deadlineMs: deadlineMs,
        serverNowMs: serverNow,
        total: Duration(milliseconds: left > turnMs ? left : turnMs),
        receivedAt: receivedAt,
      );
    }
    return PirateState(
      gameId: '${m['gameId'] ?? ''}',
      round: _int(m['round'], 1),
      slots: slots,
      pickedSlots: picked,
      stabs: stabs,
      players: (m['players'] as List? ?? const []).map((e) => '$e').toList(),
      firstTurn: m['firstTurn'] as String?,
      currentTurn: m['currentTurn'] as String?,
      phase: '${m['phase'] ?? 'playing'}',
      remaining: remaining,
      riskPct: _int(
        m['riskPct'],
        remaining > 0 ? (100 / remaining).round() : 100,
      ),
      deadline: deadline,
      bombSlot: (m['bombSlot'] as num?)?.toInt(),
      winner: m['winner'] as String?,
      loser: m['loser'] as String?,
      reason: m['reason'] as String?,
      seq: _int(m['seq'], 0),
      series: m['series'] is Map
          ? Map<String, dynamic>.from(m['series'] as Map)
          : null,
    );
  }
}

/// 해적 룰렛 2.0 상태. 서버가 로비 시작 때 판을 만들고, 화면은 열릴 때 [sync]한다.
class PirateController extends GameController {
  PirateController._() {
    on('game:pirate:state', (data) => apply(PirateState.fromMap(data)));
  }

  static final PirateController instance = PirateController._();

  PirateState? state;
  bool syncing = false;

  /// 이번 상태 변화에서 새로 꽂힌 칼(연출용). [stabSerial]이 바뀌면 새 칼.
  PirateStab? lastStab;
  int stabSerial = 0;

  /// 이 기기에서 실시간으로 본 폭발 횟수(복원으로 들어온 폭발은 세지 않는다).
  int explosionSerial = 0;

  bool sendingPick = false;

  bool get isMyTurn =>
      state != null && state!.playing && state!.currentTurn == me;

  String? get opponent {
    final s = state;
    if (s != null) {
      for (final p in s.players) {
        if (p != me) return p;
      }
    }
    return socket.partnerId;
  }

  /// 화면에 쓸 이름. 닉네임을 모르면 사용자 코드 대신 "나"/"상대".
  String displayName(String? id) {
    if (id == null) return '상대';
    final n = nameOf(id);
    if (n.isEmpty || n == id) return id == me ? '나' : '상대';
    return n;
  }

  void sync() {
    syncing = true;
    notifyListeners();
    emit('game:pirate:sync', {}, (ack) {
      syncing = false;
      final raw = ack['state'];
      if (raw is Map) {
        apply(PirateState.fromMap(Map<String, dynamic>.from(raw)));
      } else {
        notifyListeners();
      }
    });
  }

  void pick(int slot) {
    final s = state;
    if (s == null || !isMyTurn || sendingPick) return;
    if (slot < 0 || slot >= s.slots || s.pickedSlots.contains(slot)) return;
    sendingPick = true;
    notifyListeners();
    emit('game:pirate:pick', {'slot': slot, 'gameId': s.gameId}, (_) {
      sendingPick = false;
      notifyListeners();
    });
  }

  void requestRestart() => socket.requestRestart('pirate');

  /// 새 상태를 받아 연출용 변화를 계산한다.
  @visibleForTesting
  void apply(PirateState next) {
    final prev = state;
    final sameGame = prev != null && prev.gameId == next.gameId;
    if (!sameGame) {
      lastStab = null;
      sendingPick = false;
      // 재대결로 새 판이 왔으면 내 요청 대기 표시를 내린다.
      if (prev != null) socket.restartWaiting = false;
    } else {
      if (next.seq < prev.seq) return; // 늦게 온 옛 상태
      if (next.stabs.length > prev.stabs.length) {
        lastStab = next.stabs.last;
        stabSerial++;
      }
      if (prev.playing && next.exploded) explosionSerial++;
    }
    state = next;
    syncing = false;
    notifyListeners();
  }

  @override
  void reset() {
    state = null;
    lastStab = null;
    syncing = false;
    sendingPick = false;
  }
}
