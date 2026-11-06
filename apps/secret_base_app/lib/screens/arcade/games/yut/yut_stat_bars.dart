import 'package:flutter/material.dart';

import 'yut_models.dart';

/// 캐릭터 능력치 5가지를 1~5칸 막대로 보여 준다(로비 선택 카드·장비 창 공용).
/// [compact]이면 힌트 글을 빼고 좁은 카드에 맞춘다.
class YutStatBars extends StatelessWidget {
  final Map<String, int> stats;
  final Color color;
  final Color textColor;
  final Color mutedColor;
  final bool compact;

  const YutStatBars({
    super.key,
    required this.stats,
    required this.color,
    this.textColor = const Color(0xFF2A2623),
    this.mutedColor = const Color(0xFF8C867D),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final def in kYutStatDefs)
          _row(def, (stats[def.key] ?? 3).clamp(1, 5)),
      ],
    );
  }

  Widget _row(YutStatDef def, int level) {
    final pip = compact ? 4.0 : 12.0;
    final gap = compact ? 2.0 : 4.0;
    return Semantics(
      label: '${def.label} 5점 만점에 $level점. ${def.hint}',
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
          child: Row(
            children: [
              SizedBox(
                width: compact ? 46 : 72,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    def.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              for (var i = 1; i <= 5; i++)
                Container(
                  key: ValueKey('yut_stat_${def.key}_$i'),
                  width: pip,
                  height: compact ? 6 : 8,
                  margin: EdgeInsets.only(right: gap),
                  decoration: BoxDecoration(
                    color: i <= level ? color : color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              if (!compact) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    def.hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedColor,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
