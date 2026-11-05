import 'package:flutter/material.dart';

import 'game_theme.dart';

/// 조작부를 가리지 않는 짧은 안내(화면 위쪽). [id]가 바뀌면 [message]를 잠깐 보여 준다.
class GameToast extends StatefulWidget {
  final GameTheme theme;
  final Object? id;
  final String? message;
  final Duration duration;

  const GameToast({
    super.key,
    required this.theme,
    required this.id,
    required this.message,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<GameToast> createState() => _GameToastState();
}

class _GameToastState extends State<GameToast> {
  String? _shown;
  int _seq = 0;

  @override
  void didUpdateWidget(covariant GameToast old) {
    super.didUpdateWidget(old);
    if (widget.id != null && widget.id != old.id && widget.message != null) {
      final seq = ++_seq;
      setState(() => _shown = widget.message);
      Future.delayed(widget.duration, () {
        if (mounted && seq == _seq) setState(() => _shown = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(a),
            child: child,
          ),
        ),
        child: _shown == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Container(
                key: ValueKey(_seq),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (t.dark ? Colors.black : t.ink).withValues(
                    alpha: 0.78,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _shown!,
                  textAlign: TextAlign.center,
                  style: t.body(
                    size: 13.5,
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}
