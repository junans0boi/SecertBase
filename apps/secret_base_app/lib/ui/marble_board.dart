import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/socket_service.dart';
import '../core/yut_audio.dart';
import '../core/marble_characters.dart';
import 'marble_map_data.dart';

String _defaultDisplayName(String uid) => uid;

// ─── 돈 포맷 (marble_screen.dart와 동일) ─────────────────────────────────
String fmm(int n) {
  if (n == 0) return '0';
  final abs = n.abs();
  final sign = n < 0 ? '-' : '';
  final man = abs ~/ 10000;
  final rem = abs % 10000;
  if (man == 0) return '$sign${rem}원';
  if (rem == 0) return '${sign}${man}만원';
  return '${sign}${man}만${rem}원';
}

class MarbleBoard extends StatefulWidget {
  final String? gameId;
  final String? phase;
  final String? turn;
  final List<dynamic>? p1Pieces;
  final List<dynamic>? p2Pieces;
  final List<dynamic>? pendingMoves;
  final Map<String, dynamic>? startRolls;
  final int? orderCountdownUntil;
  final bool hasDoubleRoll;
  final VoidCallback onNewGame;
  final VoidCallback onRollStartDice;
  final VoidCallback onRoll;
  final void Function(int, int) onMovePiece;
  final VoidCallback onMoveNewPiece;
  final String currentUser;
  final Map<String, dynamic>? lastRoll; // {dice1, dice2, total, isDouble}
  final int? lastRollAt;
  final String p1Character;
  final String p2Character;
  final String p1UserId;
  final String p2UserId;
  final String Function(String) displayName;
  final String pieceSkin;
  final String opponentPieceSkin;
  final int? coins;
  final Map<String, dynamic> landData; // posStr → {owner, level}

  const MarbleBoard({
    super.key,
    this.gameId,
    this.phase,
    this.turn,
    this.p1Pieces,
    this.p2Pieces,
    this.pendingMoves,
    this.startRolls,
    this.orderCountdownUntil,
    this.hasDoubleRoll = false,
    required this.onNewGame,
    required this.onRollStartDice,
    required this.onRoll,
    required this.onMovePiece,
    required this.onMoveNewPiece,
    required this.currentUser,
    this.lastRoll,
    this.lastRollAt,
    this.p1Character = 'k',
    this.p2Character = 'ria',
    this.p1UserId = '',
    this.p2UserId = '',
    this.displayName = _defaultDisplayName,
    this.pieceSkin = 'base',
    this.opponentPieceSkin = 'base',
    this.coins,
    this.landData = const {},
  });

  @override
  State<MarbleBoard> createState() => _MarbleBoardState();
}

class _MoveGuideOption {
  final int index;
  final int steps;
  final int targetPos;

  const _MoveGuideOption({
    required this.index,
    required this.steps,
    required this.targetPos,
  });
}

class _MarbleBoardState extends State<MarbleBoard> with TickerProviderStateMixin {
  static const double _pieceSize = 44;
  static const double _guideSize = 56;

  // Responsive computed values (set each build from MediaQuery)
  double _cPieceSize = 36;
  double _cGuideSize = 56;
  bool _compact = false;

  late AnimationController _resultBounceCtrl;
  late AnimationController _diceRollCtrl;
  bool _showDiceAnim = false;
  Map<String, dynamic>? _animRoll;
  Map<String, dynamic>? _revealedRoll;
  Timer? _countdownTimer;
  Timer? _moveUnlockTimer;
  int _countdownSeconds = 0;

  int? _selectedPieceId;
  bool _moveInFlight = false;
  int? _lastTrackedRollAt;

  final _socket = SocketService();
  int _seenMessages = 0;
  int _chatUnread = 0;
  Map<String, dynamic>? _chatPreview;
  Timer? _previewTimer;

  String _display(String uid) => widget.displayName(uid);

  @override
  void initState() {
    super.initState();
    _resultBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _diceRollCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _diceRollCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showDiceAnim = false;
          _revealedRoll = widget.lastRoll;
        });
        _resultBounceCtrl.forward(from: 0);
      }
    });
    _revealedRoll = widget.lastRoll;
    if (_revealedRoll != null) _resultBounceCtrl.value = 1.0;
    _lastTrackedRollAt = widget.lastRollAt;
    _seenMessages = _socket.marbleChatMessages.length;
    _socket.addListener(_onSocketUpdate);
    _syncCountdown();
  }

  @override
  void didUpdateWidget(MarbleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastRollAt != oldWidget.lastRollAt && widget.lastRoll != null) {
      _animRoll = widget.lastRoll;
      if (_showDiceAnim) {
        setState(() => _animRoll = widget.lastRoll);
      } else {
        setState(() {
          _animRoll = widget.lastRoll;
          _showDiceAnim = true;
          _revealedRoll = null;
        });
        _diceRollCtrl.forward(from: 0);
      }
    }
    if (widget.turn != oldWidget.turn ||
        widget.phase != oldWidget.phase ||
        widget.pendingMoves != oldWidget.pendingMoves) {
      _selectedPieceId = null;
      _moveUnlockTimer?.cancel();
      _moveInFlight = false;
      final hadMoves = oldWidget.pendingMoves?.isNotEmpty == true;
      final hasMoves = widget.pendingMoves?.isNotEmpty == true;
      if (!hadMoves && hasMoves) {
        _selectedPieceId = _autoDefaultPieceId();
      }
    }
    if (widget.phase != oldWidget.phase ||
        widget.orderCountdownUntil != oldWidget.orderCountdownUntil) {
      _syncCountdown();
    }
    if (widget.gameId != oldWidget.gameId) {
      _lastTrackedRollAt = widget.lastRollAt;
    } else if (widget.lastRollAt != null &&
        widget.lastRollAt != _lastTrackedRollAt) {
      _lastTrackedRollAt = widget.lastRollAt;
    }
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocketUpdate);
    _previewTimer?.cancel();
    _countdownTimer?.cancel();
    _moveUnlockTimer?.cancel();
    _resultBounceCtrl.dispose();
    _diceRollCtrl.dispose();
    super.dispose();
  }

  void _syncCountdown() {
    _countdownTimer?.cancel();
    if (widget.phase != 'order_countdown' ||
        widget.orderCountdownUntil == null) {
      _countdownSeconds = 0;
      return;
    }
    void tick() {
      final remainingMs =
          widget.orderCountdownUntil! - DateTime.now().millisecondsSinceEpoch;
      final nextSeconds = (remainingMs / 1000).ceil().clamp(0, 3);
      if (mounted) { setState(() => _countdownSeconds = nextSeconds); }
      else { _countdownSeconds = nextSeconds; }
      if (nextSeconds <= 0) _countdownTimer?.cancel();
    }
    tick();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  void _onSocketUpdate() {
    if (!mounted) return;
    final msgs = _socket.marbleChatMessages;
    if (msgs.length > _seenMessages) {
      final newMsg = msgs.last;
      if (newMsg['by'] != widget.currentUser) {
        _previewTimer?.cancel();
        setState(() {
          _chatUnread++;
          _chatPreview = newMsg;
        });
        _previewTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _chatPreview = null);
        });
      }
      _seenMessages = msgs.length;
    }
  }

  void _handleRoll() {
    setState(() {
      _showDiceAnim = true;
      _animRoll = null;
      _revealedRoll = null;
    });
    _diceRollCtrl.forward(from: 0);
    widget.onRoll();
  }

  Offset _toCanvasPoint(Size size, int pos) {
    final norm = marbleNormalizedCenter(pos);
    return Offset(norm.dx * size.width, norm.dy * size.height);
  }

  int _getPos(dynamic p) {
    if (p is Map) return p['position'] as int? ?? 0;
    if (p is int) return p;
    return 0;
  }

  bool _isFinished(dynamic p) {
    if (p is Map) return p['finished'] == true;
    return false;
  }

  int _moveValue(dynamic move) {
    if (move is int) return move;
    if (move is num) return move.toInt();
    return int.tryParse('$move') ?? 0;
  }

  List<_MoveGuideOption> _moveOptionsFor(dynamic piece) {
    final moves = widget.pendingMoves;
    if (piece == null || moves == null || moves.isEmpty) {
      return const [];
    }

    if (_isFinished(piece)) {
      return const [];
    }

    final options = <_MoveGuideOption>[];
    for (var i = 0; i < moves.length; i++) {
      final steps = _moveValue(moves[i]);
      if (steps <= 0) continue;
      options.add(_MoveGuideOption(
        index: i,
        steps: steps,
        targetPos: _previewMove(piece, steps),
      ));
    }
    return options;
  }

  bool _hasMoveOptionFor(dynamic piece) {
    return _moveOptionsFor(piece).isNotEmpty;
  }

  int _optionOrdinal(_MoveGuideOption option) {
    final moves = widget.pendingMoves ?? const [];
    var ordinal = 0;
    for (var i = 0; i <= option.index && i < moves.length; i += 1) {
      if (_moveValue(moves[i]) == option.steps) {
        ordinal += 1;
      }
    }
    return ordinal;
  }

  bool _hasDuplicateMove(_MoveGuideOption option) {
    final moves = widget.pendingMoves ?? const [];
    var count = 0;
    for (final move in moves) {
      if (_moveValue(move) == option.steps) count += 1;
    }
    return count > 1;
  }

  Offset _guideJitter(_MoveGuideOption option) {
    final sameTargetCount = (widget.pendingMoves ?? const [])
        .asMap()
        .entries
        .where((entry) => _moveValue(entry.value) == option.steps)
        .length;
    if (sameTargetCount <= 1) return Offset.zero;
    final angle = option.index * pi * 0.65;
    return Offset(cos(angle), sin(angle)) * 6;
  }

  int _getNextPos(int currentPos, bool isFirstStep, int lastPos) =>
      (currentPos + 1) % 24;

  int _getPrevPos(int currentPos, int lastPos) =>
      (currentPos - 1 + 24) % 24;

  int _getLastPos(dynamic p) {
    if (p is Map) return p['lastPos'] as int? ?? 0;
    return 0;
  }

  int _previewMove(dynamic piece, int steps) {
    var pos = _getPos(piece);
    var lastPos = _getLastPos(piece);
    if (_isFinished(piece)) return pos;
    if (steps == -1) return _getPrevPos(pos, lastPos);
    for (var i = 0; i < steps; i++) {
      final nextPos = _getNextPos(pos, i == 0, lastPos);
      lastPos = pos;
      pos = nextPos;
    }
    return pos;
  }

  int? _autoDefaultPieceId() {
    if (widget.turn != widget.currentUser) return null;
    final pieces = widget.currentUser == widget.p2UserId
        ? widget.p2Pieces
        : widget.p1Pieces;
    if (pieces == null) return null;
    // 우선: 대기 중인 말 (pos == 0, 미완료)
    for (var i = 0; i < pieces.length; i++) {
      if (!_isFinished(pieces[i]) &&
          _getPos(pieces[i]) == 0 &&
          _hasMoveOptionFor(pieces[i])) {
        return i;
      }
    }
    // 폴백: 이동 가능한 첫 번째 말
    for (var i = 0; i < pieces.length; i++) {
      if (_hasMoveOptionFor(pieces[i])) {
        return i;
      }
    }
    return null;
  }

  void _selectPiece(int pieceId) {
    if (!_canSelectPiece(pieceId)) return;
    setState(() {
      _selectedPieceId = pieceId;
    });
  }

  bool _canSelectPiece(int pieceId) {
    final isMyTurn = widget.turn == widget.currentUser;
    final hasMove = widget.pendingMoves?.isNotEmpty == true;
    final isMovePhase = widget.phase == 'moving' || widget.phase == 'throwing';
    final pieces = widget.currentUser == widget.p2UserId
        ? widget.p2Pieces
        : widget.p1Pieces;
    if (_moveInFlight) return false;
    if (!isMyTurn || !hasMove || !isMovePhase || pieces == null) return false;
    if (pieceId < 0 || pieceId >= pieces.length) return false;
    return _hasMoveOptionFor(pieces[pieceId]);
  }

  Widget _buildGuideMarker(Size boardSize, _MoveGuideOption option) {
    if (_selectedPieceId == null) {
      return const SizedBox.shrink();
    }
    final targetOffset =
        _toCanvasPoint(boardSize, option.targetPos) + _guideJitter(option);
    final label = _hasDuplicateMove(option)
        ? '${_moveLabel(option.steps)}${_optionOrdinal(option)}'
        : _moveLabel(option.steps);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      left: targetOffset.dx - (_cGuideSize / 2),
      top: targetOffset.dy - (_cGuideSize / 2),
      width: _cGuideSize,
      height: _cGuideSize,
      child: GestureDetector(
        onTap: () {
          final pieceId = _selectedPieceId;
          if (pieceId == null) return;
          setState(() {
            _selectedPieceId = null;
            _moveInFlight = true;
          });
          _moveUnlockTimer?.cancel();
          _moveUnlockTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _moveInFlight = false);
          });
          widget.onMovePiece(pieceId, option.index);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.yellowAccent, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.yellowAccent, blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedPiece(
    Color color,
    String character,
    int count, {
    bool selected = false,
    String pieceSkin = 'base',
  }) {
    final inner = (_cPieceSize - 4).clamp(28.0, 44.0);
    final centerInset = (_cPieceSize - inner) / 2;
    final stackCenterOffset = (count - 1) * 2.0;
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(count, (i) {
        return Positioned(
          top: centerInset + stackCenterOffset + (i * -4.0),
          left: centerInset + stackCenterOffset + (i * -4.0),
          child: Container(
            width: inner,
            height: inner,
            alignment: Alignment.center,
            child: _CharacterToken(
              character: character,
              color: color,
              selected: selected,
              count: i == count - 1 && count > 1 ? count : null,
              pieceSkin: pieceSkin,
            ),
          ),
        );
      }).reversed.toList(),
    );
  }

  Widget _buildBoardPiece({
    Key? key,
    required Size boardSize,
    required int pos,
    required Color color,
    required String character,
    required int count,
    required bool selected,
    required VoidCallback? onTap,
    String pieceSkin = 'base',
  }) {
    final point = _toCanvasPoint(boardSize, pos);

    return AnimatedPositioned(
      key: key,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutBack,
      left: point.dx - (_cPieceSize / 2),
      top: point.dy - (_cPieceSize / 2),
      width: _cPieceSize,
      height: _cPieceSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _buildGroupedPiece(
          color,
          character,
          count,
          selected: selected,
          pieceSkin: pieceSkin,
        ),
      ),
    );
  }

  String _moveLabel(dynamic move) {
    final value = move is num ? move.toInt() : int.tryParse('$move');
    return value != null ? '$value칸' : '$move';
  }

  Widget _buildRollOrderView() {
    final p1Roll = widget.startRolls?[widget.p1UserId];
    final p2Roll = widget.startRolls?[widget.p2UserId];
    final alreadyRolled = widget.startRolls?[widget.currentUser] != null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xCC1A1A2E), Color(0xDD0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Text(
                '선공 정하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStartDice(widget.p1UserId, p1Roll),
                const SizedBox(width: 32),
                _buildStartDice(widget.p2UserId, p2Roll),
              ],
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: alreadyRolled ? null : widget.onRollStartDice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: alreadyRolled
                        ? [const Color(0xFF546E7A), const Color(0xFF37474F)]
                        : [const Color(0xFFFFC107), const Color(0xFFFF6F00)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: alreadyRolled
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFFFFB300,
                            ).withValues(alpha: 0.6),
                            blurRadius: 20,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.casino_rounded,
                      color: alreadyRolled ? Colors.white38 : Colors.black87,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      alreadyRolled ? '상대방 대기 중' : '내 주사위 굴리기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: alreadyRolled ? Colors.white38 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '숫자가 높은 사람이 먼저 윷을 던집니다.\n동점이면 다시 굴려요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCountdownView() {
    final first = widget.p1UserId;
    final second = widget.p2UserId;
    final firstRoll = widget.startRolls?[first];
    final secondRoll = widget.startRolls?[second];
    final starter = widget.turn ?? '-';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xCC1A1A2E), Color(0xDD0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Text(
                '선공 결정!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStartDice(first, firstRoll, highlight: first == starter),
                const SizedBox(width: 32),
                _buildStartDice(
                  second,
                  secondRoll,
                  highlight: second == starter,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC107), Color(0xFFFF6F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Text(
                '${_display(starter)} 선공',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${_countdownSeconds.clamp(1, 3)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 84,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Color(0x80FFFFFF), blurRadius: 24)],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '곧 게임이 시작됩니다',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDice(String name, dynamic value, {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _display(name),
          style: TextStyle(
            color: highlight ? const Color(0xFFFFD700) : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: highlight
                  ? [const Color(0xFFFFF9C4), const Color(0xFFFFEB3B)]
                  : [const Color(0xFFE0E0E0), const Color(0xFFBDBDBD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: highlight
                ? Border.all(color: const Color(0xFFFFD700), width: 3)
                : null,
            boxShadow: [
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
              if (highlight)
                const BoxShadow(color: Color(0xFFFFD700), blurRadius: 20),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value == null ? '?' : '$value',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: highlight
                  ? const Color(0xFF5D4037)
                  : const Color(0xFF795548),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _compact = screenWidth < 430;
    if (_compact) {
      _cPieceSize = 29.0; // §7: 34 * 0.85
      _cGuideSize = 44.0;
    } else {
      _cPieceSize = _pieceSize * 0.85; // §7: ≈37.4
      _cGuideSize = _guideSize;
    }

    final isMyTurn = widget.turn == widget.currentUser;
    final isP2 = widget.currentUser == widget.p2UserId;
    final isRollOrder = widget.phase == 'roll_order';
    final isOrderCountdown = widget.phase == 'order_countdown';
    final canThrow = isMyTurn && widget.phase == 'throwing';

    final myPieces = isP2 ? widget.p2Pieces : widget.p1Pieces;
    final p1PieceSkin = isP2 ? widget.opponentPieceSkin : widget.pieceSkin;
    final p2PieceSkin = isP2 ? widget.pieceSkin : widget.opponentPieceSkin;

    Map<int, int> p1Counts = {};
    if (widget.p1Pieces != null) {
      for (var p in widget.p1Pieces!) {
        final pos = _getPos(p);
        if (!_isFinished(p) && pos > 0) {
          p1Counts[pos] = (p1Counts[pos] ?? 0) + 1;
        }
      }
    }
    Map<int, int> p2Counts = {};
    if (widget.p2Pieces != null) {
      for (var p in widget.p2Pieces!) {
        final pos = _getPos(p);
        if (!_isFinished(p) && pos > 0) {
          p2Counts[pos] = (p2Counts[pos] ?? 0) + 1;
        }
      }
    }

    Set<int> renderedP1 = {};
    Set<int> renderedP2 = {};
    final selectedPiece =
        _selectedPieceId != null &&
            myPieces != null &&
            _selectedPieceId! < myPieces.length
        ? myPieces[_selectedPieceId!]
        : null;
    final guideOptions = selectedPiece == null
        ? const <_MoveGuideOption>[]
        : _moveOptionsFor(selectedPiece);

    if (widget.gameId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/yut/yut_logo.png',
              width: 120,
              errorBuilder: (_, _, _) =>
                  const Text('🎲', style: TextStyle(fontSize: 80)),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: widget.onNewGame,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC107), Color(0xFFFF6F00)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.7),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black87,
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Text(
                      '실전형 윷놀이 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isRollOrder) return _buildRollOrderView();
    if (isOrderCountdown) return _buildOrderCountdownView();

    return Stack(
      children: [
        Column(
          children: [
            // ── 보드 영역 (카드 오버레이 포함, 전체 가용 공간)
            Expanded(
              child: LayoutBuilder(
                builder: (context, stageConstraints) {
                  final stageHeight = stageConstraints.maxHeight;
                  final boardSide = min(
                    screenWidth * 0.96,
                    stageHeight * (_compact ? 0.74 : 0.78),
                  );
                  final boardTop = stageHeight * (_compact ? 0.22 : 0.19);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: boardTop,
                        left: (screenWidth - boardSide) / 2,
                        width: boardSide,
                        height: boardSide,
                        child: LayoutBuilder(
                          key: const ValueKey('marble_board_surface'),
                          builder: (context, constraints) {
                            final boardSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      key: const ValueKey('marble_board_art'),
                                      painter: _MarbleBoardPainter(
                                        landData: widget.landData,
                                        p1UserId: widget.p1UserId,
                                        p2UserId: widget.p2UserId,
                                      ),
                                    ),
                                  ),
                                ),
                                  if (selectedPiece != null &&
                                      guideOptions.isNotEmpty)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _MoveTrailPainter(
                                            start: _toCanvasPoint(
                                              boardSize,
                                              _getPos(selectedPiece),
                                            ),
                                            targets: guideOptions
                                                .map(
                                                  (option) => _toCanvasPoint(
                                                    boardSize,
                                                    option.targetPos,
                                                  ),
                                                )
                                                .toList(),
                                            color: isP2
                                                ? const Color(0xFF75ECFF)
                                                : const Color(0xFFFF91C9),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (widget.p1Pieces != null)
                                    ...widget.p1Pieces!.asMap().entries.map((
                                      e,
                                    ) {
                                      final pos = _getPos(e.value);
                                      if (pos == 0 || _isFinished(e.value)) {
                                        return const SizedBox.shrink();
                                      }
                                      if (renderedP1.contains(pos)) {
                                        return const SizedBox.shrink();
                                      }
                                      renderedP1.add(pos);
                                      return _buildBoardPiece(
                                        key: ValueKey('p1_${e.key}'),
                                        boardSize: boardSize,
                                        pos: pos,
                                        color: const Color(0xFFE45858),
                                        character: widget.p1Character,
                                        count: p1Counts[pos] ?? 1,
                                        selected:
                                            !isP2 && _selectedPieceId == e.key,
                                        onTap: !isP2
                                            ? () => _selectPiece(e.key)
                                            : null,
                                        pieceSkin: p1PieceSkin,
                                      );
                                    }),
                                  if (widget.p2Pieces != null)
                                    ...widget.p2Pieces!.asMap().entries.map((
                                      e,
                                    ) {
                                      final pos = _getPos(e.value);
                                      if (pos == 0 || _isFinished(e.value)) {
                                        return const SizedBox.shrink();
                                      }
                                      if (renderedP2.contains(pos)) {
                                        return const SizedBox.shrink();
                                      }
                                      renderedP2.add(pos);
                                      return _buildBoardPiece(
                                        key: ValueKey('p2_${e.key}'),
                                        boardSize: boardSize,
                                        pos: pos,
                                        color: const Color(0xFF4B8DD8),
                                        character: widget.p2Character,
                                        count: p2Counts[pos] ?? 1,
                                        selected:
                                            isP2 && _selectedPieceId == e.key,
                                        onTap: isP2
                                            ? () => _selectPiece(e.key)
                                            : null,
                                        pieceSkin: p2PieceSkin,
                                      );
                                    }),
                                  ...guideOptions.map(
                                    (option) =>
                                        _buildGuideMarker(boardSize, option),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // ── 액션 바 (하단 고정)
            _buildActionBar(canThrow: canThrow),
          ],
        ),
        if (_showDiceAnim)
          Positioned.fill(
            child: _DiceRollOverlay(
              animation: _diceRollCtrl,
              roll: _animRoll,
            ),
          ),
        if (_chatPreview != null)
          Positioned(
            left: 12,
            right: 64,
            bottom: 72,
            child: _ChatPreviewBubble(
              message: _chatPreview!,
              displayName: widget.displayName,
              onDismiss: () {
                _previewTimer?.cancel();
                setState(() => _chatPreview = null);
              },
            ),
          ),
      ],
    );
  }


  Widget _buildActionBar({required bool canThrow}) {
    final roll = _revealedRoll;
    final d1 = (roll?['dice1'] as num?)?.toInt() ?? 0;
    final d2 = (roll?['dice2'] as num?)?.toInt() ?? 0;
    final isDouble = roll?['isDouble'] == true;
    return Container(
      key: const ValueKey('yut_action_bar'),
      decoration: const BoxDecoration(
        color: Color(0xF00D1117),
        border: Border(top: BorderSide(color: Color(0x33FFD700), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(_compact ? 8 : 12, 8, _compact ? 8 : 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─ 왼쪽: 주사위 결과 or 안내 텍스트 ─
              Expanded(
                child: roll != null && d1 > 0
                    ? _buildDiceResultArea(d1, d2, isDouble)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _actionPrompt(canThrow: canThrow),
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: _compact ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // ─ 가운데: ROLL 버튼 ─
              _DiceRollButton(
                enabled: canThrow,
                loading: _showDiceAnim,
                compact: _compact,
                onTap: _handleRoll,
              ),
              const SizedBox(width: 8),
              // ─ 오른쪽: 설정 + 채팅 ─
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionBtn(Icons.settings_outlined, () => _showSettings(context)),
                  const SizedBox(width: 4),
                  _buildChatBtn(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiceResultArea(int d1, int d2, bool isDouble) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _compact ? 36 : 42,
          height: _compact ? 36 : 42,
          child: CustomPaint(painter: _DieFacePainter(value: d1)),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: _compact ? 36 : 42,
          height: _compact ? 36 : 42,
          child: CustomPaint(painter: _DieFacePainter(value: d2)),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d1 + d2}칸',
              style: GoogleFonts.notoSans(
                color: const Color(0xFFFFD700),
                fontSize: _compact ? 16 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (isDouble)
              Text(
                '더블!',
                style: TextStyle(
                  color: const Color(0xFF00D4FF),
                  fontSize: _compact ? 9 : 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatBtn(BuildContext context) {
    final size = _compact ? 36.0 : 40.0;
    return GestureDetector(
      onTap: () => _showChat(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Icon(Icons.chat_bubble_outline, color: Colors.white70, size: size * 0.52),
          ),
          if (_chatUnread > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  _chatUnread > 9 ? '9+' : '$_chatUnread',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, VoidCallback onTap) {
    final size = _compact ? 36.0 : 40.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white70, size: size * 0.52),
      ),
    );
  }

  String _actionPrompt({required bool canThrow}) {
    if (_showDiceAnim) return '주사위 굴리는 중';
    final isMyTurn = widget.turn == widget.currentUser;
    final hasMoves = widget.pendingMoves?.isNotEmpty ?? false;
    if (!isMyTurn) {
      return widget.phase == 'moving' ? '상대가 말을 이동하는 중' : '상대가 주사위 굴리는 중';
    }
    if (hasMoves) {
      return _selectedPieceId == null ? '내 말 선택' : '이동 칸 선택';
    }
    if (canThrow) {
      final isDouble = widget.hasDoubleRoll;
      return isDouble ? '🎲 더블! 한 번 더!' : '주사위를 굴려주세요';
    }
    return '상대방을 기다리는 중';
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _YutSettingsSheet(),
    );
  }

  void _showChat(BuildContext context) {
    setState(() {
      _chatUnread = 0;
      _chatPreview = null;
    });
    _previewTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _YutChatSheet(),
    );
  }
}

class _YutSettingsSheet extends StatefulWidget {
  const _YutSettingsSheet();

  @override
  State<_YutSettingsSheet> createState() => _YutSettingsSheetState();
}

class _YutSettingsSheetState extends State<_YutSettingsSheet> {
  final _audio = YutAudio.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xE62B3440),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '게임 설정',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('효과음', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                '던지기와 게임 결과 효과음',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              value: _audio.effectsEnabled,
              activeTrackColor: const Color(0xFF79B8B1),
              onChanged: (value) async {
                await _audio.setEffectsEnabled(value);
                if (mounted) setState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('배경음악', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                '게임 중 반복 재생되는 음악',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
              value: _audio.backgroundMusicEnabled,
              activeTrackColor: const Color(0xFF79B8B1),
              onChanged: (value) async {
                await _audio.setBackgroundMusicEnabled(value);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _YutChatSheet extends StatefulWidget {
  const _YutChatSheet();

  @override
  State<_YutChatSheet> createState() => _YutChatSheetState();
}

class _YutChatSheetState extends State<_YutChatSheet> {
  final _socket = SocketService();
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _messageController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _send() {
    _socket.sendMarbleChat(_messageController.text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _socket.marbleChatMessages;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.58,
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE62B3440),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '게임 채팅',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        '상대방에게 메시지를 보내보세요.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  : ListView.separated(
                      reverse: true,
                      itemCount: messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final message = messages[messages.length - 1 - index];
                        final isMine = message['by'] == _socket.userId;
                        final senderId = message['by'] as String;
                        final isFirstPlayer =
                            _socket.yutPlayers.isNotEmpty &&
                            _socket.yutPlayers.first == senderId;
                        final character =
                            _socket.yutCharacters[senderId] ??
                            (isFirstPlayer ? 'honggilldong' : 'miho');
                        final tokenColor = isFirstPlayer
                            ? const Color(0xFFE45858)
                            : const Color(0xFF4B8DD8);
                        final avatar = SizedBox(
                          width: 34,
                          height: 34,
                          child: _CharacterToken(
                            character: character,
                            color: tokenColor,
                            pieceSkin: 'base',
                          ),
                        );
                        final bubble = ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 218),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMine ? '나' : _socket.nameOf(senderId),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? const Color(0xFF5F8D88)
                                      : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  message['message'] as String,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: isMine
                                ? [bubble, const SizedBox(width: 6), avatar]
                                : [avatar, const SizedBox(width: 6), bubble],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLength: 200,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '메시지 입력',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                  color: const Color(0xFFA7D8D1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveTrailPainter extends CustomPainter {
  final Offset start;
  final List<Offset> targets;
  final Color color;

  const _MoveTrailPainter({
    required this.start,
    required this.targets,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var targetIndex = 0; targetIndex < targets.length; targetIndex++) {
      final target = targets[targetIndex];
      final midpoint = (start + target) / 2;
      final direction = target - start;
      final bend =
          Offset(-direction.dy, direction.dx) * (0.08 + (targetIndex * 0.018));
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          midpoint.dx + bend.dx,
          midpoint.dy + bend.dy,
          target.dx,
          target.dy,
        );

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );

      for (final metric in path.computeMetrics()) {
        for (final fraction in const [0.24, 0.48, 0.72]) {
          final tangent = metric.getTangentForOffset(metric.length * fraction);
          if (tangent == null) continue;
          canvas.drawCircle(
            tangent.position,
            fraction == 0.48 ? 2.4 : 1.7,
            Paint()..color = Colors.white.withValues(alpha: 0.88),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoveTrailPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.targets != targets ||
        oldDelegate.color != color;
  }
}

class _MarbleBoardPainter extends CustomPainter {
  final Map<String, dynamic> landData;
  final String? p1UserId;
  final String? p2UserId;

  const _MarbleBoardPainter({
    this.landData = const {},
    this.p1UserId,
    this.p2UserId,
  });

  // ── Board geometry (matches marble_map_data.dart) ──────────────────────
  static const double _unit  = 560.0;
  static const double _c     = 70.0;   // corner size
  static const double _bandW = 20.0;   // color band width (inner edge)

  // Player colors
  static const _p1Color = Color(0xFFE45858);
  static const _p2Color = Color(0xFF4B8DD8);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _unit;
    canvas.save();
    canvas.scale(scale, scale);
    _drawFrame(canvas);
    _drawCenterField(canvas);
    _drawAllTiles(canvas);
    _drawOwnershipOverlays(canvas);
    canvas.restore();
  }

  // ── Board frame & background ──────────────────────────────────────────────

  void _drawFrame(Canvas canvas) {
    final fullRect = Rect.fromLTWH(0, 0, _unit, _unit);

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 6, _unit - 2, _unit - 2),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xCC000000),
    );

    // Wood-like outer frame
    final outerRRect = RRect.fromRectAndRadius(fullRect, const Radius.circular(14));
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A2C0A), Color(0xFF2A1505)],
        ).createShader(fullRect),
    );

    // Gold outer trim
    canvas.drawRRect(
      outerRRect,
      Paint()
        ..color = const Color(0xFFD4A017)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Gold inner trim line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        fullRect.deflate(5.5),
        const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0xFFD4A017).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ── Center felt area ──────────────────────────────────────────────────────

  void _drawCenterField(Canvas canvas) {
    const centerLeft   = _c;
    const centerTop    = _c;
    const centerW      = _unit - _c * 2;
    const centerH      = _unit - _c * 2;
    const centerRect   = Rect.fromLTWH(centerLeft, centerTop, centerW, centerH);
    const cx = _unit / 2;
    const cy = _unit / 2;

    // Felt gradient
    canvas.drawRect(
      centerRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.75,
          colors: [Color(0xFF1E5433), Color(0xFF0D2E1B)],
        ).createShader(centerRect),
    );

    // Subtle concentric decorative rings
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var r in [55.0, 100.0, 145.0, 185.0]) {
      canvas.drawCircle(const Offset(cx, cy), r, ringPaint);
    }

    // Game logo text
    _drawLabel(canvas, '🏰', const Offset(cx, cy - 34), 48, Colors.white);
    _drawLabel(canvas, 'MARBLE', const Offset(cx, cy + 22), 26,
      const Color(0xFFD4A017), weight: FontWeight.w900);
    _drawLabel(canvas, 'SECRET BASE', const Offset(cx, cy + 44), 10,
      const Color(0xFF5AAA72));
  }

  // ── All perimeter tiles ───────────────────────────────────────────────────

  void _drawAllTiles(Canvas canvas) {
    for (int pos = 0; pos < 24; pos++) {
      final tile = kTileByPos[pos];
      if (tile == null) continue;
      final rect = marbleTileRect(pos);
      if (rect == null) continue;

      if (_isCorner(pos)) {
        _drawCorner(canvas, pos, rect, tile);
      } else {
        _drawSideTile(canvas, pos, rect, tile);
      }
    }
  }

  bool _isCorner(int pos) => pos == 0 || pos == 6 || pos == 12 || pos == 18;

  // Which perimeter side this pos belongs to (non-corners only).
  // 0=bottom, 1=right, 2=top, 3=left
  int _sideOf(int pos) {
    if (pos >= 1  && pos <= 5)  return 0;
    if (pos >= 7  && pos <= 11) return 1;
    if (pos >= 13 && pos <= 17) return 2;
    return 3; // 19–23
  }

  // ── Corner tiles ─────────────────────────────────────────────────────────

  void _drawCorner(Canvas canvas, int pos, Rect rect, MarbleTile tile) {
    // Gradient background per corner personality
    final List<Color> grad;
    switch (pos) {
      case 0:  grad = [const Color(0xFF236B2C), const Color(0xFF0E3515)]; break; // START green
      case 6:  grad = [const Color(0xFF252545), const Color(0xFF10102A)]; break; // JAIL navy
      case 12: grad = [const Color(0xFF113560), const Color(0xFF061A35)]; break; // TAX blue
      case 18: grad = [const Color(0xFF0E4040), const Color(0xFF062020)]; break; // GATE teal
      default: grad = [const Color(0xFF1A1A2E), const Color(0xFF0D0D17)];
    }
    canvas.drawRect(rect,
      Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad,
      ).createShader(rect));

    // Diagonal color accent stripe in corner
    final accentPath = Path();
    const stripeSize = 28.0;
    switch (pos) {
      case 0: // bottom-left
        accentPath
          ..moveTo(rect.left, rect.bottom)
          ..lineTo(rect.left + stripeSize, rect.bottom)
          ..lineTo(rect.left, rect.bottom - stripeSize)
          ..close();
        break;
      case 6: // bottom-right
        accentPath
          ..moveTo(rect.right, rect.bottom)
          ..lineTo(rect.right - stripeSize, rect.bottom)
          ..lineTo(rect.right, rect.bottom - stripeSize)
          ..close();
        break;
      case 12: // top-right
        accentPath
          ..moveTo(rect.right, rect.top)
          ..lineTo(rect.right - stripeSize, rect.top)
          ..lineTo(rect.right, rect.top + stripeSize)
          ..close();
        break;
      case 18: // top-left
        accentPath
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.left + stripeSize, rect.top)
          ..lineTo(rect.left, rect.top + stripeSize)
          ..close();
        break;
    }
    canvas.drawPath(accentPath, Paint()..color = tile.color.withValues(alpha: 0.85));

    // Colored border
    canvas.drawRect(rect,
      Paint()
        ..color = tile.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);

    final ctr = rect.center;
    _drawLabel(canvas, tile.emoji, ctr.translate(0, -12), 26, Colors.white);
    _drawLabel(canvas, tile.name, ctr.translate(0, 14), 10, Colors.white,
      weight: FontWeight.w800);
  }

  // ── Side property / special tiles ────────────────────────────────────────

  void _drawSideTile(Canvas canvas, int pos, Rect rect, MarbleTile tile) {
    final side = _sideOf(pos);
    final isCard = tile.type == MarbleTileType.card;
    final isTax  = tile.type == MarbleTileType.tax;

    // ── Background ──
    if (isCard) {
      canvas.drawRect(rect,
        Paint()..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFF0A2448), const Color(0xFF051428)],
        ).createShader(rect));
    } else if (isTax) {
      canvas.drawRect(rect,
        Paint()..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFF252525), const Color(0xFF151515)],
        ).createShader(rect));
    } else {
      // Property — cream/white
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF5F2EA));

      // Color band on inner edge
      final bandRect = _bandRectFor(rect, side);
      canvas.drawRect(bandRect,
        Paint()..shader = LinearGradient(
          begin: side == 0 || side == 2
              ? Alignment.centerLeft : Alignment.topCenter,
          end:   side == 0 || side == 2
              ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [tile.color, tile.color.withValues(alpha: 0.7)],
        ).createShader(bandRect));

      // Small shine on band
      canvas.drawRect(bandRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..blendMode = BlendMode.srcOver);
    }

    // ── Tile border ──
    canvas.drawRect(rect,
      Paint()
        ..color = const Color(0xFF888888).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6);

    // ── Content ──
    final ctr = rect.center;
    if (isCard) {
      _drawLabel(canvas, '🃏', ctr.translate(0, -7), 20, Colors.white);
      _drawLabel(canvas, '황금열쇠', ctr.translate(0, 11), 6,
        const Color(0xFF7EC8FF), weight: FontWeight.w700);
    } else if (isTax) {
      _drawLabel(canvas, '⚖️', ctr.translate(0, -7), 20, Colors.white);
      _drawLabel(canvas, '세금', ctr.translate(0, 11), 6,
        Colors.white70, weight: FontWeight.w700);
    } else if (side == 1 || side == 3) {
      // Vertical sides — rotate content
      final angle = (side == 1) ? -pi / 2 : pi / 2;
      canvas.save();
      canvas.translate(ctr.dx, ctr.dy);
      canvas.rotate(angle);
      _drawLabel(canvas, tile.emoji, const Offset(0, -8), 15, Colors.black87);
      _drawLabel(canvas, tile.name, const Offset(0, 9), 7.5,
        const Color(0xFF1A1A1A), weight: FontWeight.w700);
      if (tile.price > 0) {
        _drawLabel(canvas, '${tile.price}만', const Offset(0, 19), 6.5,
          const Color(0xFF555555));
      }
      canvas.restore();
    } else {
      // Horizontal tiles (top/bottom)
      final contentCy = side == 0
          ? ctr.dy + _bandW * 0.5
          : ctr.dy - _bandW * 0.5;
      _drawLabel(canvas, tile.emoji, Offset(ctr.dx, contentCy - 8), 15, Colors.black87);
      _drawLabel(canvas, tile.name, Offset(ctr.dx, contentCy + 8), 7.5,
        const Color(0xFF1A1A1A), weight: FontWeight.w700);
      if (tile.price > 0) {
        _drawLabel(canvas, '${tile.price}만', Offset(ctr.dx, contentCy + 18), 6.5,
          const Color(0xFF555555));
      }
    }
  }

  // Returns the color-band Rect for a given tile and its side.
  // The band sits on the INNER edge (toward the center).
  Rect _bandRectFor(Rect r, int side) {
    switch (side) {
      case 0: return Rect.fromLTWH(r.left, r.top,          r.width,  _bandW); // bottom→band at top
      case 1: return Rect.fromLTWH(r.left, r.top,          _bandW,   r.height); // right→band at left
      case 2: return Rect.fromLTWH(r.left, r.bottom - _bandW, r.width, _bandW); // top→band at bottom
      case 3: return Rect.fromLTWH(r.right - _bandW, r.top, _bandW,  r.height); // left→band at right
      default: return Rect.fromLTWH(r.left, r.top, r.width, _bandW);
    }
  }

  // ── Ownership overlays ────────────────────────────────────────────────────

  void _drawOwnershipOverlays(Canvas canvas) {
    for (int pos = 0; pos < 24; pos++) {
      final posStr = '$pos';
      final land = landData[posStr];
      if (land is! Map) continue;
      final owner = land['owner'] as String?;
      final level = (land['level'] as num?)?.toInt() ?? 1;
      if (owner == null) continue;

      final rect = marbleTileRect(pos);
      if (rect == null) continue;

      final ownerColor = (owner == p1UserId) ? _p1Color : _p2Color;

      // Color tint
      canvas.drawRect(rect.deflate(1),
        Paint()..color = ownerColor.withValues(alpha: 0.15));

      // Bold ownership border
      canvas.drawRect(rect.deflate(0.5),
        Paint()
          ..color = ownerColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0);

      _drawOwnerBadge(canvas, rect, ownerColor,
          owner == p1UserId ? '1' : owner == p2UserId ? '2' : '?');
      _drawPropertyStructure(canvas, rect, level, ownerColor);
    }
  }

  void _drawOwnerBadge(Canvas canvas, Rect rect, Color color, String label) {
    final center = Offset(rect.left + 11, rect.top + 11);
    canvas.drawCircle(center, 9, Paint()..color = color);
    canvas.drawCircle(center, 9, Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    _drawLabel(canvas, label, center, 9, Colors.white, weight: FontWeight.w900);
  }

  // Draw vector markers instead of emoji: Canvas emoji rendering differs by
  // platform and made owned buildings effectively invisible on some devices.
  void _drawPropertyStructure(Canvas canvas, Rect rect, int level, Color color) {
    final center = Offset(rect.right - 13, rect.top + 13);
    final fill = Paint()..color = color;
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (level <= 1) {
      canvas.drawLine(center.translate(-5, 7), center.translate(-5, -7), outline);
      final flag = Path()
        ..moveTo(center.dx - 5, center.dy - 7)
        ..lineTo(center.dx + 6, center.dy - 3)
        ..lineTo(center.dx - 5, center.dy + 1)
        ..close();
      canvas.drawPath(flag, fill);
      canvas.drawPath(flag, outline);
    } else if (level == 2) {
      final house = Path()
        ..moveTo(center.dx - 9, center.dy - 1)
        ..lineTo(center.dx, center.dy - 9)
        ..lineTo(center.dx + 9, center.dy - 1)
        ..lineTo(center.dx + 7, center.dy - 1)
        ..lineTo(center.dx + 7, center.dy + 8)
        ..lineTo(center.dx - 7, center.dy + 8)
        ..lineTo(center.dx - 7, center.dy - 1)
        ..close();
      canvas.drawPath(house, fill);
      canvas.drawPath(house, outline);
    } else if (level == 3) {
      final building = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(0, 1), width: 15, height: 19),
          const Radius.circular(2));
      canvas.drawRRect(building, fill);
      canvas.drawRRect(building, outline);
      final window = Paint()..color = Colors.white.withValues(alpha: 0.85);
      for (final y in [-5.0, 1.0, 7.0]) {
        canvas.drawRect(Rect.fromLTWH(center.dx - 4, center.dy + y, 3, 3), window);
        canvas.drawRect(Rect.fromLTWH(center.dx + 1, center.dy + y, 3, 3), window);
      }
    } else {
      final tower = Path()
        ..moveTo(center.dx, center.dy - 11)
        ..lineTo(center.dx + 7, center.dy + 8)
        ..lineTo(center.dx - 7, center.dy + 8)
        ..close();
      canvas.drawPath(tower, fill);
      canvas.drawPath(tower, outline);
      canvas.drawCircle(center.translate(0, -12), 3, fill);
      canvas.drawCircle(center.translate(0, -12), 3, outline);
    }
  }

  // ── Text helper ───────────────────────────────────────────────────────────

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MarbleBoardPainter old) =>
      old.landData != landData ||
      old.p1UserId != p1UserId ||
      old.p2UserId != p2UserId;
}

class _DiceRollButton extends StatefulWidget {
  final bool enabled;
  final bool loading;
  final bool compact;
  final VoidCallback onTap;

  const _DiceRollButton({
    required this.enabled,
    required this.loading,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_DiceRollButton> createState() => _DiceRollButtonState();
}

class _DiceRollButtonState extends State<_DiceRollButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.enabled && !widget.loading) _pressCtrl.forward();
  }

  void _onTapUp(_) {
    _pressCtrl.reverse();
    if (widget.enabled && !widget.loading) widget.onTap();
  }

  void _onTapCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 70.0 : 80.0;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '주사위 굴리기',
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.enabled && !widget.loading
                  ? const RadialGradient(
                      colors: [Color(0xFFFF5E7E), Color(0xFFE91E63), Color(0xFFC2185B)],
                      center: Alignment(-0.3, -0.4),
                    )
                  : null,
              color: widget.enabled
                  ? null
                  : Colors.white.withValues(alpha: 0.1),
              boxShadow: widget.enabled && !widget.loading
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: widget.compact ? 26 : 30,
                            height: widget.compact ? 26 : 30,
                            child: CustomPaint(
                              painter: _DieFacePainter(
                                value: 6,
                                faceColor: Colors.white.withValues(alpha: 0.18),
                                dotColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ROLL',
                            style: GoogleFonts.notoSans(
                              color: widget.enabled ? Colors.white : Colors.white30,
                              fontSize: widget.compact ? 11 : 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterToken extends StatelessWidget {
  final String character;
  final Color color;
  final bool selected;
  final int? count;
  final String pieceSkin;

  const _CharacterToken({
    required this.character,
    required this.color,
    this.selected = false,
    this.count,
    this.pieceSkin = 'base',
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CharacterTokenPainter(
        character: character,
        color: color,
        selected: selected,
        pieceSkin: pieceSkin,
      ),
      child: count == null
          ? const SizedBox.expand()
          : Align(
              alignment: Alignment.bottomRight,
              child: Container(
                height: 17,
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2117),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  'x$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CharacterTokenPainter extends CustomPainter {
  final String character;
  final Color color;
  final bool selected;
  final String pieceSkin;

  const _CharacterTokenPainter({
    required this.character,
    required this.color,
    required this.selected,
    this.pieceSkin = 'base',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final tokenR = radius * 0.82;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center.translate(1.5, 2), tokenR, shadow);

    canvas.drawCircle(center, tokenR, Paint()..color = color);
    canvas.drawCircle(
      center,
      tokenR,
      Paint()
        ..color = selected ? const Color(0xFFFFE66B) : Colors.white
        ..strokeWidth = selected ? 3 : 1.5
        ..style = PaintingStyle.stroke,
    );

    // Face in upper portion, body in lower portion
    final faceR = radius * 0.38;
    final faceCenter = center.translate(0, -radius * 0.18);
    final bodyCenter = center.translate(0, radius * 0.32);

    if (pieceSkin != 'base') {
      _drawSkinEmoji(canvas, center, radius);
    } else {
      switch (character) {
        case 'nolbu':
          _drawNolbu(canvas, radius, faceCenter, faceR, bodyCenter);
        case 'miho':
          _drawMiho(canvas, radius, faceCenter, faceR, bodyCenter);
        case 'k' ||
              'ria' ||
              'luna' ||
              'rex' ||
              'zia' ||
              'drv' ||
              'hayun' ||
              'jake' ||
              'nova' ||
              'omega':
          _drawSpyAgent(canvas, radius, faceCenter, faceR, bodyCenter, character);
        default:
          _drawHong(canvas, radius, faceCenter, faceR, bodyCenter);
      }
    }
  }

  void _drawSkinEmoji(Canvas canvas, Offset center, double radius) {
    // 레거시 skin ID 매핑 + 신규 아이템은 icon 이모지 직접 사용
    final emoji = switch (pieceSkin) {
      'animal' => '🐾',
      'food' => '🍡',
      'star' => '⭐',
      'crown' => '👑',
      'couple' => '💑',
      'base' || '' => '✨',
      _ => pieceSkin, // 신규 아이템: icon 이모지 그대로
    };
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: radius * 0.95),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawFace(Canvas canvas, Offset faceCenter, double faceR, Color skin) {
    canvas.drawCircle(faceCenter, faceR, Paint()..color = skin);
    final eye = Paint()..color = const Color(0xFF2B2117);
    canvas.drawCircle(
      faceCenter.translate(-faceR * 0.38, -faceR * 0.08),
      faceR * 0.12,
      eye,
    );
    canvas.drawCircle(
      faceCenter.translate(faceR * 0.38, -faceR * 0.08),
      faceR * 0.12,
      eye,
    );
    final smile = Paint()
      ..color = const Color(0xFF7B2B22)
      ..strokeWidth = faceR * 0.1
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: faceCenter.translate(0, faceR * 0.2),
        width: faceR * 0.7,
        height: faceR * 0.44,
      ),
      0.15,
      pi - 0.3,
      false,
      smile,
    );
  }

  void _drawHong(
    Canvas canvas,
    double radius,
    Offset faceCenter,
    double faceR,
    Offset bodyCenter,
  ) {
    // Hat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: faceCenter.translate(0, -(faceR + radius * 0.11)),
          width: faceR * 1.6,
          height: radius * 0.20,
        ),
        Radius.circular(radius * 0.10),
      ),
      Paint()..color = const Color(0xFF1F6F54),
    );
    // Face
    _drawFace(canvas, faceCenter, faceR, const Color(0xFFFFD7A8));
    // Body (green robe)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter,
          width: faceR * 1.6,
          height: radius * 0.40,
        ),
        Radius.circular(radius * 0.08),
      ),
      Paint()..color = const Color(0xFF1F6F54),
    );
    // Sword
    canvas.drawLine(
      bodyCenter.translate(faceR * 0.66, -radius * 0.14),
      bodyCenter.translate(faceR * 0.66, radius * 0.20),
      Paint()
        ..color = const Color(0xFFECE7D7)
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawNolbu(
    Canvas canvas,
    double radius,
    Offset faceCenter,
    double faceR,
    Offset bodyCenter,
  ) {
    // Hat
    canvas.drawOval(
      Rect.fromCenter(
        center: faceCenter.translate(0, -(faceR + radius * 0.10)),
        width: faceR * 1.7,
        height: radius * 0.24,
      ),
      Paint()..color = const Color(0xFF4D2E83),
    );
    // Face
    _drawFace(canvas, faceCenter, faceR, const Color(0xFFFFC98B));
    // Body (purple robe — wide to show greed)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter,
          width: faceR * 1.85,
          height: radius * 0.40,
        ),
        Radius.circular(radius * 0.08),
      ),
      Paint()..color = const Color(0xFF4D2E83),
    );
    // Gold coin
    final coinCenter = bodyCenter.translate(faceR * 0.52, 0);
    canvas.drawCircle(
      coinCenter,
      faceR * 0.28,
      Paint()..color = const Color(0xFFFFCF45),
    );
    canvas.drawCircle(
      coinCenter,
      faceR * 0.28,
      Paint()
        ..color = const Color(0xFFA86A10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.025,
    );
  }

  void _drawMiho(
    Canvas canvas,
    double radius,
    Offset faceCenter,
    double faceR,
    Offset bodyCenter,
  ) {
    // Fox ears (above face)
    final ear = Paint()..color = const Color(0xFFF28B35);
    final innerEar = Paint()..color = const Color(0xFFFFD7D0);
    canvas.drawPath(
      Path()
        ..moveTo(faceCenter.dx - faceR * 0.6, faceCenter.dy - faceR * 0.2)
        ..lineTo(faceCenter.dx - faceR * 0.3, faceCenter.dy - faceR * 1.1)
        ..lineTo(faceCenter.dx + faceR * 0.1, faceCenter.dy - faceR * 0.3)
        ..close(),
      ear,
    );
    canvas.drawPath(
      Path()
        ..moveTo(faceCenter.dx - faceR * 0.48, faceCenter.dy - faceR * 0.28)
        ..lineTo(faceCenter.dx - faceR * 0.3, faceCenter.dy - faceR * 0.78)
        ..lineTo(faceCenter.dx + faceR * 0.02, faceCenter.dy - faceR * 0.34)
        ..close(),
      innerEar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(faceCenter.dx + faceR * 0.6, faceCenter.dy - faceR * 0.2)
        ..lineTo(faceCenter.dx + faceR * 0.3, faceCenter.dy - faceR * 1.1)
        ..lineTo(faceCenter.dx - faceR * 0.1, faceCenter.dy - faceR * 0.3)
        ..close(),
      ear,
    );
    canvas.drawPath(
      Path()
        ..moveTo(faceCenter.dx + faceR * 0.48, faceCenter.dy - faceR * 0.28)
        ..lineTo(faceCenter.dx + faceR * 0.3, faceCenter.dy - faceR * 0.78)
        ..lineTo(faceCenter.dx - faceR * 0.02, faceCenter.dy - faceR * 0.34)
        ..close(),
      innerEar,
    );
    // Face
    _drawFace(canvas, faceCenter, faceR, const Color(0xFFFFD2A3));
    // Nose
    canvas.drawCircle(
      faceCenter.translate(0, faceR * 0.16),
      faceR * 0.1,
      Paint()..color = const Color(0xFF4B2B20),
    );
    // Body (orange fox body)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter,
          width: faceR * 1.5,
          height: radius * 0.40,
        ),
        Radius.circular(radius * 0.10),
      ),
      Paint()..color = const Color(0xFFF28B35),
    );
  }

  void _drawSpyAgent(
    Canvas canvas,
    double radius,
    Offset faceCenter,
    double faceR,
    Offset bodyCenter,
    String id,
  ) {
    final charDef = marbleCharById(id);
    final skin = charDef?.skinColor ?? const Color(0xFF505060);
    final hair = charDef?.hairColor ?? const Color(0xFF050810);
    final outfit = charDef?.outfitColor ?? const Color(0xFF080C10);
    final symbol = charDef?.initial ?? '?';
    final isOmega = id == 'omega';

    // Hair / hood (drawn before face)
    if (isOmega) {
      // Full dark hood
      canvas.drawCircle(
        faceCenter.translate(0, -faceR * 0.1),
        faceR * 1.1,
        Paint()..color = hair,
      );
    } else {
      // Hair cap arc above face
      canvas.drawArc(
        Rect.fromCenter(
          center: faceCenter.translate(0, faceR * 0.1),
          width: faceR * 2.2,
          height: faceR * 2.2,
        ),
        pi,
        pi,
        false,
        Paint()..color = hair,
      );
    }

    // Face
    if (!isOmega) {
      _drawFace(canvas, faceCenter, faceR, skin);
    } else {
      // Masked face — dark with glowing green eyes
      canvas.drawCircle(faceCenter, faceR, Paint()..color = const Color(0xFF101418));
      final glow = Paint()..color = const Color(0xFF00FF88);
      canvas.drawCircle(
        faceCenter.translate(-faceR * 0.32, -faceR * 0.08),
        faceR * 0.14,
        glow,
      );
      canvas.drawCircle(
        faceCenter.translate(faceR * 0.32, -faceR * 0.08),
        faceR * 0.14,
        glow,
      );
    }

    // Body (suit)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: bodyCenter,
          width: faceR * 1.6,
          height: radius * 0.40,
        ),
        Radius.circular(radius * 0.08),
      ),
      Paint()..color = outfit,
    );

    // Symbol letter on body
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: faceR * 0.72,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      bodyCenter - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CharacterTokenPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.color != color ||
        oldDelegate.selected != selected ||
        oldDelegate.pieceSkin != pieceSkin;
  }
}

// ─── Chat preview bubble ─────────────────────────────────────────────────────

class _ChatPreviewBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final String Function(String) displayName;
  final VoidCallback onDismiss;

  const _ChatPreviewBubble({
    required this.message,
    required this.displayName,
    required this.onDismiss,
  });

  @override
  State<_ChatPreviewBubble> createState() => _ChatPreviewBubbleState();
}

class _ChatPreviewBubbleState extends State<_ChatPreviewBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final by = widget.message['by'] as String? ?? '';
    final text = widget.message['message'] as String? ?? '';
    final name = widget.displayName(by);

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xEE1E2530),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: Color(0xFF79C8C4), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$name: ',
                        style: const TextStyle(
                          color: Color(0xFF79C8C4),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: text,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dice Roll Animation ────────────────────────────────────────────────────

class _DiceRollOverlay extends StatefulWidget {
  final Animation<double> animation;
  final Map<String, dynamic>? roll;

  const _DiceRollOverlay({required this.animation, this.roll});

  @override
  State<_DiceRollOverlay> createState() => _DiceRollOverlayState();
}

class _DiceRollOverlayState extends State<_DiceRollOverlay> {
  int _face1 = 3;
  int _face2 = 5;
  Timer? _timer;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 55), _tick);
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final t = widget.animation.value;
    if (t >= 0.88 && widget.roll != null) {
      _timer?.cancel();
      final roll = widget.roll!;
      setState(() {
        _face1 = (roll['dice1'] as int? ?? 1).clamp(1, 6);
        _face2 = (roll['dice2'] as int? ?? 1).clamp(1, 6);
      });
    } else if (t < 0.88) {
      setState(() {
        _face1 = _rng.nextInt(6) + 1;
        _face2 = _rng.nextInt(6) + 1;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context2, _) {
        final t = widget.animation.value;
        final revealed = t >= 0.88 && widget.roll != null;

        return Container(
          color: Colors.black.withValues(alpha: (t * 0.88).clamp(0.0, 0.88)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Die3D(t: t, face: _face1, delay: 0.0),
                    const SizedBox(width: 22),
                    _Die3D(t: t, face: _face2, delay: 0.06),
                  ],
                ),
                if (revealed) ...[
                  const SizedBox(height: 28),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 480),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) => Transform.scale(scale: v, child: child),
                    child: _buildResult(widget.roll!),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(Map<String, dynamic> roll) {
    const faceStr = ['', '⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    final dice1   = (roll['dice1'] as int? ?? 1).clamp(1, 6);
    final dice2   = (roll['dice2'] as int? ?? 1).clamp(1, 6);
    final total   = roll['total'] as int? ?? 0;
    final isDouble = roll['isDouble'] as bool? ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${faceStr[dice1]} + ${faceStr[dice2]} = $total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
        if (isDouble) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Text(
              '🎯 더블! 한 번 더!',
              style: TextStyle(
                color: Color(0xFF4A2512),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 3D rotating die widget ────────────────────────────────────────────────────

class _Die3D extends StatefulWidget {
  final double t;
  final int face;
  final double delay;

  const _Die3D({required this.t, required this.face, this.delay = 0.0});

  @override
  State<_Die3D> createState() => _Die3DState();
}

class _Die3DState extends State<_Die3D> {
  double _rx = 0.3;
  double _ry = 0.5;
  Timer? _rotTimer;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _rx = rng.nextDouble() * pi;
    _ry = rng.nextDouble() * pi;
    _rotTimer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _tick(Timer _) {
    if (!mounted) return;
    final tLocal = (widget.t - widget.delay).clamp(0.0, 1.0);
    if (tLocal >= 0.88) {
      _rotTimer?.cancel();
      return;
    }
    final progress = tLocal / 0.88;
    // Start fast (~0.25 rad/frame), ease out to near zero by t=0.88
    final speed = (1.0 - progress * progress) * 0.28;
    setState(() {
      _rx += speed;
      _ry += speed * 1.35; // slightly different axis for tumble effect
    });
  }

  @override
  void dispose() {
    _rotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tLocal = (widget.t - widget.delay).clamp(0.0, 1.0);
    final double bounceScale;
    if (tLocal < 0.88) {
      bounceScale = 1.0;
    } else {
      final landT = ((tLocal - 0.88) / 0.12).clamp(0.0, 1.0);
      bounceScale = 1.0 + sin(landT * pi) * 0.13;
    }

    return Transform.scale(
      scale: bounceScale,
      child: SizedBox(
        width: 88,
        height: 88,
        child: CustomPaint(
          painter: _Dice3DPainter(face: widget.face.clamp(1, 6), rx: _rx, ry: _ry),
        ),
      ),
    );
  }
}

// ── Full 3D die CustomPainter ─────────────────────────────────────────────────

class _Dice3DPainter extends CustomPainter {
  final int face;
  final double rx;
  final double ry;

  const _Dice3DPainter({required this.face, this.rx = 0, this.ry = 0});

  static const _baseColor = Color(0xFFCC2525);
  static const _edgeColor = Color(0xFF3A0000);

  // 8 vertices of unit cube
  static const _vx = [-1.0, 1.0, 1.0,-1.0,-1.0, 1.0, 1.0,-1.0];
  static const _vy = [-1.0,-1.0, 1.0, 1.0,-1.0,-1.0, 1.0, 1.0];
  static const _vz = [-1.0,-1.0,-1.0,-1.0, 1.0, 1.0, 1.0, 1.0];

  // Face defs: [vertex indices CCW from outside], face value
  // Standard die: 1↔6, 2↔5, 3↔4; 1 on top (+z), 2 faces camera (+y), 3 on right (+x)
  static const _fi = [[4,5,6,7],[3,2,1,0],[7,6,2,3],[0,1,5,4],[1,2,6,5],[4,7,3,0]];
  static const _fv = [1, 6, 2, 5, 3, 4]; // face values
  // Face normals (local space)
  static const _nx = [0.0, 0.0, 0.0, 0.0, 1.0,-1.0];
  static const _ny = [0.0, 0.0, 1.0,-1.0, 0.0, 0.0];
  static const _nz = [1.0,-1.0, 0.0, 0.0, 0.0, 0.0];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final scale = size.width * 0.30;
    const fov = 4.5;

    final cosX = cos(rx), sinX = sin(rx);
    final cosY = cos(ry), sinY = sin(ry);

    // Rotate Y then X
    (double, double, double) rot(double x, double y, double z) {
      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      final y2 = y * cosX - z1 * sinX;
      final z2 = y * sinX + z1 * cosX;
      return (x1, y2, z2);
    }

    Offset proj(double x, double y, double z) {
      final pz = z + fov;
      final f = fov / (pz < 0.01 ? 0.01 : pz);
      return Offset(cx + x * scale * f, cy - y * scale * f);
    }

    // Rotate all vertices
    final rvx = List<double>.filled(8, 0);
    final rvy = List<double>.filled(8, 0);
    final rvz = List<double>.filled(8, 0);
    for (var i = 0; i < 8; i++) {
      final r = rot(_vx[i], _vy[i], _vz[i]);
      rvx[i] = r.$1; rvy[i] = r.$2; rvz[i] = r.$3;
    }

    // Collect visible faces sorted back-to-front
    final visible = <(int, double)>[];
    for (var fi = 0; fi < 6; fi++) {
      final rn = rot(_nx[fi], _ny[fi], _nz[fi]);
      if (rn.$3 <= 0) continue; // backface cull
      final vIdx = _fi[fi];
      final avgZ = (rvz[vIdx[0]] + rvz[vIdx[1]] + rvz[vIdx[2]] + rvz[vIdx[3]]) / 4;
      visible.add((fi, avgZ));
    }
    visible.sort((a, b) => a.$2.compareTo(b.$2));

    for (final (fi, _) in visible) {
      final rn = rot(_nx[fi], _ny[fi], _nz[fi]);
      final bright = (0.35 + 0.65 * rn.$3.clamp(0.0, 1.0));
      final c = Color.fromARGB(
        255,
        ((_baseColor.r * 255.0).round() * bright).round().clamp(0, 255),
        ((_baseColor.g * 255.0).round() * bright).round().clamp(0, 255),
        ((_baseColor.b * 255.0).round() * bright).round().clamp(0, 255),
      );
      final vIdx = _fi[fi];
      final pts = vIdx.map((i) => proj(rvx[i], rvy[i], rvz[i])).toList();

      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      path.close();
      canvas.drawPath(path, Paint()..color = c);
      canvas.drawPath(path, Paint()
        ..color = _edgeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round);

      _drawDots(canvas, pts, _fv[fi]);
    }
  }

  void _drawDots(Canvas canvas, List<Offset> pts, int v) {
    // Face center
    final center = Offset(
      (pts[0].dx + pts[1].dx + pts[2].dx + pts[3].dx) / 4,
      (pts[0].dy + pts[1].dy + pts[2].dy + pts[3].dy) / 4,
    );
    // U: right axis, V: up axis in screen space (from center to mid-edges)
    final midRight = (pts[0] + pts[1]) / 2;
    final midTop   = (pts[0] + pts[3]) / 2;
    final hU = midRight - center;
    final hV = midTop   - center;

    Offset dp(double u, double v) =>
        Offset(center.dx + u * hU.dx + v * hV.dx, center.dy + u * hU.dy + v * hV.dy);

    final r = sqrt(hU.dx * hU.dx + hU.dy * hU.dy) * 0.18;

    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.25);
    final dot    = Paint()..color = Colors.white;

    for (final pos in _dotPositions(v)) {
      final p = dp(pos.dx, pos.dy);
      canvas.drawCircle(Offset(p.dx + 0.5, p.dy + 0.5), r, shadow);
      canvas.drawCircle(p, r, dot);
    }
  }

  List<Offset> _dotPositions(int v) {
    const s = 0.58;
    switch (v) {
      case 1: return const [Offset(0, 0)];
      case 2: return const [Offset(-s, -s), Offset(s, s)];
      case 3: return const [Offset(-s, -s), Offset(0, 0), Offset(s, s)];
      case 4: return const [Offset(-s, -s), Offset(s, -s), Offset(-s, s), Offset(s, s)];
      case 5: return const [Offset(-s, -s), Offset(s, -s), Offset(0, 0), Offset(-s, s), Offset(s, s)];
      case 6: return const [Offset(-s, -s), Offset(s, -s), Offset(-s, 0), Offset(s, 0), Offset(-s, s), Offset(s, s)];
      default: return const [];
    }
  }

  @override
  bool shouldRepaint(_Dice3DPainter old) =>
      old.face != face || old.rx != rx || old.ry != ry;
}

// ── Flat 2D die face painter (액션바 주사위 결과 표시용) ──────────────────────

class _DieFacePainter extends CustomPainter {
  final int value;
  final Color faceColor;
  final Color dotColor;

  const _DieFacePainter({
    required this.value,
    this.faceColor = const Color(0xFF1E2733),
    this.dotColor = const Color(0xFFFFD700),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = Offset(r, r);
    final rr = r * 0.88;

    // 배경 다크 라운드 사각형
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCircle(center: center, radius: rr), Radius.circular(rr * 0.32)),
      Paint()..color = faceColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCircle(center: center, radius: rr), Radius.circular(rr * 0.32)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 점 그리기
    final dotR = rr * 0.18;
    final s = rr * 0.52;
    final dots = _dotPositions(value.clamp(1, 6));
    final dotPaint = Paint()..color = dotColor;
    for (final d in dots) {
      canvas.drawCircle(center + d * s, dotR, dotPaint);
    }
  }

  List<Offset> _dotPositions(int v) => switch (v) {
    1 => const [Offset(0, 0)],
    2 => const [Offset(-1, -1), Offset(1, 1)],
    3 => const [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
    4 => const [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5 => const [Offset(-1, -1), Offset(1, -1), Offset(0, 0), Offset(-1, 1), Offset(1, 1)],
    _ => const [Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0), Offset(-1, 1), Offset(1, 1)],
  };

  @override
  bool shouldRepaint(_DieFacePainter old) => old.value != value;
}
