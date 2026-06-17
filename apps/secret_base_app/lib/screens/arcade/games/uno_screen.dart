import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../ui/uno_board.dart';
import '../../../widgets/game_scaffold.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  final _socket = SocketService();

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final currentUser = sock.userId ?? 'jun';

    return GameScaffold(
      title: '🃏 UNO',
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
            onNewGame: sock.newUnoGame,
            onDrawCard: sock.drawUnoCard,
            onPlayCard: (cardId, color) =>
                sock.playUnoCard(cardId, color: color),
            currentUser: currentUser,
            pendingCall: sock.unoPendingCall,
            catchable: sock.unoCatchable,
            onCallUno: sock.callUno,
            onCatchUno: sock.catchUno,
          ),
          if (sock.unoWinner != null) ...[
            const SizedBox(height: 12),
            _WinCard(winner: sock.unoWinner!, userId: sock.userId),
          ],
        ],
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

class _WinCard extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinCard({required this.winner, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return Container(
      padding: const EdgeInsets.all(18),
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
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
