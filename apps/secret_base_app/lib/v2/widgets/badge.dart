import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// Count / short label badge (ds.css `.badge`), or a small unread dot.
///
/// ```dart
/// V2Badge(count: 3)          // "3", 99+ caps
/// V2Badge(label: 'N')
/// V2Badge.dot()
/// ```
class V2Badge extends StatelessWidget {
  const V2Badge({super.key, this.count, this.label, this.semanticLabel})
    : _dot = false,
      borderColor = null,
      assert(count != null || label != null);

  const V2Badge.dot({super.key, this.borderColor, this.semanticLabel})
    : _dot = true,
      count = null,
      label = null;

  final int? count;
  final String? label;

  /// Defaults to '새 소식 n개' / '새 소식'.
  final String? semanticLabel;

  /// Ring color around the dot (match what it sits on).
  final Color? borderColor;
  final bool _dot;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    if (_dot) {
      return Semantics(
        label: semanticLabel ?? '새 소식',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: p.primary,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor ?? p.bg, width: 2),
          ),
        ),
      );
    }
    final text = label ?? (count! > 99 ? '99+' : '${count!}');
    return Semantics(
      label: semanticLabel ?? (count != null ? '새 소식 $count개' : text),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: V2Text.label.copyWith(
            color: p.onPrimary,
            height: 1.0,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
