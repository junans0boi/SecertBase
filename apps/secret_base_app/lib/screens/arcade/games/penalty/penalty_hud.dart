import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_models.dart';

/// 중계 그래픽 공통 색.
abstract final class PenaltyColors {
  static const glassTop = Color(0xF2162443);
  static const glassBottom = Color(0xF20A1329);
  static const glassBorder = Color(0x26FFFFFF);
  static const navy = Color(0xFF0A1328);
  static const miss = Color(0xFFFF5A64);

  static BoxDecoration glass({double radius = 14}) => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [glassTop, glassBottom],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: glassBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

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

/// TV 중계 스코어버그: 팀 색 띠·이모지·이름, 가운데 큰 점수, 승부차기 기록(●골 ✕실축 ○남음),
/// 아래 띠에 "승부차기 3번째 · 내가 찰 차례"와 남은 시간 막대.
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
    final over = state.finished && visibleRounds >= state.rounds.length;
    final kicker = state.kicker;
    final String label;
    if (over) {
      label = '경기 끝 · 최종 ${score(me.id)} : ${score(opponent.id)}';
    } else {
      final who = kicker == me.id
          ? '내가'
          : '${opponent.name}${josa(opponent.name, '이', '가')}';
      final n = inSd
          ? '서든데스 ${(rounds.length - regulation) ~/ 2 + 1}번째'
          : '승부차기 ${rounds.where((r) => r.kicker == kicker).length + 1}번째';
      label = '$n · $who 찰 차례';
    }
    final kicking = state.playing && !over;
    return Container(
      key: const Key('penalty_scorebug'),
      decoration: PenaltyColors.glass(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(
                    child: _TeamPlate(
                      theme: t,
                      side: me,
                      color: t.me,
                      kicking: kicking && kicker == me.id,
                      alignEnd: false,
                    ),
                  ),
                  Semantics(
                    label: '점수 나 ${score(me.id)}, 상대 ${score(opponent.id)}',
                    child: _ScoreBox(
                      theme: t,
                      left: score(me.id),
                      right: score(opponent.id),
                    ),
                  ),
                  Expanded(
                    child: _TeamPlate(
                      theme: t,
                      side: opponent,
                      color: t.opponent,
                      kicking: kicking && kicker == opponent.id,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _Tracker(
                      theme: t,
                      side: me,
                      kicks: rounds.where((r) => r.kicker == me.id).toList(),
                      suddenDeath: inSd,
                      next: kicking && kicker == me.id,
                      color: t.me,
                      alignEnd: false,
                    ),
                  ),
                  if (inSd)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: t.accent),
                      ),
                      child: Text(
                        '서든데스',
                        style: t.body(
                          size: 9.5,
                          color: t.accent,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Expanded(
                    child: _Tracker(
                      theme: t,
                      side: opponent,
                      kicks: rounds
                          .where((r) => r.kicker == opponent.id)
                          .toList(),
                      suddenDeath: inSd,
                      next: kicking && kicker == opponent.id,
                      color: t.opponent,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            _InfoStrip(
              theme: t,
              label: label,
              deadline: deadline,
              tickSound: tickSound,
              color: kicker == me.id ? t.me : t.opponent,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPlate extends StatelessWidget {
  final GameTheme theme;
  final PenaltySide side;
  final Color color;
  final bool kicking;
  final bool alignEnd;

  const _TeamPlate({
    required this.theme,
    required this.side,
    required this.color,
    required this.kicking,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final bar = Container(
      width: 5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
      ),
    );
    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B1430),
        border: Border.all(color: color, width: 2),
        boxShadow: kicking
            ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10)]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        side.emoji.isEmpty ? '🙂' : side.emoji,
        style: const TextStyle(fontSize: 17),
      ),
    );
    final role = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          kicking ? Icons.sports_soccer_rounded : Icons.back_hand_rounded,
          size: 11,
          color: kicking ? t.accent : t.subInk,
        ),
        const SizedBox(width: 3),
        Text(
          kicking ? '키커' : '키퍼',
          style: t.body(
            size: 10.5,
            color: kicking ? t.accent : t.subInk,
            weight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
    final texts = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            side.isMe ? '${side.name} (나)' : side.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 13, weight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 2),
          role,
        ],
      ),
    );
    final children = <Widget>[
      bar,
      const SizedBox(width: 8),
      avatar,
      const SizedBox(width: 7),
      texts,
      const SizedBox(width: 6),
    ];
    return Semantics(
      label: '${side.isMe ? '나' : side.name}, ${kicking ? '키커' : '키퍼'}',
      child: Row(children: alignEnd ? children.reversed.toList() : children),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final GameTheme theme;
  final int left;
  final int right;

  const _ScoreBox({
    required this.theme,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget digit(int v, Color c) => SizedBox(
      width: 26,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.6),
                end: Offset.zero,
              ).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Text(
              '$v',
              key: ValueKey(v),
              style: t.display(size: 26, color: PenaltyColors.navy),
            ),
          ),
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFDDE4EF)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          digit(left, t.me),
          Container(width: 1.4, height: 18, color: const Color(0x330A1328)),
          digit(right, t.opponent),
        ],
      ),
    );
  }
}

/// 승부차기 기록 한 줄: 정규 5칸(●골 ✕실축 ○남음), 서든데스면 서든데스 킥만.
class _Tracker extends StatelessWidget {
  final GameTheme theme;
  final PenaltySide side;
  final List<PenaltyRound> kicks;
  final bool suddenDeath;
  final bool next;
  final Color color;
  final bool alignEnd;

  const _Tracker({
    required this.theme,
    required this.side,
    required this.kicks,
    required this.suddenDeath,
    required this.next,
    required this.color,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final List<PenaltyRound?> slots;
    if (suddenDeath) {
      final sd = kicks.skip(kPenaltyKicksPerPlayer).toList();
      final recent = sd.length <= 4 ? sd : sd.sublist(sd.length - 4);
      slots = [...recent, if (next) null];
    } else {
      slots = List<PenaltyRound?>.generate(
        kPenaltyKicksPerPlayer,
        (i) => i < kicks.length ? kicks[i] : null,
      );
    }
    final nextIndex = suddenDeath
        ? (next ? slots.length - 1 : -1)
        : (next ? kicks.length : -1);
    final goals = kicks.where((k) => k.isGoal).length;
    final dots = [
      for (int i = 0; i < slots.length; i++)
        _KickDot(
          theme: theme,
          kick: slots[i],
          color: color,
          next: i == nextIndex,
        ),
    ];
    return Semantics(
      label: '${side.isMe ? '나' : side.name} 킥 ${kicks.length}번 중 골 $goals',
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in alignEnd ? dots.reversed : dots)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: d,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KickDot extends StatelessWidget {
  final GameTheme theme;
  final PenaltyRound? kick;
  final Color color;
  final bool next;

  const _KickDot({
    required this.theme,
    required this.kick,
    required this.color,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final k = kick;
    const size = 16.0;
    if (k == null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: next ? theme.accent.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: next ? theme.accent : Colors.white.withValues(alpha: 0.28),
            width: next ? 1.6 : 1.2,
          ),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: k.isGoal ? color : const Color(0x33FF5A64),
        border: Border.all(
          color: k.isGoal
              ? Color.lerp(color, Colors.white, 0.35)!
              : PenaltyColors.miss,
          width: 1.2,
        ),
        boxShadow: k.isGoal
            ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6)]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        k.isGoal ? Icons.sports_soccer_rounded : Icons.close_rounded,
        size: k.isGoal ? 11 : 11,
        color: k.isGoal ? Colors.white : PenaltyColors.miss,
      ),
    );
  }
}

/// 스코어버그 아래 띠: 상황 문구 + 남은 시간 숫자, 맨 아래 얇은 시간 막대.
class _InfoStrip extends StatefulWidget {
  final GameTheme theme;
  final String label;
  final GameDeadline? deadline;
  final bool tickSound;
  final Color color;

  const _InfoStrip({
    required this.theme,
    required this.label,
    required this.deadline,
    required this.tickSound,
    required this.color,
  });

  @override
  State<_InfoStrip> createState() => _InfoStripState();
}

class _InfoStripState extends State<_InfoStrip> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _InfoStrip old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.deadline == null) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final d = widget.deadline;
      if (d != null && widget.tickSound) {
        final s = (d.remaining().inMilliseconds / 1000).ceil();
        if (s != _lastSecond && s <= 5 && s >= 1) {
          GameSfx.instance.play(GameSound.tick);
        }
        _lastSecond = s;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final d = widget.deadline;
    final total = d?.total.inMilliseconds ?? 1;
    final left = d?.remaining().inMilliseconds ?? 0;
    final frac = d == null ? 0.0 : (left / math.max(1, total)).clamp(0.0, 1.0);
    final secs = (left / 1000).ceil();
    final urgent = d != null && secs <= 5;
    final barColor = urgent ? PenaltyColors.miss : t.accent;
    return Container(
      height: 28,
      color: const Color(0x59000000),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 3),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.label,
                      key: const Key('penalty_round_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(size: 11.5, weight: FontWeight.w700),
                    ),
                  ),
                  if (d != null)
                    Semantics(
                      key: const Key('penalty_timer'),
                      label: '남은 시간 $secs초',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: urgent ? PenaltyColors.miss : t.subInk,
                          ),
                          const SizedBox(width: 3),
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$secs',
                              textAlign: TextAlign.right,
                              style: t.display(
                                size: 15,
                                color: urgent ? PenaltyColors.miss : t.ink,
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
          if (d != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 상대의 최근 킥 5번을 작은 골대 히트맵으로. 많이 찬 칸일수록 진하고, 점 하나가 킥 하나.
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
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
      decoration: PenaltyColors.glass(radius: 12),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, size: 16, color: t.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '상대 최근 킥',
                  maxLines: 1,
                  style: t.body(
                    size: 11.5,
                    weight: FontWeight.w800,
                    height: 1.2,
                  ),
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
                    weight: fav != null ? FontWeight.w800 : FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _HeatGoal(cells: cells, kicks: recent, color: t.opponent),
        ],
      ),
    );
  }
}

class _HeatGoal extends StatelessWidget {
  final int cells;
  final List<PenaltyRound> kicks;
  final Color color;

  const _HeatGoal({
    required this.cells,
    required this.kicks,
    required this.color,
  });

  static const _w = 96.0;
  static const _h = 36.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final rows = cells == 6 ? 2 : 1;
    final counts = List<int>.filled(cells, 0);
    for (final k in kicks) {
      if (k.kickerDir >= 0 && k.kickerDir < cells) counts[k.kickerDir]++;
    }
    final cw = (_w - _inset * 2) / 3;
    final ch = (_h - _inset - 1) / rows;
    final dot = cells == 6 ? 6.0 : 7.0;
    final placed = List<int>.filled(cells, 0);
    final children = <Widget>[];
    for (int i = 0; i < kicks.length; i++) {
      final k = kicks[i];
      final c = k.kickerDir.clamp(0, cells - 1);
      final n = counts[c];
      final idx = placed[c]++;
      final col = penaltyCol(c);
      final row = penaltyRow(cells, c);
      final center = Offset(
        _inset + cw * (col + 0.5) + (idx - (n - 1) / 2) * (dot + 2),
        _inset + ch * (row + 0.5),
      );
      final latest = i == kicks.length - 1;
      children.add(
        Positioned(
          left: center.dx - dot / 2,
          top: center.dy - dot / 2,
          width: dot,
          height: dot,
          child: Semantics(
            label:
                '${penaltyCellName(cells, k.kickerDir)}, ${k.isGoal ? '골' : '막힘'}',
            child: Container(
              key: Key('penalty_history_kick_$i'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: k.isGoal ? color : const Color(0xFF0A1328),
                border: Border.all(
                  color: latest
                      ? Colors.white
                      : k.isGoal
                      ? Color.lerp(color, Colors.white, 0.3)!
                      : const Color(0xFFAFB9CC),
                  width: latest ? 1.4 : 1,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: _w,
      height: _h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeatPainter(cells, counts, color)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  final int cells;
  final List<int> counts;
  final Color color;

  _HeatPainter(this.cells, this.counts, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = _HeatGoal._inset;
    final mouth = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - 1,
    );
    final rows = cells == 6 ? 2 : 1;
    final maxCount = counts.fold<int>(0, math.max);
    canvas.drawRect(mouth, Paint()..color = const Color(0x40000000));
    for (int c = 0; c < cells; c++) {
      final col = penaltyCol(c);
      final row = penaltyRow(cells, c);
      final r = Rect.fromLTWH(
        mouth.left + mouth.width * col / 3,
        mouth.top + mouth.height * row / rows,
        mouth.width / 3,
        mouth.height / rows,
      ).deflate(0.8);
      if (counts[c] > 0 && maxCount > 0) {
        canvas.drawRect(
          r,
          Paint()
            ..color = color.withValues(
              alpha: 0.12 + 0.38 * counts[c] / maxCount,
            ),
        );
      }
    }
    // 그물 결.
    final mesh = Paint()
      ..strokeWidth = 0.5
      ..color = const Color(0x1FFFFFFF);
    for (double x = mouth.left + 4; x < mouth.right; x += 4) {
      canvas.drawLine(Offset(x, mouth.top), Offset(x, mouth.bottom), mesh);
    }
    for (double y = mouth.top + 4; y < mouth.bottom; y += 4) {
      canvas.drawLine(Offset(mouth.left, y), Offset(mouth.right, y), mesh);
    }
    final grid = Paint()
      ..strokeWidth = 0.8
      ..color = const Color(0x40FFFFFF);
    for (int c = 1; c < 3; c++) {
      final x = mouth.left + mouth.width * c / 3;
      canvas.drawLine(Offset(x, mouth.top), Offset(x, mouth.bottom), grid);
    }
    if (cells == 6) {
      canvas.drawLine(
        Offset(mouth.left, mouth.center.dy),
        Offset(mouth.right, mouth.center.dy),
        grid,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(mouth.left, mouth.bottom)
        ..lineTo(mouth.left, mouth.top)
        ..lineTo(mouth.right, mouth.top)
        ..lineTo(mouth.right, mouth.bottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) =>
      old.cells != cells || old.color != color || !_same(old.counts, counts);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 중계 화면 하단 자막("골!", "선방!"). [id]가 바뀔 때마다 한 번 들어왔다 나간다.
/// 처음 그려질 때의 id는 재생하지 않는다(지난 알림이 다시 뜨지 않게).
class PenaltyLowerThird extends StatefulWidget {
  final GameTheme theme;
  final Object? id;
  final String title;
  final String? sub;
  final Color color;

  const PenaltyLowerThird({
    super.key,
    required this.theme,
    required this.id,
    required this.title,
    required this.color,
    this.sub,
  });

  @override
  State<PenaltyLowerThird> createState() => _PenaltyLowerThirdState();
}

class _PenaltyLowerThirdState extends State<PenaltyLowerThird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  String _title = '';
  String? _sub;
  Color _color = Colors.white;

  @override
  void didUpdateWidget(covariant PenaltyLowerThird old) {
    super.didUpdateWidget(old);
    if (widget.id != null && widget.id != old.id) {
      _title = widget.title;
      _sub = widget.sub;
      _color = widget.color;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final v = _c.value;
          final inK = Curves.easeOutCubic.transform((v / 0.14).clamp(0.0, 1.0));
          final outK = Curves.easeInCubic.transform(
            ((v - 0.86) / 0.14).clamp(0.0, 1.0),
          );
          final subK = Curves.easeOutCubic.transform(
            ((v - 0.08) / 0.14).clamp(0.0, 1.0),
          );
          return Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Opacity(
                opacity: 1 - outK,
                child: Transform(
                  transform: Matrix4.skewX(-0.14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: inK,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 52, color: _color),
                              Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xF2101C38),
                                      Color(0xF20A1328),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  _title,
                                  style: t.display(
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Container(width: 12, height: 52, color: t.accent),
                            ],
                          ),
                        ),
                      ),
                      if (_sub != null)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            widthFactor: subK,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              color: const Color(0xF2F4F7FC),
                              child: Text(
                                _sub!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.body(
                                  size: 12.5,
                                  color: PenaltyColors.navy,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
