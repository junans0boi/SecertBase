import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../core/socket_service.dart';
import 'game_notice_listener.dart';

/// ⋮ button to place in GameScaffold actions
class GameMenuButton extends StatelessWidget {
  final bool hasRestart;
  final bool restartWaiting;
  final VoidCallback? onRequestRestart;
  final Color iconColor;

  const GameMenuButton({
    super.key,
    this.hasRestart = false,
    this.restartWaiting = false,
    this.onRequestRestart,
    this.iconColor = kText,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '게임 메뉴',
      icon: Icon(Icons.more_vert, color: iconColor),
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
                        style: GoogleFonts.notoSans(
                          color: kTextSub,
                          fontSize: 12,
                        ),
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
          style: GoogleFonts.notoSans(
            color: kText,
            fontWeight: FontWeight.w700,
          ),
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
              style: GoogleFonts.notoSans(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showDisconnectDialog(),
      );
    }
    if (!_sock.opponentJustLeft) _disconnectDialogShown = false;

    if (_sock.restartPending && !_restartDialogShown) {
      _restartDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRestartDialog());
      WidgetsBinding.instance.ensureVisualUpdate();
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
          style: GoogleFonts.notoSans(
            color: kText,
            fontWeight: FontWeight.w700,
          ),
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
    ).then((_) {
      if (mounted) setState(() => _disconnectDialogShown = false);
    });
  }

  void _showRestartDialog() {
    if (!mounted) return;
    final requester = _sock.nameOf(_sock.partnerId);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => _RematchDialog(
        requester: requester.isEmpty ? '상대' : requester,
        onAnswer: (accept) {
          Navigator.pop(dialogContext);
          _sock.respondToRestart(accept, widget.gameType);
          setState(() => _restartDialogShown = false);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _restartDialogShown = false);
    });
  }

  @override
  Widget build(BuildContext context) =>
      GameNoticeListener(gameType: widget.gameType, child: widget.child);
}

/// 재대결 요청 카드. 게임 테마를 모르므로 앱의 브랜드 톤(장밋빛)으로 그린다.
/// 요청이 취소·거절되거나 새 판이 이미 시작돼 [SocketService.restartPending]이 꺼지면 스스로 닫힌다
/// (오래된 초대 창이 새 판 위에 남아 입력을 막지 않게).
class _RematchDialog extends StatefulWidget {
  final String requester;
  final ValueChanged<bool> onAnswer;

  const _RematchDialog({required this.requester, required this.onAnswer});

  @override
  State<_RematchDialog> createState() => _RematchDialogState();
}

class _RematchDialogState extends State<_RematchDialog> {
  final _sock = SocketService();
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _sock.addListener(_onSocket);
  }

  @override
  void dispose() {
    _sock.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (_answered || _sock.restartPending || !mounted) return;
    _answered = true;
    Navigator.of(context).pop();
  }

  void _answer(bool accept) {
    if (_answered) return;
    _answered = true;
    widget.onAnswer(accept);
  }

  @override
  Widget build(BuildContext context) {
    const rose = Color(0xFFFF6F9F);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFF3DCE6)),
          boxShadow: [
            BoxShadow(
              color: rose.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFEEF5),
              ),
              child: const Text('🔁', style: TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 14),
            Text(
              '한 판 더 할까요?',
              style: GoogleFonts.notoSans(
                color: kText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.requester}님이 다시 겨루고 싶어해요.\n수락하면 바로 새 판이 시작돼요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: kTextSub,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFF3DCE6)),
                      shape: const StadiumBorder(),
                      foregroundColor: kTextSub,
                    ),
                    child: Text(
                      '다음에',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _answer(true),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: rose,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '좋아요!',
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
