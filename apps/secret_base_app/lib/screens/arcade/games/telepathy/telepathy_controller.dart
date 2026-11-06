import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';
import 'telepathy_models.dart';

/// 텔레파시 2.0 상태. 서버 `game:telepathy:state`만 받아 그대로 들고 있고,
/// 화면은 이것만 보고 그린다. 조작은 `game:telepathy:pick {round, choice}`.
class TelepathyController extends GameController {
  TelepathyController._() {
    on('game:telepathy:state', applyState);
  }

  static final TelepathyController instance = TelepathyController._();

  TelepathyState? state;

  /// 이번 문제에 내가 고른 쪽(서버 확인 전에도 바로 보이게 먼저 채운다).
  String? myPick;
  int? myPickRound;

  /// 이번 문제 마감시각(기기 시계 기준).
  GameDeadline? deadline;

  bool sending = false;

  /// 화면이 열릴 때 현재 판을 다시 받는다(서버가 `game:telepathy:state`로도 보낸다).
  void sync() => emit('game:telepathy:sync', const {});

  bool get iPicked {
    final s = state;
    if (s == null) return false;
    if (myPick != null && myPickRound == s.round) return true;
    return s.picked[me] == true;
  }

  bool get partnerPicked {
    final s = state;
    if (s == null) return false;
    return s.picked[s.opponentOf(me)] == true;
  }

  void pick(String choice) {
    final s = state;
    if (s == null || !s.playing || iPicked || sending) return;
    if (choice != 'A' && choice != 'B') return;
    final round = s.round;
    final gameId = s.gameId;
    myPick = choice;
    myPickRound = round;
    sending = true;
    notifyListeners();
    emit(
      'game:telepathy:pick',
      {'choice': choice, 'round': round, 'gameId': gameId},
      (ack) {
        sending = false;
        if (ack['ok'] == false && myPickRound == round) {
          // 거부되면 다시 고를 수 있게 한다(안내는 SocketService가 띄운다).
          myPick = null;
          myPickRound = null;
        }
        notifyListeners();
      },
    );
  }

  /// 표시 이름. 닉네임을 모르면 사용자 코드를 쓰지 않고 '나'/'상대'로 쓴다.
  String displayName(String? id) {
    if (id == null) return '상대';
    final n = nameOf(id);
    if (n.isEmpty || n == id) return id == me ? '나' : '상대';
    return n;
  }

  @visibleForTesting
  void applyState(Map<String, dynamic> data, {DateTime? receivedAt}) {
    final next = TelepathyState.fromMap(data);
    final prev = state;
    if (prev == null || prev.gameId != next.gameId) {
      myPick = null;
      myPickRound = null;
      sending = false;
      // 새 판이 왔으면 재대결 대기 표시를 끈다.
      socket.restartWaiting = false;
    }
    if (next.myPick != null) {
      myPick = next.myPick;
      myPickRound = next.round;
    } else if (myPickRound != null &&
        (myPickRound != next.round || (!sending && next.picked[me] == false))) {
      // 문제가 넘어갔거나, 서버가 내 선택을 받지 못했다(다시 고를 수 있게).
      myPick = null;
      myPickRound = null;
    }
    if (prev != null && prev.round != next.round) sending = false;
    final now = receivedAt ?? DateTime.now();
    final dl = next.turnDeadline;
    deadline = (dl == null || !next.playing)
        ? null
        : GameDeadline(
            now.add(
              Duration(
                milliseconds:
                    (dl - (next.serverNow ?? now.millisecondsSinceEpoch))
                        .clamp(0, 600000)
                        .toInt(),
              ),
            ),
            Duration(milliseconds: next.turnMs),
          );
    state = next;
    notifyListeners();
  }

  /// 테스트용: 상태를 비우고 알린다.
  @visibleForTesting
  void clearForTest() {
    reset();
    notifyListeners();
  }

  @override
  void reset() {
    state = null;
    myPick = null;
    myPickRound = null;
    deadline = null;
    sending = false;
  }
}
