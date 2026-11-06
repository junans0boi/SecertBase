/// 판이 끝났을 때 화면 전체를 덮는 결과 화면(블랙잭·도둑잡기 시안).
library;

import 'package:flutter/material.dart';

import '../../core/game_sfx/game_sfx.dart';
import 'game_result_overlay.dart' show GameOutcome;
import 'game_theme.dart';
import 'modern_kit.dart';

/// 결과 화면: 바 · 가운데 내용(스크롤 가능) · 아래 "나가기 / 재대결".
/// 재대결은 상대 동의 절차를 쓰는 [onRematch]로만 한다.
class ModResultView extends StatefulWidget {
  final GameTheme theme;
  final ModBackdropKind backdrop;
  final String gameType;
  final GameOutcome outcome;
  final Widget hero;
  final String title;
  final Color? titleColor;
  final double titleSize;
  final String? why;

  /// 사유 아래·전적 위에 끼우는 내용(마지막 손패 등).
  final Widget? extra;
  final Map<String, dynamic>? series;
  final String? me;

  /// 맨 아래 표(라운드 기록·최근 기록).
  final Widget? table;
  final VoidCallback? onRematch;
  final bool rematchWaiting;
  final VoidCallback? onExit;
  final VoidCallback? onHelp;

  /// 같은 결과로 다시 그려질 때 소리를 반복하지 않게 하는 식별자(예: gameId).
  final Object? resultId;

  const ModResultView({
    super.key,
    required this.theme,
    required this.backdrop,
    required this.gameType,
    required this.outcome,
    required this.hero,
    required this.title,
    this.titleColor,
    this.titleSize = 30,
    this.why,
    this.extra,
    this.series,
    this.me,
    this.table,
    this.onRematch,
    this.rematchWaiting = false,
    this.onExit,
    this.onHelp,
    this.resultId,
  });

  @override
  State<ModResultView> createState() => _ModResultViewState();
}

class _ModResultViewState extends State<ModResultView> {
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
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Material(
      color: t.backdrop.last,
      child: ModBackdrop(
        theme: t,
        kind: widget.backdrop,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  ModTopBar(
                    theme: t,
                    title: '결과',
                    gameType: widget.gameType,
                    onBack: widget.onExit,
                    onHelp: widget.onHelp,
                    showMenu: false,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: box.maxHeight - 20,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              widget.hero,
                              const SizedBox(height: 16),
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: t
                                    .display(
                                      size: widget.titleSize,
                                      color: widget.titleColor,
                                    )
                                    .copyWith(
                                      letterSpacing: widget.titleSize > 40
                                          ? widget.titleSize * 0.04
                                          : 0,
                                    ),
                              ),
                              if (widget.why != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.why!,
                                  textAlign: TextAlign.center,
                                  style: t.body(
                                    size: 15,
                                    color: t.subInk,
                                    weight: FontWeight.w400,
                                  ),
                                ),
                              ],
                              if (widget.extra != null) ...[
                                const SizedBox(height: 20),
                                widget.extra!,
                              ],
                              if (widget.series != null) ...[
                                const SizedBox(height: 18),
                                ModSeriesPill(
                                  theme: t,
                                  series: widget.series,
                                  me: widget.me,
                                ),
                              ],
                              if (widget.table != null) ...[
                                const SizedBox(height: 20),
                                widget.table!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ModButton(
                            theme: t,
                            label: '나가기',
                            kind: ModButtonKind.outline,
                            onPressed:
                                widget.onExit ??
                                () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        if (widget.onRematch != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ModButton(
                              theme: t,
                              label: widget.rematchWaiting
                                  ? '상대의 수락을 기다리는 중…'
                                  : '재대결',
                              onPressed: widget.rematchWaiting
                                  ? null
                                  : widget.onRematch,
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
        ),
      ),
    );
  }
}
