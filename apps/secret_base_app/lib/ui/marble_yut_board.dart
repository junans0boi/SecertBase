import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/socket_service.dart';
import '../core/yut_audio.dart';
import 'marble_map_data.dart';

String _defaultDisplayName(String uid) => uid;

class MarbleYutBoard extends StatefulWidget {
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

  const MarbleYutBoard({
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
    this.p1Character = 'honggilldong',
    this.p2Character = 'miho',
    this.p1UserId = '',
    this.p2UserId = '',
    this.displayName = _defaultDisplayName,
    this.pieceSkin = 'base',
    this.opponentPieceSkin = 'base',
    this.coins,
    this.landData = const {},
  });

  @override
  State<MarbleYutBoard> createState() => _MarbleYutBoardState();
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

class _MarbleYutBoardState extends State<MarbleYutBoard> with TickerProviderStateMixin {
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
    _syncCountdown();
  }

  @override
  void didUpdateWidget(MarbleYutBoard oldWidget) {
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
      if (mounted) setState(() => _countdownSeconds = nextSeconds);
      else _countdownSeconds = nextSeconds;
      if (nextSeconds <= 0) _countdownTimer?.cancel();
    }
    tick();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
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

  int _getNextPos(int currentPos, bool isFirstStep, int lastPos) {
    if (currentPos == 20) return 20;
    if (isFirstStep) {
      if (currentPos == 5) return 21;
      if (currentPos == 10) return 24;
      if (currentPos == 23) return 26;
    }

    switch (currentPos) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      case 5:
        return 6;
      case 6:
        return 7;
      case 7:
        return 8;
      case 8:
        return 9;
      case 9:
        return 10;
      case 10:
        return 11;
      case 11:
        return 12;
      case 12:
        return 13;
      case 13:
        return 14;
      case 14:
        return 15;
      case 15:
        return 16;
      case 16:
        return 17;
      case 17:
        return 18;
      case 18:
        return 19;
      case 19:
        return 20;
      case 21:
        return 22;
      case 22:
        return 23;
      case 24:
        return 25;
      case 25:
        return 23;
      case 23:
        return lastPos == 22 ? 28 : 26;
      case 26:
        return 27;
      case 27:
        return 20;
      case 28:
        return 29;
      case 29:
        return 15;
    }
    return 20;
  }

  int _getPrevPos(int currentPos, int lastPos) {
    switch (currentPos) {
      case 0:
        return 0;
      case 1:
        return 0;
      case 2:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      case 5:
        return 4;
      case 6:
        return 5;
      case 7:
        return 6;
      case 8:
        return 7;
      case 9:
        return 8;
      case 10:
        return 9;
      case 11:
        return 10;
      case 12:
        return 11;
      case 13:
        return 12;
      case 14:
        return 13;
      case 15:
        if (lastPos == 29) return 29;
        return 14;
      case 16:
        return 15;
      case 17:
        return 16;
      case 18:
        return 17;
      case 19:
        return 18;
      case 20:
        return lastPos == 0 ? 19 : lastPos;
      case 21:
        return 5;
      case 22:
        return 21;
      case 23:
        return (lastPos == 25 || lastPos == 24 || lastPos == 10) ? 25 : 22;
      case 24:
        return 10;
      case 25:
        return 24;
      case 26:
        return 23;
      case 27:
        return 26;
      case 28:
        return 23;
      case 29:
        return 28;
    }
    return 0;
  }

  int _getLastPos(dynamic p) {
    if (p is Map) return p['lastPos'] as int? ?? 0;
    return 0;
  }

  int _previewMove(dynamic piece, int steps) {
    var pos = _getPos(piece);
    var lastPos = _getLastPos(piece);
    if (_isFinished(piece)) return 20;
    if (steps == -1) return _getPrevPos(pos, lastPos);
    for (var i = 0; i < steps; i++) {
      if (pos == 20) return 20;
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
      _cPieceSize = 34.0;
      _cGuideSize = 48.0;
    } else {
      _cPieceSize = _pieceSize;
      _cGuideSize = _guideSize;
    }

    final isMyTurn = widget.turn == widget.currentUser;
    final opponent = widget.currentUser == widget.p1UserId
        ? widget.p2UserId
        : widget.p1UserId;
    final isP2 = widget.currentUser == widget.p2UserId;
    final isRollOrder = widget.phase == 'roll_order';
    final isOrderCountdown = widget.phase == 'order_countdown';
    final canThrow = isMyTurn && widget.phase == 'throwing';

    final myPieces = isP2 ? widget.p2Pieces : widget.p1Pieces;
    final opPieces = isP2 ? widget.p1Pieces : widget.p2Pieces;
    final myColor = isP2 ? const Color(0xFF4B8DD8) : const Color(0xFFE45858);
    final opColor = isP2 ? const Color(0xFFE45858) : const Color(0xFF4B8DD8);
    final myCharacter = isP2 ? widget.p2Character : widget.p1Character;
    final opCharacter = isP2 ? widget.p1Character : widget.p2Character;
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
                    screenWidth * 0.94,
                    stageHeight * (_compact ? 0.62 : 0.72),
                  );
                  final boardTop = stageHeight * (_compact ? 0.30 : 0.12);

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
                      // PLAYER 2 카드 (좌상단 오버레이)
                      Positioned(
                        top: _compact ? stageHeight * 0.105 : 20,
                        left: _compact ? 10 : 16,
                        width: screenWidth * (_compact ? 0.40 : 0.28),
                        child: _buildPlayerCard(
                          key: const ValueKey('yut_opponent_profile'),
                          userId: opponent,
                          color: opColor,
                          character: opCharacter,
                          pieces: opPieces,
                          isActiveTurn:
                              widget.turn == opponent && widget.phase != null,
                          isMe: false,
                          showPieceControls: false,
                          pieceSkin: widget.opponentPieceSkin,
                        ),
                      ),
                      // MY PROFILE 카드 (우하단 오버레이)
                      Positioned(
                        bottom: _compact ? 8 : 14,
                        right: _compact ? 10 : 16,
                        width: screenWidth * (_compact ? 0.68 : 0.47),
                        child: _buildPlayerCard(
                          key: const ValueKey('yut_my_profile'),
                          userId: widget.currentUser,
                          color: myColor,
                          character: myCharacter,
                          pieces: myPieces,
                          isActiveTurn: isMyTurn,
                          isMe: true,
                          showPieceControls: true,
                          onPieceTap: _selectPiece,
                          pieceSkin: widget.pieceSkin,
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
      ],
    );
  }

  Widget _buildPlayerCard({
    Key? key,
    required String userId,
    required Color color,
    required String character,
    required List<dynamic>? pieces,
    required bool isActiveTurn,
    required bool isMe,
    required bool showPieceControls,
    void Function(int)? onPieceTap,
    String pieceSkin = 'base',
  }) {
    final safePieces = pieces ?? List.generate(4, (_) => 0);
    final borderColor = isActiveTurn
        ? const Color(0xFFA7D8D1)
        : const Color(0x66FFFFFF);
    const bgGrad = LinearGradient(
      colors: [Color(0xA62B3440), Color(0x99202731)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final profileKeyPrefix = isMe ? 'yut_my_profile' : 'yut_opponent_profile';
    final cardHeight = _compact ? 96.0 : 104.0;
    final avatarSize = _compact ? 42.0 : 48.0;
    final pieceSize = _compact ? 36.0 : 40.0;
    final completedCount = safePieces.where(_isFinished).length;

    if (!showPieceControls) {
      final compactPieceSize = _compact ? 16.0 : 18.0;
      return SizedBox(
        height: _compact ? 62 : 68,
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: bgGrad,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              if (isActiveTurn)
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.38),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: _compact ? 30 : 34,
                height: _compact ? 30 : 34,
                child: _CharacterToken(
                  character: character,
                  color: color,
                  selected: isActiveTurn,
                  pieceSkin: pieceSkin,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _display(userId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${4 - completedCount}말 남음',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      children: safePieces.map((piece) {
                        final isFinished = _isFinished(piece);
                        return Padding(
                          padding: const EdgeInsets.only(left: 1),
                          child: SizedBox(
                            width: compactPieceSize,
                            height: compactPieceSize,
                            child: isFinished
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF9BEA85),
                                    size: 14,
                                  )
                                : Opacity(
                                    opacity: _getPos(piece) > 0 ? 0.45 : 1,
                                    child: _CharacterToken(
                                      character: character,
                                      color: color,
                                      pieceSkin: pieceSkin,
                                    ),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: cardHeight,
      child: Container(
        key: key,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: bgGrad,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (isActiveTurn)
              BoxShadow(
                color: borderColor.withValues(alpha: 0.55),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                SizedBox(
                  key: ValueKey('${profileKeyPrefix}_remaining'),
                  width: _compact ? 154 : 174,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMe ? '내 남은 말' : '상대 남은 말',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: safePieces.asMap().entries.map((entry) {
                          final pieceId = entry.key;
                          final pos = _getPos(entry.value);
                          final isFinished = _isFinished(entry.value);
                          final isOnBoard = pos > 0 && !isFinished;
                          final canTap = isMe && _canSelectPiece(pieceId);
                          final selected = isMe && _selectedPieceId == pieceId;

                          return GestureDetector(
                            onTap: canTap
                                ? () => onPieceTap?.call(pieceId)
                                : null,
                            child: AnimatedContainer(
                              key: ValueKey(
                                '${profileKeyPrefix}_piece_$pieceId',
                              ),
                              duration: const Duration(milliseconds: 200),
                              width: pieceSize,
                              height: pieceSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? Colors.amber.withValues(alpha: 0.35)
                                    : Colors.transparent,
                                border: selected
                                    ? Border.all(
                                        color: Colors.amber,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  if (isFinished)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF9BEA85),
                                      size: 18,
                                    )
                                  else
                                    Opacity(
                                      opacity: isOnBoard ? 0.35 : 1,
                                      child: SizedBox(
                                        width: pieceSize - 2,
                                        height: pieceSize - 2,
                                        child: _CharacterToken(
                                          character: character,
                                          color: color,
                                          selected: selected,
                                          pieceSkin: pieceSkin,
                                        ),
                                      ),
                                    ),
                                  if (isOnBoard && !isFinished)
                                    Positioned(
                                      bottom: -1,
                                      right: -1,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: color,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (!isOnBoard && !isFinished && canTap)
                                    Positioned(
                                      bottom: -1,
                                      right: -1,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        key: ValueKey('${profileKeyPrefix}_avatar'),
                        width: avatarSize,
                        height: avatarSize,
                        child: _CharacterToken(
                          character: character,
                          color: color,
                          selected: isActiveTurn,
                          pieceSkin: pieceSkin,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Column(
                        key: ValueKey('${profileKeyPrefix}_identity'),
                        children: [
                          const Text(
                            'Lv. -',
                            style: TextStyle(
                              color: Color(0xFFFFE27A),
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _display(userId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActiveTurn
                      ? const Color(0xFF52FF8A)
                      : Colors.white24,
                  boxShadow: isActiveTurn
                      ? const [
                          BoxShadow(color: Color(0xFF52FF8A), blurRadius: 6),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar({required bool canThrow}) {
    return Container(
      key: const ValueKey('yut_action_bar'),
      decoration: const BoxDecoration(
        color: Color(0xD90F1720),
        border: Border(top: BorderSide(color: Color(0x18FFFFFF), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _compact ? 10 : 14,
            10,
            _compact ? 10 : 14,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _actionPrompt(canThrow: canThrow),
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: _compact ? 12 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _DiceRollButton(
                enabled: canThrow,
                loading: _showDiceAnim,
                compact: _compact,
                onTap: _handleRoll,
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionBtn(
                    Icons.settings_outlined,
                    () => _showSettings(context),
                  ),
                  const SizedBox(width: 4),
                  _buildActionBtn(
                    Icons.chat_bubble_outline,
                    () => _showChat(context),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    _socket.sendYutChat(_messageController.text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _socket.yutChatMessages;
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

  // ── Drawing constants ────────────────────────────────────────────────────
  static const double _unit = 560.0;
  static const double _c = 80.0;

  static const _p1Color = Color(0xFFE45858);
  static const _p2Color = Color(0xFF4B8DD8);
  static const _centerBg = Color(0xFF22573E);
  static const _borderCol = Color(0xFF0D2B1E);
  static const _tileStroke = Color(0xFF0A2016);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _unit;
    canvas.save();
    canvas.scale(scale, scale);

    _drawBoard(canvas);

    canvas.restore();
  }

  void _drawBoard(Canvas canvas) {
    // 1. Outer board background
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _unit, _unit),
      const Radius.circular(12),
    );
    canvas.drawRRect(boardRect, Paint()..color = _borderCol);

    // 2. Center area
    const centerInset = _c + 2.0;
    const centerSize = _unit - centerInset * 2;
    canvas.drawRect(
      const Rect.fromLTWH(centerInset, centerInset, centerSize, centerSize),
      Paint()..color = _centerBg,
    );

    // 3. Diagonal shortcut lanes
    _drawDiagonals(canvas);

    // 4. Center node
    _drawCenterNode(canvas);

    // 5. All perimeter tiles
    for (int pos = 0; pos <= 19; pos++) {
      _drawPerimeterTile(canvas, pos);
    }

    // 6. Diagonal shortcut nodes
    for (final pos in [21, 22, 24, 25, 26, 27, 28, 29]) {
      _drawShortcutNode(canvas, pos);
    }
  }

  void _drawDiagonals(Canvas canvas) {
    // Diagonal A: pos 5 (520,520) → center (280,280) → pos 15 (40,40)
    final paintA = Paint()
      ..color = const Color(0x44705427)
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(520, 520),
      const Offset(40, 40),
      paintA,
    );

    // Diagonal B: pos 10 (520,40) → center (280,280) → pos 0 (40,520)
    final paintB = Paint()
      ..color = const Color(0x440A5272)
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(520, 40),
      const Offset(40, 520),
      paintB,
    );

    // Lane outlines (thinner)
    final outlineA = Paint()
      ..color = const Color(0x66B87A3A)
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.overlay;
    canvas.drawLine(const Offset(520, 520), const Offset(40, 40), outlineA);
    final outlineB = outlineA..color = const Color(0x661EB8EA);
    canvas.drawLine(const Offset(520, 40), const Offset(40, 520), outlineB);
  }

  void _drawCenterNode(Canvas canvas) {
    const center = Offset(280, 280);
    canvas.drawCircle(center, 28, Paint()..color = const Color(0xFF6B21A8));
    canvas.drawCircle(center, 26, Paint()..color = const Color(0xFF9333EA));
    canvas.drawCircle(
      center, 28,
      Paint()
        ..color = const Color(0xFFD8B4FE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _drawText(canvas, '🌐', center, 22, Colors.white);
    _drawText(canvas, '세계중심', center.translate(0, 18), 8, Colors.white70);
  }

  void _drawPerimeterTile(Canvas canvas, int pos) {
    final rect = marbleTileRect(pos);
    if (rect == null) return;
    final tile = kTileByPos[pos];
    final isCorner = (pos == 0 || pos == 5 || pos == 10 || pos == 15);

    // Base tile background
    final bgColor = isCorner
        ? _cornerBgColor(pos)
        : const Color(0xFFF0EFE6);
    canvas.drawRect(rect, Paint()..color = bgColor);

    // Tile border
    canvas.drawRect(
      rect,
      Paint()
        ..color = _tileStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    if (isCorner) {
      _drawCornerTile(canvas, pos, rect, tile);
    } else {
      _drawPropertyTile(canvas, pos, rect, tile);
    }

    // Ownership overlay
    _drawOwnership(canvas, pos, rect);
  }

  Color _cornerBgColor(int pos) {
    switch (pos) {
      case 0:  return const Color(0xFF1A3A0E); // start: dark green
      case 5:  return const Color(0xFF1A1A2E); // jail: dark navy
      case 10: return const Color(0xFF0D2B4A); // event: deep blue
      case 15: return const Color(0xFF0D3530); // free: dark teal
      default: return const Color(0xFF1A3A0E);
    }
  }

  void _drawCornerTile(Canvas canvas, int pos, Rect rect, MarbleTile? tile) {
    if (tile == null) return;
    final center = rect.center;
    final name = tile.name;
    final emoji = tile.emoji;

    // Color accent stripe
    final accentPaint = Paint()..color = tile.color.withValues(alpha: 0.9);
    if (pos == 0) {
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.bottom - 16, rect.right, rect.bottom), accentPaint);
    } else if (pos == 5) {
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + 16), accentPaint);
    } else if (pos == 10) {
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + 16), accentPaint);
    } else if (pos == 15) {
      canvas.drawRect(Rect.fromLTRB(rect.left, rect.bottom - 16, rect.right, rect.bottom), accentPaint);
    }

    _drawText(canvas, emoji, center.translate(0, -10), 22, Colors.white);
    _drawText(canvas, name, center.translate(0, 14), 9.5, Colors.white, fontWeight: FontWeight.w800);
  }

  void _drawPropertyTile(Canvas canvas, int pos, Rect rect, MarbleTile? tile) {
    if (tile == null) return;
    final center = rect.center;
    final color = tile.color;

    // Color band (inner edge of board)
    const bandW = 14.0;
    Rect band;
    bool isHoriz = (pos >= 1 && pos <= 4) || (pos >= 11 && pos <= 14);
    if (pos >= 1 && pos <= 4) {
      // bottom side: band at top (inner)
      band = Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + bandW);
    } else if (pos >= 6 && pos <= 9) {
      // right side: band at left (inner)
      band = Rect.fromLTRB(rect.left, rect.top, rect.left + bandW, rect.bottom);
    } else if (pos >= 11 && pos <= 14) {
      // top side: band at bottom (inner)
      band = Rect.fromLTRB(rect.left, rect.bottom - bandW, rect.right, rect.bottom);
    } else {
      // left side: band at right (inner)
      band = Rect.fromLTRB(rect.right - bandW, rect.top, rect.right, rect.bottom);
    }
    canvas.drawRect(band, Paint()..color = color);

    // Content area
    final bool vertical = !isHoriz && (pos >= 6 && pos <= 9 || pos >= 16 && pos <= 19);
    if (vertical) {
      // For vertical tiles, rotate canvas
      final tileCx = center.dx;
      final tileCy = center.dy;
      canvas.save();
      canvas.translate(tileCx, tileCy);
      // Flip 90°: right side reads up, left side reads down
      final angle = (pos >= 6 && pos <= 9) ? -pi / 2 : pi / 2;
      canvas.rotate(angle);
      _drawText(canvas, tile.emoji, const Offset(0, -10), 16, Colors.black87);
      _drawText(canvas, tile.name, const Offset(0, 8), 8.5, const Color(0xFF1A1A1A), fontWeight: FontWeight.w700);
      _drawText(canvas, '${tile.price}만', const Offset(0, 19), 7, const Color(0xFF555555));
      canvas.restore();
    } else {
      // Horizontal tiles
      final textY = (pos >= 1 && pos <= 4) ? center.dy + 4 : center.dy - 4;
      _drawText(canvas, tile.emoji, Offset(center.dx, textY - 10), 16, Colors.black87);
      _drawText(canvas, tile.name, Offset(center.dx, textY + 6), 8.5, const Color(0xFF1A1A1A), fontWeight: FontWeight.w700);
      _drawText(canvas, '${tile.price}만', Offset(center.dx, textY + 17), 7, const Color(0xFF555555));
    }
  }

  void _drawShortcutNode(Canvas canvas, int pos) {
    final norm = marbleNormalizedCenter(pos);
    final center = Offset(norm.dx * _unit, norm.dy * _unit);
    final tile = kTileByPos[pos];
    if (tile == null) return;

    final bgColor = tile.color;
    canvas.drawCircle(center, 22, Paint()..color = bgColor.withValues(alpha: 0.9));
    canvas.drawCircle(
      center, 22,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawText(canvas, tile.emoji, center.translate(0, -5), 13, Colors.white);
    _drawText(canvas, tile.name, center.translate(0, 10), 7, Colors.white, fontWeight: FontWeight.w700);

    // Ownership
    final posStr = '$pos';
    final land = landData[posStr];
    if (land is Map) {
      final owner = land['owner'] as String?;
      if (owner == p1UserId) {
        canvas.drawCircle(center, 24, Paint()..color = _p1Color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 3);
      } else if (owner == p2UserId) {
        canvas.drawCircle(center, 24, Paint()..color = _p2Color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 3);
      }
    }
  }

  void _drawOwnership(Canvas canvas, int pos, Rect rect) {
    final posStr = '$pos';
    final land = landData[posStr];
    if (land is! Map) return;
    final owner = land['owner'] as String?;
    final level = land['level'] as int? ?? 1;
    if (owner == null) return;

    final ownerColor = (owner == p1UserId) ? _p1Color : _p2Color;

    // Ownership tint
    canvas.drawRect(
      rect.deflate(1),
      Paint()..color = ownerColor.withValues(alpha: 0.18),
    );

    // Ownership border
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..color = ownerColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Level stars
    if (level > 1) {
      final starText = '★' * (level - 1);
      final center = rect.center;
      final isCorner = (pos == 0 || pos == 5 || pos == 10 || pos == 15);
      final starPos = isCorner
          ? center.translate(0, 26)
          : center.translate(0, 28);
      _drawText(canvas, starText, starPos, 9, ownerColor, fontWeight: FontWeight.w900);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(canvas, center.translate(-tp.width / 2, -tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MarbleBoardPainter old) =>
      old.landData != landData ||
      old.p1UserId != p1UserId ||
      old.p2UserId != p2UserId;
}

class _DiceRollButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final width = compact ? 122.0 : 140.0;
    final height = compact ? 58.0 : 66.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '주사위 굴리기',
      child: GestureDetector(
        onTap: enabled && !loading ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF5B9BFF), Color(0xFF2554D4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? const Color(0xFF9EC4FF) : Colors.white.withValues(alpha: 0.14),
              width: enabled ? 1.5 : 1,
            ),
            boxShadow: enabled
                ? const [BoxShadow(color: Color(0x66000000), blurRadius: 7, offset: Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                loading ? '🎲' : '🎲',
                style: TextStyle(fontSize: compact ? 24 : 28),
              ),
              SizedBox(width: compact ? 6 : 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loading ? '굴리는 중' : '주사위',
                    style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: enabled ? Colors.white : Colors.white38,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    loading ? '결과 확인 중' : '굴려주세요',
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.white70 : Colors.white30,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
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

  @override
  bool shouldRepaint(covariant _CharacterTokenPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.color != color ||
        oldDelegate.selected != selected ||
        oldDelegate.pieceSkin != pieceSkin;
  }
}

// ─── Dice Roll Animation ────────────────────────────────────────────────────

class _DiceRollOverlay extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic>? roll;

  const _DiceRollOverlay({required this.animation, this.roll});

  String _dieFace(int n) {
    const faces = ['', '⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return (n >= 1 && n <= 6) ? faces[n] : '🎲';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, _) {
        final t = animation.value;
        final revealed = t > 0.85 && roll != null;
        final dice1 = roll?['dice1'] as int?;
        final dice2 = roll?['dice2'] as int?;
        final total = roll?['total'] as int?;
        final isDouble = roll?['isDouble'] as bool? ?? false;

        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AnimatedDie(
                      t: t,
                      face: revealed ? (dice1 ?? 0) : 0,
                      offset: -1,
                    ),
                    const SizedBox(width: 24),
                    _AnimatedDie(
                      t: t,
                      face: revealed ? (dice2 ?? 0) : 0,
                      offset: 1,
                    ),
                  ],
                ),
                if (revealed) ...[
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, child) => Transform.scale(
                      scale: Curves.elasticOut.transform(v),
                      child: child,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_dieFace(dice1 ?? 0)} + ${_dieFace(dice2 ?? 0)} = $total',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                        if (isDouble)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '🎯 더블! 한 번 더!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4A2512),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedDie extends StatelessWidget {
  final double t;
  final int face;
  final double offset;

  const _AnimatedDie({required this.t, required this.face, required this.offset});

  String _randomFace() {
    const faces = ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return faces[(DateTime.now().microsecondsSinceEpoch + offset.toInt()) % 6];
  }

  String _dieFace(int n) {
    const faces = ['', '⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return (n >= 1 && n <= 6) ? faces[n] : '🎲';
  }

  @override
  Widget build(BuildContext context) {
    final revealed = t > 0.85 && face > 0;
    final scale = revealed
        ? 1.0
        : (0.8 + 0.2 * (1 - (t * 8 % 1)));

    return Transform.translate(
      offset: Offset(offset * 12 * (1 - t), 0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Text(
            revealed ? _dieFace(face) : _randomFace(),
            style: const TextStyle(fontSize: 48),
          ),
        ),
      ),
    );
  }
}
