import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'penalty_controller.dart';
import 'penalty_controls.dart';
import 'penalty_hud.dart';
import 'penalty_models.dart';
import 'penalty_pitch.dart';

const _howToTitle = '패널티킥 하는 법';
const _howToLines = [
  '골대 칸 중 하나를 골라요. 키퍼가 같은 칸을 고르면 막혀요!',
  '칸을 누르고 큰 버튼(슛!·막기!)으로 확정해요. 20초가 지나면 자동으로 골라져요.',
  '5번씩 번갈아 차서 골이 많으면 승리! 동점이면 한 번씩 더 차요.',
];

/// 패널티킥 2.0 — 선셋 스타디움. 서버가 판을 만들고 이 화면은 보여 주고 고르기만 한다.
class PenaltyGameScreen extends StatefulWidget {
  const PenaltyGameScreen({super.key});

  @override
  State<PenaltyGameScreen> createState() => _PenaltyGameScreenState();
}

class _PenaltyGameScreenState extends State<PenaltyGameScreen>
    with TickerProviderStateMixin {
  static const _theme = GameTheme.sunsetStadium;
  final _c = PenaltyController.instance;
  final _socket = SocketService();

  late final AnimationController _shot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  String? _gameId;
  int _shownRounds = 0;
  int? _lastRound;
  int? _selected;
  int _lastKicks = 0;
  PenaltyRound? _playback;
  bool _kickFired = false;
  bool _impactFired = false;

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  Color? _bannerColor;
  Object? _confettiId;
  Object? _toastId;
  String? _toast;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.whistle,
      GameSound.kick,
      GameSound.net,
      GameSound.cheer,
      GameSound.aww,
      GameSound.save,
      GameSound.select,
      GameSound.confirm,
      GameSound.tick,
      GameSound.win,
      GameSound.lose,
      GameSound.draw,
    ]);
    _shot.addListener(_onShotTick);
    _shot.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishPlayback();
    });
    _c.addListener(_onState);
    _adopt(_c.state, initial: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.sync();
      showHowToOnce(
        context,
        prefKey: 'penalty_tutorial_seen',
        theme: _theme,
        title: _howToTitle,
        lines: _howToLines,
        emoji: '⚽',
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _shot.dispose();
    _idle.dispose();
    super.dispose();
  }

  // ── 상태 흐름 ────────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    setState(() => _adopt(_c.state));
  }

  void _adopt(PenaltyState? s, {bool initial = false}) {
    if (s == null) return;
    if (s.gameId != _gameId) {
      _gameId = s.gameId;
      // 들어오기 전의 킥은 다시 재생하지 않는다.
      _shownRounds = s.rounds.length;
      _playback = null;
      _shot.reset();
      _selected = null;
      _lastRound = s.round;
      _lastKicks = s.rounds.length;
      if (s.rounds.isEmpty && s.playing) {
        final first = s.firstKicker ?? s.kicker;
        GameSfx.instance.play(GameSound.whistle);
        _banner(
          '경기 시작!',
          first == _c.me ? '내가 먼저 차요' : '상대가 먼저 차요',
          _theme.accent,
        );
      }
    }
    // 킥 하나가 끝날 때마다(역할이 바뀌므로) 고른 칸을 비운다. round는 두 킥을 묶어 센다.
    final kicks = s.rounds.length;
    if (_lastRound != s.round || _lastKicks != kicks) {
      _lastRound = s.round;
      _lastKicks = kicks;
      _selected = null;
    }
    if (!initial) _maybeStartPlayback(s);
  }

  void _maybeStartPlayback(PenaltyState s) {
    if (_playback != null || s.rounds.length <= _shownRounds) return;
    // 여러 킥이 한꺼번에 왔으면(재접속 등) 마지막 킥만 보여 준다.
    if (s.rounds.length - _shownRounds > 1) _shownRounds = s.rounds.length - 1;
    _playback = s.rounds[_shownRounds];
    _kickFired = false;
    _impactFired = false;
    GameSfx.instance.play(GameSound.whistle, volume: 0.7);
    _shot.forward(from: 0);
  }

  void _onShotTick() {
    final v = _shot.value;
    if (!_kickFired && v >= kPenaltyKickAt) {
      _kickFired = true;
      GameSfx.instance.play(GameSound.kick);
    }
    if (!_impactFired && v >= kPenaltyImpactAt) _impact();
  }

  void _impact() {
    final pb = _playback;
    if (pb == null || _impactFired) return;
    _impactFired = true;
    final me = _c.me;
    final kickerName = pb.kicker == me ? '나' : _c.displayName(pb.kicker);
    final keeperName = pb.keeper == me ? '나' : _c.displayName(pb.keeper);
    if (pb.isGoal) {
      GameSfx.instance.play(GameSound.net);
      GameSfx.instance.play(GameSound.cheer);
      _banner(
        '골!',
        pb.kicker == me ? '멋진 슛이에요!' : '$kickerName의 슛이 들어갔어요',
        pb.kicker == me ? _theme.me : _theme.opponent,
      );
      if (pb.kicker == me) _confettiId = 'goal-$_gameId-${pb.round}';
    } else {
      GameSfx.instance.play(GameSound.save);
      GameSfx.instance.play(GameSound.aww);
      _banner(
        '나이스 세이브!',
        pb.keeper == me
            ? '내가 막았어요!'
            : '$keeperName${josa(keeperName, '이', '가')} 막았어요',
        pb.keeper == me ? _theme.me : _theme.opponent,
      );
      if (pb.keeper == me) _confettiId = 'save-$_gameId-${pb.round}';
    }
    if ((pb.kicker == me && pb.autoKicker) ||
        (pb.keeper == me && pb.autoKeeper)) {
      final picks = _c.state?.autoPicks[me] ?? 0;
      _toastId = 'auto-$_gameId-${pb.round}';
      _toast = picks >= 2
          ? '시간이 지나 자동으로 골랐어요. 한 번 더 지나면 기권패예요!'
          : '시간이 지나 자동으로 골랐어요';
    }
    if (mounted) setState(() {});
  }

  void _finishPlayback() {
    if (_playback == null) return;
    if (!_impactFired) _impact();
    _shownRounds += 1;
    _playback = null;
    _shot.reset();
    final s = _c.state;
    if (s != null) _maybeStartPlayback(s);
    if (mounted) setState(() {});
  }

  void _skip() => _finishPlayback();

  void _banner(String text, String? sub, Color color) {
    _bannerId = Object();
    _bannerText = text;
    _bannerSub = sub;
    _bannerColor = color;
  }

  void _select(int cell) {
    setState(() => _selected = cell);
  }

  void _confirm() {
    final cell = _selected;
    if (cell == null) return;
    GameSfx.instance.play(GameSound.confirm);
    _c.submit(cell);
  }

  void _showHelp() => showGameHowTo(
    context,
    theme: _theme,
    title: _howToTitle,
    lines: _howToLines,
    emoji: '⚽',
  );

  // ── 화면 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: 'penalty',
        child: GameBackdrop(
          theme: t,
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
    final t = _theme;
    final s = _c.state;
    final topBar = GameTopBar(
      theme: t,
      title: '패널티킥',
      gameType: 'penalty',
      canRestart: true,
      restartWaiting: _socket.restartWaiting,
      onRequestRestart: () => _socket.requestRestart('penalty'),
      onHelp: _showHelp,
    );
    if (s == null) {
      return Column(
        children: [
          topBar,
          Expanded(
            child: Center(
              child: GamePanel(
                theme: t,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚽', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    Text('판을 준비하는 중…', style: t.display(size: 20)),
                    const SizedBox(height: 6),
                    Text(
                      _c.syncedEmpty ? '로비에서 방장이 시작하면 바로 열려요' : '잠시만 기다려 주세요',
                      style: t.body(size: 13, color: t.subInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final me = _c.me ?? '';
    final opp = _c.opponent ?? '';
    final iAmPlayer = s.players.contains(me);
    final pb = _playback;
    final kickerId = pb?.kicker ?? s.kicker;
    final keeperId = pb?.keeper ?? s.keeper;
    final iAmKicker = s.kicker == me;
    final submitted = s.submitted.contains(me);
    final oppSubmitted = s.submitted.contains(opp);
    final canChoose =
        s.playing && iAmPlayer && pb == null && !submitted && !_c.submitting;
    final visibleRounds = (_shownRounds + (pb != null && _impactFired ? 1 : 0))
        .clamp(0, s.rounds.length);
    final showResult =
        s.finished && pb == null && _shownRounds >= s.rounds.length;
    Color colorOf(String id) => id == me ? t.me : t.opponent;

    final mySide = PenaltySide(
      id: me,
      name: _c.displayName(me),
      emoji: _c.emojiOf(me),
      isMe: true,
    );
    final oppSide = PenaltySide(
      id: opp,
      name: _c.displayName(opp),
      emoji: _c.emojiOf(opp),
      isMe: false,
    );

    String status;
    if (!iAmPlayer) {
      status = '구경하는 중이에요';
    } else if (s.finished) {
      status = '경기가 끝났어요';
    } else if (pb != null) {
      status = '화면을 누르면 건너뛰어요';
    } else if (submitted || _c.submitting) {
      status = '골랐어요! 상대를 기다리는 중…';
    } else if (iAmKicker) {
      status = '내가 찰 차례! 어디로 찰까요?';
    } else {
      status = '내가 막을 차례! 어디를 막을까요?';
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                topBar,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PenaltyScoreboard(
                    theme: t,
                    state: s,
                    me: mySide,
                    opponent: oppSide,
                    visibleRounds: visibleRounds,
                    deadline: s.playing && pb == null ? _c.deadline : null,
                    tickSound: canChoose,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PenaltyHabitStrip(
                    theme: t,
                    cells: s.cells,
                    opponentKicks: s.rounds
                        .take(visibleRounds)
                        .where((r) => r.kicker == opp)
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PenaltyPitch(
                            theme: t,
                            cells: s.cells,
                            kicker: MascotLook(
                              emoji: _c.emojiOf(kickerId),
                              color: colorOf(kickerId),
                            ),
                            keeper: MascotLook(
                              emoji: _c.emojiOf(keeperId),
                              color: colorOf(keeperId),
                            ),
                            playback: pb,
                            progress: _shot,
                            idle: _idle,
                            selected: pb == null ? _selected : null,
                            zonesEnabled: canChoose,
                            selectColor: t.me,
                            iAmKicker: iAmKicker,
                            onZoneTap: (c) {
                              GameSfx.instance.play(GameSound.select);
                              _select(c);
                            },
                            onSkip: _skip,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 10,
                          child: ReactionBubble(
                            theme: t,
                            forPlayer: opp,
                            gameType: 'penalty',
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: ReactionBubble(
                            theme: t,
                            forPlayer: me,
                            gameType: 'penalty',
                          ),
                        ),
                        if (oppSubmitted && s.playing && pb == null)
                          Positioned(
                            top: 8,
                            left: 10,
                            child: GameChip(
                              key: const Key('penalty_opp_ready'),
                              theme: t,
                              leading: '✅',
                              label: '상대는 골랐어요',
                              color: t.opponent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          key: const Key('penalty_status'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body(size: 14, weight: FontWeight.w800),
                        ),
                      ),
                      ReactionButton(theme: t, gameType: 'penalty'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 0, 9, 10),
                  child: PenaltyControls(
                    theme: t,
                    cells: s.cells,
                    selected: pb == null ? _selected : null,
                    enabled: canChoose,
                    iAmKicker: iAmKicker,
                    waiting: s.playing && (submitted || _c.submitting),
                    color: t.me,
                    onSelect: _select,
                    onConfirm: _confirm,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: GameTurnBanner(
            theme: t,
            id: _bannerId,
            text: _bannerText,
            sub: _bannerSub,
            color: _bannerColor,
          ),
        ),
        Positioned.fill(
          child: ConfettiBurst(
            trigger: _confettiId,
            colors: [t.me, t.gold, t.opponent, Colors.white, t.accent],
          ),
        ),
        Positioned(
          top: 56,
          left: 0,
          right: 0,
          child: Center(
            child: GameToast(theme: t, id: _toastId, message: _toast),
          ),
        ),
        if (showResult) _result(s, me),
      ],
    );
  }

  Widget _result(PenaltyState s, String me) {
    final t = _theme;
    final r = s.result;
    final outcome = r == null || r.isDraw
        ? GameOutcome.draw
        : r.winner == me
        ? GameOutcome.win
        : GameOutcome.lose;
    final opp = _c.opponent;
    final score = '${s.scoreOf(me)} : ${s.scoreOf(opp)}';
    final sd = s.rounds.length > kPenaltyKicksPerPlayer * 2;
    final String reason;
    switch (r?.reason) {
      case 'forfeit':
        reason = outcome == GameOutcome.win
            ? '상대가 자리를 오래 비워 이겼어요'
            : '시간 초과가 3번 이어져 기권패가 되었어요';
      case 'abandoned':
        reason = '둘 다 자리를 비워 경기가 끝났어요';
      case 'draw':
        reason = '서든데스까지 $score 동점이에요';
      default:
        reason = sd ? '서든데스 끝에 $score' : '최종 점수 $score';
    }
    return Positioned.fill(
      child: GameResultOverlay(
        key: const Key('penalty_result'),
        theme: t,
        outcome: outcome,
        title: switch (outcome) {
          GameOutcome.win => '승리!',
          GameOutcome.lose => '아쉬운 패배',
          GameOutcome.draw => '무승부',
        },
        reason: reason,
        series: s.series,
        me: me,
        resultId: s.gameId,
        rematchWaiting: _socket.restartWaiting,
        onRematch: () => _socket.requestRestart('penalty'),
      ),
    );
  }
}
