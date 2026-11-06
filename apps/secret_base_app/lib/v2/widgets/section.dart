import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';

/// Section label + optional trailing action, then optional content
/// (ds.css `.sec`). Adds the page side padding to the label row only.
///
/// ```dart
/// V2Section(title: '우리 이야기', child: V2List(children: [...]))
/// V2Section(title: '이번 주', actionLabel: '전체 보기', onAction: openAll)
/// ```
class V2Section extends StatelessWidget {
  const V2Section({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.top = 24,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? child;

  /// Padding applied to the child (and label row).
  final EdgeInsetsGeometry padding;

  /// Space above the label.
  final double top;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final header = Padding(
      padding: EdgeInsets.only(top: top),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: V2Text.cap.copyWith(
                    color: p.sub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: p.primary,
                  textStyle: V2Text.cap.copyWith(fontWeight: FontWeight.w700),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [header, ?child],
      ),
    );
  }
}
