import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Drawing data types
// ─────────────────────────────────────────────────────────────────────────────

class _Pt {
  final double x, y; // normalized 0.0–1.0
  const _Pt(this.x, this.y);
}

class _Stroke {
  final Color color;
  final double size;
  final List<_Pt> pts = [];
  _Stroke({required this.color, required this.size});
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas Painter
// ─────────────────────────────────────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  final List<_Stroke> strokes;
  _CanvasPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );
    for (final stroke in strokes) {
      if (stroke.pts.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final pts = stroke.pts;
      if (pts.length == 1) {
        canvas.drawCircle(
          Offset(pts[0].x * size.width, pts[0].y * size.height),
          stroke.size / 2,
          Paint()..color = stroke.color..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(pts[0].x * size.width, pts[0].y * size.height);
      for (int i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final curr = pts[i];
        final mx = ((prev.x + curr.x) / 2) * size.width;
        final my = ((prev.y + curr.y) / 2) * size.height;
        path.quadraticBezierTo(
          prev.x * size.width, prev.y * size.height, mx, my);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CatchScreen extends StatefulWidget {
  const CatchScreen({super.key});
  @override
  State<CatchScreen> createState() => _CatchScreenState();
}

class _CatchScreenState extends State<CatchScreen> {
  final _socket = SocketService();

  // ── local (drawer) strokes ─────────────────────────────────────────────────
  final List<_Stroke> _myStrokes = [];
  _Stroke? _currentStroke;

  // ── remote (guesser view) strokes ─────────────────────────────────────────
  final List<_Stroke> _remoteStrokes = [];
  _Stroke? _remoteCurrentStroke;

  // ── tool state ─────────────────────────────────────────────────────────────
  int _colorIdx = 0;
  int _sizeIdx = 1;
  bool _erasing = false;

  static const _colors = [
    Color(0xFF1A1A1A), // black
    Color(0xFFE53935), // red
    Color(0xFFFF7043), // orange
    Color(0xFFFDD835), // yellow
    Color(0xFF43A047), // green
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFBDBDBD), // light grey (pastel)
  ];
  static const _sizes = [3.0, 6.0, 13.0];

  // ── guess input ────────────────────────────────────────────────────────────
  final TextEditingController _guessCtrl = TextEditingController();
  final FocusNode _guessFocus = FocusNode();

  // ── timer ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  int _timeLeft = 60;

  // ── emit throttle ─────────────────────────────────────────────────────────
  int _lastEmitMs = 0;

  bool get _isDrawer => _socket.catchDrawer == _socket.userId;
  bool get _isHost => _socket.lobbyHost == _socket.userId;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onState);
    _socket.registerCatchCallbacks(_onRemoteDraw, _onRemoteClear);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _guessCtrl.dispose();
    _guessFocus.dispose();
    _socket.removeListener(_onState);
    _socket.unregisterCatchCallbacks();
    super.dispose();
  }

  // ── state handler ──────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    final phase = _socket.catchPhase;
    if (phase == 'drawing') {
      if (_timer == null) _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
    setState(() {});
  }

  void _startTimer() {
    _timeLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          _timer?.cancel();
          _timer = null;
          if (_isHost) _socket.timeoutCatch();
        }
      });
    });
  }

  // ── remote draw callbacks ──────────────────────────────────────────────────

  void _onRemoteDraw(Map<String, dynamic> data) {
    final x = (data['x'] as num).toDouble();
    final y = (data['y'] as num).toDouble();
    final newStroke = data['s'] as bool? ?? false;
    final cIdx = (data['c'] as int?) ?? 0;
    final sIdx = (data['sz'] as int?) ?? 1;

    if (newStroke || _remoteCurrentStroke == null) {
      final color = (cIdx == 7) ? Colors.white : _colors[cIdx.clamp(0, 7)];
      final size = _sizes[sIdx.clamp(0, 2)];
      final stroke = _Stroke(color: color, size: size);
      _remoteStrokes.add(stroke);
      _remoteCurrentStroke = stroke;
    }
    _remoteCurrentStroke!.pts.add(_Pt(x, y));
    if (mounted) setState(() {});
  }

  void _onRemoteClear() {
    _remoteStrokes.clear();
    _remoteCurrentStroke = null;
    if (mounted) setState(() {});
  }

  // ── local drawing ──────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d, Size canvasSize) {
    if (!_isDrawer || _socket.catchPhase != 'drawing') return;
    final nx = d.localPosition.dx / canvasSize.width;
    final ny = d.localPosition.dy / canvasSize.height;
    final color = _erasing ? Colors.white : _colors[_colorIdx];
    final size = _erasing ? 28.0 : _sizes[_sizeIdx];
    final cIdx = _erasing ? 7 : _colorIdx;
    final sIdx = _erasing ? 2 : _sizeIdx;
    final stroke = _Stroke(color: color, size: size);
    stroke.pts.add(_Pt(nx, ny));
    setState(() {
      _myStrokes.add(stroke);
      _currentStroke = stroke;
    });
    _socket.sendCatchDraw(nx, ny, true, cIdx, sIdx);
    _lastEmitMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPanUpdate(DragUpdateDetails d, Size canvasSize) {
    if (!_isDrawer || _currentStroke == null || _socket.catchPhase != 'drawing') return;
    final nx = d.localPosition.dx / canvasSize.width;
    final ny = d.localPosition.dy / canvasSize.height;
    setState(() => _currentStroke!.pts.add(_Pt(nx, ny)));
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmitMs >= 16) {
      final cIdx = _erasing ? 7 : _colorIdx;
      final sIdx = _erasing ? 2 : _sizeIdx;
      _socket.sendCatchDraw(nx, ny, false, cIdx, sIdx);
      _lastEmitMs = now;
    }
  }

  void _onPanEnd(DragEndDetails _) {
    _currentStroke = null;
  }

  void _clearCanvas() {
    HapticFeedback.lightImpact();
    setState(() {
      _myStrokes.clear();
      _currentStroke = null;
    });
    _socket.sendCatchClear();
  }

  // ── guess ──────────────────────────────────────────────────────────────────

  void _submitGuess() {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty) return;
    _guessCtrl.clear();
    HapticFeedback.selectionClick();
    _socket.guessCatch(text);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final phase = sock.catchPhase;

    return GameScaffold(
      title: '🎨 캐치마인드',
      actions: [const GameMenuButton()],
      child: LayoutBuilder(builder: (ctx, box) {
        final compact = box.maxWidth < 430;

        // 게임 전 대기
        if (!sock.catchActive && phase != 'gameover') {
          return _WaitingView(
            compact: compact,
            isHost: _isHost,
            onStart: () => sock.startCatch(maxRounds: 6),
          );
        }

        // 게임 종료
        if (phase == 'gameover') {
          return _GameOverView(
            compact: compact,
            sock: sock,
            isHost: _isHost,
            onReset: sock.resetCatch,
          );
        }

        // 라운드 결과
        if (phase == 'guessed' || phase == 'timeout') {
          return _RoundResultView(
            compact: compact,
            sock: sock,
            isHost: _isHost,
            onNext: sock.nextCatchRound,
          );
        }

        // 진행 중 (drawing)
        return _GameView(
          compact: compact,
          sock: sock,
          isDrawer: _isDrawer,
          timeLeft: _timeLeft,
          myStrokes: _myStrokes,
          remoteStrokes: _remoteStrokes,
          colorIdx: _colorIdx,
          sizeIdx: _sizeIdx,
          erasing: _erasing,
          guessCtrl: _guessCtrl,
          guessFocus: _guessFocus,
          onColorChanged: (i) => setState(() { _colorIdx = i; _erasing = false; }),
          onSizeChanged: (i) => setState(() => _sizeIdx = i),
          onEraseToggle: () => setState(() => _erasing = !_erasing),
          onClear: _clearCanvas,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onGuess: _submitGuess,
          onHint: sock.requestCatchHint,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Waiting View
// ─────────────────────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final bool compact, isHost;
  final VoidCallback onStart;
  const _WaitingView({required this.compact, required this.isHost, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎨', style: TextStyle(fontSize: compact ? 60 : 80)),
            const SizedBox(height: 16),
            Text(
              '캐치마인드',
              style: GoogleFonts.notoSans(
                fontSize: compact ? 24 : 30,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '출제자가 그림을 그리면\n정답자가 맞추는 게임!',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (isHost) ...[
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('게임 시작!',
                      style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              Text('6라운드 진행 (3 + 3턴)', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
            ] else
              Text('방장이 시작하길 기다려요...', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game View (drawing phase)
// ─────────────────────────────────────────────────────────────────────────────

class _GameView extends StatelessWidget {
  final bool compact, isDrawer, erasing;
  final SocketService sock;
  final int timeLeft, colorIdx, sizeIdx;
  final List<_Stroke> myStrokes, remoteStrokes;
  final TextEditingController guessCtrl;
  final FocusNode guessFocus;
  final void Function(int) onColorChanged, onSizeChanged;
  final VoidCallback onEraseToggle, onClear, onGuess, onHint;
  final void Function(DragStartDetails, Size) onPanStart;
  final void Function(DragUpdateDetails, Size) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;

  const _GameView({
    required this.compact,
    required this.isDrawer,
    required this.erasing,
    required this.sock,
    required this.timeLeft,
    required this.colorIdx,
    required this.sizeIdx,
    required this.myStrokes,
    required this.remoteStrokes,
    required this.guessCtrl,
    required this.guessFocus,
    required this.onColorChanged,
    required this.onSizeChanged,
    required this.onEraseToggle,
    required this.onClear,
    required this.onGuess,
    required this.onHint,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  static const _colors = [
    Color(0xFF1A1A1A),
    Color(0xFFE53935),
    Color(0xFFFF7043),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFBDBDBD),
  ];
  static const _sizeLabels = ['S', 'M', 'L'];

  @override
  Widget build(BuildContext context) {
    final word = sock.catchWord;
    final wordLen = sock.catchWordLen;
    final hint = sock.catchHint;
    final round = sock.catchRound;
    final maxRounds = sock.catchMaxRounds;
    final drawerName = sock.nameOf(sock.catchDrawer);

    // Header
    final header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      color: kCard,
      child: Row(
        children: [
          // Round info
          Text(
            'R$round/$maxRounds',
            style: GoogleFonts.notoSans(
              color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isDrawer
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '단어: $word',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: kPrimary,
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Hint / blank display
                      Text(
                        hint != null
                            ? hint.split('').join(' ')
                            : List.filled(wordLen, '_').join('  '),
                        style: GoogleFonts.notoSans(
                          color: hint != null ? kPrimary : kTextMuted,
                          fontSize: compact ? 16 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        '$wordLen 글자  •  $drawerName 이(가) 그리는 중',
                        style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 10),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          // Timer
          _TimerBadge(timeLeft: timeLeft, compact: compact),
        ],
      ),
    );

    // Canvas area
    final strokes = isDrawer ? myStrokes : remoteStrokes;
    final canvas = LayoutBuilder(builder: (_, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: isDrawer ? (d) => onPanStart(d, size) : null,
        onPanUpdate: isDrawer ? (d) => onPanUpdate(d, size) : null,
        onPanEnd: isDrawer ? onPanEnd : null,
        child: CustomPaint(
          size: size,
          painter: _CanvasPainter(List.of(strokes)),
        ),
      );
    });

    // Bottom: tools (drawer) or guess input (guesser)
    final bottom = isDrawer
        ? _DrawerTools(
            compact: compact,
            colorIdx: colorIdx,
            sizeIdx: sizeIdx,
            erasing: erasing,
            colors: _colors,
            sizeLabels: _sizeLabels,
            onColorChanged: onColorChanged,
            onSizeChanged: onSizeChanged,
            onEraseToggle: onEraseToggle,
            onClear: onClear,
          )
        : _GuessPanel(
            compact: compact,
            ctrl: guessCtrl,
            focus: guessFocus,
            guessLog: sock.catchGuessLog,
            onGuess: onGuess,
            onHint: onHint,
            hint: hint,
          );

    final bottomHeight = compact ? 110.0 : 120.0;

    return Column(
      children: [
        header,
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                bottom: bottomHeight,
                child: canvas,
              ),
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: bottomHeight,
                child: bottom,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timer Badge
// ─────────────────────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  final int timeLeft;
  final bool compact;
  const _TimerBadge({required this.timeLeft, required this.compact});

  @override
  Widget build(BuildContext context) {
    final urgent = timeLeft <= 10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (urgent ? kError : kPrimary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: urgent ? kError : kPrimary),
      ),
      child: Text(
        '$timeLeft초',
        style: GoogleFonts.notoSans(
          color: urgent ? kError : kPrimary,
          fontSize: compact ? 13 : 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawer Tools
// ─────────────────────────────────────────────────────────────────────────────

class _DrawerTools extends StatelessWidget {
  final bool compact, erasing;
  final int colorIdx, sizeIdx;
  final List<Color> colors;
  final List<String> sizeLabels;
  final void Function(int) onColorChanged, onSizeChanged;
  final VoidCallback onEraseToggle, onClear;

  const _DrawerTools({
    required this.compact,
    required this.erasing,
    required this.colorIdx,
    required this.sizeIdx,
    required this.colors,
    required this.sizeLabels,
    required this.onColorChanged,
    required this.onSizeChanged,
    required this.onEraseToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final dotSz = compact ? 28.0 : 32.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16, vertical: compact ? 8 : 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color palette
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < colors.length; i++)
                GestureDetector(
                  onTap: () => onColorChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: dotSz,
                    height: dotSz,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (!erasing && colorIdx == i)
                            ? kPrimary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: (!erasing && colorIdx == i)
                          ? [BoxShadow(color: kPrimary.withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Size + erase + clear
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < sizeLabels.length; i++)
                GestureDetector(
                  onTap: () => onSizeChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 34,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: (!erasing && sizeIdx == i)
                          ? kPrimary.withValues(alpha: 0.12)
                          : kCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (!erasing && sizeIdx == i) ? kPrimary : kBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(sizeLabels[i],
                          style: GoogleFonts.notoSans(
                            color: (!erasing && sizeIdx == i) ? kPrimary : kTextMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              // Eraser
              GestureDetector(
                onTap: onEraseToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 28,
                  decoration: BoxDecoration(
                    color: erasing ? kError.withValues(alpha: 0.1) : kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: erasing ? kError : kBorder),
                  ),
                  child: Center(
                    child: Text('🧹', style: TextStyle(fontSize: compact ? 14 : 16)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Clear
              GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 34,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder),
                  ),
                  child: Center(
                    child: Text('🗑️', style: TextStyle(fontSize: compact ? 14 : 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guess Panel
// ─────────────────────────────────────────────────────────────────────────────

class _GuessPanel extends StatelessWidget {
  final bool compact;
  final TextEditingController ctrl;
  final FocusNode focus;
  final List<Map<String, dynamic>> guessLog;
  final VoidCallback onGuess, onHint;
  final String? hint;

  const _GuessPanel({
    required this.compact,
    required this.ctrl,
    required this.focus,
    required this.guessLog,
    required this.onGuess,
    required this.onHint,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Guess log (scrollable, compact)
          if (guessLog.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                itemCount: guessLog.length,
                itemBuilder: (_, i) {
                  final item = guessLog[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      '${item['text']}',
                      style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          // Input row
          Padding(
            padding: EdgeInsets.fromLTRB(10, guessLog.isEmpty ? 10 : 0, 10, 10),
            child: Row(
              children: [
                // Hint button
                if (hint == null)
                  GestureDetector(
                    onTap: onHint,
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kGold.withValues(alpha: 0.5)),
                      ),
                      child: const Center(child: Text('💡', style: TextStyle(fontSize: 18))),
                    ),
                  ),
                // Text field
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    focusNode: focus,
                    onSubmitted: (_) => onGuess(),
                    textInputAction: TextInputAction.send,
                    style: GoogleFonts.notoSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '정답 입력...',
                      hintStyle: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: kPrimary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                GestureDetector(
                  onTap: onGuess,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Round Result View
// ─────────────────────────────────────────────────────────────────────────────

class _RoundResultView extends StatelessWidget {
  final bool compact;
  final SocketService sock;
  final bool isHost;
  final VoidCallback onNext;

  const _RoundResultView({
    required this.compact,
    required this.sock,
    required this.isHost,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final guessed = sock.catchPhase == 'guessed';
    final word = sock.catchWord ?? '';
    final userId = sock.userId ?? '';
    final players = sock.lobbyPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '');
    final myScore = sock.catchScores[userId] ?? 0;
    final opScore = sock.catchScores[opId] ?? 0;

    return Padding(
      padding: EdgeInsets.all(compact ? 20 : 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            guessed ? '🎉 정답!' : '⏰ 시간 초과!',
            style: GoogleFonts.notoSans(
              fontSize: compact ? 30 : 38,
              fontWeight: FontWeight.w900,
              color: guessed ? kSuccess : kError,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              word,
              style: GoogleFonts.notoSans(
                fontSize: compact ? 28 : 36,
                fontWeight: FontWeight.w900,
                color: kText,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScorePill(
                label: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
                score: myScore,
                isMe: true,
                compact: compact,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('vs',
                    style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 16)),
              ),
              _ScorePill(
                label: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
                score: opScore,
                isMe: false,
                compact: compact,
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (isHost)
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('다음 라운드 →',
                  style: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w800)),
            )
          else
            Text('방장이 다음 라운드를 시작하길 기다려요',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int score;
  final bool isMe, compact;
  const _ScorePill({required this.label, required this.score, required this.isMe, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.notoSans(
                color: isMe ? kPrimary : kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
        Text('$score',
            style: GoogleFonts.notoSans(
                color: kText, fontSize: compact ? 36 : 44, fontWeight: FontWeight.w900)),
        Text('점', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Game Over View
// ─────────────────────────────────────────────────────────────────────────────

class _GameOverView extends StatelessWidget {
  final bool compact;
  final SocketService sock;
  final bool isHost;
  final VoidCallback onReset;

  const _GameOverView({required this.compact, required this.sock, required this.isHost, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final userId = sock.userId ?? '';
    final winner = sock.catchGameWinner;
    final iWon = winner == userId;
    final isDraw = winner == 'draw';
    final players = sock.lobbyPlayers;
    final opId = players.firstWhere((p) => p != userId, orElse: () => '');

    return Padding(
      padding: EdgeInsets.all(compact ? 24 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isDraw ? '🤝 무승부!' : (iWon ? '🏆 승리!' : '😢 패배'),
            style: GoogleFonts.notoSans(
              fontSize: compact ? 34 : 44,
              fontWeight: FontWeight.w900,
              color: isDraw ? kGold : (iWon ? kSuccess : kError),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ScorePill(
                label: sock.nameOf(userId).isNotEmpty ? sock.nameOf(userId) : '나',
                score: sock.catchScores[userId] ?? 0,
                isMe: true,
                compact: compact,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('vs', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 18)),
              ),
              _ScorePill(
                label: sock.nameOf(opId).isNotEmpty ? sock.nameOf(opId) : '상대',
                score: sock.catchScores[opId] ?? 0,
                isMe: false,
                compact: compact,
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (isHost)
            ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          else
            Text('방장이 다시 시작하길 기다려요',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
