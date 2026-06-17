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
      child: sock.yutWinner != null
          ? _WinBanner(winner: sock.yutWinner!, userId: sock.userId)
          : !sock.yutActive
              ? _buildLobby(twoPlayers, sock)
              : _buildGame(sock, isMyTurn),
    );
  }

  Widget _buildLobby(bool twoPlayers, SocketService sock) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1976D2).withOpacity(0.08), const Color(0xFF42A5F5).withOpacity(0.04)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.2)),
            ),
            child: Column(children: [
              const Text('🀄', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text('윷놀이', style: GoogleFonts.notoSans(color: kText, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                twoPlayers ? '게임을 시작해보세요!' : '상대방을 기다리는 중...',
                style: GoogleFonts.notoSans(color: kTextSub, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text('4개의 말을 모두 완주하면 승리!', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 32),
          if (twoPlayers)
            _BigButton(label: '새 게임 시작', color: const Color(0xFF1976D2), onTap: () => sock.newYutGame())
          else
            _WaitingBadge(text: '상대방이 접속하면 시작할 수 있어요'),
        ],
      ),
    );
  }

  Widget _buildGame(SocketService sock, bool isMyTurn) {
    final myId = sock.userId ?? '';
    final opponents = sock.presenceUsers.where((u) => u != myId).toList();
    final opponentId = opponents.isNotEmpty ? opponents.first : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Turn indicator
          _TurnBadge(isMyTurn: isMyTurn, currentTurn: sock.yutCurrentTurn ?? ''),
          const SizedBox(height: 16),

          // Board: My pieces + Opponent pieces
          Row(
            children: [
              Expanded(child: _PiecesPanel(
                label: '나 ($myId)',
                pieces: sock.yutPieces[myId] ?? [0, 0, 0, 0],
                color: kPrimary,
                isMe: true,
              )),
              const SizedBox(width: 10),
              Expanded(child: _PiecesPanel(
                label: '상대 ($opponentId)',
                pieces: sock.yutPieces[opponentId] ?? [0, 0, 0, 0],
                color: kAccent,
                isMe: false,
              )),
            ],
          ),
          const SizedBox(height: 16),

          // Last throw result
          if (sock.yutLastThrow != null)
            _ThrowResultCard(result: sock.yutLastThrow!),
          if (sock.yutLastThrow != null) const SizedBox(height: 12),

          // Pending moves
          if (sock.yutPendingMoves.isNotEmpty)
            _PendingCard(pending: sock.yutPendingMoves),
          if (sock.yutPendingMoves.isNotEmpty) const SizedBox(height: 12),

          // Move buttons when pending moves exist
          if (isMyTurn && sock.yutPendingMoves.isNotEmpty) ...[
            Text('이동할 말 번호를 선택하세요', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13)),
            const SizedBox(height: 10),
            _PieceSelectRow(
              pieces: sock.yutPieces[myId] ?? [0, 0, 0, 0],
              onSelect: (i) => sock.moveYut(i),
            ),
            const SizedBox(height: 16),
          ],

          // Action button
          if (isMyTurn && sock.yutPendingMoves.isEmpty)
            _BigButton(
              label: '🎲 윷 던지기!',
              color: const Color(0xFF1976D2),
              onTap: () => sock.throwYut(),
            )
          else if (!isMyTurn)
            _WaitingBadge(text: '${sock.yutCurrentTurn ?? "상대방"}의 차례'),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── 말 패널 (4개 말 위치) ─────────────────────────────────────────

class _PiecesPanel extends StatelessWidget {
  final String label;
  final List<int> pieces;
  final Color color;
  final bool isMe;
  const _PiecesPanel({required this.label, required this.pieces, required this.color, required this.isMe});

  String _posLabel(int pos) {
    if (pos == 0) return '출발';
    if (pos >= 20) return '완주!';
    return '$pos칸';
  }

  @override
  Widget build(BuildContext context) {
    final finished = pieces.where((p) => p >= 20).length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? color.withOpacity(0.06) : kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: isMe ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: GoogleFonts.notoSans(color: color, fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            Text('$finished/4 완주', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          ...List.generate(4, (i) {
            final pos = pieces[i];
            final done = pos >= 20;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFF2EB872).withOpacity(0.15) : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: done ? kSuccess : color.withOpacity(0.4)),
                  ),
                  child: Center(child: Text('${i + 1}', style: GoogleFonts.notoSans(color: done ? kSuccess : color, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 6),
                Expanded(child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (pos / 20).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: done ? kSuccess : color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                )),
                const SizedBox(width: 6),
                Text(_posLabel(pos), style: GoogleFonts.notoSans(color: done ? kSuccess : kTextSub, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 말 선택 버튼 ─────────────────────────────────────────────────

class _PieceSelectRow extends StatelessWidget {
  final List<int> pieces;
  final void Function(int) onSelect;
  const _PieceSelectRow({required this.pieces, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (i) {
        final pos = pieces[i];
        final done = pos >= 20;
        return GestureDetector(
          onTap: done ? null : () => onSelect(i),
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: done ? kBorder.withOpacity(0.5) : kPrimary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: done ? kBorder : kPrimary, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${i + 1}', style: GoogleFonts.notoSans(color: done ? kTextMuted : kPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(done ? '완주' : '${pos}칸', style: GoogleFonts.notoSans(color: done ? kTextMuted : kTextSub, fontSize: 9)),
            ]),
          ),
        );
      }),
    );
  }
}

// ─── 공용 위젯들 ──────────────────────────────────────────────────

class _TurnBadge extends StatelessWidget {
  final bool isMyTurn;
  final String currentTurn;
  const _TurnBadge({required this.isMyTurn, required this.currentTurn});

  @override
  Widget build(BuildContext context) {
    final c = isMyTurn ? kSuccess : kAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isMyTurn ? Icons.play_circle : Icons.hourglass_empty, color: c, size: 18),
        const SizedBox(width: 8),
        Text(
          isMyTurn ? '내 차례입니다! 윷을 던지세요' : '$currentTurn의 차례',
          style: GoogleFonts.notoSans(color: c, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

class _ThrowResultCard extends StatelessWidget {
  final String result;
  const _ThrowResultCard({required this.result});

  String get _emoji {
    switch (result) {
      case '도': return '🔴';
      case '개': return '🟠';
      case '걸': return '🟡';
      case '윷': return '🟢';
      case '모': return '🔵';
      default: return '🎲';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: kGold.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('윷 결과', style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 11)),
          Text(result, style: GoogleFonts.notoSans(color: kGold, fontSize: 28, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final List<Map<String, dynamic>> pending;
  const _PendingCard({required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kGold.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.pending_actions, color: kGold, size: 18),
        const SizedBox(width: 8),
        Text('이동 대기: ${pending.length}회 남음', style: GoogleFonts.notoSans(color: kGold, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
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
  final String text;
  const _WaitingBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kTextMuted)),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13))),
      ]),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(isMe ? '🎉' : '😢', style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 20),
          Text(
            isMe ? '내가 이겼어요!' : '$winner이 이겼어요',
            style: GoogleFonts.notoSans(color: isMe ? kSuccess : kError, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(isMe ? '축하해요! 💕' : '다음엔 이길 수 있어요!', style: GoogleFonts.notoSans(color: kTextSub, fontSize: 15)),
        ]),
      ),
    );
  }
}
