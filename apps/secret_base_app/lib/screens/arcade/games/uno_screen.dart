import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../../../core/uno_audio.dart';
import '../../../ui/uno_board.dart';
import '../../../widgets/game_menu.dart';

class UnoScreen extends StatefulWidget {
  const UnoScreen({super.key});

  @override
  State<UnoScreen> createState() => _UnoScreenState();
}

class _UnoScreenState extends State<UnoScreen> {
  final _socket = SocketService();
  String? _lastWinner;
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    _socket.addListener(_rebuild);
    // Unlock audio when UNO screen opens (web autoplay policy)
    UnoAudio.instance.unlock();
  }

  @override
  void dispose() {
    _socket.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    final w = _socket.unoWinner;
    if (w == null) {
      _lastWinner = null; // 새 게임 시작 시 리셋
    } else if (w != _lastWinner) {
      _lastWinner = w;
      _resultShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult(w));
    }
    setState(() {});
  }

  void _showResult(String winner) {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final isMe = winner == _socket.userId;
    if (isMe) {
      UnoAudio.instance.victory();
    } else {
      UnoAudio.instance.defeat();
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ResultDialog(
        winner: winner,
        userId: _socket.userId,
        onRestart: () {
          Navigator.of(context).pop();
          _socket.newUnoGame(mode: _socket.unoMode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sock = _socket;
    final currentUser = sock.userId ?? 'jun';

    return Scaffold(
      backgroundColor: const Color(0xFF10121C),
      body: SafeArea(
        child: GameMenuListener(
          gameType: 'uno',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShort = constraints.maxHeight < 520;
              final topInset = isShort ? 52.0 : 86.0;

              return Stack(
                children: [
                  Positioned.fill(
                    child: UnoBoard(
                      gameId: sock.unoActive ? 'active' : null,
                      turn: sock.unoCurrentPlayer,
                      p1Count: sock.unoP1Count,
                      p2Count: sock.unoP2Count,
                      hand: sock.unoHand,
                      topCard: sock.unoTopCardMap,
                      declaredColor: sock.unoDeclaredColor,
                      mode: sock.unoMode,
                      drawStack: sock.unoDrawStack,
                      drawStackType: sock.unoDrawStackType,
                      onNewGame: () =>
                          sock.newUnoGame(mode: sock.selectedUnoMode),
                      onDrawCard: sock.drawUnoCard,
                      onPlayCard: (cardId, color) =>
                          sock.playUnoCard(cardId, color: color),
                      onChallengeDraw4: sock.challengeDraw4,
                      currentUser: currentUser,
                      pendingCall: sock.unoPendingCall,
                      catchable: sock.unoCatchable,
                      onUnoButton: () {
                        if (sock.unoPendingCall) {
                          UnoAudio.instance.unoCall();
                        } else if (sock.unoCatchable) {
                          UnoAudio.instance.unoCaught();
                        }
                        sock.pressUnoButton();
                      },
                      lastSpecialCard: sock.unoLastSpecialCard,
                      lastSpecialBy: sock.unoLastSpecialBy,
                      lastSpecialAt: sock.unoLastSpecialAt,
                      topInset: topInset,
                    ),
                  ),
                  if (sock.unoActive)
                    Positioned(
                      right: 8,
                      top: topInset + 10,
                      child: _UnoReactionBar(onReact: sock.sendUnoReaction),
                    ),
                  if (sock.unoReactionType != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _UnoGiftBurst(
                          key: ValueKey(sock.unoReactionAt),
                          type: sock.unoReactionType!,
                          by: sock.unoReactionBy,
                          isMe: sock.unoReactionBy == sock.userId,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _UnoTopOverlay(
                      sock: sock,
                      compact: isShort,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (sock.unoWinner != null)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: _WinBanner(
                        winner: sock.unoWinner!,
                        userId: sock.userId,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UnoTopOverlay extends StatelessWidget {
  final SocketService sock;
  final bool compact;
  final VoidCallback onBack;

  const _UnoTopOverlay({
    required this.sock,
    required this.compact,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.56),
            Colors.black.withValues(alpha: compact ? 0.12 : 0.0),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, compact ? 2 : 6, 8, compact ? 4 : 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: compact ? 36 : 42,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Text(
                      '🃏 UNO',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  GameMenuButton(
                    hasRestart: sock.unoActive,
                    restartWaiting: sock.restartWaiting,
                    onRequestRestart: () => sock.requestRestart('uno'),
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
            if (!compact) _UnoStatus(sock: sock),
          ],
        ),
      ),
    );
  }
}

class _UnoReactionBar extends StatelessWidget {
  final void Function(String type) onReact;
  const _UnoReactionBar({required this.onReact});

  static const _gifts = [
    ('cake', '🎂'),
    ('candy', '🍬'),
    ('coffee', '☕'),
    ('pizza', '🍕'),
    ('pillow', '🛏️'),
    ('tomato', '🍅'),
    ('flyby', '✈️'),
    ('sportscar', '🏎️'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _gifts
            .map(
              (gift) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => onReact(gift.$1),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Text(
                        gift.$2,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _UnoGiftBurst extends StatefulWidget {
  final String type;
  final String? by;
  final bool isMe;

  const _UnoGiftBurst({
    super.key,
    required this.type,
    required this.by,
    required this.isMe,
  });

  @override
  State<_UnoGiftBurst> createState() => _UnoGiftBurstState();
}

class _UnoGiftBurstState extends State<_UnoGiftBurst> {
  @override
  void initState() {
    super.initState();
    UnoAudio.instance.giftReaction(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    final gift = _UnoGiftSpec.fromType(widget.type);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: gift.durationMs),
      builder: (context, t, _) {
        final opacity = t < 0.18
            ? t / 0.18
            : t > 0.78
            ? (1 - t) / 0.22
            : 1.0;
        final curved = Curves.easeOutCubic.transform(t.clamp(0, 1));

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Stack(
            children: [
              ...List.generate(gift.count, (i) {
                final lane = i - ((gift.count - 1) / 2);
                final startX = widget.isMe ? -0.34 : 0.34;
                final endX = widget.isMe ? 0.18 : -0.18;
                final dxFactor = startX + ((endX - startX) * curved);
                final arc =
                    math.sin((t + i * 0.045).clamp(0, 1) * math.pi) *
                    (72 + (i % 3) * 18);
                final wobble = math.sin((t * 8) + i) * 10;

                return Align(
                  alignment: Alignment(dxFactor, -0.08 + lane * 0.05),
                  child: Transform.translate(
                    offset: Offset(wobble, -arc),
                    child: Transform.rotate(
                      angle: (widget.isMe ? 1 : -1) * (0.9 * t + i * 0.08),
                      child: Transform.scale(
                        scale: 0.82 + 0.28 * math.sin(t * math.pi),
                        child: Text(
                          gift.emoji,
                          style: TextStyle(fontSize: gift.fontSize),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              Align(
                alignment: const Alignment(0, 0.42),
                child: Text(
                  widget.isMe ? '나의 선물' : '${widget.by ?? '상대'}의 선물',
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnoGiftSpec {
  final String emoji;
  final int count;
  final double fontSize;
  final int durationMs;

  const _UnoGiftSpec({
    required this.emoji,
    required this.count,
    required this.fontSize,
    required this.durationMs,
  });

  static _UnoGiftSpec fromType(String type) {
    switch (type) {
      case 'cake':
        return const _UnoGiftSpec(
          emoji: '🎂',
          count: 9,
          fontSize: 38,
          durationMs: 1350,
        );
      case 'candy':
        return const _UnoGiftSpec(
          emoji: '🍬',
          count: 7,
          fontSize: 36,
          durationMs: 1100,
        );
      case 'coffee':
        return const _UnoGiftSpec(
          emoji: '☕',
          count: 5,
          fontSize: 38,
          durationMs: 1150,
        );
      case 'pizza':
        return const _UnoGiftSpec(
          emoji: '🍕',
          count: 6,
          fontSize: 38,
          durationMs: 1150,
        );
      case 'pillow':
        return const _UnoGiftSpec(
          emoji: '🛏️',
          count: 9,
          fontSize: 34,
          durationMs: 1300,
        );
      case 'tomato':
        return const _UnoGiftSpec(
          emoji: '🍅',
          count: 8,
          fontSize: 36,
          durationMs: 1050,
        );
      case 'flyby':
        return const _UnoGiftSpec(
          emoji: '✈️',
          count: 3,
          fontSize: 46,
          durationMs: 1250,
        );
      case 'sportscar':
        return const _UnoGiftSpec(
          emoji: '🏎️',
          count: 3,
          fontSize: 46,
          durationMs: 1250,
        );
      default:
        return const _UnoGiftSpec(
          emoji: '🎁',
          count: 5,
          fontSize: 38,
          durationMs: 1100,
        );
    }
  }
}

class _UnoStatus extends StatelessWidget {
  final SocketService sock;
  const _UnoStatus({required this.sock});

  @override
  Widget build(BuildContext context) {
    final isMyTurn = sock.unoCurrentPlayer == sock.userId;
    final modeLabel = sock.unoActive
        ? (sock.unoMode == 'classic' ? '클래식' : '고와일드')
        : (sock.selectedUnoMode == 'classic' ? '클래식' : '고와일드');
    final text = !sock.unoActive
        ? '$modeLabel · 새 게임을 시작하면 7장씩 받고 바로 플레이합니다.'
        : isMyTurn
        ? '$modeLabel · 내 턴 · 낼 수 있는 카드를 터치하거나 더미를 눌러 뽑기'
        : '$modeLabel · ${sock.unoCurrentPlayer ?? '상대'} 차례입니다';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn
              ? kSuccess.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isMyTurn ? kSuccess : Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Slim inline banner (always visible while winner != null)
class _WinBanner extends StatelessWidget {
  final String winner;
  final String? userId;
  const _WinBanner({required this.winner, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? kSuccess.withValues(alpha: 0.1)
            : kError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMe ? kSuccess : kError),
      ),
      child: Text(
        isMe ? '🎉 UNO! 손패를 모두 냈어요!' : '$winner 승리! 다음 판에서 복수하자 😤',
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          color: isMe ? kSuccess : kError,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// Full-screen result dialog
class _ResultDialog extends StatelessWidget {
  final String winner;
  final String? userId;
  final VoidCallback onRestart;

  const _ResultDialog({
    required this.winner,
    required this.userId,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = winner == userId;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF10121C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isMe
                ? const Color(0xFF4CAE4C).withValues(alpha: 0.6)
                : const Color(0xFFE52521).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isMe ? const Color(0xFF4CAE4C) : const Color(0xFFE52521))
                  .withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isMe ? '🏆' : '😢', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              isMe ? 'UNO 승리!' : '패배...',
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isMe ? '손패를 모두 냈어요! 최고예요!' : '$winner 님이 먼저 UNO를 달성했어요.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onRestart,
                    style: FilledButton.styleFrom(
                      backgroundColor: isMe
                          ? const Color(0xFF4CAE4C)
                          : const Color(0xFFE52521),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isMe ? '한 판 더!' : '복수하기!',
                      style: GoogleFonts.notoSans(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
