import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'onecard_cards.dart';
import 'onecard_models.dart';
import 'onecard_ui.dart';

/// 캡슐 안 보조 문구의 색.
enum OneCardSub { plain, hi, warn }

/// 플레이어 캡슐: 이름 첫 글자 아바타(차례면 시간 링이 감쌈) + 이름 + 보조 문구 + 남은 초.
class OneCardPlayerCap extends StatefulWidget {
  final String name;
  final String sub;
  final OneCardSub subStyle;
  final bool mine;
  final bool active;
  final GameDeadline? deadline;
  final bool tickSound;

  const OneCardPlayerCap({
    super.key,
    required this.name,
    required this.sub,
    this.subStyle = OneCardSub.plain,
    this.mine = false,
    this.active = false,
    this.deadline,
    this.tickSound = false,
  });

  @override
  State<OneCardPlayerCap> createState() => _OneCardPlayerCapState();
}

class _OneCardPlayerCapState extends State<OneCardPlayerCap> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final d = widget.deadline;
      if (d == null) return;
      if (widget.tickSound) {
        final s = d.remaining().inSeconds;
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
    final d = widget.deadline;
    final total = d?.total.inMilliseconds ?? 1;
    final left = d?.remaining().inMilliseconds ?? 0;
    final frac = d == null ? 0.0 : (left / math.max(1, total)).clamp(0.0, 1.0);
    final secs = (left / 1000).ceil();
    final low = d != null && secs <= 5;
    final subColor = switch (widget.subStyle) {
      OneCardSub.plain => OneCardUi.sub,
      OneCardSub.hi => OneCardUi.vio2,
      OneCardSub.warn => OneCardUi.warn,
    };
    return Semantics(
      label:
          '${widget.name}${widget.active ? ', 차례' : ''}, ${widget.sub}${d == null ? '' : ', 남은 시간 $secs초'}',
      excludeSemantics: true,
      child: Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
        decoration: BoxDecoration(
          color: widget.active
              ? const Color(0x248E6CF2)
              : const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: widget.active ? const Color(0x8CB9A2FF) : OneCardUi.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (d != null)
                    Positioned(
                      left: -4,
                      top: -4,
                      child: CustomPaint(
                        size: const Size(48, 48),
                        painter: _RingPainter(frac: frac, low: low),
                      ),
                    ),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.mine
                          ? OneCardUi.meAvatar
                          : OneCardUi.oppAvatar,
                    ),
                    child: Text(
                      oneCardInitial(widget.name),
                      style: OneCardUi.sans(
                        size: 14,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OneCardUi.sans(
                      size: 14,
                      weight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OneCardUi.sans(
                      size: 12,
                      color: subColor,
                      weight: widget.subStyle == OneCardSub.plain
                          ? FontWeight.w500
                          : FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            if (d != null) ...[
              const SizedBox(width: 6),
              Text(
                '$secs',
                style: OneCardUi.sans(
                  size: 13,
                  color: low ? OneCardUi.warn : OneCardUi.vio2,
                  weight: FontWeight.w800,
                  features: OneCardUi.tabular,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final bool low;

  _RingPainter({required this.frac, required this.low});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 21.0;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x1FFFFFFF),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = low ? OneCardUi.urgent : OneCardUi.vio2,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.frac != frac || old.low != low;
}

/// 원카드! / 잡기! 알약 버튼. 꺼져 있으면 흐리고, 켜지면 원카드!는 보라 후광, 잡기!는 흰 외곽선.
class OneCardCallButton extends StatelessWidget {
  final String label;
  final String semantics;
  final bool enabled;
  final bool primary;
  final bool compact;
  final VoidCallback onTap;

  const OneCardCallButton({
    super.key,
    required this.label,
    required this.semantics,
    required this.enabled,
    required this.primary,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = enabled;
    final Color bg;
    final Color fg;
    final Color border;
    List<BoxShadow>? glow;
    if (!on) {
      bg = const Color(0x0AFFFFFF);
      fg = const Color(0xFF5E5080);
      border = OneCardUi.line;
    } else if (primary) {
      bg = OneCardUi.vio;
      fg = Colors.white;
      border = Colors.transparent;
      glow = const [BoxShadow(color: Color(0x388E6CF2), spreadRadius: 5)];
    } else {
      bg = Colors.transparent;
      fg = OneCardUi.ink;
      border = const Color(0x66FFFFFF);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: semantics,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          constraints: BoxConstraints(minWidth: compact ? 66 : 76),
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
            boxShadow: glow,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: OneCardUi.sans(
              size: 14,
              color: fg,
              weight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 잠깐 뜨는 안내: 밝은 알약. [id]가 바뀌면 [message]를 잠깐 보여 준다.
class OneCardToast extends StatefulWidget {
  final Object? id;
  final String? message;
  final Duration duration;

  const OneCardToast({
    super.key,
    required this.id,
    required this.message,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<OneCardToast> createState() => _OneCardToastState();
}

class _OneCardToastState extends State<OneCardToast> {
  String? _shown;
  int _seq = 0;

  @override
  void didUpdateWidget(covariant OneCardToast old) {
    super.didUpdateWidget(old);
    if (widget.id != null && widget.id != old.id && widget.message != null) {
      final seq = ++_seq;
      setState(() => _shown = widget.message);
      Future.delayed(widget.duration, () {
        if (mounted && seq == _seq) setState(() => _shown = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: _shown == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Center(
                key: ValueKey(_seq),
                child: Container(
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE7FF),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59000000),
                        offset: Offset(0, 8),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _shown!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OneCardUi.sans(
                            size: 13,
                            color: const Color(0xFF1D1040),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// 색 고르기 시트(바닥 시트): 네 색 중 하나를 골라(추천 색이 미리 켜져 있음) 확정 버튼으로 바꾼다.
class OneCardColorSheet extends StatefulWidget {
  final Map<String, int> counts;
  final String initial;

  const OneCardColorSheet({
    super.key,
    required this.counts,
    required this.initial,
  });

  @override
  State<OneCardColorSheet> createState() => _OneCardColorSheetState();
}

class _OneCardColorSheetState extends State<OneCardColorSheet> {
  late String _picked = widget.initial;

  static const _glyphs = {'red': 0, 'yellow': 1, 'blue': 2, 'green': 3};

  /// 목업 순서: 로즈 · 허니 · 스카이 · 세이지.
  static const _order = ['red', 'yellow', 'blue', 'green'];

  @override
  Widget build(BuildContext context) {
    final name = OneCardColors.name(_picked);
    final n = widget.counts[_picked] ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: const BoxDecoration(
        color: OneCardUi.sheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x24FFFFFF))),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '어떤 색으로 바꿀까요?',
              textAlign: TextAlign.center,
              style: OneCardUi.sans(
                size: 19,
                weight: FontWeight.w800,
                spacing: -0.02,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '상대도 바뀐 색을 바로 봐요',
              style: OneCardUi.sans(size: 13, color: OneCardUi.sub),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                for (final color in _order) ...[
                  if (color != _order.first) const SizedBox(width: 10),
                  Expanded(
                    child: _Pick(
                      color: color,
                      glyph: _glyphs[color]!,
                      selected: color == _picked,
                      count: widget.counts[color] ?? 0,
                      onTap: () {
                        GameSfx.instance.play(GameSound.select);
                        setState(() => _picked = color);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            OneCardMainButton(
              label: '$name${_ro(name)} 바꾸기, 손에 $n장',
              style: OneCardButtonStyle.sky,
              onPressed: () => Navigator.of(context).pop(_picked),
            ),
          ],
        ),
      ),
    );
  }

  /// 받침이 있으면 "으로", 없으면 "로"(ㄹ 받침은 "로").
  static String _ro(String word) {
    if (word.isEmpty) return '로';
    final code = word.runes.last;
    if (code < 0xAC00 || code > 0xD7A3) return '로';
    final jong = (code - 0xAC00) % 28;
    return jong == 0 || jong == 8 ? '로' : '으로';
  }
}

class _Pick extends StatelessWidget {
  final String color;
  final int glyph;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _Pick({
    required this.color,
    required this.glyph,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = OneCardSuit.color(color);
    final fg = color == 'yellow' ? const Color(0xFF2E1C00) : Colors.white;
    final name = OneCardColors.name(color);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name으로 바꾸기, 손에 $count장',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: selected ? 1 : 0.42,
          child: Container(
            height: 104,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(18),
              boxShadow: selected
                  ? const [
                      BoxShadow(color: OneCardUi.sheet, spreadRadius: 3),
                      BoxShadow(color: Colors.white, spreadRadius: 5),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 26,
                        child: CustomPaint(painter: SuitPainter(glyph, fg)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: OneCardUi.sans(
                          size: 13,
                          color: fg,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Positioned(top: 8, right: 8, child: _Check()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xF2FFFFFF),
      ),
      child: CustomPaint(painter: _CheckPainter()),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate((size.width - 12) / 2, (size.height - 12) / 2);
    canvas.scale(12 / 24);
    canvas.drawPath(
      Path()
        ..moveTo(6, 12.5)
        ..lineTo(10, 16.5)
        ..lineTo(18, 7.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF211540),
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => false;
}

/// 결과 시트: 승리/패배 + 이유 + 코인 + 남은 손패 + 이번 방 전적 + 한 판 더/나가기.
class OneCardResultSheet extends StatefulWidget {
  final bool won;
  final String title;
  final String reason;
  final int stake;
  final String loserLabel;
  final List<OneCard> loserHand;
  final int myWins;
  final int oppWins;
  final int draws;
  final bool rematchWaiting;
  final Object? resultId;
  final VoidCallback? onRematch;
  final VoidCallback? onExit;

  const OneCardResultSheet({
    super.key,
    required this.won,
    required this.title,
    required this.reason,
    required this.stake,
    required this.loserLabel,
    required this.loserHand,
    required this.myWins,
    required this.oppWins,
    required this.draws,
    required this.rematchWaiting,
    this.resultId,
    this.onRematch,
    this.onExit,
  });

  @override
  State<OneCardResultSheet> createState() => _OneCardResultSheetState();
}

class _OneCardResultSheetState extends State<OneCardResultSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  static final Set<Object> _played = {};

  @override
  void initState() {
    super.initState();
    final id = widget.resultId;
    if (id == null || _played.add(id)) {
      GameSfx.instance.play(widget.won ? GameSound.win : GameSound.lose);
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    final w = widget;
    final games = w.myWins + w.oppWins + w.draws;
    final dots = math.min(games, 10);
    final shown = w.loserHand.take(4).toList();
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: curve,
          child: const ColoredBox(color: Color(0xB30A0516)),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curve),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
                      decoration: BoxDecoration(
                        color: OneCardUi.sheet,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0x1FFFFFFF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            offset: Offset(0, 30),
                            blurRadius: 60,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            w.won ? 'VICTORY' : 'DEFEAT',
                            style: OneCardUi.sans(
                              size: 12,
                              color: OneCardUi.vio2,
                              weight: FontWeight.w700,
                              spacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            w.title,
                            textAlign: TextAlign.center,
                            style: OneCardUi.headline(
                              size: w.title.length > 4 ? 40 : 54,
                              color: w.won ? OneCardUi.ink : OneCardUi.warn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            w.reason,
                            textAlign: TextAlign.center,
                            style: OneCardUi.sans(
                              size: 14,
                              color: OneCardUi.sub,
                              height: 1.4,
                            ),
                          ),
                          if (w.stake > 0) ...[
                            const SizedBox(height: 20),
                            Semantics(
                              label: w.won
                                  ? '판돈 ${w.stake}코인을 얻었어요'
                                  : '판돈 ${w.stake}코인을 잃었어요',
                              excludeSemantics: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${w.won ? '+' : '-'}${oneCardMoney(w.stake)}',
                                    style: OneCardUi.sans(
                                      size: 34,
                                      color: w.won
                                          ? Colors.white
                                          : OneCardUi.warn,
                                      weight: FontWeight.w800,
                                      spacing: -0.02,
                                      features: OneCardUi.tabular,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '코인',
                                    style: OneCardUi.sans(
                                      size: 14,
                                      color: OneCardUi.sub,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          const _Rule(),
                          _ResultRow(
                            label: w.loserLabel,
                            child: shown.isEmpty
                                ? Text(
                                    '없음',
                                    style: OneCardUi.sans(
                                      size: 14,
                                      weight: FontWeight.w700,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 32 + (shown.length - 1) * 14.0,
                                        height: 32 * kOneCardAspect,
                                        child: Stack(
                                          children: [
                                            for (
                                              var i = 0;
                                              i < shown.length;
                                              i++
                                            )
                                              Positioned(
                                                left: i * 14.0,
                                                child: OneCardFace(
                                                  card: shown[i],
                                                  width: 32,
                                                  shadows: OneCardShadows.row,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${w.loserHand.length}장',
                                        style: OneCardUi.sans(
                                          size: 14,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const _Rule(),
                          _ResultRow(
                            label: '이번 방 전적',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < dots; i++) ...[
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i < w.myWins
                                          ? OneCardUi.vio2
                                          : const Color(0x2EFFFFFF),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${w.myWins}승 ${w.oppWins}패${w.draws > 0 ? ' ${w.draws}무' : ''}',
                                  style: OneCardUi.sans(
                                    size: 14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _Rule(),
                          const SizedBox(height: 16),
                          Text(
                            '재대결은 같은 모드·판돈으로 하고, 선공이 바뀌어요',
                            textAlign: TextAlign.center,
                            style: OneCardUi.sans(
                              size: 12,
                              color: OneCardUi.sub,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (w.onRematch != null)
                            OneCardMainButton(
                              label: w.rematchWaiting
                                  ? '상대의 수락을 기다리는 중…'
                                  : '한 판 더',
                              onPressed: w.rematchWaiting ? null : w.onRematch,
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: TextButton(
                              onPressed:
                                  w.onExit ??
                                  () => Navigator.of(context).maybePop(),
                              child: Text(
                                '나가기',
                                style: OneCardUi.sans(
                                  size: 16,
                                  color: OneCardUi.sub,
                                  weight: FontWeight.w700,
                                ),
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
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: OneCardUi.line);
}

class _ResultRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _ResultRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OneCardUi.sans(size: 13, color: OneCardUi.sub),
            ),
          ),
          const SizedBox(width: 8),
          child,
        ],
      ),
    );
  }
}
