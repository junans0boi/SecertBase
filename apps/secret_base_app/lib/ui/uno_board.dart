import 'package:flutter/material.dart';
import 'dart:math' as math;

class UnoBoard extends StatelessWidget {
  final String? gameId;
  final String? turn;
  final int? p1Count;
  final int? p2Count;
  final List<dynamic>? hand;
  final Map<String, dynamic>? topCard;
  final String? declaredColor;
  final VoidCallback onNewGame;
  final VoidCallback onDrawCard;
  final void Function(String, String?) onPlayCard;
  final String currentUser;
  final bool pendingCall;
  final bool catchable;
  final VoidCallback? onCallUno;
  final VoidCallback? onCatchUno;

  const UnoBoard({
    super.key,
    this.gameId,
    this.turn,
    this.p1Count,
    this.p2Count,
    this.hand,
    this.topCard,
    this.declaredColor,
    required this.onNewGame,
    required this.onDrawCard,
    required this.onPlayCard,
    required this.currentUser,
    this.pendingCall = false,
    this.catchable = false,
    this.onCallUno,
    this.onCatchUno,
  });

  void _handleCardTap(BuildContext context, Map<String, dynamic> cardMap) {
    if (turn != currentUser) return;

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
                  onPlayCard(id, color);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getColorFromString(color),
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
      onPlayCard(id, null);
    }
  }

  static Color _getColorFromString(String? colorStr) {
    if (colorStr == 'red') return const Color(0xFFE52521); // UNO Red
    if (colorStr == 'blue') return const Color(0xFF0068B5); // UNO Blue
    if (colorStr == 'green') return const Color(0xFF4CAE4C); // UNO Green
    if (colorStr == 'yellow') return const Color(0xFFF9D000); // UNO Yellow
    return const Color(0xFF222222); // Wild Black
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = turn == currentUser;
    final opponentCount = currentUser == 'jun'
        ? (p2Count ?? 0)
        : (p1Count ?? 0);
    final myCount = currentUser == 'jun' ? (p1Count ?? 0) : (p2Count ?? 0);

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

        return Container(
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
            child: gameId == null
                ? Center(
                    child: ElevatedButton.icon(
                      onPressed: onNewGame,
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
                              '상대방 (${turn != currentUser ? "턴" : "대기중"}) - $opponentCount장',
                              style: TextStyle(
                                color: turn != currentUser
                                    ? Colors.yellow
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Positioned(
                              top: 24,
                              child: Wrap(
                                spacing: -20, // Overlap cards
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
                            // UNO! button (I played to 1 card - must call)
                            if (pendingCall)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: _UnoCallButton(
                                  label: 'UNO!',
                                  color: const Color(0xFFE52521),
                                  onTap: onCallUno ?? () {},
                                ),
                              ),

                            // 잡기! button (opponent has 1 card and hasn't called)
                            if (catchable)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: _UnoCallButton(
                                  label: '잡기! 😈',
                                  color: const Color(0xFF7B1FA2),
                                  onTap: onCatchUno ?? () {},
                                ),
                              ),

                            if (declaredColor != null)
                              Positioned(
                                top: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getColorFromString(declaredColor),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Text(
                                    '선언됨',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Draw Pile
                                  GestureDetector(
                                    onTap: isMyTurn ? onDrawCard : null,
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
                                                  color: Colors.yellow,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  '뽑기',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
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
                                  if (topCard != null)
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      transitionBuilder: (child, animation) {
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
                                        key: ValueKey(topCard!['id']),
                                        angle: 0.1, // Slight tilt for realism
                                        child: UnoCardFront(
                                          cardMap: topCard!,
                                          width: pileCardWidth,
                                          height: pileCardHeight,
                                        ),
                                      ),
                                    ),
                                ],
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
                              isMyTurn
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.black45,
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '내 패 ${isMyTurn ? "(내 턴!)" : ""} - $myCount장',
                              style: TextStyle(
                                color: isMyTurn
                                    ? Colors.greenAccent
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: hand == null || hand!.isEmpty
                                  ? const Center(
                                      child: Text(
                                        '카드가 없습니다.',
                                        style: TextStyle(color: Colors.white),
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
                                        children: hand!.map((c) {
                                          final cmap = _asMap(c);
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeOut,
                                              margin: EdgeInsets.only(
                                                bottom: isMyTurn ? 0 : 10,
                                              ),
                                              child: GestureDetector(
                                                onTap: isMyTurn
                                                    ? () => _handleCardTap(
                                                        context,
                                                        cmap,
                                                      )
                                                    : null,
                                                child: UnoCardFront(
                                                  cardMap: cmap,
                                                  width: handCardWidth,
                                                  height: handCardHeight,
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
        );
      },
    );
  }
}

class _UnoCallButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _UnoCallButton({required this.label, required this.color, required this.onTap});

  @override
  State<_UnoCallButton> createState() => _UnoCallButtonState();
}

class _UnoCallButtonState extends State<_UnoCallButton> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
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
              BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 2),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
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
          color: const Color(0xFFE52521), // Red
          borderRadius: BorderRadius.circular(width * 0.08),
        ),
        child: Center(
          child: Transform.rotate(
            angle: -math.pi / 6, // -30 degrees
            child: Container(
              width: width * 0.7,
              height: height * 0.35,
              decoration: BoxDecoration(
                color: const Color(0xFFF9D000), // Yellow
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
    final cardColor = UnoBoard._getColorFromString(colorStr);

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
    } // Using symbol for skip
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
            // Center skewed white oval
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
            // Center text
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
            // Top Left corner text
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
            // Bottom Right corner text
            Positioned(
              bottom: 4,
              right: 4,
              child: Transform.rotate(
                angle: math.pi, // 180 degrees
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
