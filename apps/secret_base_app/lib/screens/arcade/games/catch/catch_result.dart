/// 판이 끝났을 때: 승패·점수·라운드별 그림 갤러리·한 판 더.
library;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'catch_controller.dart';
import 'catch_models.dart';
import 'catch_paint.dart';

class CatchResultOverlay extends StatefulWidget {
  final GameTheme theme;
  final CatchController controller;
  final CatchState state;
  final VoidCallback onRematch;
  final bool rematchWaiting;
  final VoidCallback onExit;

  const CatchResultOverlay({
    super.key,
    required this.theme,
    required this.controller,
    required this.state,
    required this.onRematch,
    required this.rematchWaiting,
    required this.onExit,
  });

  @override
  State<CatchResultOverlay> createState() => _CatchResultOverlayState();
}

class _CatchResultOverlayState extends State<CatchResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  static final Set<String> _played = {};

  GameOutcome get _outcome {
    final r = widget.state.result;
    if (r == null || r.draw || r.winner == null) return GameOutcome.draw;
    return r.winner == widget.controller.me
        ? GameOutcome.win
        : GameOutcome.lose;
  }

  @override
  void initState() {
    super.initState();
    if (_played.add(widget.state.gameId)) {
      GameSfx.instance.play(switch (_outcome) {
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

  String _reason() {
    final c = widget.controller;
    final s = widget.state;
    final r = s.result;
    if (r == null) return '';
    switch (r.reason) {
      case 'forfeit':
        final loser = r.loser;
        return loser == c.me
            ? '그림을 그리지 않아 기권 처리됐어요'
            : '${c.displayName(loser)}님이 오래 자리를 비워 기권 처리됐어요';
      case 'both_away':
        return '두 사람 모두 그림을 그리지 않아 끝났어요';
      default:
        return r.draw ? '점수가 같아요!' : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final c = widget.controller;
    final s = widget.state;
    final outcome = _outcome;
    final me = c.me;
    final opp = s.opponentOf(me);
    final (emoji, title, color) = switch (outcome) {
      GameOutcome.win => ('🏆', '내가 이겼어요!', t.gold),
      GameOutcome.lose => ('🥲', '아쉬운 패배', t.opponent),
      GameOutcome.draw => ('🤝', '무승부', t.subInk),
    };
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    final reason = _reason();
    return Stack(
      fit: StackFit.expand,
      children: [
        FadeTransition(
          opacity: _in,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        ),
        if (outcome == GameOutcome.win)
          ConfettiBurst(
            trigger: 'catch-win-${s.gameId}',
            colors: [t.gold, t.accent, t.me, t.opponent, Colors.white],
          ),
        SafeArea(
          child: Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.88, end: 1.0).animate(curve),
              child: FadeTransition(
                opacity: _in,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: GamePanel(
                      theme: t,
                      radius: 26,
                      opaque: true,
                      glow: outcome == GameOutcome.win ? t.gold : null,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 34)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.display(size: 28, color: color),
                                ),
                              ),
                            ],
                          ),
                          if (reason.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                reason,
                                textAlign: TextAlign.center,
                                style: t.body(size: 12.5, color: t.subInk),
                              ),
                            ),
                          const SizedBox(height: 8),
                          _ScoreLine(
                            theme: t,
                            leftName: c.displayName(me),
                            leftEmoji: c.emojiOf(me),
                            leftScore: s.scores[me] ?? 0,
                            rightName: c.displayName(opp),
                            rightEmoji: c.emojiOf(opp),
                            rightScore: s.scores[opp] ?? 0,
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (s.gallery.isNotEmpty)
                                    _Gallery(
                                      theme: t,
                                      controller: c,
                                      items: s.gallery,
                                    ),
                                  if (s.series != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      '이번 방 전적',
                                      style: t.body(
                                        size: 11.5,
                                        color: t.subInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SeriesScore.fromMap(t, s.series, me),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          GamePrimaryButton(
                            key: const ValueKey('catch-rematch'),
                            theme: t,
                            label: widget.rematchWaiting
                                ? '상대의 수락을 기다리는 중…'
                                : '한 판 더!',
                            icon: widget.rematchWaiting
                                ? Icons.hourglass_top_rounded
                                : Icons.replay_rounded,
                            height: 50,
                            onPressed: widget.rematchWaiting
                                ? null
                                : widget.onRematch,
                          ),
                          TextButton(
                            onPressed: widget.onExit,
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
        ),
      ],
    );
  }
}

class _ScoreLine extends StatelessWidget {
  final GameTheme theme;
  final String leftName;
  final String leftEmoji;
  final int leftScore;
  final String rightName;
  final String rightEmoji;
  final int rightScore;

  const _ScoreLine({
    required this.theme,
    required this.leftName,
    required this.leftEmoji,
    required this.leftScore,
    required this.rightName,
    required this.rightEmoji,
    required this.rightScore,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget side(String emoji, String name, int score, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            emoji.isEmpty ? '🙂' : emoji,
            style: const TextStyle(fontSize: 26),
          ),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(size: 12.5, weight: FontWeight.w800),
          ),
          Text('$score점', style: t.display(size: 26, color: color)),
        ],
      ),
    );
    return Semantics(
      label: '$leftName $leftScore점 대 $rightName $rightScore점',
      child: Row(
        children: [
          side(leftEmoji, leftName, leftScore, t.me),
          Text(
            'VS',
            style: t.body(size: 12, color: t.subInk, weight: FontWeight.w900),
          ),
          side(rightEmoji, rightName, rightScore, t.opponent),
        ],
      ),
    );
  }
}

/// 라운드별 그림 모음: 작은 스케치북 카드마다 정답·그린 사람·결과.
class _Gallery extends StatelessWidget {
  final GameTheme theme;
  final CatchController controller;
  final List<CatchGalleryItem> items;

  const _Gallery({
    required this.theme,
    required this.controller,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('catch-gallery'),
      children: [
        Text(
          '오늘의 그림',
          style: theme.body(
            size: 12,
            color: theme.subInk,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 8.0;
            final w = (box.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: w,
                    child: _GalleryCard(
                      theme: theme,
                      controller: controller,
                      item: item,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GameTheme theme;
  final CatchController controller;
  final CatchGalleryItem item;

  const _GalleryCard({
    required this.theme,
    required this.controller,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final r = item.info;
    final drawer = controller.displayName(r.drawer);
    final status = r.correct ? '정답 +${r.points[r.guesser] ?? 0}' : '시간 끝';
    return Semantics(
      label: '${r.round}라운드, $drawer님이 그린 ${r.word}, $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: kCatchBoardAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: SketchPaperPainter()),
                    CustomPaint(
                      painter: CatchStaticStrokesPainter(item.strokes),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 5, 3, 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.round}. ${r.word}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(
                        size: 12.5,
                        color: Colors.white,
                        weight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    r.correct ? '✓' : '✗',
                    style: t.body(
                      size: 12.5,
                      color: r.correct
                          ? const Color(0xFFB9F6CA)
                          : const Color(0xFFFFC9C0),
                      weight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 2),
              child: Text(
                '$drawer · $status',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body(
                  size: 10.5,
                  color: Colors.white.withValues(alpha: 0.82),
                  weight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
