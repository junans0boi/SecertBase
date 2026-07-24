import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class BasketballScreen extends StatefulWidget {
  const BasketballScreen({super.key});

  @override
  State<BasketballScreen> createState() => _BasketballScreenState();
}

class _BasketballScreenState extends State<BasketballScreen> {
  final _socket = SocketService();
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isShooting = false;
  double _ballX = 0;
  double _ballY = 0;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _startGame() {
    if (_socket.presenceUsers.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상대방이 접속해야 시작할 수 있어요')));
      return;
    }
    _socket.startBasketball();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isShooting) return;
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isShooting) return;
    setState(() {
      _dragCurrent = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isShooting || _dragStart == null || _dragCurrent == null) return;

    final dx = _dragCurrent!.dx - _dragStart!.dx;
    final dy = _dragStart!.dy - _dragCurrent!.dy;

    if (dy > 30) {
      _isShooting = true;
      final isMade = dy > 80 && dx.abs() < 50;
      _animateShot(isMade);
    }

    setState(() {
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _animateShot(bool isMade) async {
    for (int i = 0; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      setState(() {
        _ballY = -i * 14.0;
        _ballX = (isMade ? 0 : 45.0) * (i / 20.0);
      });
    }

    _socket.submitBasketballShot(isMade, points: 2);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _isShooting = false;
      _ballX = 0;
      _ballY = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _socket.basketballState;
    final isPlaying = state != null && state['status'] == 'playing';
    final isFinished = state != null && state['status'] == 'finished';
    final myId = _socket.userId ?? '';
    final shots =
        ((state?['shots'] as Map<String, dynamic>?)?[myId] as List?) ?? [];
    final score =
        ((state?['scores'] as Map<String, dynamic>?)?[myId] as num?)?.toInt() ??
        0;

    return GameScaffold(
      title: 'NBA 3PT SHOOTOUT 🏀',
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF451A03), Color(0xFF1E1B4B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (state == null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1E1B4B,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🏀 🏀 🏀',
                              style: TextStyle(fontSize: 44),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'NBA FREETHROW CONTEST',
                              style: GoogleFonts.orbitron(
                                color: Colors.amberAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '농구 코트 코트에서 스와이프 슈팅으로 10슛 대결!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSans(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _startGame,
                              icon: const Icon(
                                Icons.sports_basketball_rounded,
                                color: Colors.black,
                              ),
                              label: Text(
                                '스타트',
                                style: GoogleFonts.orbitron(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amberAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amberAccent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHOTS: ${shots.length} / 10',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'SCORE: $score PTS',
                          style: GoogleFonts.orbitron(
                            color: Colors.amberAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isPlaying)
                  Expanded(
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF78350F).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Backboard & Hoop
                            Positioned(
                              top: 40,
                              child: Column(
                                children: [
                                  Container(
                                    width: 140,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      border: Border.all(
                                        color: Colors.orangeAccent,
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 50,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.orange,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 70,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.redAccent,
                                        width: 4,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Ball
                            Positioned(
                              bottom: 80 - _ballY,
                              left:
                                  MediaQuery.of(context).size.width / 2 -
                                  40 +
                                  _ballX,
                              child: const Text(
                                '🏀',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),
                            if (shots.length >= 10)
                              Center(
                                child: Text(
                                  'WAITING FOR OPPONENT...',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.amberAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isFinished) _buildResultSection(state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultSection(Map<String, dynamic> state) {
    final result = state['result'] as Map<String, dynamic>?;
    final winner = result?['winner'] as String?;
    final myId = _socket.userId ?? '';
    final isWinner = winner == myId;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            isWinner ? '🏆 CHAMPION!' : '😭 DEFEAT',
            style: GoogleFonts.orbitron(
              color: isWinner ? Colors.greenAccent : Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
            ),
            child: Text(
              'RESTART',
              style: GoogleFonts.orbitron(
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
