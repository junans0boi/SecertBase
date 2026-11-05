import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_hud.dart';
import 'penalty_models.dart';

/// 아래 조작부: 골대 칸과 같은 배치의 얇은 세그먼트(3칸 또는 3×2) + 확정 버튼 하나.
/// 골대를 직접 눌러도 되고, 이 세그먼트로 골라도 된다(접근성).
class PenaltyControls extends StatelessWidget {
  final GameTheme theme;
  final int cells;
  final int? selected;
  final bool enabled;
  final bool iAmKicker;
  final bool waiting;
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
    required this.onSelect,
    required this.onConfirm,
  });

  static const _icons3 = [
    Icons.west_rounded,
    Icons.north_rounded,
    Icons.east_rounded,
  ];
  static const _icons6 = [
    Icons.north_west_rounded,
    Icons.north_rounded,
    Icons.north_east_rounded,
    Icons.south_west_rounded,
    Icons.south_rounded,
    Icons.south_east_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final rows = cells == 6 ? 2 : 1;
    final String label;
    if (waiting) {
      label = '상대를 기다리는 중…';
    } else if (iAmKicker) {
      label = selected == null ? '찰 곳을 골라요' : '슛!';
    } else {
      label = selected == null ? '막을 곳을 골라요' : '막기!';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xB30A1328),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PenaltyColors.glassBorder),
            ),
            child: Column(
              children: [
                for (int r = 0; r < rows; r++)
                  Padding(
                    padding: EdgeInsets.only(top: r == 0 ? 0 : 3),
                    child: Row(
                      children: [
                        for (int c = 0; c < 3; c++) ...[
                          if (c > 0) const SizedBox(width: 3),
                          Expanded(
                            child: _Segment(
                              key: Key('penalty_button_${r * 3 + c}'),
                              theme: t,
                              icon: cells == 6
                                  ? _icons6[r * 3 + c]
                                  : _icons3[c],
                              label: penaltyCellName(cells, r * 3 + c),
                              selected: selected == r * 3 + c,
                              enabled: enabled,
                              onTap: () => onSelect(r * 3 + c),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        PenaltyShootButton(
          key: const Key('penalty_confirm'),
          theme: t,
          label: label,
          icon: waiting
              ? Icons.hourglass_top_rounded
              : iAmKicker
              ? Icons.sports_soccer_rounded
              : Icons.back_hand_rounded,
          onPressed: enabled && selected != null && !waiting ? onConfirm : null,
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final GameTheme theme;
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Segment({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final fg = selected ? PenaltyColors.navy : t.ink.withValues(alpha: 0.88);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? PenaltyColors.navy : t.accent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(size: 13, color: fg, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 스포츠 중계풍 확정 버튼(비스듬한 라임 블록). 고르기 전에는 안내 문구만 보이는 어두운 버튼.
class PenaltyShootButton extends StatefulWidget {
  final GameTheme theme;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  const PenaltyShootButton({
    super.key,
    required this.theme,
    required this.label,
    required this.icon,
    this.onPressed,
    this.height = 58,
  });

  @override
  State<PenaltyShootButton> createState() => _PenaltyShootButtonState();
}

class _PenaltyShootButtonState extends State<PenaltyShootButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = widget.onPressed != null;
    final fg = enabled ? PenaltyColors.navy : t.subInk;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _ShootPainter(enabled: enabled, accent: t.accent),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Row(
                      key: ValueKey('${widget.label}$enabled'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: fg, size: enabled ? 24 : 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: enabled
                                ? t.display(size: 26, color: fg)
                                : t.body(
                                    size: 15,
                                    color: fg,
                                    weight: FontWeight.w700,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShootPainter extends CustomPainter {
  final bool enabled;
  final Color accent;

  _ShootPainter({required this.enabled, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const skew = 14.0;
    const r = 8.0;
    final path = Path()
      ..moveTo(skew + r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width - 1.5, r * 0.6)
      ..lineTo(size.width - skew + 1.5, size.height - r * 0.6)
      ..quadraticBezierTo(
        size.width - skew,
        size.height,
        size.width - skew - r,
        size.height,
      )
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 1.5, size.height - r * 0.6)
      ..lineTo(skew - 1.5, r * 0.6)
      ..quadraticBezierTo(skew, 0, skew + r, 0)
      ..close();
    final rect = Offset.zero & size;
    if (!enabled) {
      canvas.drawPath(path, Paint()..color = const Color(0x990A1328));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x40FFFFFF),
      );
      return;
    }
    canvas.drawShadow(path, accent, 10, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(accent, Colors.white, 0.35)!,
            accent,
            Color.lerp(accent, Colors.black, 0.12)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // 빗살 광택.
    canvas.save();
    canvas.clipPath(path);
    final sheen = Paint()..color = const Color(0x1FFFFFFF);
    for (double x = -size.height; x < size.width; x += 22) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + 8, size.height)
          ..lineTo(x + 8 + size.height * 0.45, 0)
          ..lineTo(x + size.height * 0.45, 0)
          ..close(),
        sheen,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.45),
      Paint()..color = const Color(0x22FFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShootPainter old) =>
      old.enabled != enabled || old.accent != accent;
}
