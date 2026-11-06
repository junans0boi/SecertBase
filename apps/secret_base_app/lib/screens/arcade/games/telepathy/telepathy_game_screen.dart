import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'telepathy_controller.dart';
import 'telepathy_models.dart';
import 'telepathy_result.dart';
import 'telepathy_widgets.dart';

const _kGameType = 'telepathy';

/// 공개 연출 길이(서버의 revealMs 3.5초보다 조금 짧게).
const Duration kTelepathyRevealDuration = Duration(milliseconds: 3300);

const _kHowToLines = [
  '매 문제마다 둘 중 마음에 드는 쪽을 몰래 골라요.',
  '두 사람이 같은 쪽을 고르면 "통했어요!" 별이 하나 켜져요.',
  '연속으로 통하면 🔥 연속 기록이 쌓여요.',
  '한 문제는 15초. 시간이 지나면 그 문제는 엇갈린 걸로 넘어가요.',
  '연속 3문제를 고르지 않으면 판이 끝나요. 이기고 지는 건 없어요.',
];

/// 공개 연출 타임라인(0→1). 잠깐 멈춤 → 두 카드가 함께 뒤집힘 → 판정 → 빛줄기.
class TelepathyReveal {
  static const double flipStart = 0.10;
  static const double flipEnd = 0.38;
  static const double verdict = 0.42;
  static const double beamEnd = 0.68;
}

/// 텔레파시 2.0: 별빛 편지. 서버가 로비 시작과 함께 판을 만든다(시작 버튼 없음).
class TelepathyGameScreen extends StatefulWidget {
  const TelepathyGameScreen({super.key});

  @override
  State<TelepathyGameScreen> createState() => _TelepathyGameScreenState();
}

class _TelepathyGameScreenState extends State<TelepathyGameScreen>
    with TickerProviderStateMixin {
  static const GameTheme theme = GameTheme.starlight;

  final _c = TelepathyController.instance;
  final _socket = SocketService();

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kTelepathyRevealDuration,
  )..addStatusListener(_onRevealStatus);
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  String? _gameId;
  int _shownRound = 0;
  TelepathyRound? _revealing;
  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  int _toastSeq = 0;
  String? _toast;
  Object? _confettiId;
  final Set<int> _soundsPlayed = {};

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.tap,
      GameSound.select,
      GameSound.confirm,
      GameSound.tick,
      GameSound.warn,
      GameSound.whoosh,
      GameSound.cardFlip,
      GameSound.sparkle,
      GameSound.pop,
      GameSound.aww,
      GameSound.cheer,
      GameSound.win,
      GameSound.draw,
    ]);
    _reveal.addListener(_onRevealTick);
    _c.addListener(_onState);
    _absorbState();
    _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'howto_telepathy_v2',
        theme: theme,
        title: '텔레파시 규칙',
        emoji: '💫',
        lines: _kHowToLines,
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _reveal.removeListener(_onRevealTick);
    _reveal.dispose();
    _sway.dispose();
    super.dispose();
  }

  // ── 상태 변화 ────────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    setState(_absorbState);
  }

  /// 새 판이면 화면 상태를 비우고, 새로 공개된 문제가 있으면 연출을 시작한다.
  void _absorbState() {
    final s = _c.state;
    if (s == null) return;
    if (s.gameId != _gameId) {
      final first = _gameId == null;
      _gameId = s.gameId;
      _shownRound = s.lastRound?.round ?? 0;
      _revealing = null;
      _confettiId = null;
      _soundsPlayed.clear();
      _reveal.reset();
      if (!first && s.playing) _banner('새 판 시작!', '${s.rounds}문제');
    } else if (_revealing == null &&
        s.lastRound != null &&
        s.lastRound!.round > _shownRound) {
      _startReveal(s.lastRound!);
    }
  }

  void _startReveal(TelepathyRound r) {
    _revealing = r;
    _soundsPlayed.clear();
    HapticFeedback.mediumImpact();
    _reveal.forward(from: 0);
  }

  /// 연출 진행에 맞춰 소리를 한 번씩만 낸다.
  void _onRevealTick() {
    final r = _revealing;
    if (r == null) return;
    final v = _reveal.value;
    void once(int key, double at, VoidCallback f) {
      if (v >= at && _soundsPlayed.add(key)) f();
    }

    once(0, 0.02, () => GameSfx.instance.play(GameSound.whoosh));
    once(
      1,
      TelepathyReveal.flipStart,
      () => GameSfx.instance.play(GameSound.cardFlip),
    );
    once(2, TelepathyReveal.verdict, () {
      if (r.matched) {
        GameSfx.instance.play(GameSound.sparkle);
        HapticFeedback.heavyImpact();
        if (mounted) setState(() => _confettiId = '${_gameId}_${r.round}');
        if (r.streak >= 3) GameSfx.instance.play(GameSound.cheer);
      } else {
        GameSfx.instance.play(r.timedOut ? GameSound.warn : GameSound.aww);
      }
    });
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final r = _revealing;
    if (r == null) return;
    final s = _c.state;
    setState(() {
      _shownRound = r.round;
      _revealing = null;
      if (s == null) return;
      final mine = s.timeouts[_c.me] ?? 0;
      if (s.playing && mine >= 2) {
        _toast = '한 번 더 안 고르면 판이 끝나요';
        _toastSeq++;
        GameSfx.instance.play(GameSound.warn);
      } else if (s.playing && r.picks[_c.me] == null) {
        _toast = '시간이 지나 넘어갔어요';
        _toastSeq++;
      }
      // 연출 중에 다음 문제가 또 끝났으면 이어서 보여 준다.
      final last = s.lastRound;
      if (last != null && last.round > _shownRound) _startReveal(last);
    });
  }

  void _banner(String text, String? sub) {
    _bannerText = text;
    _bannerSub = sub;
    _bannerId = Object();
  }

  // ── 조작 ─────────────────────────────────────────────────────────────────

  void _pick(String choice) {
    if (_revealing != null) return;
    GameSfx.instance.play(GameSound.confirm);
    HapticFeedback.selectionClick();
    _c.pick(choice);
  }

  void _help() => showGameHowTo(
    context,
    theme: theme,
    title: '텔레파시 규칙',
    emoji: '💫',
    lines: _kHowToLines,
  );

  // ── 그리기 ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backdrop.last,
      body: GameMenuListener(
        gameType: _kGameType,
        child: GameBackdrop(
          theme: theme,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([_c, _socket]),
              builder: (context, _) => _body(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final s = _c.state;
    final me = _c.me;
    final opp = s?.opponentOf(me) ?? _socket.partnerId;
    final revealing = _revealing != null;
    final showResult = s != null && s.finished && !revealing;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  GameTopBar(
                    theme: theme,
                    title: '텔레파시',
                    gameType: _kGameType,
                    canRestart: true,
                    restartWaiting: _socket.restartWaiting,
                    onRequestRestart: () => _socket.requestRestart(_kGameType),
                    onHelp: _help,
                  ),
                  if (s == null)
                    Expanded(
                      child: _Preparing(theme: theme, sway: _sway),
                    )
                  else ...[
                    _bond(s, me, opp),
                    const SizedBox(height: 4),
                    _progress(s),
                    const SizedBox(height: 8),
                    Expanded(child: _stage(s, me, opp)),
                    _footer(),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 58,
          left: 0,
          right: 0,
          child: Center(
            child: GameToast(theme: theme, id: _toastSeq, message: _toast),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiBurst(
              trigger: _confettiId,
              colors: [theme.gold, theme.accent, theme.me, Colors.white],
              count: 46,
            ),
          ),
        ),
        Positioned.fill(
          child: GameTurnBanner(
            theme: theme,
            id: _bannerId,
            text: _bannerText,
            sub: _bannerSub,
            hold: const Duration(milliseconds: 650),
          ),
        ),
        Positioned(
          top: 126,
          right: 18,
          child: ReactionBubble(
            theme: theme,
            forPlayer: opp,
            gameType: _kGameType,
          ),
        ),
        Positioned(
          top: 126,
          left: 18,
          child: ReactionBubble(
            theme: theme,
            forPlayer: me,
            gameType: _kGameType,
          ),
        ),
        if (showResult) Positioned.fill(child: _result(s, me, opp)),
      ],
    );
  }

  // 위쪽: 나 ── (타이머 / 판정) ── 상대. 통하면 빛줄기가 뻗는다.
  Widget _bond(TelepathyState s, String? me, String? opp) {
    final r = _revealing;
    final iPicked = _c.iPicked;
    final oppPicked = _c.partnerPicked;
    String? myStatus;
    String? oppStatus;
    if (s.playing && r == null) {
      myStatus = iPicked ? '골랐어요' : '고르는 중…';
      oppStatus = oppPicked ? '골랐어요' : '고르는 중…';
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _sway]),
      builder: (context, _) {
        final v = _reveal.value;
        final beam = r != null && r.matched
            ? Curves.easeOutCubic.transform(
                telepathySpan(
                  v,
                  TelepathyReveal.verdict,
                  TelepathyReveal.beamEnd,
                ),
              )
            : 0.0;
        Widget center;
        if (r != null && v >= TelepathyReveal.verdict) {
          center = _verdictBadge(r);
        } else if (r == null && s.playing) {
          center = TurnTimerRing(
            theme: theme,
            deadline: _c.deadline,
            size: 46,
            tickSound: !iPicked,
          );
        } else {
          center = const SizedBox(width: 46, height: 46);
        }
        return SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TelepathyAvatar(
                theme: theme,
                emoji: _c.emojiOf(me),
                name: _c.displayName(me),
                mine: true,
                status: myStatus,
                glowing: (r == null && iPicked) || (r != null && beam > 0),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: TelepathyBeamPainter(
                          theme: theme,
                          beam: beam,
                          shimmer: (_sway.value + v * 3) % 1.0,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 1,
                      child: Center(child: center),
                    ),
                  ],
                ),
              ),
              TelepathyAvatar(
                theme: theme,
                emoji: _c.emojiOf(opp),
                name: _c.displayName(opp),
                mine: false,
                status: oppStatus,
                glowing: (r == null && oppPicked) || (r != null && beam > 0),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _verdictBadge(TelepathyRound r) {
    final t = theme;
    final String text;
    final Color color;
    if (r.matched) {
      text = r.streak >= 2 ? '🔥 ${r.streak}연속' : '통했어요';
      color = t.gold;
    } else {
      text = r.timedOut ? '시간 초과' : '엇갈림';
      color = t.subInk;
    }
    return Container(
      height: 46,
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF16143F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.6),
        boxShadow: r.matched
            ? [BoxShadow(color: t.gold.withValues(alpha: 0.6), blurRadius: 16)]
            : null,
      ),
      child: Text(
        text,
        maxLines: 1,
        style: t.body(size: 13, color: color, weight: FontWeight.w900),
      ),
    );
  }

  // 진행 점 + 통한 수 + 연속.
  Widget _progress(TelepathyState s) {
    final r = _revealing;
    // 연출 중에는 방금 공개된 문제를 아직 점에 넣지 않는다.
    final visible = r == null
        ? s.history
        : s.history.where((h) => h.round < r.round).toList();
    final results = [for (final h in visible) h.matched];
    final cur = r == null ? s.round : r.round;
    final score = visible.where((h) => h.matched).length;
    final streak = visible.isEmpty ? 0 : visible.last.streak;
    return Column(
      children: [
        TelepathyProgressDots(
          theme: theme,
          total: s.rounds,
          current: cur,
          results: results,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameChip(
              theme: theme,
              label: '${cur.clamp(1, s.rounds)}/${s.rounds}번째',
              leading: '💌',
            ),
            const SizedBox(width: 6),
            GameChip(
              theme: theme,
              label: '통한 $score',
              leading: '⭐',
              emphasized: score > 0,
            ),
            if (streak >= 2) ...[
              const SizedBox(width: 6),
              GameChip(
                theme: theme,
                label: '$streak연속',
                leading: '🔥',
                color: theme.accent,
                emphasized: true,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _stage(TelepathyState s, String? me, String? opp) {
    final r = _revealing;
    final TelepathyQuestion? q =
        r?.question ?? s.question ?? s.lastRound?.question;
    if (q == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 360;
        return Column(
          children: [
            SizedBox(
              height: compact ? 26 : 34,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${q.categoryLabel} · 더 끌리는 쪽은?',
                    style: theme.display(size: compact ? 16 : 19),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${s.gameId}_${q.id}'),
                  child: _cards(s, q, r, me, opp),
                ),
              ),
            ),
            _caption(s, r),
          ],
        );
      },
    );
  }

  Widget _cards(
    TelepathyState s,
    TelepathyQuestion q,
    TelepathyRound? r,
    String? me,
    String? opp,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _sway]),
      builder: (context, _) {
        final v = _reveal.value;
        final flip = r == null
            ? 0.0
            : Curves.easeInOutCubic.transform(
                telepathySpan(
                  v,
                  TelepathyReveal.flipStart,
                  TelepathyReveal.flipEnd,
                ),
              );
        final verdict = r != null && v >= TelepathyReveal.verdict;
        TelepathyCard card(String letter) {
          final marks = <TelepathyMark>[];
          if (r != null) {
            if (r.picks[me] == letter) {
              marks.add(
                TelepathyMark(
                  emoji: _c.emojiOf(me).isEmpty ? '🙂' : _c.emojiOf(me),
                  mine: true,
                  name: _c.displayName(me),
                ),
              );
            }
            if (r.picks[opp] == letter) {
              marks.add(
                TelepathyMark(
                  emoji: _c.emojiOf(opp).isEmpty ? '🙂' : _c.emojiOf(opp),
                  mine: false,
                  name: _c.displayName(opp),
                ),
              );
            }
          }
          final mine = _c.myPick;
          final mode = r != null
              ? TelepathyCardMode.idle
              : !_c.iPicked
              ? TelepathyCardMode.idle
              : mine == letter
              ? TelepathyCardMode.picked
              : TelepathyCardMode.dimmed;
          return TelepathyCard(
            theme: theme,
            letter: letter,
            emoji: q.emojiOf(letter),
            text: q.textOf(letter),
            mode: mode,
            flip: flip,
            marks: marks,
            glow: r != null && r.matched && marks.length == 2 && verdict,
            faded: r != null && marks.isEmpty,
            onTap: r == null && s.playing && !_c.iPicked
                ? () => _pick(letter)
                : null,
          );
        }

        final lit = r != null && r.matched && verdict;
        return Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                Expanded(child: Align(child: card('A'))),
                const SizedBox(height: 34),
                Expanded(child: Align(child: card('B'))),
              ],
            ),
            TelepathyVsMedallion(
              theme: theme,
              label: lit ? '💞' : null,
              lit: lit,
              pulse: _sway.value,
            ),
          ],
        );
      },
    );
  }

  Widget _caption(TelepathyState s, TelepathyRound? r) {
    final String text;
    Color color = theme.subInk;
    if (r != null) {
      if (_reveal.value < TelepathyReveal.verdict) {
        text = '두 사람의 선택을 공개해요…';
      } else if (r.matched) {
        text = r.streak >= 2 ? '통했어요! ${r.streak}문제 연속이에요' : '통했어요! 마음이 같네요';
        color = theme.gold;
      } else if (r.timedOut) {
        text = '시간이 지나 이번 문제는 넘어가요';
      } else {
        text = '이번엔 엇갈렸어요. 다음엔 통할 거예요';
      }
    } else if (!s.playing) {
      text = '';
    } else if (!_c.iPicked) {
      text = '마음이 끌리는 쪽을 눌러 주세요';
    } else if (_c.partnerPicked) {
      text = '둘 다 골랐어요. 곧 공개!';
      color = theme.gold;
    } else {
      text = '상대가 고르는 중이에요…';
    }
    return SizedBox(
      height: 40,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: theme.body(size: 13.5, color: color, weight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _footer() {
    return SizedBox(
      height: 50,
      child: Align(
        alignment: Alignment.centerRight,
        child: ReactionButton(theme: theme, gameType: _kGameType),
      ),
    );
  }

  Widget _result(TelepathyState s, String? me, String? opp) {
    return TelepathyResultCard(
      theme: theme,
      state: s,
      me: me,
      partner: opp,
      nameOf: _c.displayName,
      myEmoji: _c.emojiOf(me),
      partnerEmoji: _c.emojiOf(opp),
      onRematch: () => _socket.requestRestart(_kGameType),
      rematchWaiting: _socket.restartWaiting,
    );
  }
}

class _Preparing extends StatelessWidget {
  final GameTheme theme;
  final Animation<double> sway;

  const _Preparing({required this.theme, required this.sway});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sway,
      builder: (context, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: (sway.value - 0.5) * 0.3,
              child: const Text('💌', style: TextStyle(fontSize: 76)),
            ),
            const SizedBox(height: 14),
            Text('판을 준비하는 중', style: theme.display(size: 24)),
            const SizedBox(height: 4),
            Text(
              '별빛 편지를 쓰고 있어요',
              style: theme.body(size: 13, color: theme.subInk),
            ),
          ],
        ),
      ),
    );
  }
}
