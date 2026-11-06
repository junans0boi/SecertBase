import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'yut_models.dart';
import 'yut_palette.dart';

/// 두툼한 버튼: 단색 면 + 아래 5px 진한 가장자리. 누르면 가장자리만큼 내려앉는다.
/// 모션을 줄이는 설정이면 눌림 애니메이션 없이 바로 바뀐다.
class YutChunkyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  /// true면 흰 바탕의 조용한 보조 버튼.
  final bool ghost;
  final bool busy;

  const YutChunkyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 56,
    this.ghost = false,
    this.busy = false,
  });

  @override
  State<YutChunkyButton> createState() => _YutChunkyButtonState();
}

class _YutChunkyButtonState extends State<YutChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    final enabled = widget.onPressed != null;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Color face;
    final Color edge;
    final Color text;
    if (!enabled) {
      face = p.btnDisabled;
      edge = p.btnDisabledEdge;
      text = p.sub;
    } else if (widget.ghost) {
      face = p.panel;
      edge = p.panelEdge;
      text = p.ink;
    } else {
      face = p.acc;
      edge = p.acc2;
      text = p.onAcc;
    }
    const lip = 5.0;
    final dy = _down && enabled ? lip - 1 : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: SizedBox(
          height: widget.height + lip,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: lip,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: edge,
                    borderRadius: BorderRadius.circular(widget.height / 2.4),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: dy,
                height: widget.height,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: face,
                    borderRadius: BorderRadius.circular(widget.height / 2.4),
                    boxShadow: enabled && !widget.ghost
                        ? [
                            BoxShadow(
                              color: p.glow,
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.busy)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: text,
                            ),
                          ),
                        )
                      else if (widget.icon != null) ...[
                        Icon(widget.icon, size: 22, color: text),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: p.display(size: 21, color: text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 둥근 알약(내 차례·효과 N·등급 표시). [filled]이면 포인트색 바탕.
class YutPill extends StatelessWidget {
  final String text;
  final bool filled;
  final Color? color;
  final double size;
  final Widget? leading;

  const YutPill(
    this.text, {
    super.key,
    this.filled = false,
    this.color,
    this.size = 12,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    final base = color ?? p.acc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: filled ? base : base.withValues(alpha: p.night ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(99),
        boxShadow: filled
            ? [BoxShadow(color: p.acc2, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 3)],
          Text(
            text,
            style: p.body(
              size: size,
              weight: FontWeight.w800,
              color: filled ? p.onAcc : p.accText,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 유리 같은 둥근 버튼(뒤로·도움말·소리). 터치 영역은 44px.
class YutRoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const YutRoundButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.glass,
            border: Border.all(color: p.glassEdge),
            boxShadow: [
              BoxShadow(color: p.panelEdge, offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, size: 21, color: p.ink),
        ),
      ),
    );
  }
}

/// 위쪽 바: 뒤로, 제목, 도움말·소리·메뉴(재대결 요청 포함).
class YutTopBar extends StatefulWidget {
  final String title;
  final bool canRestart;
  final bool restartWaiting;
  final VoidCallback? onRequestRestart;
  final VoidCallback? onHelp;

  const YutTopBar({
    super.key,
    required this.title,
    this.canRestart = false,
    this.restartWaiting = false,
    this.onRequestRestart,
    this.onHelp,
  });

  @override
  State<YutTopBar> createState() => _YutTopBarState();
}

class _YutTopBarState extends State<YutTopBar> {
  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            YutRoundButton(
              icon: Icons.arrow_back_ios_new_rounded,
              label: '게임 나가기',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            // 제목은 양쪽 버튼 사이 남는 자리의 가운데(좁은 폭에서도 버튼과 겹치지 않는다).
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    style: p
                        .display(size: 24)
                        .copyWith(
                          shadows: [
                            Shadow(
                              color: p.night
                                  ? const Color(0x80FFBE64)
                                  : Colors.white.withValues(alpha: 0.6),
                              blurRadius: p.night ? 14 : 0,
                              offset: p.night
                                  ? Offset.zero
                                  : const Offset(0, 2),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ),
            if (widget.onHelp != null)
              YutRoundButton(
                icon: Icons.help_outline_rounded,
                label: '규칙 보기',
                onTap: widget.onHelp,
              ),
            const SizedBox(width: 8),
            YutRoundButton(
              icon: GameSfx.instance.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              label: GameSfx.instance.muted ? '소리 켜기' : '소리 끄기',
              onTap: () async {
                await GameSfx.instance.setMuted(!GameSfx.instance.muted);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(width: 4),
            GameMenuButton(
              hasRestart: widget.canRestart,
              restartWaiting: widget.restartWaiting,
              onRequestRestart: widget.onRequestRestart,
              iconColor: p.ink,
            ),
          ],
        ),
      ),
    );
  }
}

/// 남은 시간 링: 굵은 숫자 + 주황(밤은 호박색) 호. 마지막 5초는 붉게, 내 차례면 초마다 틱.
class YutTimerRing extends StatefulWidget {
  final GameDeadline? deadline;
  final bool tick;
  final double size;

  const YutTimerRing({
    super.key,
    required this.deadline,
    required this.tick,
    this.size = 50,
  });

  @override
  State<YutTimerRing> createState() => _YutTimerRingState();
}

class _YutTimerRingState extends State<YutTimerRing> {
  Timer? _timer;
  int _last = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final d = widget.deadline;
      if (!mounted || d == null) return;
      final secs = d.remaining().inSeconds;
      if (widget.tick && secs <= 5 && secs >= 1 && secs != _last) {
        GameSfx.instance.play(GameSound.tick);
      }
      _last = secs;
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
    final p = YutPalette.of(context);
    final d = widget.deadline;
    if (d == null) return SizedBox(width: widget.size, height: widget.size);
    final left = d.remaining().inMilliseconds;
    final frac = (left / math.max(1, d.total.inMilliseconds)).clamp(0.0, 1.0);
    final urgent = left <= 5000;
    final color = urgent ? const Color(0xFFE5483B) : p.acc;
    return Semantics(
      label: '남은 시간 ${(left / 1000).ceil()}초',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  frac,
                  color,
                  p.ink.withValues(alpha: 0.1),
                ),
              ),
            ),
            Text(
              '${(left / 1000).ceil()}',
              style: p.display(
                size: widget.size * 0.4,
                color: urgent ? color : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;

  _RingPainter(this.frac, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(3);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = track,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.frac != frac || old.color != color;
}

/// 캐릭터 상반신(머리~허리). 카드 가장자리를 넘어 솟아오르게 놓는다.
class YutBust extends StatelessWidget {
  final String character;
  final double height;

  const YutBust({super.key, required this.character, required this.height});

  @override
  Widget build(BuildContext context) {
    final aspect = yutCharacterAspect(character);
    // 전신 그림의 위쪽 62%만 보이게 자른다.
    final fullH = height / 0.62;
    return SizedBox(
      height: height,
      width: fullH * aspect,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: fullH,
          maxHeight: fullH,
          minWidth: fullH * aspect,
          maxWidth: fullH * aspect,
          child: Image.asset(
            yutCharacterAsset(character),
            height: fullH,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 판 위쪽에 잠깐 떴다 사라지는 알약 안내(상대 카드를 가리지 않는다).
class YutToastPill extends StatelessWidget {
  final Object? id;
  final String? text;
  final bool strong;

  const YutToastPill({
    super.key,
    required this.id,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: text == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Container(
              key: ValueKey(id),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: strong ? p.acc : (p.night ? p.panel : Colors.white),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: strong ? p.acc2 : p.panelEdge,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.display(
                  size: 17,
                  color: strong ? p.onAcc : p.ink,
                  height: 1.2,
                ),
              ),
            ),
    );
  }
}

/// 아이템 효과가 발동했을 때 뜨는 작은 알약.
class YutEffectPill extends StatelessWidget {
  final String message;

  const YutEffectPill({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: p.night ? p.panel : Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: p.panelEdge, offset: const Offset(0, 2))],
      ),
      child: Text(message, style: p.body(size: 12.5, weight: FontWeight.w800)),
    );
  }
}
