import 'package:flutter/foundation.dart';

import '../../../core/socket_service.dart';

/// 게임 2.0 화면의 상태 컨트롤러 바탕.
///
/// 게임마다 싱글톤 하나를 두고(`static final instance = XController._();`), 생성자에서
/// [on]으로 자기 소켓 이벤트를 등록한다. SocketService에는 연결·방·공용 상태만 남기고
/// 게임 상태는 여기에만 둔다. 방을 나가거나 로그아웃하면 [reset]이 불린다.
abstract class GameController extends ChangeNotifier {
  GameController() {
    socket.addResetHook(_onReset);
  }

  final SocketService socket = SocketService();

  String? get me => socket.userId;

  String nameOf(String? userId) => socket.nameOf(userId);

  String emojiOf(String? userId) =>
      userId == null ? '' : (socket.profileEmojis[userId] ?? '');

  /// 서버 이벤트 [event]를 받으면 [handler]가 불린다(데이터는 Map으로 정리돼 온다).
  @protected
  void on(String event, void Function(Map<String, dynamic> data) handler) {
    socket.addGameHandler(event, handler);
  }

  /// ack를 받아 거부 사유를 안내하는 전송.
  @protected
  void emit(
    String event, [
    Map<String, dynamic>? payload,
    void Function(Map<String, dynamic> ack)? onAck,
  ]) => socket.emitGameEvent(event, payload, onAck);

  /// 이 게임의 상태를 모두 지운다.
  @protected
  void reset();

  void _onReset() {
    reset();
    notifyListeners();
  }
}
