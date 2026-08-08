import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../ui/marble_board.dart';
import '../../../ui/marble_map_data.dart';
import '../../../ui/character_painters.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

// ─── 돈 포맷 (콤마 방식 절대 금지) ──────────────────────────────────────────
String fmm(int n) {
  if (n == 0) return '0';
  final abs = n.abs();
  final sign = n < 0 ? '-' : '';
  final man = abs ~/ 10000;
  final rem = abs % 10000;
  if (man == 0) return '$sign${rem}원';
  if (rem == 0) return '$sign${man}만원';
  return '$sign${man}만${rem}원'; // 예: 3000020 → '300만20원'
}

int _landValueOf(String userId, Map<String, dynamic> landData) {
  int total = 0;
  for (final entry in landData.entries) {
    final data = entry.value;
    if (data is Map && data['owner'] == userId) {
      final pos = int.tryParse(entry.key) ?? 0;
      final level = (data['level'] as int? ?? 1);
      final tile = kTileByPos[pos];
      if (tile != null && tile.price > 0) total += tile.price * level;
    }
  }
  return total;
}

class MarbleScreen extends StatefulWidget {
  const MarbleScreen({super.key});

  @override
  State<MarbleScreen> createState() => _MarbleScreenState();
}

class _MarbleScreenState extends State<MarbleScreen> {
  final _socket = SocketService();
  String? _lastShownWinner;

  // ─── 타일 이벤트 오버레이 ────────────────────────────────────────────────
  bool _showTileEvent = false;
  Map<String, dynamic>? _tileEventData;

  // ─── 컨페티 레이어 ──────────────────────────────────────────────────────
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _socket.onMarbleTollPaid    = _showTollPaidSnackbar;
    _socket.onMarbleSpecialTile = _showSpecialTileOverlay;
    _socket.onMarblePassedStart = _triggerConfetti;
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    if (_socket.onMarbleTollPaid    == _showTollPaidSnackbar)  _socket.onMarbleTollPaid    = null;
    if (_socket.onMarbleSpecialTile == _showSpecialTileOverlay) _socket.onMarbleSpecialTile = null;
    if (_socket.onMarblePassedStart == _triggerConfetti)        _socket.onMarblePassedStart = null;
    super.dispose();
  }

  void _triggerConfetti() {
    if (!mounted) return;
    setState(() => _showConfetti = true);
  }

  void _showSpecialTileOverlay(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String? ?? '';
    String text;
    Color bgColor;

    if (type == 'tax') {
      final amount = data['amount'] as int? ?? 0;
      text = '⚖️ 세금 징수! -${fmm(amount)}';
      bgColor = const Color(0xFFB71C1C);
    } else if (type == 'card') {
      final card = data['card'] as Map<String, dynamic>?;
      text = '🗝️ 황금열쇠: ${card?['text'] ?? ''}';
      final amount = card?['amount'] as int? ?? 0;
      bgColor = amount >= 0 ? const Color(0xFF388E3C) : const Color(0xFFB71C1C);
    } else if (type == 'event') {
      final ev = data['event'] as Map<String, dynamic>?;
      text = '⚡ ${ev?['text'] ?? '이벤트!'}';
      final amount = ev?['amount'] as int? ?? 0;
      bgColor = amount >= 0 ? const Color(0xFF1565C0) : const Color(0xFFB71C1C);
    } else {
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.notoSans(fontWeight: FontWeight.w700)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 이벤트 타일 오버레이 표시
    setState(() {
      _showTileEvent = true;
      _tileEventData = data;
    });
  }

  void _showTollPaidSnackbar(Map<String, dynamic> data) {
    if (!mounted) return;
    final payer    = data['payer']    as String?;
    final receiver = data['receiver'] as String?;
    final toll     = data['toll']     as int? ?? 0;
    if (payer == null || receiver == null || toll == 0) return;

    final isMePayer    = payer    == _socket.userId;
    final isMeReceiver = receiver == _socket.userId;
    if (!isMePayer && !isMeReceiver) return;

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
                    ? '상대 영지에 도착 → ${fmm(toll)} 지불'
                    : '상대가 내 영지 도착 → ${fmm(toll)} 획득!',
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
    if (!_socket.marbleCatchBonusPending ||
        _socket.marbleCatchBonusBy != _socket.userId ||
        _catchBonusShowing) {
      return;
    }
    final targetId = _socket.marbleCatchBonusTarget;
    if (targetId == null) return;
    final lands = _socket.marbleLands.entries
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
          myCoins: _socket.marbleCoins[_socket.userId] ?? 0,
          onAct: (pos) { _socket.actMarbleLand('catch_acquire', pos); _catchBonusShowing = false; },
          onSkip: () { _socket.actMarbleLand('catch_skip', 0); _catchBonusShowing = false; },
          until: _socket.marbleCatchBonusUntil,
        ),
      ).whenComplete(() => _catchBonusShowing = false);
    });
  }

  // ─── 영지 프롬프트 팝업 ───────────────────────────────────────────────────
  bool _landPromptShowing = false;

  void _handleLandPrompt() {
    final prompt = _socket.marbleLandPrompt;
    if (prompt == null || _landPromptShowing) return;
    _landPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _LandPromptDialog(
          prompt: prompt,
          myCoins: _socket.marbleCoins[_socket.userId] ?? 0,
          onAct: (action) {
            _socket.actMarbleLand(action, prompt['pos'] as int? ?? 0);
            _landPromptShowing = false;
          },
          onSkip: () {
            _socket.actMarbleLand('skip', prompt['pos'] as int? ?? 0);
            _landPromptShowing = false;
          },
        ),
      ).whenComplete(() => _landPromptShowing = false);
    });
  }

  // ─── 승리 다이얼로그 ─────────────────────────────────────────────────────
  void _showWinnerIfNeeded() {
    final winner    = _socket.marbleWinner;
    final winReason = _socket.marbleWinReason;
    final isDraw    = winner == null && winReason == 'timeout_draw';
    if (!isDraw && winner == null) return;
    final shownKey  = isDraw ? '__draw__' : winner!;
    if (shownKey == _lastShownWinner) return;
    _lastShownWinner = shownKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _MarbleResultDialog(
          winner:    winner,
          winReason: winReason,
          userId:    _socket.userId,
          myCoins:   _socket.marbleCoins[_socket.userId] ?? 0,
          opCoins:   _socket.marbleCoins.entries
              .where((e) => e.key != _socket.userId)
              .map((e) => e.value)
              .firstOrNull ?? 0,
          myCharacter: _socket.marbleCharacters[_socket.userId] ?? 'k',
          opCharacter: _socket.marbleCharacters.entries
              .where((e) => e.key != _socket.userId)
              .map((e) => e.value)
              .firstOrNull ?? 'ria',
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
    final sock        = _socket;
    final currentUser = sock.userId ?? '';
    final p1 = sock.marblePlayers.isNotEmpty ? sock.marblePlayers[0] : '';
    final p2 = sock.marblePlayers.length > 1  ? sock.marblePlayers[1] : '';
    final p1Pieces = sock.marblePieceDetails[p1]?.take(1).toList();
    final p2Pieces = sock.marblePieceDetails[p2]?.take(1).toList();
    final myCoins     = sock.marbleCoins[currentUser] ?? 1500;
    final opponentId  = (currentUser == p1) ? p2 : p1;
    final opCoins     = sock.marbleCoins[opponentId] ?? 1500;

    return GameScaffold(
      title: '🎲 마블',
      fullBleed: true,
      showAppBar: false,
      child: GameMenuListener(
        gameType: 'marble',
        child: Stack(
          children: [
            const Positioned.fill(child: _MarbleBackdrop()),

            // ─── 보드 ─────────────────────────────────────────────────────
            Positioned.fill(
              child: MarbleBoard(
                gameId:               sock.marbleActive ? (sock.marbleGameId ?? 'active') : null,
                phase:                sock.marblePhase,
                turn:                 sock.marbleCurrentTurn,
                p1Pieces:             p1Pieces,
                p2Pieces:             p2Pieces,
                pendingMoves:         sock.marblePendingMoves,
                startRolls:           sock.marbleStartRolls,
                orderCountdownUntil:  sock.marbleOrderCountdownUntil,
                hasDoubleRoll:        sock.marbleHasDoubleRoll,
                landData:             sock.marbleLands,
                onNewGame:            sock.newMarbleGame,
                onRollStartDice:      sock.rollMarbleStartDice,
                onRoll:               sock.rollMarble,
                onMovePiece:          (pieceId, moveIndex) => sock.moveMarble(pieceId, moveIndex: moveIndex),
                onMoveNewPiece:       () => sock.moveMarble(0),
                currentUser:          currentUser,
                lastRoll:             sock.marbleLastRoll,
                lastRollAt:           sock.marbleLastRollAt,
                p1UserId:             p1,
                p2UserId:             p2,
                displayName:          sock.nameOf,
                p1Character:          sock.marbleCharacters[p1] ?? 'k',
                p2Character:          sock.marbleCharacters[p2] ?? 'ria',
                pieceSkin:            sock.marbleEquippedItems[currentUser]?['piece_skin'] ?? 'base',
                opponentPieceSkin:    sock.marbleEquippedItems[opponentId]?['piece_skin'] ?? 'base',
                coins:                myCoins,
              ),
            ),

            // ─── 상단 HUD ─────────────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: _MarbleHud(
                currentUser: currentUser,
                p1:          p1,
                p2:          p2,
                myCoins:     myCoins,
                opCoins:     opCoins,
                round:       sock.marbleRound,
                currentTurn: sock.marbleCurrentTurn,
                displayName: sock.nameOf,
                landData:    sock.marbleLands,
                characters:  sock.marbleCharacters,
              ),
            ),

            // ─── 좌상단 나가기 버튼 ───────────────────────────────────────
            Positioned(
              left: 10, top: 54,
              child: _ChromeButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),

            // ─── 우상단 메뉴 ─────────────────────────────────────────────
            Positioned(
              right: 8, top: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x992B3440),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: GameMenuButton(
                  hasRestart:     sock.marbleActive,
                  restartWaiting: sock.restartWaiting,
                  onRequestRestart: () => sock.requestRestart('marble'),
                ),
              ),
            ),

            // ─── 이벤트 타일 오버레이 ─────────────────────────────────────
            if (_showTileEvent && _tileEventData != null)
              Positioned.fill(
                child: _TileEventOverlay(
                  data: _tileEventData!,
                  onDismiss: () => setState(() {
                    _showTileEvent  = false;
                    _tileEventData  = null;
                  }),
                ),
              ),

            // ─── 컨페티 (임무개시 통과) ────────────────────────────────────
            if (_showConfetti)
              Positioned.fill(
                child: _ConfettiLayer(
                  onDone: () => setState(() => _showConfetti = false),
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
  final String? currentTurn;
  final String Function(String) displayName;
  final Map<String, dynamic> landData;
  final Map<String, String> characters;

  const _MarbleHud({
    required this.currentUser,
    required this.p1,
    required this.p2,
    required this.myCoins,
    required this.opCoins,
    required this.round,
    this.currentTurn,
    required this.displayName,
    required this.landData,
    required this.characters,
  });

  @override
  Widget build(BuildContext context) {
    final opponentId = (currentUser == p1) ? p2 : p1;
    final isMyTurn   = currentTurn == currentUser;

    final myLandVal = _landValueOf(currentUser, landData);
    final opLandVal = _landValueOf(opponentId, landData);
    final myTotal   = myCoins + myLandVal;
    final opTotal   = opCoins + opLandVal;
    final myRank    = myTotal >= opTotal ? 1 : 2;
    final opRank    = 3 - myRank;

    final myCharacter = characters[currentUser] ?? 'k';
    final opCharacter = characters[opponentId]  ?? 'ria';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xEE0D1117), Color(0xAA161B22)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF), width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileCard(
                  character:   myCharacter,
                  nickname:    displayName(currentUser),
                  coins:       myCoins,
                  totalAssets: myTotal,
                  rank:        myRank,
                  isMyTurn:    isMyTurn,
                  teamColor:   const Color(0xFF7C4DFF),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x33FFFFFF)),
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
                    const SizedBox(height: 3),
                    Text(
                      isMyTurn ? '⚡ 내 턴!' : '⏳',
                      style: GoogleFonts.notoSans(
                        color: isMyTurn ? const Color(0xFFFFD700) : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _ProfileCard(
                  character:   opCharacter,
                  nickname:    displayName(opponentId),
                  coins:       opCoins,
                  totalAssets: opTotal,
                  rank:        opRank,
                  isMyTurn:    !isMyTurn && currentTurn != null,
                  teamColor:   const Color(0xFFE91E63),
                  reversed:    true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String character;
  final String nickname;
  final int coins;
  final int totalAssets;
  final int rank;
  final bool isMyTurn;
  final Color teamColor;
  final bool reversed;

  const _ProfileCard({
    required this.character,
    required this.nickname,
    required this.coins,
    required this.totalAssets,
    required this.rank,
    required this.isMyTurn,
    required this.teamColor,
    this.reversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bust = CharacterBust(character: character, width: 40, height: 52);

    final infoCol = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nickname.length > 6 ? '${nickname.substring(0, 6)}…' : nickname,
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '💰 ${fmm(totalAssets)}',
          style: GoogleFonts.notoSans(
            color: const Color(0xFFFFD700),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '🏠 ${fmm(coins)}',
          style: GoogleFonts.notoSans(
            color: Colors.white60,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 130,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? const Color(0xFFFFD700) : teamColor.withValues(alpha: 0.4),
          width: isMyTurn ? 1.5 : 1,
        ),
        boxShadow: isMyTurn
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
            : [BoxShadow(color: teamColor.withValues(alpha: 0.15), blurRadius: 4)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: reversed
                ? [Expanded(child: infoCol), const SizedBox(width: 4), bust]
                : [bust, const SizedBox(width: 4), Expanded(child: infoCol)],
          ),
          Positioned(
            top: -6,
            right: reversed ? null : -6,
            left:  reversed ? -6  : null,
            child: _RankBadge(rank: rank),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFirst ? const Color(0xFFFFD700) : const Color(0xFFB0BEC5),
        boxShadow: [
          BoxShadow(
            color: (isFirst ? const Color(0xFFFFD700) : const Color(0xFFB0BEC5))
                .withValues(alpha: 0.5),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        isFirst ? '1위' : '2위',
        style: const TextStyle(
          color: Color(0xFF1A1008),
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─── 영지 프롬프트 다이얼로그 (Dialog 패턴으로 교체, 텍스트 색상 버그 방지) ──

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
    final type    = prompt['type'] as String? ?? 'claim';
    final pos     = prompt['pos']  as int? ?? 0;
    final cost    = prompt['cost'] as int? ?? 0;
    final level   = prompt['level'] as int? ?? 1;
    final stacked = prompt['stacked'] as bool? ?? false;
    final canAfford = myCoins >= cost;

    final isClaim   = type == 'claim';
    final isAcquire = type == 'acquire';

    final String title;
    final String icon;
    final String actionLabel;
    final List<Color> bannerColors;

    if (isAcquire) {
      title = '도시 인수';
      icon  = '🤝';
      actionLabel = '인수 💴 ${fmm(cost)}';
      bannerColors = [const Color(0xFFB91C1C), const Color(0xFF991B1B)];
    } else if (isClaim) {
      title = stacked ? '영지 점령 (업기)' : '영지 점령';
      icon  = '🏴';
      actionLabel = '점령 💴 ${fmm(cost)}';
      bannerColors = [const Color(0xFF5B21B6), const Color(0xFF4C1D95)];
    } else {
      title = '건물 건설';
      icon  = _levelIcon(level + 1);
      actionLabel = '건설 Lv${level + 1} 💴 ${fmm(cost)}';
      bannerColors = [const Color(0xFFC2410C), const Color(0xFF9A3412)];
    }

    final tile = kTileByPos[pos];
    final locationStr = tile != null ? '${tile.emoji} ${tile.name} (${_groupLabel(pos)})' : 'Pos $pos';
    final remaining   = myCoins - cost;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1230), Color(0xFF0D1117)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x44FFD700), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 타이틀 배너
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: bannerColors,
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 22)),
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
            ),

            // 정보 행
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  _InfoRow(label: '위치',   value: locationStr),
                  if (type == 'upgrade') _InfoRow(label: '레벨', value: 'Lv$level → Lv${level + 1}'),
                  if (isAcquire)        _InfoRow(label: '레벨', value: 'Lv$level'),
                  _InfoRow(
                    label: '인수비용',
                    value: fmm(cost) + (stacked && isClaim ? ' (x2, Lv2)' : stacked && isAcquire ? ' (50% 할인)' : ''),
                  ),
                  _InfoRow(label: '보유 마블', value: fmm(myCoins)),
                  if (canAfford)
                    _InfoRow(label: '인수 후 잔액', value: fmm(remaining),
                        valueColor: remaining < 200000 ? const Color(0xFFFF3D00) : null),
                  if (!canAfford)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x22FF3D00),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x66FF3D00)),
                        ),
                        child: Text(
                          '💸 마블이 부족합니다',
                          style: GoogleFonts.notoSans(
                            color: const Color(0xFFFF3D00),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () { Navigator.of(context).pop(); onSkip(); },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        '취소',
                        style: GoogleFonts.notoSans(color: Colors.white60, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: canAfford
                        ? GestureDetector(
                            onTap: () { Navigator.of(context).pop(); onAct(type); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                actionLabel,
                                style: GoogleFonts.notoSans(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '마블 부족',
                              style: GoogleFonts.notoSans(
                                color: Colors.white30,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _groupLabel(int pos) {
    if (pos >= 1  && pos <= 5)  return '핑크';
    if (pos >= 7  && pos <= 11) return '그린';
    if (pos >= 13 && pos <= 17) return '블루';
    if (pos >= 19 && pos <= 23) return '골드';
    return '';
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
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.notoSans(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.notoSans(
                  color: valueColor ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
      ],
    );
  }
}

// ─── 잡기 보너스 다이얼로그 ─────────────────────────────────────────────────

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
    if (remain <= 0) {
      _timer?.cancel();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _remainingMs = remain);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainSec = (_remainingMs / 1000).ceil();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1230), Color(0xFF0D1117)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x44FFD700), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF5B21B6)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 22)),
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
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상대방을 잡았습니다! 15초 내에 상대의 영지 하나를 인수할 수 있습니다.',
                    style: GoogleFonts.notoSans(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(label: '내 자금', value: fmm(widget.myCoins)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.lands.length,
                      itemBuilder: (context, index) {
                        final entry = widget.lands[index];
                        final pos   = int.tryParse(entry.key) ?? 0;
                        final level = entry.value['level'] as int? ?? 1;
                        int baseVal = 100;
                        if ([5, 10, 15].contains(pos)) baseVal = 300;
                        else if (pos == 23) baseVal = 200;
                        else if ([21, 22, 24, 25, 26, 27, 28, 29].contains(pos)) baseVal = 150;
                        final cost       = (baseVal * 1.3).floor();
                        final canAfford  = widget.myCoins >= cost;
                        final isSelected = _selectedPos == pos;
                        final tile = kTileByPos[pos];
                        final posLabel = tile != null
                            ? '${tile.emoji} ${tile.name} (Lv$level)'
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
                                color: isSelected ? const Color(0xFFE91E63)
                                    : (canAfford ? const Color(0x22FFFFFF) : const Color(0x11FFFFFF)),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(posLabel, style: GoogleFonts.notoSans(
                                    color: canAfford ? Colors.white : Colors.white30,
                                    fontWeight: FontWeight.w700)),
                                Text(fmm(cost), style: GoogleFonts.notoSans(
                                    color: canAfford ? const Color(0xFFE91E63) : Colors.white30,
                                    fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () { Navigator.of(context).pop(); widget.onSkip(); },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('건너뛰기',
                              style: GoogleFonts.notoSans(color: Colors.white60, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      if (_selectedPos != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () { Navigator.of(context).pop(); widget.onAct(_selectedPos!); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text('인수하기',
                                  style: GoogleFonts.notoSans(
                                      color: Colors.black87, fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 결과 다이얼로그 ──────────────────────────────────────────────────────────

class _MarbleResultDialog extends StatefulWidget {
  final String? winner;
  final String? winReason;
  final String? userId;
  final int myCoins;
  final int opCoins;
  final String myCharacter;
  final String opCharacter;
  final VoidCallback onExit;

  const _MarbleResultDialog({
    required this.winner,
    required this.winReason,
    required this.userId,
    required this.myCoins,
    required this.opCoins,
    required this.myCharacter,
    required this.opCharacter,
    required this.onExit,
  });

  @override
  State<_MarbleResultDialog> createState() => _MarbleResultDialogState();
}

class _MarbleResultDialogState extends State<_MarbleResultDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _flash;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _flash = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _scale = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDraw = widget.winner == null || widget.winReason == 'timeout_draw';
    final isMe   = widget.winner == widget.userId;

    final (titleText, titleColor, titleIcon) = _buildTitle(isDraw, isMe, widget.winReason);
    final isWin = isMe && !isDraw;
    final isMonopoly = isWin && ['bankrupt', 'shrine', 'line'].contains(widget.winReason);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Stack(
        children: [
          // 흰색 플래시 (독점/파산 승리 시)
          if (isMonopoly && _flash.value > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _flash.value * 0.7),
                ),
              ),
            ),
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1535), Color(0xFF0D1117)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDraw ? const Color(0x44FFFFFF) :
                           isMe  ? const Color(0x88FFD700) : const Color(0x33FFFFFF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isWin) BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      blurRadius: 32, spreadRadius: 4,
                    ),
                    const BoxShadow(color: Color(0xAA000000), blurRadius: 24),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 타이틀
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                      child: Text(
                        '$titleIcon  $titleText',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          color: titleColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // 캐릭터 버스트
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isDraw) ...[
                            // 내 캐릭터 (크게)
                            CharacterBust(character: widget.myCharacter, width: 64, height: 80),
                            const SizedBox(width: 16),
                          ],
                          // vs or emoji
                          Text(
                            isDraw ? '🤝' : (isMe ? '>' : '<'),
                            style: TextStyle(
                              color: isDraw ? Colors.white60 : Colors.white38,
                              fontSize: isDraw ? 48 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (!isDraw) ...[
                            const SizedBox(width: 16),
                            // 상대 캐릭터 (작게)
                            Opacity(
                              opacity: isMe ? 0.6 : 1.0,
                              child: CharacterBust(character: widget.opCharacter, width: 48, height: 60),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 자산 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _AssetChip(
                              label: '내 마블',
                              amount: widget.myCoins,
                              color: const Color(0xFF7C4DFF),
                              big: isMe,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AssetChip(
                              label: '상대 마블',
                              amount: widget.opCoins,
                              color: const Color(0xFFE91E63),
                              big: !isMe,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 이유 텍스트
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Text(
                        _reasonLabel(widget.winReason, isMe),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),

                    // 버튼
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('닫기',
                                  style: GoogleFonts.notoSans(color: Colors.white54, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: widget.onExit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDraw
                                        ? [const Color(0xFF546E7A), const Color(0xFF37474F)]
                                        : (isMe
                                            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                            : [const Color(0xFF374151), const Color(0xFF1F2937)]),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '나가기',
                                  style: GoogleFonts.notoSans(
                                    color: isMe ? Colors.black87 : Colors.white70,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (String, Color, String) _buildTitle(bool isDraw, bool isMe, String? reason) {
    if (isDraw) return ('무승부', Colors.white60, '🤝');
    if (!isMe) return ('패배', Colors.white38, '😢');
    return switch (reason) {
      'bankrupt'  => ('파산 승리!',       const Color(0xFFFB923C), '💀'),
      'shrine'    => ('독점 승리!',        const Color(0xFFFFD700), '🏆'),
      'line'      => ('라인 독점 승리!',   const Color(0xFFFFD700), '🏆'),
      'timeout'   => ('자산 승리!',        Colors.white,            '⏱️'),
      _           => ('승리!',            const Color(0xFFFFD700), '🏆'),
    };
  }

  static String _reasonLabel(String? reason, bool isMe) {
    return switch (reason) {
      'bankrupt'     => isMe ? '상대방이 파산했습니다' : '파산했습니다',
      'shrine'       => '독점을 달성했습니다',
      'line'         => '한 라인을 완전히 점령했습니다',
      'timeout'      => '20라운드 후 자산으로 결정됐습니다',
      'timeout_draw' => '20라운드 후 동점으로 무승부',
      _              => '게임이 종료됐습니다',
    };
  }
}

class _AssetChip extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool big;
  const _AssetChip({required this.label, required this.amount, required this.color, required this.big});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: big ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: big ? 0.6 : 0.25), width: 1),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            fmm(amount),
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: big ? 14 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 이벤트 타일 오버레이 ───────────────────────────────────────────────────

class _TileEventOverlay extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;

  const _TileEventOverlay({required this.data, required this.onDismiss});

  @override
  State<_TileEventOverlay> createState() => _TileEventOverlayState();
}

class _TileEventOverlayState extends State<_TileEventOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDismiss();
      })
      ..forward();

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 300,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1700),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 200),
    ]).animate(_ctrl);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 300),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1700),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 200),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.data['type'] as String? ?? '';
    final (icon, name, description) = _tileInfo(type, widget.data);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: _opacity.value * 0.75),
          child: Center(
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 12)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: const Color(0xFFFFD700),
                        fontSize: 16,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static (String, String, String) _tileInfo(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'tax':
        final amount = data['amount'] as int? ?? 0;
        return ('🏦', '운영본부', '세금 ${fmm(amount)} 납부');
      case 'card':
        final card = data['card'] as Map<String, dynamic>?;
        return ('🗝️', '황금열쇠', card?['text'] as String? ?? '카드를 뽑습니다');
      case 'event':
        final ev = data['event'] as Map<String, dynamic>?;
        return ('⚡', '이벤트!', ev?['text'] as String? ?? '이벤트가 발생했습니다');
      default:
        return ('🎲', '이벤트', '이벤트가 발생했습니다');
    }
  }
}

// ─── 컨페티 레이어 (임무개시 통과 시) ─────────────────────────────────────

class _ConfettiLayer extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiLayer({required this.onDone});

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = Random();
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(28, (_) => _Particle(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: size,
          painter: _ConfettiPainter(_particles, _ctrl.value),
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double speed;
  final double phase;
  final Color color;
  final double size;

  _Particle(Random rng)
      : x = rng.nextDouble(),
        speed = 0.55 + rng.nextDouble() * 0.9,
        phase = rng.nextDouble() * 2 * pi,
        color = const [
          Color(0xFFFFD700),
          Color(0xFF00D4FF),
          Colors.white,
          Color(0xFF7C4DFF),
          Color(0xFF00C853),
        ][Random().nextInt(5)],
        size = 3 + Random().nextDouble() * 6;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = (t * p.speed).clamp(0.0, 1.1);
      if (progress > 1.0) continue;
      final x = p.x + sin(t * 3 * pi + p.phase) * 0.045;
      final opacity = t < 0.7 ? 1.0 : ((1.0 - (t - 0.7) / 0.3)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x * size.width, progress * size.height),
        p.size,
        Paint()..color = p.color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ─── 배경 ─────────────────────────────────────────────────────────────────

class _MarbleBackdrop extends StatelessWidget {
  const _MarbleBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1230), Color(0xFF2A1540), Color(0xFF1E1E35)],
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
