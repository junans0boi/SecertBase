import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/game_theme.dart';
import '../../../../widgets/play_kit/modern_kit.dart';

/// 라운지 테이블: 헤어라인 황동 테두리 한 겹 + 안쪽 장식선을 두른 에메랄드 펠트.
/// 안쪽 여백은 16px로 위아래·좌우가 같다(좌석·패·가운데가 모두 한 축에 선다).
class BlackjackFelt extends StatelessWidget {
  final GameTheme theme;
  final Widget child;

  const BlackjackFelt({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.gold.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: t.gold.withValues(alpha: 0.14)),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// 위쪽 승수 HUD: [나] | 라운드 | [상대]. 세 칸이 같은 축(중앙)을 기준으로 선다.
class BlackjackHud extends StatelessWidget {
  final GameTheme theme;
  final int round;
  final int maxRounds;
  final int winsNeeded;
  final int myWins;
  final int oppWins;

  const BlackjackHud({
    super.key,
    required this.theme,
    required this.round,
    required this.maxRounds,
    required this.winsNeeded,
    required this.myWins,
    required this.oppWins,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget side(String label, int wins) => Semantics(
      label: '$label $wins승',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: t.body(
              size: 12,
              color: t.subInk,
              weight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          RoundPips(theme: t, wins: wins, needed: winsNeeded),
        ],
      ),
    );
    final divider = BorderSide(color: t.hair);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.hair),
      ),
      child: Row(
        children: [
          Expanded(flex: 100, child: side('나', myWins)),
          Expanded(
            flex: 125,
            child: Semantics(
              label: '$round라운드, 최대 $maxRounds라운드',
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: divider, right: divider),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$round라운드',
                      style: t
                          .display(size: 20, color: t.gold)
                          .copyWith(height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '먼저 $winsNeeded승 · 최대 $maxRounds라운드',
                        maxLines: 1,
                        style: t.body(
                          size: 12,
                          color: t.subInk,
                          weight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(flex: 100, child: side('상대', oppWins)),
        ],
      ),
    );
  }
}

/// 라운드 승수 표시(먼저 [needed]승): ○ ●.
class RoundPips extends StatelessWidget {
  final GameTheme theme;
  final int wins;
  final int needed;

  const RoundPips({
    super.key,
    required this.theme,
    required this.wins,
    required this.needed,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < needed; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOut,
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < wins ? t.accent : Colors.transparent,
              border: Border.all(
                color: i < wins ? t.accent : t.gold.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 합계 플라크: 큰 숫자 + 12px 캡션. 이긴 쪽은 황동 테두리, 버스트는 붉은 숫자.
class ScorePlaque extends StatelessWidget {
  final GameTheme theme;
  final String value;
  final String caption;
  final bool win;
  final bool bust;

  const ScorePlaque({
    super.key,
    required this.theme,
    required this.value,
    required this.caption,
    this.win = false,
    this.bust = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: '$caption $value',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        // 두 플라크의 폭을 같게 해 왼쪽 끝이 어긋나지 않게 한다.
        width: 96,
        height: 56,
        decoration: BoxDecoration(
          color: win
              ? t.accent.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: win ? t.accent : t.hair),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              style: t
                  .display(
                    size: 26,
                    color: bust ? t.lose : (win ? t.gold : t.ink),
                  )
                  .copyWith(height: 1),
            ),
            const SizedBox(height: 3),
            Text(
              caption,
              maxLines: 1,
              style: t.body(
                size: 12,
                color: t.subInk,
                weight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가운데 줄: 선 · (타이머 링 또는 결과 알약) · 선. 두 선의 길이가 늘 같다.
class BlackjackMidRow extends StatelessWidget {
  final GameTheme theme;
  final Widget center;

  const BlackjackMidRow({super.key, required this.theme, required this.center});

  @override
  Widget build(BuildContext context) {
    final line = Container(height: 1, color: theme.hair);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(child: line),
          const SizedBox(width: 16),
          center,
          const SizedBox(width: 16),
          Expanded(child: line),
        ],
      ),
    );
  }
}

/// 가운데 알약: "카드 공개", "패배  18 : 20".
class BlackjackChip extends StatelessWidget {
  final GameTheme theme;
  final String text;
  final bool lose;

  const BlackjackChip({
    super.key,
    required this.theme,
    required this.text,
    this.lose = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lose ? t.lose.withValues(alpha: 0.7) : t.accent,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: t.body(
          size: 15,
          color: lose ? t.lose : t.gold,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
