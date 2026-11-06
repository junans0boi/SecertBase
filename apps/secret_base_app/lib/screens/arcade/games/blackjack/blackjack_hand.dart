import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';

/// 한 사람의 손패. 카드는 테이블 가장자리에서 날아와 자리를 잡고, 가려진 카드가 공개되면
/// 세로축으로 뒤집힌다. [gold]이면 금빛 테두리가 손패 둘레를 한 바퀴 돌고,
/// [bust]가 켜지는 순간 손패가 흔들린다. [winner]이면 카드마다 황동 테두리가 둘린다.
class BlackjackHand extends StatefulWidget {
  final GameTheme theme;
  final List<Map<String, dynamic>> cards;

  /// 같은 라운드의 카드인지 가르는 열쇠(예: `gameId-round`). 바뀌면 새로 딜한다.
  final String roundKey;

  /// 손패 가운데에서 카드가 나오는 자리까지의 거리(픽셀). 카드가 여기서 출발한다.
  final Offset dealFrom;

  /// 처음 두 장을 번갈아 나눠 주는 순서(0 = 선공, 1 = 후공).
  final int seat;

  /// 내 손이면 홀카드에 "숨은 카드" 표시를 한다(상대에게는 안 보인다는 뜻).
  final bool markHole;
  final bool gold;
  final bool bust;

  /// 이번 라운드를 이긴 손(카드마다 황동 테두리).
  final bool winner;

  /// 홀카드가 공개될 때 뒤집기 전 기다리는 시간(순서대로 공개).
  final Duration flipDelay;
  final double maxCardWidth;
  final String semanticsLabel;

  const BlackjackHand({
    super.key,
    required this.theme,
    required this.cards,
    required this.roundKey,
    required this.dealFrom,
    required this.semanticsLabel,
    this.seat = 0,
    this.markHole = false,
    this.gold = false,
    this.bust = false,
    this.winner = false,
    this.flipDelay = Duration.zero,
    this.maxCardWidth = 96,
  });

  @override
  State<BlackjackHand> createState() => _BlackjackHandState();
}

class _BlackjackHandState extends State<BlackjackHand>
    with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.gold) _ring.forward();
    if (widget.bust) _shake.forward();
  }

  @override
  void didUpdateWidget(covariant BlackjackHand old) {
    super.didUpdateWidget(old);
    if (widget.gold && !old.gold) _ring.forward(from: 0);
    if (!widget.gold && old.gold) _ring.value = 0;
    if (widget.roundKey != old.roundKey) _ring.value = 0;
    if (widget.bust && !old.bust) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Semantics(
      label: widget.semanticsLabel,
      child: LayoutBuilder(
        builder: (context, box) {
          final n = math.max(1, widget.cards.length);
          final maxW = box.maxWidth.isFinite ? box.maxWidth : 360.0;
          final maxH = box.maxHeight.isFinite ? box.maxHeight : 160.0;
          // 카드는 줄 높이를 꽉 채운다(비율 66:94). 장수가 많으면 겹쳐서 폭에 맞춘다.
          final cardH = math.min(maxH, widget.maxCardWidth * 94 / 66);
          final cardW = math.min(cardH * 66 / 94, maxW * 0.4);
          // 기본 겹침은 카드 폭의 39%(66px 카드에서 26px).
          final step = n <= 1
              ? 0.0
              : math.min(cardW * 0.606, (maxW - cardW) / (n - 1));
          final handW = cardW + step * (n - 1);
          return Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_shake, _ring]),
              builder: (context, child) {
                final s = _shake.value;
                final dx = s == 0 || s == 1
                    ? 0.0
                    : math.sin(s * math.pi * 7) * 9 * (1 - s);
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: CustomPaint(
                    foregroundPainter: _ring.value > 0
                        ? _GoldRingPainter(
                            progress: _ring.value,
                            gold: t.gold,
                            light: Color.lerp(t.gold, Colors.white, 0.55)!,
                            radius: cardW * 0.16,
                          )
                        : null,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: handW,
                height: cardH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < widget.cards.length; i++)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: step * i,
                        top: 0,
                        child: _DealtCard(
                          key: ValueKey('${widget.roundKey}-$i'),
                          card: widget.cards[i],
                          width: cardW,
                          from:
                              widget.dealFrom -
                              Offset(step * i - (handW - cardW) / 2, 0),
                          delay: i < 2
                              ? Duration(
                                  milliseconds: (i * 2 + widget.seat) * 170,
                                )
                              : Duration.zero,
                          flipDelay: widget.flipDelay,
                          hole:
                              widget.markHole &&
                              i == 1 &&
                              widget.cards[i]['hidden'] != true,
                          ring: widget.winner,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 테이블 가장자리에서 날아와 앉고, 앞면이 처음 보이게 되면 뒤집히는 카드 한 장.
class _DealtCard extends StatefulWidget {
  final Map<String, dynamic> card;
  final double width;
  final Offset from;
  final Duration delay;
  final Duration flipDelay;

  /// 내 숨은 카드(라벨 + 황동 테두리).
  final bool hole;

  /// 이긴 손의 카드(황동 테두리).
  final bool ring;

  const _DealtCard({
    super.key,
    required this.card,
    required this.width,
    required this.from,
    required this.delay,
    required this.flipDelay,
    this.hole = false,
    this.ring = false,
  });

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard> with TickerProviderStateMixin {
  static const _flyMs = 430;
  static const _flipMs = 420;
  late final AnimationController _deal;
  late final AnimationController _flip;
  late final double _dealStart;
  double _flipStart = 0;
  bool _dealSounded = false;
  bool _flipSounded = false;
  bool _flipping = false;

  bool get _hidden =>
      widget.card['hidden'] == true || widget.card['rank'] == null;

  @override
  void initState() {
    super.initState();
    final total = widget.delay.inMilliseconds + _flyMs;
    _dealStart = widget.delay.inMilliseconds / total;
    _deal = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    )..addListener(_onDealTick);
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _flipMs),
    )..addListener(_onFlipTick);
    _deal.forward();
  }

  void _onDealTick() {
    if (!_dealSounded && _deal.value >= _dealStart) {
      _dealSounded = true;
      GameSfx.instance.play(GameSound.cardDeal, minGapMs: 20);
    }
  }

  void _onFlipTick() {
    if (!_flipSounded && _flip.value >= _flipStart) {
      _flipSounded = true;
      GameSfx.instance.play(GameSound.cardFlip, minGapMs: 20);
    }
  }

  @override
  void didUpdateWidget(covariant _DealtCard old) {
    super.didUpdateWidget(old);
    final wasHidden = old.card['hidden'] == true || old.card['rank'] == null;
    if (wasHidden && !_hidden) {
      final total = widget.flipDelay.inMilliseconds + _flipMs;
      _flipStart = widget.flipDelay.inMilliseconds / total;
      _flip.duration = Duration(milliseconds: total);
      _flipSounded = false;
      _flipping = true;
      _flip.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _flipping = false);
      });
    }
  }

  @override
  void dispose() {
    _deal.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_deal, _flip]),
      builder: (context, _) {
        // 날아오기: 시작 전에는 나오는 자리에 뒷면으로 작게 있다가 호를 그리며 자리로.
        final raw = _deal.value <= _dealStart
            ? 0.0
            : (_deal.value - _dealStart) / (1 - _dealStart);
        final k = Curves.easeOutCubic.transform(raw.clamp(0.0, 1.0));
        final lift = math.sin(k * math.pi) * -18;
        final offset = Offset.lerp(widget.from, Offset.zero, k)!;
        final angle = (1 - k) * -0.5;
        final scale = 0.72 + 0.28 * k;
        final arrived = raw > 0;

        // 뒤집기: 0 → 0.5 뒷면이 접히고, 0.5 → 1 앞면이 펼쳐진다.
        double flipT = 1;
        if (_flipping) {
          final f = _flip.value <= _flipStart
              ? 0.0
              : (_flip.value - _flipStart) / (1 - _flipStart);
          flipT = Curves.easeInOut.transform(f.clamp(0.0, 1.0));
        }
        final showFace = !_hidden && (!_flipping || flipT >= 0.5);
        final yAngle = !_flipping
            ? 0.0
            : (flipT < 0.5 ? flipT * math.pi : (flipT - 1) * math.pi);

        final card = PlayingCard.fromMap(
          showFace ? widget.card : const {'hidden': true},
          width: widget.width,
          style: CardStyle.lounge,
          highlight: showFace && (widget.hole || widget.ring),
          badge: showFace && widget.hole ? '숨은 카드' : null,
        );
        return Opacity(
          opacity: arrived ? 1 : 0,
          child: Transform.translate(
            offset: offset + Offset(0, lift),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(yAngle),
                  child: card,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 손패 둘레를 도는 금빛 테두리(21 달성).
class _GoldRingPainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color light;
  final double radius;

  _GoldRingPainter({
    required this.progress,
    required this.gold,
    required this.light,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).inflate(3),
      Radius.circular(radius + 3),
    );
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final sweep = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final drawn = metric.extractPath(0, metric.length * sweep);
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = gold.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [light, gold, light],
          const [0, 0.5, 1],
        ),
    );
    if (sweep < 1) {
      final tip = metric.getTangentForOffset(metric.length * sweep)?.position;
      if (tip != null) {
        canvas.drawCircle(
          tip,
          5,
          Paint()
            ..color = light
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldRingPainter old) =>
      old.progress != progress || old.gold != gold;
}
