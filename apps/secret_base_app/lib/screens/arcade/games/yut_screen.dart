import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../core/yut_audio.dart';
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
  int? _lastThrowSoundAt;
  int? _lastMoveSoundAt;
  String? _lastShownWinner;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    YutAudio.instance.stopBackground();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    _playPendingAudio();
    _showWinnerIfNeeded();
    setState(() {});
  }

  String _characterFor(String? player) {
    if (player == null) return SocketService.yutCharacterIds.first;
    return _socket.yutCharacters[player] ??
        _socket.lobbyStartedYutCharacters[player] ??
        SocketService.yutCharacterIds.first;
  }

  String get _myCharacter => _characterFor(_socket.userId);

  void _playPendingAudio() {
    final moveAt = _socket.yutLastMoveAt;
    if (moveAt != null && moveAt != _lastMoveSoundAt) {
      _lastMoveSoundAt = moveAt;
      final by = _socket.yutLastMoveBy;
      if (_socket.yutLastCapturedCount > 0) {
        if (by == _socket.userId) {
          YutAudio.instance.playCaptured(_myCharacter);
        } else {
          YutAudio.instance.playGotCaptured(_myCharacter);
        }
      }
      if (by == _socket.userId && _socket.yutLastStackedCount > 0) {
        Future<void>.delayed(
          const Duration(milliseconds: 420),
          () => YutAudio.instance.playStacked(_myCharacter),
        );
      }
    }
  }

  void _playThrowResultAudio(int throwAt) {
    if (throwAt == _lastThrowSoundAt || _socket.yutLastThrow == null) return;
    _lastThrowSoundAt = throwAt;
    YutAudio.instance.playThrowResult(
      _characterFor(_socket.yutLastThrowBy),
      _socket.yutLastThrow!,
      seed: throwAt,
    );
  }

  void _showWinnerIfNeeded() {
    final winner = _socket.yutWinner;
    if (winner == null || winner == _lastShownWinner) return;
    _lastShownWinner = winner;

    YutAudio.instance.stopBackground();
    if (winner == _socket.userId) {
      YutAudio.instance.playVictory(_myCharacter);
    } else {
      YutAudio.instance.playDefeat(_myCharacter);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _YutResultDialog(
          winner: winner,
          userId: _socket.userId,
          onExit: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final currentUser = sock.userId ?? 'jun';
    final p1 = sock.yutPlayers.isNotEmpty ? sock.yutPlayers[0] : 'jun';
    final p2 = sock.yutPlayers.length > 1 ? sock.yutPlayers[1] : 'gf';
    final boardUser = currentUser == p2 ? 'gf' : 'jun';
    final boardTurn = sock.yutCurrentTurn == p2
        ? 'gf'
        : sock.yutCurrentTurn == p1
        ? 'jun'
        : sock.yutCurrentTurn;
    final boardStartRolls = {
      'jun': sock.yutStartRolls[p1],
      'gf': sock.yutStartRolls[p2],
    };
    final p1Pieces = sock.yutPieceDetails[p1] ?? sock.yutPieces[p1];
    final p2Pieces = sock.yutPieceDetails[p2] ?? sock.yutPieces[p2];

    return GameScaffold(
      title: '🀄 윷놀이',
      fullBleed: true,
      actions: [
        GameMenuButton(
          hasRestart: sock.yutActive,
          restartWaiting: sock.restartWaiting,
          onRequestRestart: () => sock.requestRestart('yut'),
        ),
      ],
      child: GameMenuListener(
        gameType: 'yut',
        child: Stack(
          children: [
            const Positioned.fill(child: _YutBackdrop()),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 62, 10, 10),
                child: YutBoard(
                  gameId: sock.yutActive ? (sock.yutGameId ?? 'active') : null,
                  phase: sock.yutPhase,
                  turn: boardTurn,
                  p1Pieces: p1Pieces,
                  p2Pieces: p2Pieces,
                  pendingMoves: sock.yutPendingMoves,
                  startRolls: boardStartRolls,
                  orderCountdownUntil: sock.yutOrderCountdownUntil,
                  onNewGame: sock.newYutGame,
                  onRollStartDice: sock.rollYutStartDice,
                  hasBonusThrow: sock.yutHasBonusThrow,
                  onThrow: sock.throwYut,
                  onMovePiece: (pieceId, moveIndex, {int? backdoDir}) =>
                      sock.moveYut(pieceId, moveIndex: moveIndex, backdoDir: backdoDir),
                  onMoveNewPiece: () => sock.moveYut(0),
                  currentUser: boardUser,
                  lastResultName: sock.yutLastThrow,
                  lastThrowAt: sock.yutLastThrowAt,
                  lastThrowNak: sock.yutLastNak,
                  p1Character: _characterFor(p1),
                  p2Character: _characterFor(p2),
                  onThrowResultRevealed: _playThrowResultAudio,
                  nicknames: {
                    'jun': sock.nameOf(p1),
                    'gf': sock.nameOf(p2),
                  },
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              top: 12,
              child: _StatusStrip(sock: sock),
            ),
          ],
        ),
      ),
    );
  }
}

class _YutBackdrop extends StatelessWidget {
  const _YutBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A211A), Color(0xFF5B4632), Color(0xFF1E2C25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _YutBackdropPainter()),
    );
  }
}

class _YutBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tilePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const tile = 42.0;
    for (double y = 0; y < size.height + tile; y += tile) {
      final stagger = ((y / tile).round().isEven) ? 0.0 : tile / 2;
      for (double x = -tile; x < size.width + tile; x += tile) {
        final rect = Rect.fromLTWH(x + stagger, y, tile, tile * 0.58);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          tilePaint..style = PaintingStyle.stroke,
        );
      }
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFD46B).withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.7, size.height * 0.18),
              radius: size.shortestSide * 0.55,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YutResultDialog extends StatelessWidget {
  final String winner;
  final String? userId;
  final VoidCallback onExit;

  const _YutResultDialog({
    required this.winner,
    required this.userId,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        isMe ? '윷놀이 승리!' : '윷놀이 패배',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isMe ? kSuccess : kError,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isMe ? '🏆' : '😢', style: const TextStyle(fontSize: 62)),
          const SizedBox(height: 12),
          Text(
            isMe ? '내 말 4개가 모두 도착했어요.' : '$winner 님이 먼저 완주했어요.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(color: kTextSub, fontSize: 14),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '닫기',
            style: GoogleFonts.notoSans(
              color: kTextMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          onPressed: onExit,
          style: FilledButton.styleFrom(
            backgroundColor: isMe ? kSuccess : kError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            '나가기',
            style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
          ),
        ),
      ],
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
        : sock.yutPhase == 'order_countdown'
        ? '${sock.yutCurrentTurn ?? '선공'} 선공 · 곧 시작합니다'
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
