import 'package:flutter/material.dart';
import '../core/socket_service.dart';

/// Wraps a game screen to emit game:session:enter on mount and game:session:leave
/// on dispose. The server uses this to track which socket is actively viewing
/// which game, enabling resume logic when the partner joins the same game.
class GameSessionPresence extends StatefulWidget {
  final String gameType;
  final Widget child;

  const GameSessionPresence({
    super.key,
    required this.gameType,
    required this.child,
  });

  @override
  State<GameSessionPresence> createState() => _GameSessionPresenceState();
}

class _GameSessionPresenceState extends State<GameSessionPresence> {
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _socket.enterGameSession(widget.gameType);
  }

  @override
  void dispose() {
    _socket.leaveGameSession(widget.gameType);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
