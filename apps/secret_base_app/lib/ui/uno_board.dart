import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../core/uno_audio.dart';

class UnoBoard extends StatefulWidget {
  final String? gameId;
  final String? turn;
  final int? p1Count;
  final int? p2Count;
  final List<dynamic>? hand;
  final Map<String, dynamic>? topCard;
  final String? declaredColor;
  final String mode;
  final int drawStack;
  final String? drawStackType;
  final VoidCallback onNewGame;
  final VoidCallback onDrawCard;
  final void Function(String, String?) onPlayCard;
  final VoidCallback? onChallengeDraw4;
  final String currentUser;
  final bool pendingCall;
  final bool catchable;
  final VoidCallback? onUnoButton;
  final String? lastSpecialCard;
  final String? lastSpecialBy;
  final int? lastSpecialAt;
  final double topInset;

  const UnoBoard({
    super.key,
    this.gameId,
    this.turn,
    this.p1Count,
    this.p2Count,
    this.hand,
    this.topCard,
    this.declaredColor,
    this.mode = 'go_wild',
    this.drawStack = 0,
    this.drawStackType,
    required this.onNewGame,
    required this.onDrawCard,
    required this.onPlayCard,
    this.onChallengeDraw4,
    required this.currentUser,
    this.pendingCall = false,
    this.catchable = false,
    this.onUnoButton,
    this.lastSpecialCard,
    this.lastSpecialBy,
    this.lastSpecialAt,
    this.topInset = 0,
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

  // --- Turn timer ---
  static const _turnSeconds = 15;
  int _timeLeft = _turnSeconds;
  Timer? _turnTimer;
  bool _autoActed = false;

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
      _turnTimer?.cancel();
      _visibleCardCount = 0;
      _isDealing = false;
      setState(() => _timeLeft = _turnSeconds);
    }

    // Turn changed → restart timer
    if (widget.turn != old.turn && widget.gameId != null && !_isDealing) {
      _startTurnTimer();
    }

    // Trigger dealing animation when hand is populated for the first time
    final wasEmpty = old.hand == null || old.hand!.isEmpty;
    final nowHasCards = widget.hand != null && widget.hand!.isNotEmpty;
    if (wasEmpty && nowHasCards && widget.gameId != null) {
      _startDealingAnimation();
    }

    // Trigger special card effect for every server play event, including repeats.
    final specialChanged =
        widget.lastSpecialAt != null &&
        widget.lastSpecialAt != old.lastSpecialAt;
    final legacySpecialChanged =
        widget.lastSpecialAt == null &&
        widget.lastSpecialCard != old.lastSpecialCard;
    if (widget.lastSpecialCard != null &&
        (specialChanged || legacySpecialChanged)) {
      _triggerSpecialEffect(widget.lastSpecialCard!);
    }

    // Draw stack resolved → play correct draw voice (M_07/M_08/M_09)
    if (old.drawStack > 0 && widget.drawStack == 0) {
      UnoAudio.instance.drawResolved(old.drawStack, old.drawStackType);
    }
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    _turnTimer?.cancel();
    _effectCtrl.dispose();
    super.dispose();
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    _autoActed = false;
    setState(() => _timeLeft = _turnSeconds);
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _timeLeft--);
      if (_timeLeft <= 5 && _timeLeft > 0) {
        UnoAudio.instance.timerTick();
      }
      if (_timeLeft <= 0) {
        t.cancel();
        UnoAudio.instance.timerEnd();
        _autoAct();
      }
    });
  }

  void _autoAct() {
    if (_autoActed || !mounted) return;
    _autoActed = true;
    if (widget.turn != widget.currentUser) return;

    final hand = (widget.hand ?? []).map(_asMap).toList();
    final playable = hand.where(_isCardPlayable).toList();

    if (playable.isNotEmpty) {
      final card = playable[math.Random().nextInt(playable.length)];
      final val = card['value'] as String?;
      if (val == 'wild' || val == 'wild_draw4') {
        const colors = ['red', 'yellow', 'green', 'blue'];
        widget.onPlayCard(
          card['id'] as String,
          colors[math.Random().nextInt(4)],
        );
      } else {
        widget.onPlayCard(card['id'] as String, null);
      }
    } else {
      _handleDrawCard();
    }
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
        UnoAudio.instance.cardDeal();
      } else {
        setState(() => _isDealing = false);
        timer.cancel();
        _startTurnTimer();
      }
    });
  }

  void _triggerSpecialEffect(String card) {
    setState(() => _effectCard = card);
    _effectCtrl.forward(from: 0);
    switch (card) {
      case 'skip':
        UnoAudio.instance.cardSkip();
        break;
      case 'reverse':
        UnoAudio.instance.cardReverse();
        break;
      case 'discard_all':
        UnoAudio.instance.cardPick();
        break;
      // draw2/draw4 목소리는 실제로 카드를 받을 때(drawStack→0) 재생
    }
  }

  void _handleCardTap(BuildContext context, Map<String, dynamic> cardMap) {
    if (widget.turn != widget.currentUser) return;

    UnoAudio.instance.cardPick();

    final val = cardMap['value'] as String?;
    final id = cardMap['id'] as String;

    if (val == 'wild' || val == 'wild_draw4') {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (ctx) => _ColorPickerDialog(
          onColorSelected: (color) {
            UnoAudio.instance.colorDeclared(color);
            widget.onPlayCard(id, color);
          },
        ),
      );
    } else {
      widget.onPlayCard(id, null);
    }
  }

  void _handleDrawCard() {
    UnoAudio.instance.cardDrawFromDeck();
    widget.onDrawCard();
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
      if (widget.mode == 'classic') return false;
      return val == 'draw2' || val == 'wild_draw4';
    }
    if (widget.mode == 'classic' && val == 'discard_all') return false;
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
    // p1Count = 나(currentUser)의 패 수, p2Count = 상대방의 패 수
    final myCount = widget.p1Count ?? 0;
    final opponentCount = widget.p2Count ?? 0;
    final hasPendingStack = widget.drawStack > 0 && isMyTurn;

    // Wild/+4 카드는 선언된 색상으로 표시
    final rawTop = widget.topCard;
    final displayTopCard = rawTop == null
        ? null
        : () {
            final v = rawTop['value'] as String?;
            if ((v == 'wild' || v == 'wild_draw4') &&
                widget.declaredColor != null) {
              return Map<String, dynamic>.from(rawTop)
                ..['color'] = widget.declaredColor;
            }
            return rawTop;
          }();

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardWidth = constraints.maxWidth;
        final boardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (boardWidth < 700 ? 500.0 : 620.0);
        final isLandscape = boardWidth > boardHeight * 1.15;
        final isCompact = boardWidth < 520 || boardHeight < 560;
        final scale = math
            .min(boardWidth / 540, boardHeight / 560)
            .clamp(isLandscape ? 0.68 : 0.76, 1.2);
        final handCardWidth = (64.0 * scale).clamp(
          isLandscape ? 44.0 : 50.0,
          78.0,
        );
        final handCardHeight = handCardWidth * 1.5;
        final pileCardWidth = (76.0 * scale).clamp(
          isLandscape ? 50.0 : 60.0,
          94.0,
        );
        final pileCardHeight = pileCardWidth * 1.5;
        final opponentAreaHeight =
            (86.0 * scale).clamp(isLandscape ? 54.0 : 68.0, 112.0) +
            widget.topInset;
        final handAreaHeight = (168.0 * scale).clamp(
          isLandscape ? 108.0 : 128.0,
          208.0,
        );
        final pileGap = (boardWidth * 0.06).clamp(18.0, 44.0);
        final sideActionInset = isCompact ? 8.0 : 14.0;
        final visibleOpponentCards = opponentCount.clamp(
          0,
          boardWidth > 760 ? 18 : (isCompact ? 10 : 14),
        );

        final sortedHand = [...(widget.hand ?? [])]
          ..sort((a, b) {
            final aIsWild4 = (_asMap(a)['value'] as String?) == 'wild_draw4'
                ? 0
                : 1;
            final bIsWild4 = (_asMap(b)['value'] as String?) == 'wild_draw4'
                ? 0
                : 1;
            return aIsWild4.compareTo(bIsWild4);
          });
        final displayHand = _isDealing
            ? sortedHand.take(_visibleCardCount).toList()
            : sortedHand;

        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: boardHeight,
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0xFF2A2D43), Color(0xFF10121C)],
                ),
              ),
              child: ClipRect(
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
                            height: opponentAreaHeight,
                            padding: EdgeInsets.only(
                              top: widget.topInset + 12 * scale,
                            ),
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
                                  top: 24 * scale,
                                  child: Wrap(
                                    spacing: -18 * scale,
                                    children: List.generate(
                                      visibleOpponentCards,
                                      (i) => UnoCardBack(
                                        width: (38 * scale).clamp(31.0, 46.0),
                                        height: (57 * scale).clamp(46.5, 69.0),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- TURN TIMER ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            child: _TurnTimerBar(
                              timeLeft: _timeLeft,
                              totalSeconds: _turnSeconds,
                              isMyTurn: isMyTurn,
                              turn: widget.turn,
                            ),
                          ),

                          // --- MIDDLE: Piles & Status ---
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned(
                                  bottom: sideActionInset,
                                  left: sideActionInset,
                                  child: _UnoCallButton(
                                    label: 'UNO!',
                                    color: const Color(0xFFE52521),
                                    enabled:
                                        widget.pendingCall || widget.catchable,
                                    onTap: widget.onUnoButton ?? () {},
                                  ),
                                ),
                                // Wild 카드가 아닌데 색상이 active한 경우 (일반 카드 후 color reset 등)에만 배지 표시
                                if (widget.declaredColor != null &&
                                    widget.topCard != null &&
                                    widget.topCard!['value'] != 'wild' &&
                                    widget.topCard!['value'] != 'wild_draw4')
                                  Positioned(
                                    top: sideActionInset,
                                    right: sideActionInset,
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
                                    top: sideActionInset,
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
                                            ? _handleDrawCard
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
                                      SizedBox(width: pileGap),
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
                                    top: sideActionInset,
                                    right: sideActionInset,
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
                            height: handAreaHeight,
                            padding: EdgeInsets.only(bottom: 12 * scale),
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
                                        fontSize: isCompact ? 14 : 16,
                                      ),
                                    ),
                                    if (hasPendingStack &&
                                        widget.mode != 'classic') ...[
                                      if (!isCompact) ...[
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
                                  ],
                                ),
                                SizedBox(height: 10 * scale),
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
                                            horizontal: 14,
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
                                                padding: EdgeInsets.only(
                                                  right: 7.0 * scale,
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
      case 'discard_all':
        label = 'ALL!';
        color = const Color(0xFF00897B);
        emoji = '🃏';
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
      builder: (context2, _) {
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
  final bool enabled;

  const _UnoCallButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
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
    );
    if (widget.enabled) {
      _anim.repeat(reverse: true);
    }
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _UnoCallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_anim.isAnimating) {
      _anim.repeat(reverse: true);
    } else if (!widget.enabled && _anim.isAnimating) {
      _anim.stop();
      _anim.value = 0;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.enabled
        ? widget.color
        : const Color(0xFF5F6675);

    return ScaleTransition(
      scale: widget.enabled ? _scale : const AlwaysStoppedAnimation(1.0),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: effectiveColor.withValues(
                  alpha: widget.enabled ? 0.6 : 0.2,
                ),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(
                alpha: widget.enabled ? 0.4 : 0.18,
              ),
              width: 2,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.enabled ? Colors.white : Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
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

class _DiscardAllMark extends StatelessWidget {
  final Color color;
  final double width;

  const _DiscardAllMark({required this.color, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width * 0.58,
      height: width * 0.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _miniCard(-width * 0.16, -0.22),
          _miniCard(0, 0),
          _miniCard(width * 0.16, 0.22),
        ],
      ),
    );
  }

  Widget _miniCard(double dx, double turns) {
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Transform.rotate(
        angle: turns,
        child: Container(
          width: width * 0.26,
          height: width * 0.38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(width * 0.04),
            border: Border.all(color: color, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: width * 0.13,
              height: width * 0.13,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    final valueStr = cardMap['value'] as String?;

    // Wild Draw 4: 전용 디자인 (실제 UNO +4 카드 스타일)
    if (valueStr == 'wild_draw4') return _buildWildDraw4();
    // Wild: 4색 원형 디자인
    if (valueStr == 'wild') return _buildWild();

    final colorStr = cardMap['color'] as String?;
    final cardColor = UnoBoard.getColorFromString(colorStr);

    String displayValue = valueStr ?? '?';
    String cornerValue = displayValue;
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
    if (displayValue == 'discard_all') {
      displayValue = 'ALL';
      cornerValue = 'ALL';
    }

    if (valueStr == 'discard_all') {
      return _cardShell(
        color: cardColor,
        cornerValue: cornerValue,
        child: Center(
          child: _DiscardAllMark(color: cardColor, width: width),
        ),
      );
    }

    return _cardShell(
      color: cardColor,
      cornerValue: cornerValue,
      child: Center(
        child: Text(
          displayValue,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cardColor,
            fontSize: displayValue.length > 2 ? width * 0.2 : width * 0.35,
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
    );
  }

  Widget _cardShell({
    required Color color,
    required String cornerValue,
    required Widget child,
    Color? overrideBackground,
  }) {
    final bg = overrideBackground ?? color;
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
          color: bg,
          borderRadius: BorderRadius.circular(width * 0.08),
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: Stack(
          children: [
            // Oval center highlight
            Center(
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Container(
                  width: width * 0.8,
                  height: height * 0.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(width * 0.4),
                  ),
                ),
              ),
            ),
            child,
            // Top-left corner
            Positioned(
              top: 3,
              left: 4,
              child: Text(
                cornerValue,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width * 0.15,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 1)],
                ),
              ),
            ),
            // Bottom-right corner (rotated)
            Positioned(
              bottom: 3,
              right: 4,
              child: Transform.rotate(
                angle: math.pi,
                child: Text(
                  cornerValue,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width * 0.15,
                    fontWeight: FontWeight.w900,
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

  Widget _buildWild() {
    const qColors = [
      Color(0xFFE52521),
      Color(0xFFF9D000),
      Color(0xFF0068B5),
      Color(0xFF4CAE4C),
    ];
    return _cardShell(
      color: const Color(0xFF111111),
      overrideBackground: const Color(0xFF111111),
      cornerValue: 'W',
      child: Center(
        child: Container(
          width: width * 0.62,
          height: height * 0.45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: ClipOval(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Container(color: qColors[0])),
                      Expanded(child: Container(color: qColors[1])),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: Container(color: qColors[2])),
                      Expanded(child: Container(color: qColors[3])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWildDraw4() {
    const qColors = [
      Color(0xFFE52521),
      Color(0xFFF9D000),
      Color(0xFF4CAE4C),
      Color(0xFF0068B5),
    ];
    // Reference: real UNO +4 card — 4 colored small cards fanned + black bg
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width * 0.1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(2, 3)),
        ],
      ),
      padding: EdgeInsets.all(width * 0.05),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(width * 0.08),
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 4 mini colored cards arranged in 2x2
            Positioned(
              top: height * 0.12,
              left: width * 0.06,
              child: _miniCard(qColors[0], width, height),
            ),
            Positioned(
              top: height * 0.12,
              right: width * 0.06,
              child: _miniCard(qColors[1], width, height),
            ),
            Positioned(
              top: height * 0.38,
              left: width * 0.06,
              child: _miniCard(qColors[2], width, height),
            ),
            Positioned(
              top: height * 0.38,
              right: width * 0.06,
              child: _miniCard(qColors[3], width, height),
            ),
            // +4 circle in center
            Center(
              child: Container(
                width: width * 0.48,
                height: width * 0.48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF111111),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Text(
                    '+4',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width * 0.28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            // Corner labels
            Positioned(
              top: 3,
              left: 4,
              child: Text(
                '+4',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width * 0.14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              bottom: 3,
              right: 4,
              child: Transform.rotate(
                angle: math.pi,
                child: Text(
                  '+4',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width * 0.14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(Color color, double w, double h) {
    return Container(
      width: w * 0.35,
      height: h * 0.22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(w * 0.04),
        border: Border.all(color: Colors.white, width: 1),
      ),
    );
  }
}

// ── Color Picker Dialog ───────────────────────────────────────────────────────

class _ColorPickerDialog extends StatelessWidget {
  final void Function(String color) onColorSelected;
  const _ColorPickerDialog({required this.onColorSelected});

  static const _colors = ['red', 'yellow', 'green', 'blue'];
  static const _labels = ['빨강', '노랑', '초록', '파랑'];
  static const _emojis = ['🔴', '🟡', '🟢', '🔵'];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C28),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'WILD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '색상을 선택하세요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: List.generate(4, (i) {
                final color = _colors[i];
                final cardColor = UnoBoard.getColorFromString(color);
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onColorSelected(color);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_emojis[i], style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          _labels[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 3),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Turn Timer Bar ────────────────────────────────────────────────────────────

class _TurnTimerBar extends StatelessWidget {
  final int timeLeft;
  final int totalSeconds;
  final bool isMyTurn;
  final String? turn;

  const _TurnTimerBar({
    required this.timeLeft,
    required this.totalSeconds,
    required this.isMyTurn,
    required this.turn,
  });

  Color get _barColor {
    if (timeLeft > 8) return const Color(0xFF4CAE4C);
    if (timeLeft > 4) return const Color(0xFFF9D000);
    return const Color(0xFFE52521);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (timeLeft / totalSeconds).clamp(0.0, 1.0);
    final barColor = _barColor;
    final isWarning = timeLeft <= 5;

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            isMyTurn ? '내 턴' : (turn ?? '상대'),
            style: TextStyle(
              color: isMyTurn ? Colors.greenAccent : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: barColor,
            fontSize: isWarning ? 15 : 13,
            fontWeight: FontWeight.w900,
          ),
          child: Text('$timeLeft'),
        ),
      ],
    );
  }
}
