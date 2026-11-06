import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';

/// Pill chip (ds.css `.chip`): 32px visual, 44px hit area when tappable.
///
/// * Filter chip: `V2Chip(label: '가 본 곳', selected: f == 1, onTap: () => pick(1))`
///   (selected = ink fill).
/// * Status chip: `V2Chip(label: '연결됨', tone: V2Tone.ok)` (not tappable).
/// * With icon: `V2Chip(label: '도움이 필요하면', icon: V2Icons.phone, tone: V2Tone.rose, onTap: help)`
class V2Chip extends StatelessWidget {
  const V2Chip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.tone = V2Tone.neutral,
    this.icon,
  });

  final String label;

  /// Only meaningful for tappable filter chips.
  final bool selected;
  final VoidCallback? onTap;
  final V2Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2ToneColors.of(tone);
    final Color bg;
    final Color fg;
    if (selected) {
      bg = p.ink;
      fg = p.bg;
    } else if (tone == V2Tone.neutral || p.dark) {
      bg = p.soft;
      fg = p.sub;
    } else {
      bg = t.soft;
      fg = t.text;
    }

    final pill = AnimatedContainer(
      duration: V2Motion.of(context, V2Motion.fast),
      height: 32,
      padding: EdgeInsets.only(left: icon == null ? 12 : 10, right: 12),
      decoration: BoxDecoration(color: bg, borderRadius: V2Radius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            style: V2Text.cap.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(container: true, child: pill);
    }
    // Material InkWell provides the tap action; Semantics only adds flags.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Center(widthFactor: 1, child: pill),
          ),
        ),
      ),
    );
  }
}
