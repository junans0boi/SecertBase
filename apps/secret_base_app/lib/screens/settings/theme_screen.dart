import 'package:flutter/material.dart';

import '../../v2/v2.dart';

/// 설정 > 화면 테마: pick one of the color themes. Only colors change; layout
/// and shapes stay. Applies immediately and is saved on this device.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key, this.controller});

  /// Injectable for tests; defaults to the app-wide controller.
  final V2ThemeController? controller;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? V2ThemeController.instance;
    final p = V2Palette.of(context);
    return V2Theme(
      child: Scaffold(
        appBar: const V2Header(title: '화면 테마'),
        body: ValueListenableBuilder<V2ThemeId>(
          valueListenable: c,
          builder: (context, selected, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
              V2Space.page,
              V2Space.x2,
              V2Space.page,
              V2Space.x10,
            ),
            children: [
              Text(
                '색만 바뀌고 화면 배치는 그대로예요. 이 기기에만 저장돼요.',
                style: V2Text.cap.copyWith(color: p.sub),
              ),
              const SizedBox(height: V2Space.x4),
              for (final id in V2ThemeId.values) ...[
                _ThemeOption(
                  id: id,
                  selected: id == selected,
                  onTap: () => c.select(id),
                ),
                const SizedBox(height: V2Space.x3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final V2ThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V2Palette.of(context);
    final t = V2Palettes.byId(id);
    return Semantics(
      button: true,
      selected: selected,
      label: '${id.label} 테마, ${id.description}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: p.surface,
          borderRadius: V2Radius.cardAll,
          child: InkWell(
            borderRadius: V2Radius.cardAll,
            onTap: onTap,
            child: AnimatedContainer(
              duration: V2Motion.of(context, V2Motion.fast),
              padding: const EdgeInsets.all(V2Space.x3),
              decoration: BoxDecoration(
                borderRadius: V2Radius.cardAll,
                border: Border.all(
                  color: selected ? p.primary : p.line,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  _Preview(palette: t),
                  const SizedBox(width: V2Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          id.label,
                          style: V2Text.bodyStrong.copyWith(color: p.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          id.description,
                          style: V2Text.cap.copyWith(color: p.sub),
                        ),
                        const SizedBox(height: V2Space.x2),
                        Row(
                          children: [
                            for (final c in [
                              t.bg,
                              t.ink,
                              t.primary,
                              t.point,
                              t.primarySoft,
                            ])
                              Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: p.ink.withValues(alpha: .12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: V2Space.x2),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? p.primary : p.control,
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tiny home screen drawn in [palette]'s colors.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette});

  final V2Palette palette;

  @override
  Widget build(BuildContext context) {
    final t = palette;
    return Container(
      width: 76,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            decoration: BoxDecoration(gradient: t.heroWash),
            padding: const EdgeInsets.fromLTRB(7, 8, 7, 0),
            alignment: Alignment.topLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'D+',
                    style: TextStyle(color: t.point, fontSize: 8),
                  ),
                  TextSpan(
                    text: '412',
                    style: TextStyle(color: t.ink, fontSize: 13),
                  ),
                ],
              ),
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(6, 2, 6, 0),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _bar(t.soft2, 18)),
                    const SizedBox(width: 3),
                    Expanded(child: _bar(t.primarySoft, 18)),
                  ],
                ),
                const SizedBox(height: 4),
                _bar(t.primary, 9),
              ],
            ),
          ),
          const Spacer(),
          Container(
            height: 12,
            color: t.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dot(t.primary),
                _dot(t.muted),
                _dot(t.muted),
                _dot(t.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color c, double h) => Container(
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
  );

  Widget _dot(Color c) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}
