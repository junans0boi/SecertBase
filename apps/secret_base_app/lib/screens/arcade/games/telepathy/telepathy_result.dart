import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'telepathy_models.dart';

/// 등급 id → 이모지.
String telepathyTierEmoji(String tierId) => switch (tierId) {
  'soulmate' => '💞',
  'eyes' => '👀',
  'learning' => '🌱',
  _ => '🧲',
};

String telepathyTierBlurb(String tierId) => switch (tierId) {
  'soulmate' => '마음이 완전히 이어져 있어요',
  'eyes' => '눈빛만 봐도 알아요',
  'learning' => '서로를 더 알아가는 중이에요',
  _ => '다르니까 더 끌리는 사이예요',
};

/// 판이 끝났을 때의 결과 카드: 등급 · 통한 수 · 최고 연속 · 문제별 두 사람의 선택 · 방 기록 · 한 판 더.
/// 협동 게임이라 승패는 없다.
class TelepathyResultCard extends StatefulWidget {
  final GameTheme theme;
  final TelepathyState state;
  final String? me;
  final String? partner;
  final String Function(String?) nameOf;
  final String myEmoji;
  final String partnerEmoji;
  final VoidCallback? onRematch;
  final bool rematchWaiting;
  final VoidCallback? onExit;

  const TelepathyResultCard({
    super.key,
    required this.theme,
    required this.state,
    required this.me,
    required this.partner,
    required this.nameOf,
    required this.myEmoji,
    required this.partnerEmoji,
    this.onRematch,
    this.rematchWaiting = false,
    this.onExit,
  });

  @override
  State<TelepathyResultCard> createState() => _TelepathyResultCardState();
}

class _TelepathyResultCardState extends State<TelepathyResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  static final Set<String> _played = {};

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    if (_played.add(s.gameId)) {
      final good =
          (s.result?.tier.id ?? '') == 'soulmate' ||
          (s.result?.tier.id ?? '') == 'eyes';
      GameSfx.instance.play(good ? GameSound.win : GameSound.draw);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final s = widget.state;
    final res = s.result;
    if (res == null) return const SizedBox.shrink();
    final good = res.tier.id == 'soulmate' || res.tier.id == 'eyes';
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    final reason = switch (res.reason) {
      'away' =>
        res.awayPlayer == widget.me
            ? '연속 3문제를 고르지 않아 판이 끝났어요'
            : '상대가 연속 3문제를 고르지 않아 판이 끝났어요',
      'both_away' => '둘 다 자리를 비워 판이 끝났어요',
      _ => telepathyTierBlurb(res.tier.id),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _in,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
        ),
        if (good && res.complete)
          ConfettiBurst(
            trigger: s.gameId,
            colors: [t.gold, t.accent, t.me, t.opponent, Colors.white],
          ),
        Center(
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curve),
            child: FadeTransition(
              opacity: _in,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.sizeOf(context).height - 24,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: GamePanel(
                    theme: t,
                    radius: 28,
                    opaque: true,
                    glow: good ? t.gold : null,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          telepathyTierEmoji(res.tier.id),
                          style: const TextStyle(fontSize: 44),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          res.tier.label,
                          textAlign: TextAlign.center,
                          style: t.display(size: 30, color: t.gold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reason,
                          textAlign: TextAlign.center,
                          style: t.body(
                            size: 13,
                            color: t.subInk,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stats(theme: t, result: res),
                        const SizedBox(height: 10),
                        Flexible(
                          child: _Recap(
                            theme: t,
                            history: s.history,
                            me: widget.me,
                            partner: widget.partner,
                            nameOf: widget.nameOf,
                          ),
                        ),
                        if ((s.series?.games ?? 0) > 0) ...[
                          const SizedBox(height: 8),
                          _SeriesLine(theme: t, series: s.series!),
                        ],
                        const SizedBox(height: 10),
                        if (widget.onRematch != null)
                          GamePrimaryButton(
                            theme: t,
                            label: widget.rematchWaiting
                                ? '상대의 수락을 기다리는 중…'
                                : '한 판 더!',
                            icon: widget.rematchWaiting
                                ? Icons.hourglass_top_rounded
                                : Icons.replay_rounded,
                            height: 50,
                            onPressed: widget.rematchWaiting
                                ? null
                                : widget.onRematch,
                          ),
                        SizedBox(
                          height: 44,
                          child: TextButton(
                            onPressed:
                                widget.onExit ??
                                () => Navigator.of(context).maybePop(),
                            child: Text(
                              '나가기',
                              style: t.body(size: 14, color: t.subInk),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  final GameTheme theme;
  final TelepathyResult result;

  const _Stats({required this.theme, required this.result});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget cell(String big, String small, String semantic) => Expanded(
      child: Semantics(
        label: semantic,
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text(big, style: t.display(size: 28, color: t.ink)),
              Text(small, style: t.body(size: 11.5, color: t.subInk)),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.surfaceBorder),
      ),
      child: Row(
        children: [
          cell(
            '${result.matches}/${result.total}',
            '통한 문제',
            '${result.total}문제 중 ${result.matches}문제가 통했어요',
          ),
          Container(width: 1, height: 34, color: t.surfaceBorder),
          cell(
            '🔥 ${result.bestStreak}',
            '최고 연속',
            '최고 연속 ${result.bestStreak}문제',
          ),
        ],
      ),
    );
  }
}

class _Recap extends StatelessWidget {
  final GameTheme theme;
  final List<TelepathyRound> history;
  final String? me;
  final String? partner;
  final String Function(String?) nameOf;

  const _Recap({
    required this.theme,
    required this.history,
    required this.me,
    required this.partner,
    required this.nameOf,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제별 우리의 선택', style: t.body(size: 12, color: t.subInk)),
        const SizedBox(height: 4),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) => _RecapRow(
              theme: t,
              round: history[i],
              me: me,
              partner: partner,
              nameOf: nameOf,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  final GameTheme theme;
  final TelepathyRound round;
  final String? me;
  final String? partner;
  final String Function(String?) nameOf;

  const _RecapRow({
    required this.theme,
    required this.round,
    required this.me,
    required this.partner,
    required this.nameOf,
  });

  String _pickText(String? id) {
    final c = round.picks[id];
    return c == null ? '시간 초과' : round.question.textOf(c);
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final q = round.question;
    final matched = round.matched;
    final mine = _pickText(me);
    final theirs = _pickText(partner);
    return Semantics(
      label:
          '${round.round}번째 ${q.a} 또는 ${q.b}. '
          '나는 $mine, ${nameOf(partner)}은 $theirs. '
          '${matched ? '통했어요' : (round.timedOut ? '시간 초과' : '엇갈렸어요')}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          decoration: BoxDecoration(
            color: matched
                ? t.gold.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: matched
                  ? t.gold.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${round.round}',
                  style: t.body(size: 12, color: t.subInk),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${q.emojiA} ${q.a}  ↔  ${q.emojiB} ${q.b}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(size: 12.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '나 $mine',
                            style: TextStyle(color: t.me),
                          ),
                          TextSpan(
                            text: '  ·  ',
                            style: TextStyle(color: t.subInk),
                          ),
                          TextSpan(
                            text: '${nameOf(partner)} $theirs',
                            style: TextStyle(color: t.opponent),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(size: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                matched
                    ? Icons.star_rounded
                    : (round.timedOut
                          ? Icons.timer_off_rounded
                          : Icons.close_rounded),
                size: 20,
                color: matched ? t.gold : t.subInk.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesLine extends StatelessWidget {
  final GameTheme theme;
  final TelepathySeries series;

  const _SeriesLine({required this.theme, required this.series});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label:
          '이번 방 기록 ${series.games}판, 통한 비율 ${series.ratio}퍼센트, '
          '최고 연속 ${series.bestStreak}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            '이번 방 ${series.games}판 · 통한 비율 ${series.ratio}% · 최고 연속 ${series.bestStreak}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 12, color: t.ink),
          ),
        ),
      ),
    );
  }
}
