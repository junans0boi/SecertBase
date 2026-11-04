import 'package:flutter/material.dart';
import '../core/socket_service.dart';

/// 서버가 게임 동작을 거부했을 때(SocketService.gameNotice) 짧은 안내를 띄운다.
/// GameScaffold와 GameMenuListener 양쪽에 들어가도 같은 안내는 한 번만 표시된다.
class GameNoticeListener extends StatefulWidget {
  final Widget child;

  const GameNoticeListener({super.key, required this.child});

  @override
  State<GameNoticeListener> createState() => _GameNoticeListenerState();
}

class _GameNoticeListenerState extends State<GameNoticeListener> {
  static int _lastShownSeq = 0;
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    // 화면에 들어오기 전에 쌓인 안내는 다시 띄우지 않는다.
    if (_socket.gameNoticeSeq > _lastShownSeq) {
      _lastShownSeq = _socket.gameNoticeSeq;
    }
    _socket.addListener(_onSocket);
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;
    final seq = _socket.gameNoticeSeq;
    final message = _socket.gameNotice;
    if (seq <= _lastShownSeq || message == null) return;
    _lastShownSeq = seq;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
