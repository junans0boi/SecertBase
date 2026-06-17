import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class YutScreen extends StatefulWidget {
  const YutScreen({super.key});

  @override
  State<YutScreen> createState() => _YutScreenState();
}

class _YutScreenState extends State<YutScreen> {
  final _socket = SocketService();

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

  void _rebuild() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final isMyTurn = sock.yutCurrentTurn == sock.userId;
    final twoPlayers = sock.presenceUsers.length == 2;

    return GameScaffold(
      title: '🀄 윷놀이',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (sock.yutWinner != null)
              _WinBanner(winner: sock.yutWinner!, userId: sock.userId)
            else if (!sock.yutActive) ...[
              const SizedBox(height: 32),
              _StatusCard(
                icon: '🀄',
                title: '윷놀이',
                subtitle: twoPlayers ? '게임을 시작해보세요!' : '상대방을 기다리는 중...',
                color: const Color(0xFF5DADE2),
              ),
              const SizedBox(height: 32),
              if (twoPlayers)
                _ActionButton(
                  label: '새 게임 시작',
                  color: const Color(0xFF5DADE2),
                  onTap: () => sock.newYutGame(),
                )
              else
                const _WaitingBadge(),
            ] else ...[
              _TurnBadge(
                currentTurn: sock.yutCurrentTurn ?? '',
                userId: sock.userId ?? '',
                isMyTurn: isMyTurn,
              ),
              const SizedBox(height: 24),
              if (sock.yutLastThrow != null)
                _ThrowResult(result: sock.yutLastThrow!),
              const SizedBox(height: 24),
              if (sock.yutPendingMoves.isNotEmpty)
                _PendingMovesCard(pending: sock.yutPendingMoves),
              const Spacer(),
              if (isMyTurn)
                _ActionButton(
                  label: '윷 던지기!',
                  color: const Color(0xFF5DADE2),
                  icon: Icons.shuffle,
                  onTap: () => sock.throwYut(),
                )
              else
                _WaitingBadge(text: '${sock.yutCurrentTurn ?? "상대방"}의 차례'),
              const SizedBox(height: 16),
              if (isMyTurn && sock.yutPendingMoves.isNotEmpty)
                _MoveButtons(onMove: (i) => sock.moveYut(i)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TurnBadge extends StatelessWidget {
  final String currentTurn;
  final String userId;
  final bool isMyTurn;
  const _TurnBadge({required this.currentTurn, required this.userId, required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: (isMyTurn ? kSuccess : kAccent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isMyTurn ? kSuccess : kAccent).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMyTurn ? Icons.play_circle : Icons.hourglass_empty,
            color: isMyTurn ? kSuccess : kAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isMyTurn ? '내 차례입니다!' : '$currentTurn의 차례',
            style: GoogleFonts.notoSans(
              color: isMyTurn ? kSuccess : kAccent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThrowResult extends StatelessWidget {
  final String result;
  const _ThrowResult({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Text('윷 결과', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            result,
            style: GoogleFonts.notoSans(color: kGold, fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PendingMovesCard extends StatelessWidget {
  final List<Map<String, dynamic>> pending;
  const _PendingMovesCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pending_actions, color: kGold, size: 18),
          const SizedBox(width: 8),
          Text(
            '이동 가능: ${pending.length}회',
            style: GoogleFonts.notoSans(color: kGold, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MoveButtons extends StatelessWidget {
  final void Function(int) onMove;
  const _MoveButtons({required this.onMove});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('이동할 말을 선택하세요', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (i) => GestureDetector(
            onTap: () => onMove(i),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: kPrimary, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.notoSans(color: kPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          )),
        ),
      ],
    );
  }
}

class _WinBanner extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinBanner({required this.winner, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(isMe ? '🎉' : '😢', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            isMe ? '내가 이겼어요!' : '$winner이 이겼어요',
            style: GoogleFonts.notoSans(
              color: isMe ? kSuccess : kError,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── shared game widgets ───────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  const _StatusCard({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.notoSans(color: kText, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: MaterialButton(
          onPressed: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.notoSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  final String? text;
  const _WaitingBadge({this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted),
          ),
          const SizedBox(width: 10),
          Text(text ?? '상대방을 기다리는 중...', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
