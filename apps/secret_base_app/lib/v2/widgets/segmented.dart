import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import '../typography.dart';

/// One option of a [V2Segmented].
class V2Segment<T> {
  const V2Segment({required this.value, required this.label});
  final T value;
  final String label;
}

/// 44px segmented control (ds.css `.seg`), e.g. the 나/우리 toggle.
///
/// ```dart
/// V2Segmented<int>(
///   segments: const [V2Segment(value: 0, label: '나'), V2Segment(value: 1, label: '우리')],
///   selected: mode,
///   onChanged: (v) => setState(() => mode = v),
/// )
/// ```
class V2Segmented<T> extends StatelessWidget {
  const V2Segmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<V2Segment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final duration = V2Motion.of(context, V2Motion.fast);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.soft2, borderRadius: V2Radius.ctlAll),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: s.value == selected,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onChanged == null ? null : () => onChanged!(s.value),
                    child: AnimatedContainer(
                      duration: duration,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.value == selected
                            ? p.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: s.value == selected && !p.dark
                            ? const [
                                BoxShadow(
                                  color: Color(0x263C1428),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V2Text.buttonSm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: s.value == selected ? p.ink : p.sub,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
