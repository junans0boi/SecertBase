import 'package:flutter/foundation.dart';

import '../game_controller.dart';
import 'gostop_models.dart';

/// 고스톱 2.0 상태 컨트롤러. 계약: docs/socket-events/gostop.md
///
/// 서버가 로비 시작과 함께 판을 만들고, 화면이 열리면 [sync]로 현재 상태를 받는다.
/// 상태는 `game:gostop:state`(한 사람용 view) 하나로 오고, 끝나면 `game:gostop:ended`.
class GostopController extends GameController {
  static final GostopController instance = GostopController._();

  GostopController._() {
    on('game:gostop:state', _onState);
    on('game:gostop:ended', _onEnded);
  }

  static const gameType = 'gostop';

  /// 거부 사유 한국어 안내(서버는 코드만 보낸다).
  static const reasonMessages = <String, String>{
    'not_your_turn': '아직 내 차례가 아니에요.',
    'invalid_phase': '지금은 할 수 없는 동작이에요.',
    'card_not_in_hand': '손에 없는 패예요. 화면을 다시 불러올게요.',
    'cannot_shake': '지금은 흔들 수 없어요.',
    'cannot_bomb': '폭탄을 낼 수 있는 월이 아니에요.',
    'no_dotan': '도탄 차례가 아니에요.',
    'invalid_choice': '고를 수 없는 패예요.',
    'invalid_decision': '고 또는 스톱만 고를 수 있어요.',
    'game_over': '이미 끝난 판이에요.',
    'no_game': '진행 중인 판이 없어요.',
    'not_in_game': '이 판의 참가자가 아니에요.',
    'internal_error': '잠시 문제가 생겼어요. 다시 시도해 주세요.',
  };

  static const _sharedNoticeReasons = {
    'not_your_turn',
    'no_game',
    'internal_error',
    'invalid_payload',
    'not_joined',
  };

  GostopView? view;
  HResult? result;

  /// sync 결과. null이면 아직 모름, 'no_game'이면 판이 아직 없다.
  String? syncStatus;
  bool syncing = false;

  /// 화면 안 안내(거부 사유 등). [noticeSeq]가 바뀔 때마다 한 번 띄운다.
  String? notice;
  int noticeSeq = 0;

  /// 같은 화면에서 이어지는 판 수(새 판이면 바뀐다).
  int gameEpoch = 0;

  String? get opponent => view?.opponentOf(me) ?? _opponentFromPresence();

  String? _opponentFromPresence() {
    final mine = me;
    for (final id in socket.presenceUsers) {
      if (id != mine) return id;
    }
    return null;
  }

  bool get isMyTurn =>
      view != null && view!.current == me && !(view!.ended) && result == null;

  /// 사용자 코드 대신 보여 줄 이름. 닉네임을 모르면 "상대"/"나".
  String displayName(String? userId) {
    if (userId == null) return '상대';
    final name = nameOf(userId);
    if (name.isEmpty || name == userId) return userId == me ? '나' : '상대';
    return name;
  }

  void _onState(Map<String, dynamic> data) {
    final next = GostopView.fromJson(data);
    if (next.gameId != null && next.gameId != view?.gameId) {
      gameEpoch++;
      result = null;
      socket.restartWaiting = false;
    }
    view = next;
    syncStatus = 'ok';
    notifyListeners();
  }

  void _onEnded(Map<String, dynamic> data) {
    result = HResult.fromJson(data);
    socket.restartWaiting = false;
    notifyListeners();
  }

  void _say(String message) {
    notice = message;
    noticeSeq++;
    notifyListeners();
  }

  void _handleAck(Map<String, dynamic> ack) {
    if (ack['ok'] != false) return;
    final reason = '${ack['reason'] ?? ''}';
    if (reason.isEmpty) return;
    // 공용 안내(SocketService)가 이미 한국어로 띄우는 사유는 겹쳐 띄우지 않는다.
    if (!_sharedNoticeReasons.contains(reason)) {
      _say(reasonMessages[reason] ?? '요청을 처리하지 못했어요.');
    }
    if (reason == 'card_not_in_hand' || reason == 'not_your_turn') sync();
  }

  /// 현재 판을 다시 받는다(화면 진입, 재접속, 방장 "다시 불러오기").
  void sync() {
    syncing = true;
    notifyListeners();
    emit('game:gostop:sync', const {}, (ack) {
      syncing = false;
      if (ack['ok'] == true) {
        final state = ack['state'];
        if (state is Map) _onState(Map<String, dynamic>.from(state));
      } else {
        final reason = '${ack['reason'] ?? ''}';
        // 끝난 판의 결과를 보는 중이면 "준비 중"으로 바꾸지 않는다.
        if (result == null) syncStatus = reason.isEmpty ? 'error' : reason;
        notifyListeners();
      }
    });
  }

  void play(HCard card, {bool shake = false, String? targetId}) => emit(
    'game:gostop:play',
    {'cardId': card.id, if (shake) 'shake': true, 'targetId': ?targetId},
    _handleAck,
  );

  void bomb(int month) =>
      emit('game:gostop:bomb', {'month': month}, _handleAck);

  void dotan() => emit('game:gostop:dotan', const {}, _handleAck);

  void choose(HCard card) =>
      emit('game:gostop:choose', {'cardId': card.id}, _handleAck);

  void decide(bool go) =>
      emit('game:gostop:decide', {'decision': go ? 'go' : 'stop'}, _handleAck);

  void chongtong(bool declare) =>
      emit('game:gostop:chongtong', {'declare': declare}, _handleAck);

  void requestRematch() => socket.requestRestart(gameType);

  @override
  void reset() {
    view = null;
    result = null;
    syncStatus = null;
    syncing = false;
    notice = null;
  }

  /// 위젯 테스트용: 서버 view를 직접 넣는다.
  @visibleForTesting
  void debugApplyState(Map<String, dynamic> data) => _onState(data);

  @visibleForTesting
  void debugApplyEnded(Map<String, dynamic> data) => _onEnded(data);

  @visibleForTesting
  void debugReset({String? syncStatus}) {
    reset();
    this.syncStatus = syncStatus;
    notifyListeners();
  }
}
