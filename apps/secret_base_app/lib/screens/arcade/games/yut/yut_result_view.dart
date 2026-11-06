import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'yut_figures.dart';
import 'yut_palette.dart';
import 'yut_ui.dart';

/// 결과 화면: 햇살 줄기 + 큰 글자("승리") + 하얀 받침 위 캐릭터 + 정산 카드 + 한 판 더.
/// 글자는 도현체(Do Hyeon): "승리"가 다른 글자로 읽히지 않는 또렷한 서체다.
class YutResultView extends StatefulWidget {
  final YutPalette palette;
  final bool won;
  final bool forfeit;
  final String title;
  final String who;
  final String reason;
  final YutFigureSpec winnerSpec;
  final Color winnerTeam;
  final int stake;
  final int shownStake;
  final int shownBonus;
  final bool settlementFailed;
  final String? skinName;
  final String finishedLine;
  final Widget? series;
  final Object resultId;
  final bool rematchWaiting;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  const YutResultView({
    super.key,
    required this.palette,
    required this.won,
    required this.forfeit,
    required this.title,
    required this.who,
    required this.reason,
    required this.winnerSpec,
    required this.winnerTeam,
    required this.stake,
    required this.shownStake,
    required this.shownBonus,
    required this.settlementFailed,
    required this.skinName,
    required this.finishedLine,
    required this.series,
    required this.resultId,
    required this.rematchWaiting,
    required this.onRematch,
    required this.onExit,
  });

  @override
  State<YutResultView> createState() => _YutResultViewState();
}

class _YutResultViewState extends State<YutResultView>
    with SingleTickerProviderStateMixin {
  static final Set<Object> _played = {};
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void initState() {
    super.initState();
    if (_played.add(widget.resultId)) {
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
    final p = widget.palette;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);
    final pop = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return YutPaletteScope(
      palette: p,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 결과는 판 위에 얹지 않고 하늘(밤은 달밤) 배경 전체로 보여 준다.
          FadeTransition(
            opacity: curve,
            child: GameBackdrop(
              theme: p.theme,
              frame: false,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: curve,
                child: CustomPaint(painter: _RayPainter(p.ray)),
              ),
            ),
          ),
          if (widget.won)
            ConfettiBurst(
              trigger: widget.resultId,
              colors: [p.acc, p.opp, p.yellow, Colors.white, p.accText],
              count: 46,
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: reduce
                                  ? const AlwaysStoppedAnimation(1.0)
                                  : Tween(begin: 1.5, end: 1.0).animate(pop),
                              child: FadeTransition(
                                opacity: curve,
                                child: _BigWord(
                                  text: widget.title,
                                  p: p,
                                  won: widget.won,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _Pedestal(
                              p: p,
                              child: YutFigure(
                                height: 150,
                                team: widget.winnerTeam,
                                spec: widget.winnerSpec,
                                badge: false,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                YutPill(widget.who, filled: true, size: 13),
                                Text(
                                  widget.reason,
                                  textAlign: TextAlign.center,
                                  style: p.body(
                                    size: 14,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _Receipt(view: widget, p: p),
                            if (widget.series != null) ...[
                              const SizedBox(height: 10),
                              widget.series!,
                            ],
                            const SizedBox(height: 16),
                            YutChunkyButton(
                              label: widget.rematchWaiting
                                  ? '상대의 수락을 기다리는 중…'
                                  : '한 판 더',
                              icon: widget.rematchWaiting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.replay_rounded,
                              onPressed: widget.rematchWaiting
                                  ? null
                                  : widget.onRematch,
                            ),
                            const SizedBox(height: 8),
                            YutChunkyButton(
                              label: '나가기',
                              ghost: true,
                              height: 50,
                              onPressed: widget.onExit,
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
      ),
    );
  }
}

class _BigWord extends StatelessWidget {
  final String text;
  final YutPalette p;
  final bool won;

  const _BigWord({required this.text, required this.p, required this.won});

  @override
  Widget build(BuildContext context) {
    final color = won ? p.acc : p.ink;
    final style = p.display(size: 84, color: color, height: 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        // 아래로 떨어지는 단단한 그림자(글자 두께).
        Transform.translate(
          offset: const Offset(0, 6),
          child: Text(
            text,
            style: style.copyWith(color: won ? p.acc2 : p.panelEdge),
          ),
        ),
        Text(
          text,
          style: style.copyWith(
            shadows: [Shadow(color: p.glow, blurRadius: 18)],
          ),
        ),
      ],
    );
  }
}

/// 흰 타원 받침(옆면 두께 포함) 위에 선 캐릭터.
class _Pedestal extends StatelessWidget {
  final YutPalette p;
  final Widget child;

  const _Pedestal({required this.p, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 190,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 260,
              height: 50,
              decoration: BoxDecoration(
                color: p.plateSide,
                borderRadius: BorderRadius.all(Radius.elliptical(260, 50)),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 260,
              height: 50,
              decoration: BoxDecoration(
                color: p.plate,
                borderRadius: BorderRadius.all(Radius.elliptical(260, 50)),
                boxShadow: [BoxShadow(color: p.shadow, blurRadius: 18)],
              ),
            ),
          ),
          Positioned(bottom: 22, child: child),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  final YutResultView view;
  final YutPalette p;

  const _Receipt({required this.view, required this.p});

  Widget _row(String l, Widget r, {bool bold = false, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: p.sub.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              style: p.body(
                size: bold ? 15 : 13.5,
                color: bold ? p.ink : p.sub,
                weight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          r,
        ],
      ),
    );
  }

  Widget _coins(int n, {bool big = false, String sign = ''}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (sign.isNotEmpty)
        Text(
          sign,
          style: p.display(size: big ? 28 : 16, color: big ? p.accText : p.sub),
        ),
      Container(
        width: big ? 22 : 15,
        height: big ? 22 : 15,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFE07A),
          border: Border.all(
            color: const Color(0xFFFFC83A),
            width: big ? 5 : 3.5,
          ),
        ),
      ),
      Text(
        '$n',
        style: big
            ? p.display(size: 34, color: p.accText, height: 1.0)
            : p.body(size: 14, weight: FontWeight.w800),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (view.stake > 0) {
      if (view.settlementFailed) {
        rows.add(
          _row(
            '코인 정산',
            Text(
              '지연되고 있어요',
              style: p.body(size: 13.5, weight: FontWeight.w800),
            ),
          ),
        );
      } else {
        rows.add(_row('판돈', _coins(view.shownStake)));
        if (view.won && view.shownBonus > 0) {
          rows.add(
            _row(
              '${view.skinName ?? '윷 스킨'} 효과',
              _coins(view.shownBonus, sign: '+'),
            ),
          );
        }
        final total = view.shownStake + (view.won ? view.shownBonus : 0);
        rows.add(
          _row(
            view.won ? '이긴 코인' : '잃은 코인',
            _coins(total, big: true, sign: view.won ? '+' : '−'),
            bold: true,
          ),
        );
      }
    }
    rows.add(
      _row(
        '도착한 말',
        Text(
          view.finishedLine,
          style: p.body(size: 14, weight: FontWeight.w800),
        ),
        last: true,
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      decoration: BoxDecoration(
        color: p.night ? p.panel : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: p.panelEdge, offset: const Offset(0, 5))],
      ),
      child: Column(children: rows),
    );
  }
}

class _RayPainter extends CustomPainter {
  final Color color;

  _RayPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.34);
    final r = size.longestSide;
    const n = 16;
    for (int i = 0; i < n; i += 2) {
      final a0 = i / n * math.pi * 2;
      final a1 = (i + 1) / n * math.pi * 2;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r)
          ..lineTo(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r)
          ..close(),
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r * 0.7)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) => old.color != color;
}
