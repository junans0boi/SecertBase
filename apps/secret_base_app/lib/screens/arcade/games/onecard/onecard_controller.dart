import 'package:flutter/foundation.dart';

import '../game_controller.dart';
import 'onecard_models.dart';

/// 원카드(내부 식별자 uno) 2.0 상태 컨트롤러. 계약: docs/socket-events/onecard.md
///
/// 서버가 로비 시작과 함께 판을 만들고, 화면이 열리면 [sync]로 현재 상태를 받는다.
/// 상태는 `game:uno:state`(한 사람용 view) 하나로 오고, 끝나면 `game:uno:ended`.
class OneCardController extends GameController {
  static final OneCardController instance = OneCardController._();

  OneCardController._() {
    on('game:uno:state', _onState);
    on('game:uno:ended', _onEnded);
  }

  static const gameType = 'uno';

  /// 거부 사유 한국어 안내(서버는 코드만 보낸다).
  static const reasonMessages = <String, String>{
    'cannot_play_card': '지금 색이나 숫자와 맞는 카드만 낼 수 있어요.',
    'must_draw_or_defend': '쌓인 벌칙을 막을 카드를 내거나 받아야 해요.',
    'must_choose_drawn_card': '방금 뽑은 카드를 낼지 넘길지 먼저 골라 주세요.',
    'must_declare_color': '바꿀 색을 골라 주세요.',
    'not_your_turn': '아직 내 차례가 아니에요.',
    'card_not_found': '손에 없는 카드예요. 화면을 다시 불러올게요.',
    'not_needed': '지금은 원카드를 외칠 때가 아니에요.',
    'no_target': '잡을 수 있는 때가 지났어요.',
    'cannot_challenge_during_stack': '벌칙이 쌓인 +4는 도전할 수 없어요.',
    'no_challenge_data': '도전할 수 있는 +4가 없어요.',
    'no_draw_choice': '넘길 카드가 없어요.',
    'game_over': '이미 끝난 판이에요.',
    'no_game': '진행 중인 판이 없어요.',
    'not_in_game': '이 판의 참가자가 아니에요.',
    'internal_error': '잠시 문제가 생겼어요. 다시 시도해 주세요.',
  };

  static const _sharedNoticeReasons = {
    'not_your_turn',
    'must_choose_drawn_card',
    'must_draw_or_defend',
    'no_game',
    'internal_error',
    'invalid_payload',
    'not_joined',
  };

  OneCardView? view;
  OneCardResult? result;

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

  bool get isMyTurn => view != null && view!.currentPlayer == me;
  bool get canCall => view?.unoCallNeeded != null && view!.unoCallNeeded == me;
  bool get canCatch => view?.unoCallNeeded != null && view!.unoCallNeeded != me;

  /// 사용자 코드 대신 보여 줄 이름. 닉네임을 모르면 "상대"/"나".
  String displayName(String? userId) {
    if (userId == null) return '상대';
    final name = nameOf(userId);
    if (name.isEmpty || name == userId) return userId == me ? '나' : '상대';
    return name;
  }

  void _onState(Map<String, dynamic> data) {
    final next = OneCardView.fromJson(data);
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
    result = OneCardResult.fromJson(data);
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
    if (reason == 'card_not_found' || reason == 'not_your_turn') sync();
  }

  /// 현재 판을 다시 받는다(화면 진입, 재접속, 방장 "다시 불러오기").
  void sync() {
    syncing = true;
    notifyListeners();
    emit('game:uno:sync', const {}, (ack) {
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

  void play(OneCard card, {String? color}) => emit('game:uno:play', {
    'cardId': card.id,
    'declaredColor': ?color,
  }, _handleAck);

  void draw() => emit('game:uno:draw', const {}, _handleAck);

  void pass() => emit('game:uno:pass', const {}, _handleAck);

  void callOneCard() => emit('game:uno:call', const {}, _handleAck);

  void catchOpponent() => emit('game:uno:catch', const {}, _handleAck);

  void challenge() => emit('game:uno:challenge', const {}, _handleAck);

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
