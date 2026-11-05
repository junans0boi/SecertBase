import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_models.dart';

/// 아래 조작부: 골대 칸과 같은 배치의 큰 방향 버튼(3개 또는 3×2) + 확정 버튼 하나.
class PenaltyControls extends StatelessWidget {
  final GameTheme theme;
  final int cells;
  final int? selected;
  final bool enabled;
  final bool iAmKicker;
  final bool waiting;
  final Color color;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfirm;

  const PenaltyControls({
    super.key,
    required this.theme,
    required this.cells,
    required this.selected,
    required this.enabled,
    required this.iAmKicker,
    required this.waiting,
    required this.color,
    required this.onSelect,
    required this.onConfirm,
  });

  static const _arrows3 = ['←', '↑', '→'];
  static const _arrows6 = ['↖', '↑', '↗', '↙', '↓', '↘'];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final rows = cells == 6 ? 2 : 1;
    final height = cells == 6 ? 46.0 : 54.0;
    Widget button(int c) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: _DirButton(
          key: Key('penalty_button_$c'),
          theme: t,
          arrow: cells == 6 ? _arrows6[c] : _arrows3[c],
          label: penaltyCellName(cells, c),
          selected: selected == c,
          enabled: enabled,
          color: color,
          height: height,
          onTap: () => onSelect(c),
        ),
      ),
    );
    final String confirmLabel;
    if (waiting) {
      confirmLabel = '상대를 기다리는 중…';
    } else if (iAmKicker) {
      confirmLabel = selected == null ? '찰 곳을 골라요' : '슛!';
    } else {
      confirmLabel = selected == null ? '막을 곳을 골라요' : '막기!';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int r = 0; r < rows; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 8 : 6),
            child: Row(
              children: [for (int c = 0; c < 3; c++) button(r * 3 + c)],
            ),
          ),
        GamePrimaryButton(
          key: const Key('penalty_confirm'),
          theme: t,
          label: confirmLabel,
          icon: waiting
              ? Icons.hourglass_top_rounded
              : iAmKicker
              ? Icons.sports_soccer_rounded
              : Icons.back_hand_rounded,
          height: 56,
          color: iAmKicker ? t.accent : t.me,
          onPressed: enabled && selected != null && !waiting ? onConfirm : null,
        ),
      ],
    );
  }
}

class _DirButton extends StatelessWidget {
  final GameTheme theme;
  final String arrow;
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final double height;
  final VoidCallback onTap;

  const _DirButton({
    super.key,
    required this.theme,
    required this.arrow,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                GameSfx.instance.play(GameSound.select);
                onTap();
              }
            : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: height,
            decoration: BoxDecoration(
              color: selected
                  ? Color.lerp(color, Colors.black, 0.18)
                  : t.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.white : t.surfaceBorder,
                width: selected ? 2.2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (selected ? color : Colors.black).withValues(
                    alpha: selected ? 0.45 : 0.06,
                  ),
                  blurRadius: selected ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  arrow,
                  style: t.body(
                    size: 18,
                    color: selected ? Colors.white : t.accent,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(
                      size: 13,
                      color: selected ? Colors.white : t.ink,
                      weight: FontWeight.w800,
                    ),
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
