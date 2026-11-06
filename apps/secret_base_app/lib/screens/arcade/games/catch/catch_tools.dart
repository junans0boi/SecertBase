/// 그리는 사람의 도구함: 12색 팔레트(44px 이상), 연필·마커·지우개, 굵기 3단계 미리보기, 되돌리기, 전체 지우기.
library;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'catch_models.dart';

/// 팔레트 한 칸의 최소 터치 크기.
const double kCatchTouch = 44;

class CatchToolbar extends StatelessWidget {
  final GameTheme theme;
  final CatchTool tool;
  final int colorIndex;
  final int sizeIndex;
  final bool canUndo;
  final bool enabled;
  final ValueChanged<CatchTool> onTool;
  final ValueChanged<int> onColor;
  final ValueChanged<int> onSize;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const CatchToolbar({
    super.key,
    required this.theme,
    required this.tool,
    required this.colorIndex,
    required this.sizeIndex,
    required this.canUndo,
    required this.enabled,
    required this.onTool,
    required this.onColor,
    required this.onSize,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.surfaceBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  key: ValueKey('palette-row-$row'),
                  children: [
                    for (var i = row * 6; i < row * 6 + 6; i++)
                      Expanded(
                        child: _Swatch(
                          theme: t,
                          index: i,
                          selected: tool != CatchTool.eraser && colorIndex == i,
                          onTap: () => onColor(i),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  for (final tl in CatchTool.values)
                    Expanded(
                      child: _ToolButton(
                        theme: t,
                        tool: tl,
                        selected: tool == tl,
                        onTap: () => onTool(tl),
                      ),
                    ),
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: t.surfaceBorder,
                  ),
                  for (var i = 0; i < kCatchBrushWidths.length; i++)
                    Expanded(
                      child: _SizeButton(
                        theme: t,
                        index: i,
                        selected: sizeIndex == i,
                        color: tool == CatchTool.eraser
                            ? const Color(0xFFB9B4A6)
                            : kCatchPalette[colorIndex].color,
                        tool: tool,
                        onTap: () => onSize(i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      key: const ValueKey('catch-undo'),
                      theme: t,
                      icon: Icons.undo_rounded,
                      label: '되돌리기',
                      onTap: canUndo ? onUndo : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ActionButton(
                      key: const ValueKey('catch-clear'),
                      theme: t,
                      icon: Icons.delete_sweep_rounded,
                      label: '전체 지우기',
                      onTap: onClear,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final GameTheme theme;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.theme,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = kCatchPalette[index];
    final light = ink.color.computeLuminance() > 0.6;
    return Semantics(
      button: true,
      selected: selected,
      label: '${ink.name} 색',
      child: GestureDetector(
        key: ValueKey('swatch-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: kCatchTouch,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: selected ? 36 : 30,
              height: selected ? 36 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ink.color,
                border: Border.all(
                  color: selected
                      ? theme.accent
                      : (light
                            ? const Color(0x33000000)
                            : Colors.white.withValues(alpha: 0.7)),
                  width: selected ? 3 : 1.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: light ? const Color(0xFF23242C) : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final GameTheme theme;
  final CatchTool tool;
  final bool selected;
  final VoidCallback onTap;

  const _ToolButton({
    required this.theme,
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = selected ? Colors.white : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tool.label} 도구',
      child: GestureDetector(
        key: ValueKey('tool-${tool.wire}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              switch (tool) {
                CatchTool.pen => Icon(
                  Icons.edit_rounded,
                  size: 20,
                  color: color,
                ),
                CatchTool.marker => Icon(
                  Icons.brush_rounded,
                  size: 20,
                  color: color,
                ),
                CatchTool.eraser => SizedBox(
                  width: 22,
                  height: 20,
                  child: CustomPaint(painter: _EraserIcon(color)),
                ),
              },
              const SizedBox(height: 1),
              Text(
                tool.label,
                style: t.body(
                  size: 10.5,
                  color: color,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EraserIcon extends CustomPainter {
  final Color color;

  const _EraserIcon(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.6);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 17, height: 9),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = color,
    );
    canvas.drawRect(
      Rect.fromLTRB(-8.5, -4.5, -2.5, 4.5),
      Paint()..color = color.withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserIcon old) => old.color != color;
}

class _SizeButton extends StatelessWidget {
  final GameTheme theme;
  final int index;
  final bool selected;
  final Color color;
  final CatchTool tool;
  final VoidCallback onTap;

  const _SizeButton({
    required this.theme,
    required this.index,
    required this.selected,
    required this.color,
    required this.tool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // 미리보기: 실제 굵기와 같은 비율(보드 너비 약 330px 기준)로 점을 그린다.
    final dot = (kCatchBrushWidths[index] * 330 * catchWidthFactor(tool)).clamp(
      4.0,
      30.0,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '굵기 ${kCatchBrushLabels[index]}',
      child: GestureDetector(
        key: ValueKey('size-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.accent : Colors.transparent,
              width: 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: tool == CatchTool.marker
                  ? color.withValues(alpha: 0.65)
                  : color,
              borderRadius: BorderRadius.circular(
                tool == CatchTool.marker ? dot * 0.22 : dot,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final GameTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: on ? 1 : 0.4,
          child: Container(
            height: kCatchTouch,
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: t.accent),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: t.body(
                    size: 13,
                    color: t.accent,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
