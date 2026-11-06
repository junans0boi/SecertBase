import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/game_result_overlay.dart' show GameOutcome;
import '../../../../widgets/play_kit/game_theme.dart';
import '../../../../widgets/play_kit/modern_kit.dart';
import 'blackjack_controller.dart';
import 'blackjack_rules.dart';

/// 라운드 결과 한 덩이: "이번 라운드는 졌어요" + 사유 · 승수(나 : 상대).
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
    final title = tie
        ? '이번 라운드는 비겼어요'
        : iWon
        ? '이번 라운드는 이겼어요'
        : '이번 라운드는 졌어요';
    final reason = tie
        ? roundReasonText('tie', iWon: false)
        : roundReasonText(r['reason'] as String?, iWon: iWon);
    return Semantics(
      label:
          '$title. $reason. 라운드 승수 나 ${view.winsOf(me)}, 상대 ${view.winsOf(opp)}',
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.display(size: 20).copyWith(height: 1.3),
            ),
            const SizedBox(height: 2),
            Text(
              '$reason · ${view.winsOf(me)} : ${view.winsOf(opp)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body(
                size: 13,
                color: t.subInk,
                weight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 최종 결과 화면의 라운드 기록 표("1R · 블랙잭 승 · 처음 두 장이 21 · 21 : 18").
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
    final rounds = [
      for (final raw in (view.raw['rounds'] as List?) ?? const [])
        if (raw is Map) raw,
    ];
    final me = view.me;
    return ModRowsCard(
      theme: t,
      header: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('라운드 기록', style: _small(t)),
              Text('나 : 상대', style: _small(t)),
            ],
          ),
        ),
      ),
      rows: [for (final r in rounds) _row(t, r, me)],
    );
  }

  static TextStyle _small(GameTheme t) =>
      t.body(size: 12, color: t.subInk, weight: FontWeight.w400);

  Widget _row(GameTheme t, Map raw, String? me) {
    final winner = raw['winner'];
    final iWon = winner == me;
    final tie = winner == 'tie' || winner == null;
    final reason = raw['reason'] as String?;
    final String label;
    final String why;
    if (tie) {
      label = '무승부';
      why = '두 사람의 합이 같음';
    } else if (iWon) {
      label = reason == 'blackjack' ? '블랙잭 승' : '승리';
      why = switch (reason) {
        'blackjack' => '처음 두 장이 21',
        'bust' => '상대가 21을 넘김',
        _ => '21에 더 가까움',
      };
    } else {
      label = '패배';
      why = switch (reason) {
        'blackjack' => '상대의 블랙잭',
        'bust' => '21을 넘김',
        _ => '상대가 21에 더 가까움',
      };
    }
    final scores = (raw['scores'] as Map?) ?? const {};
    final mine = scores[me];
    Object? theirs;
    scores.forEach((k, v) {
      if (k != me) theirs = v;
    });
    final Color fill = iWon && !tie ? t.accent : Colors.transparent;
    final Color fg = tie ? t.ink : (iWon ? t.onAccent : t.lose);
    final Color border = tie
        ? t.ink.withValues(alpha: 0.3)
        : (iWon ? t.accent : t.lose.withValues(alpha: 0.6));
    return SizedBox(
      height: 50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${raw['round']}R',
                style: t.display(size: 14, color: t.subInk),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 76,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: border),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: t.body(
                  size: 12,
                  color: tie ? t.subInk : fg,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                why,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.body(
                  size: 12.5,
                  color: t.subInk,
                  weight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              mine != null && theirs != null ? '$mine : $theirs' : '',
              style: t.display(size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// 최종 결과 위쪽 원형 표식: 이기면 왕관, 아니면 깃발/저울 대신 단정한 선 아이콘.
class BlackjackResultMark extends StatelessWidget {
  final GameTheme theme;
  final GameOutcome outcome;

  const BlackjackResultMark({
    super.key,
    required this.theme,
    required this.outcome,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = switch (outcome) {
      GameOutcome.win => t.accent,
      GameOutcome.lose => t.lose,
      GameOutcome.draw => t.subInk,
    };
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.only(top: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
      child: outcome == GameOutcome.win
          ? CustomPaint(
              size: const Size.square(34),
              painter: _CrownPainter(color),
            )
          : Icon(
              outcome == GameOutcome.lose
                  ? Icons.flag_outlined
                  : Icons.drag_handle_rounded,
              size: 32,
              color: color,
            ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;

  _CrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      Path()
        ..moveTo(3.5, 18.5)
        ..relativeLineTo(-0.7, -11)
        ..relativeLineTo(5, 4.2)
        ..lineTo(12, 5)
        ..relativeLineTo(4.2, 6.7)
        ..relativeLineTo(5, -4.2)
        ..relativeLineTo(-0.7, 11)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawLine(
      const Offset(4.5, 21.5),
      const Offset(19.5, 21.5),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}
