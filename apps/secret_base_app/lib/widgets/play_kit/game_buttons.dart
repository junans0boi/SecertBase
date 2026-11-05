import 'package:flutter/material.dart';

import 'game_theme.dart';

/// 금박 테두리 + 강조 그라데이션의 큰 버튼. 눌림 애니메이션과 비활성 상태가 있다.
class GamePrimaryButton extends StatefulWidget {
  final GameTheme theme;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  /// 강조색 대신 쓸 색(예: 위험 버튼).
  final Color? color;

  const GamePrimaryButton({
    super.key,
    required this.theme,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 56,
    this.expand = true,
    this.color,
  });

  @override
  State<GamePrimaryButton> createState() => _GamePrimaryButtonState();
}

class _GamePrimaryButtonState extends State<GamePrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = widget.onPressed != null;
    final base = widget.color ?? t.accent;
    final onBase = base.computeLuminance() > 0.45
        ? const Color(0xFF2A1A12)
        : Colors.white;
    final button = AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 90),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            gradient: t.goldGradient,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: base.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(base, Colors.white, 0.2)!, base],
              ),
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: onBase, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body(
                          size: widget.height >= 52 ? 17 : 15,
                          color: onBase,
                          weight: FontWeight.w800,
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
    );
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
        child: widget.expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

/// 테두리만 있는 보조 버튼.
class GameSecondaryButton extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const GameSecondaryButton({
    super.key,
    required this.theme,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: t.surface.withValues(alpha: t.dark ? 0.55 : 0.85),
          shape: StadiumBorder(
            side: BorderSide(color: t.gold.withValues(alpha: 0.7), width: 1.2),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: t.ink),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body(size: 14, weight: FontWeight.w700),
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

/// 작은 정보 칩(라운드, 남은 장수 등).
class GameChip extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final String? leading;
  final Color? color;
  final bool emphasized;

  const GameChip({
    super.key,
    required this.theme,
    required this.label,
    this.leading,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final c = color ?? t.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? c.withValues(alpha: 0.22)
            : t.surface.withValues(alpha: t.dark ? 0.6 : 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: emphasized ? 0.9 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            Text(leading!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: t.body(
              size: 12,
              color: emphasized
                  ? (t.dark ? Colors.white : Color.lerp(c, Colors.black, 0.5)!)
                  : t.ink,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 테마 표면 패널(유리/종이 느낌 + 금박 실선).
class GamePanel extends StatelessWidget {
  final GameTheme theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glow;

  /// 아래 내용이 비치지 않게 불투명하게(결과 카드·대화상자).
  final bool opaque;

  const GamePanel({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.glow,
    this.opaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: opaque
            ? Color.alphaBlend(t.surface, t.backdrop.last)
            : t.surface.withValues(alpha: t.dark ? 0.72 : 0.92),
        gradient: opaque
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    Color.alphaBlend(t.surface, t.backdrop.last),
                    Colors.white,
                    t.dark ? 0.06 : 0.4,
                  )!,
                  Color.alphaBlend(t.surface, t.backdrop.last),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glow ?? t.surfaceBorder,
          width: glow != null ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (glow ?? Colors.black).withValues(
              alpha: glow != null ? 0.35 : (t.dark ? 0.35 : 0.08),
            ),
            blurRadius: glow != null ? 22 : 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
