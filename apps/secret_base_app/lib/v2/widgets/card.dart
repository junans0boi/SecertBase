import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum V2CardVariant {
  /// White, hairline border, level-1 shadow.
  raised,

  /// White, hairline border, no shadow.
  flat,

  /// Soft blush fill, no border, no shadow.
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
    final fill = color ?? (variant == V2CardVariant.soft ? p.soft : p.surface);
    final bordered = variant != V2CardVariant.soft && gradient == null;
    final decoration = BoxDecoration(
      color: gradient == null ? fill : null,
      gradient: gradient,
      borderRadius: br,
      border: bordered ? Border.all(color: p.line) : null,
      boxShadow: variant == V2CardVariant.raised && !p.dark
          ? V2Shadow.level1
          : null,
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
