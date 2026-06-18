import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/game_menu.dart';

class BombScreen extends StatefulWidget {
  const BombScreen({super.key});

  @override
  State<BombScreen> createState() => _BombScreenState();
}

class _BombScreenState extends State<BombScreen> with SingleTickerProviderStateMixin {
  final _socket = SocketService();
  final _answerCtrl = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _socket.addListener(_rebuild);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _answerCtrl.dispose();
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    if (_socket.bombActive && _timer == null) {
      _startTimer();
    } else if (!_socket.bombActive) {
      _timer?.cancel();
      _timer = null;
      if (_socket.bombLoser != null) {
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _startTimer() {
    _remaining = _socket.bombDuration ?? 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining > 0) _remaining--;
      });
    });
  }

  void _submitAnswer() {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return;
    _socket.answerBomb(answer);
    _answerCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final isMyTurn = sock.bombCurrentPlayer == sock.userId;
    final twoPlayers = sock.presenceUsers.length == 2;

    return GameScaffold(
      title: '💣 폭탄 돌리기',
      actions: [
        GameMenuButton(
          hasRestart: sock.bombActive,
          restartWaiting: sock.restartWaiting,
          onRequestRestart: () => sock.requestRestart('bomb'),
        ),
      ],
      child: GameMenuListener(
        gameType: 'bomb',
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (sock.bombLoser != null)
              Expanded(child: _ExplodeScreen(loser: sock.bombLoser!, userId: sock.userId))
            else if (!sock.bombActive) ...[
              const SizedBox(height: 24),
              _StartPanel(twoPlayers: twoPlayers, onStart: (d) => sock.newBombGame(duration: d)),
            ] else
              Expanded(child: _buildGameUI(sock, isMyTurn)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildGameUI(SocketService sock, bool isMyTurn) {
    return Column(
      children: [
        _HolderCard(
          currentPlayer: sock.bombCurrentPlayer ?? '',
          userId: sock.userId ?? '',
          isMyTurn: isMyTurn,
        ),
        const SizedBox(height: 20),
        _BombVisual(pulse: _pulse, remaining: _remaining, isMyTurn: isMyTurn),
        const SizedBox(height: 24),
        if (sock.bombQuestion != null)
          _QuestionCard(
            question: sock.bombQuestion!,
            category: sock.bombCategory,
            lastCorrect: sock.bombLastAnswerCorrect,
          ),
        const SizedBox(height: 24),
        if (isMyTurn) ...[
          Text(
            '정답을 맞추면 폭탄을 넘길 수 있어요!',
            style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _AnswerInput(
            ctrl: _answerCtrl,
            onSubmit: _submitAnswer,
          ),
        ] else
          _WaitingBadge(player: sock.bombCurrentPlayer ?? '상대방'),
        const SizedBox(height: 16),
        Text(
          '패스 횟수: ${sock.bombPassCount}회',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _BombVisual extends StatelessWidget {
  final Animation<double> pulse;
  final int remaining;
  final bool isMyTurn;
  const _BombVisual({required this.pulse, required this.remaining, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: isMyTurn ? pulse : const AlwaysStoppedAnimation(1.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMyTurn ? kError.withOpacity(0.15) : kCard,
                  border: Border.all(
                    color: isMyTurn ? kError : kBorder,
                    width: isMyTurn ? 2 : 1,
                  ),
                  boxShadow: isMyTurn
                      ? [BoxShadow(color: kError.withOpacity(0.25), blurRadius: 24, spreadRadius: 4)]
                      : null,
                ),
                child: const Center(
                  child: Text('💣', style: TextStyle(fontSize: 54)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _timerColor(remaining).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _timerColor(remaining).withOpacity(0.4)),
          ),
          child: Text(
            '⏱️ $remaining초',
            style: GoogleFonts.notoSans(
              color: _timerColor(remaining),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  static Color _timerColor(int t) {
    if (t <= 5) return kError;
    if (t <= 10) return kGold;
    return kSuccess;
  }
}

class _HolderCard extends StatelessWidget {
  final String currentPlayer;
  final String userId;
  final bool isMyTurn;
  const _HolderCard({required this.currentPlayer, required this.userId, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: (isMyTurn ? kError : kPrimary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isMyTurn ? kError : kPrimary).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMyTurn ? Icons.warning_amber : Icons.hourglass_empty,
            color: isMyTurn ? kError : kPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isMyTurn ? '💣 내가 폭탄을 들고 있어요!' : '$currentPlayer이 폭탄을 들고 있어요',
            style: GoogleFonts.notoSans(
              color: isMyTurn ? kError : kTextMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  final String? category;
  final bool? lastCorrect;
  const _QuestionCard({required this.question, this.category, this.lastCorrect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category ?? '문제',
                  style: GoogleFonts.notoSans(color: kGold, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              if (lastCorrect == false) ...[
                const SizedBox(width: 8),
                const Icon(Icons.close, color: kError, size: 16),
                Text(' 오답', style: GoogleFonts.notoSans(color: kError, fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            question,
            style: GoogleFonts.notoSans(color: kText, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnswerInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSubmit;
  const _AnswerInput({required this.ctrl, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: kText, fontSize: 16),
            decoration: const InputDecoration(hintText: '정답 입력...'),
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: kPrimaryGrad,
              borderRadius: BorderRadius.circular(14),
            ),
            child: MaterialButton(
              onPressed: onSubmit,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Text('제출', style: GoogleFonts.notoSans(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  final String player;
  const _WaitingBadge({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '$player이 문제를 풀고 있어요...',
        style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
      ),
    );
  }
}

class _StartPanel extends StatefulWidget {
  final bool twoPlayers;
  final void Function(int) onStart;
  const _StartPanel({required this.twoPlayers, required this.onStart});

  @override
  State<_StartPanel> createState() => _StartPanelState();
}

class _StartPanelState extends State<_StartPanel> {
  int _duration = 30;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: kError.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kError.withOpacity(0.25)),
          ),
          child: Column(
            children: [
              const Text('💣', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text('폭탄 돌리기', style: GoogleFonts.notoSans(color: kText, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                widget.twoPlayers ? '퀴즈를 맞추면 폭탄을 넘길 수 있어요' : '상대방을 기다리는 중...',
                style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (widget.twoPlayers) ...[
          Text('제한 시간', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _duration > 10 ? () => setState(() => _duration -= 10) : null,
                icon: const Icon(Icons.remove_circle_outline, color: kPrimary),
              ),
              Text(
                '$_duration초',
                style: GoogleFonts.notoSans(color: kText, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: _duration < 120 ? () => setState(() => _duration += 10) : null,
                icon: const Icon(Icons.add_circle_outline, color: kPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F43),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFFFF9F43).withOpacity(0.3), blurRadius: 16)],
              ),
              child: MaterialButton(
                onPressed: () => widget.onStart(_duration),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Text('게임 시작!', style: GoogleFonts.notoSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
                const SizedBox(width: 10),
                Text('상대방을 기다리는 중...', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ExplodeScreen extends StatelessWidget {
  final String loser;
  final String? userId;
  const _ExplodeScreen({required this.loser, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = loser == userId;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isMe ? '💀' : '🎉', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            isMe ? '폭탄이 나한테서 터졌어요!' : '$loser에게서 폭탄이 터졌어요!',
            style: GoogleFonts.notoSans(
              color: isMe ? kError : kSuccess,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
