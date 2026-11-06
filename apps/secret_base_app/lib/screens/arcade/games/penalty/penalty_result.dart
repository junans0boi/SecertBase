import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/confetti_burst.dart';
import '../../../../widgets/play_kit/game_result_overlay.dart' show GameOutcome;
import 'penalty_chrome.dart';
import 'penalty_models.dart';

/// 패널티킥 최종 결과(목업 안 A "야간 방송"의 FULL TIME 화면).
/// 경기 화면 위에 통째로 올리는 불투명 오버레이다. 공용 [GameResultOverlay]와 달리
/// 킥 기록표(●골 ○막힘)와 이번 방 전적을 함께 보여 준다. 재대결·나가기 계약은 그대로.
class PenaltyResultView extends StatefulWidget {
  final GameOutcome outcome;
  final String title;
  final String reason;
  final PenaltyState state;
  final String me;
  final String? opponent;
  final String myName;
  final String opponentName;
  final bool rematchWaiting;
  final VoidCallback? onRematch;
  final VoidCallback? onExit;
  final VoidCallback? onHelp;

  const PenaltyResultView({
    super.key,
    required this.outcome,
    required this.title,
    required this.reason,
    required this.state,
    required this.me,
    required this.opponent,
    required this.myName,
    required this.opponentName,
    this.rematchWaiting = false,
    this.onRematch,
    this.onExit,
    this.onHelp,
  });

  @override
  State<PenaltyResultView> createState() => _PenaltyResultViewState();
}

class _PenaltyResultViewState extends State<PenaltyResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  static final Set<Object> _played = {};

  @override
  void initState() {
    super.initState();
    final id = widget.state.gameId;
    if (id == null || _played.add(id)) {
      GameSfx.instance.play(switch (widget.outcome) {
        GameOutcome.win => GameSound.win,
        GameOutcome.lose => GameSound.lose,
        GameOutcome.draw => GameSound.draw,
      });
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final myScore = s.scoreOf(widget.me);
    final oppScore = s.scoreOf(widget.opponent);
    final myKicks = s.kicksBy(widget.me);
    final oppKicks = s.kicksBy(widget.opponent);
    final win = widget.outcome == GameOutcome.win;
    final lose = widget.outcome == GameOutcome.lose;

    return FadeTransition(
      opacity: _in,
      child: PenaltyNightBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (win)
              ConfettiBurst(
                trigger: s.gameId ?? 'win',
                colors: const [
                  PenaltyNight.accent,
                  PenaltyNight.me,
                  PenaltyNight.opponent,
                  Colors.white,
                ],
              ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      PenaltyTopBar(
                        chip: '${s.cells}칸',
                        onBack: widget.onExit ?? () => _leave(context),
                        onHelp: widget.onHelp,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final compact = box.maxHeight < 520;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                12,
                              ),
                              child: _FinalCard(
                                title: widget.title,
                                reason: widget.reason,
                                compact: compact,
                                myScore: myScore,
                                oppScore: oppScore,
                                myHighlight: win,
                                oppHighlight: lose,
                                myName: widget.myName,
                                opponentName: widget.opponentName,
                                myKicks: myKicks,
                                oppKicks: oppKicks,
                                series: s.series,
                                me: widget.me,
                                cells: s.cells,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          math.max(
                            24,
                            MediaQuery.viewPaddingOf(context).bottom + 8,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onRematch != null)
                              PenaltyMainButton(
                                label: widget.rematchWaiting
                                    ? '상대의 수락을 기다리는 중…'
                                    : '한 판 더',
                                onPressed: widget.rematchWaiting
                                    ? null
                                    : widget.onRematch,
                              ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed:
                                    widget.onExit ?? () => _leave(context),
                                child: Text(
                                  '나가기',
                                  style: PenaltyNight.ui(
                                    14,
                                    color: PenaltyNight.sub,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  void _leave(BuildContext context) => Navigator.of(context).maybePop();
}

class _FinalCard extends StatelessWidget {
  final String title;
  final String reason;
  final bool compact;
  final int myScore;
  final int oppScore;
  final bool myHighlight;
  final bool oppHighlight;
  final String myName;
  final String opponentName;
  final List<PenaltyRound> myKicks;
  final List<PenaltyRound> oppKicks;
  final Map<String, dynamic>? series;
  final String me;
  final int cells;

  const _FinalCard({
    required this.title,
    required this.reason,
    required this.compact,
    required this.myScore,
    required this.oppScore,
    required this.myHighlight,
    required this.oppHighlight,
    required this.myName,
    required this.opponentName,
    required this.myKicks,
    required this.oppKicks,
    required this.series,
    required this.me,
    required this.cells,
  });

  @override
  Widget build(BuildContext context) {
    final hasKicks = myKicks.isNotEmpty || oppKicks.isNotEmpty;
    final regular = [
      myKicks.length,
      oppKicks.length,
    ].reduce((a, b) => a > b ? a : b).clamp(0, kPenaltyKicksPerPlayer);
    final sudden =
        [myKicks.length, oppKicks.length].reduce((a, b) => a > b ? a : b) -
        kPenaltyKicksPerPlayer;
    final bigSize = compact ? 60.0 : 76.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        compact ? 22 : 28,
        22,
        compact ? 16 : 20,
      ),
      decoration: PenaltyNight.card(radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FULL TIME',
            style: PenaltyNight.ui(12, color: PenaltyNight.sub, spacing: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: PenaltyNight.display(compact ? 36 : 44),
          ),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: PenaltyNight.ui(
              13,
              color: PenaltyNight.sub,
              weight: FontWeight.w400,
              height: 1.5,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: compact ? 10 : 14,
              bottom: compact ? 14 : 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$myScore',
                  key: const Key('penalty_result_my_score'),
                  style: _bigStyle(
                    bigSize,
                    myHighlight ? PenaltyNight.accent : PenaltyNight.ink,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  ':',
                  style: PenaltyNight.ui(
                    36,
                    color: PenaltyNight.sub,
                    weight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '$oppScore',
                  key: const Key('penalty_result_opp_score'),
                  style: _bigStyle(
                    bigSize,
                    oppHighlight ? PenaltyNight.accent : PenaltyNight.ink,
                  ),
                ),
              ],
            ),
          ),
          if (hasKicks) ...[
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: PenaltyNight.line)),
              ),
              child: Column(
                children: [
                  _KickRow(
                    name: myName,
                    kicks: myKicks,
                    score: myScore,
                    regularSlots: regular,
                    height: compact ? 46 : 52,
                  ),
                  _KickRow(
                    name: opponentName,
                    kicks: oppKicks,
                    score: oppScore,
                    regularSlots: regular,
                    height: compact ? 46 : 52,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Dot(kind: _DotKind.goal, size: 10),
                  const SizedBox(width: 4),
                  Text('골', style: _noteStyle),
                  const SizedBox(width: 8),
                  const _Dot(kind: _DotKind.miss, size: 10),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '막힘   정규 $regular번'
                      '${sudden > 0 ? ' + 서든데스 $sudden번' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _noteStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (series != null)
            _SeriesRow(series: series!, me: me, compact: compact),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '재대결은 칸 수($cells칸)는 그대로, 첫 키커만 바뀌어요',
              textAlign: TextAlign.center,
              style: _noteStyle,
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _bigStyle(double size, Color color) => PenaltyNight.ui(
    size,
    color: color,
    weight: FontWeight.w800,
    spacing: -0.04,
    height: 1,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static final _noteStyle = PenaltyNight.ui(
    12,
    color: PenaltyNight.sub,
    weight: FontWeight.w400,
  );
}

enum _DotKind { goal, miss, pending }

class _Dot extends StatelessWidget {
  final _DotKind kind;
  final double size;

  const _Dot({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: switch (kind) {
        _DotKind.goal => const BoxDecoration(
          shape: BoxShape.circle,
          color: PenaltyNight.accent,
        ),
        _DotKind.miss => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PenaltyNight.opponent, width: 2),
        ),
        _DotKind.pending => BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PenaltyNight.line, width: 1.5),
        ),
      },
    );
  }
}

/// 한 선수의 킥 기록: 정규 킥(안 찬 칸은 빈 원) | 서든데스 킥, 맨 오른쪽에 골 수.
class _KickRow extends StatelessWidget {
  final String name;
  final List<PenaltyRound> kicks;
  final int score;
  final int regularSlots;
  final double height;

  const _KickRow({
    required this.name,
    required this.kicks,
    required this.score,
    required this.regularSlots,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final regular = kicks.take(kPenaltyKicksPerPlayer).toList();
    final sudden = kicks.skip(kPenaltyKicksPerPlayer).toList();
    _Dot dot(PenaltyRound r) =>
        _Dot(kind: r.isGoal ? _DotKind.goal : _DotKind.miss, size: 16);
    final dots = <Widget>[
      for (int i = 0; i < regularSlots; i++)
        i < regular.length
            ? dot(regular[i])
            : const _Dot(kind: _DotKind.pending, size: 16),
      if (sudden.isNotEmpty)
        Container(
          width: 1,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          color: PenaltyNight.line,
        ),
      for (final r in sudden) dot(r),
    ];
    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PenaltyNight.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PenaltyNight.ui(14),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  for (int i = 0; i < dots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    dots[i],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 24,
            child: Text(
              '$score',
              textAlign: TextAlign.right,
              style: PenaltyNight.ui(20, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번 방 전적: 이긴 판(형광) → 진 판 → 비긴 판 순서의 점 + "3승 1패".
class _SeriesRow extends StatelessWidget {
  final Map<String, dynamic> series;
  final String me;
  final bool compact;

  const _SeriesRow({
    required this.series,
    required this.me,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final wins = (series['wins'] as Map?) ?? const {};
    int mine = 0, theirs = 0;
    wins.forEach((k, v) {
      final n = (v as num?)?.toInt() ?? 0;
      if (k == me) {
        mine = n;
      } else {
        theirs += n;
      }
    });
    final draws = (series['draws'] as num?)?.toInt() ?? 0;
    final label = '$mine승 $theirs패${draws > 0 ? ' $draws무' : ''}';
    final total = (mine + theirs + draws).clamp(0, 8);
    int shown = 0;
    Widget dot(Color fill, {Color? border}) {
      shown++;
      return Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: border == null ? null : Border.all(color: border),
        ),
      );
    }

    final dots = <Widget>[
      for (int i = 0; i < mine && shown < total; i++) dot(PenaltyNight.accent),
      for (int i = 0; i < theirs && shown < total; i++) dot(PenaltyNight.line),
      for (int i = 0; i < draws && shown < total; i++)
        dot(Colors.transparent, border: PenaltyNight.sub),
    ];
    return Semantics(
      label: '이번 방 전적 나 $mine승, 상대 $theirs승, 무승부 $draws',
      excludeSemantics: true,
      child: Container(
        margin: EdgeInsets.only(top: compact ? 12 : 16),
        height: compact ? 46 : 52,
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: PenaltyNight.line),
          ),
        ),
        child: Row(
          children: [
            Text(
              '이번 방 전적',
              style: PenaltyNight.ui(
                13,
                color: PenaltyNight.sub,
                weight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            ...dots,
            const SizedBox(width: 2),
            Text(label, style: PenaltyNight.ui(14)),
          ],
        ),
      ),
    );
  }
}
