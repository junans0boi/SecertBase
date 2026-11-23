import 'package:flutter/foundation.dart';

import '../../../core/socket_service.dart';

/// 서버가 활성 Couple 상대에게만 보내는 쪽지 이벤트.
const noteEventNames = [
  'note:new',
  'note:read',
  'note:deleted',
  'note:reaction',
];

/// 이벤트 구독을 추상화해 테스트에서 소켓 없이 쓴다. 반환값은 구독 해제 함수.
typedef NotesEventSource =
    VoidCallback Function(
      void Function(String event, Map<String, dynamic> data) listener,
    );

VoidCallback socketNotesEvents(
  void Function(String event, Map<String, dynamic> data) listener,
) {
  final socket = SocketService();
  final handlers = <String, void Function(Map<String, dynamic>)>{};
  for (final event in noteEventNames) {
    void handler(Map<String, dynamic> data) => listener(event, data);
    handlers[event] = handler;
    socket.addGameHandler(event, handler);
  }
  return () {
    handlers.forEach(socket.removeGameHandler);
  };
}
