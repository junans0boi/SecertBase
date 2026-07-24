import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class OldMaidScreen extends StatefulWidget {
  const OldMaidScreen({super.key});

  @override
  State<OldMaidScreen> createState() => _OldMaidScreenState();
}

class _OldMaidScreenState extends State<OldMaidScreen> {
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
    _socket.startOldMaid();
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Text(
              '도둑잡기 가이드 🃏',
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideSection(
                '🎯 목표',
                '손패의 카드를 먼저 모두 버리세요! 마지막까지 조커(JOKER)를 든 사람이 패배합니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🃏 초기 카드 배분',
                '카드가 나눠지면 같은 숫자의 짝 카드는 자동으로 버려집니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🎮 플레이 방법',
                '내 턴에 상대방의 뒤집힌 카드 중 1장을 뽑습니다.\n뽑은 카드가 내 손패와 짝이 맞으면 자동으로 버려집니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '👑 승패 판정',
                '모든 짝이 버려지고 마지막 조커 1장이 남아있는 사람이 최종 패배합니다!',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '확인',
              style: TextStyle(
                color: Colors.amberAccent.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSans(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: GoogleFonts.notoSans(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _socket.oldmaidState;
    final isFinished = state != null && state['status'] == 'finished';

    return GameScaffold(
      title: '도둑잡기 🃏',
      actions: [
        IconButton(
          icon: const Icon(
            Icons.help_outline_rounded,
            color: Colors.amberAccent,
          ),
          onPressed: _showGuideDialog,
          tooltip: '게임방법',
        ),
      ],
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
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
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.withValues(alpha: 0.1),
                              ),
                              child: const Text(
                                '🃏',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '도둑잡기 (Old Maid)',
                              style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '상대의 손패에서 카드를 뽑아 짝을 맞춰 버리세요.\n마지막 조커(JOKER)를 쥐고 있는 사람이 패배합니다!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.notoSans(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showGuideDialog,
                                  icon: const Icon(
                                    Icons.help_outline,
                                    size: 18,
                                    color: Colors.amberAccent,
                                  ),
                                  label: Text(
                                    '가이드',
                                    style: GoogleFonts.notoSans(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.amberAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _startGame,
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.black,
                                  ),
                                  label: Text(
                                    '게임 시작',
                                    style: GoogleFonts.notoSans(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amberAccent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildGameTable(state),
                        const SizedBox(height: 20),
                        if (isFinished) _buildResultSection(state),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTable(Map<String, dynamic> state) {
    final myId = _socket.userId ?? '';
    final turn = state['turn'] as String?;
    final isMyTurn = turn == myId;
    final players = (state['players'] as Map<String, dynamic>?) ?? {};
    final playerIds = players.keys.toList();
    final opponentId = playerIds.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    final myHand =
        ((players[myId] as Map<String, dynamic>?)?['hand'] as List?) ?? [];
    final opponentHand =
        ((players[opponentId] as Map<String, dynamic>?)?['hand'] as List?) ??
        [];

    final lastDrawn = state['lastDrawnCard'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Turn Indicator Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isMyTurn
                ? Colors.amberAccent.withValues(alpha: 0.15)
                : Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMyTurn ? Colors.amberAccent : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMyTurn
                    ? Icons.touch_app_rounded
                    : Icons.hourglass_top_rounded,
                color: isMyTurn ? Colors.amberAccent : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isMyTurn
                    ? '내 턴! 상대 카드를 터치해서 뽑으세요'
                    : '상대방 턴! 내 카드를 선택하는 중입니다...',
                style: GoogleFonts.notoSans(
                  color: isMyTurn ? Colors.amberAccent : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Opponent Hand Section (Face down cards to pick from)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.purpleAccent,
                        child: Text('👤', style: TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '상대방 손패 (${opponentHand.length}장)',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (isMyTurn)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '1장 선택',
                        style: GoogleFonts.notoSans(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < opponentHand.length; i++)
                    _buildOpponentCardWidget(
                      card: opponentHand[i] as Map<String, dynamic>,
                      isMyTurn: isMyTurn && state['status'] == 'playing',
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Center Info / Discarded Pairs info
        if (lastDrawn != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              lastDrawn['wasPairRemoved'] == true
                  ? '✨ 최근 뽑은 카드로 짝이 맞춰져 카드를 버렸습니다!'
                  : '🃏 최근 뽑은 카드를 손패에 추가했습니다.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: lastDrawn['wasPairRemoved'] == true
                    ? Colors.greenAccent
                    : Colors.white70,
                fontSize: 13,
              ),
            ),
          ),

        const SizedBox(height: 16),

        // My Hand Section (Face up cards)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          ' me ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '내 손패 (${myHand.length}장)',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in myHand)
                    _buildMyCardWidget(card as Map<String, dynamic>),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpponentCardWidget({
    required Map<String, dynamic> card,
    required bool isMyTurn,
  }) {
    final cardId = card['id']?.toString() ?? '';

    return InkWell(
      onTap: isMyTurn ? () => _socket.drawOldMaidCard(cardId) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 58,
        height: 86,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isMyTurn
                ? [const Color(0xFFD97706), const Color(0xFF78350F)]
                : [const Color(0xFF334155), const Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMyTurn ? Colors.amberAccent : Colors.white30,
            width: isMyTurn ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isMyTurn
                  ? Colors.amberAccent.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: isMyTurn ? 8 : 4,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '🂠',
            style: TextStyle(
              fontSize: 32,
              color: isMyTurn ? Colors.amberAccent : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyCardWidget(Map<String, dynamic> card) {
    final isJoker = card['isJoker'] == true;
    final suit = card['suit'] ?? '';
    final rank = card['rank'] ?? '';
    final isRed = suit == '♥' || suit == '♦';

    if (isJoker) {
      return Container(
        width: 58,
        height: 86,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF881337), Color(0xFF4C0519)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🃏', style: TextStyle(fontSize: 28)),
            SizedBox(height: 2),
            Text(
              'JOKER',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 58,
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rank,
              style: TextStyle(
                color: isRed
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 16,
                height: 1,
              ),
            ),
            Center(
              child: Text(
                suit,
                style: TextStyle(
                  color: isRed
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F172A),
                  fontSize: 24,
                  height: 1,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                rank,
                style: TextStyle(
                  color: isRed
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(Map<String, dynamic> state) {
    final result = state['result'] as Map<String, dynamic>?;
    final winner = result?['winner'] as String?;
    final myId = _socket.userId ?? '';

    final isWinner = winner == myId;
    final text = isWinner ? '🎉 도둑잡기 승리했습니다!' : '😭 조커를 가져서 패배했습니다...';
    final color = isWinner ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    final icon = isWinner
        ? Icons.emoji_events_rounded
        : Icons.sentiment_very_dissatisfied_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            text,
            style: GoogleFonts.notoSans(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            label: Text(
              '다시 하기',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
