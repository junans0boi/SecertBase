import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class PirateScreen extends StatefulWidget {
  const PirateScreen({super.key});

  @override
  State<PirateScreen> createState() => _PirateScreenState();
}

class _PirateScreenState extends State<PirateScreen>
    with TickerProviderStateMixin {
  final _socket = SocketService();
  int _slots = 8;

  late final AnimationController _explodeCtrl;
  late final Animation<double> _explodeAnim;
  bool _explodeShown = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    _explodeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _explodeAnim = CurvedAnimation(
      parent: _explodeCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    _explodeCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    final hasBomb = _socket.pirateBombSlot != null;
    if (hasBomb && !_explodeShown) {
      _explodeShown = true;
      _explodeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
    setState(() {});
  }

  void _startGame() {
    if (_socket.presenceUsers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상대방이 접속해야 시작할 수 있어요')));
      return;
    }
    _explodeShown = false;
    _explodeCtrl.reset();
    _socket.startPirate(_slots);
  }

  void _pickSlot(int slot) {
    if (_socket.pirateCurrentTurn != _socket.userId) return;
    _socket.pickPirateSlot(slot);
  }

  void _resetGame() {
    _explodeShown = false;
    _explodeCtrl.reset();
    _socket.resetPirate();
  }

  bool get _isMyTurn =>
      _socket.pirateActive && _socket.pirateCurrentTurn == _socket.userId;

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final active = sock.pirateActive;
    final bombSlot = sock.pirateBombSlot;
    final isResult = bombSlot != null;
    final imLoser = sock.pirateLoser == sock.userId;

    return GameScaffold(
      title: '🏴‍☠️ 해적 룰렛',
      actions: const [],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 14 : 20),
            child: Column(
              children: [
                if (!active && !isResult) _buildSetup(compact),
                if (active) _buildPlaying(compact),
                if (isResult) _buildResult(compact, imLoser, bombSlot),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _isHost =>
      _socket.userId != null && _socket.lobbyHost == _socket.userId;

  // ── Setup Phase ──────────────────────────────────────────────────────────

  Widget _buildSetup(bool compact) {
    final isHost = _isHost;
    return Column(
      children: [
        const SizedBox(height: 8),
        _PirateBarrelWidget(
          state: _BarrelState.calm,
          piratePop: 0,
          size: compact ? 150 : 180,
        ),
        const SizedBox(height: 20),
        Text(
          '해적 룰렛',
          style: GoogleFonts.notoSans(
            color: const Color(0xFF2A1A0E),
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '통 속의 구멍 하나에 폭탄이 숨어있어요.\n한 명씩 번갈아 구멍을 골라 칼을 꽂으세요.\n폭탄 구멍을 고른 사람이 패배!',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: const Color(0xFF7A5C3A),
            fontSize: compact ? 12 : 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        if (isHost) ...[
          _buildSlotStepper(compact),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: compact ? 48 : 54,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC4F2A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: Text(
                '게임 시작!',
                style: GoogleFonts.notoSans(
                  fontSize: compact ? 15 : 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 28,
              vertical: compact ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E9D4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4A96A)),
            ),
            child: Text(
              '방장이 구멍 개수를 정하고\n게임을 시작할 때까지 기다려요',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: const Color(0xFF7A5C3A),
                fontSize: compact ? 13 : 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSlotStepper(bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E9D4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A96A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '구멍 개수',
            style: GoogleFonts.notoSans(
              color: const Color(0xFF7A5C3A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 20),
          IconButton(
            onPressed: _slots > 4 ? () => setState(() => _slots--) : null,
            icon: Icon(
              Icons.remove_circle,
              color: _slots > 4 ? const Color(0xFFCC4F2A) : Colors.grey[400],
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$_slots',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: const Color(0xFF2A1A0E),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: _slots < 16 ? () => setState(() => _slots++) : null,
            icon: Icon(
              Icons.add_circle,
              color: _slots < 16 ? const Color(0xFFCC4F2A) : Colors.grey[400],
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ── Playing Phase ─────────────────────────────────────────────────────────

  Widget _buildPlaying(bool compact) {
    final sock = _socket;
    final isMyTurn = _isMyTurn;
    final turnLabel = isMyTurn
        ? '내 차례 — 구멍을 골라요!'
        : '${sock.nameOf(sock.pirateCurrentTurn) == '' ? '상대방' : sock.nameOf(sock.pirateCurrentTurn)} 차례입니다';

    return Column(
      children: [
        const SizedBox(height: 4),
        _buildTurnBanner(isMyTurn, turnLabel, compact),
        const SizedBox(height: 16),
        _PirateBarrelWidget(
          state: isMyTurn ? _BarrelState.nervous : _BarrelState.waiting,
          piratePop: 0,
          size: compact ? 120 : 150,
        ),
        const SizedBox(height: 20),
        _buildHoleGrid(compact),
        const SizedBox(height: 16),
        Text(
          '남은 구멍 ${sock.pirateTotalSlots - sock.piratePickedSlots.length}개',
          style: GoogleFonts.notoSans(
            color: const Color(0xFF7A5C3A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTurnBanner(bool isMyTurn, String label, bool compact) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: isMyTurn ? const Color(0xFFFFEDD5) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMyTurn ? const Color(0xFFCC4F2A) : const Color(0xFFCCCCCC),
          width: isMyTurn ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isMyTurn ? '⚔️' : '⏳',
            style: TextStyle(fontSize: compact ? 18 : 20),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: isMyTurn
                    ? const Color(0xFFCC4F2A)
                    : const Color(0xFF666666),
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleGrid(bool compact) {
    final sock = _socket;
    final total = sock.pirateTotalSlots;
    const cols = 4;
    final holeSize = compact ? 58.0 : 70.0;
    final spacing = compact ? 8.0 : 10.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        final isPicked = sock.piratePickedSlots.contains(i);
        final canTap = _isMyTurn && !isPicked;
        return _HoleWidget(
          index: i,
          isPicked: isPicked,
          canTap: canTap,
          size: holeSize,
          onTap: canTap ? () => _pickSlot(i) : null,
        );
      },
    );
  }

  // ── Result Phase ──────────────────────────────────────────────────────────

  Widget _buildResult(bool compact, bool imLoser, int bombSlot) {
    return Column(
      children: [
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _explodeAnim,
          builder: (_, __) => _PirateBarrelWidget(
            state: _BarrelState.exploded,
            piratePop: _explodeAnim.value,
            size: compact ? 150 : 180,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          imLoser ? '💥 폭탄을 찾았어요!' : '🎉 살았다!',
          style: GoogleFonts.notoSans(
            color: imLoser ? const Color(0xFFCC2A2A) : const Color(0xFF2A7A2A),
            fontSize: compact ? 22 : 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          imLoser
              ? '${bombSlot + 1}번 구멍에 폭탄이 있었어요'
              : '${_socket.nameOf(_socket.pirateLoser).isNotEmpty ? _socket.nameOf(_socket.pirateLoser) : '상대방'}이(가) 폭탄을 건드렸어요',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: const Color(0xFF7A5C3A),
            fontSize: compact ? 13 : 14,
          ),
        ),
        const SizedBox(height: 20),
        _buildResultGrid(compact, bombSlot),
        const SizedBox(height: 24),
        if (_isHost)
          OutlinedButton.icon(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('다시 하기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCC4F2A),
              side: const BorderSide(color: Color(0xFFCC4F2A)),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 18 : 24,
                vertical: compact ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        else
          Text(
            '방장이 다시 시작하길 기다려요',
            style: GoogleFonts.notoSans(
              color: const Color(0xFF7A5C3A),
              fontSize: compact ? 12 : 13,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResultGrid(bool compact, int bombSlot) {
    final picked = _socket.piratePickedSlots;
    final total = _socket.pirateTotalSlots + 1; // slots before explosion
    const cols = 4;
    final holeSize = compact ? 52.0 : 62.0;
    final spacing = compact ? 7.0 : 9.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        final isBomb = i == bombSlot;
        final isPicked = picked.contains(i);
        return _HoleWidget(
          index: i,
          isPicked: isPicked,
          isBomb: isBomb,
          canTap: false,
          size: holeSize,
        );
      },
    );
  }
}

// ── Hole Widget ──────────────────────────────────────────────────────────────

class _HoleWidget extends StatelessWidget {
  final int index;
  final bool isPicked;
  final bool isBomb;
  final bool canTap;
  final double size;
  final VoidCallback? onTap;

  const _HoleWidget({
    required this.index,
    required this.isPicked,
    required this.canTap,
    required this.size,
    this.isBomb = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    String label;
    double fontSize;

    if (isBomb) {
      bg = const Color(0xFFFFDDD0);
      border = const Color(0xFFCC2A2A);
      label = '💥';
      fontSize = size * 0.4;
    } else if (isPicked) {
      bg = const Color(0xFFDFF5E3);
      border = const Color(0xFF4CAF50);
      label = '⚔️';
      fontSize = size * 0.38;
    } else if (canTap) {
      bg = const Color(0xFFFFF3E0);
      border = const Color(0xFFFF8C00);
      label = '${index + 1}';
      fontSize = size * 0.28;
    } else {
      bg = const Color(0xFF3A2414);
      border = const Color(0xFF5A3A1A);
      label = '${index + 1}';
      fontSize = size * 0.26;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: canTap ? 2.5 : 1.5),
          boxShadow: canTap
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : isBomb
              ? [
                  BoxShadow(
                    color: const Color(0xFFCC2A2A).withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: (isPicked || isBomb || canTap) ? null : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pirate Barrel Illustration ───────────────────────────────────────────────

enum _BarrelState { calm, nervous, waiting, exploded }

class _PirateBarrelWidget extends StatelessWidget {
  final _BarrelState state;
  final double piratePop; // 0.0 = in barrel, 1.0 = fully popped
  final double size;

  const _PirateBarrelWidget({
    required this.state,
    required this.piratePop,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.2,
      child: CustomPaint(
        painter: _PirateBarrelPainter(state: state, piratePop: piratePop),
      ),
    );
  }
}

class _PirateBarrelPainter extends CustomPainter {
  final _BarrelState state;
  final double piratePop;

  const _PirateBarrelPainter({required this.state, required this.piratePop});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final barrelH = size.height * 0.72;
    final barrelW = size.width * 0.88;
    final barrelTop = size.height * 0.30;
    final barrelBottom = barrelTop + barrelH;

    _drawBarrel(canvas, cx, barrelTop, barrelBottom, barrelW, size);
    _drawPirate(canvas, cx, barrelTop, barrelW, size);
  }

  void _drawBarrel(
    Canvas canvas,
    double cx,
    double barrelTop,
    double barrelBottom,
    double barrelW,
    Size size,
  ) {
    final barrelH = barrelBottom - barrelTop;

    // Barrel body (slightly wider at middle)
    final bodyPath = Path();
    final left = cx - barrelW / 2;
    final right = cx + barrelW / 2;
    bodyPath.moveTo(left + barrelW * 0.06, barrelTop);
    bodyPath.quadraticBezierTo(
      left - barrelW * 0.04,
      barrelTop + barrelH * 0.5,
      left + barrelW * 0.06,
      barrelBottom,
    );
    bodyPath.lineTo(right - barrelW * 0.06, barrelBottom);
    bodyPath.quadraticBezierTo(
      right + barrelW * 0.04,
      barrelTop + barrelH * 0.5,
      right - barrelW * 0.06,
      barrelTop,
    );
    bodyPath.close();

    // Shadow
    canvas.drawPath(
      bodyPath.shift(const Offset(3, 5)),
      Paint()..color = Colors.black.withOpacity(0.18),
    );

    // Main body fill
    final woodGrad = Paint()
      ..shader =
          LinearGradient(
            colors: const [
              Color(0xFF8B4A12),
              Color(0xFFC27830),
              Color(0xFF8B4A12),
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(
            Rect.fromLTWH(cx - barrelW / 2, barrelTop, barrelW, barrelH),
          );
    canvas.drawPath(bodyPath, woodGrad);

    // Wood grain lines
    final grain = Paint()
      ..color = const Color(0xFF6B3A0A).withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 1; i <= 5; i++) {
      final y = barrelTop + barrelH * (i / 6.0);
      canvas.drawLine(
        Offset(cx - barrelW * 0.38, y),
        Offset(cx + barrelW * 0.38, y),
        grain,
      );
    }

    // Barrel rings (steel bands)
    final ringPaint = Paint()
      ..color = const Color(0xFF4A3828)
      ..strokeWidth = barrelW * 0.055
      ..style = PaintingStyle.stroke;
    final ringYPositions = [0.18, 0.5, 0.82];
    for (final frac in ringYPositions) {
      final ry = barrelTop + barrelH * frac;
      final halfW = barrelW * 0.46 + (frac == 0.5 ? barrelW * 0.04 : 0);
      canvas.drawLine(
        Offset(cx - halfW, ry),
        Offset(cx + halfW, ry),
        ringPaint,
      );
    }

    // Top rim (open circle)
    final rimPaint = Paint()
      ..color = const Color(0xFF5C3A1A)
      ..strokeWidth = barrelW * 0.04
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, barrelTop),
        width: barrelW * 0.88,
        height: barrelW * 0.22,
      ),
      rimPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, barrelTop),
        width: barrelW * 0.88,
        height: barrelW * 0.22,
      ),
      Paint()
        ..color = const Color(0xFF3A2010)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawPirate(
    Canvas canvas,
    double cx,
    double barrelTop,
    double barrelW,
    Size size,
  ) {
    // Pop offset: calm = slightly inside barrel, nervous = head at rim, exploded = flying
    double popY;
    if (state == _BarrelState.exploded) {
      // piratePop: 0->1, pirate flies upward
      popY = barrelTop - piratePop * size.height * 0.55;
    } else if (state == _BarrelState.nervous) {
      popY = barrelTop - size.height * 0.08;
    } else {
      popY = barrelTop - size.height * 0.02;
    }

    final headR = barrelW * 0.28;
    final headCenter = Offset(cx, popY);

    // ── Bandana (behind head) ──
    final bandanaPath = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: headR * 1.05));
    canvas.drawPath(bandanaPath, Paint()..color = const Color(0xFFCC2222));
    // Bandana knot on right
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter.translate(headR * 0.92, -headR * 0.15),
        width: headR * 0.48,
        height: headR * 0.3,
      ),
      Paint()..color = const Color(0xFFAA1515),
    );

    // Skull on bandana
    final skullPaint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter.translate(-headR * 0.38, -headR * 0.45),
        width: headR * 0.32,
        height: headR * 0.28,
      ),
      skullPaint,
    );
    // Crossbones on bandana (simplified)
    final bonePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = headR * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      headCenter.translate(-headR * 0.55, -headR * 0.3),
      headCenter.translate(-headR * 0.21, -headR * 0.6),
      bonePaint,
    );
    canvas.drawLine(
      headCenter.translate(-headR * 0.21, -headR * 0.3),
      headCenter.translate(-headR * 0.55, -headR * 0.6),
      bonePaint,
    );

    // ── Face ──
    final skin = Paint()..color = const Color(0xFFFFD09A);
    canvas.drawCircle(headCenter, headR * 0.88, skin);

    // ── Eye patch (left) ──
    final patchRect = Rect.fromCenter(
      center: headCenter.translate(-headR * 0.32, -headR * 0.14),
      width: headR * 0.42,
      height: headR * 0.28,
    );
    canvas.drawOval(patchRect, Paint()..color = const Color(0xFF1A1A1A));
    // Patch strap (horizontal)
    canvas.drawLine(
      headCenter.translate(-headR * 0.7, -headR * 0.14),
      headCenter.translate(headR * 0.05, -headR * 0.14),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = headR * 0.06
        ..strokeCap = StrokeCap.round,
    );

    // ── Right eye ──
    canvas.drawCircle(
      headCenter.translate(headR * 0.31, -headR * 0.16),
      headR * 0.16,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      headCenter.translate(headR * 0.33, -headR * 0.14),
      headR * 0.09,
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // ── Mouth / expression ──
    final mouthPaint = Paint()
      ..color = const Color(0xFF5C2A00)
      ..strokeWidth = headR * 0.07
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (state == _BarrelState.exploded) {
      // Shocked "O" mouth
      canvas.drawOval(
        Rect.fromCenter(
          center: headCenter.translate(headR * 0.06, headR * 0.32),
          width: headR * 0.28,
          height: headR * 0.36,
        ),
        Paint()..color = const Color(0xFF5C2A00),
      );
    } else if (state == _BarrelState.nervous) {
      // Wavy nervous smile
      final path = Path()
        ..moveTo(headCenter.dx - headR * 0.28, headCenter.dy + headR * 0.28)
        ..quadraticBezierTo(
          headCenter.dx - headR * 0.1,
          headCenter.dy + headR * 0.15,
          headCenter.dx + headR * 0.02,
          headCenter.dy + headR * 0.28,
        )
        ..quadraticBezierTo(
          headCenter.dx + headR * 0.15,
          headCenter.dy + headR * 0.42,
          headCenter.dx + headR * 0.28,
          headCenter.dy + headR * 0.28,
        );
      canvas.drawPath(path, mouthPaint);
    } else {
      // Normal grin
      canvas.drawArc(
        Rect.fromCenter(
          center: headCenter.translate(headR * 0.06, headR * 0.22),
          width: headR * 0.56,
          height: headR * 0.38,
        ),
        0.1,
        pi - 0.2,
        false,
        mouthPaint,
      );
    }

    // ── Beard (stubble) ──
    final beard = Paint()
      ..color = const Color(0xFF3A2A10)
      ..strokeWidth = headR * 0.05
      ..strokeCap = StrokeCap.round;
    final rng = Random(42);
    for (int i = 0; i < 8; i++) {
      final bx = headCenter.dx + (rng.nextDouble() - 0.5) * headR * 1.0;
      final by = headCenter.dy + headR * 0.4 + rng.nextDouble() * headR * 0.35;
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + (rng.nextDouble() - 0.5) * 4, by + 5),
        beard,
      );
    }

    // Stars on explosion
    if (state == _BarrelState.exploded && piratePop > 0.3) {
      _drawExplosionStars(canvas, headCenter, headR, piratePop);
    }
  }

  void _drawExplosionStars(
    Canvas canvas,
    Offset center,
    double headR,
    double pop,
  ) {
    final starPaint = Paint()..color = const Color(0xFFFFCC00);
    final angles = [0.0, pi / 3, 2 * pi / 3, pi, 4 * pi / 3, 5 * pi / 3];
    final r = headR * 1.6 * pop;
    for (final angle in angles) {
      final sx = center.dx + cos(angle) * r;
      final sy = center.dy + sin(angle) * r;
      _drawStar(canvas, Offset(sx, sy), headR * 0.18 * pop, starPaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * pi / 5) - pi / 2;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      final ix = center.dx + cos(angle + pi / 5) * r * 0.4;
      final iy = center.dy + sin(angle + pi / 5) * r * 0.4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PirateBarrelPainter old) =>
      old.state != state || old.piratePop != piratePop;
}
