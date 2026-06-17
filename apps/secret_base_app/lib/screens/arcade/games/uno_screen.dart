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

  static Color _cardColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('red')) return const Color(0xFFE53935);
    if (l.contains('blue')) return const Color(0xFF1E88E5);
    if (l.contains('green')) return const Color(0xFF43A047);
    if (l.contains('yellow')) return const Color(0xFFFDD835);
    return const Color(0xFF7B1FA2); // wild
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final isMyTurn = sock.unoCurrentPlayer == sock.userId;
    final twoPlayers = sock.presenceUsers.length == 2;

    if (sock.unoWinner != null) {
      return GameScaffold(
        title: '🃏 UNO',
        child: _WinScreen(winner: sock.unoWinner!, userId: sock.userId),
      );
    }

    if (!sock.unoActive) {
      return GameScaffold(
        title: '🃏 UNO',
        child: _Lobby(twoPlayers: twoPlayers, onStart: () => sock.newUnoGame()),
      );
    }

    return GameScaffold(
      title: '🃏 UNO',
      child: _buildGame(sock, isMyTurn),
    );
  }

  Widget _buildGame(SocketService sock, bool isMyTurn) {
    final topColor = _cardColor(sock.unoTopCard ?? '');
    final myCount = sock.unoHand.length;
    final opponents = sock.presenceUsers.where((u) => u != sock.userId).toList();
    final opponentId = opponents.isNotEmpty ? opponents.first : '상대';
    final opponentCount = sock.unoP2Count ?? 0;

    return Column(
      children: [
        // Turn + score header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isMyTurn ? kSuccess.withOpacity(0.06) : kAccent.withOpacity(0.06),
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            // My info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('나 (${sock.userId ?? ''})', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11)),
              Text('$myCount장', style: GoogleFonts.notoSans(color: kPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            ])),
            // Turn indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMyTurn ? kSuccess.withOpacity(0.12) : kAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isMyTurn ? kSuccess.withOpacity(0.4) : kAccent.withOpacity(0.4)),
              ),
              child: Text(
                isMyTurn ? '내 차례' : '상대 차례',
                style: GoogleFonts.notoSans(color: isMyTurn ? kSuccess : kAccent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            // Opponent info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(opponentId, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11)),
              Text('$opponentCount장', style: GoogleFonts.notoSans(color: kAccent, fontSize: 22, fontWeight: FontWeight.w800)),
            ])),
          ]),
        ),

        // Discard pile
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Text('버린 카드', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
            const SizedBox(height: 8),
            _UnoCard(
              colorStr: sock.unoTopCard?.split(' ').firstOrNull ?? 'wild',
              value: sock.unoTopCard?.split(' ').lastOrNull ?? '?',
              width: 80, height: 110, fontSize: 22,
              onTap: null,
            ),
          ]),
        ),

        // My hand
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('내 손패', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
            const SizedBox(width: 8),
            if (sock.unoHand.isEmpty && isMyTurn)
              Text('카드가 없으면 뽑으세요!', style: GoogleFonts.notoSans(color: kError, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 8),

        // Hand cards
        Expanded(
          child: sock.unoHand.isEmpty
              ? Center(child: Text(
                  isMyTurn ? '카드가 없어요. 아래 "뽑기" 버튼을 눌러요!' : '카드를 기다리는 중...',
                  style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: sock.unoHand.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final card = sock.unoHand[i];
                    final id = card is Map ? '${card['id']}' : '$i';
                    final color = card is Map ? '${card['color']}' : 'wild';
                    final value = card is Map ? '${card['value']}' : '?';
                    return _UnoCard(
                      colorStr: color,
                      value: value,
                      width: 68, height: 96, fontSize: 16,
                      onTap: isMyTurn ? () => _onPlayCard(id, color) : null,
                    );
                  },
                ),
        ),

        // Draw button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isMyTurn ? () => sock.drawUnoCard() : null,
              icon: Icon(Icons.add_card, size: 18, color: isMyTurn ? kPrimary : kTextMuted),
              label: Text(
                isMyTurn ? '카드 뽑기' : '상대방 차례...',
                style: GoogleFonts.notoSans(color: isMyTurn ? kPrimary : kTextMuted, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isMyTurn ? kPrimary : kBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPlayCard(String id, String color) {
    if (color == 'wild') {
      _showColorPicker(id);
    } else {
      _socket.playUnoCard(id);
    }
  }

  void _showColorPicker(String cardId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('색상을 선택하세요', style: GoogleFonts.notoSans(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final c in ['red', 'blue', 'green', 'yellow'])
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _socket.playUnoCard(cardId, color: c);
                },
                child: Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _cardColor(c),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _cardColor(c).withOpacity(0.4), blurRadius: 12)],
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ─── UNO 카드 위젯 ────────────────────────────────────────────────

class _UnoCard extends StatelessWidget {
  final String colorStr;
  final String value;
  final double width;
  final double height;
  final double fontSize;
  final VoidCallback? onTap;
  const _UnoCard({
    required this.colorStr, required this.value,
    required this.width, required this.height, required this.fontSize,
    required this.onTap,
  });

  Color get _bg {
    switch (colorStr.toLowerCase()) {
      case 'red': return const Color(0xFFE53935);
      case 'blue': return const Color(0xFF1E88E5);
      case 'green': return const Color(0xFF43A047);
      case 'yellow': return const Color(0xFFFDD835);
      default: return const Color(0xFF424242); // wild/black
    }
  }

  Color get _textColor => colorStr.toLowerCase() == 'yellow' ? Colors.black87 : Colors.white;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(color: _bg.withOpacity(onTap != null ? 0.5 : 0.2), blurRadius: onTap != null ? 10 : 4, offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(children: [
          // Top-left
          Positioned(top: 5, left: 5,
            child: Text(value, style: GoogleFonts.notoSans(color: _textColor, fontSize: fontSize * 0.55, fontWeight: FontWeight.w800)),
          ),
          // Center
          Center(child: Text(
            value,
            style: GoogleFonts.notoSans(color: _textColor, fontSize: fontSize, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          )),
          // Tap highlight
          if (onTap != null)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            )),
        ]),
      ),
    );
  }
}

// ─── 로비 ─────────────────────────────────────────────────────────

class _Lobby extends StatelessWidget {
  final bool twoPlayers;
  final VoidCallback onStart;
  const _Lobby({required this.twoPlayers, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF7B1FA2).withOpacity(0.08), const Color(0xFFA29BFE).withOpacity(0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.2)),
          ),
          child: Column(children: [
            const Text('🃏', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('UNO', style: GoogleFonts.notoSans(color: kText, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              twoPlayers ? '게임을 시작해보세요!' : '상대방을 기다리는 중...',
              style: GoogleFonts.notoSans(color: kTextSub, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text('손패를 모두 버리면 승리!', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 32),
        if (twoPlayers)
          SizedBox(
            width: double.infinity, height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7B1FA2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF7B1FA2).withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: MaterialButton(
                onPressed: onStart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Text('새 게임 시작', style: GoogleFonts.notoSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
              const SizedBox(width: 10),
              Text('상대방이 접속하면 시작할 수 있어요', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
            ]),
          ),
      ]),
    );
  }
}

// ─── 승리 화면 ────────────────────────────────────────────────────

class _WinScreen extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinScreen({required this.winner, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(isMe ? '🎉' : '😢', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(
            isMe ? 'UNO! 내가 이겼어요!' : '$winner 승리!',
            style: GoogleFonts.notoSans(color: isMe ? kSuccess : kError, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(isMe ? '대단해요! 💕' : '다음엔 더 잘할 수 있어요!', style: GoogleFonts.notoSans(color: kTextSub, fontSize: 15)),
        ]),
      ),
    );
  }
}
