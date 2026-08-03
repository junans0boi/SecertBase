import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../core/app_theme.dart';
import '../../../core/auth_service.dart';
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
  final _auth = AuthService();
  int? _lastThrowSoundAt;
  int? _lastMoveSoundAt;
  String? _lastShownWinner;
  String _pieceSkin = 'base';
  String _yutSkin = 'base';

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _loadSkin();
  }

  Future<void> _loadSkin() async {
    try {
      final base = _socket.serverUrl ?? '';
      final res = await http.get(
        Uri.parse('$base/api/shop/equipped?game=yut'),
        headers: {'Authorization': 'Bearer ${_auth.token}'},
      );
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] == true) {
        final slots = body['slots'] as Map? ?? {};
        String pieceSkin = 'base';
        String yutSkin = 'base';
        final piece = slots['yut_piece'];
        if (piece != null) {
          final icon = piece['icon'] as String? ?? '';
          pieceSkin = icon.isNotEmpty ? icon : 'base';
        }
        final yut = slots['yut_yut'];
        if (yut != null) {
          final icon = yut['icon'] as String? ?? '';
          final grade = yut['grade'] as String? ?? 'B';
          yutSkin = _iconToYutSkin(icon, grade);
        }
        if (mounted) {
          setState(() {
            _pieceSkin = pieceSkin;
            _yutSkin = yutSkin;
          });
        }
      }
    } catch (_) {}
  }

  String _iconToYutSkin(String icon, String grade) {
    return switch (icon) {
      '🌸' || '🌺' || '💝' || '🌷' => 'cherry',
      '🔥' || '⛈️' || '🐉' => 'fire',
      '🌱' || '🍃' || '🌿' || '🎋' => 'bamboo',
      '❄️' || '🧊' || '🌙' || '⭐' || '💎' => 'crystal',
      '🌌' || '✨' || '🎯' || '🦅' || '⚡' => 'legend',
      '🪨' || '🪵' => 'stone',
      '☀️' || '🌞' || '🏅' => 'gold',
      '🍁' => 'autumn',
      '🌊' => 'wave',
      '💨' => 'wind',
      '🌪️' => 'storm',
      _ => switch (grade) {
        'SSS' => 'legend',
        'SS' => 'crystal',
        'S' => 'gold',
        'A' => 'bamboo',
        _ => 'base',
      },
    };
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

  void _showItemPopup(BuildContext ctx, Map<String, dynamic> slotInfo) {
    final name = slotInfo['name'] as String? ?? '?';
    final icon = slotInfo['icon'] as String? ?? '🎁';
    final grade = slotInfo['grade'] as String? ?? 'B';
    final stats = (slotInfo['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final firstStat = stats.entries.firstOrNull;

    showModalBottomSheet<void>(
      context: ctx,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$icon $name',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _GradeBadge(grade: grade),
            if (firstStat != null) ...[
              const SizedBox(height: 8),
              Text(
                '${_statLabel(firstStat.key)}: ${firstStat.value}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _statLabel(String key) {
    const labels = {
      'yut_control_pct': '윷 컨트롤 +%',
      'yut_mo_rate_pct': '모 확률 +%',
      'yut_backdo_bonus_pct': '백도 보너스 던지기 %',
      'yut_win_coin_pct': '윷/모 추가 코인 %',
      'yut_overturn_pct': '역전 확률 +%',
      'piece_catch_resist_pct': '잡힘 방어 %',
      'piece_catch_coin_bonus': '잡기 추가 코인',
      'piece_safe_zone_pct': '안전 착지 %',
      'piece_group_pct': '그룹 유지 %',
      'coin_bonus_pct': '코인 보너스 +%',
      'shop_discount_pct': '상점 할인 %',
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final currentUser = sock.userId ?? '';
    final p1 = sock.yutPlayers.isNotEmpty ? sock.yutPlayers[0] : '';
    final p2 = sock.yutPlayers.length > 1 ? sock.yutPlayers[1] : '';
    final p1Pieces = sock.yutPieceDetails[p1] ?? sock.yutPieces[p1];
    final p2Pieces = sock.yutPieceDetails[p2] ?? sock.yutPieces[p2];
    final opponentCode = (currentUser == p1) ? p2 : p1;
    final opponentItems = sock.yutEquippedItems[opponentCode] ?? {};
    final opPieceData = opponentItems['yut_piece'] as Map? ?? {};
    final opYutData = opponentItems['yut_yut'] as Map? ?? {};
    final opponentPieceSkin =
        (opPieceData['icon'] as String?)?.isNotEmpty == true
        ? opPieceData['icon'] as String
        : 'base';
    final opponentYutSkin = opYutData.isNotEmpty
        ? _iconToYutSkin(
            opYutData['icon'] as String? ?? '',
            opYutData['grade'] as String? ?? 'B',
          )
        : 'base';

    return GameScaffold(
      title: '🀄 윷놀이',
      fullBleed: true,
      showAppBar: false,
      child: GameMenuListener(
        gameType: 'yut',
        child: Stack(
          children: [
            const Positioned.fill(child: _YutBackdrop()),
            Positioned.fill(
              child: YutBoard(
                gameId: sock.yutActive ? (sock.yutGameId ?? 'active') : null,
                phase: sock.yutPhase,
                turn: sock.yutCurrentTurn,
                p1Pieces: p1Pieces,
                p2Pieces: p2Pieces,
                pendingMoves: sock.yutPendingMoves,
                startRolls: sock.yutStartRolls,
                orderCountdownUntil: sock.yutOrderCountdownUntil,
                onNewGame: sock.newYutGame,
                onRollStartDice: sock.rollYutStartDice,
                hasBonusThrow: sock.yutHasBonusThrow,
                onThrow: sock.throwYut,
                onMovePiece: (pieceId, moveIndex, {int? backdoDir}) =>
                    sock.moveYut(
                      pieceId,
                      moveIndex: moveIndex,
                      backdoDir: backdoDir,
                    ),
                onMoveNewPiece: () => sock.moveYut(0),
                currentUser: currentUser,
                lastResultName: sock.yutLastThrow,
                lastThrowAt: sock.yutLastThrowAt,
                lastThrowNak: sock.yutLastNak,
                p1Character: _characterFor(p1),
                p2Character: _characterFor(p2),
                onThrowResultRevealed: _playThrowResultAudio,
                p1UserId: p1,
                p2UserId: p2,
                displayName: sock.nameOf,
                pieceSkin: _pieceSkin,
                yutSkin: _yutSkin,
                opponentPieceSkin: opponentPieceSkin,
                opponentYutSkin: opponentYutSkin,
                coins: sock.walletBalance,
              ),
            ),
            Positioned(
              left: 10,
              top: 8,
              child: _YutChromeButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: '나가기',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              right: 8,
              top: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC0B4075),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD36A), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: GameMenuButton(
                  hasRestart: sock.yutActive,
                  restartWaiting: sock.restartWaiting,
                  onRequestRestart: () => sock.requestRestart('yut'),
                ),
              ),
            ),
            // 상대방 장착 아이템 배지 (우상단)
            if (opponentItems.isNotEmpty)
              Positioned(
                right: 14,
                top: 58,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final slot in ['yut_yut', 'yut_piece'])
                      if (opponentItems[slot] != null)
                        GestureDetector(
                          onTap: () =>
                              _showItemPopup(context, opponentItems[slot]!),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _GradeBadge(
                              grade:
                                  opponentItems[slot]!['grade'] as String? ??
                                  'B',
                              icon:
                                  opponentItems[slot]!['icon'] as String? ??
                                  '🎁',
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
}

class _YutChromeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _YutChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF299DEB), Color(0xFF0755A5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD36A), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String grade;
  final String? icon;
  const _GradeBadge({required this.grade, this.icon});

  static Color _color(String g) => switch (g) {
    'SSS' => const Color(0xFFFF7043),
    'SS' => const Color(0xFFAB47BC),
    'S' => const Color(0xFF42A5F5),
    'A' => const Color(0xFF66BB6A),
    _ => const Color(0xFF9E9E9E),
  };

  @override
  Widget build(BuildContext context) {
    final c = _color(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        border: Border.all(color: c, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Text(icon!, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 2),
          Text(
            grade,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _YutBackdrop extends StatelessWidget {
  const _YutBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/yut/Summer.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2A211A),
                  Color(0xFF5B4632),
                  Color(0xFF1E2C25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.03),
                Colors.black.withValues(alpha: 0.14),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
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
