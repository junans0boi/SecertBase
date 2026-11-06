/// "모던 클래식" 게임 화면 공용 부품(블랙잭·도둑잡기 시안에서 뽑았다).
///
/// 헤어라인 테두리 + 단색 면 + 한 겹 그림자만 쓰고, 번쩍이는 그라데이션·굵은 외곽선은 쓰지 않는다.
/// 글자는 [GameTheme.body](Noto Sans KR)와 [GameTheme.display](Gowun Batang)만 쓴다.
/// `play_kit.dart`에는 내보내지 않는다 — 쓰는 곳에서 직접 import 한다.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/game_sfx/game_sfx.dart';
import '../game_menu.dart';
import 'game_hud.dart';
import 'game_theme.dart';

/// 시안 공통 색 규칙.
extension ModTokens on GameTheme {
  /// 헤어라인 테두리색.
  Color get hair => surfaceBorder;

  /// 어두운 테마는 바탕을 살짝 눌러 주고, 밝은 테마는 흰 종이 면을 쓴다.
  Color get plate => dark ? Colors.black.withValues(alpha: 0.16) : surface;

  /// 강조색 위에 올리는 글자색.
  Color get onAccent =>
      accent.computeLuminance() > 0.45 ? const Color(0xFF2A1E05) : Colors.white;

  /// 졌을 때/버스트 표시색.
  Color get lose => const Color(0xFFF08C84);

  /// 이름 첫 글자를 아바타에 쓴다.
  static String initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : String.fromCharCode(t.runes.first);
  }
}

/// 테마 바탕. 어두운 라운지는 가운데가 밝은 타원 그라데이션, 밝은 동화책은 크림 종이 + 옅은 점 질감.
enum ModBackdropKind { felt, paper }

class ModBackdrop extends StatelessWidget {
  final GameTheme theme;
  final ModBackdropKind kind;
  final Widget child;

  const ModBackdrop({
    super.key,
    required this.theme,
    required this.kind,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _ModBackdropPainter(theme, kind)),
        ),
        child,
      ],
    );
  }
}

class _ModBackdropPainter extends CustomPainter {
  final GameTheme theme;
  final ModBackdropKind kind;

  _ModBackdropPainter(this.theme, this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = theme.backdrop;
    if (kind == ModBackdropKind.felt) {
      // CSS radial-gradient(120% 62% at 50% 36%, a 0, b 52%, c 100%).
      final m = Matrix4.identity()
        ..translateByDouble(size.width * 0.5, size.height * 0.36, 0, 1)
        ..scaleByDouble(size.width * 1.2, size.height * 0.62, 1, 1);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [c[0], c[1], c[2]],
            const [0, 0.52, 1],
            TileMode.clamp,
            m.storage,
          ),
      );
      return;
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
          c[0],
          c[1],
        ]),
    );
    // 16px 격자 한가운데에 반지름 1px 점.
    final dots = <Offset>[];
    for (var y = 8.0; y < size.height; y += 16) {
      for (var x = 8.0; x < size.width; x += 16) {
        dots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      dots,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.06)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ModBackdropPainter old) =>
      old.theme != theme || old.kind != kind;
}

/// 상단 바: 1fr · 제목 · 1fr 그리드라 제목이 늘 화면 정가운데에 선다.
class ModTopBar extends StatelessWidget {
  final GameTheme theme;
  final String title;
  final String gameType;
  final VoidCallback? onBack;
  final VoidCallback? onHelp;
  final bool showSound;
  final bool canRestart;
  final bool restartWaiting;
  final VoidCallback? onRequestRestart;

  /// 게임 메뉴(⋮: 재대결 요청·나가기). 로비에서는 끈다.
  final bool showMenu;

  const ModTopBar({
    super.key,
    required this.theme,
    required this.title,
    required this.gameType,
    this.onBack,
    this.onHelp,
    this.showSound = true,
    this.canRestart = false,
    this.restartWaiting = false,
    this.onRequestRestart,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ModIconButton(
                  theme: t,
                  icon: Icons.chevron_left_rounded,
                  size: 30,
                  tooltip: '게임 나가기',
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Text(
              title,
              maxLines: 1,
              style: t.display(size: 17).copyWith(letterSpacing: 0.3),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onHelp != null)
                      ModIconButton(
                        theme: t,
                        icon: Icons.help_outline_rounded,
                        tooltip: '규칙 보기',
                        onPressed: onHelp,
                      ),
                    if (showSound) ModMuteButton(theme: t),
                    if (showMenu)
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: GameMenuButton(
                          hasRestart: canRestart,
                          restartWaiting: restartWaiting,
                          onRequestRestart: onRequestRestart,
                          iconColor: t.ink.withValues(alpha: 0.82),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44px 터치 영역의 가는 선 아이콘 버튼.
class ModIconButton extends StatelessWidget {
  final GameTheme theme;
  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback? onPressed;

  const ModIconButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: theme.ink.withValues(alpha: 0.82)),
      ),
    );
  }
}

class ModMuteButton extends StatefulWidget {
  final GameTheme theme;

  const ModMuteButton({super.key, required this.theme});

  @override
  State<ModMuteButton> createState() => _ModMuteButtonState();
}

class _ModMuteButtonState extends State<ModMuteButton> {
  @override
  Widget build(BuildContext context) {
    final sfx = GameSfx.instance;
    return ModIconButton(
      theme: widget.theme,
      icon: sfx.muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
      tooltip: sfx.muted ? '소리 켜기' : '소리 끄기',
      onPressed: () async {
        await sfx.setMuted(!sfx.muted);
        if (!sfx.muted) sfx.play(GameSound.tap);
        if (mounted) setState(() {});
      },
    );
  }
}

enum ModButtonKind { filled, outline }

/// 높이 56 · 반경 18 단색 버튼. 보조 설명 한 줄([sub])을 달 수 있다.
class ModButton extends StatefulWidget {
  final GameTheme theme;
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final ModButtonKind kind;
  final double height;

  const ModButton({
    super.key,
    required this.theme,
    required this.label,
    this.sub,
    this.onPressed,
    this.kind = ModButtonKind.filled,
    this.height = 56,
  });

  @override
  State<ModButton> createState() => _ModButtonState();
}

class _ModButtonState extends State<ModButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = widget.onPressed != null;
    final filled = widget.kind == ModButtonKind.filled;
    final Color bg;
    final Color fg;
    Border? border;
    if (filled && enabled) {
      bg = t.accent;
      fg = t.onAccent;
    } else if (filled) {
      bg = t.dark
          ? Colors.white.withValues(alpha: 0.10)
          : t.ink.withValues(alpha: 0.08);
      fg = t.subInk;
    } else {
      bg = Colors.transparent;
      fg = t.ink;
      border = Border.all(color: t.ink.withValues(alpha: 0.34));
    }
    final body = AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: const Duration(milliseconds: 90),
      child: Opacity(
        opacity: !enabled && !filled ? 0.45 : 1,
        child: Container(
          height: widget.height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  style: t.body(
                    size: 17,
                    color: fg,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (widget.sub != null)
                Text(
                  widget.sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(
                    size: 12,
                    color: fg.withValues(alpha: 0.78),
                    weight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.sub == null
          ? widget.label
          : '${widget.label}, ${widget.sub}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: body,
      ),
    );
  }
}

/// 이름 첫 글자를 담은 원형 아바타.
class ModAvatar extends StatelessWidget {
  final GameTheme theme;
  final String name;
  final bool mine;
  final double size;

  const ModAvatar({
    super.key,
    required this.theme,
    required this.name,
    required this.mine,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mine ? t.me : t.opponent,
      ),
      child: Text(
        ModTokens.initial(name),
        style: t.display(
          size: size >= 44 ? 16 : (size >= 40 ? 15 : 14),
          color: t.dark ? const Color(0xFF06302A) : Colors.white,
        ),
      ),
    );
  }
}

/// 플레이어 캡슐: 아바타 + 이름 + 한 줄 상태. [active]면 강조 테두리와 옅은 링.
class ModCapsule extends StatelessWidget {
  final GameTheme theme;
  final String name;
  final String? sub;
  final bool mine;
  final bool active;
  final double height;
  final double minWidth;

  const ModCapsule({
    super.key,
    required this.theme,
    required this.name,
    required this.mine,
    this.sub,
    this.active = false,
    this.height = 56,
    this.minWidth = 172,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final avatar = height >= 56 ? 40.0 : 36.0;
    final pad = (height - avatar) / 2;
    final capsule = Container(
      height: height,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: EdgeInsets.fromLTRB(pad, 0, height >= 56 ? 18 : 20, 0),
      decoration: BoxDecoration(
        color: t.dark ? Colors.black.withValues(alpha: 0.18) : t.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: active
              ? t.accent
              : (t.dark ? t.ink.withValues(alpha: 0.16) : t.hair),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModAvatar(theme: t, name: name, mine: mine, size: avatar),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(
                    size: height >= 56 ? 15 : 14.5,
                    weight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty)
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(
                      size: 12.5,
                      color: active ? (t.dark ? t.gold : t.accent) : t.subInk,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: '$name${active ? ', 차례' : ''}${sub != null ? ', $sub' : ''}',
      excludeSemantics: true,
      child: active
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                // 차례 링: 캡슐 바깥으로 3px 번지는 옅은 테두리(안쪽 배경에는 번지지 않는다).
                Positioned(
                  left: -3,
                  right: -3,
                  top: -3,
                  bottom: -3,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2 + 3),
                        border: Border.all(
                          color: t.accent.withValues(
                            alpha: t.dark ? 0.14 : 0.12,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
                capsule,
              ],
            )
          : capsule,
    );
  }
}

/// 남은 시간 링. 마지막 5초는 붉게 바뀌고 초마다 틱 소리.
class ModTimerRing extends StatefulWidget {
  final GameTheme theme;
  final GameDeadline? deadline;
  final double size;
  final double stroke;
  final double numberSize;
  final bool tickSound;

  const ModTimerRing({
    super.key,
    required this.theme,
    required this.deadline,
    this.size = 56,
    this.stroke = 3,
    this.numberSize = 19,
    this.tickSound = false,
  });

  @override
  State<ModTimerRing> createState() => _ModTimerRingState();
}

class _ModTimerRingState extends State<ModTimerRing> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final d = widget.deadline;
      if (d != null && widget.tickSound) {
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
    final t = widget.theme;
    final d = widget.deadline;
    final total = d?.total.inMilliseconds ?? 1;
    final left = d?.remaining().inMilliseconds ?? 0;
    final frac = d == null ? 0.0 : (left / math.max(1, total)).clamp(0.0, 1.0);
    final secs = (left / 1000).ceil();
    final urgent = d != null && secs <= 5;
    final color = urgent ? const Color(0xFFFF5A5F) : t.accent;
    return Semantics(
      label: d == null ? '시간 제한 없음' : '남은 시간 $secs초',
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ModRingPainter(
            frac: frac,
            color: color,
            track: t.dark
                ? t.ink.withValues(alpha: 0.14)
                : t.ink.withValues(alpha: 0.10),
            stroke: widget.stroke,
          ),
          child: Center(
            child: Text(
              d == null ? '' : '$secs',
              style: t.display(
                size: widget.numberSize,
                color: urgent ? color : t.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModRingPainter extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;
  final double stroke;

  _ModRingPainter({
    required this.frac,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ModRingPainter old) =>
      old.frac != frac || old.color != color || old.track != track;
}

/// 조작부를 가리지 않는 짧은 안내. [id]가 바뀌면 [message]를 잠깐 보여 준다.
class ModToast extends StatefulWidget {
  final GameTheme theme;
  final Object? id;
  final String? message;
  final Duration duration;

  const ModToast({
    super.key,
    required this.theme,
    required this.id,
    required this.message,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<ModToast> createState() => _ModToastState();
}

class _ModToastState extends State<ModToast> {
  String? _shown;
  int _seq = 0;

  @override
  void didUpdateWidget(covariant ModToast old) {
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
    final t = widget.theme;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _shown == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Container(
                key: ValueKey(_seq),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: t.dark
                      ? const Color(0xE6051F1B)
                      : t.ink.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: t.dark ? t.accent : Colors.transparent,
                  ),
                ),
                child: Text(
                  _shown!,
                  textAlign: TextAlign.center,
                  style: t.body(
                    size: 14,
                    color: t.dark ? t.gold : Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

/// "내 차례" 같은 짧은 알림 알약. [id]가 바뀔 때마다 한 번 재생하고,
/// 처음 그려질 때의 id는 재생하지 않는다.
class ModTurnFlash extends StatefulWidget {
  final GameTheme theme;
  final Object? id;
  final String text;
  final String? sub;
  final Alignment alignment;
  final Duration hold;

  const ModTurnFlash({
    super.key,
    required this.theme,
    required this.id,
    required this.text,
    this.sub,
    this.alignment = Alignment.center,
    this.hold = const Duration(milliseconds: 1000),
  });

  @override
  State<ModTurnFlash> createState() => _ModTurnFlashState();
}

class _ModTurnFlashState extends State<ModTurnFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  String _text = '';
  String? _sub;

  @override
  void didUpdateWidget(covariant ModTurnFlash old) {
    super.didUpdateWidget(old);
    if (widget.id != null && widget.id != old.id) {
      _text = widget.text;
      _sub = widget.sub;
      _c.duration = widget.hold + const Duration(milliseconds: 500);
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
          final total = _c.duration!.inMilliseconds.toDouble();
          final ms = _c.value * total;
          const inMs = 220.0, outMs = 280.0;
          double opacity = 1, scale = 1;
          if (ms < inMs) {
            final k = Curves.easeOutCubic.transform(ms / inMs);
            opacity = k;
            scale = 0.92 + 0.08 * k;
          } else if (ms > total - outMs) {
            opacity =
                1 - Curves.easeIn.transform((ms - (total - outMs)) / outMs);
          }
          return Align(
            alignment: widget.alignment,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _text,
                        style: t.display(size: 24, color: t.onAccent),
                      ),
                      if (_sub != null)
                        Text(
                          _sub!,
                          style: t.body(
                            size: 12.5,
                            color: t.onAccent.withValues(alpha: 0.82),
                            weight: FontWeight.w500,
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

/// 규칙 요약 대화상자.
Future<void> showModHowTo(
  BuildContext context, {
  required GameTheme theme,
  required String title,
  required List<String> lines,
}) {
  final t = theme;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: t.dark ? t.backdrop[1] : t.backdrop[0],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: t.dark ? t.gold.withValues(alpha: 0.38) : t.hair,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: t.display(size: 22),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: t.dark ? t.gold : t.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                line,
                                style: t.body(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  height: 1.5,
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
            const SizedBox(height: 8),
            ModButton(
              theme: t,
              label: '알겠어요',
              height: 52,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

final Set<String> _modHowToRequested = {};

/// 테스트용: 이번 실행에서 띄운 기록을 지운다.
@visibleForTesting
void resetModHowToRequests() => _modHowToRequested.clear();

/// 처음 한 번만 규칙을 띄운다(기기에 저장).
Future<void> showModHowToOnce(
  BuildContext context, {
  required String prefKey,
  required GameTheme theme,
  required String title,
  required List<String> lines,
}) async {
  if (!_modHowToRequested.add(prefKey)) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefKey) == true) return;
    await prefs.setBool(prefKey, true);
  } catch (_) {
    return;
  }
  if (!context.mounted) return;
  await showModHowTo(context, theme: theme, title: title, lines: lines);
}

/// 이번 방 전적 알약: "이번 방 전적  3 : 2".
class ModSeriesPill extends StatelessWidget {
  final GameTheme theme;
  final Map<String, dynamic>? series;
  final String? me;

  const ModSeriesPill({
    super.key,
    required this.theme,
    required this.series,
    required this.me,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final wins = (series?['wins'] as Map?) ?? const {};
    int mine = 0, theirs = 0;
    wins.forEach((k, v) {
      final n = (v as num?)?.toInt() ?? 0;
      if (k == me) {
        mine = n;
      } else {
        theirs += n;
      }
    });
    final draws = (series?['draws'] as num?)?.toInt() ?? 0;
    return Semantics(
      label: '이번 방 전적 나 $mine승, 상대 $theirs승, 무승부 $draws',
      excludeSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: t.dark ? null : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.hair),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '이번 방 전적',
              style: t.body(size: 13, color: t.subInk, weight: FontWeight.w500),
            ),
            const SizedBox(width: 10),
            Text('$mine : $theirs', style: t.display(size: 20)),
            if (draws > 0) ...[
              const SizedBox(width: 8),
              Text(
                '무 $draws',
                style: t.body(
                  size: 12,
                  color: t.subInk,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 둥근 테두리 안에 줄이 나뉘는 표 껍데기(규칙 목록·기록 표).
class ModRowsCard extends StatelessWidget {
  final GameTheme theme;
  final List<Widget> rows;
  final Widget? header;

  const ModRowsCard({
    super.key,
    required this.theme,
    required this.rows,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final divider = Border(
      top: BorderSide(color: t.dark ? t.gold.withValues(alpha: 0.16) : t.hair),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.plate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.hair),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?header,
          for (var i = 0; i < rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: (i == 0 && header == null) ? null : divider,
              ),
              child: rows[i],
            ),
        ],
      ),
    );
  }
}
