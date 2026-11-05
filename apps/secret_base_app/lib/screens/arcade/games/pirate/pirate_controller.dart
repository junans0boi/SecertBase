import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';

/// 벌칙 프리셋(01-grilling Q34). 서버 `PIRATE_PENALTY_PRESETS`와 같다.
const kPiratePenaltyPresets = [
  '어깨 주물러 주기',
  '칭찬 3가지',
  '노래 한 소절',
  '오늘 설거지',
  '딱밤 한 대',
  '사진 한 장 찍어 주기',
  '소원 하나 들어주기',
  '애교 한 번',
  '아이스크림 사기',
  '10분 안마',
];

const kPiratePenaltyMax = 30;

/// 서버와 같은 규칙으로 벌칙 문구를 정리한다(줄바꿈·연속 공백 → 공백 하나, 앞뒤 공백 제거).
String normalizePiratePenalty(String raw) => raw
    .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// 벌칙 문구 검증. 괜찮으면 null, 아니면 안내 문구.
String? validatePiratePenalty(String raw) {
  final text = normalizePiratePenalty(raw);
  if (text.isEmpty) return '벌칙을 적어 주세요';
  if (text.runes.length > kPiratePenaltyMax) {
    return '$kPiratePenaltyMax자까지 적을 수 있어요';
  }
  return null;
}

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

@immutable
class PiratePenalty {
  final String text;
  final String by;
  final bool done;

  const PiratePenalty({
    required this.text,
    required this.by,
    required this.done,
  });
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
  final PiratePenalty? penalty;
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
    required this.penalty,
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
    final p = m['penalty'];
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
      penalty: p is Map
          ? PiratePenalty(
              text: '${p['text'] ?? ''}',
              by: '${p['by'] ?? ''}',
              done: p['doneAt'] != null,
            )
          : null,
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

  /// 벌칙이 정해짐/완료됨(실시간 변화만).
  int penaltySetSerial = 0;
  int penaltyDoneSerial = 0;

  bool sendingPick = false;
  bool sendingPenalty = false;

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

  /// 이긴 사람이 벌칙을 정한다. 검증에 걸리면 안내 문구를 돌려주고 보내지 않는다.
  String? sendPenalty(String raw) {
    final error = validatePiratePenalty(raw);
    if (error != null) return error;
    final s = state;
    if (s == null || !s.exploded || s.winner != me || s.penalty != null) {
      return '지금은 벌칙을 정할 수 없어요';
    }
    if (sendingPenalty) return null;
    sendingPenalty = true;
    notifyListeners();
    emit('game:pirate:penalty', {'text': normalizePiratePenalty(raw)}, (_) {
      sendingPenalty = false;
      notifyListeners();
    });
    return null;
  }

  void penaltyDone() {
    final s = state;
    if (s == null || s.loser != me || s.penalty == null || s.penalty!.done) {
      return;
    }
    emit('game:pirate:penalty_done', {});
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
      sendingPenalty = false;
      // 재대결로 새 판이 왔으면 내 요청 대기 표시를 내린다.
      if (prev != null) socket.restartWaiting = false;
    } else {
      if (next.seq < prev.seq) return; // 늦게 온 옛 상태
      if (next.stabs.length > prev.stabs.length) {
        lastStab = next.stabs.last;
        stabSerial++;
      }
      if (prev.playing && next.exploded) explosionSerial++;
      if (prev.penalty == null && next.penalty != null) penaltySetSerial++;
      if (prev.penalty?.done != true && next.penalty?.done == true) {
        penaltyDoneSerial++;
      }
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
    sendingPenalty = false;
  }
}
