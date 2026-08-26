import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/socket_service.dart';
import '../core/yut_audio.dart';

String _defaultDisplayName(String uid) => uid;

const _yutBoardAssetAspect = 1498 / 1050;
const _yutBoardTopLeft = Offset(0.237, 0.171);
const _yutBoardTopRight = Offset(0.758, 0.171);
const _yutBoardBottomLeft = Offset(0.190, 0.760);
const _yutBoardBottomRight = Offset(0.806, 0.760);

/// Returns the previous board position using the same backdo route as the
/// realtime server. Position 20 is the goal checkpoint, not a finished piece.
int yutPreviousPosition(int currentPos, int lastPos) {
  switch (currentPos) {
    case 0:
      return 0;
    case 1:
      // Nal-backdo waits on the goal checkpoint instead of returning to start.
      return 20;
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
      return lastPos == 29 ? 29 : 14;
    case 16:
      return 15;
    case 17:
      return 16;
    case 18:
      return 17;
    case 19:
      return 18;
    case 20:
      return lastPos == 27 ? 27 : 19;
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
    default:
      return 0;
  }
}

Offset _projectYutPoint(Rect rect, Offset normalized) {
  final depth = normalized.dy.clamp(0.0, 1.0);
  final across = normalized.dx.clamp(0.0, 1.0);
  final left = Offset.lerp(_yutBoardTopLeft, _yutBoardBottomLeft, depth)!;
  final right = Offset.lerp(_yutBoardTopRight, _yutBoardBottomRight, depth)!;
  final projected = Offset.lerp(left, right, across)!;
  return Offset(
    rect.left + (projected.dx * rect.width),
    rect.top + (projected.dy * rect.height),
  );
}

Offset _logicalYutPoint(int pos) {
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

class YutBoard extends StatefulWidget {
  final String? gameId;
  final String? phase;
  final String? turn;
  final List<dynamic>? p1Pieces;
  final List<dynamic>? p2Pieces;
  final List<dynamic>? pendingMoves;
  final Map<String, dynamic>? startRolls;
  final int? orderCountdownUntil;
  final bool hasBonusThrow;
  final VoidCallback onNewGame;
  final VoidCallback onRollStartDice;
  final VoidCallback onThrow;
  final void Function(int, int, {int? backdoDir}) onMovePiece;
  final VoidCallback onMoveNewPiece;
  final String currentUser;
  final String? lastResultName; // Added to show the recent throw
  final List<Map<String, dynamic>>? turnThrows;
  final int? lastThrowAt;
  final bool lastThrowNak;
  final int lastCapturedCount;
  final int lastCaptureBlockedCount;
  final String p1Character;
  final String p2Character;
  final ValueChanged<int>? onThrowResultRevealed;
  final String p1UserId;
  final String p2UserId;
  final String Function(String) displayName;
  final String pieceSkin;
  final String yutSkin;
  final String opponentPieceSkin;
  final String opponentYutSkin;
  final int? coins;

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
    this.hasBonusThrow = false,
    required this.onNewGame,
    required this.onRollStartDice,
    required this.onThrow,
    required this.onMovePiece,
    required this.onMoveNewPiece,
    required this.currentUser,
    this.lastResultName,
    this.turnThrows,
    this.lastThrowAt,
    this.lastThrowNak = false,
    this.lastCapturedCount = 0,
    this.lastCaptureBlockedCount = 0,
    this.p1Character = 'honggilldong',
    this.p2Character = 'miho',
    this.onThrowResultRevealed,
    this.p1UserId = '',
    this.p2UserId = '',
    this.displayName = _defaultDisplayName,
    this.pieceSkin = 'base',
    this.yutSkin = 'base',
    this.opponentPieceSkin = 'base',
    this.opponentYutSkin = 'base',
    this.coins,
  });

  @override
  State<YutBoard> createState() => _YutBoardState();
}

class _MoveGuideOption {
  final int index;
  final int steps;
  final int targetPos;
  final int? backdoDir;

  const _MoveGuideOption({
    required this.index,
    required this.steps,
    required this.targetPos,
    this.backdoDir,
  });
}

class _YutBoardState extends State<YutBoard> with TickerProviderStateMixin {
  static const double _pieceSize = 44;
  static const double _guideSize = 56;

  // Responsive computed values (set each build from MediaQuery)
  double _cPieceSize = 36;
  double _cGuideSize = 56;
  bool _compact = false;

  late AnimationController _resultBounceCtrl;
  late Animation<double> _resultBounce;
  late AnimationController _stickThrowCtrl;
  bool _showThrowAnim = false;
  String? _animResult;
  int? _animThrowAt;
  int? _notifiedThrowAt;
  // 결과는 연출이 끝난 뒤에만 노출한다. widget.lastResultName을 직접 그리면
  // 서버 응답이 연출 중에 도착했을 때 스포일러가 된다.
  String? _revealedResultName;
  bool _revealedNak = false;
  Timer? _countdownTimer;
  Timer? _moveUnlockTimer;
  int _countdownSeconds = 0;

  int? _selectedPieceId;
  bool _moveInFlight = false;
  bool _isOpponentThrow = false;
  int? _lastTrackedThrowAt;

  final _socket = SocketService();
  int _seenYutMessages = 0;
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
        setState(() {
          _showThrowAnim = false;
          _revealedResultName = widget.lastResultName;
          _revealedNak = widget.lastThrowNak;
        });
        _resultBounceCtrl.forward(from: 0);
        _notifyThrowResultRevealed();
      }
    });
    // 재접속 복원 등 연출 없이 진입한 경우 마지막 결과를 즉시 노출한다.
    _revealedResultName = widget.lastResultName;
    _revealedNak = widget.lastThrowNak;
    if (_revealedResultName != null) {
      _resultBounceCtrl.value = 1.0;
    }
    _lastTrackedThrowAt = widget.lastThrowAt;
    _seenYutMessages = _socket.yutChatMessages.length;
    _socket.addListener(_onSocketUpdate);
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
        _isOpponentThrow = true;
        setState(() {
          _animResult = widget.lastResultName;
          _showThrowAnim = true;
          _revealedResultName = null;
        });
        YutAudio.instance.playThrow();
        _stickThrowCtrl.forward(from: 0);
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
      _lastTrackedThrowAt = widget.lastThrowAt;
    } else if (widget.lastThrowAt != null &&
        widget.lastThrowAt != _lastTrackedThrowAt) {
      _lastTrackedThrowAt = widget.lastThrowAt;
    }
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocketUpdate);
    _previewTimer?.cancel();
    _countdownTimer?.cancel();
    _moveUnlockTimer?.cancel();
    _resultBounceCtrl.dispose();
    _stickThrowCtrl.dispose();
    super.dispose();
  }

  void _onSocketUpdate() {
    if (!mounted) return;
    final msgs = _socket.yutChatMessages;
    if (msgs.length > _seenYutMessages) {
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
      _seenYutMessages = msgs.length;
    }
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
    _isOpponentThrow = false;
    setState(() {
      _showThrowAnim = true;
      _animResult = null;
      _animThrowAt = null;
      _revealedResultName = null;
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
    return _logicalYutPoint(pos);
  }

  Offset _toCanvasPoint(Size size, int pos) {
    final point = _getBoardPoint(pos);
    return _projectYutPoint(Offset.zero & size, point);
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
      // At pos 23, 백도 is ambiguous: two paths (22 or 25). Show both.
      if (steps == -1 && position == 23) {
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 22,
            backdoDir: 22,
          ),
        );
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 25,
            backdoDir: 25,
          ),
        );
        continue;
      }
      // At pos 15 (bottom-left corner), 백도 is ambiguous: outer left (14) or diagonal (29).
      if (steps == -1 && position == 15) {
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 14,
            backdoDir: 14,
          ),
        );
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 29,
            backdoDir: 29,
          ),
        );
        continue;
      }
      // At pos 20 (goal checkpoint, not yet finished), 백도 is ambiguous: outer (19) or diagonal (27).
      if (steps == -1 && position == 20) {
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 19,
            backdoDir: 19,
          ),
        );
        options.add(
          _MoveGuideOption(
            index: i,
            steps: steps,
            targetPos: 27,
            backdoDir: 27,
          ),
        );
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
    return yutPreviousPosition(currentPos, lastPos);
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

  void _submitMoveGuide(_MoveGuideOption option) {
    final pieceId = _selectedPieceId;
    if (pieceId == null || _moveInFlight) return;

    setState(() {
      _selectedPieceId = null;
      _moveInFlight = true;
    });
    _moveUnlockTimer?.cancel();
    _moveUnlockTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _moveInFlight = false);
    });
    widget.onMovePiece(pieceId, option.index, backdoDir: option.backdoDir);
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
      key: ValueKey(
        'yut_move_guide_${option.index}_${option.targetPos}_${option.backdoDir ?? ''}',
      ),
      duration: const Duration(milliseconds: 250),
      left: targetOffset.dx - (_cGuideSize / 2),
      top: targetOffset.dy - (_cGuideSize / 2),
      width: _cGuideSize,
      height: _cGuideSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _submitMoveGuide(option),
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
    final depthScale = 0.84 + (_getBoardPoint(pos).dy * 0.16);

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
        child: Transform.scale(
          scale: depthScale,
          alignment: Alignment.center,
          child: _buildGroupedPiece(
            color,
            character,
            count,
            selected: selected,
            pieceSkin: pieceSkin,
          ),
        ),
      ),
    );
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

  String _turnThrowText() {
    final throws = widget.turnThrows ?? const <Map<String, dynamic>>[];
    return throws
        .map((throwResult) {
          final resultName = throwResult['resultName'];
          return resultName is String
              ? resultName
              : _moveLabel(throwResult['result']);
        })
        .join(' · ');
  }

  String _captureResultPrompt({required bool isMyTurn}) {
    final messages = <String>[];
    if (widget.lastCapturedCount > 0) {
      messages.add(
        isMyTurn
            ? '💥 ${widget.lastCapturedCount}개를 잡았습니다'
            : '💥 상대가 ${widget.lastCapturedCount}개를 잡았습니다',
      );
    }
    if (widget.lastCaptureBlockedCount > 0) {
      messages.add(
        isMyTurn
            ? '🛡️ 상대 방어로 ${widget.lastCaptureBlockedCount}개 생존'
            : '🛡️ 내 말 ${widget.lastCaptureBlockedCount}개 방어 성공',
      );
    }
    return messages.join(' · ');
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
    final canThrow =
        isMyTurn &&
        (widget.phase == 'throwing' ||
            (widget.phase == 'moving' && widget.hasBonusThrow));

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
                  final boardWidth = min(
                    screenWidth * 1.24,
                    stageHeight * 0.88 * _yutBoardAssetAspect,
                  );
                  final boardTop = stageHeight * (_compact ? 0.325 : 0.12);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (_revealedResultName != null)
                        Positioned(
                          top: stageHeight * 0.46,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xDD17212B),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFFFC107),
                                    width: 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    _revealedResultName!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 보드는 가로를 넓게, 세로를 눌러 3/4 시점으로 보이게 한다.
                      Positioned(
                        top: boardTop,
                        left: (screenWidth - boardWidth) / 2,
                        width: boardWidth,
                        child: AspectRatio(
                          key: const ValueKey('yut_board_surface'),
                          aspectRatio: _yutBoardAssetAspect,
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
                                    child: Image.asset(
                                      key: const ValueKey('yut_board_art'),
                                      'assets/images/yut/yut_board_3d_rail_v2.png',
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        key: const ValueKey('yut_board_nodes'),
                                        painter: const _YutBoardNodePainter(),
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
        // 윗 던지기 애니메이션 오버레이
        if (_showThrowAnim)
          Positioned.fill(
            child: _YutThrowOverlay(
              animation: _stickThrowCtrl,
              resultName: _animResult,
              yutSkin: _isOpponentThrow
                  ? widget.opponentYutSkin
                  : widget.yutSkin,
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
        height: 68,
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
    final captureNotice =
        widget.lastCapturedCount > 0 || widget.lastCaptureBlockedCount > 0;
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_turnThrowText().isNotEmpty) ...[
                      Text(
                        '이번 턴 결과  ${_turnThrowText()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFFFD54F),
                          fontSize: _compact ? 10 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      _actionPrompt(canThrow: canThrow),
                      maxLines: _turnThrowText().isNotEmpty ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: captureNotice
                            ? const Color(0xFFFFD54F)
                            : Colors.white.withValues(alpha: 0.84),
                        fontSize: _compact ? 12 : 14,
                        fontWeight: captureNotice
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _YutThrowButton(
                enabled: canThrow,
                loading: _showThrowAnim,
                compact: _compact,
                onTap: _handleThrow,
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
                  _buildChatBtn(context),
                ],
              ),
            ],
          ),
        ),
      ),
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
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.white70,
              size: size * 0.52,
            ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
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
    if (_showThrowAnim) return '윷을 던지는 중';
    final isMyTurn = widget.turn == widget.currentUser;
    final capturePrompt = _captureResultPrompt(isMyTurn: isMyTurn);
    if (capturePrompt.isNotEmpty) return capturePrompt;
    final hasMoves = widget.pendingMoves?.isNotEmpty ?? false;
    if (!isMyTurn) {
      return widget.phase == 'moving' ? '상대가 말을 이동하는 중' : '상대가 윷을 던지는 중';
    }
    if (hasMoves) {
      return _selectedPieceId == null ? '내 말 선택' : '이동 칸 선택';
    }
    if (canThrow) return '윷을 던져주세요';
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

class _YutBoardNodePainter extends CustomPainter {
  const _YutBoardNodePainter();

  static const _red = Color(0xFFFF6B63);
  static const _blue = Color(0xFF45D8FF);
  static const _gold = Color(0xFFFFD85B);
  static const _violet = Color(0xFFD878FF);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (var position = 1; position <= 29; position++) {
      final center = _projectYutPoint(rect, _logicalYutPoint(position));
      final isCorner = const {5, 10, 15, 20}.contains(position);
      final isCenter = position == 23;
      final radius =
          size.width * (isCorner ? 0.031 : (isCenter ? 0.025 : 0.017));
      final accent = _accentFor(position);

      canvas.drawCircle(
        center.translate(0, radius * 0.30),
        radius * 1.08,
        Paint()..color = const Color(0x77331B22),
      );
      canvas.drawCircle(
        center,
        radius * 1.65,
        Paint()
          ..color = accent.withValues(alpha: isCorner ? 0.34 : 0.24)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.85),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white,
              Color.lerp(accent, Colors.white, 0.62)!,
              accent,
              Color.lerp(accent, Colors.black, 0.32)!,
            ],
            stops: const [0, 0.26, 0.72, 1],
            center: const Alignment(-0.34, -0.40),
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFFFF2BD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCorner ? 2.4 : 1.5,
      );
      if (isCorner || isCenter) {
        canvas.drawCircle(
          center,
          radius * 0.62,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        for (var i = 0; i < 4; i++) {
          final angle = (pi / 2) * i;
          canvas.drawLine(
            center + Offset(cos(angle), sin(angle)) * radius * 0.22,
            center + Offset(cos(angle), sin(angle)) * radius * 0.52,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.82)
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
  }

  Color _accentFor(int position) {
    if (position == 5) return _red;
    if (position == 10) return _blue;
    if (position == 15) return _gold;
    if (position == 20) return _violet;
    if (position <= 5) return _red;
    if (position <= 10) return _blue;
    if (position <= 20) return _gold;
    if (position == 23) return _blue;
    if (position == 21 || position == 22 || position == 26 || position == 27) {
      return _red;
    }
    return _blue;
  }

  @override
  bool shouldRepaint(covariant _YutBoardNodePainter oldDelegate) => false;
}

class _YutThrowButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final bool compact;
  final VoidCallback onTap;

  const _YutThrowButton({
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
      label: '윷 던지기',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFFFFD786), Color(0xFFC77425)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFFFE9B0)
                  : Colors.white.withValues(alpha: 0.14),
              width: enabled ? 1.5 : 1,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _YutStickGlyph(enabled: enabled, compact: compact),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading ? '던지는 중' : '윷 던지기',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15 : 17,
                        fontWeight: FontWeight.w900,
                        color: enabled
                            ? const Color(0xFF4A2512)
                            : Colors.white38,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loading ? '결과 확인 중' : '윷을 던져보세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? const Color(0xFF70401E)
                            : Colors.white30,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YutStickGlyph extends StatelessWidget {
  final bool enabled;
  final bool compact;

  const _YutStickGlyph({required this.enabled, required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = compact ? 28.0 : 32.0;
    final height = compact ? 36.0 : 40.0;
    final stickColor = enabled
        ? const [Color(0xFFFFE5A7), Color(0xFFAD592A)]
        : const [Color(0xFF7A858A), Color(0xFF465158)];

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (offset, angle) in const [
            (Offset(-6, 2), -0.33),
            (Offset(0, -2), 0.04),
            (Offset(6, 2), 0.33),
          ])
            Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: compact ? 7 : 8,
                  height: compact ? 31 : 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: stickColor,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: enabled ? const Color(0xFF7D3D1E) : Colors.white24,
                    ),
                  ),
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

// ─── Yut Stick Throw Animation ─────────────────────────────────────────────

enum _ParticleShape { circle, diamond, petal, star }

class _YutThrowOverlay extends StatelessWidget {
  final Animation<double> animation;
  final String? resultName;
  final String yutSkin;

  const _YutThrowOverlay({
    required this.animation,
    this.resultName,
    this.yutSkin = 'base',
  });

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
                painter: _YutSticksPainter(
                  t: t,
                  resultName: resultName,
                  yutSkin: yutSkin,
                ),
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
  final String yutSkin;

  _YutSticksPainter({required this.t, this.resultName, this.yutSkin = 'base'});

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

    // 스킨별 이펙트 (던지는 중에만)
    if (t > 0.05 && t < 0.98) _drawSkinEffect(canvas, size, cx);

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

  void _drawSkinEffect(Canvas canvas, Size size, double cx) {
    final rng = sin(t * 31.4 + 7.3); // pseudo-random seed from t
    switch (yutSkin) {
      case 'fire':
        _drawLightning(canvas, size, cx);
        _drawParticles(
          canvas,
          size,
          cx,
          count: 22,
          seed: rng,
          color1: const Color(0xFFFF6B00),
          color2: const Color(0xFFFFD700),
        );
      case 'cherry':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 20,
          seed: rng,
          color1: const Color(0xFFFFB7C5),
          color2: const Color(0xFFFF69B4),
          shape: _ParticleShape.petal,
        );
      case 'crystal':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 18,
          seed: rng,
          color1: const Color(0xFF88C0D0),
          color2: const Color(0xFFB0E0FF),
          shape: _ParticleShape.diamond,
        );
      case 'bamboo':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 16,
          seed: rng,
          color1: const Color(0xFF8BC34A),
          color2: const Color(0xFFC5E1A5),
        );
      case 'legend':
        _drawRainbowBurst(canvas, size, cx, seed: rng);
      case 'stone':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 14,
          seed: rng,
          color1: const Color(0xFF9E9E9E),
          color2: const Color(0xFFBDBDBD),
        );
      case 'gold':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 20,
          seed: rng,
          color1: const Color(0xFFFFD700),
          color2: const Color(0xFFFFF8DC),
          shape: _ParticleShape.star,
        );
      case 'autumn':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 18,
          seed: rng,
          color1: const Color(0xFFFF8C00),
          color2: const Color(0xFFFFD700),
          shape: _ParticleShape.petal,
        );
      case 'wave':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 20,
          seed: rng,
          color1: const Color(0xFF0077B6),
          color2: const Color(0xFF00B4D8),
          shape: _ParticleShape.diamond,
        );
      case 'wind':
        _drawParticles(
          canvas,
          size,
          cx,
          count: 24,
          seed: rng,
          color1: const Color(0xFFB0BEC5),
          color2: const Color(0xFFECEFF1),
        );
      case 'storm':
        _drawLightning(canvas, size, cx);
        _drawParticles(
          canvas,
          size,
          cx,
          count: 16,
          seed: rng,
          color1: const Color(0xFF455A64),
          color2: const Color(0xFF78909C),
        );
      default:
        break;
    }
  }

  void _drawLightning(Canvas canvas, Size size, double cx) {
    final paint = Paint()
      ..color = const Color(
        0xFFFFFF00,
      ).withValues(alpha: (0.6 + sin(t * 9) * 0.3).clamp(0.0, 1.0))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final seeds = [0.0, 0.38, 0.73];
    for (final s in seeds) {
      final x = cx + (s - 0.5) * size.width * 0.5;
      final path = Path();
      path.moveTo(x, size.height * 0.05);
      path.lineTo(x - 10, size.height * 0.22);
      path.lineTo(x + 8, size.height * 0.22);
      path.lineTo(x - 6, size.height * 0.4);
      path.lineTo(x + 12, size.height * 0.4);
      path.lineTo(x - 4, size.height * 0.6);
      canvas.drawPath(path, paint);
    }
    // flash overlay
    final flash = Paint()
      ..color = const Color(
        0xFFFFFF88,
      ).withValues(alpha: (sin(t * 18) * 0.12).clamp(0.0, 0.18));
    canvas.drawRect(Offset.zero & size, flash);
  }

  void _drawRainbowBurst(
    Canvas canvas,
    Size size,
    double cx, {
    required double seed,
  }) {
    const colors = [
      Color(0xFFFF0000),
      Color(0xFFFF7700),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF0088FF),
      Color(0xFF8800FF),
    ];
    final center = Offset(cx, size.height * 0.45);
    for (var k = 0; k < 24; k++) {
      final angle = (k / 24) * 6.283 + t * 3.14;
      final r = (60 + sin(t * 5 + k) * 30) * t;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      final col = colors[k % colors.length];
      canvas.drawCircle(
        Offset(x, y),
        4 + sin(t * 8 + k) * 2,
        Paint()..color = col.withValues(alpha: ((1 - t) * 0.9).clamp(0.0, 1.0)),
      );
    }
  }

  void _drawParticles(
    Canvas canvas,
    Size size,
    double cx, {
    required int count,
    required double seed,
    required Color color1,
    required Color color2,
    _ParticleShape shape = _ParticleShape.circle,
  }) {
    final center = Offset(cx, size.height * 0.45);
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 6.283 + seed * 2.1 + i * 0.37;
      final speed = 0.5 + ((i * 7 + 3) % 10) / 10.0;
      final r = (size.shortestSide * 0.3 * t * speed).clamp(
        0.0,
        size.shortestSide * 0.5,
      );
      final x = center.dx + cos(angle) * r + sin(t * 4 + i) * 6;
      final y = center.dy + sin(angle) * r + t * t * 40;
      final alpha = ((1 - t * 0.85) * 0.9).clamp(0.0, 1.0);
      final col = i.isEven
          ? color1.withValues(alpha: alpha)
          : color2.withValues(alpha: alpha);
      final radius = (3.0 + ((i * 3 + 1) % 5)).toDouble();
      switch (shape) {
        case _ParticleShape.circle:
          canvas.drawCircle(Offset(x, y), radius, Paint()..color = col);
        case _ParticleShape.diamond:
          final path = Path()
            ..moveTo(x, y - radius * 1.4)
            ..lineTo(x + radius, y)
            ..lineTo(x, y + radius * 1.4)
            ..lineTo(x - radius, y)
            ..close();
          canvas.drawPath(path, Paint()..color = col);
        case _ParticleShape.petal:
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: radius * 2,
              height: radius * 3.5,
            ),
            Paint()..color = col,
          );
        case _ParticleShape.star:
          for (var s = 0; s < 4; s++) {
            final sa = s * 1.571 + angle;
            canvas.drawLine(
              Offset(x + cos(sa) * radius * 1.8, y + sin(sa) * radius * 1.8),
              Offset(x - cos(sa) * radius * 0.5, y - sin(sa) * radius * 0.5),
              Paint()
                ..color = col
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke,
            );
          }
      }
    }
  }

  void _drawStick(Canvas canvas, bool showFlat) {
    const w = 78.0;
    const h = 20.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(10),
    );

    final (flatColor, roundColor, grainColor) = switch (yutSkin) {
      'bamboo' => (
        const Color(0xFF8BC34A),
        const Color(0xFF33691E),
        const Color(0xFF558B2F),
      ),
      'gold' => (
        const Color(0xFFFFD700),
        const Color(0xFFB8860B),
        const Color(0xFFDAA520),
      ),
      'crystal' => (
        const Color(0xFF88C0D0),
        const Color(0xFF2E4A6E),
        const Color(0xFF5E81AC),
      ),
      'fire' => (
        const Color(0xFFFF6B00),
        const Color(0xFFB71C1C),
        const Color(0xFFFF8C00),
      ),
      'legend' => (
        const Color(0xFFAB47BC),
        const Color(0xFF4A148C),
        const Color(0xFFCE93D8),
      ),
      'cherry' => (
        const Color(0xFFFFB7C5),
        const Color(0xFFE91E63),
        const Color(0xFFFF69B4),
      ),
      'stone' => (
        const Color(0xFF9E9E9E),
        const Color(0xFF424242),
        const Color(0xFF616161),
      ),
      _ => (
        const Color(0xFFDEB887),
        const Color(0xFF5C3A21),
        const Color(0xFFC49A6C),
      ),
    };

    final fill = Paint()..color = showFlat ? flatColor : roundColor;
    canvas.drawRRect(rrect, fill);

    // grain lines
    final grainLine = Paint()
      ..color = grainColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final dx in [-20.0, 0.0, 20.0]) {
      canvas.drawLine(Offset(dx, -6), Offset(dx, 6), grainLine);
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
      old.t != t || old.resultName != resultName || old.yutSkin != yutSkin;
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
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Color(0xFF79C8C4),
                size: 16,
              ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
