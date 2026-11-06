import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// iOS-style 51×31 switch (ds.css `.toggle`) inside a 44px hit area.
/// Off track uses [V2Colors.control] (3.27:1 non-text contrast).
///
/// ```dart
/// V2Toggle(value: push, onChanged: (v) => setState(() => push = v), semanticLabel: '알림 받기')
/// ```
/// Inside a [V2ListTile] (`trailing:`) the row's title already labels it,
/// so [semanticLabel] may be omitted there.
class V2Toggle extends StatelessWidget {
  const V2Toggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Null = disabled.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final enabled = onChanged != null;
    final duration = V2Motion.of(context, V2Motion.fast);
    void toggle() => onChanged?.call(!value);

    final track = AnimatedContainer(
      duration: duration,
      curve: V2Motion.curve,
      width: 51,
      height: 31,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? p.primary : p.control,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: V2Motion.curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 27,
          height: 27,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );

    // Material InkWell gives keyboard focus/activation and the semantic tap
    // action; Semantics adds the toggled state and label.
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? toggle : null,
            customBorder: const StadiumBorder(),
            child: SizedBox(width: 59, height: 44, child: Center(child: track)),
          ),
        ),
      ),
    );
  }
}
