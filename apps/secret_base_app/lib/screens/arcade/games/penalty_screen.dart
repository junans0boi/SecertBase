import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Penalty shootout — behind-the-kicker view.
// The goal owns ONE coordinate system (_PitchGeometry): the 3x3 target cells,
// the ball's flight and the keeper's dive all resolve to the same cell centers,
// so a matching pick visually collides and a different pick visually scores.
// ─────────────────────────────────────────────────────────────────────────────

class _PitchGeometry {
  final Size size;
  late final Rect goal;
  late final Offset spot; // penalty spot (ball position)

  _PitchGeometry(this.size) {
    final w = size.width * 0.74;
    final h = math.min(size.height * 0.40, 132.0);
    goal = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.135 + h / 2),
      width: w,
      height: h,
    );
    spot = Offset(size.width / 2, size.height * 0.82);
  }

  /// Center of a 3x3 target cell. dir: 0..8, row-major from top-left.
  Offset cellCenter(int dir) {
    final col = dir % 3;
    final row = dir ~/ 3;
    return Offset(
      goal.left + (col + 0.5) * goal.width / 3,
      goal.top + (row + 0.5) * goal.height / 3,
    );
  }

  int? cellAt(Offset p) {
    final hit = goal.inflate(10);
    if (!hit.contains(p)) return null;
    final col = ((p.dx - goal.left) / (goal.width / 3)).floor().clamp(0, 2);
    final row = ((p.dy - goal.top) / (goal.height / 3)).floor().clamp(0, 2);
    return row * 3 + col;
  }
}

class PenaltyScreen extends StatefulWidget {
  const PenaltyScreen({super.key});

  @override
  State<PenaltyScreen> createState() => _PenaltyScreenState();
}

class _PenaltyScreenState extends State<PenaltyScreen>
    with TickerProviderStateMixin {
  final _socket = SocketService();

  late final AnimationController _shotCtrl;

  int _animatedRounds = 0; // rounds already played back
  int? _animKickerDir;
  int? _animKeeperDir;
  bool? _animIsGoal;
  bool _isAnimating = false;

  int? _selectedTarget;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_onSocket);
    _shotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _shotCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _isAnimating = false;
            _animKickerDir = null;
            _animKeeperDir = null;
            _animIsGoal = null;
            _shotCtrl.reset();
          });
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Don't replay history when (re)entering mid-game.
      final rounds = (_socket.penaltyState?['rounds'] as List?) ?? const [];
      _animatedRounds = rounds.length;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _socket.removeListener(_onSocket);
    _shotCtrl.dispose();
    super.dispose();
  }

  void _onSocket() {
    if (!mounted) return;
    final state = _socket.penaltyState;
    if (state != null && !_isAnimating) {
      final rounds = (state['rounds'] as List?) ?? const [];
      if (rounds.length > _animatedRounds) {
        final last = Map<String, dynamic>.from(rounds.last as Map);
        _animatedRounds = rounds.length;
        _animKickerDir = ((last['kickerDir'] as num?) ?? 4).toInt();
        _animKeeperDir = ((last['keeperDir'] as num?) ?? 4).toInt();
        _animIsGoal = last['isGoal'] == true;
        _isAnimating = true;
        _selectedTarget = null;
        _shotCtrl.forward(from: 0);
      }
    }
    setState(() {});
  }

  void _submit() {
    final target = _selectedTarget;
    if (target == null) return;
    _socket.submitPenaltyChoice(target);
    setState(() => _selectedTarget = null);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String get _myId => _socket.userId ?? '';

  bool get _isKicker {
    final state = _socket.penaltyState;
    return state != null && state['kicker']?.toString() == _myId;
  }

  bool get _hasSubmitted {
    final subs =
        (_socket.penaltyState?['submissions'] as Map<String, dynamic>?) ?? {};
    return subs.containsKey(_myId);
  }

  String _opponentId(Map<String, dynamic> scores) {
    for (final k in scores.keys) {
      if (k != _myId) return k;
    }
    return '';
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _socket.penaltyState;
    final isPlaying = state?['status'] == 'playing';
    final isFinished = state?['status'] == 'finished';

    return GameScaffold(
      title: '승부차기 ⚽',
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2A1A), Color(0xFF14381F)],
          ),
        ),
        child: SafeArea(
          child: state == null
              ? Center(
                  child: Text(
                    '게임을 준비하는 중...',
                    style: GoogleFonts.notoSans(color: Colors.white70),
                  ),
                )
              : Column(
                  children: [
                    _buildScoreboard(state),
                    const SizedBox(height: 6),
                    Expanded(child: _buildPitch(state)),
                    if (isPlaying) _buildControls(state),
                    if (isFinished) _buildResult(state),
                  ],
                ),
        ),
      ),
    );
  }

  // ── scoreboard: PK dots, 5 kicks each ─────────────────────────────────────

  Widget _buildScoreboard(Map<String, dynamic> state) {
    final scores = (state['scores'] as Map<String, dynamic>?) ?? {};
    final rounds = (state['rounds'] as List?) ?? const [];
    final oppId = _opponentId(scores);
    final myKicks = rounds
        .where((r) => (r as Map)['kicker'].toString() == _myId)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0B1F12).withValues(alpha: 0.9),
            const Color(0xFF122B18).withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _scoreSide(
            '나',
            ((scores[_myId] as num?) ?? 0).toInt(),
            rounds,
            _myId,
            CrossAxisAlignment.start,
          ),
          Column(
            children: [
              Text(
                'PENALTY',
                style: GoogleFonts.orbitron(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${math.min(myKicks + 1, 5)} / 5',
                style: GoogleFonts.orbitron(
                  color: Colors.amberAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          _scoreSide(
            '상대',
            ((scores[oppId] as num?) ?? 0).toInt(),
            rounds,
            oppId,
            CrossAxisAlignment.end,
          ),
        ],
      ),
    );
  }

  Widget _scoreSide(
    String label,
    int score,
    List rounds,
    String pid,
    CrossAxisAlignment align,
  ) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.notoSans(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$score',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: List.generate(5, (i) => _pkDot(rounds, pid, i))),
      ],
    );
  }

  Widget _pkDot(List rounds, String pid, int attempt) {
    bool? isGoal;
    int count = 0;
    for (final r in rounds) {
      final m = r as Map;
      if (m['kicker'].toString() == pid) {
        if (count == attempt) {
          isGoal = m['isGoal'] == true;
          break;
        }
        count++;
      }
    }
    final color = isGoal == null
        ? Colors.white24
        : (isGoal ? const Color(0xFF4ADE80) : const Color(0xFFF87171));
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white38, width: 1),
      ),
    );
  }

  // ── pitch scene ────────────────────────────────────────────────────────────

  Widget _buildPitch(Map<String, dynamic> state) {
    final canPick =
        state['status'] == 'playing' && !_hasSubmitted && !_isAnimating;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final geo = _PitchGeometry(size);
            return GestureDetector(
              key: const Key('penalty_pitch'),
              behavior: HitTestBehavior.opaque,
              onTapUp: canPick
                  ? (d) {
                      final cell = geo.cellAt(d.localPosition);
                      if (cell != null) {
                        setState(() => _selectedTarget = cell);
                      }
                    }
                  : null,
              child: AnimatedBuilder(
                animation: _shotCtrl,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _PitchPainter(
                    progress: _isAnimating ? _shotCtrl.value : null,
                    kickerDir: _animKickerDir,
                    keeperDir: _animKeeperDir,
                    isGoal: _animIsGoal,
                    showGrid: canPick,
                    selectedCell: canPick ? _selectedTarget : null,
                    isKickerView: _isKicker,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── controls ───────────────────────────────────────────────────────────────

  Widget _buildControls(Map<String, dynamic> state) {
    final isKicker = _isKicker;

    if (_isAnimating) {
      return _controlShell(
        child: Text(
          '⚽ 킥! 결과를 확인하세요...',
          style: GoogleFonts.notoSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_hasSubmitted) {
      return _controlShell(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.amberAccent,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isKicker ? '상대 골키퍼가 다이빙 방향을 고르는 중...' : '상대 키커가 슛 코스를 고르는 중...',
              style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final hasPick = _selectedTarget != null;
    return _controlShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isKicker ? '⚽ 골대에서 노릴 코스를 탭하세요' : '🧤 막으러 몸을 날릴 코스를 탭하세요',
            style: GoogleFonts.notoSans(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: hasPick ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isKicker
                    ? Colors.amberAccent
                    : Colors.cyanAccent,
                disabledBackgroundColor: Colors.white12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                hasPick
                    ? (isKicker ? '이 코스로 슛! ⚽' : '이 코스로 다이빙! 🧤')
                    : '코스를 먼저 선택하세요',
                style: GoogleFonts.notoSans(
                  color: hasPick ? Colors.black : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlShell({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Center(child: child),
    );
  }

  // ── result ─────────────────────────────────────────────────────────────────

  Widget _buildResult(Map<String, dynamic> state) {
    final winner = state['result']?['winner']?.toString();
    final isWin = winner == _myId;
    final isDraw = winner == 'draw';
    final text = isWin ? '🏆 승리!' : (isDraw ? '🤝 무승부' : '아쉽게 패배...');
    final color = isWin
        ? const Color(0xFFFFC93C)
        : (isDraw ? Colors.white : const Color(0xFF8A93A6));
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.notoSans(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _animatedRounds = 0;
              _socket.startPenalty();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
            ),
            child: Text(
              '한 판 더!',
              style: GoogleFonts.notoSans(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pitch painter — stadium, goal + net, keeper, kicker, ball, target grid and
// the full shot cutscene, all driven by one progress value.
//   0.00-0.30 : kicker run-up
//   0.30-0.38 : kick contact
//   0.38-0.72 : ball flight  /  keeper dive (0.34-0.70)
//   0.72-1.00 : result banner (GOAL! / SAVE!)
// ─────────────────────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  final double? progress; // null → idle scene
  final int? kickerDir;
  final int? keeperDir;
  final bool? isGoal;
  final bool showGrid;
  final int? selectedCell;
  final bool isKickerView;

  _PitchPainter({
    required this.progress,
    required this.kickerDir,
    required this.keeperDir,
    required this.isGoal,
    required this.showGrid,
    required this.selectedCell,
    required this.isKickerView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _PitchGeometry(size);
    _paintStadium(canvas, size, geo);
    _paintGrass(canvas, size, geo);
    _paintGoal(canvas, size, geo);
    if (showGrid) _paintTargetGrid(canvas, geo);

    final p = progress;
    if (p == null) {
      _paintKeeper(canvas, geo, dive: null, t: 0);
      _paintBall(canvas, geo.spot, 9);
      _paintKicker(canvas, geo, runT: 0, kickT: 0);
      return;
    }

    // ── animated shot ──
    final runT = Curves.easeIn.transform((p / 0.30).clamp(0.0, 1.0));
    final kickT = ((p - 0.30) / 0.08).clamp(0.0, 1.0);
    final flightT = Curves.easeOutQuad.transform(
      ((p - 0.38) / 0.34).clamp(0.0, 1.0),
    );
    final diveT = Curves.easeOutQuad.transform(
      ((p - 0.34) / 0.36).clamp(0.0, 1.0),
    );

    final target = geo.cellCenter(kickerDir ?? 4);
    final keeperTarget = geo.cellCenter(keeperDir ?? 4);
    final saved = isGoal == false;

    _paintKeeper(canvas, geo, dive: keeperTarget, t: diveT);

    // Ball flight: spot → target cell (or into the keeper's hands on a save).
    final end = saved ? keeperTarget : target;
    final pos = Offset.lerp(geo.spot, end, flightT)!;
    // slight arc lift so it feels airborne
    final lift = math.sin(flightT * math.pi) * geo.goal.height * 0.22;
    final r = _lerp(9, 5, flightT);
    final drop = saved && p > 0.72
        ? (p - 0.72) / 0.28 * geo.goal.height * 0.45
        : 0.0;
    _paintBall(canvas, Offset(pos.dx, pos.dy - lift + drop), r);

    _paintKicker(canvas, geo, runT: runT, kickT: kickT);

    if (p > 0.72) {
      _paintResultBanner(canvas, geo, saved: saved, t: (p - 0.72) / 0.28);
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // ── background ─────────────────────────────────────────────────────────────

  void _paintStadium(Canvas canvas, Size size, _PitchGeometry geo) {
    final standRect = Rect.fromLTRB(0, 0, size.width, size.height * 0.14);
    canvas.drawRect(
      standRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232B3F), Color(0xFF39415C)],
        ).createShader(standRect),
    );
    // Crowd: rows of tiny dots.
    final rnd = math.Random(7);
    final crowd = Paint();
    for (int i = 0; i < 260; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * standRect.height * 0.92;
      crowd.color = const [
        Color(0xFF8891AC),
        Color(0xFFB7BDD1),
        Color(0xFFD8A6A6),
        Color(0xFFA6C5D8),
      ][rnd.nextInt(4)].withValues(alpha: 0.8);
      canvas.drawCircle(Offset(x, y), 1.6, crowd);
    }
  }

  void _paintGrass(Canvas canvas, Size size, _PitchGeometry geo) {
    final grassTop = size.height * 0.14;
    canvas.drawRect(
      Rect.fromLTRB(0, grassTop, size.width, size.height),
      Paint()..color = const Color(0xFF2E8B3D),
    );

    // Mown stripes widening toward the viewer.
    final stripe = Paint()..color = const Color(0xFF37A048);
    double y = grassTop;
    int i = 0;
    while (y < size.height) {
      final h = 14.0 + (y - grassTop) * 0.16;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTRB(0, y, size.width, y + h), stripe);
      }
      y += h;
      i++;
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Goal line + penalty box hint.
    final goalLineY = geo.goal.bottom + 6;
    canvas.drawLine(
      Offset(size.width * 0.02, goalLineY),
      Offset(size.width * 0.98, goalLineY),
      line,
    );
    final box = Rect.fromLTRB(
      size.width * 0.10,
      goalLineY,
      size.width * 0.90,
      goalLineY + size.height * 0.30,
    );
    canvas.drawRect(box, line..strokeWidth = 2);

    // Penalty arc behind the spot.
    canvas.drawArc(
      Rect.fromCircle(center: geo.spot, radius: size.width * 0.16),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      line,
    );
    // Penalty spot.
    canvas.drawCircle(
      geo.spot,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintGoal(Canvas canvas, Size size, _PitchGeometry geo) {
    final g = geo.goal;

    // Net (behind posts): slightly bowed grid.
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      final x = g.left + g.width * i / 10;
      final bow = math.sin(i / 10 * math.pi) * 4;
      canvas.drawLine(Offset(x, g.top - bow), Offset(x, g.bottom), net);
    }
    for (int j = 0; j <= 7; j++) {
      final y = g.top + g.height * j / 7;
      canvas.drawLine(Offset(g.left, y), Offset(g.right, y), net);
    }

    // Posts + crossbar.
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(g.topLeft, g.bottomLeft, post);
    canvas.drawLine(g.topRight, g.bottomRight, post);
    canvas.drawLine(g.topLeft, g.topRight, post);
    // Post shading.
    final shade = Paint()
      ..color = const Color(0xFFB9C2CF)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      g.topLeft.translate(2, 0),
      g.bottomLeft.translate(2, 0),
      shade,
    );
    canvas.drawLine(
      g.topRight.translate(-2, 0),
      g.bottomRight.translate(-2, 0),
      shade,
    );
  }

  void _paintTargetGrid(Canvas canvas, _PitchGeometry geo) {
    final g = geo.goal;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(g.left + g.width * i / 3, g.top),
        Offset(g.left + g.width * i / 3, g.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(g.left, g.top + g.height * i / 3),
        Offset(g.right, g.top + g.height * i / 3),
        grid,
      );
    }
    final sel = selectedCell;
    if (sel != null) {
      final c = geo.cellCenter(sel);
      final ring = Paint()
        ..color = isKickerView
            ? const Color(0xFFFF5252)
            : const Color(0xFF40E0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(c, 15, ring);
      canvas.drawCircle(c, 5, ring..style = PaintingStyle.fill);
    }
  }

  // ── characters ─────────────────────────────────────────────────────────────

  /// Keeper: idle sway at the goal center, or a full-body dive to [dive].
  void _paintKeeper(
    Canvas canvas,
    _PitchGeometry geo, {
    Offset? dive,
    required double t,
  }) {
    final g = geo.goal;
    final idle = Offset(g.center.dx, g.bottom - 4);
    final bodyH = g.height * 0.52;

    Offset pos;
    double angle = 0;
    bool armsUp = false;
    if (dive == null || t == 0) {
      pos = idle;
    } else {
      // Dive toward the chosen cell: the body tilts and stretches so the
      // hands reach the cell center.
      final reach = Offset(
        dive.dx,
        math.max(dive.dy + bodyH * 0.3, g.top + bodyH * 0.4),
      );
      pos = Offset.lerp(idle, reach, t)!;
      final dx = dive.dx - g.center.dx;
      final row = (keeperDir ?? 4) ~/ 3;
      final sideness = (dx / (g.width / 2)).clamp(-1.0, 1.0);
      angle = sideness * (row == 2 ? 1.15 : 0.85) * t;
      armsUp = true;
    }

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    _drawPlayer(
      canvas,
      height: bodyH,
      jersey: const Color(0xFFD9E24A),
      shorts: const Color(0xFF1F2937),
      skin: const Color(0xFFE8B98E),
      armsUp: armsUp,
      armSpread: dive == null ? 0.5 : 1.0,
      runPhase: 0,
      gloves: true,
    );
    canvas.restore();
  }

  /// Kicker: waits beside the spot, runs up and swings a leg through the ball.
  void _paintKicker(
    Canvas canvas,
    _PitchGeometry geo, {
    required double runT,
    required double kickT,
  }) {
    final start = Offset(
      geo.spot.dx - geo.size.width * 0.17,
      geo.spot.dy + geo.size.height * 0.06,
    );
    final contact = Offset(geo.spot.dx - 12, geo.spot.dy + 2);
    final pos = Offset.lerp(start, contact, runT)!;
    final bodyH = geo.size.height * 0.16;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    // Lean forward while running, whip back upright through the kick.
    canvas.rotate(0.12 * runT - 0.10 * kickT);
    _drawPlayer(
      canvas,
      height: bodyH,
      jersey: const Color(0xFFE23C3C),
      shorts: Colors.white,
      skin: const Color(0xFFE8B98E),
      armsUp: false,
      armSpread: 0.35 + 0.3 * runT,
      runPhase: runT > 0 && runT < 1 ? runT * 4 : 0,
      kickSwing: kickT,
      gloves: false,
    );
    canvas.restore();
  }

  /// Small vector footballer, origin at the feet.
  void _drawPlayer(
    Canvas canvas, {
    required double height,
    required Color jersey,
    required Color shorts,
    required Color skin,
    required bool armsUp,
    required double armSpread,
    required double runPhase,
    double kickSwing = 0,
    required bool gloves,
  }) {
    final h = height;
    final headR = h * 0.14;
    final torsoTop = -h + headR * 2.1;
    final torsoBot = -h * 0.42;
    final hipY = torsoBot;

    final limb = Paint()
      ..strokeWidth = h * 0.085
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Legs
    limb.color = skin;
    final legLen = h * 0.42;
    final runSwing = math.sin(runPhase * math.pi * 2) * 0.5;
    // Support leg
    canvas.drawLine(
      Offset(0, hipY),
      Offset(-h * 0.07 + runSwing * h * 0.06, 0),
      limb,
    );
    // Kicking / free leg
    final kickAngle = kickSwing > 0
        ? _lerp(0.7, -1.2, Curves.easeOut.transform(kickSwing))
        : -runSwing * 0.9;
    final footX = math.sin(kickAngle) * legLen;
    final footY = math.cos(kickAngle) * legLen;
    canvas.drawLine(Offset(0, hipY), Offset(footX, hipY + footY), limb);
    // Boots
    final boot = Paint()..color = const Color(0xFF222831);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-h * 0.07 + runSwing * h * 0.06, 2),
        width: h * 0.16,
        height: h * 0.08,
      ),
      boot,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(footX, hipY + footY),
        width: h * 0.16,
        height: h * 0.08,
      ),
      boot,
    );

    // Shorts
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-h * 0.14, hipY - h * 0.10, h * 0.14, hipY + h * 0.04),
        Radius.circular(h * 0.04),
      ),
      Paint()..color = shorts,
    );

    // Torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(-h * 0.15, torsoTop, h * 0.15, torsoBot),
        Radius.circular(h * 0.06),
      ),
      Paint()..color = jersey,
    );

    // Arms
    limb.color = jersey;
    final shoulderY = torsoTop + h * 0.06;
    final armLen = h * 0.34;
    if (armsUp) {
      canvas.drawLine(
        Offset(-h * 0.13, shoulderY),
        Offset(-h * 0.13 - armLen * 0.5, shoulderY - armLen),
        limb,
      );
      canvas.drawLine(
        Offset(h * 0.13, shoulderY),
        Offset(h * 0.13 + armLen * 0.5, shoulderY - armLen),
        limb,
      );
      if (gloves) {
        final glove = Paint()..color = Colors.white;
        canvas.drawCircle(
          Offset(-h * 0.13 - armLen * 0.5, shoulderY - armLen),
          h * 0.06,
          glove,
        );
        canvas.drawCircle(
          Offset(h * 0.13 + armLen * 0.5, shoulderY - armLen),
          h * 0.06,
          glove,
        );
      }
    } else {
      final spread = armSpread * armLen;
      canvas.drawLine(
        Offset(-h * 0.13, shoulderY),
        Offset(-h * 0.13 - spread, shoulderY + armLen * 0.7),
        limb,
      );
      canvas.drawLine(
        Offset(h * 0.13, shoulderY),
        Offset(h * 0.13 + spread, shoulderY + armLen * 0.7),
        limb,
      );
    }

    // Head + hair
    canvas.drawCircle(
      Offset(0, torsoTop - headR * 0.9),
      headR,
      Paint()..color = skin,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, torsoTop - headR * 0.9), radius: headR),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3B2B20),
    );
  }

  void _paintBall(Canvas canvas, Offset c, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + r * 0.9),
        width: r * 2.0,
        height: r * 0.6,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFBFC7D1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final patch = Paint()..color = const Color(0xFF23272E);
    canvas.drawCircle(c, r * 0.32, patch);
    for (int i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.78,
        r * 0.17,
        patch,
      );
    }
  }

  void _paintResultBanner(
    Canvas canvas,
    _PitchGeometry geo, {
    required bool saved,
    required double t,
  }) {
    final text = saved ? 'SAVE!' : 'GOAL!';
    final color = saved ? const Color(0xFF40E0FF) : const Color(0xFFFFD54A);
    final scale = Curves.elasticOut.transform(t.clamp(0.0, 1.0));

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.orbitron(
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.8), blurRadius: 18),
            const Shadow(
              color: Colors.black54,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final center = Offset(geo.size.width / 2, geo.size.height * 0.52);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PitchPainter old) =>
      old.progress != progress ||
      old.showGrid != showGrid ||
      old.selectedCell != selectedCell ||
      old.kickerDir != kickerDir ||
      old.keeperDir != keeperDir;
}
