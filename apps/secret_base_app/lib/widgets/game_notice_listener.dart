import 'package:flutter/material.dart';
import '../core/socket_service.dart';

/// 서버가 게임 동작을 거부했을 때(SocketService.gameNotice) 짧은 안내를 띄운다.
/// GameScaffold와 GameMenuListener 양쪽에 들어가도 같은 안내는 한 번만 표시된다.
class GameNoticeListener extends StatefulWidget {
  final Widget child;

  /// 이 화면의 게임 종류. 다른 게임에 대한 안내(예: 나온 판의 잠수 기권)는 띄우지 않는다.
  final String? gameType;

  const GameNoticeListener({super.key, required this.child, this.gameType});

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
    final noticeGame = _socket.gameNoticeGameType;
    if (!gameNoticeMatches(noticeGame, widget.gameType)) return;
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

/// 게임별 안내가 지금 화면에 해당하는지. 제로는 서버에서 `rps`로 다룬다.
bool gameNoticeMatches(String? noticeGameType, String? screenGameType) {
  if (noticeGameType == null || screenGameType == null) return true;
  String norm(String t) => t == 'zero' ? 'rps' : t;
  return norm(noticeGameType) == norm(screenGameType);
}
