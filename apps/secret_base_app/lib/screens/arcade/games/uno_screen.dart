import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
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

  static Color _cardColor(String? cardStr) {
    if (cardStr == null) return kTextMuted;
    final s = cardStr.toLowerCase();
    if (s.contains('red')) return const Color(0xFFFF5252);
    if (s.contains('blue')) return const Color(0xFF448AFF);
    if (s.contains('green')) return const Color(0xFF69F0AE);
    if (s.contains('yellow')) return const Color(0xFFFFD740);
    return const Color(0xFF9575CD);
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final isMyTurn = sock.unoCurrentPlayer == sock.userId;
    final twoPlayers = sock.presenceUsers.length == 2;

    return GameScaffold(
      title: '🃏 UNO',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (sock.unoWinner != null)
              Expanded(child: _WinScreen(winner: sock.unoWinner!, userId: sock.userId))
            else if (!sock.unoActive) ...[
              const SizedBox(height: 32),
              _StatusCard(
                icon: '🃏',
                title: 'UNO',
                subtitle: twoPlayers ? '게임을 시작해보세요!' : '상대방을 기다리는 중...',
                color: const Color(0xFFA29BFE),
              ),
              const SizedBox(height: 32),
              if (twoPlayers)
                _ActionButton(
                  label: '새 게임 시작',
                  color: const Color(0xFFA29BFE),
                  onTap: () => sock.newUnoGame(),
                )
              else
                const _WaitingBadge(),
            ] else
              Expanded(child: _buildGame(sock, isMyTurn)),
          ],
        ),
      ),
    );
  }

  Widget _buildGame(SocketService sock, bool isMyTurn) {
    final topColor = _cardColor(sock.unoTopCard);
    return Column(
      children: [
        _TurnIndicator(isMyTurn: isMyTurn, currentPlayer: sock.unoCurrentPlayer ?? ''),
        const SizedBox(height: 20),
        _ScoreRow(p1Count: sock.unoP1Count ?? 0, p2Count: sock.unoP2Count ?? 0),
        const SizedBox(height: 24),
        _DiscardPile(topCard: sock.unoTopCard ?? '?', color: topColor),
        const SizedBox(height: 24),
        Text(
          '내 손패 (${sock.unoHand.length}장)',
          style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (sock.unoHand.isNotEmpty)
          Expanded(child: _HandView(hand: sock.unoHand, isMyTurn: isMyTurn, onPlay: (id) => sock.playUnoCard(id)))
        else
          const Expanded(child: Center(child: Text('카드 없음', style: TextStyle(color: kTextMuted)))),
        const SizedBox(height: 16),
        if (isMyTurn)
          _DrawButton(onTap: () => sock.drawUnoCard()),
      ],
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final bool isMyTurn;
  final String currentPlayer;
  const _TurnIndicator({required this.isMyTurn, required this.currentPlayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: (isMyTurn ? kSuccess : kAccent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isMyTurn ? kSuccess : kAccent).withOpacity(0.35)),
      ),
      child: Center(
        child: Text(
          isMyTurn ? '내 차례! 카드를 선택하세요' : '$currentPlayer의 차례',
          style: GoogleFonts.notoSans(
            color: isMyTurn ? kSuccess : kAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int p1Count;
  final int p2Count;
  const _ScoreRow({required this.p1Count, required this.p2Count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CountBadge(label: '나', count: p1Count, color: kPrimary),
        Text('vs', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        _CountBadge(label: '상대', count: p2Count, color: kAccent),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count장',
          style: GoogleFonts.notoSans(color: color, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(label, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
      ],
    );
  }
}

class _DiscardPile extends StatelessWidget {
  final String topCard;
  final Color color;
  const _DiscardPile({required this.topCard, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 120,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 16)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            topCard.split(' ').lastOrNull ?? '?',
            style: GoogleFonts.notoSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            topCard.split(' ').firstOrNull ?? '',
            style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _HandView extends StatelessWidget {
  final List<dynamic> hand;
  final bool isMyTurn;
  final void Function(String) onPlay;
  const _HandView({required this.hand, required this.isMyTurn, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: hand.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (ctx, i) {
        final card = hand[i];
        final id = card is Map ? '${card['id']}' : '$i';
        final color = card is Map ? '${card['color']}' : 'wild';
        final value = card is Map ? '${card['value']}' : '?';
        final cardColor = _cardColorFromStr(color);

        return GestureDetector(
          onTap: isMyTurn ? () => onPlay(id) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 70,
            height: 100,
            decoration: BoxDecoration(
              color: cardColor.withOpacity(isMyTurn ? 0.25 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMyTurn ? cardColor : kBorder,
                width: isMyTurn ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.notoSans(
                    color: isMyTurn ? cardColor : kTextMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Color _cardColorFromStr(String s) {
    switch (s.toLowerCase()) {
      case 'red': return const Color(0xFFFF5252);
      case 'blue': return const Color(0xFF448AFF);
      case 'green': return const Color(0xFF69F0AE);
      case 'yellow': return const Color(0xFFFFD740);
      default: return const Color(0xFF9575CD);
    }
  }
}

class _DrawButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DrawButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_card, size: 18),
      label: const Text('카드 뽑기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _WinScreen extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinScreen({required this.winner, required this.userId});

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
            isMe ? 'UNO 승리!' : '$winner 승리',
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

// re-use shared widgets
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
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
        ),
        child: MaterialButton(
          onPressed: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: GoogleFonts.notoSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _WaitingBadge extends StatelessWidget {
  const _WaitingBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
          const SizedBox(width: 10),
          Text('상대방을 기다리는 중...', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
