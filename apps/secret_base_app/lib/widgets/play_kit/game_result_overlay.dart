import 'package:flutter/material.dart';

import '../../core/game_sfx/game_sfx.dart';
import 'confetti_burst.dart';
import 'game_buttons.dart';
import 'game_hud.dart';
import 'game_theme.dart';

enum GameOutcome { win, lose, draw }

/// 판이 끝났을 때 화면 위에 올리는 결과 카드: 승/패/무 + 이유 + 이번 방 전적 + 재대결.
/// 상태로 띄우는 위젯이라 Stack 맨 위에 두고, 결과가 없으면 빼면 된다.
/// 재대결은 상대 동의 절차(`game:restart:*`)를 쓰는 [onRematch]로만 한다.
class GameResultOverlay extends StatefulWidget {
  final GameTheme theme;
  final GameOutcome outcome;
  final String? title;
  final String? reason;
  final Map<String, dynamic>? series;
  final String? me;
  final Widget? details;
  final VoidCallback? onRematch;
  final bool rematchWaiting;
  final VoidCallback? onExit;

  /// 같은 결과로 다시 그려질 때 소리·색종이를 반복하지 않게 하는 식별자(예: gameId).
  final Object? resultId;

  const GameResultOverlay({
    super.key,
    required this.theme,
    required this.outcome,
    this.title,
    this.reason,
    this.series,
    this.me,
    this.details,
    this.onRematch,
    this.rematchWaiting = false,
    this.onExit,
    this.resultId,
  });

  @override
  State<GameResultOverlay> createState() => _GameResultOverlayState();
}

class _GameResultOverlayState extends State<GameResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  static final Set<Object> _played = {};

  @override
  void initState() {
    super.initState();
    final id = widget.resultId;
    if (id == null || _played.add(id)) {
      GameSfx.instance.play(switch (widget.outcome) {
        GameOutcome.win => GameSound.win,
        GameOutcome.lose => GameSound.lose,
        GameOutcome.draw => GameSound.draw,
      });
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final (emoji, defaultTitle, color) = switch (widget.outcome) {
      GameOutcome.win => ('🏆', '승리!', t.gold),
      GameOutcome.lose => ('🥲', '아쉬운 패배', t.opponent),
      GameOutcome.draw => ('🤝', '무승부', t.subInk),
    };
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _in,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        ),
        if (widget.outcome == GameOutcome.win)
          ConfettiBurst(
            trigger: widget.resultId ?? 'win',
            colors: [t.gold, t.accent, t.me, t.opponent, Colors.white],
          ),
        Center(
          child: ScaleTransition(
            scale: Tween(begin: 0.86, end: 1.0).animate(curve),
            child: FadeTransition(
              opacity: _in,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: GamePanel(
                    theme: t,
                    radius: 28,
                    glow: widget.outcome == GameOutcome.win ? t.gold : null,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 54)),
                        const SizedBox(height: 6),
                        Text(
                          widget.title ?? defaultTitle,
                          textAlign: TextAlign.center,
                          style: t.display(size: 32, color: color),
                        ),
                        if (widget.reason != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.reason!,
                            textAlign: TextAlign.center,
                            style: t.body(
                              size: 14,
                              color: t.subInk,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (widget.details != null) ...[
                          const SizedBox(height: 14),
                          widget.details!,
                        ],
                        if (widget.series != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            '이번 방 전적',
                            style: t.body(size: 11.5, color: t.subInk),
                          ),
                          const SizedBox(height: 4),
                          SeriesScore.fromMap(t, widget.series, widget.me),
                        ],
                        const SizedBox(height: 18),
                        if (widget.onRematch != null)
                          GamePrimaryButton(
                            theme: t,
                            label: widget.rematchWaiting
                                ? '상대의 수락을 기다리는 중…'
                                : '한 판 더!',
                            icon: widget.rematchWaiting
                                ? Icons.hourglass_top_rounded
                                : Icons.replay_rounded,
                            height: 52,
                            onPressed: widget.rematchWaiting
                                ? null
                                : widget.onRematch,
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed:
                              widget.onExit ??
                              () => Navigator.of(context).maybePop(),
                          child: Text(
                            '나가기',
                            style: t.body(size: 14, color: t.subInk),
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
      ],
    );
  }
}
