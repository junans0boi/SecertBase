import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';

enum V2ButtonVariant {
  /// Rose600 fill, white label. One per screen.
  primary,

  /// Rose soft fill, rose700 label. Secondary action.
  soft,

  /// Outlined, ink label.
  ghost,

  /// No fill, sub label (취소, 나중에).
  text,

  /// Err fill, white label. Destructive confirm only.
  danger,

  /// Err soft fill, err label (로그아웃 같은 덜 강한 위험).
  dangerSoft,
}

enum V2ButtonSize {
  /// 52px tall, full width by default.
  md,

  /// 44px tall, hugs content.
  sm,
}

/// The 2.0 button (ds.css `.btn`). Built on [TextButton] so focus, hover,
/// keyboard and semantics come from Material.
///
/// ```dart
/// V2Button(label: '기록 남기기', onPressed: save)
/// V2Button(label: '나중에', variant: V2ButtonVariant.text, onPressed: close)
/// V2Button(label: '저장', size: V2ButtonSize.sm, loading: saving, onPressed: save)
/// V2Button(label: '탈퇴하기', variant: V2ButtonVariant.danger, onPressed: leave)
/// ```
/// `onPressed: null` renders the disabled (`.off`) look.
class V2Button extends StatelessWidget {
  const V2Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = V2ButtonVariant.primary,
    this.size = V2ButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final V2ButtonVariant variant;
  final V2ButtonSize size;

  /// Leading icon (`V2Icons.*`).
  final IconData? icon;

  /// Shows a spinner and ignores taps (label stays for screen readers).
  final bool loading;

  /// Defaults to true for [V2ButtonSize.md], false for sm.
  final bool? fullWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final sm = size == V2ButtonSize.sm;
    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      V2ButtonVariant.primary => (p.primary, p.onPrimary, null),
      V2ButtonVariant.soft => (p.primarySoft, p.onPrimarySoft, null),
      V2ButtonVariant.ghost => (
        Colors.transparent,
        p.ink,
        BorderSide(color: p.line2, width: 1.5),
      ),
      V2ButtonVariant.text => (Colors.transparent, p.sub, null),
      V2ButtonVariant.danger => (
        p.err,
        p.dark ? V2DarkColors.bg : Colors.white,
        null,
      ),
      V2ButtonVariant.dangerSoft => (
        p.errSoft,
        p.dark ? V2DarkColors.err : V2Colors.errText,
        null,
      ),
    };
    final filled =
        variant != V2ButtonVariant.text && variant != V2ButtonVariant.ghost;
    final height = sm || variant == V2ButtonVariant.text ? 44.0 : 52.0;
    final textStyle = (sm ? V2Text.buttonSm : V2Text.button).copyWith(
      fontWeight: variant == V2ButtonVariant.text ? FontWeight.w600 : null,
    );
    final enabled = onPressed != null && !loading;

    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(44, height)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 64)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: sm ? 18 : 20),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            sm ? V2Radius.ctl : V2Radius.button,
          ),
        ),
      ),
      textStyle: WidgetStatePropertyAll(textStyle),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled) && !loading) {
          return filled ? p.soft2 : Colors.transparent;
        }
        return bg;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled) && !loading) return p.disabled;
        return fg;
      }),
      overlayColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.pressed)) return fg.withValues(alpha: 0.14);
        if (s.contains(WidgetState.hovered)) return fg.withValues(alpha: 0.07);
        if (s.contains(WidgetState.focused)) return fg.withValues(alpha: 0.12);
        return null;
      }),
      side: side == null
          ? null
          : WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.disabled)
                  ? side.copyWith(color: p.line)
                  : side,
            ),
      elevation: const WidgetStatePropertyAll(0),
    );

    final child = loading
        ? SizedBox.square(
            dimension: sm ? 18 : 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: fg,
              backgroundColor: Colors.transparent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: sm ? 18 : 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    Widget button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: loading
          ? Semantics(label: semanticLabel ?? label, child: child)
          : (semanticLabel == null
                ? child
                : Semantics(
                    label: semanticLabel,
                    excludeSemantics: true,
                    child: child,
                  )),
    );
    if (fullWidth ?? !sm) {
      button = SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
