import 'package:flutter_test/flutter_test.dart';
import 'package:secret_base_app/core/socket_service.dart';

void main() {
  test('bomb reconnect restores holder from the server currentPlayer field', () {
    final socket = SocketService();
    socket.restoreGamesForTest({
      'bomb': {'currentPlayer': 'u2', 'timer': 12, 'category': 'x'},
    });
    expect(socket.bombCurrentPlayer, 'u2');
  });
}
