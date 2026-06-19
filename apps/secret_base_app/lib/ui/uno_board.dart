import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class UnoBoard extends StatefulWidget {
  final String? gameId;
  final String? turn;
  final int? p1Count;
  final int? p2Count;
  final List<dynamic>? hand;
  final Map<String, dynamic>? topCard;
  final String? declaredColor;
  final int drawStack;
  final String? drawStackType;
  final VoidCallback onNewGame;
  final VoidCallback onDrawCard;
  final void Function(String, String?) onPlayCard;
  final VoidCallback? onChallengeDraw4;
  final String currentUser;
  final bool pendingCall;
  final bool catchable;
  final VoidCallback? onCallUno;
  final VoidCallback? onCatchUno;
  final String? lastSpecialCard;
  final String? lastSpecialBy;

  const UnoBoard({
    super.key,
    this.gameId,
    this.turn,
    this.p1Count,
    this.p2Count,
    this.hand,
    this.topCard,
    this.declaredColor,
    this.drawStack = 0,
    this.drawStackType,
    required this.onNewGame,
    required this.onDrawCard,
    required this.onPlayCard,
    this.onChallengeDraw4,
    required this.currentUser,
    this.pendingCall = false,
    this.catchable = false,
    this.onCallUno,
    this.onCatchUno,
    this.lastSpecialCard,
    this.lastSpecialBy,
  });

  @override
  State<UnoBoard> createState() => _UnoBoardState();

  static Color getColorFromString(String? colorStr) {
    if (colorStr == 'red') return const Color(0xFFE52521);
    if (colorStr == 'blue') return const Color(0xFF0068B5);
    if (colorStr == 'green') return const Color(0xFF4CAE4C);
    if (colorStr == 'yellow') return const Color(0xFFF9D000);
    return const Color(0xFF222222);
  }
}

class _UnoBoardState extends State<UnoBoard> with TickerProviderStateMixin {
  // --- Dealing animation ---
  int _visibleCardCount = 0;
  bool _isDealing = false;
  Timer? _dealTimer;

  // --- Special card effect ---
  late AnimationController _effectCtrl;
  String? _effectCard;

  @override
  void initState() {
    super.initState();
    _effectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _effectCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _effectCard = null);
        _effectCtrl.reset();
      }
    });
  }

  @override
  void didUpdateWidget(UnoBoard old) {
    super.didUpdateWidget(old);

    // New game: reset dealing state
    if (old.gameId != null && widget.gameId == null) {
      _dealTimer?.cancel();
      _visibleCardCount = 0;
      _isDealing = false;
    }

    // Trigger dealing animation when hand is populated for the first time
    final wasEmpty = old.hand == null || old.hand!.isEmpty;
    final nowHasCards = widget.hand != null && widget.hand!.isNotEmpty;
    if (wasEmpty && nowHasCards && widget.gameId != null) {
      _startDealingAnimation();
    }

    // Trigger special card effect
    if (widget.lastSpecialCard != null &&
        widget.lastSpecialCard != old.lastSpecialCard) {
      _triggerSpecialEffect(widget.lastSpecialCard!);
    }
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _effectCtrl.dispose();
    super.dispose();
  }

  void _startDealingAnimation() {
    _dealTimer?.cancel();
    final total = widget.hand?.length ?? 7;
    setState(() {
      _visibleCardCount = 0;
      _isDealing = true;
    });
    _dealTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_visibleCardCount < total) {
        setState(() => _visibleCardCount++);
      } else {
        setState(() => _isDealing = false);
        timer.cancel();
      }
    });
  }

  void _triggerSpecialEffect(String card) {
    setState(() => _effectCard = card);
    _effectCtrl.forward(from: 0);
  }

  void _handleCardTap(BuildContext context, Map<String, dynamic> cardMap) {
    if (widget.turn != widget.currentUser) return;

    final val = cardMap['value'] as String?;
    final id = cardMap['id'] as String;

    if (val == 'wild' || val == 'wild_draw4') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            '색상 선택',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Wrap(
            spacing: 12,
            children: ['red', 'blue', 'green', 'yellow'].map((color) {
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onPlayCard(id, color);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: UnoBoard.getColorFromString(color),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    } else {
      widget.onPlayCard(id, null);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return {};
  }

  bool _isCardPlayable(Map<String, dynamic> card) {
    if (widget.turn != widget.currentUser) return false;
    final val = card['value'] as String?;
    // In draw stack mode, only matching defense cards are playable
    if (widget.drawStack > 0 && widget.drawStackType != null) {
      return val == widget.drawStackType;
    }
    // Normal playability check (mirrors server canPlayCard)
    if (val == 'wild' || val == 'wild_draw4') return true;
    final topCard = widget.topCard;
    if (topCard == null) return true;
    final effectiveColor = widget.declaredColor ?? topCard['color'];
    if (card['color'] == effectiveColor) return true;
    if (val == topCard['value']) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = widget.turn == widget.currentUser;
    final opponentCount = widget.currentUser == 'jun'
        ? (widget.p2Count ?? 0)
        : (widget.p1Count ?? 0);
    final myCount = widget.currentUser == 'jun'
        ? (widget.p1Count ?? 0)
        : (widget.p2Count ?? 0);
    final hasPendingStack = widget.drawStack > 0 && isMyTurn;

    // Wild/+4 카드는 선언된 색상으로 표시
    final rawTop = widget.topCard;
    final displayTopCard = rawTop == null
        ? null
        : () {
            final v = rawTop['value'] as String?;
            if ((v == 'wild' || v == 'wild_draw4') && widget.declaredColor != null) {
              return Map<String, dynamic>.from(rawTop)
                ..['color'] = widget.declaredColor;
            }
            return rawTop;
          }();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final handCardWidth = isCompact ? 58.0 : 70.0;
        final handCardHeight = isCompact ? 88.0 : 105.0;
        final pileCardWidth = isCompact ? 68.0 : 80.0;
        final pileCardHeight = isCompact ? 102.0 : 120.0;
        final visibleOpponentCards = opponentCount.clamp(
          0,
          isCompact ? 10 : 15,
        );

        final sortedHand = [...(widget.hand ?? [])]
          ..sort((a, b) {
            final aIsWild4 = (_asMap(a)['value'] as String?) == 'wild_draw4' ? 0 : 1;
            final bIsWild4 = (_asMap(b)['value'] as String?) == 'wild_draw4' ? 0 : 1;
            return aIsWild4.compareTo(bIsWild4);
          });
        final displayHand = _isDealing
            ? sortedHand.take(_visibleCardCount).toList()
            : sortedHand;

        return Stack(
          children: [
            Container(
              height: isCompact ? 500 : 550,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF2A2D43), Color(0xFF10121C)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: widget.gameId == null
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: widget.onNewGame,
                          icon: const Icon(Icons.play_arrow, size: 32),
                          label: const Text(
                            '새 게임 시작',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            backgroundColor: const Color(0xFFE52521),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // --- TOP: Opponent Hand ---
                          Container(
                            height: 100,
                            padding: const EdgeInsets.only(top: 16),
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Text(
                                  '상대방 (${widget.turn != widget.currentUser ? "턴" : "대기중"}) - $opponentCount장',
                                  style: TextStyle(
                                    color: widget.turn != widget.currentUser
                                        ? Colors.yellow
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Positioned(
                                  top: 24,
                                  child: Wrap(
                                    spacing: -20,
                                    children: List.generate(
                                      visibleOpponentCards,
                                      (i) => UnoCardBack(
                                        width: isCompact ? 34 : 40,
                                        height: isCompact ? 51 : 60,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- MIDDLE: Piles & Status ---
                          Expanded(
                            child: Stack(
                              children: [
                                if (widget.pendingCall)
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: _UnoCallButton(
                                      label: 'UNO!',
                                      color: const Color(0xFFE52521),
                                      onTap: widget.onCallUno ?? () {},
                                    ),
                                  ),
                                if (widget.catchable)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: _UnoCallButton(
                                      label: '잡기! 😈',
                                      color: const Color(0xFF7B1FA2),
                                      onTap: widget.onCatchUno ?? () {},
                                    ),
                                  ),
                                // Wild 카드가 아닌데 색상이 active한 경우 (일반 카드 후 color reset 등)에만 배지 표시
                                if (widget.declaredColor != null &&
                                    widget.topCard != null &&
                                    widget.topCard!['value'] != 'wild' &&
                                    widget.topCard!['value'] != 'wild_draw4')
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: UnoBoard.getColorFromString(
                                          widget.declaredColor,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Text(
                                        '색상 변경됨',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Draw stack indicator (center-top)
                                if (widget.drawStack > 0)
                                  Positioned(
                                    top: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _DrawStackBadge(
                                        count: widget.drawStack,
                                        stackType: widget.drawStackType,
                                      ),
                                    ),
                                  ),

                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Draw Pile
                                      GestureDetector(
                                        onTap: isMyTurn
                                            ? widget.onDrawCard
                                            : null,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            UnoCardBack(
                                              width: pileCardWidth,
                                              height: pileCardHeight,
                                            ),
                                            Positioned(
                                              left: -2,
                                              top: -2,
                                              child: UnoCardBack(
                                                width: pileCardWidth,
                                                height: pileCardHeight,
                                              ),
                                            ),
                                            Positioned(
                                              left: -4,
                                              top: -4,
                                              child: UnoCardBack(
                                                width: pileCardWidth,
                                                height: pileCardHeight,
                                              ),
                                            ),
                                            if (isMyTurn)
                                              Positioned(
                                                bottom: -20,
                                                left: 0,
                                                right: 0,
                                                child: Center(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: hasPendingStack
                                                          ? Colors.redAccent
                                                          : Colors.yellow,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      hasPendingStack
                                                          ? '${widget.drawStack}장 받기'
                                                          : '뽑기',
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 30),
                                      // Discard Pile (Top Card)
                                      if (displayTopCard != null)
                                        AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          transitionBuilder:
                                              (child, animation) {
                                                return ScaleTransition(
                                                  scale: CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutBack,
                                                  ),
                                                  child: RotationTransition(
                                                    turns: Tween<double>(
                                                      begin: -0.05,
                                                      end: 0.05,
                                                    ).animate(animation),
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          child: Transform.rotate(
                                            // key includes declaredColor so the card animates when color changes
                                            key: ValueKey(
                                              '${displayTopCard['id']}_${widget.declaredColor}',
                                            ),
                                            angle: 0.1,
                                            child: UnoCardFront(
                                              cardMap: displayTopCard,
                                              width: pileCardWidth,
                                              height: pileCardHeight,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // +4 Challenge button (shown when I must respond to +4)
                                if (hasPendingStack &&
                                    widget.drawStackType == 'wild_draw4' &&
                                    widget.onChallengeDraw4 != null)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: _UnoCallButton(
                                      label: '도전! 🔍',
                                      color: const Color(0xFFFF6D00),
                                      onTap: widget.onChallengeDraw4!,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // --- BOTTOM: Player Hand ---
                          Container(
                            height: 180,
                            padding: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  hasPendingStack
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : isMyTurn
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.black45,
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '내 패 ${isMyTurn ? "(내 턴!)" : ""} - $myCount장',
                                      style: TextStyle(
                                        color: hasPendingStack
                                            ? Colors.redAccent
                                            : isMyTurn
                                            ? Colors.greenAccent
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (hasPendingStack) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.drawStackType == 'draw2'
                                            ? '+2로 방어 가능'
                                            : '+4로 방어 또는 도전',
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: displayHand.isEmpty
                                      ? const Center(
                                          child: Text(
                                            '카드가 없습니다.',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: displayHand.asMap().entries.map((
                                              entry,
                                            ) {
                                              final i = entry.key;
                                              final c = entry.value;
                                              final cmap = _asMap(c);
                                              final playable = _isCardPlayable(
                                                cmap,
                                              );

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 8.0,
                                                ),
                                                child: _DealingCard(
                                                  index: i,
                                                  isDealing: _isDealing,
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    curve: Curves.easeOut,
                                                    margin: EdgeInsets.only(
                                                      bottom:
                                                          isMyTurn &&
                                                              !hasPendingStack
                                                          ? 0
                                                          : 10,
                                                    ),
                                                    child: GestureDetector(
                                                      onTap: playable
                                                          ? () =>
                                                                _handleCardTap(
                                                                  context,
                                                                  cmap,
                                                                )
                                                          : null,
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 200,
                                                            ),
                                                        transform:
                                                            Matrix4.translationValues(
                                                              0,
                                                              playable ? -8 : 0,
                                                              0,
                                                            ),
                                                        decoration: playable
                                                            ? BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .greenAccent
                                                                        .withValues(
                                                                          alpha:
                                                                              0.6,
                                                                        ),
                                                                    blurRadius:
                                                                        12,
                                                                    spreadRadius:
                                                                        2,
                                                                  ),
                                                                ],
                                                              )
                                                            : null,
                                                        child: Opacity(
                                                          opacity:
                                                              isMyTurn &&
                                                                  !playable
                                                              ? 0.45
                                                              : 1.0,
                                                          child: UnoCardFront(
                                                            cardMap: cmap,
                                                            width:
                                                                handCardWidth,
                                                            height:
                                                                handCardHeight,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Special card effect overlay
            if (_effectCard != null)
              Positioned.fill(
                child: _SpecialCardEffect(
                  card: _effectCard!,
                  animation: _effectCtrl,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Dealing card wrapper ─────────────────────────────────────────────────────

class _DealingCard extends StatelessWidget {
  final int index;
  final bool isDealing;
  final Widget child;

  const _DealingCard({
    required this.index,
    required this.isDealing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDealing) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, t, ch) => Transform.translate(
        offset: Offset(0, (1 - t) * -40),
        child: Opacity(opacity: t, child: ch),
      ),
      child: child,
    );
  }
}

// ── Draw stack badge ─────────────────────────────────────────────────────────

class _DrawStackBadge extends StatelessWidget {
  final int count;
  final String? stackType;
  const _DrawStackBadge({required this.count, required this.stackType});

  @override
  Widget build(BuildContext context) {
    final isWild = stackType == 'wild_draw4';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isWild ? const Color(0xFF7B1FA2) : const Color(0xFFE52521),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: (isWild ? Colors.purple : Colors.red).withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isWild ? '⚡ +4 누적' : '📥 +2 누적',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$count장',
              style: TextStyle(
                color: isWild
                    ? const Color(0xFF7B1FA2)
                    : const Color(0xFFE52521),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Special card effect overlay ───────────────────────────────────────────────

class _SpecialCardEffect extends StatelessWidget {
  final String card;
  final Animation<double> animation;

  const _SpecialCardEffect({required this.card, required this.animation});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    String emoji;

    switch (card) {
      case 'skip':
        label = 'SKIP!';
        color = const Color(0xFFE52521);
        emoji = '🚫';
        break;
      case 'reverse':
        label = 'REVERSE!';
        color = const Color(0xFF0068B5);
        emoji = '🔄';
        break;
      case 'draw2':
        label = '+2!';
        color = const Color(0xFF4CAE4C);
        emoji = '📥';
        break;
      case 'wild_draw4':
        label = '+4!';
        color = const Color(0xFF7B1FA2);
        emoji = '⚡';
        break;
      default:
        return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        // Fade in fast, linger, fade out at end
        final t = animation.value;
        double opacity;
        if (t < 0.15) {
          opacity = t / 0.15;
        } else if (t < 0.75) {
          opacity = 1.0;
        } else {
          opacity = 1.0 - (t - 0.75) / 0.25;
        }
        final scale = t < 0.15
            ? Curves.elasticOut.transform(t / 0.15) * 0.6 + 0.4
            : 1.0;

        return IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              color: color.withValues(alpha: 0.18),
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.7),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── UNO Call / Action button ─────────────────────────────────────────────────

class _UnoCallButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _UnoCallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_UnoCallButton> createState() => _UnoCallButtonState();
}

class _UnoCallButtonState extends State<_UnoCallButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card Widgets ──────────────────────────────────────────────────────────────

class UnoCardBack extends StatelessWidget {
  final double width;
  final double height;

  const UnoCardBack({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(2, 2)),
        ],
      ),
      padding: EdgeInsets.all(width * 0.06),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE52521),
          borderRadius: BorderRadius.circular(width * 0.08),
        ),
        child: Center(
          child: Transform.rotate(
            angle: -math.pi / 6,
            child: Container(
              width: width * 0.7,
              height: height * 0.35,
              decoration: BoxDecoration(
                color: const Color(0xFFF9D000),
                borderRadius: BorderRadius.circular(width * 0.35),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'UNO',
                style: TextStyle(
                  color: const Color(0xFFE52521),
                  fontSize: width * 0.22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnoCardFront extends StatelessWidget {
  final Map<String, dynamic> cardMap;
  final double width;
  final double height;

  const UnoCardFront({
    super.key,
    required this.cardMap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorStr = cardMap['color'] as String?;
    final valueStr = cardMap['value'] as String?;
    final cardColor = UnoBoard.getColorFromString(colorStr);

    String displayValue = valueStr ?? '?';
    String cornerValue = displayValue;

    if (displayValue == 'wild') {
      displayValue = 'WILD';
      cornerValue = 'W';
    }
    if (displayValue == 'wild_draw4') {
      displayValue = '+4\nWILD';
      cornerValue = '+4';
    }
    if (displayValue == 'draw2') {
      displayValue = '+2';
      cornerValue = '+2';
    }
    if (displayValue == 'skip') {
      displayValue = 'Ø';
      cornerValue = 'Ø';
    }
    if (displayValue == 'reverse') {
      displayValue = '⇄';
      cornerValue = '⇄';
    }

    final isBlack = cardColor == const Color(0xFF222222);
    final textColorColor = isBlack ? Colors.black : cardColor;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 2)),
        ],
      ),
      padding: EdgeInsets.all(width * 0.05),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(width * 0.08),
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: Stack(
          children: [
            Center(
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Container(
                  width: width * 0.8,
                  height: height * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width * 0.4),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(-1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                displayValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColorColor,
                  fontSize: displayValue.length > 2
                      ? width * 0.2
                      : width * 0.35,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 1,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Text(
                cornerValue,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width * 0.15,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 1)],
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Transform.rotate(
                angle: math.pi,
                child: Text(
                  cornerValue,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width * 0.15,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 1)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
