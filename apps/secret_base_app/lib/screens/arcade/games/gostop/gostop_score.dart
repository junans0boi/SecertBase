import 'package:flutter/material.dart';

import '../../../../core/gostop_coach.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_models.dart';

String gostopCoins(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-$buf' : '$buf';
}

/// 큰 ×N 배수 배지.
class MultiplierBadge extends StatelessWidget {
  final GameTheme theme;
  final int multiplier;
  final double size;

  const MultiplierBadge({
    super.key,
    required this.theme,
    required this.multiplier,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hot = multiplier > 1;
    return Semantics(
      label: '배수 $multiplier배',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hot
              ? t.goldGradient
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
          border: Border.all(
            color: hot ? Colors.white.withValues(alpha: 0.9) : Colors.white24,
            width: 1.6,
          ),
          boxShadow: hot
              ? [
                  BoxShadow(
                    color: t.gold.withValues(alpha: 0.55),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              '×$multiplier',
              style: t.display(
                size: 24,
                color: hot ? const Color(0xFF3A2A00) : t.subInk,
                weight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 늘 보이는 점수판: 내 점수·고, 큰 ×N 배지와 분해 칩, 예상 금액, 상대 점수·고.
class GostopScoreBoard extends StatelessWidget {
  final GameTheme theme;
  final GostopView view;
  final String? me;
  final String? opp;
  final String myName;
  final String oppName;

  const GostopScoreBoard({
    super.key,
    required this.theme,
    required this.view,
    required this.me,
    required this.opp,
    required this.myName,
    required this.oppName,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final mine = view.projectionOf(me);
    final theirs = view.projectionOf(opp);
    final myScore = view.scoreOf(me).total;
    final oppScore = view.scoreOf(opp).total;
    final staked = view.perPointBet > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _Side(
                  theme: t,
                  title: '내 점수',
                  score: myScore,
                  go: view.goOf(me),
                  color: t.me,
                  align: CrossAxisAlignment.start,
                ),
              ),
              MultiplierBadge(theme: t, multiplier: mine.multiplier),
              Expanded(
                child: _Side(
                  theme: t,
                  title: '$oppName 점수',
                  score: oppScore,
                  go: view.goOf(opp),
                  color: t.opponent,
                  align: CrossAxisAlignment.end,
                  multiplier: theirs.multiplier > 1 ? theirs.multiplier : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    for (final m in mine.multipliers)
                      GameChip(
                        theme: t,
                        label: '${m.label} ×${m.factor}',
                        color: t.gold,
                      ),
                    if (mine.multipliers.isEmpty)
                      Text('배수 없음', style: t.body(size: 11, color: t.subInk)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                myScore >= 7
                    ? (staked
                          ? '지금 스톱 +${gostopCoins(mine.amount)}코인'
                          : '지금 스톱 ${mine.total}점')
                    : '7점부터 고/스톱',
                key: const ValueKey('projected-payout'),
                style: t.body(
                  size: 11.5,
                  weight: FontWeight.w900,
                  color: myScore >= 7 ? t.gold : t.subInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final int score;
  final int go;
  final Color color;
  final CrossAxisAlignment align;
  final int? multiplier;

  const _Side({
    required this.theme,
    required this.title,
    required this.score,
    required this.go,
    required this.color,
    required this.align,
    this.multiplier,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final right = align == CrossAxisAlignment.end;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body(size: 10.5, color: t.subInk),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: right ? TextDirection.rtl : TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$score',
              style: t.display(size: 30, color: color, weight: FontWeight.w900),
            ),
            Text('점', style: t.body(size: 12, color: color)),
          ],
        ),
        Wrap(
          spacing: 3,
          alignment: right ? WrapAlignment.end : WrapAlignment.start,
          children: [
            if (go > 0)
              GameChip(
                theme: t,
                label: '$go고',
                color: const Color(0xFFFF8A5B),
                emphasized: true,
              ),
            if (multiplier != null)
              GameChip(theme: t, label: '×$multiplier', color: t.gold),
          ],
        ),
      ],
    );
  }
}

/// "홍단 1장 남음" 같은 곧 점수가 나는 묶음 칩.
class GostopHintChips extends StatelessWidget {
  final GameTheme theme;
  final List<HCard> captures;

  const GostopHintChips({
    super.key,
    required this.theme,
    required this.captures,
  });

  @override
  Widget build(BuildContext context) {
    final hints = nearMissHints([for (final c in captures) c.coach]);
    if (hints.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: [
        for (final h in hints)
          GameChip(theme: theme, label: h, leading: '✦', color: theme.me),
      ],
    );
  }
}
