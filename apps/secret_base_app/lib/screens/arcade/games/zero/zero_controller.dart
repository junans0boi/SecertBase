import 'package:flutter/foundation.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import '../game_controller.dart';
import 'zero_models.dart';

/// 제로 2.0 상태. 서버 `game:zero:state`만 받아 그대로 들고 있고,
/// 화면은 이것만 보고 그린다. 조작은 `game:zero:pick`.
class ZeroController extends GameController {
  ZeroController._() {
    on('game:zero:state', applyState);
  }

  static final ZeroController instance = ZeroController._();

  ZeroState? state;

  /// 이번 라운드에 내가 낸 손(서버 확인 전에도 바로 보이게 먼저 채운다).
  ZeroPick? myPick;
  int? myPickRound;

  /// 이번 라운드 마감시각(기기 시계 기준).
  GameDeadline? deadline;

  bool sending = false;

  /// 화면이 열릴 때 현재 판을 다시 받는다(서버가 `game:zero:state`로도 보낸다).
  void sync() => emit('game:zero:sync', const {});

  bool get iSubmitted {
    final s = state;
    if (s == null) return false;
    if (myPick != null && myPickRound == s.round) return true;
    return s.submitted[me] == true;
  }

  bool get opponentSubmitted {
    final s = state;
    if (s == null) return false;
    return s.submitted[s.opponentOf(me)] == true;
  }

  void pick(int fingers, int guess) {
    final s = state;
    if (s == null || !s.playing || iSubmitted || sending) return;
    if (!zeroGuessOptions(fingers).contains(guess)) return;
    final round = s.round;
    myPick = ZeroPick(fingers, guess);
    myPickRound = round;
    sending = true;
    notifyListeners();
    emit(
      'game:zero:pick',
      {'fingers': fingers, 'guess': guess, 'round': round},
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
    final next = ZeroState.fromMap(data);
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
        (myPickRound != next.round ||
            (!sending && next.submitted[me] == false))) {
      // 라운드가 넘어갔거나, 서버가 내 선택을 받지 못했다(다시 고를 수 있게).
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
