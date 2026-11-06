import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import 'telepathy_models.dart';
import 'telepathy_widgets.dart';

/// 등급 id → 문양에서 두 원이 겹치는 정도.
double telepathyTierOverlap(String tierId) => switch (tierId) {
  'soulmate' => 0.95,
  'eyes' => 0.6,
  'learning' => 0.3,
  _ => 0.0,
};

String telepathyTierBlurb(String tierId) => switch (tierId) {
  'soulmate' => '마음이 완전히 이어져 있어요',
  'eyes' => '말하지 않아도 거의 통하는 사이예요',
  'learning' => '서로를 더 알아가는 중이에요',
  _ => '다르니까 더 끌리는 사이예요',
};

/// 판이 끝났을 때의 결과 화면(전체 화면): 등급 · 통한 문제 · 최고 연속 · 문제별 두 사람의 선택 ·
/// 방 기록 · 한 판 더. 협동 게임이라 승패는 없다.
class TelepathyResultPage extends StatefulWidget {
  final TelepathyState state;
  final String? me;
  final String? partner;
  final String Function(String?) nameOf;
  final VoidCallback? onRematch;
  final bool rematchWaiting;
  final VoidCallback? onExit;

  const TelepathyResultPage({
    super.key,
    required this.state,
    required this.me,
    required this.partner,
    required this.nameOf,
    this.onRematch,
    this.rematchWaiting = false,
    this.onExit,
  });

  @override
  State<TelepathyResultPage> createState() => _TelepathyResultPageState();
}

class _TelepathyResultPageState extends State<TelepathyResultPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  static final Set<String> _played = {};

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    if (_played.add(s.gameId)) {
      final tier = s.result?.tier.id ?? '';
      GameSfx.instance.play(
        tier == 'soulmate' || tier == 'eyes' ? GameSound.win : GameSound.draw,
      );
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
    final res = s.result;
    if (res == null) return const SizedBox.shrink();
    final blurb = switch (res.reason) {
      'away' =>
        res.awayPlayer == widget.me
            ? '연속 3문제를 고르지 않아 판이 끝났어요'
            : '상대가 연속 3문제를 고르지 않아 판이 끝났어요',
      'both_away' => '둘 다 자리를 비워 판이 끝났어요',
      _ => telepathyTierBlurb(res.tier.id),
    };
    final myName = widget.nameOf(widget.me);
    final partnerName = widget.nameOf(widget.partner);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
      child: ColoredBox(
        color: kTpBg,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('결과', style: tpSerif(size: 19)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              tooltip: '나가기',
                              iconSize: 24,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: kTpInk,
                              ),
                              onPressed:
                                  widget.onExit ??
                                  () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
                        stops: [0, 0.93, 1],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                        children: [
                          Center(
                            child: TelepathySigil(
                              size: 64,
                              overlap: telepathyTierOverlap(res.tier.id),
                              star: res.tier.id == 'soulmate',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            res.tier.label,
                            textAlign: TextAlign.center,
                            style: tpSerif(size: 32, color: kTpGold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            blurb,
                            textAlign: TextAlign.center,
                            style: tpSans(size: 13.5, color: kTpSub),
                          ),
                          const SizedBox(height: 20),
                          _Stats(result: res),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              children: [
                                Text(
                                  '문제별 우리의 선택',
                                  style: tpSans(
                                    size: 13.5,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                _Legend(
                                  name: '나',
                                  initial: telepathyInitial(myName),
                                  mine: true,
                                ),
                                const SizedBox(width: 10),
                                _Legend(
                                  name: partnerName,
                                  initial: telepathyInitial(partnerName),
                                  mine: false,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kTpLine),
                              color: const Color(0x08FFFFFF),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (int i = 0; i < s.history.length; i++)
                                  _RecapRow(
                                    round: s.history[i],
                                    first: i == 0,
                                    me: widget.me,
                                    partner: widget.partner,
                                    nameOf: widget.nameOf,
                                  ),
                              ],
                            ),
                          ),
                          if ((s.series?.games ?? 0) > 0) ...[
                            const SizedBox(height: 14),
                            Semantics(
                              label:
                                  '이번 방 ${s.series!.games}판, 통한 비율 ${s.series!.ratio}퍼센트, 최고 연속 ${s.series!.bestStreak}',
                              child: ExcludeSemantics(
                                child: Text(
                                  '이번 방 ${s.series!.games}판 · 통한 비율 ${s.series!.ratio}% · 최고 연속 ${s.series!.bestStreak}',
                                  textAlign: TextAlign.center,
                                  style: tpSans(size: 12, color: kTpSub),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onRematch != null)
                          _MainButton(
                            label: widget.rematchWaiting
                                ? '상대의 수락을 기다리는 중…'
                                : '한 판 더',
                            icon: widget.rematchWaiting
                                ? Icons.hourglass_top_rounded
                                : Icons.refresh_rounded,
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
                              style: tpSans(size: 14, color: kTpSub),
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
      ),
    );
  }
}

/// 달빛 금 단색 주 버튼(56, 알약).
class _MainButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _MainButton({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      onTap: onPressed,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: kTpGold,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 20, color: const Color(0xFF1B1A30)),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: tpSans(
                        size: 17,
                        color: const Color(0xFF1B1A30),
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final TelepathyResult result;

  const _Stats({required this.result});

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget big, String small, String semantic) => Expanded(
      child: Semantics(
        container: true,
        label: semantic,
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              big,
              const SizedBox(height: 2),
              Text(small, style: tpSans(size: 12.5, color: kTpSub)),
            ],
          ),
        ),
      ),
    );
    return Container(
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kTpLine),
        color: const Color(0x09FFFFFF),
      ),
      child: Row(
        children: [
          cell(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${result.matches}', style: tpSerif(size: 32)),
                  TextSpan(
                    text: '/${result.total}',
                    style: tpSerif(
                      size: 17,
                      color: kTpSub,
                      weight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            '통한 문제',
            '${result.total}문제 중 ${result.matches}문제가 통했어요',
          ),
          Container(width: 1, height: 42, color: kTpLine),
          cell(
            Text('${result.bestStreak}', style: tpSerif(size: 32)),
            '최고 연속',
            '최고 연속 ${result.bestStreak}문제',
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String name;
  final String initial;
  final bool mine;

  const _Legend({
    required this.name,
    required this.initial,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TelepathyInitialDot(initial: initial, mine: mine, size: 16, ring: 1.3),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 72),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tpSans(size: 12, color: kTpSub),
        ),
      ),
    ],
  );
}

class _RecapRow extends StatelessWidget {
  final TelepathyRound round;
  final bool first;
  final String? me;
  final String? partner;
  final String Function(String?) nameOf;

  const _RecapRow({
    required this.round,
    required this.first,
    required this.me,
    required this.partner,
    required this.nameOf,
  });

  String _pickText(String? id) {
    final c = round.picks[id];
    return c == null ? '시간 초과' : round.question.textOf(c);
  }

  Widget _pick(String? id, bool mine) {
    final c = round.picks[id];
    final color = mine ? kTpGold : kTpPeri;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c == null ? kTpLine : color, width: 1.3),
      ),
      child: Text(
        c ?? '–',
        style: tpSans(
          size: 11,
          color: c == null ? kTpSub : color,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = round.question;
    final matched = round.matched;
    return Semantics(
      label:
          '${round.round}번째 ${q.a} 또는 ${q.b}. '
          '나는 ${_pickText(me)}, ${nameOf(partner)}은 ${_pickText(partner)}. '
          '${matched ? '통했어요' : (round.timedOut ? '시간 초과' : '엇갈렸어요')}',
      child: ExcludeSemantics(
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: kTpLine)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${round.round}',
                  style: tpSans(
                    size: 12,
                    color: kTpSub,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${q.emojiA} ${q.a}  ↔  ${q.emojiB} ${q.b}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tpSans(size: 13.5),
                ),
              ),
              const SizedBox(width: 8),
              _pick(me, true),
              const SizedBox(width: 5),
              _pick(partner, false),
              const SizedBox(width: 10),
              SizedBox(
                width: 18,
                child: matched
                    ? const Icon(Icons.star_rounded, size: 18, color: kTpGold)
                    : Text(
                        '–',
                        textAlign: TextAlign.center,
                        style: tpSans(size: 14, color: kTpSub),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
