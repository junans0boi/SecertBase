import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icons.dart';

/// 24px rounded checkbox (ds.css `.check`). With [label] the whole row is
/// the hit area (min 44px) — use this for 약관 동의 rows.
///
/// ```dart
/// V2Check(value: agree, onChanged: (v) => setState(() => agree = v), label: '(필수) 이용약관 동의')
/// ```
class V2Check extends StatelessWidget {
  const V2Check({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.semanticLabel,
    this.trailing,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  /// Needed when there is no visible [label].
  final String? semanticLabel;

  /// E.g. a '보기' text button for 약관 rows.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final enabled = onChanged != null;
    final box = AnimatedContainer(
      duration: V2Motion.of(context, V2Motion.fast),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? p.primary : p.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? p.primary : (enabled ? p.control : p.line2),
          width: 2,
        ),
      ),
      child: value ? Icon(V2Icons.check, size: 16, color: p.onPrimary) : null,
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
      child: label == null
          ? Center(widthFactor: 1, child: box)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                children: [
                  box,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label!,
                      style: V2Text.body.copyWith(
                        color: enabled ? p.ink : p.disabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );

    final check = Semantics(
      container: true,
      checked: value,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: V2Radius.ctlAll,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: content,
        ),
      ),
    );
    if (trailing == null) return check;
    return Row(
      children: [
        Expanded(child: check),
        trailing!,
      ],
    );
  }
}
