import 'package:flutter/material.dart';

import 'game_theme.dart';

/// 화면을 가로지르는 배너("내 차례!", "골!"). [id]가 바뀔 때마다 한 번 재생하고,
/// 처음 그려질 때의 id는 재생하지 않는다(지난 알림이 다시 뜨지 않게).
class GameTurnBanner extends StatefulWidget {
  final GameTheme theme;
  final Object? id;
  final String text;
  final String? sub;
  final Color? color;
  final Duration hold;

  const GameTurnBanner({
    super.key,
    required this.theme,
    required this.id,
    required this.text,
    this.sub,
    this.color,
    this.hold = const Duration(milliseconds: 1100),
  });

  @override
  State<GameTurnBanner> createState() => _GameTurnBannerState();
}

class _GameTurnBannerState extends State<GameTurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  String _text = '';
  String? _sub;
  Color? _color;

  @override
  void didUpdateWidget(covariant GameTurnBanner old) {
    super.didUpdateWidget(old);
    if (widget.id != null && widget.id != old.id) {
      _text = widget.text;
      _sub = widget.sub;
      _color = widget.color;
      _c.duration = widget.hold + const Duration(milliseconds: 700);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final total = _c.duration!.inMilliseconds;
          final ms = _c.value * total;
          const inMs = 320.0, outMs = 320.0;
          double dx;
          double opacity;
          if (ms < inMs) {
            final k = Curves.easeOutCubic.transform(ms / inMs);
            dx = (1 - k) * 1.2;
            opacity = k;
          } else if (ms > total - outMs) {
            final k = Curves.easeInCubic.transform(
              (ms - (total - outMs)) / outMs,
            );
            dx = -k * 1.2;
            opacity = 1 - k;
          } else {
            dx = 0;
            opacity = 1;
          }
          final c = _color ?? t.accent;
          return Center(
            child: FractionalTranslation(
              translation: Offset(dx, 0),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.withValues(alpha: 0),
                        c.withValues(alpha: 0.92),
                        c.withValues(alpha: 0.92),
                        c.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.18, 0.82, 1],
                    ),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: t.gold.withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _text,
                        textAlign: TextAlign.center,
                        style: t
                            .display(size: 30, color: Colors.white)
                            .copyWith(
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                      ),
                      if (_sub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _sub!,
                            textAlign: TextAlign.center,
                            style: t.body(size: 13, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
