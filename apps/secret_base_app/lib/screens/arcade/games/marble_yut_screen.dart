import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../ui/marble_yut_board.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class MarbleYutScreen extends StatefulWidget {
  const MarbleYutScreen({super.key});

  @override
  State<MarbleYutScreen> createState() => _MarbleYutScreenState();
}

class _MarbleYutScreenState extends State<MarbleYutScreen> {
  final _socket = SocketService();
  String? _lastShownWinner;

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
    if (!mounted) return;
    _handleLandPrompt();
    _showWinnerIfNeeded();
    setState(() {});
  }

  // ─── 영지 프롬프트 팝업 ───────────────────────────────────────────────────
  bool _landPromptShowing = false;

  void _handleLandPrompt() {
    final prompt = _socket.marbleYutLandPrompt;
    if (prompt == null || _landPromptShowing) return;
    _landPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LandPromptDialog(
          prompt: prompt,
          myCoins: _socket.marbleYutCoins[_socket.userId] ?? 0,
          onAct: (action) {
            final pos = prompt['pos'] as int? ?? 0;
            _socket.actMarbleYutLand(action, pos);
            _landPromptShowing = false;
          },
          onSkip: () {
            final pos = prompt['pos'] as int? ?? 0;
            _socket.actMarbleYutLand('skip', pos);
            _landPromptShowing = false;
          },
        ),
      ).whenComplete(() => _landPromptShowing = false);
    });
  }

  // ─── 승리 다이얼로그 ──────────────────────────────────────────────────────
  void _showWinnerIfNeeded() {
    final winner = _socket.marbleYutWinner;
    if (winner == null || winner == _lastShownWinner) return;
    _lastShownWinner = winner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _MarbleResultDialog(
          winner: winner,
          winReason: _socket.marbleYutWinReason,
          userId: _socket.userId,
          myCoins: _socket.marbleYutCoins[_socket.userId] ?? 0,
          opCoins: _socket.marbleYutCoins.entries
              .where((e) => e.key != _socket.userId)
              .map((e) => e.value)
              .firstOrNull ?? 0,
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
    final currentUser = sock.userId ?? '';
    final p1 = sock.marbleYutPlayers.isNotEmpty ? sock.marbleYutPlayers[0] : '';
    final p2 = sock.marbleYutPlayers.length > 1 ? sock.marbleYutPlayers[1] : '';
    final p1Pieces = sock.marbleYutPieceDetails[p1];
    final p2Pieces = sock.marbleYutPieceDetails[p2];
    final myCoins = sock.marbleYutCoins[currentUser] ?? 1500;
    final opponentId = (currentUser == p1) ? p2 : p1;
    final opCoins = sock.marbleYutCoins[opponentId] ?? 1500;

    return GameScaffold(
      title: '🏯 마블윷',
      fullBleed: true,
      showAppBar: false,
      child: GameMenuListener(
        gameType: 'marble_yut',
        child: Stack(
          children: [
            const Positioned.fill(child: _MarbleBackdrop()),

            // ─── 보드 ───────────────────────────────────────────────────
            Positioned.fill(
              child: MarbleYutBoard(
                gameId: sock.marbleYutActive
                    ? (sock.marbleYutGameId ?? 'active')
                    : null,
                phase: sock.marbleYutPhase,
                turn: sock.marbleYutCurrentTurn,
                p1Pieces: p1Pieces,
                p2Pieces: p2Pieces,
                pendingMoves: sock.marbleYutPendingMoves,
                startRolls: sock.marbleYutStartRolls,
                orderCountdownUntil: sock.marbleYutOrderCountdownUntil,
                hasBonusThrow: sock.marbleYutHasBonusThrow,
                landData: sock.marbleYutLands,
                onNewGame: sock.newMarbleYutGame,
                onRollStartDice: sock.rollMarbleYutStartDice,
                onThrow: sock.throwMarbleYut,
                onMovePiece: (pieceId, moveIndex, {int? backdoDir}) =>
                    sock.moveMarbleYut(
                  pieceId,
                  moveIndex: moveIndex,
                  backdoDir: backdoDir,
                ),
                onMoveNewPiece: () => sock.moveMarbleYut(0),
                currentUser: currentUser,
                lastResultName: sock.marbleYutLastThrow,
                lastThrowAt: sock.marbleYutLastThrowAt,
                lastThrowNak: sock.marbleYutLastNak,
                p1UserId: p1,
                p2UserId: p2,
                displayName: sock.nameOf,
                pieceSkin: 'base',
                yutSkin: 'base',
                opponentPieceSkin: 'base',
                opponentYutSkin: 'base',
                coins: myCoins,
              ),
            ),

            // ─── 상단 HUD: 자금 + 라운드 ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _MarbleHud(
                currentUser: currentUser,
                p1: p1,
                p2: p2,
                myCoins: myCoins,
                opCoins: opCoins,
                round: sock.marbleYutRound,
                displayName: sock.nameOf,
              ),
            ),

            // ─── 좌상단 나가기 버튼 ───────────────────────────────────────
            Positioned(
              left: 10,
              top: 54,
              child: _ChromeButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),

            // ─── 우상단 메뉴 ─────────────────────────────────────────────
            Positioned(
              right: 8,
              top: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x992B3440),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: GameMenuButton(
                  hasRestart: sock.marbleYutActive,
                  restartWaiting: sock.restartWaiting,
                  onRequestRestart: () => sock.requestRestart('marble_yut'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상단 HUD ──────────────────────────────────────────────────────────────

class _MarbleHud extends StatelessWidget {
  final String currentUser;
  final String p1;
  final String p2;
  final int myCoins;
  final int opCoins;
  final int round;
  final String Function(String) displayName;

  const _MarbleHud({
    required this.currentUser,
    required this.p1,
    required this.p2,
    required this.myCoins,
    required this.opCoins,
    required this.round,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final opponentId = (currentUser == p1) ? p2 : p1;
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xDD1A1230), Color(0xAA2A1540)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 내 자금
              _CoinChip(
                label: '나',
                coins: myCoins,
                color: const Color(0xFF7C4DFF),
                isMe: true,
              ),
              const Spacer(),
              // 라운드
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x44FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x44FFFFFF)),
                ),
                child: Text(
                  'Round $round / 20',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              // 상대 자금
              _CoinChip(
                label: displayName(opponentId).isNotEmpty
                    ? displayName(opponentId).characters.first
                    : '상',
                coins: opCoins,
                color: const Color(0xFFE91E63),
                isMe: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final String label;
  final int coins;
  final Color color;
  final bool isMe;

  const _CoinChip({
    required this.label,
    required this.coins,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('💰', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            coins.toString().replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'),
              (m) => ',',
            ),
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 영지 프롬프트 다이얼로그 ────────────────────────────────────────────────

class _LandPromptDialog extends StatelessWidget {
  final Map<String, dynamic> prompt;
  final int myCoins;
  final void Function(String action) onAct;
  final VoidCallback onSkip;

  const _LandPromptDialog({
    required this.prompt,
    required this.myCoins,
    required this.onAct,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final type = prompt['type'] as String? ?? 'claim';
    final pos = prompt['pos'] as int? ?? 0;
    final cost = prompt['cost'] as int? ?? 0;
    final level = prompt['level'] as int? ?? 1;
    final canAfford = myCoins >= cost;

    final isClaim = type == 'claim';
    final title = isClaim ? '영지 점령' : '영지 강화';
    final tierLabel = _tierLabel(pos);
    final icon = isClaim ? '🏴' : _levelIcon(level + 1);
    final actionLabel = isClaim ? '점령 (-$cost 💰)' : '강화 Lv${level + 1} (-$cost 💰)';
    final accentColor = isClaim
        ? const Color(0xFF7C4DFF)
        : const Color(0xFFFF6D00);

    return AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: '위치', value: 'Pos $pos ($tierLabel)'),
          if (!isClaim) _InfoRow(label: '현재 레벨', value: 'Lv$level → Lv${level + 1}'),
          _InfoRow(label: '비용', value: '$cost 💰'),
          _InfoRow(label: '보유 자금', value: '$myCoins 💰'),
          if (!canAfford)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '💸 자금이 부족합니다',
                style: GoogleFonts.notoSans(
                  color: kError,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onSkip();
          },
          child: Text(
            '건너뛰기',
            style: GoogleFonts.notoSans(color: kTextMuted, fontWeight: FontWeight.w700),
          ),
        ),
        if (canAfford)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAct(type);
            },
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  static String _tierLabel(int pos) {
    if ([5, 10, 15].contains(pos)) return 'S 신수';
    if (pos == 23) return 'A 중심';
    if ([21, 22, 24, 25, 26, 27, 28, 29].contains(pos)) return 'B 대각';
    return 'C 일반';
  }

  static String _levelIcon(int level) {
    return switch (level) {
      2 => '⭐',
      3 => '🌟',
      4 => '🛡️',
      _ => '🔼',
    };
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.notoSans(color: kTextSub, fontSize: 13)),
          Text(value,
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

// ─── 결과 다이얼로그 ──────────────────────────────────────────────────────────

class _MarbleResultDialog extends StatelessWidget {
  final String? winner;
  final String? winReason;
  final String? userId;
  final int myCoins;
  final int opCoins;
  final VoidCallback onExit;

  const _MarbleResultDialog({
    required this.winner,
    required this.winReason,
    required this.userId,
    required this.myCoins,
    required this.opCoins,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = winner == null || winReason == 'timeout_draw';
    final isMe = winner == userId;
    final reasonLabel = _reasonLabel(winReason);

    return AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        isDraw ? '무승부!' : (isMe ? '승리! 🏆' : '패배 😢'),
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isDraw
              ? kTextSub
              : (isMe ? kSuccess : kError),
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isDraw ? '🤝' : (isMe ? '🏯' : '💔'),
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 10),
          Text(
            reasonLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(color: kTextSub, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CoinChip(
                label: '나',
                coins: myCoins,
                color: const Color(0xFF7C4DFF),
                isMe: true,
              ),
              _CoinChip(
                label: '상대',
                coins: opCoins,
                color: const Color(0xFFE91E63),
                isMe: false,
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('닫기',
              style: GoogleFonts.notoSans(
                  color: kTextMuted, fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          onPressed: onExit,
          style: FilledButton.styleFrom(
            backgroundColor: isDraw ? kTextSub : (isMe ? kSuccess : kError),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child:
              Text('나가기', style: GoogleFonts.notoSans(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  static String _reasonLabel(String? reason) {
    return switch (reason) {
      'bankrupt' => '상대방이 파산했습니다',
      'shrine' => '신수 3곳을 모두 점령했습니다',
      'line' => '한 변을 완전히 점령했습니다',
      'timeout' => '20라운드 후 점수로 결정됐습니다',
      'timeout_draw' => '20라운드 후 동점으로 무승부',
      _ => '게임이 종료됐습니다',
    };
  }
}

// ─── 배경 ─────────────────────────────────────────────────────────────────

class _MarbleBackdrop extends StatelessWidget {
  const _MarbleBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF1A1230),
            Color(0xFF2A1540),
            Color(0xFF1E1E35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ─── 버튼 ─────────────────────────────────────────────────────────────────

class _ChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ChromeButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x992B3440),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
