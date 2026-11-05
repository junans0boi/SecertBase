import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'zero_controller.dart';
import 'zero_hand.dart';
import 'zero_models.dart';
import 'zero_reveal.dart';
import 'zero_widgets.dart';

const _kGameType = 'zero';

const _kHowToLines = [
  '0~5 중 낼 손가락 수를 골라요.',
  '두 사람 손가락의 합계를 예측해요. 내 숫자보다 작은 합은 나올 수 없어서 고를 수 없어요.',
  '정확히 맞히면 2점, 둘 다 빗나가면 더 가까운 쪽이 1점이에요.',
  '5라운드 점수를 더해 승부! 동점이면 한 라운드씩 서든데스예요.',
  '한 라운드는 20초. 시간이 지나면 자동으로 내고, 3번 연속이면 기권패예요.',
];

/// 제로 2.0: 스포트라이트 쇼. 서버가 로비 시작과 함께 판을 만든다(시작 버튼 없음).
class ZeroScreen extends StatefulWidget {
  const ZeroScreen({super.key});

  @override
  State<ZeroScreen> createState() => _ZeroScreenState();
}

class _ZeroScreenState extends State<ZeroScreen> with TickerProviderStateMixin {
  static const GameTheme theme = GameTheme.showtime;

  final _c = ZeroController.instance;
  final _socket = SocketService();

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kZeroRevealDuration,
  )..addStatusListener(_onRevealStatus);
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  String? _gameId;
  int _shownRound = 0;
  ZeroRound? _revealing;
  int? _fingers;
  int? _guess;

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  int _toastSeq = 0;
  String? _toast;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.tap,
      GameSound.select,
      GameSound.confirm,
      GameSound.tick,
      GameSound.drumroll,
      GameSound.whoosh,
      GameSound.reveal,
      GameSound.sparkle,
      GameSound.pop,
      GameSound.warn,
      GameSound.win,
      GameSound.lose,
      GameSound.draw,
    ]);
    _c.addListener(_onState);
    _absorbState();
    _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'howto_zero_v2',
        theme: theme,
        title: '제로 규칙',
        emoji: '✋',
        lines: _kHowToLines,
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _reveal.dispose();
    _sway.dispose();
    super.dispose();
  }

  // ── 상태 변화 ────────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    setState(_absorbState);
  }

  /// 새 판이면 화면 상태를 비우고, 새로 공개된 라운드가 있으면 연출을 시작한다.
  void _absorbState() {
    final s = _c.state;
    if (s != null && s.gameId != _gameId) {
      final first = _gameId == null;
      _gameId = s.gameId;
      _shownRound = s.lastRound?.round ?? 0;
      _revealing = null;
      _reveal.reset();
      _fingers = null;
      _guess = null;
      if (!first && s.playing) _banner('새 판 시작!', '5라운드 승부');
    } else if (s != null &&
        _revealing == null &&
        s.lastRound != null &&
        s.lastRound!.round > _shownRound) {
      _startReveal(s.lastRound!);
    }
  }

  void _startReveal(ZeroRound r) {
    _revealing = r;
    _banner('공개!', null);
    HapticFeedback.mediumImpact();
    _reveal.forward(from: 0);
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final r = _revealing;
    if (r == null) return;
    final me = _c.me;
    final s = _c.state;
    setState(() {
      _shownRound = r.round;
      _revealing = null;
      _fingers = null;
      _guess = null;
      if (s == null) return;
      if (s.playing && s.suddenDeath && !r.suddenDeath) {
        _banner('마지막 한 판!', '동점이라 서든데스로 가요');
      }
      if (s.playing && (s.autoPicks[me] ?? 0) >= 2) {
        _toast = '한 번 더 시간이 지나면 기권패예요';
        _toastSeq++;
        GameSfx.instance.play(GameSound.warn);
      } else if (r.auto[me] == true) {
        _toast = '시간이 지나 자동으로 냈어요';
        _toastSeq++;
      }
      // 연출 중에 다음 라운드가 또 끝났으면 이어서 보여 준다.
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

  void _selectFingers(int n) {
    GameSfx.instance.play(GameSound.select);
    HapticFeedback.selectionClick();
    setState(() {
      _fingers = n;
      if (_guess != null && !zeroGuessOptions(n).contains(_guess)) {
        _guess = null;
      }
    });
  }

  void _selectGuess(int g) {
    GameSfx.instance.play(GameSound.tap);
    HapticFeedback.selectionClick();
    setState(() => _guess = g);
  }

  void _submit() {
    final f = _fingers;
    final g = _guess;
    if (f == null || g == null) return;
    GameSfx.instance.play(GameSound.confirm);
    HapticFeedback.mediumImpact();
    _c.pick(f, g);
  }

  void _help() => showGameHowTo(
    context,
    theme: theme,
    title: '제로 규칙',
    emoji: '✋',
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
        // 무대 조명: 공개 때 좁혀지며 주위가 어두워진다.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_reveal, _sway]),
              builder: (context, _) {
                final v = _reveal.value;
                final focus = _revealing == null
                    ? (s == null ? 0.3 : 0.0)
                    : ZeroRevealTimeline.span(
                            v,
                            ZeroRevealTimeline.focusStart,
                            ZeroRevealTimeline.focusEnd,
                          ) *
                          (1 - ZeroRevealTimeline.span(v, 0.92, 1));
                final sway = _revealing == null
                    ? Curves.easeInOut.transform(_sway.value) * 2 - 1
                    : 0.0;
                return CustomPaint(
                  painter: ZeroSpotlightPainter(
                    focus: focus,
                    sway: sway,
                    warm: theme.gold,
                  ),
                );
              },
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  GameTopBar(
                    theme: theme,
                    title: '제로',
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
                    _header(s, opp),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _reveal,
                      builder: (context, _) => ZeroScoreboard(
                        theme: theme,
                        state: s,
                        me: me,
                        opponent: opp,
                        myName: _c.displayName(me),
                        opponentName: _c.displayName(opp),
                        visibleRounds: _visibleRounds(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: revealing
                          ? ZeroRevealStage(
                              theme: theme,
                              round: _revealing!,
                              me: me,
                              opponent: opp,
                              nameOf: _c.displayName,
                              progress: _reveal,
                            )
                          : _stage(s, opp),
                    ),
                    if (!revealing && s.playing) _controls(s),
                    _footer(me),
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
          child: GameTurnBanner(
            theme: theme,
            id: _bannerId,
            text: _bannerText,
            sub: _bannerSub,
            hold: const Duration(milliseconds: 650),
          ),
        ),
        Positioned(
          top: 100,
          right: 24,
          child: ReactionBubble(
            theme: theme,
            forPlayer: opp,
            gameType: _kGameType,
          ),
        ),
        Positioned(
          bottom: 58,
          left: 24,
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

  int _visibleRounds() {
    final r = _revealing;
    if (r == null) return 1 << 20;
    return _reveal.value >= ZeroRevealTimeline.points ? r.round : r.round - 1;
  }

  Widget _header(ZeroState s, String? opp) {
    final oppDone = _c.opponentSubmitted;
    final waitingOnOpp = s.playing && _revealing == null && !oppDone;
    return Row(
      children: [
        Expanded(
          child: PlayerBadge(
            theme: theme,
            emoji: _c.emojiOf(opp),
            name: _c.displayName(opp),
            subtitle: !s.playing || _revealing != null
                ? null
                : oppDone
                ? '냈어요!'
                : '고르는 중…',
            active: waitingOnOpp,
            compact: true,
            align: CrossAxisAlignment.start,
          ),
        ),
        const SizedBox(width: 6),
        s.suddenDeath
            ? GameChip(
                theme: theme,
                label: '마지막 한 판!',
                leading: '🔥',
                color: theme.accent,
                emphasized: true,
              )
            : GameChip(
                theme: theme,
                label: '라운드 ${s.round.clamp(1, s.maxRounds)}/${s.maxRounds}',
                leading: '🎤',
              ),
        const SizedBox(width: 6),
        TurnTimerRing(
          theme: theme,
          deadline: s.playing && _revealing == null ? _c.deadline : null,
          size: 42,
          tickSound: s.playing && !_c.iSubmitted,
        ),
      ],
    );
  }

  Widget _stage(ZeroState s, String? opp) {
    final me = _c.me;
    if (!s.playing) {
      // 끝난 판: 마지막 라운드의 두 손을 펼쳐 둔다.
      final last = s.lastRound;
      return Row(
        children: [
          Expanded(
            child: _StageHand(
              theme: theme,
              label: _c.displayName(me),
              fingers: (last?.fingers[me] ?? 0).toDouble(),
              color: theme.me,
              mirrored: false,
              dim: false,
            ),
          ),
          Expanded(
            child: _StageHand(
              theme: theme,
              label: _c.displayName(opp),
              fingers: (last?.fingers[opp] ?? 0).toDouble(),
              color: theme.opponent,
              mirrored: true,
              dim: false,
            ),
          ),
        ],
      );
    }
    final mine = _c.iSubmitted ? _c.myPick?.fingers : _fingers;
    final oppDone = _c.opponentSubmitted;
    return Row(
      children: [
        Expanded(
          child: _StageHand(
            theme: theme,
            label: mine == null ? '내 손' : '내 손 $mine',
            fingers: (mine ?? 0).toDouble(),
            color: theme.me,
            mirrored: false,
            dim: mine == null,
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _sway,
            builder: (context, child) => Transform.rotate(
              angle: oppDone
                  ? 0
                  : (Curves.easeInOut.transform(_sway.value) * 2 - 1) * 0.05,
              child: child,
            ),
            child: _StageHand(
              theme: theme,
              label: oppDone ? '준비 완료!' : '고르는 중…',
              fingers: 0,
              color: theme.opponent,
              mirrored: true,
              dim: !oppDone,
              mystery: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(ZeroState s) {
    if (_c.iSubmitted) {
      final p = _c.myPick;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GamePanel(
          theme: theme,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              ZeroHand(
                fingers: (p?.fingers ?? 0).toDouble(),
                sleeve: theme.me,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p == null ? '냈어요!' : '내 손 ${p.fingers} · 예측 ${p.guess}',
                      style: theme.display(size: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _c.opponentSubmitted ? '상대도 냈어요. 곧 공개!' : '상대가 고르는 중이에요…',
                      style: theme.body(size: 13, color: theme.subInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final f = _fingers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GamePanel(
        theme: theme,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('낼 손가락', style: theme.body(size: 12.5, color: theme.subInk)),
            const SizedBox(height: 6),
            ZeroFingerRow(theme: theme, selected: f, onSelect: _selectFingers),
            const SizedBox(height: 10),
            Text(
              f == null ? '합계 예측' : '합계 예측 · $f ~ ${f + kZeroMaxFingers}',
              style: theme.body(size: 12.5, color: theme.subInk),
            ),
            const SizedBox(height: 6),
            ZeroGuessRow(
              theme: theme,
              fingers: f,
              selected: _guess,
              onSelect: _selectGuess,
            ),
            const SizedBox(height: 10),
            GamePrimaryButton(
              theme: theme,
              label: '제출!',
              icon: Icons.back_hand_rounded,
              height: 50,
              onPressed: f != null && _guess != null && !_c.sending
                  ? _submit
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(String? me) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: PlayerBadge(
              theme: theme,
              emoji: _c.emojiOf(me),
              name: _c.displayName(me),
              isMe: true,
              compact: true,
              align: CrossAxisAlignment.start,
            ),
          ),
          ReactionButton(theme: theme, gameType: _kGameType),
        ],
      ),
    );
  }

  Widget _result(ZeroState s, String? me, String? opp) {
    final res = s.result;
    final outcome = res == null || res.draw
        ? GameOutcome.draw
        : res.winner == me
        ? GameOutcome.win
        : GameOutcome.lose;
    final my = s.scores[me] ?? 0;
    final their = s.scores[opp] ?? 0;
    final sdRounds = s.history.where((r) => r.suddenDeath).length;
    final reason = switch (res?.reason) {
      'sudden_death' => '서든데스 $sdRounds라운드째에 승부가 났어요 · $my : $their',
      'draw_cap' => '서든데스까지 동점이라 무승부예요 · $my : $their',
      'forfeit' =>
        res?.winner == me ? '상대가 연속 3번 시간을 넘겨 기권했어요' : '연속 3번 시간을 넘겨 기권패했어요',
      'both_away' => '둘 다 자리를 비워 무승부예요',
      _ => '5라운드 합산 $my : $their',
    };
    return GameResultOverlay(
      theme: theme,
      outcome: outcome,
      reason: reason,
      series: s.series,
      me: me,
      resultId: s.gameId,
      details: ZeroScoreboard(
        theme: theme,
        state: s,
        me: me,
        opponent: opp,
        myName: _c.displayName(me),
        opponentName: _c.displayName(opp),
        visibleRounds: 1 << 20,
      ),
      onRematch: () => _socket.requestRestart(_kGameType),
      rematchWaiting: _socket.restartWaiting,
    );
  }
}

class _StageHand extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final double fingers;
  final Color color;
  final bool mirrored;
  final bool dim;
  final bool mystery;

  const _StageHand({
    required this.theme,
    required this.label,
    required this.fingers,
    required this.color,
    required this.mirrored,
    required this.dim,
    this.mystery = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ZeroHand(
                    fingers: fingers,
                    sleeve: color,
                    mirrored: mirrored,
                    size: 130,
                    dim: dim,
                  ),
                ),
              ),
              if (mystery)
                Text(
                  '?',
                  style: theme
                      .display(size: 40, color: Colors.white)
                      .copyWith(
                        shadows: [Shadow(color: color, blurRadius: 14)],
                      ),
                ),
            ],
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.body(size: 13, color: color, weight: FontWeight.w800),
        ),
      ],
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
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: (sway.value - 0.5) * 0.2,
                  child: ZeroHand(fingers: 5, sleeve: theme.accent, size: 110),
                ),
                const SizedBox(height: 14),
                Text('판을 준비하는 중', style: theme.display(size: 24)),
                const SizedBox(height: 4),
                Text(
                  '곧 무대 조명이 켜져요',
                  style: theme.body(size: 13, color: theme.subInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
