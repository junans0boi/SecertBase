import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/yut_audio.dart';

class YutBoard extends StatefulWidget {
  final String? gameId;
  final String? phase;
  final String? turn;
  final List<dynamic>? p1Pieces;
  final List<dynamic>? p2Pieces;
  final List<dynamic>? pendingMoves;
  final Map<String, dynamic>? startRolls;
  final int? orderCountdownUntil;
  final VoidCallback onNewGame;
  final VoidCallback onRollStartDice;
  final VoidCallback onThrow;
  final void Function(int, int) onMovePiece;
  final VoidCallback onMoveNewPiece;
  final String currentUser;
  final String? lastResultName; // Added to show the recent throw
  final int? lastThrowAt;
  final bool lastThrowNak;
  final String p1Character;
  final String p2Character;
  final ValueChanged<int>? onThrowResultRevealed;

  const YutBoard({
    super.key,
    this.gameId,
    this.phase,
    this.turn,
    this.p1Pieces,
    this.p2Pieces,
    this.pendingMoves,
    this.startRolls,
    this.orderCountdownUntil,
    required this.onNewGame,
    required this.onRollStartDice,
    required this.onThrow,
    required this.onMovePiece,
    required this.onMoveNewPiece,
    required this.currentUser,
    this.lastResultName,
    this.lastThrowAt,
    this.lastThrowNak = false,
    this.p1Character = 'honggilldong',
    this.p2Character = 'miho',
    this.onThrowResultRevealed,
  });

  @override
  State<YutBoard> createState() => _YutBoardState();
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

class _YutBoardState extends State<YutBoard> with TickerProviderStateMixin {
  static const double _boardInset = 28;
  static const double _pieceSize = 36;
  static const double _guideSize = 56;

  late AnimationController _resultBounceCtrl;
  late Animation<double> _resultBounce;
  late AnimationController _stickThrowCtrl;
  bool _showThrowAnim = false;
  String? _animResult;
  int? _animThrowAt;
  int? _notifiedThrowAt;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  int? _selectedPieceId;

  @override
  void initState() {
    super.initState();
    _resultBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _resultBounce = CurvedAnimation(
      parent: _resultBounceCtrl,
      curve: Curves.bounceOut,
    );

    _stickThrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _stickThrowCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showThrowAnim = false);
        _resultBounceCtrl.forward(from: 0);
        _notifyThrowResultRevealed();
      }
    });
    _syncCountdown();
  }

  @override
  void didUpdateWidget(YutBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastThrowAt != oldWidget.lastThrowAt &&
        widget.lastResultName != null) {
      _animThrowAt = widget.lastThrowAt;
      if (_showThrowAnim) {
        // My throw: result arrived mid-animation — update result so sticks settle correctly
        setState(() => _animResult = widget.lastResultName);
      } else {
        // Opponent's throw: play the same throw animation then show result
        setState(() {
          _animResult = widget.lastResultName;
          _showThrowAnim = true;
        });
        YutAudio.instance.playThrow();
        _stickThrowCtrl.forward(from: 0);
      }
    }
    if (widget.turn != oldWidget.turn ||
        widget.phase != oldWidget.phase ||
        widget.pendingMoves != oldWidget.pendingMoves) {
      _selectedPieceId = null;
    }
    if (widget.phase != oldWidget.phase ||
        widget.orderCountdownUntil != oldWidget.orderCountdownUntil) {
      _syncCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resultBounceCtrl.dispose();
    _stickThrowCtrl.dispose();
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
      if (mounted) {
        setState(() => _countdownSeconds = nextSeconds);
      } else {
        _countdownSeconds = nextSeconds;
      }
      if (nextSeconds <= 0) {
        _countdownTimer?.cancel();
      }
    }

    tick();
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => tick(),
    );
  }

  void _handleThrow() {
    setState(() {
      _showThrowAnim = true;
      _animResult = null;
      _animThrowAt = null;
    });
    YutAudio.instance.playThrow();
    _stickThrowCtrl.forward(from: 0);
    widget.onThrow();
  }

  void _notifyThrowResultRevealed() {
    final throwAt = _animThrowAt;
    if (throwAt == null || throwAt == _notifiedThrowAt) return;
    _notifiedThrowAt = throwAt;
    widget.onThrowResultRevealed?.call(throwAt);
  }

  Offset _getBoardPoint(int pos) {
    if (pos == 0 || pos == 20) return const Offset(1.0, 1.0);
    if (pos >= 1 && pos <= 5) return Offset(1.0, 1.0 - (pos * 0.2));
    if (pos >= 6 && pos <= 10) return Offset(1.0 - ((pos - 5) * 0.2), 0.0);
    if (pos >= 11 && pos <= 15) return Offset(0.0, (pos - 10) * 0.2);
    if (pos >= 16 && pos <= 19) return Offset((pos - 15) * 0.2, 1.0);
    if (pos == 21) return const Offset(0.75, 0.25);
    if (pos == 22) return const Offset(0.6, 0.4);
    if (pos == 23) return const Offset(0.5, 0.5);
    if (pos == 24) return const Offset(0.25, 0.25);
    if (pos == 25) return const Offset(0.4, 0.4);
    if (pos == 26) return const Offset(0.6, 0.6);
    if (pos == 27) return const Offset(0.75, 0.75);
    if (pos == 28) return const Offset(0.4, 0.6);
    if (pos == 29) return const Offset(0.25, 0.75);
    return const Offset(1.0, 1.0);
  }

  Offset _toCanvasPoint(Size size, int pos) {
    final point = _getBoardPoint(pos);
    final boardWidth = size.width - (_boardInset * 2);
    final boardHeight = size.height - (_boardInset * 2);
    return Offset(
      _boardInset + (point.dx * boardWidth),
      _boardInset + (point.dy * boardHeight),
    );
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

    final position = _getPos(piece);
    if (_isFinished(piece)) {
      return const [];
    }

    final options = <_MoveGuideOption>[];
    for (var i = 0; i < moves.length; i += 1) {
      final steps = _moveValue(moves[i]);
      if (steps == -1 && position == 0) {
        continue;
      }
      options.add(
        _MoveGuideOption(
          index: i,
          steps: steps,
          targetPos: _previewMove(piece, steps),
        ),
      );
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
    final pieces = widget.currentUser == 'gf'
        ? widget.p2Pieces
        : widget.p1Pieces;
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
      left: targetOffset.dx - (_guideSize / 2),
      top: targetOffset.dy - (_guideSize / 2),
      width: _guideSize,
      height: _guideSize,
      child: GestureDetector(
        onTap: () {
          final pieceId = _selectedPieceId;
          if (pieceId == null) return;
          setState(() {
            _selectedPieceId = null;
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
    Offset offset = Offset.zero,
    bool selected = false,
  }) {
    return Transform.translate(
      offset: offset,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(count, (i) {
          return Positioned(
            top: i * -4.0,
            left: i * -4.0,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: _CharacterToken(
                character: character,
                color: color,
                selected: selected,
                count: i == count - 1 && count > 1 ? count : null,
              ),
            ),
          );
        }).reversed.toList(),
      ),
    );
  }

  Widget _buildBoardPiece({
    required Size boardSize,
    required int pos,
    required Color color,
    required String character,
    required int count,
    required bool selected,
    required VoidCallback? onTap,
    required Offset stackOffset,
  }) {
    final point = _toCanvasPoint(boardSize, pos);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutBack,
      left: point.dx - (_pieceSize / 2),
      top: point.dy - (_pieceSize / 2),
      width: _pieceSize,
      height: _pieceSize,
      child: GestureDetector(
        onTap: onTap,
        child: _buildGroupedPiece(
          color,
          character,
          count,
          offset: stackOffset,
          selected: selected,
        ),
      ),
    );
  }

  int _getRemaining(List<dynamic>? pieces) {
    if (pieces == null) return 4;
    int remaining = 0;
    for (var p in pieces) {
      if (_getPos(p) == 0) remaining++;
    }
    return remaining;
  }

  String _moveLabel(dynamic move) {
    final value = move is num ? move.toInt() : int.tryParse('$move');
    return switch (value) {
      -1 => '백도',
      1 => '도',
      2 => '개',
      3 => '걸',
      4 => '윷',
      5 => '모',
      _ => '$move',
    };
  }

  String _pendingMoveText() {
    final moves = widget.pendingMoves;
    if (moves == null || moves.isEmpty) return '-';
    return moves.map(_moveLabel).join(' · ');
  }

  Widget _buildRollOrderView() {
    final junRoll = widget.startRolls?['jun'];
    final gfRoll = widget.startRolls?['gf'];
    final alreadyRolled = widget.startRolls?[widget.currentUser] != null;

    return Container(
      color: Colors.brown[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '선공 정하기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStartDice('jun', junRoll),
                const SizedBox(width: 28),
                _buildStartDice('gf', gfRoll),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: alreadyRolled ? null : widget.onRollStartDice,
              icon: const Icon(Icons.casino),
              label: Text(alreadyRolled ? '상대방 대기 중' : '내 주사위 굴리기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '숫자가 높은 사람이 먼저 윷을 던집니다. 동점이면 다시 굴려요.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCountdownView() {
    final players = widget.startRolls?.keys.toList() ?? const [];
    final first = players.contains('jun')
        ? 'jun'
        : (players.isNotEmpty ? players[0] : 'jun');
    final second = players.contains('gf')
        ? 'gf'
        : (players.length > 1
              ? players.firstWhere(
                  (player) => player != first,
                  orElse: () => 'gf',
                )
              : 'gf');
    final firstRoll = widget.startRolls?[first];
    final secondRoll = widget.startRolls?[second];
    final starter = widget.turn ?? '-';

    return Container(
      color: Colors.brown[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '선공 결정!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStartDice(first, firstRoll, highlight: first == starter),
                const SizedBox(width: 28),
                _buildStartDice(
                  second,
                  secondRoll,
                  highlight: second == starter,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber[700],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '$starter 선공',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '${_countdownSeconds.clamp(1, 3)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 76,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '곧 게임이 시작됩니다',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDice(String name, dynamic value, {bool highlight = false}) {
    return Column(
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: highlight
                ? Border.all(color: Colors.amberAccent, width: 4)
                : null,
            boxShadow: [
              const BoxShadow(
                color: Colors.black45,
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
              if (highlight)
                const BoxShadow(color: Colors.amberAccent, blurRadius: 18),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            value == null ? '?' : '$value',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.brown,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = widget.turn == widget.currentUser;
    final opponent = widget.currentUser == 'jun' ? 'gf' : 'jun';
    final isGf = widget.currentUser == 'gf';
    final isRollOrder = widget.phase == 'roll_order';
    final isOrderCountdown = widget.phase == 'order_countdown';
    final canThrow = isMyTurn && widget.phase == 'throwing';

    final myPieces = isGf ? widget.p2Pieces : widget.p1Pieces;
    final opPieces = isGf ? widget.p1Pieces : widget.p2Pieces;

    final myColor = isGf ? const Color(0xFF4B8DD8) : const Color(0xFFE45858);
    final opColor = isGf ? const Color(0xFFE45858) : const Color(0xFF4B8DD8);
    final myCharacter = isGf ? widget.p2Character : widget.p1Character;
    final opCharacter = isGf ? widget.p1Character : widget.p2Character;

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

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E9D8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFB88F55), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: widget.gameId == null
            ? Center(
                child: ElevatedButton.icon(
                  onPressed: widget.onNewGame,
                  icon: const Icon(Icons.play_arrow, size: 32),
                  label: const Text(
                    '실전형 윷놀이 시작',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    backgroundColor: const Color(0xFF7D4F2A),
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            : isRollOrder
            ? _buildRollOrderView()
            : isOrderCountdown
            ? _buildOrderCountdownView()
            : Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF5D3F25), Color(0xFF8B622F)],
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildProfileCard(
                                opponent,
                                opColor,
                                opCharacter,
                                opPieces,
                                widget.turn == opponent,
                                false,
                                null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildProfileCard(
                                widget.currentUser,
                                myColor,
                                myCharacter,
                                myPieces,
                                isMyTurn,
                                true,
                                _selectPiece,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final boardSize = Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: HangameYutPainter(
                                          inset: _boardInset,
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
                                        final count = p1Counts[pos] ?? 1;
                                        return _buildBoardPiece(
                                          boardSize: boardSize,
                                          pos: pos,
                                          color: const Color(0xFFE45858),
                                          character: widget.p1Character,
                                          count: count,
                                          selected:
                                              !isGf &&
                                              _selectedPieceId == e.key,
                                          onTap: !isGf
                                              ? () => _selectPiece(e.key)
                                              : null,
                                          stackOffset: const Offset(-10, -10),
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
                                        final count = p2Counts[pos] ?? 1;
                                        return _buildBoardPiece(
                                          boardSize: boardSize,
                                          pos: pos,
                                          color: const Color(0xFF4B8DD8),
                                          character: widget.p2Character,
                                          count: count,
                                          selected:
                                              isGf && _selectedPieceId == e.key,
                                          onTap: isGf
                                              ? () => _selectPiece(e.key)
                                              : null,
                                          stackOffset: const Offset(10, 10),
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
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4C58C),
                          border: Border(
                            top: BorderSide(color: Color(0xFFBA8A45), width: 1),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              widget.lastThrowNak
                                  ? '낙 · 다음 차례로 넘어갑니다'
                                  : '이동 대기: ${_pendingMoveText()}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: widget.lastThrowNak
                                    ? const Color(0xFFB13B2E)
                                    : const Color(0xFF5A3718),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 74,
                              child: Center(
                                child: widget.lastResultName != null
                                    ? ScaleTransition(
                                        scale: _resultBounce,
                                        child: CircleAvatar(
                                          radius: 34,
                                          backgroundColor: const Color(
                                            0xFFFFF9EA,
                                          ),
                                          child: Text(
                                            widget.lastThrowNak
                                                ? '낙'
                                                : widget.lastResultName!,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF6E3F1D),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.casino,
                                        size: 42,
                                        color: Color(0xAA6E3F1D),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: canThrow ? _handleThrow : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: canThrow
                                      ? const Color(0xFFFFCB4D)
                                      : const Color(0xFFBDAE98),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '윷 던지기',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3D2A12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Yut stick throw animation overlay
                  if (_showThrowAnim)
                    Positioned.fill(
                      child: _YutThrowOverlay(
                        animation: _stickThrowCtrl,
                        resultName: _animResult,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileCard(
    String name,
    Color color,
    String character,
    List<dynamic>? pieces,
    bool isActiveTurn,
    bool selectable,
    void Function(int)? onPieceTap,
  ) {
    final safePieces = pieces ?? List.generate(4, (_) => 0);

    return Container(
      decoration: BoxDecoration(
        color: isActiveTurn ? const Color(0xFFFFF4CF) : const Color(0x33FFFFFF),
        border: Border.all(
          color: isActiveTurn ? const Color(0xFFFFCB4D) : Colors.white24,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: _CharacterToken(
                  character: character,
                  color: color,
                  selected: isActiveTurn,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActiveTurn
                        ? const Color(0xFF3D2A12)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: safePieces.asMap().entries.map((entry) {
              final pieceId = entry.key;
              final pos = _getPos(entry.value);
              final isFinished = _isFinished(entry.value);
              final isWaiting = pos == 0;
              final canTap = selectable && _canSelectPiece(pieceId);
              final selected = selectable && _selectedPieceId == pieceId;

              return GestureDetector(
                onTap: canTap ? () => onPieceTap?.call(pieceId) : null,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: isFinished ? 0.45 : 1,
                          child: _CharacterToken(
                            character: character,
                            color: isFinished ? const Color(0xFF8E8E8E) : color,
                            selected: selected || canTap,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          constraints: const BoxConstraints(minWidth: 17),
                          decoration: BoxDecoration(
                            color: isFinished
                                ? const Color(0xFF61705B)
                                : isWaiting
                                ? const Color(0xFF5B4632)
                                : const Color(0xFFFFCB4D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            isFinished
                                ? '✓'
                                : isWaiting
                                ? '${pieceId + 1}'
                                : '$pos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 7),
          Text(
            '대기 ${_getRemaining(pieces)} · 완주 ${safePieces.where(_isFinished).length}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActiveTurn
                  ? const Color(0xFF5A3718)
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isActiveTurn)
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Text(
                widget.pendingMoves?.isNotEmpty == true ? '말 선택' : '윷 던지기',
                style: const TextStyle(
                  color: Color(0xFF1A7D4E),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterToken extends StatelessWidget {
  final String character;
  final Color color;
  final bool selected;
  final int? count;

  const _CharacterToken({
    required this.character,
    required this.color,
    this.selected = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CharacterTokenPainter(
        character: character,
        color: color,
        selected: selected,
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

  const _CharacterTokenPainter({
    required this.character,
    required this.color,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center.translate(1.5, 2), radius * 0.82, shadow);

    final base = Paint()..color = color;
    canvas.drawCircle(center, radius * 0.82, base);
    canvas.drawCircle(
      center,
      radius * 0.82,
      Paint()
        ..color = selected ? const Color(0xFFFFE66B) : Colors.white
        ..strokeWidth = selected ? 3 : 1.5
        ..style = PaintingStyle.stroke,
    );

    switch (character) {
      case 'nolbu':
        _drawNolbu(canvas, center, radius);
        break;
      case 'miho':
        _drawMiho(canvas, center, radius);
        break;
      default:
        _drawHong(canvas, center, radius);
    }
  }

  void _drawFace(Canvas canvas, Offset center, double radius, Color skin) {
    canvas.drawCircle(
      center.translate(0, radius * 0.02),
      radius * 0.44,
      Paint()..color = skin,
    );
    final eye = Paint()..color = const Color(0xFF2B2117);
    canvas.drawCircle(
      center.translate(-radius * 0.17, -radius * 0.04),
      radius * 0.045,
      eye,
    );
    canvas.drawCircle(
      center.translate(radius * 0.17, -radius * 0.04),
      radius * 0.045,
      eye,
    );
    final smile = Paint()
      ..color = const Color(0xFF7B2B22)
      ..strokeWidth = radius * 0.045
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: center.translate(0, radius * 0.08),
        width: radius * 0.34,
        height: radius * 0.22,
      ),
      0.15,
      pi - 0.3,
      false,
      smile,
    );
  }

  void _drawHong(Canvas canvas, Offset center, double radius) {
    _drawFace(canvas, center, radius, const Color(0xFFFFD7A8));
    final hat = Paint()..color = const Color(0xFF1F6F54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, -radius * 0.42),
          width: radius * 0.88,
          height: radius * 0.26,
        ),
        Radius.circular(radius * 0.12),
      ),
      hat,
    );
    final sword = Paint()
      ..color = const Color(0xFFECE7D7)
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(radius * 0.34, radius * 0.34),
      center.translate(radius * 0.62, -radius * 0.36),
      sword,
    );
  }

  void _drawNolbu(Canvas canvas, Offset center, double radius) {
    _drawFace(canvas, center, radius, const Color(0xFFFFC98B));
    final hat = Paint()..color = const Color(0xFF4D2E83);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -radius * 0.42),
        width: radius * 0.88,
        height: radius * 0.34,
      ),
      hat,
    );
    final coin = Paint()..color = const Color(0xFFFFCF45);
    canvas.drawCircle(
      center.translate(radius * 0.42, radius * 0.27),
      radius * 0.16,
      coin,
    );
    canvas.drawCircle(
      center.translate(radius * 0.42, radius * 0.27),
      radius * 0.1,
      Paint()
        ..color = const Color(0xFFA86A10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.025,
    );
  }

  void _drawMiho(Canvas canvas, Offset center, double radius) {
    final ear = Paint()..color = const Color(0xFFF28B35);
    final innerEar = Paint()..color = const Color(0xFFFFD7D0);
    final leftEar = Path()
      ..moveTo(center.dx - radius * 0.38, center.dy - radius * 0.28)
      ..lineTo(center.dx - radius * 0.2, center.dy - radius * 0.76)
      ..lineTo(center.dx, center.dy - radius * 0.3)
      ..close();
    final rightEar = Path()
      ..moveTo(center.dx + radius * 0.38, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius * 0.2, center.dy - radius * 0.76)
      ..lineTo(center.dx, center.dy - radius * 0.3)
      ..close();
    canvas.drawPath(leftEar, ear);
    canvas.drawPath(rightEar, ear);
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - radius * 0.28, center.dy - radius * 0.33)
        ..lineTo(center.dx - radius * 0.2, center.dy - radius * 0.57)
        ..lineTo(center.dx - radius * 0.04, center.dy - radius * 0.32)
        ..close(),
      innerEar,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + radius * 0.28, center.dy - radius * 0.33)
        ..lineTo(center.dx + radius * 0.2, center.dy - radius * 0.57)
        ..lineTo(center.dx + radius * 0.04, center.dy - radius * 0.32)
        ..close(),
      innerEar,
    );
    _drawFace(canvas, center, radius, const Color(0xFFFFD2A3));
    final nose = Paint()..color = const Color(0xFF4B2B20);
    canvas.drawCircle(center.translate(0, radius * 0.08), radius * 0.06, nose);
  }

  @override
  bool shouldRepaint(covariant _CharacterTokenPainter oldDelegate) {
    return oldDelegate.character != character ||
        oldDelegate.color != color ||
        oldDelegate.selected != selected;
  }
}

class HangameYutPainter extends CustomPainter {
  final double inset;

  const HangameYutPainter({required this.inset});

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    final background = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      const Radius.circular(20),
    );

    canvas.drawRRect(
      background.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      background,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF5E9D0), Color(0xFFD8B97A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(background.outerRect),
    );

    final tilePaint = Paint()
      ..color = const Color(0xFFB59663).withValues(alpha: 0.24)
      ..strokeWidth = 1;
    const tile = 34.0;
    for (
      double y = background.outerRect.top + 10;
      y < background.outerRect.bottom;
      y += tile * 0.62
    ) {
      final row = ((y - background.outerRect.top) / (tile * 0.62)).floor();
      final stagger = row.isEven ? 0.0 : tile / 2;
      for (
        double x = background.outerRect.left + 10 - tile;
        x < background.outerRect.right;
        x += tile
      ) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + stagger, y, tile, tile * 0.5),
            const Radius.circular(3),
          ),
          tilePaint..style = PaintingStyle.stroke,
        );
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF9D7B4A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF9F2DF), Color(0xFFC7A976)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(boardRect);
    final bigDotPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF2C5), Color(0xFFD68B2E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(boardRect);
    final dotBorder = Paint()
      ..color = const Color(0xFF8A6335)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Offset point(double x, double y) {
      return Offset(
        boardRect.left + (boardRect.width * x),
        boardRect.top + (boardRect.height * y),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(16)),
      linePaint,
    );
    canvas.drawLine(point(0, 0), point(1, 1), linePaint);
    canvas.drawLine(point(0, 1), point(1, 0), linePaint);

    const steps = 5;

    for (int i = 0; i <= steps; i++) {
      final step = i / steps;
      for (var offset in [
        point(step, 0),
        point(step, 1),
        point(0, step),
        point(1, step),
      ]) {
        final isCorner =
            (offset.dx == boardRect.left || offset.dx == boardRect.right) &&
            (offset.dy == boardRect.top || offset.dy == boardRect.bottom);
        _drawDot(
          canvas,
          offset,
          isCorner ? 16 : 8,
          isCorner,
          dotPaint,
          bigDotPaint,
          dotBorder,
        );
      }
    }

    _drawDot(
      canvas,
      point(0.5, 0.5),
      20,
      true,
      dotPaint,
      bigDotPaint,
      dotBorder,
    );

    for (final diagonalPoint in const [
      Offset(0.25, 0.25),
      Offset(0.4, 0.4),
      Offset(0.6, 0.6),
      Offset(0.75, 0.75),
      Offset(0.75, 0.25),
      Offset(0.6, 0.4),
      Offset(0.4, 0.6),
      Offset(0.25, 0.75),
    ]) {
      _drawDot(
        canvas,
        point(diagonalPoint.dx, diagonalPoint.dy),
        8,
        false,
        dotPaint,
        bigDotPaint,
        dotBorder,
      );
    }
  }

  void _drawDot(
    Canvas canvas,
    Offset center,
    double radius,
    bool big,
    Paint dotPaint,
    Paint bigDotPaint,
    Paint border,
  ) {
    canvas.drawCircle(
      center.translate(1.5, 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, radius, big ? bigDotPaint : dotPaint);
    canvas.drawCircle(center, radius, border);
    if (big) {
      canvas.drawCircle(
        center,
        radius * 0.62,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HangameYutPainter oldDelegate) {
    return oldDelegate.inset != inset;
  }
}

// ─── Yut Stick Throw Animation ─────────────────────────────────────────────

class _YutThrowOverlay extends StatelessWidget {
  final Animation<double> animation;
  final String? resultName;

  const _YutThrowOverlay({required this.animation, this.resultName});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, _) {
        final t = animation.value;
        return Container(
          color: Colors.black.withValues(alpha: 0.82),
          child: Stack(
            children: [
              CustomPaint(
                painter: _YutSticksPainter(t: t, resultName: resultName),
                child: const SizedBox.expand(),
              ),
              if (t > 0.96 && resultName != null)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, v, child) => Transform.scale(
                      scale: Curves.elasticOut.transform(v),
                      child: child,
                    ),
                    child: Text(
                      resultName!,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _YutSticksPainter extends CustomPainter {
  final double t;
  final String? resultName;

  _YutSticksPainter({required this.t, this.resultName});

  int get _flatCount {
    switch (resultName) {
      case '도':
        return 1;
      case '개':
        return 2;
      case '걸':
        return 3;
      case '윷':
        return 4;
      default:
        return 0; // 모
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final flatCount = _flatCount;

    // Each stick has a slightly different trajectory
    final offsets = [-1.5, -0.5, 0.5, 1.5]; // horizontal spread multipliers
    final peakYOffsets = [-0.12, -0.18, -0.15, -0.10]; // different heights

    for (int i = 0; i < 4; i++) {
      final isFlat = i < flatCount;

      // --- position ---
      final startX = cx + offsets[i] * 28;
      final startY = size.height * 0.88;

      final peakX = cx + offsets[i] * 55 + sin(i * 1.4) * 18;
      final peakY = size.height * (0.38 + peakYOffsets[i]);

      final landX = cx + offsets[i] * 44;
      final landY = size.height * 0.52 + (i % 2 == 0 ? -10 : 10);

      double x, y;
      if (t <= 0.55) {
        final ft = Curves.easeOut.transform(t / 0.55);
        x = _lerp(startX, peakX, ft);
        y = _lerp(startY, peakY, ft);
      } else {
        final lt = Curves.bounceOut.transform((t - 0.55) / 0.45);
        x = _lerp(peakX, landX, lt);
        y = _lerp(peakY, landY, lt);
      }

      // --- rotation ---
      final spinSpeed = 10.0 + i * 1.5;
      double angle;
      if (t <= 0.55) {
        // rapid spin while flying
        angle = t * spinSpeed;
      } else {
        // settle: flat=0 (배 up), round=pi (등 up)
        final targetAngle = isFlat ? 0.0 : pi;
        // Snap to nearest target quickly as t→1
        final rawAngle = 0.55 * spinSpeed;
        // keep spinning direction but converge to target
        final ft = Curves.easeInOut.transform((t - 0.55) / 0.45);
        angle = rawAngle + (targetAngle - rawAngle) * ft;
      }

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      // show correct orientation only after landing phase starts
      _drawStick(canvas, isFlat && t > 0.55);

      canvas.restore();
    }
  }

  void _drawStick(Canvas canvas, bool showFlat) {
    const w = 78.0;
    const h = 20.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(10),
    );

    final fill = Paint()
      ..color = showFlat ? const Color(0xFFDEB887) : const Color(0xFF5C3A21);
    canvas.drawRRect(rrect, fill);

    // grain lines
    final line = Paint()
      ..color = showFlat ? const Color(0xFFC49A6C) : const Color(0xFF3D2010)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final dx in [-20.0, 0.0, 20.0]) {
      canvas.drawLine(Offset(dx, -6), Offset(dx, 6), line);
    }

    // border
    final border = Paint()
      ..color = Colors.black38
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, border);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(_YutSticksPainter old) =>
      old.t != t || old.resultName != resultName;
}
