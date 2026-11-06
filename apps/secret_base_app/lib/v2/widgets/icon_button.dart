import 'package:flutter/material.dart';

import '../theme.dart';
import 'badge.dart';

/// 44×44 round icon button (ds.css `.ib`). [tooltip] is required: it is the
/// screen-reader label, in Korean (예: '알림', '뒤로 가기').
///
/// ```dart
/// V2IconButton(icon: V2Icons.bell, tooltip: '알림', dot: true, onPressed: open)
/// ```
class V2IconButton extends StatelessWidget {
  const V2IconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.dot = false,
    this.color,
    this.size = 24,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Soft round background (`.ib.fill`).
  final bool filled;

  /// Small rose unread dot at the top-right.
  final bool dot;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final fg = onPressed == null ? p.disabled : (color ?? p.ink);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: filled ? p.soft : Colors.transparent,
        foregroundColor: fg,
        disabledForegroundColor: p.disabled,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: dot
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: fg),
                Positioned(
                  top: -1,
                  right: -1,
                  child: V2Badge.dot(borderColor: filled ? p.soft : p.bg),
                ),
              ],
            )
          : Icon(icon, color: fg),
    );
  }
}
