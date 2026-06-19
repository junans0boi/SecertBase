import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../core/uno_audio.dart';
import '../../../ui/uno_board.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  final _socket = SocketService();
  String? _lastWinner;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    // Unlock audio when UNO screen opens (web autoplay policy)
    UnoAudio.instance.unlock();
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    final w = _socket.unoWinner;
    if (w != null && w != _lastWinner) {
      _lastWinner = w;
      _resultShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(w));
    }
    setState(() {});
  }

  void _showResult(String winner) {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final isMe = winner == _socket.userId;
    if (isMe) {
      UnoAudio.instance.victory();
    } else {
      UnoAudio.instance.defeat();
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ResultDialog(
        winner: winner,
        userId: _socket.userId,
        onRestart: () {
          Navigator.of(context).pop();
          _socket.newUnoGame();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final currentUser = sock.userId ?? 'jun';

    return GameScaffold(
      title: '🃏 UNO',
      actions: [
        GameMenuButton(
          hasRestart: sock.unoActive,
          restartWaiting: sock.restartWaiting,
          onRequestRestart: () => sock.requestRestart('uno'),
        ),
      ],
      child: GameMenuListener(
        gameType: 'uno',
        child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _UnoStatus(sock: sock),
          const SizedBox(height: 10),
          UnoBoard(
            gameId: sock.unoActive ? 'active' : null,
            turn: sock.unoCurrentPlayer,
            p1Count: sock.unoP1Count,
            p2Count: sock.unoP2Count,
            hand: sock.unoHand,
            topCard: sock.unoTopCardMap,
            declaredColor: sock.unoDeclaredColor,
            drawStack: sock.unoDrawStack,
            drawStackType: sock.unoDrawStackType,
            onNewGame: sock.newUnoGame,
            onDrawCard: sock.drawUnoCard,
            onPlayCard: (cardId, color) =>
                sock.playUnoCard(cardId, color: color),
            onChallengeDraw4: sock.challengeDraw4,
            currentUser: currentUser,
            pendingCall: sock.unoPendingCall,
            catchable: sock.unoCatchable,
            onCallUno: sock.callUno,
            onCatchUno: sock.catchUno,
            lastSpecialCard: sock.unoLastSpecialCard,
            lastSpecialBy: sock.unoLastSpecialBy,
          ),
          if (sock.unoWinner != null) ...[
            const SizedBox(height: 12),
            _WinBanner(winner: sock.unoWinner!, userId: sock.userId),
          ],
        ],
        ),
      ),
    );
  }
}

class _UnoStatus extends StatelessWidget {
  final SocketService sock;
  const _UnoStatus({required this.sock});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = sock.unoCurrentPlayer == sock.userId;
    final text = !sock.unoActive
        ? '새 게임을 시작하면 7장씩 받고 바로 플레이합니다.'
        : isMyTurn
        ? '내 턴 · 낼 수 있는 카드를 터치하거나 더미를 눌러 뽑기'
        : '${sock.unoCurrentPlayer ?? '상대'} 차례입니다';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMyTurn ? kSuccess.withValues(alpha: 0.5) : kBorder,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isMyTurn ? kSuccess : kTextSub,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Slim inline banner (always visible while winner != null)
class _WinBanner extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinBanner({required this.winner, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? kSuccess.withValues(alpha: 0.1)
            : kError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMe ? kSuccess : kError),
      ),
      child: Text(
        isMe ? '🎉 UNO! 손패를 모두 냈어요!' : '$winner 승리! 다음 판에서 복수하자 😤',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isMe ? kSuccess : kError,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// Full-screen result dialog
class _ResultDialog extends StatelessWidget {
  final String winner;
  final String? userId;
  final VoidCallback onRestart;

  const _ResultDialog({
    required this.winner,
    required this.userId,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF10121C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isMe
                ? const Color(0xFF4CAE4C).withValues(alpha: 0.6)
                : const Color(0xFFE52521).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe
                  ? const Color(0xFF4CAE4C)
                  : const Color(0xFFE52521))
                  .withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMe ? '🏆' : '😢',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              isMe ? 'UNO 승리!' : '패배...',
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe
                  ? '손패를 모두 냈어요! 최고예요!'
                  : '$winner 님이 먼저 UNO를 달성했어요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onRestart,
                    style: FilledButton.styleFrom(
                      backgroundColor: isMe
                          ? const Color(0xFF4CAE4C)
                          : const Color(0xFFE52521),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isMe ? '한 판 더!' : '복수하기!',
                      style: GoogleFonts.notoSans(
                        fontWeight: FontWeight.w800,
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
