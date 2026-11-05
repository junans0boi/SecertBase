import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'zero_hand.dart';
import 'zero_models.dart';

/// 손 카드 6장(0~5) 한 줄. 누르면 바로 그 숫자가 된다(+ 연타 없음).
/// 고른 카드는 커지고 살짝 흔들린다.
class ZeroFingerRow extends StatefulWidget {
  final GameTheme theme;
  final int? selected;
  final ValueChanged<int>? onSelect;

  const ZeroFingerRow({
    super.key,
    required this.theme,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<ZeroFingerRow> createState() => _ZeroFingerRowState();
}

class _ZeroFingerRowState extends State<ZeroFingerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(covariant ZeroFingerRow old) {
    super.didUpdateWidget(old);
    if (widget.selected != null && widget.selected != old.selected) {
      _wiggle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Row(
      children: [
        for (int n = 0; n <= kZeroMaxFingers; n++) ...[
          if (n > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedBuilder(
              animation: _wiggle,
              builder: (context, child) {
                final on = widget.selected == n;
                final k = _wiggle.value;
                final angle = on
                    ? math.sin(k * math.pi * 4) * 0.12 * (1 - k)
                    : 0.0;
                return Transform.rotate(angle: angle, child: child);
              },
              child: _FingerCard(
                theme: t,
                n: n,
                selected: widget.selected == n,
                onTap: widget.onSelect == null
                    ? null
                    : () => widget.onSelect!(n),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FingerCard extends StatelessWidget {
  final GameTheme theme;
  final int n;
  final bool selected;
  final VoidCallback? onTap;

  const _FingerCard({
    required this.theme,
    required this.n,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: '손가락 $n개',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.1 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 74,
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(t.accent, Colors.white, 0.35)!,
                        t.accent,
                      ],
                    )
                  : null,
              color: selected ? null : t.surface.withValues(alpha: 0.85),
              border: Border.all(
                color: selected ? t.gold : t.surfaceBorder,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: t.accent.withValues(alpha: 0.5),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(
                    child: ZeroHand(
                      fingers: n.toDouble(),
                      trim: t.me,
                      size: 44,
                    ),
                  ),
                ),
                Text(
                  '$n',
                  style: t.display(
                    size: 17,
                    color: selected ? const Color(0xFF3A1240) : t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 합계 예측 칩: 내 숫자 ~ 내 숫자 + 5만 보인다(나올 수 없는 합계는 고를 수 없다).
class ZeroGuessRow extends StatelessWidget {
  final GameTheme theme;
  final int? fingers;
  final int? selected;
  final ValueChanged<int>? onSelect;

  const ZeroGuessRow({
    super.key,
    required this.theme,
    required this.fingers,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final f = fingers;
    if (f == null) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.surfaceBorder),
          color: t.surface.withValues(alpha: 0.4),
        ),
        child: Text('먼저 낼 손가락을 골라요', style: t.body(size: 13, color: t.subInk)),
      );
    }
    final options = zeroGuessOptions(f);
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _GuessChip(
              theme: t,
              value: options[i],
              selected: selected == options[i],
              onTap: onSelect == null ? null : () => onSelect!(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _GuessChip extends StatelessWidget {
  final GameTheme theme;
  final int value;
  final bool selected;
  final VoidCallback? onTap;

  const _GuessChip({
    required this.theme,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      label: '합계 $value 예측',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(24),
            color: selected ? t.gold : t.surface.withValues(alpha: 0.85),
            border: Border.all(
              color: selected ? Colors.white : t.gold.withValues(alpha: 0.55),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.gold.withValues(alpha: 0.55),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$value',
            key: ValueKey('zero-guess-$value'),
            style: t.display(
              size: 21,
              color: selected ? const Color(0xFF3A1240) : t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 라운드별 점수판: 5칸(본 라운드) + 서든데스 칸. [visibleRounds]까지만 점수를 보인다
/// (공개 연출이 끝나기 전에 점수가 먼저 새지 않게).
class ZeroScoreboard extends StatelessWidget {
  final GameTheme theme;
  final ZeroState state;
  final String? me;
  final String? opponent;
  final String myName;
  final String opponentName;
  final int visibleRounds;

  const ZeroScoreboard({
    super.key,
    required this.theme,
    required this.state,
    required this.me,
    required this.opponent,
    required this.myName,
    required this.opponentName,
    required this.visibleRounds,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final shown = state.history.where((r) => r.round <= visibleRounds).toList();
    final sdPlayed = shown.where((r) => r.suddenDeath).length;
    final inSd =
        state.history.any((r) => r.suddenDeath) ||
        (state.suddenDeath && state.playing);
    final columns =
        state.maxRounds +
        (inSd ? math.max(1, sdPlayed + (state.playing ? 1 : 0)) : 0);
    final currentRound = state.playing ? state.round : -1;
    int total(String? id) =>
        shown.fold(0, (sum, r) => sum + (r.points[id] ?? 0));

    Widget row(String? id, String name, Color color) {
      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body(size: 12, color: color, weight: FontWeight.w800),
            ),
          ),
          for (int c = 1; c <= columns; c++) ...[
            const SizedBox(width: 3),
            Expanded(
              child: _ScoreCell(
                theme: t,
                round: shown.where((r) => r.round == c).firstOrNull,
                id: id,
                color: color,
                current: c == currentRound && c > visibleRounds,
                suddenDeath: c > state.maxRounds,
              ),
            ),
          ],
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              '${total(id)}',
              textAlign: TextAlign.right,
              style: t.display(size: 22, color: color),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: '점수 $myName ${total(me)}점, $opponentName ${total(opponent)}점',
      child: GamePanel(
        theme: t,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        radius: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(opponent, opponentName, t.opponent),
            const SizedBox(height: 5),
            row(me, myName, t.me),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final GameTheme theme;
  final ZeroRound? round;
  final String? id;
  final Color color;
  final bool current;
  final bool suddenDeath;

  const _ScoreCell({
    required this.theme,
    required this.round,
    required this.id,
    required this.color,
    required this.current,
    required this.suddenDeath,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = round;
    final pts = r?.points[id];
    final filled = pts != null && pts > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: filled
            ? color.withValues(alpha: pts == 2 ? 0.9 : 0.5)
            : t.ink.withValues(alpha: r == null ? 0.06 : 0.12),
        border: Border.all(
          color: current
              ? t.gold
              : suddenDeath
              ? t.accent.withValues(alpha: 0.5)
              : Colors.transparent,
          width: current ? 1.6 : 1,
        ),
      ),
      child: Text(
        r == null ? '' : '${pts ?? 0}',
        style: t.body(
          size: 11.5,
          weight: FontWeight.w900,
          color: filled ? const Color(0xFF2A0E2E) : t.subInk,
        ),
      ),
    );
  }
}

/// 무대 조명. [focus]가 0이면 넓고 은은하게, 1이면 가운데 원만 남기고 주위를 어둡게.
class ZeroSpotlightPainter extends CustomPainter {
  final double focus;
  final double sway;
  final Color warm;

  ZeroSpotlightPainter({
    required this.focus,
    required this.sway,
    required this.warm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2 + sway * w * 0.04, h * 0.56);
    final radius = (w * 0.62) - (w * 0.24) * focus;
    // 위에서 내려오는 빛줄기.
    final beam = Path()
      ..moveTo(w * (0.46 + sway * 0.01), 0)
      ..lineTo(w * (0.54 + sway * 0.01), 0)
      ..lineTo(center.dx + radius * 0.9, center.dy)
      ..lineTo(center.dx - radius * 0.9, center.dy)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            warm.withValues(alpha: 0.10 + 0.18 * focus),
            warm.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    // 주위 어둡게(조명이 좁혀질수록 진하게).
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment((center.dx / w) * 2 - 1, (center.dy / h) * 2 - 1),
          radius: radius / math.max(1, size.shortestSide) * 1.1,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.12 + 0.5 * focus),
          ],
          stops: const [0.72, 1],
        ).createShader(Offset.zero & size),
    );
    // 바닥의 빛 웅덩이.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, h * 0.9),
        width: radius * 1.5,
        height: h * 0.12,
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                warm.withValues(alpha: 0.28 + 0.2 * focus),
                warm.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(center.dx, h * 0.9),
                width: radius * 1.5,
                height: h * 0.12,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant ZeroSpotlightPainter old) =>
      old.focus != focus || old.sway != sway || old.warm != warm;
}
