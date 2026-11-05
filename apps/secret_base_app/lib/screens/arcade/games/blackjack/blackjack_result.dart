import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'blackjack_controller.dart';
import 'blackjack_rules.dart';

/// 라운드 결과 한 줄: "이번 라운드 승리!" + 사유 + 승수(나 : 상대).
class BlackjackRoundHeadline extends StatelessWidget {
  final GameTheme theme;
  final BlackjackView view;

  const BlackjackRoundHeadline({
    super.key,
    required this.theme,
    required this.view,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = view.lastRoundResult ?? const {};
    final winner = r['winner'] as String?;
    final me = view.me;
    final opp = view.opponent;
    final iWon = winner == me;
    final tie = winner == null || winner == 'tie';
    final (title, color) = tie
        ? ('무승부 라운드', t.ink)
        : iWon
        ? ('이번 라운드 승리!', t.gold)
        : ('이번 라운드 패배', t.opponent);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.display(size: 19, color: color),
              ),
              Text(
                tie
                    ? roundReasonText('tie', iWon: false)
                    : roundReasonText(r['reason'] as String?, iWon: iWon),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body(size: 11.5, color: t.subInk),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Semantics(
          label: '라운드 승수 나 ${view.winsOf(me)}, 상대 ${view.winsOf(opp)}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${view.winsOf(me)}',
                style: t.display(size: 24, color: t.me),
              ),
              Text(' : ', style: t.display(size: 18, color: t.subInk)),
              Text(
                '${view.winsOf(opp)}',
                style: t.display(size: 24, color: t.opponent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 라운드 결과에서 "다음 라운드" 준비 버튼 + 상대 준비 표시.
class BlackjackReadyBar extends StatelessWidget {
  final GameTheme theme;
  final BlackjackView view;
  final bool pending;
  final VoidCallback onReady;

  const BlackjackReadyBar({
    super.key,
    required this.theme,
    required this.view,
    required this.pending,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final iReady = view.ready[view.me] == true;
    final oppReady = view.ready[view.opponent] == true;
    return Row(
      children: [
        Expanded(
          child: GamePrimaryButton(
            theme: t,
            height: 52,
            label: iReady ? '상대를 기다리는 중…' : '다음 라운드',
            icon: iReady
                ? Icons.hourglass_top_rounded
                : Icons.play_arrow_rounded,
            onPressed: iReady || pending ? null : onReady,
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          label: oppReady ? '상대 준비 완료' : '상대 준비 전',
          child: SizedBox(
            width: 58,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  oppReady
                      ? Icons.check_circle_rounded
                      : Icons.more_horiz_rounded,
                  size: 22,
                  color: oppReady ? t.me : t.subInk,
                ),
                Text(
                  oppReady ? '상대 준비' : '상대 확인 중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(size: 10.5, color: t.subInk),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 최종 결과 카드 안의 라운드 기록("1R 승 19:17 · 2R 무 · 3R 승").
class BlackjackRoundHistory extends StatelessWidget {
  final GameTheme theme;
  final BlackjackView view;

  const BlackjackRoundHistory({
    super.key,
    required this.theme,
    required this.view,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final rounds = (view.raw['rounds'] as List?) ?? const [];
    final me = view.me;
    final opp = view.opponent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '라운드 ${view.winsOf(me)} : ${view.winsOf(opp)}',
          style: t.display(size: 20, color: t.ink),
        ),
        if (rounds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final raw in rounds)
                if (raw is Map) _chip(t, raw, me),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(GameTheme t, Map raw, String? me) {
    final winner = raw['winner'];
    final label = winner == 'tie' ? '무' : (winner == me ? '승' : '패');
    final color = winner == 'tie'
        ? t.subInk
        : (winner == me ? t.me : t.opponent);
    final scores = (raw['scores'] as Map?) ?? const {};
    final mine = scores[me];
    Object? theirs;
    scores.forEach((k, v) {
      if (k != me) theirs = v;
    });
    final detail = mine != null && theirs != null ? ' $mine:$theirs' : '';
    return GameChip(
      theme: t,
      color: color,
      label: '${raw['round']}R $label$detail',
    );
  }
}
