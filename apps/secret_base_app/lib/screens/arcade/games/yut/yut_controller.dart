import 'package:flutter/foundation.dart';

import '../game_controller.dart';
import 'yut_models.dart';

/// 윷놀이 2.0 상태 컨트롤러. 계약: docs/socket-events/yut.md
///
/// 서버가 로비 시작과 함께 판을 만들고, 화면이 열리면 [sync]로 현재 상태를 받는다.
/// 상태는 `game:yut:state` 하나로 오고(두 사람 같은 내용), 끝나면 `game:yut:ended`.
class YutController extends GameController {
  static final YutController instance = YutController._();

  YutController._() {
    on('game:yut:state', _onState);
    on('game:yut:ended', _onEnded);
  }

  static const gameType = 'yut';

  /// 거부 사유 한국어 안내(서버는 코드만 보낸다).
  static const reasonMessages = <String, String>{
    'not_your_turn': '아직 내 차례가 아니에요.',
    'must_move_first': '먼저 말을 옮겨 주세요.',
    'must_throw_first': '먼저 윷을 던져 주세요.',
    'invalid_move': '그 말은 그렇게 옮길 수 없어요.',
    'invalid_payload': '요청을 처리하지 못했어요.',
    'game_over': '이미 끝난 판이에요.',
    'no_game': '진행 중인 판이 없어요.',
    'not_in_game': '이 판의 참가자가 아니에요.',
    'internal_error': '잠시 문제가 생겼어요. 다시 시도해 주세요.',
  };

  static const _sharedNoticeReasons = {
    'no_game',
    'internal_error',
    'not_joined',
  };

  YutView? view;
  YutResult? result;

  /// sync 결과. null이면 아직 모름, 'no_game'이면 판이 아직 없다.
  String? syncStatus;
  bool syncing = false;

  /// 화면 안 안내(거부 사유 등). [noticeSeq]가 바뀔 때마다 한 번 띄운다.
  String? notice;
  int noticeSeq = 0;

  /// 같은 화면에서 이어지는 판 수(새 판이면 바뀐다).
  int gameEpoch = 0;

  /// 던지기·이동을 보내고 서버 답을 기다리는 중(연타 방지).
  bool busy = false;

  String? get opponent => view?.opponentOf(me) ?? _opponentFromPresence();

  String? _opponentFromPresence() {
    final mine = me;
    for (final id in socket.presenceUsers) {
      if (id != mine) return id;
    }
    return null;
  }

  bool get isMyTurn =>
      view != null && view!.currentTurn == me && view!.winner == null;

  /// 사용자 코드 대신 보여 줄 이름. 닉네임을 모르면 "상대"/"나".
  String displayName(String? userId) {
    if (userId == null) return '상대';
    final name = nameOf(userId);
    if (name.isEmpty || name == userId) return userId == me ? '나' : '상대';
    return name;
  }

  String characterOf(String? userId) =>
      view?.characters[userId] ?? (userId == me ? 'honggilldong' : 'miho');

  void _onState(Map<String, dynamic> data) {
    final next = YutView.fromJson(data);
    if (next.gameId != null && next.gameId != view?.gameId) {
      gameEpoch++;
      result = null;
      socket.restartWaiting = false;
    }
    view = next;
    syncStatus = 'ok';
    busy = false;
    notifyListeners();
  }

  void _onEnded(Map<String, dynamic> data) {
    result = YutResult.fromJson(data);
    socket.restartWaiting = false;
    busy = false;
    notifyListeners();
  }

  void _say(String message) {
    notice = message;
    noticeSeq++;
    notifyListeners();
  }

  void _handleAck(Map<String, dynamic> ack) {
    busy = false;
    if (ack['ok'] != false) return;
    final reason = '${ack['reason'] ?? ''}';
    if (reason.isEmpty) return;
    if (!_sharedNoticeReasons.contains(reason)) {
      _say(reasonMessages[reason] ?? '요청을 처리하지 못했어요.');
    }
    if (reason == 'not_your_turn' || reason == 'invalid_move') sync();
    notifyListeners();
  }

  /// 현재 판을 다시 받는다(화면 진입, 재접속, 방장 "다시 불러오기").
  void sync() {
    syncing = true;
    notifyListeners();
    emit('game:yut:sync', const {}, (ack) {
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

  void throwSticks() {
    if (busy) return;
    busy = true;
    emit('game:yut:throw', const {}, _handleAck);
    notifyListeners();
  }

  void move(YutLegalMove m) {
    if (busy) return;
    busy = true;
    emit('game:yut:move', {
      'pieceId': m.pieceId,
      'moveIndex': m.moveIndex,
      'backdoDir': ?m.backdoDir,
    }, _handleAck);
    notifyListeners();
  }

  void requestRematch() => socket.requestRestart(gameType);

  @override
  void reset() {
    view = null;
    result = null;
    syncStatus = null;
    syncing = false;
    notice = null;
    busy = false;
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
