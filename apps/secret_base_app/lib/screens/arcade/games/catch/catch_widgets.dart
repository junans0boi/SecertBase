/// 그림 맞히기 화면 부품: 양옆 배지·점수, 글자 칸 힌트, 추측 말풍선, 입력창, 정답 연출.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'catch_controller.dart';
import 'catch_models.dart';

// ── 양옆 배지 + 가운데 시계 ────────────────────────────────────────────────

class CatchScoreRow extends StatelessWidget {
  final GameTheme theme;
  final CatchController controller;
  final CatchState state;

  const CatchScoreRow({
    super.key,
    required this.theme,
    required this.controller,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final me = c.me;
    final opp = state.opponentOf(me);
    return Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: _slot(me, true)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TurnTimerRing(
                theme: theme,
                deadline: c.deadline,
                size: 54,
                tickSound: state.drawing,
              ),
              const SizedBox(height: 2),
              Text(
                '${state.round.clamp(1, state.maxRounds)} / ${state.maxRounds}',
                style: theme.body(
                  size: 11.5,
                  color: theme.subInk,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _slot(opp, false),
          ),
        ),
      ],
    );
  }

  Widget _slot(String? id, bool isMe) {
    final isDrawer = id != null && id == state.drawer;
    final role = !state.playing
        ? null
        : state.revealing
        ? null
        : (isDrawer ? '그리는 중' : '맞히는 중');
    return PlayerBadge(
      theme: theme,
      emoji: controller.emojiOf(id),
      name: controller.displayName(id),
      subtitle: role,
      active: isDrawer && state.drawing,
      isMe: isMe,
      compact: true,
      extra: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: _ScorePill(theme: theme, score: state.scores[id] ?? 0),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final GameTheme theme;
  final int score;

  const _ScorePill({required this.theme, required this.score});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: '$score점',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: t.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Text(
            '$score점',
            key: ValueKey(score),
            style: t.body(size: 12, color: t.accent, weight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

// ── 글자 칸 힌트 ───────────────────────────────────────────────────────────

/// 제시어 글자 수만큼 칸을 놓는다. 열린 칸은 글자, 닫힌 칸은 빈 종이 조각.
/// 그리는 사람과 정답 공개 때는 모든 글자가 보이고, 칸이 열릴 때마다 뒤집힌다.
class CatchLetterTiles extends StatelessWidget {
  final GameTheme theme;
  final int length;
  final List<String> hint;
  final String? word;
  final bool showAll;
  final bool mine;

  const CatchLetterTiles({
    super.key,
    required this.theme,
    required this.length,
    required this.hint,
    required this.word,
    required this.showAll,
    this.mine = false,
  });

  String _charAt(int i) {
    if (showAll && word != null) {
      final chars = word!.characters.toList();
      return i < chars.length ? chars[i] : '';
    }
    return i < hint.length ? hint[i] : '';
  }

  @override
  Widget build(BuildContext context) {
    final label = showAll && word != null
        ? '제시어 $word'
        : '$length글자, 열린 글자 ${hint.where((h) => h.isNotEmpty).join(', ')}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 5.0;
          final n = math.max(1, length);
          final w = ((box.maxWidth - gap * (n - 1)) / n).clamp(24.0, 42.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _LetterTile(
                  theme: theme,
                  width: w,
                  char: _charAt(i),
                  gold: mine || showAll,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  final GameTheme theme;
  final double width;
  final String char;
  final bool gold;

  const _LetterTile({
    required this.theme,
    required this.width,
    required this.char,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final open = char.isNotEmpty;
    final height = width * 1.2 + 4;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, anim) => AnimatedBuilder(
          animation: anim,
          child: child,
          builder: (context, child) {
            final v = anim.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX((1 - v) * math.pi / 2),
              child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
            );
          },
        ),
        child: Container(
          key: ValueKey(char),
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: open ? const Color(0xFFFFFDF6) : const Color(0xFFF6EEDC),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: open && gold ? t.gold : t.accent.withValues(alpha: 0.5),
              width: open && gold ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: open ? 0.14 : 0.07),
                blurRadius: open ? 6 : 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: open
              ? Text(
                  char,
                  style: t.display(size: width * 0.62, color: t.ink),
                )
              : Container(
                  width: width * 0.46,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── 추측 말풍선(보드 위 양옆) ───────────────────────────────────────────────

/// 배지에서 튀어나오는 말풍선. 그리는 사람도 본다. 마지막 추측만 잠깐 떠 있다.
class CatchGuessBubbles extends StatefulWidget {
  final GameTheme theme;
  final CatchController controller;
  final String? leftId;
  final String? rightId;

  const CatchGuessBubbles({
    super.key,
    required this.theme,
    required this.controller,
    required this.leftId,
    required this.rightId,
  });

  @override
  State<CatchGuessBubbles> createState() => _CatchGuessBubblesState();
}

class _CatchGuessBubblesState extends State<CatchGuessBubbles> {
  static const Duration life = Duration(milliseconds: 3800);
  final Map<String, DateTime> _shownAt = {};
  final Map<String, String> _shownId = {};
  Timer? _expire;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    _expire?.cancel();
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    var changed = false;
    for (final e in widget.controller.latestGuess.entries) {
      if (_shownId[e.key] != e.value.id) {
        _shownId[e.key] = e.value.id;
        _shownAt[e.key] = DateTime.now();
        changed = true;
      }
    }
    // 새 라운드에서 지워졌으면 말풍선도 지운다.
    if (widget.controller.latestGuess.isEmpty && _shownId.isNotEmpty) {
      _shownId.clear();
      _shownAt.clear();
      changed = true;
    }
    if (changed && mounted) {
      setState(() {});
      _expire?.cancel();
      _expire = Timer(life + const Duration(milliseconds: 60), () {
        if (mounted) setState(() {});
      });
    }
  }

  CatchGuess? _visible(String? id) {
    if (id == null) return null;
    final at = _shownAt[id];
    final g = widget.controller.latestGuess[id];
    if (at == null || g == null) return null;
    return DateTime.now().difference(at) < life ? g : null;
  }

  @override
  Widget build(BuildContext context) {
    final left = _visible(widget.leftId);
    final right = _visible(widget.rightId);
    return IgnorePointer(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: left == null
                  ? const SizedBox.shrink()
                  : _Bubble(
                      key: ValueKey(left.id),
                      theme: widget.theme,
                      guess: left,
                      tailLeft: true,
                    ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: right == null
                  ? const SizedBox.shrink()
                  : _Bubble(
                      key: ValueKey(right.id),
                      theme: widget.theme,
                      guess: right,
                      tailLeft: false,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final GameTheme theme;
  final CatchGuess guess;
  final bool tailLeft;

  const _Bubble({
    super.key,
    required this.theme,
    required this.guess,
    required this.tailLeft,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final (bg, fg, tag) = guess.correct
        ? (const Color(0xFFD7F5DE), const Color(0xFF1D6B38), '정답!')
        : guess.close
        ? (const Color(0xFFFFEBB0), const Color(0xFF7A5200), '아까워요!')
        : (Colors.white, t.ink, null);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: v.clamp(0.0, 1.2),
        alignment: tailLeft ? Alignment.topLeft : Alignment.topRight,
        child: child,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(tailLeft ? 3 : 14),
            topRight: Radius.circular(tailLeft ? 14 : 3),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
          border: Border.all(color: fg.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null)
              Text(
                tag,
                style: t.body(size: 10.5, color: fg, weight: FontWeight.w900),
              ),
            Text(
              guess.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.body(size: 14, color: fg, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 맞히는 사람의 입력창 ─────────────────────────────────────────────────────

class CatchGuessInput extends StatefulWidget {
  final GameTheme theme;
  final bool enabled;
  final String placeholder;
  final bool canHint;
  final bool Function(String text) onSubmit;
  final VoidCallback onHint;

  const CatchGuessInput({
    super.key,
    required this.theme,
    required this.enabled,
    required this.placeholder,
    required this.canHint,
    required this.onSubmit,
    required this.onHint,
  });

  @override
  State<CatchGuessInput> createState() => _CatchGuessInputState();
}

class _CatchGuessInputState extends State<CatchGuessInput> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (!widget.enabled) return;
    final value = _text.text.trim();
    if (value.isEmpty) return;
    if (widget.onSubmit(value)) {
      _text.clear();
      HapticFeedback.selectionClick();
    }
    // 키보드를 내리지 않고 바로 다음 추측을 쓸 수 있게 한다.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: t.accent.withValues(alpha: 0.55), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            enabled: widget.canHint && widget.enabled,
            label: '힌트 보기, 1점 차감',
            child: GestureDetector(
              key: const ValueKey('catch-hint'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.canHint && widget.enabled ? widget.onHint : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.canHint && widget.enabled ? 1 : 0.35,
                child: Container(
                  width: kCatchHintSize,
                  height: kCatchHintSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBB0),
                    shape: BoxShape.circle,
                    border: Border.all(color: t.gold, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💡', style: TextStyle(fontSize: 21)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('catch-guess-field'),
              controller: _text,
              focusNode: _focus,
              enabled: widget.enabled,
              maxLength: 20,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: t.body(size: 16, weight: FontWeight.w700),
              cursorColor: t.accent,
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                border: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: t.body(
                  size: 15,
                  color: t.subInk.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            enabled: widget.enabled,
            label: '추측 보내기',
            child: GestureDetector(
              key: const ValueKey('catch-send'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? _send : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: widget.enabled ? 1 : 0.4,
                child: Container(
                  width: kCatchHintSize,
                  height: kCatchHintSize,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 24,
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

const double kCatchHintSize = 44;

/// 이번 라운드의 최근 추측 목록(맞히는 사람이 내가 뭘 썼는지 보게).
class CatchGuessLog extends StatelessWidget {
  final GameTheme theme;
  final CatchController controller;
  final int maxItems;

  const CatchGuessLog({
    super.key,
    required this.theme,
    required this.controller,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final items = controller.guessLog.reversed.take(maxItems).toList();
    if (items.isEmpty) {
      return Center(
        child: Text(
          '떠오르는 말을 바로 써 보세요!',
          style: t.body(size: 13, color: t.subInk, weight: FontWeight.w700),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final g in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${controller.displayName(g.userId)}  ',
                  style: t.body(
                    size: 12,
                    color: g.userId == controller.me ? t.me : t.opponent,
                    weight: FontWeight.w900,
                  ),
                ),
                Flexible(
                  child: Text(
                    g.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(size: 14, weight: FontWeight.w700),
                  ),
                ),
                if (g.close)
                  Text(
                    '  아까워요!',
                    style: t.body(
                      size: 12,
                      color: const Color(0xFFB07A00),
                      weight: FontWeight.w900,
                    ),
                  )
                else if (g.correct)
                  Text(
                    '  정답!',
                    style: t.body(
                      size: 12,
                      color: const Color(0xFF1D8A47),
                      weight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 정답 연출 ──────────────────────────────────────────────────────────────

/// 라운드가 끝났을 때 보드 위에 도장처럼 찍히는 "정답!" / "시간 끝!".
class CatchRevealOverlay extends StatelessWidget {
  final GameTheme theme;
  final CatchRoundResult result;
  final CatchController controller;

  const CatchRevealOverlay({
    super.key,
    required this.theme,
    required this.result,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = result.record;
    final c = controller;
    final good = r.correct;
    final color = good ? const Color(0xFF1D8A47) : const Color(0xFFC2543F);
    final guesser = r.guesser;
    final lines = <String>[
      if (good && guesser != null)
        '${c.displayName(guesser)}${josa(c.displayName(guesser), '이', '가')} 맞혔어요!'
      else
        '아쉽게 시간이 끝났어요',
    ];
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: const Color(0xFFFFFBF0).withValues(alpha: 0.55)),
          Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('reveal-${r.round}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.rotate(
                angle: -0.07,
                child: Transform.scale(
                  scale: (1.9 - 0.9 * v).clamp(0.9, 1.9),
                  child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color, width: 3.4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      good ? '정답!' : '시간 끝!',
                      style: t.display(size: 38, color: color),
                    ),
                    Text(
                      lines.first,
                      style: t.body(
                        size: 13,
                        color: t.ink,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '정답은 “${r.word}”',
                      style: t.display(size: 20, color: t.ink),
                    ),
                    if (good) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final p in [guesser!, r.drawer])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _PointChip(
                                theme: t,
                                label: c.displayName(p),
                                points: r.points[p] ?? 0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (good)
            ConfettiBurst(
              trigger: 'catch-${r.round}-${result.revealUntil}',
              colors: [
                t.accent,
                t.gold,
                t.opponent,
                const Color(0xFF3BA55D),
                Colors.white,
              ],
              count: 80,
            ),
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final int points;

  const _PointChip({
    required this.theme,
    required this.label,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label +$points',
        style: theme.body(
          size: 12,
          color: theme.accent,
          weight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ── 준비 중 ───────────────────────────────────────────────────────────────

class CatchPreparing extends StatefulWidget {
  final GameTheme theme;

  const CatchPreparing({super.key, required this.theme});

  @override
  State<CatchPreparing> createState() => _CatchPreparingState();
}

class _CatchPreparingState extends State<CatchPreparing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) =>
                Transform.rotate(angle: (_c.value - 0.5) * 0.5, child: child),
            child: const Text('✏️', style: TextStyle(fontSize: 54)),
          ),
          const SizedBox(height: 12),
          Text('스케치북을 펼치는 중…', style: t.display(size: 22)),
          const SizedBox(height: 4),
          Text('곧 제시어가 정해져요', style: t.body(size: 13, color: t.subInk)),
        ],
      ),
    );
  }
}
