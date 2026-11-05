import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';
import 'penalty_models.dart';

/// 패널티킥 2.0 상태. 서버가 로비 시작 때 판을 만들고, 화면은 [sync]로 받는다.
/// 소켓 계약: docs/socket-events/penalty.md
class PenaltyController extends GameController {
  PenaltyController._() {
    on('game:penalty:state', applyState);
  }

  static final PenaltyController instance = PenaltyController._();

  PenaltyState? state;

  /// 상태를 받은 이 기기 시각(마감시각 보정 기준).
  DateTime? receivedAt;

  /// sync 응답이 왔는데 판이 없었다(로비에서 막 넘어온 직후 등).
  bool syncedEmpty = false;

  /// 내 선택을 보냈고 서버 응답을 기다리는 중.
  bool submitting = false;

  /// 이번 화면에서 sync를 보냈는지.
  bool _syncSent = false;

  /// 화면이 열릴 때 현재 상태를 요청한다.
  void sync() {
    _syncSent = true;
    emit('game:penalty:sync', const {}, (ack) {
      final raw = ack['state'];
      if (raw is Map) {
        applyState(Map<String, dynamic>.from(raw));
      } else if (ack['ok'] == true && state == null) {
        syncedEmpty = true;
        notifyListeners();
      }
    });
  }

  bool get syncSent => _syncSent;

  /// 고른 칸을 낸다(서버가 0 ≤ choice < cells를 검사한다).
  void submit(int choice) {
    final s = state;
    final me = this.me;
    if (s == null || me == null || s.finished || submitting) return;
    if (s.submitted.contains(me)) return;
    submitting = true;
    notifyListeners();
    emit('game:penalty:submit', {'choice': choice}, (ack) {
      submitting = false;
      notifyListeners();
    });
  }

  /// 서버 상태를 반영한다(테스트에서도 직접 부른다).
  @visibleForTesting
  void applyState(Map<String, dynamic> data) {
    final next = PenaltyState.fromMap(data);
    final previous = state;
    // 새 판(재대결)이 왔으면 내가 보낸 재대결 요청 표시를 지운다.
    if (previous != null && previous.gameId != next.gameId) {
      socket.restartWaiting = false;
    }
    if (previous == null || previous.round != next.round) submitting = false;
    state = next;
    receivedAt = DateTime.now();
    syncedEmpty = false;
    notifyListeners();
  }

  /// 지금 킥의 마감시각(기기 시계로 옮긴 것). 판정 연출 여유 시간은 잘라내지 않는다.
  GameDeadline? get deadline {
    final s = state;
    final at = receivedAt;
    if (s == null || at == null || s.finished || s.turnDeadlineMs == null) {
      return null;
    }
    final serverNow = s.serverNowMs ?? at.millisecondsSinceEpoch;
    final left = (s.turnDeadlineMs! - serverNow).clamp(0, 60000);
    return GameDeadline(at.add(Duration(milliseconds: left)), kPenaltyTurn);
  }

  /// 상대 id(2인 게임).
  String? get opponent {
    final s = state;
    final me = this.me;
    if (s != null) {
      for (final p in s.players) {
        if (p != me) return p;
      }
    }
    return socket.partnerId;
  }

  /// 화면에 보일 이름. 닉네임을 모르면 사용자 코드 대신 '나'/'상대'.
  String displayName(String? id) {
    if (id == null) return '상대';
    final n = nameOf(id);
    if (n.isEmpty || n == id) return id == me ? '나' : '상대';
    return n;
  }

  @override
  void reset() {
    state = null;
    receivedAt = null;
    syncedEmpty = false;
    submitting = false;
    _syncSent = false;
  }
}
