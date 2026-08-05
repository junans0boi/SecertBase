import 'dart:async';
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
    _socket.onMarbleYutTollPaid = _showTollPaidSnackbar;
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    if (_socket.onMarbleYutTollPaid == _showTollPaidSnackbar) {
      _socket.onMarbleYutTollPaid = null;
    }
    super.dispose();
  }

  void _showTollPaidSnackbar(Map<String, dynamic> data) {
    if (!mounted) return;
    final payer = data['payer'] as String?;
    final receiver = data['receiver'] as String?;
    final toll = data['toll'] as int? ?? 0;
    
    if (payer == null || receiver == null || toll == 0) return;
    
    final isMePayer = payer == _socket.userId;
    final isMeReceiver = receiver == _socket.userId;
    
    if (!isMePayer && !isMeReceiver) return;
    
    final formattedToll = toll.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isMePayer ? '💸' : '💰', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isMePayer
                    ? '상대 영지에 도착하여 $formattedToll 코인을 지불했습니다!'
                    : '상대가 내 영지에 도착하여 $formattedToll 코인을 획득했습니다!',
                style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        backgroundColor: isMePayer ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _rebuild() {
    if (!mounted) return;
    _handleLandPrompt();
    _handleCatchBonus();
    _showWinnerIfNeeded();
    setState(() {});
  }

  // ─── Catch Bonus 프롬프트 ───────────────────────────────────────────────
  bool _catchBonusShowing = false;

  void _handleCatchBonus() {
    // H2: 턴 전환 여부와 독립적으로 catchBonusBy로 판단
    // currentTurn에만 의존하면 턴 전환이 먼저 일어나 팔업이 누락됨
    if (!_socket.marbleYutCatchBonusPending ||
        _socket.marbleYutCatchBonusBy != _socket.userId ||
        _catchBonusShowing) {
      return;
    }
    
    final targetId = _socket.marbleYutCatchBonusTarget;
    if (targetId == null) return;
    
    final lands = _socket.marbleYutLands.entries
      .where((e) => e.value['owner'] == targetId && (e.value['level'] as int? ?? 1) < 4)
      .toList();
      
    if (lands.isEmpty) return;

    _catchBonusShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CatchBonusDialog(
          lands: lands,
          myCoins: _socket.marbleYutCoins[_socket.userId] ?? 0,
          onAct: (pos) {
            _socket.actMarbleYutLand('catch_acquire', pos);
            _catchBonusShowing = false;
          },
          onSkip: () {
            _socket.actMarbleYutLand('catch_skip', 0);
            _catchBonusShowing = false;
          },
          until: _socket.marbleYutCatchBonusUntil,
        ),
      ).whenComplete(() => _catchBonusShowing = false);
    });
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

  // ─── 승리 다이얼로그 ──────────────────────────────────────────
  void _showWinnerIfNeeded() {
    final winner = _socket.marbleYutWinner;
    final winReason = _socket.marbleYutWinReason;
    // C3: timeout_draw는 winner==null 이지만 ended 이벤트가 발송되므로 winReason으로 식별
    final isDraw = winner == null && winReason == 'timeout_draw';
    if (!isDraw && winner == null) return; // 실제 게임 진행 중
    final shownKey = isDraw ? '__draw__' : winner!;
    if (shownKey == _lastShownWinner) return;
    _lastShownWinner = shownKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _MarbleResultDialog(
          winner: winner, // draw시 null, timeout시 uid
          winReason: winReason,
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
                p1Character: sock.marbleYutCharacters[p1] ?? 'honggilldong',
                p2Character: sock.marbleYutCharacters[p2] ?? 'miho',
                pieceSkin: sock.marbleYutEquippedItems[currentUser]?['piece_skin'] ?? 'base',
                yutSkin: sock.marbleYutEquippedItems[currentUser]?['yut_skin'] ?? 'base',
                opponentPieceSkin: sock.marbleYutEquippedItems[opponentId]?['piece_skin'] ?? 'base',
                opponentYutSkin: sock.marbleYutEquippedItems[opponentId]?['yut_skin'] ?? 'base',
                coins: myCoins,
              ),
            ),

            // ─── 상단 HUD: 자금 + 라운드 ─────────────────────────────
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
                currentTurn: sock.marbleYutCurrentTurn, // M7: 현재 누구 턴
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
  final String? currentTurn; // M7: 현재 턴 표시용
  final String Function(String) displayName;

  const _MarbleHud({
    required this.currentUser,
    required this.p1,
    required this.p2,
    required this.myCoins,
    required this.opCoins,
    required this.round,
    this.currentTurn,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final opponentId = (currentUser == p1) ? p2 : p1;
    final isMyTurn = currentTurn == currentUser;
    return Container(
      height: 56,
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
              // 내 자금 + 내 턴 하이라이트
              _CoinChip(
                label: '나',
                coins: myCoins,
                color: const Color(0xFF7C4DFF),
                isMe: true,
                isMyTurn: isMyTurn,
              ),
              const Spacer(),
              // 라운드 + 턴 안내 (M7)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x44FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x44FFFFFF)),
                    ),
                    child: Text(
                      'Round $round / 20',
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isMyTurn ? '⚡ 내 턴!' : '상대 턴',
                    style: GoogleFonts.notoSans(
                      color: isMyTurn ? const Color(0xFFFFD700) : Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 상대 자금 + 상대 턴 하이라이트
              _CoinChip(
                label: displayName(opponentId).isNotEmpty
                    ? displayName(opponentId).characters.first
                    : '상',
                coins: opCoins,
                color: const Color(0xFFE91E63),
                isMe: false,
                isMyTurn: !isMyTurn && currentTurn != null,
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
  final bool isMyTurn;  // M7: 혁재 턴 사용자인지 여부

  const _CoinChip({
    required this.label,
    required this.coins,
    required this.color,
    required this.isMe,
    this.isMyTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMyTurn
            ? color.withValues(alpha: 0.45)
            : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? color : color.withValues(alpha: 0.6),
          width: isMyTurn ? 2 : 1,
        ),
        boxShadow: isMyTurn
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💰', style: TextStyle(fontSize: 12)),
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
    final stacked = prompt['stacked'] as bool? ?? false;
    final canAfford = myCoins >= cost;

    final isClaim = type == 'claim';
    final isAcquire = type == 'acquire';
    
    final String title;
    final String icon;
    final String actionLabel;
    final Color accentColor;
    
    if (isAcquire) {
      title = '영지 인수';
      icon = '🤝';
      actionLabel = '인수 (-$cost 💰)';
      accentColor = const Color(0xFFE91E63);
    } else if (isClaim) {
      title = stacked ? '영지 점령 (업기)' : '영지 점령';
      icon = '🏴';
      actionLabel = '점령 (-$cost 💰)';
      accentColor = const Color(0xFF7C4DFF);
    } else { // upgrade
      title = '영지 강화';
      icon = _levelIcon(level + 1);
      actionLabel = '강화 Lv${level + 1} (-$cost 💰)';
      accentColor = const Color(0xFFFF6D00);
    }

    final tierLabel = _tierLabel(pos);

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
          if (type == 'upgrade') _InfoRow(label: '현재 레벨', value: 'Lv$level → Lv${level + 1}'),
          if (isAcquire) _InfoRow(label: '현재 레벨', value: 'Lv$level'),
          _InfoRow(
            label: '비용', 
            value: '$cost 💰${stacked ? (isClaim ? ' (x2 비용, Lv2)' : (isAcquire ? ' (50% 할인)' : '')) : ''}'
          ),
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

// ─── 잡기 보너스 다이얼로그 ─────────────────────────────────────────────────────

class _CatchBonusDialog extends StatefulWidget {
  final List<MapEntry<String, dynamic>> lands;
  final int myCoins;
  final void Function(int pos) onAct;
  final VoidCallback onSkip;
  final int? until;

  const _CatchBonusDialog({
    required this.lands,
    required this.myCoins,
    required this.onAct,
    required this.onSkip,
    required this.until,
  });

  @override
  State<_CatchBonusDialog> createState() => _CatchBonusDialogState();
}

class _CatchBonusDialogState extends State<_CatchBonusDialog> {
  int? _selectedPos;
  Timer? _timer;
  int _remainingMs = 0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (widget.until == null) return;
    final remain = widget.until! - DateTime.now().millisecondsSinceEpoch;
    // H1: 재접속 복원 시 이미 지난 타임스킬막이면 즉시 스킵 (자동 입력 방지)
    if (remain <= 0) {
      _timer?.cancel();
      // 재접속으로 인한 즉시 닫힘 시 서버에게 skip 통보 도 하지 않음
      // (서버 setTimeout이 15초 후 자동으로 catch skip 처리함)
      if (mounted) {
        Navigator.of(context).pop();
        // 고의적으로 onSkip을 호출하지 않음 (timeout 이전에 닫히면 서버가 타이룬으로 처리)
      }
    } else {
      setState(() => _remainingMs = remain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainSec = (_remainingMs / 1000).ceil();

    return AlertDialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(
            '잡기 보너스! ($remainSec초)',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상대방을 잡았습니다! 15초 내에 상대의 영지 하나를 인수할 수 있습니다. (레벨4 제외)',
              style: GoogleFonts.notoSans(color: kTextSub, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: '내 자금', value: '${widget.myCoins} 💰'),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.lands.length,
                itemBuilder: (context, index) {
                  final entry = widget.lands[index];
                  final pos = int.tryParse(entry.key) ?? 0;
                  final level = entry.value['level'] as int? ?? 1;
                  // L5: 신수 위치에 이름 표시 + 실제 서버 calcAcquireCost 동일 로직
                  final shrineNames = {5: '백호', 10: '청룡', 15: '주작'};
                  int baseVal = 100;
                  if ([5, 10, 15].contains(pos)) {
                    baseVal = 300;
                  } else if (pos == 23) {
                    baseVal = 200;
                  } else if ([21, 22, 24, 25, 26, 27, 28, 29].contains(pos)) {
                    baseVal = 150;
                  }
                  final cost = (baseVal * 1.3).floor();
                  final canAfford = widget.myCoins >= cost;
                  final isSelected = _selectedPos == pos;
                  final posLabel = shrineNames.containsKey(pos)
                      ? '✨ ${shrineNames[pos]} (Lv$level)'
                      : 'Pos $pos (Lv$level)';

                  return InkWell(
                    onTap: canAfford ? () => setState(() => _selectedPos = pos) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0x33E91E63) : const Color(0x11FFFFFF),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE91E63) : (canAfford ? const Color(0x22FFFFFF) : const Color(0x11FFFFFF)),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(posLabel, style: GoogleFonts.notoSans(color: canAfford ? Colors.white : kTextMuted, fontWeight: FontWeight.w700)),
                          Text('$cost 💰', style: GoogleFonts.notoSans(color: canAfford ? const Color(0xFFE91E63) : kTextMuted, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSkip();
          },
          child: Text(
            '건너뛰기',
            style: GoogleFonts.notoSans(color: kTextMuted, fontWeight: FontWeight.w700),
          ),
        ),
        if (_selectedPos != null)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onAct(_selectedPos!);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('인수하기', style: GoogleFonts.notoSans(fontWeight: FontWeight.w800)),
          ),
      ],
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
