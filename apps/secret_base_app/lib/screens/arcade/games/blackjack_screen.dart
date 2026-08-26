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
                '각자 자기 패만 보면서 히트/스탠드를 선택합니다.\n상대 패와 점수는 라운드가 끝날 때까지 공개되지 않습니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🔒 비공개 패',
                '상대가 몇 장을 가지고 있는지만 보이고, 카드 내용과 점수는 숨겨집니다. 라운드 결과에서 모두 공개됩니다.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                '🏆 승패 대결',
                '각 라운드에서 21에 더 가까운 사람이 승리합니다. 두 라운드의 승패를 합산해 최종 승자를 정합니다.',
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
                              '1대1 블랙잭',
                              style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '각자의 패를 숨긴 채\n상대보다 21에 가깝게 만들어 보세요!',
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
                        if (state['phase'] == 'round_result')
                          _buildRoundResult(state),
                        if (isFinished) _buildResultSection(state),
                        if (isPlaying && state['phase'] != 'round_result')
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
    final players =
        (state['players'] as List?)
            ?.map((player) => player.toString())
            .toList() ??
        const <String>[];
    final hands = state['hands'] is Map
        ? Map<String, dynamic>.from(state['hands'] as Map)
        : const <String, dynamic>{};
    final statuses = state['statuses'] is Map
        ? Map<String, dynamic>.from(state['statuses'] as Map)
        : const <String, dynamic>{};
    final phase = state['phase']?.toString() ?? 'player_turn';
    final revealAll = state['status'] == 'finished' || phase == 'round_result';

    Widget handPanel({
      required String userId,
      required List hand,
      required bool isMine,
      required Color accent,
      required String status,
    }) {
      final score = isMine || revealAll ? _calculateScore(hand) : null;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
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
                Flexible(
                  child: Text(
                    '${isMine ? '내 패' : '상대 패'} · ${_socket.nameOf(userId).isEmpty ? userId : _socket.nameOf(userId)}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  score == null ? '점수: ?' : '점수: $score점',
                  style: GoogleFonts.notoSans(
                    color: score != null && score > 21
                        ? Colors.redAccent
                        : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _getStatusText(status),
              style: GoogleFonts.notoSans(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int i = 0; i < hand.length; i++)
                  _buildCardWidget(
                    hand[i] as Map<String, dynamic>,
                    hidden: !isMine && !revealAll,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (players.length < 2) return const SizedBox.shrink();

    List<dynamic> handFor(String userId) {
      final hand = hands[userId];
      return hand is List ? hand : const [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.amberAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amberAccent.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            '라운드 ${state['round'] ?? 1}/2 · ${phase == 'player_turn' ? (state['currentTurn'] == myId ? '내 턴' : '상대 턴') : '라운드 결과'}',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        handPanel(
          userId: players[0],
          hand: handFor(players[0]),
          isMine: players[0] == myId,
          accent: Colors.amberAccent,
          status: statuses[players[0]]?.toString() ?? 'playing',
        ),
        const SizedBox(height: 16),
        handPanel(
          userId: players[1],
          hand: handFor(players[1]),
          isMine: players[1] == myId,
          accent: Colors.lightBlueAccent,
          status: statuses[players[1]]?.toString() ?? 'playing',
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'hidden':
        return '상대 상태 비공개';
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
    final phase = state['phase']?.toString();
    final isMyTurn = phase == 'player_turn' && state['currentTurn'] == myId;
    if (!isMyTurn) {
      final waitingText = phase == 'player_turn'
          ? '상대가 손패를 고르는 중입니다...'
          : '라운드 결과를 정리하는 중입니다...';
      return _waitingPanel(waitingText);
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _socket.hitBlackjack,
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
            onPressed: _socket.standBlackjack,
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

  Widget _waitingPanel(String text) {
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
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundResult(Map<String, dynamic> state) {
    final round = state['lastRoundResult'] as Map<String, dynamic>?;
    if (round == null) return const SizedBox.shrink();
    final winner = round['winner']?.toString();
    final myId = _socket.userId ?? '';
    final players =
        (round['players'] as List?)
            ?.map((player) => player.toString())
            .toList() ??
        const <String>[];
    final scores = round['scores'] is Map
        ? Map<String, dynamic>.from(round['scores'] as Map)
        : const <String, dynamic>{};
    final opponentId = players.firstWhere(
      (playerId) => playerId != myId,
      orElse: () => '',
    );
    final text = winner == 'tie'
        ? '이번 라운드: 무승부'
        : winner == myId
        ? '이번 라운드: 승리'
        : '이번 라운드: 패배';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: GoogleFonts.notoSans(
              color: Colors.amberAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '나 ${scores[myId] ?? '?'}점 · 상대 ${scores[opponentId] ?? '?'}점',
            style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 14),
          ),
          if (state['round'] == 1) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _socket.nextBlackjackRound,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('2라운드 시작'),
            ),
          ] else if (winner != null) ...[
            const SizedBox(height: 8),
            const Text(
              '최종 승패를 계산합니다.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _socket.nextBlackjackRound,
              child: const Text('최종 결과 보기'),
            ),
          ],
        ],
      ),
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
