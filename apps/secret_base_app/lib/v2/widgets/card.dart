import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum V2CardVariant {
  /// 2.1: a gray block on white pages (no border, no shadow). On tinted
  /// pages (종이, 버터) it is a white block instead.
  raised,

  /// Same as [raised] (kept for older call sites).
  flat,

  /// Soft fill, no border, no shadow.
  soft,
}

/// Card container (ds.css `.card`). Tappable when [onTap] is set; then it
/// is a single button for screen readers, labelled by its text content
/// (or [semanticLabel]).
///
/// ```dart
/// V2Card(child: Text('오늘의 기록'))
/// V2Card(variant: V2CardVariant.soft, onTap: open, child: ...)
/// V2Card(gradient: V2Gradients.hero, child: ...)
/// ```
class V2Card extends StatelessWidget {
  const V2Card({
    super.key,
    required this.child,
    this.variant = V2CardVariant.raised,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.semanticLabel,
    this.radius = V2Radius.card,
  });

  final Widget child;
  final V2CardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Overrides the fill color.
  final Color? color;

  /// Fills with a gradient (border and shadow dropped).
  final Gradient? gradient;
  final String? semanticLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final br = BorderRadius.circular(radius);
    // 2.1: cards are flat blocks. On a white page a white card would vanish,
    // so it takes the soft gray; on tinted pages it stays the surface color.
    final whitePage = p.bg == p.surface;
    final fill =
        color ??
        (variant == V2CardVariant.soft || whitePage ? p.soft : p.surface);
    final decoration = BoxDecoration(
      color: gradient == null ? fill : null,
      gradient: gradient,
      borderRadius: br,
    );
    if (onTap == null) {
      return Container(decoration: decoration, padding: padding, child: child);
    }
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            child: Padding(
              padding: padding,
              child: semanticLabel == null
                  ? child
                  : ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
