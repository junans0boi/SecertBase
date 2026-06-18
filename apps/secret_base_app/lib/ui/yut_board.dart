import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

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
  final void Function(int) onMovePiece;
  final VoidCallback onMoveNewPiece;
  final String currentUser;
  final String? lastResultName; // Added to show the recent throw

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
  });

  @override
  State<YutBoard> createState() => _YutBoardState();
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
      }
    });
    _syncCountdown();
  }

  @override
  void didUpdateWidget(YutBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastResultName != oldWidget.lastResultName &&
        widget.lastResultName != null) {
      _animResult = widget.lastResultName;
      if (!_showThrowAnim) {
        // result arrived without our animation (opponent's throw), just bounce
        _resultBounceCtrl.forward(from: 0);
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
    });
    _stickThrowCtrl.forward(from: 0);
    widget.onThrow();
  }

  Offset _getBoardPoint(int pos) {
    if (pos == 0 || pos >= 20) return const Offset(1.0, 1.0);
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

  int _getFirstPendingMove() {
    final move = widget.pendingMoves?.isNotEmpty == true
        ? widget.pendingMoves!.first
        : null;
    if (move is int) return move;
    if (move is num) return move.toInt();
    return 0;
  }

  int _getNextPos(int currentPos, bool isFirstStep) {
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
        return 26;
      case 26:
        return 27;
      case 27:
        return 20;
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
        return 20;
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
    }
    return 0;
  }

  int _getLastPos(dynamic p) {
    if (p is Map) return p['lastPos'] as int? ?? 0;
    return 0;
  }

  int _previewMove(dynamic piece, int steps) {
    var pos = _getPos(piece);
    if (pos == 20) return 20;
    if (steps == -1) return _getPrevPos(pos, _getLastPos(piece));
    for (var i = 0; i < steps; i++) {
      if (pos == 20) break;
      pos = _getNextPos(pos, i == 0);
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
    return _getPos(pieces[pieceId]) != 20;
  }

  Widget _buildGuideMarker(Size boardSize, int targetPos) {
    if (_selectedPieceId == null) {
      return const SizedBox.shrink();
    }
    final targetOffset = _toCanvasPoint(boardSize, targetPos);
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
          widget.onMovePiece(pieceId);
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
          child: const Icon(Icons.touch_app, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildGroupedPiece(
    Color color,
    String team,
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.yellowAccent : Colors.white,
                  width: selected ? 4 : 2,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                  if (selected)
                    const BoxShadow(color: Colors.yellowAccent, blurRadius: 14),
                ],
              ),
              alignment: Alignment.center,
              child: i == count - 1
                  ? Text(
                      count > 1 ? 'x$count' : '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
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
    required String team,
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
          team,
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

    final myColor = isGf ? Colors.blueAccent : Colors.redAccent;
    final opColor = isGf ? Colors.redAccent : Colors.blueAccent;

    Map<int, int> p1Counts = {};
    if (widget.p1Pieces != null) {
      for (var p in widget.p1Pieces!) {
        final pos = _getPos(p);
        if (pos > 0 && pos < 20) p1Counts[pos] = (p1Counts[pos] ?? 0) + 1;
        if (pos > 20) p1Counts[pos] = (p1Counts[pos] ?? 0) + 1;
      }
    }

    Map<int, int> p2Counts = {};
    if (widget.p2Pieces != null) {
      for (var p in widget.p2Pieces!) {
        final pos = _getPos(p);
        if (pos > 0 && pos < 20) p2Counts[pos] = (p2Counts[pos] ?? 0) + 1;
        if (pos > 20) p2Counts[pos] = (p2Counts[pos] ?? 0) + 1;
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
    final guideTarget = selectedPiece == null
        ? null
        : _previewMove(selectedPiece, _getFirstPendingMove());

    return Container(
      height: 690,
      decoration: BoxDecoration(
        color: const Color(0xFFC0A080),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF8B5A2B), width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                    backgroundColor: Colors.brown[800],
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
                        color: Colors.brown[900],
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildProfileCard(
                                opponent,
                                opColor,
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
                                        if (pos == 0 || pos == 20) {
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
                                          color: Colors.redAccent,
                                          team: 'P1',
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
                                        if (pos == 0 || pos == 20) {
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
                                          color: Colors.blueAccent,
                                          team: 'P2',
                                          count: count,
                                          selected:
                                              isGf && _selectedPieceId == e.key,
                                          onTap: isGf
                                              ? () => _selectPiece(e.key)
                                              : null,
                                          stackOffset: const Offset(10, 10),
                                        );
                                      }),
                                    if (guideTarget != null)
                                      _buildGuideMarker(boardSize, guideTarget),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.brown[800],
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              '이동 대기: ${widget.pendingMoves?.join(", ") ?? "-"}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.yellowAccent,
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
                                          backgroundColor: Colors.white,
                                          child: Text(
                                            widget.lastResultName!,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.brown,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.casino,
                                        size: 42,
                                        color: Colors.white54,
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
                                      ? Colors.amber[700]
                                      : Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  '윷 던지기',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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
    List<dynamic>? pieces,
    bool isActiveTurn,
    bool selectable,
    void Function(int)? onPieceTap,
  ) {
    final safePieces = pieces ?? List.generate(4, (_) => 0);

    return Container(
      decoration: BoxDecoration(
        color: isActiveTurn ? Colors.white24 : Colors.transparent,
        border: Border.all(
          color: isActiveTurn ? Colors.amber : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isActiveTurn ? Colors.amber : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: safePieces.asMap().entries.map((entry) {
              final pieceId = entry.key;
              final pos = _getPos(entry.value);
              final isFinished = pos == 20;
              final isWaiting = pos == 0;
              final canTap = selectable && _canSelectPiece(pieceId);
              final selected = selectable && _selectedPieceId == pieceId;

              return GestureDetector(
                onTap: canTap ? () => onPieceTap?.call(pieceId) : null,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isFinished ? Colors.grey : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.yellowAccent : Colors.white,
                      width: selected ? 4 : 2,
                    ),
                    boxShadow: [
                      if (canTap)
                        const BoxShadow(
                          color: Colors.yellowAccent,
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isFinished
                        ? '✓'
                        : isWaiting
                        ? '${pieceId + 1}'
                        : '$pos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '대기: ${_getRemaining(pieces)}개',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (isActiveTurn)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                widget.pendingMoves?.isNotEmpty == true ? '말 선택' : '윷 던지기',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HangameYutPainter extends CustomPainter {
  final double inset;

  const HangameYutPainter({required this.inset});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF5C3A21)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF5C3A21)
      ..style = PaintingStyle.fill;
    final bigDotPaint = Paint()
      ..color = const Color(0xFF8B2500)
      ..style = PaintingStyle.fill;

    final boardRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );

    Offset point(double x, double y) {
      return Offset(
        boardRect.left + (boardRect.width * x),
        boardRect.top + (boardRect.height * y),
      );
    }

    canvas.drawRect(boardRect, linePaint);
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
        bool isCorner =
            (offset.dx == boardRect.left || offset.dx == boardRect.right) &&
            (offset.dy == boardRect.top || offset.dy == boardRect.bottom);
        canvas.drawCircle(
          offset,
          isCorner ? 12 : 6,
          isCorner ? bigDotPaint : dotPaint,
        );
        if (isCorner) canvas.drawCircle(offset, 14, linePaint..strokeWidth = 2);
      }
    }

    canvas.drawCircle(point(0.5, 0.5), 16, bigDotPaint);
    canvas.drawCircle(point(0.5, 0.5), 18, linePaint..strokeWidth = 2);

    for (final diagonalPoint in const [
      Offset(0.25, 0.25),
      Offset(0.4, 0.4),
      Offset(0.6, 0.6),
      Offset(0.75, 0.75),
      Offset(0.75, 0.25),
      Offset(0.6, 0.4),
    ]) {
      canvas.drawCircle(point(diagonalPoint.dx, diagonalPoint.dy), 6, dotPaint);
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
              if (t > 0.82 && resultName != null)
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
