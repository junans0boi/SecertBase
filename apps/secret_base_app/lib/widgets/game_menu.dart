import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../core/socket_service.dart';

/// ⋮ button to place in GameScaffold actions
class GameMenuButton extends StatelessWidget {
  final bool hasRestart;
  final bool restartWaiting;
  final VoidCallback? onRequestRestart;

  const GameMenuButton({
    super.key,
    this.hasRestart = false,
    this.restartWaiting = false,
    this.onRequestRestart,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert, color: kText),
      onPressed: () => _showMenu(context),
    );
  }

  void _showMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GameMenuSheet(
        hasRestart: hasRestart,
        restartWaiting: restartWaiting,
        parentCtx: ctx,
        onRequestRestart: onRequestRestart,
      ),
    );
  }
}

class _GameMenuSheet extends StatelessWidget {
  final bool hasRestart;
  final bool restartWaiting;
  final BuildContext parentCtx;
  final VoidCallback? onRequestRestart;

  const _GameMenuSheet({
    required this.hasRestart,
    required this.restartWaiting,
    required this.parentCtx,
    this.onRequestRestart,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            if (hasRestart) ...[
              ListTile(
                leading: restartWaiting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restart_alt, color: kPrimary),
                title: Text(
                  restartWaiting ? '상대방의 응답을 기다리는 중...' : '다시 시작',
                  style: GoogleFonts.notoSans(
                    color: restartWaiting ? kTextSub : kText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: restartWaiting
                    ? null
                    : Text(
                        '상대방에게 동의를 구합니다',
                        style: GoogleFonts.notoSans(color: kTextSub, fontSize: 12),
                      ),
                enabled: !restartWaiting,
                onTap: restartWaiting
                    ? null
                    : () {
                        Navigator.pop(context); // close sheet
                        _confirmRestart(parentCtx);
                      },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ],
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: kError),
              title: Text(
                '게임 나가기',
                style: GoogleFonts.notoSans(
                  color: kError,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // sheet
                Navigator.of(parentCtx).pop(); // screen
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestart(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '다시 시작 요청',
          style: GoogleFonts.notoSans(color: kText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '상대방에게 다시 시작을 요청할게요.\n상대방이 수락해야 재시작됩니다.',
          style: GoogleFonts.notoSans(color: kTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: GoogleFonts.notoSans(color: kTextMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRequestRestart?.call();
            },
            child: Text(
              '요청하기',
              style: GoogleFonts.notoSans(color: kPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrap game body to auto-show disconnect / restart dialogs
class GameMenuListener extends StatefulWidget {
  final Widget child;
  final String gameType;

  const GameMenuListener({
    super.key,
    required this.child,
    required this.gameType,
  });

  @override
  State<GameMenuListener> createState() => _GameMenuListenerState();
}

class _GameMenuListenerState extends State<GameMenuListener> {
  final _sock = SocketService();
  bool _disconnectDialogShown = false;
  bool _restartDialogShown = false;

  @override
  void initState() {
    super.initState();
    _sock.addListener(_onChange);
  }

  @override
  void dispose() {
    _sock.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (_sock.opponentJustLeft && !_disconnectDialogShown) {
      _disconnectDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDisconnectDialog());
    }
    if (!_sock.opponentJustLeft) _disconnectDialogShown = false;

    if (_sock.restartPending && !_restartDialogShown) {
      _restartDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRestartDialog());
    }
    if (!_sock.restartPending) _restartDialogShown = false;
  }

  void _showDisconnectDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '상대방이 나갔어요',
          style: GoogleFonts.notoSans(color: kText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '상대방과의 연결이 끊겼어요.\n잠시 기다리면 돌아올 수도 있어요.',
          style: GoogleFonts.notoSans(color: kTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
            child: Text('게임 나가기', style: GoogleFonts.notoSans(color: kError)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sock.clearOpponentLeft();
              setState(() => _disconnectDialogShown = false);
            },
            child: Text(
              '기다리기',
              style: GoogleFonts.notoSans(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => setState(() => _disconnectDialogShown = false));
  }

  void _showRestartDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '다시 시작 요청',
          style: GoogleFonts.notoSans(color: kText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '상대방이 게임을 다시 시작하고 싶어해요.\n수락하면 새 게임이 시작됩니다.',
          style: GoogleFonts.notoSans(color: kTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sock.respondToRestart(false, widget.gameType);
              setState(() => _restartDialogShown = false);
            },
            child: Text('거절', style: GoogleFonts.notoSans(color: kTextMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sock.respondToRestart(true, widget.gameType);
              setState(() => _restartDialogShown = false);
            },
            child: Text(
              '수락',
              style: GoogleFonts.notoSans(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).then((_) => setState(() => _restartDialogShown = false));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
