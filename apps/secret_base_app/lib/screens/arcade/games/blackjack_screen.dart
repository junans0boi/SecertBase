import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/socket_service.dart';
import '../../../widgets/game_scaffold.dart';

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({super.key});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
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
    _socket.startBlackjack();
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
              '블랙잭 가이드 ♠️',
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
                '카드 합이 21에 가장 가깝게 만드세요 (21 초과 시 버스트/패배).',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🃏 카드의 점수',
                '• 2~10: 숫자 그대로\n• J, Q, K: 10점\n• A: 1점 또는 11점 (자동 유연 적용)',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🎮 플레이 방법',
                '1. **히트 (Hit)**: 카드를 1장 더 받습니다.\n2. **스탠드 (Stand)**: 카드 받기를 멈추고 현 점수를 확정합니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🤖 딜러 룰',
                '딜러는 카드의 합이 17 이상이 될 때까지 무조건 카드를 받습니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🏆 승패 대결',
                '두 사람 모두 각자의 딜러와 대결을 마치면, 딜러 대비 손패 성과(승/무/패)를 서로 비교해 최종 승자를 결정합니다!',
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

  int _calculateScore(List cards) {
    int score = 0;
    int aces = 0;
    for (final card in cards) {
      final rank = card['rank']?.toString() ?? '';
      if (rank == 'A') {
        aces += 1;
        score += 11;
      } else if (['J', 'Q', 'K'].contains(rank)) {
        score += 10;
      } else {
        score += int.tryParse(rank) ?? 0;
      }
    }
    while (score > 21 && aces > 0) {
      score -= 10;
      aces -= 1;
    }
    return score;
  }

  @override
  Widget build(BuildContext me) {
    final state = _socket.blackjackState;
    final isPlaying = state != null && state['status'] == 'playing';
    final isFinished = state != null && state['status'] == 'finished';

    return GameScaffold(
      title: '블랙잭 ♠️',
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
                                '♠️',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '카지노 스타일 블랙잭',
                              style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '딜러를 꺾고 21점에 더 가까운 카드를 만드세요.\n두 사람 중 딜러 상대 결과가 더 좋은 사람이 승리합니다!',
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
                        _buildPlayerTable(state, _socket.userId ?? ''),
                        const SizedBox(height: 20),
                        if (isFinished) _buildResultSection(state),
                        if (isPlaying)
                          _buildControls(state, _socket.userId ?? ''),
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

  Widget _buildPlayerTable(Map<String, dynamic> state, String myId) {
    final players = (state['players'] as Map<String, dynamic>?) ?? {};
    final dealers = (state['dealers'] as Map<String, dynamic>?) ?? {};

    final myPlayerData = (players[myId] as Map<String, dynamic>?) ?? {};
    final myDealerData = (dealers[myId] as Map<String, dynamic>?) ?? {};

    final isFinished = state['status'] == 'finished';

    final myHand = (myPlayerData['hand'] as List?) ?? [];
    final dealerHand = (myDealerData['hand'] as List?) ?? [];

    final myStatus = myPlayerData['status'] ?? 'playing';

    final myScore = _calculateScore(myHand);
    final dealerScore = isFinished
        ? _calculateScore(dealerHand)
        : (dealerHand.isNotEmpty ? _calculateScore([dealerHand[0]]) : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dealer Card Container
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                        backgroundColor: Colors.amberAccent,
                        child: Text('🤖', style: TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '딜러 (AI)',
                        style: GoogleFonts.notoSans(
                          color: Colors.amberAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFinished ? '점수: $dealerScore' : '오픈: $dealerScore점',
                      style: GoogleFonts.notoSans(
                        color: Colors.amberAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                  for (int i = 0; i < dealerHand.length; i++)
                    _buildCardWidget(
                      dealerHand[i] as Map<String, dynamic>,
                      hidden: !isFinished && i == 1,
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // My Card Container
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: myStatus == 'bust'
                  ? Colors.redAccent.withValues(alpha: 0.5)
                  : (myStatus == 'stand'
                        ? Colors.blueAccent.withValues(alpha: 0.5)
                        : Colors.white24),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                        child: Text('👤', style: TextStyle(fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '나 (내 손패)',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '점수: $myScore점',
                          style: GoogleFonts.notoSans(
                            color: myScore > 21
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            myStatus,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getStatusColor(myStatus)),
                        ),
                        child: Text(
                          _getStatusText(myStatus),
                          style: GoogleFonts.notoSans(
                            color: _getStatusColor(myStatus),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                    _buildCardWidget(card as Map<String, dynamic>),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'bust':
        return Colors.redAccent;
      case 'stand':
        return Colors.blueAccent;
      case 'blackjack':
        return Colors.amberAccent;
      default:
        return Colors.greenAccent;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'bust':
        return '버스트 (Bust)';
      case 'stand':
        return '스탠드 (Stand)';
      case 'blackjack':
        return '블랙잭 (21!)';
      default:
        return '진행 중';
    }
  }

  Widget _buildCardWidget(Map<String, dynamic> card, {bool hidden = false}) {
    if (hidden) {
      return Container(
        width: 58,
        height: 86,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF334155), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.amberAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🂠',
            style: TextStyle(fontSize: 32, color: Colors.amberAccent),
          ),
        ),
      );
    }

    final suit = card['suit'] ?? '';
    final rank = card['rank'] ?? '';
    final isRed = suit == '♥' || suit == '♦';

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

  Widget _buildControls(Map<String, dynamic> state, String myId) {
    final players = (state['players'] as Map<String, dynamic>?) ?? {};
    final myData = (players[myId] as Map<String, dynamic>?) ?? {};
    final myStatus = myData['status'] ?? 'playing';

    if (myStatus != 'playing') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amberAccent,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '상대방이 게임을 마칠 때까지 대기 중...',
              style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _socket.hitBlackjack(),
            icon: const Icon(Icons.add_card_rounded, color: Colors.white),
            label: Text(
              '히트 (Hit)',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _socket.standBlackjack(),
            icon: const Icon(Icons.front_hand_rounded, color: Colors.white),
            label: Text(
              '스탠드 (Stand)',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(Map<String, dynamic> state) {
    final result = state['result'] as Map<String, dynamic>?;
    final winner = result?['winner'] as String?;
    final myId = _socket.userId ?? '';

    String text = '무승부!';
    Color color = Colors.amberAccent;
    IconData icon = Icons.balance_rounded;

    if (winner == myId) {
      text = '🎉 최종 승리했습니다!';
      color = const Color(0xFF4ADE80);
      icon = Icons.emoji_events_rounded;
    } else if (winner != null && winner != 'tie') {
      text = '😭 아쉽게 패배했습니다...';
      color = const Color(0xFFF87171);
      icon = Icons.sentiment_very_dissatisfied_rounded;
    }

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
