import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_models.dart';

/// 한 사람의 표시 정보.
class PenaltySide {
  final String id;
  final String name;
  final String emoji;
  final bool isMe;

  const PenaltySide({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isMe,
  });
}

/// 위쪽 점수판: 양쪽 이모지·이름·역할, 킥마다 ●(골)/✕(실축), 가운데 점수·시간 링·킥 번호.
class PenaltyScoreboard extends StatelessWidget {
  final GameTheme theme;
  final PenaltyState state;
  final PenaltySide me;
  final PenaltySide opponent;
  final GameDeadline? deadline;
  final bool tickSound;

  /// 연출 중에는 아직 보여 주지 않은 킥을 빼고 그린다.
  final int visibleRounds;

  const PenaltyScoreboard({
    super.key,
    required this.theme,
    required this.state,
    required this.me,
    required this.opponent,
    required this.visibleRounds,
    this.deadline,
    this.tickSound = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final rounds = state.rounds.take(visibleRounds).toList();
    int score(String id) =>
        rounds.where((r) => r.kicker == id && r.isGoal).length;
    final regulation = kPenaltyKicksPerPlayer * 2;
    final inSd = rounds.length >= regulation;
    String label;
    if (state.finished && visibleRounds >= state.rounds.length) {
      label = '경기 끝';
    } else if (inSd) {
      label = '서든데스 ${(rounds.length - regulation) ~/ 2 + 1}';
    } else {
      final kicker = state.kicker;
      final n = rounds.where((r) => r.kicker == kicker).length + 1;
      label = '${kicker == me.id ? '나' : '상대'}의 $n번째 킥';
    }
    return GamePanel(
      theme: t,
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Side(
              theme: t,
              side: me,
              kicks: rounds.where((r) => r.kicker == me.id).toList(),
              suddenDeath: inSd,
              kicking: state.playing && state.kicker == me.id,
              color: t.me,
              alignEnd: false,
            ),
          ),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: '점수 나 ${score(me.id)}, 상대 ${score(opponent.id)}',
                  child: FittedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${score(me.id)}',
                          style: t.display(size: 28, color: t.me),
                        ),
                        Text(
                          ' : ',
                          style: t.display(size: 22, color: t.subInk),
                        ),
                        Text(
                          '${score(opponent.id)}',
                          style: t.display(size: 28, color: t.opponent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 34,
                  child: deadline == null
                      ? Center(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: t.body(size: 11, color: t.subInk),
                          ),
                        )
                      : TurnTimerRing(
                          key: const Key('penalty_timer'),
                          theme: t,
                          deadline: deadline,
                          size: 34,
                          tickSound: tickSound,
                        ),
                ),
                if (deadline != null)
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(size: 10.5, color: t.subInk),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _Side(
              theme: t,
              side: opponent,
              kicks: rounds.where((r) => r.kicker == opponent.id).toList(),
              suddenDeath: inSd,
              kicking: state.playing && state.kicker == opponent.id,
              color: t.opponent,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final GameTheme theme;
  final PenaltySide side;
  final List<PenaltyRound> kicks;
  final bool suddenDeath;
  final bool kicking;
  final Color color;
  final bool alignEnd;

  const _Side({
    required this.theme,
    required this.side,
    required this.kicks,
    required this.suddenDeath,
    required this.kicking,
    required this.color,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: kicking
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)]
            : null,
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          side.emoji.isEmpty ? '🙂' : side.emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
    final texts = Flexible(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            side.isMe ? '${side.name} (나)' : side.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 12.5, weight: FontWeight.w800),
          ),
          Text(
            kicking ? '⚽ 키커' : '🧤 키퍼',
            maxLines: 1,
            style: t.body(size: 10.5, color: t.subInk),
          ),
        ],
      ),
    );
    // 정규 5킥은 다섯 칸, 서든데스에서는 서든데스 킥만 최근 5개.
    final regularKicks = kicks.take(kPenaltyKicksPerPlayer).toList();
    final shown = suddenDeath
        ? kicks.skip(kPenaltyKicksPerPlayer).toList().reversed.take(5).toList()
        : regularKicks;
    final slots = suddenDeath
        ? shown.reversed.toList()
        : List<PenaltyRound?>.generate(
            kPenaltyKicksPerPlayer,
            (i) => i < regularKicks.length ? regularKicks[i] : null,
          );
    final goals = kicks.where((k) => k.isGoal).length;
    return Semantics(
      label:
          '${side.isMe ? '나' : side.name}, ${kicking ? '키커' : '키퍼'}, 킥 ${kicks.length}번 중 골 $goals',
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: alignEnd
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: alignEnd
                ? [texts, const SizedBox(width: 6), avatar]
                : [avatar, const SizedBox(width: 6), texts],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            children: [
              if (suddenDeath)
                Text('서든', style: t.body(size: 9.5, color: t.gold)),
              for (final k in slots) _KickDot(theme: t, kick: k, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _KickDot extends StatelessWidget {
  final GameTheme theme;
  final PenaltyRound? kick;
  final Color color;

  const _KickDot({
    required this.theme,
    required this.kick,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final k = kick;
    if (k == null) {
      return Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.subInk.withValues(alpha: 0.35)),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: k.isGoal ? color : Colors.white,
        border: Border.all(
          color: k.isGoal ? color : theme.subInk.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: k.isGoal
          ? null
          : Icon(Icons.close_rounded, size: 9, color: theme.subInk),
    );
  }
}

/// 상대의 최근 킥 5번: 작은 골대에 찬 곳을 점으로. 습관 읽기용.
class PenaltyHabitStrip extends StatelessWidget {
  final GameTheme theme;
  final int cells;
  final List<PenaltyRound> opponentKicks;

  const PenaltyHabitStrip({
    super.key,
    required this.theme,
    required this.cells,
    required this.opponentKicks,
  });

  /// 3번 이상 찼고 한 곳에 2번 이상 몰렸으면 그 칸 이름.
  static String? favourite(int cells, List<PenaltyRound> kicks) {
    if (kicks.length < 3) return null;
    final counts = <int, int>{};
    for (final k in kicks) {
      counts[k.kickerDir] = (counts[k.kickerDir] ?? 0) + 1;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final tie = counts.values.where((v) => v == best.value).length > 1;
    if (best.value < 2 || tie) return null;
    return penaltyCellName(cells, best.key);
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final recent = opponentKicks.length <= 5
        ? opponentKicks
        : opponentKicks.sublist(opponentKicks.length - 5);
    final fav = favourite(cells, recent);
    return Container(
      key: const Key('penalty_habit'),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '상대 최근 킥',
                  maxLines: 1,
                  style: t.body(size: 12, weight: FontWeight.w800),
                ),
                Text(
                  fav != null
                      ? '자주 찬 곳: $fav'
                      : recent.isEmpty
                      ? '아직 기록이 없어요'
                      : '습관을 읽어 보세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(
                    size: 10.5,
                    color: fav != null ? t.accent : t.subInk,
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: i < recent.length
                  ? Semantics(
                      label:
                          '${penaltyCellName(cells, recent[i].kickerDir)}, ${recent[i].isGoal ? '골' : '막힘'}',
                      child: MiniGoal(
                        key: Key('penalty_history_kick_$i'),
                        cells: cells,
                        cell: recent[i].kickerDir,
                        goal: recent[i].isGoal,
                        color: t.opponent,
                      ),
                    )
                  : MiniGoal(cells: cells, color: t.opponent),
            ),
        ],
      ),
    );
  }
}

/// 작은 골대 그림. [cell]이 있으면 그 칸에 점(골이면 색, 막혔으면 회색).
class MiniGoal extends StatelessWidget {
  final int cells;
  final int? cell;
  final bool goal;
  final Color color;

  const MiniGoal({
    super.key,
    required this.cells,
    required this.color,
    this.cell,
    this.goal = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 21,
      child: CustomPaint(painter: _MiniGoalPainter(cells, cell, goal, color)),
    );
  }
}

class _MiniGoalPainter extends CustomPainter {
  final int cells;
  final int? cell;
  final bool goal;
  final Color color;

  _MiniGoalPainter(this.cells, this.cell, this.goal, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 2);
    final empty = cell == null;
    canvas.drawRect(
      r,
      Paint()
        ..color = empty ? const Color(0x0F000000) : const Color(0x1A2EC4A6),
    );
    final grid = Paint()
      ..strokeWidth = 0.7
      ..color = const Color(0x40000000);
    for (int c = 1; c < 3; c++) {
      final x = r.left + r.width * c / 3;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
    }
    if (cells == 6) {
      canvas.drawLine(
        Offset(r.left, r.center.dy),
        Offset(r.right, r.center.dy),
        grid,
      );
    }
    final frame = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.bottom);
    canvas.drawPath(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = empty ? const Color(0x55000000) : const Color(0xFF6E5A63),
    );
    final c = cell;
    if (c == null) return;
    final col = penaltyCol(c);
    final row = penaltyRow(cells, c);
    final rows = cells == 6 ? 2 : 1;
    final center = Offset(
      r.left + r.width * (col + 0.5) / 3,
      r.top + r.height * (row + 0.5) / rows,
    );
    canvas.drawCircle(
      center,
      3.6,
      Paint()..color = goal ? color : const Color(0xFFB0A4AA),
    );
    if (!goal) {
      canvas.drawLine(
        center + const Offset(-2.4, -2.4),
        center + const Offset(2.4, 2.4),
        Paint()
          ..strokeWidth = 1.2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGoalPainter old) =>
      old.cell != cell || old.goal != goal || old.cells != cells;
}
