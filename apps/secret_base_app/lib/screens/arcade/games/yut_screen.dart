import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../ui/yut_board.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class YutScreen extends StatefulWidget {
  const YutScreen({super.key});

  @override
  State<YutScreen> createState() => _YutScreenState();
}

class _YutScreenState extends State<YutScreen> {
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
    final p1Pieces = sock.yutPieceDetails['jun'] ?? sock.yutPieces['jun'];
    final p2Pieces = sock.yutPieceDetails['gf'] ?? sock.yutPieces['gf'];

    return GameScaffold(
      title: '🀄 윷놀이',
      actions: [
        GameMenuButton(
          hasRestart: sock.yutActive,
          restartWaiting: sock.restartWaiting,
          onRequestRestart: () => sock.requestRestart('yut'),
        ),
      ],
      child: GameMenuListener(
        gameType: 'yut',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _StatusStrip(sock: sock),
            const SizedBox(height: 10),
            YutBoard(
              gameId: sock.yutActive ? (sock.yutGameId ?? 'active') : null,
              phase: sock.yutPhase,
              turn: sock.yutCurrentTurn,
              p1Pieces: p1Pieces,
              p2Pieces: p2Pieces,
              pendingMoves: sock.yutPendingMoves,
              startRolls: sock.yutStartRolls,
              onNewGame: sock.newYutGame,
              onRollStartDice: sock.rollYutStartDice,
              onThrow: sock.throwYut,
              onMovePiece: sock.moveYut,
              onMoveNewPiece: () => sock.moveYut(0),
              currentUser: currentUser,
              lastResultName: sock.yutLastThrow,
            ),
            if (sock.yutWinner != null) ...[
              const SizedBox(height: 12),
              _WinCard(winner: sock.yutWinner!, userId: sock.userId),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final SocketService sock;
  const _StatusStrip({required this.sock});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = sock.yutCurrentTurn == sock.userId;
    final text = !sock.yutActive
        ? '새 게임을 시작하면 선공 주사위부터 굴립니다.'
        : sock.yutPhase == 'roll_order'
        ? '선공 정하기 · 각자 주사위를 굴려요'
        : isMyTurn
        ? (sock.yutPendingMoves.isEmpty
              ? '내 턴 · 윷을 던지세요'
              : '내 턴 · 말을 선택하고 가이드를 눌러 이동')
        : '${sock.yutCurrentTurn ?? '상대'} 차례입니다';

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
        isMe ? '🎉 네 말 4개가 모두 완주했어요!' : '$winner 승리! 다음 판 가자 😤',
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
