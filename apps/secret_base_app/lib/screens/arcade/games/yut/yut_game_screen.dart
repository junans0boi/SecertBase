import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../core/yut_audio.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'yut_board_view.dart';
import 'yut_controller.dart';
import 'yut_models.dart';
import 'yut_figures.dart';
import 'yut_palette.dart';
import 'yut_result_view.dart';
import 'yut_sticks.dart';
import 'yut_ui.dart';
import 'yut_stat_bars.dart';

/// 윷놀이 2.0 — 햇살 풀밭(GameTheme.meadow).
/// 서버가 로비 시작과 함께 판을 만든다. 이 화면에는 시작 버튼이 없다.
class YutGameScreen extends StatefulWidget {
  const YutGameScreen({super.key});

  @override
  State<YutGameScreen> createState() => _YutGameScreenState();
}

class _YutGameScreenState extends State<YutGameScreen>
    with TickerProviderStateMixin {
  YutPalette get _pal => YutPalette.forTheme(c.view?.theme);
  GameTheme get _theme => _pal.theme;
  static const _sounds = [
    GameSound.yutToss,
    GameSound.yutClack,
    GameSound.yutDrum,
    GameSound.yutGong,
    GameSound.yutKkwaeng,
    GameSound.yutCapture,
    GameSound.yutGoal,
    GameSound.yutStack,
    GameSound.yutStep,
    GameSound.turnMine,
    GameSound.tick,
    GameSound.warn,
    GameSound.select,
    GameSound.confirm,
    GameSound.sparkle,
    GameSound.start,
    GameSound.win,
    GameSound.lose,
  ];

  static const _howToLines = [
    '윷가락 네 개를 던져요. 납작한 면이 많을수록 멀리 가요: 도 1칸, 개 2칸, 걸 3칸, 윷 4칸, 모 5칸. 표시 막대(붉은 ×)만 납작하면 빽도(한 칸 뒤로)예요.',
    '윷이나 모가 나오거나 상대 말을 잡으면 한 번 더 던져요.',
    '아래 던지기 칩을 고르고, 움직일 말을 누르면 가는 길이 붓으로 그려져요. 확인하고 "여기로 옮기기"를 눌러요. 같은 편 말이 만나면 업혀서 함께 가요.',
    '모·뒷모·찌모 모서리에 멈추면 지름길로 가요. 말을 모두 참먹이 너머로 먼저 보내면 승리!',
    '30초 안에 하지 않으면 자동으로 던지고 가장 알맞은 말을 옮겨요. 세 번 연속이면 기권패예요.',
  ];

  final YutController c = YutController.instance;
  final SocketService _socket = SocketService();

  final List<Timer> _timers = [];
  late final AnimationController _moveCtl = AnimationController(vsync: this);
  late final AnimationController _effectCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  // 연출 큐: 서버가 연달아 보낸 던지기·이동을 한 건씩 끝까지 보여 준다.
  final List<YutAction> _queue = [];
  bool _playing = false;
  YutThrow? _stage;
  int _stageSeq = 0;
  String? _stageBy;
  YutMoveAnim? _moveAnim;
  YutBoardEffect? _effect;
  int _goalBursts = 0;

  String? _seenGame;
  int _seenSeq = -1;
  int _seenNotice = 0;
  bool _wasMyTurn = false;
  int _syncRetries = 0;

  // 선택(칩 → 말 → 확정). 규칙은 서버 legalMoves가 정한다.
  int? _chip;
  int? _pieceId;
  int? _destTo;
  int? _destDir;

  Object? _pillId;
  String? _pillText;
  bool _pillStrong = false;
  Timer? _pillTimer;

  String? _resultFor;
  bool _showResult = false;
  bool _resultPending = false;

  final List<({int id, YutItemEffect effect})> _itemEffects = [];
  int _effectSeq = 0;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(_sounds);
    _seenNotice = c.noticeSeq;
    c.addListener(_onController);
    _seenGame = c.view?.gameId;
    _seenSeq = c.view?.seq ?? -1;
    _wasMyTurn = c.isMyTurn;
    if (c.result != null) {
      _resultFor = c.result!.gameId;
      _showResult = true;
    }
    c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'yut_howto_v2_seen',
        theme: YutPalette.daylight.theme,
        title: '윷놀이',
        emoji: '🎲',
        lines: _howToLines,
      );
    });
  }

  @override
  void dispose() {
    _pillTimer?.cancel();
    c.removeListener(_onController);
    for (final timer in _timers) {
      timer.cancel();
    }
    _moveCtl.dispose();
    _effectCtl.dispose();
    YutAudio.instance.stopBackground();
    super.dispose();
  }

  void _after(int ms, VoidCallback fn) {
    late final Timer timer;
    timer = Timer(Duration(milliseconds: ms), () {
      _timers.remove(timer);
      if (mounted) fn();
    });
    _timers.add(timer);
  }

  // ── 서버 상태 → 연출·소리 ──────────────────────────────────────────────
  void _onController() {
    if (!mounted) return;
    if (c.noticeSeq != _seenNotice) {
      _seenNotice = c.noticeSeq;
      if (c.notice != null) _showToast(c.notice!);
    }
    final v = c.view;
    if (v == null && c.result == null && c.syncStatus == 'no_game') {
      // 로비가 막 끝났을 수 있으니 몇 번 조용히 다시 묻는다.
      if (_syncRetries < 3) {
        _syncRetries++;
        _after(1800, () {
          if (c.view == null) c.sync();
        });
      }
    }
    if (v != null) {
      if (v.gameId != _seenGame) {
        _seenGame = v.gameId;
        _seenSeq = v.seq;
        _showResult = false;
        _resultFor = null;
        _resultPending = false;
        _queue.clear();
        _playing = false;
        _stage = null;
        _moveAnim = null;
        _effect = null;
        _clearSelection();
        final first = c.displayName(v.currentTurn);
        _after(350, () {
          GameSfx.instance.play(GameSound.start);
          _banner(
            '윷놀이 시작!',
            sub: v.currentTurn == c.me ? '내가 먼저 던져요' : '$first 먼저 던져요',
            color: _theme.gold,
          );
        });
      } else if (v.seq > _seenSeq) {
        _seenSeq = v.seq;
        final a = v.lastAction;
        if (a != null) _enqueue(a);
        _revalidateSelection(v);
      }
      final mine = v.currentTurn == c.me && v.winner == null;
      if (mine && !_wasMyTurn && c.result == null) {
        _after(_playing ? 2200 : 450, () {
          if (!c.isMyTurn || c.result != null) return;
          GameSfx.instance.play(GameSound.turnMine);
          _say('내 차례예요', strong: true, ms: 1000);
        });
      }
      _wasMyTurn = mine;
    }
    final r = c.result;
    if (r != null && r.gameId != _resultFor) {
      _resultFor = r.gameId;
      _showResult = false;
      _resultPending = true;
      _maybeShowResult();
    }
    setState(() {});
  }

  void _maybeShowResult() {
    if (!_resultPending || _playing || _queue.isNotEmpty) return;
    _resultPending = false;
    _after(700, () => setState(() => _showResult = true));
  }

  /// 판 위쪽의 작은 알약 안내(상대 카드를 가리지 않는다). 짧게 떴다 사라진다.
  void _say(String text, {bool strong = false, int ms = 1700}) {
    _pillTimer?.cancel();
    setState(() {
      _pillId = Object();
      _pillText = text;
      _pillStrong = strong;
    });
    _pillTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _pillText = null);
    });
  }

  void _banner(String text, {String? sub, Color? color}) =>
      _say(sub == null ? text : '$text · $sub', strong: true, ms: 1300);

  void _showToast(String message) => _say(message);

  String _who(String? player) => player == c.me ? '내' : c.displayName(player);

  void _enqueue(YutAction a) {
    if (a.type != 'throw' && a.type != 'move') return;
    // 연출이 너무 밀리면 오래된 것부터 건너뛴다(마지막 상태가 화면의 진실).
    if (_queue.length >= 3) _queue.removeAt(0);
    _queue.add(a);
    if (!_playing) _next();
  }

  void _next() {
    if (_queue.isEmpty) {
      setState(() => _playing = false);
      _maybeShowResult();
      return;
    }
    _playing = true;
    final a = _queue.removeAt(0);
    for (final e in a.itemEffects) {
      _showItemEffect(e);
    }
    switch (a.type) {
      case 'throw':
        _playThrow(a);
      case 'move':
        _playMove(a);
      default:
        _next();
    }
  }

  void _showItemEffect(YutItemEffect e) {
    final id = _effectSeq++;
    setState(() => _itemEffects.add((id: id, effect: e)));
    GameSfx.instance.play(GameSound.sparkle);
    _after(
      2800,
      () => setState(() => _itemEffects.removeWhere((x) => x.id == id)),
    );
  }

  void _playThrow(YutAction a) {
    final t = a.thrown;
    if (t == null) {
      _next();
      return;
    }
    GameSfx.instance.play(GameSound.yutToss);
    setState(() {
      _stage = t;
      _stageSeq = a.seq;
      _stageBy = a.by;
    });
  }

  void _onSticksLanded(YutAction a) {
    final t = a.thrown;
    if (t == null) return;
    final sfx = GameSfx.instance;
    sfx.play(GameSound.yutClack);
    if (t.isBig) {
      _after(120, () => sfx.play(GameSound.yutKkwaeng));
    } else if (t.nak) {
      sfx.play(GameSound.yutGong);
    } else {
      _after(100, () => sfx.play(GameSound.yutDrum));
    }
    YutAudio.instance.playThrowResult(
      c.characterOf(a.by),
      t.resultName,
      seed: a.seq,
    );
  }

  void _onSticksDone(YutAction a) {
    final t = a.thrown;
    _after(a.thrown?.isBig == true ? 1000 : 750, () {
      setState(() => _stage = null);
      final who = _who(a.by);
      if (a.auto) {
        final name = c.displayName(a.by);
        _showToast('시간이 지나 $name${josa(name, '이', '가')} 자동으로 던졌어요');
      } else if (t != null && t.nak) {
        _showToast('낙! 쓸 수 있는 말이 없어 차례가 넘어가요');
      } else if (t != null && t.bonus) {
        _showToast(a.by == c.me ? '한 번 더 던져요!' : '$who 한 번 더 던져요');
      }
      _after(220, _next);
    });
  }

  void _playMove(YutAction a) {
    final info = a.move;
    if (info == null) {
      _next();
      return;
    }
    final steps = math.max(1, info.path.length - 1);
    final ms = math.max(520, steps * 230);
    setState(() => _moveAnim = YutMoveAnim(a.by ?? '', info));
    _moveCtl.duration = Duration(milliseconds: ms);
    for (var i = 1; i <= steps; i++) {
      _after((ms * i / steps * 0.92).round(), () {
        GameSfx.instance.play(GameSound.yutStep, minGapMs: 20);
      });
    }
    if (a.auto) {
      final name = c.displayName(a.by);
      _showToast('시간이 지나 $name${josa(name, '이', '가')} 말을 옮겼어요');
    }
    _moveCtl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _afterMove(a, info);
    });
  }

  void _afterMove(YutAction a, YutMoveInfo info) {
    final sfx = GameSfx.instance;
    final mine = a.by == c.me;
    var hold = 380;
    if (info.didCapture) {
      hold = 1000;
      sfx.play(GameSound.yutCapture);
      setState(() => _effect = YutBoardEffect(YutEffectKind.capture, info.to));
      _effectCtl.forward(from: 0);
      _banner(
        '잡았다!',
        sub: mine ? '한 번 더 던져요' : '${c.displayName(a.by)}의 잡기',
        color: _theme.accent,
      );
      if (mine) {
        YutAudio.instance.playCaptured(c.characterOf(c.me));
      } else if (info.capturedPlayer == c.me) {
        YutAudio.instance.playGotCaptured(c.characterOf(c.me));
      }
    } else if (info.wasBlocked) {
      hold = 900;
      sfx.play(GameSound.sparkle);
      setState(
        () => _effect = YutBoardEffect(
          YutEffectKind.block,
          info.blockedAt ?? info.to,
        ),
      );
      _effectCtl.forward(from: 0);
      _showToast('🛡️ 방어! 말이 한 칸 앞에서 멈췄어요');
    } else if (info.finish) {
      hold = 1100;
      sfx.play(GameSound.yutGoal);
      setState(() => _goalBursts++);
      _showToast(
        mine ? '골인! 말이 참먹이를 지났어요' : '${c.displayName(a.by)}의 말이 골인했어요',
      );
    } else if (info.stacked) {
      hold = 800;
      sfx.play(GameSound.yutStack);
      setState(() => _effect = YutBoardEffect(YutEffectKind.stack, info.to));
      _effectCtl.forward(from: 0);
      _showToast(mine ? '업었어요! 함께 가요' : '${c.displayName(a.by)}의 말이 업혔어요');
      if (mine) YutAudio.instance.playStacked(c.characterOf(c.me));
    }
    if (a.discardedBackdo > 0) {
      _showToast('쓸 수 없는 빽도는 낙이 되어 사라졌어요');
    }
    _after(hold, () {
      setState(() {
        _moveAnim = null;
        _effect = null;
      });
      _next();
    });
  }

  // ── 선택(칩 → 말 → 확정) ────────────────────────────────────────────────
  void _clearSelection() {
    _chip = null;
    _pieceId = null;
    _destTo = null;
    _destDir = null;
  }

  void _revalidateSelection(YutView v) {
    _pieceId = null;
    _destTo = null;
    _destDir = null;
    if (v.currentTurn != c.me || v.pendingMoves.isEmpty) _chip = null;
  }

  _Sel _selection(YutView v) {
    final active = !_playing && v.currentTurn == c.me && v.winner == null;
    if (!active || v.legalMoves.isEmpty) {
      return const _Sel(
        chip: null,
        moves: [],
        selectable: {},
        preview: [],
        chosen: null,
      );
    }
    final indices = v.legalMoves.map((m) => m.moveIndex).toSet();
    var chip = _chip;
    if (chip == null || !indices.contains(chip)) {
      chip = (indices.toList()..sort()).first;
    }
    final moves = v.legalMoves.where((m) => m.moveIndex == chip).toList();
    final selectable = {for (final m in moves) ...m.pieceIds};
    final pid = _pieceId;
    final preview = pid == null
        ? const <YutLegalMove>[]
        : moves.where((m) => m.pieceIds.contains(pid)).toList();
    YutLegalMove? chosen;
    if (preview.length == 1) {
      chosen = preview.first;
    } else if (preview.length > 1 && _destTo != null) {
      for (final m in preview) {
        if (m.to == _destTo && m.backdoDir == _destDir) chosen = m;
      }
    }
    return _Sel(
      chip: chip,
      moves: moves,
      selectable: selectable,
      preview: preview,
      chosen: chosen,
    );
  }

  void _onChipTap(int moveIndex) {
    GameSfx.instance.play(GameSound.select);
    setState(() {
      _chip = moveIndex;
      _pieceId = null;
      _destTo = null;
      _destDir = null;
    });
  }

  void _onPieceTap(int pieceId) {
    GameSfx.instance.play(GameSound.select);
    setState(() {
      _pieceId = _pieceId == pieceId ? null : pieceId;
      _destTo = null;
      _destDir = null;
    });
  }

  void _onDestinationTap(YutLegalMove m, YutLegalMove? chosen) {
    final already =
        chosen != null && chosen.to == m.to && chosen.backdoDir == m.backdoDir;
    if (already) {
      _confirm(m);
      return;
    }
    GameSfx.instance.play(GameSound.select);
    setState(() {
      _destTo = m.to;
      _destDir = m.backdoDir;
    });
  }

  void _confirm(YutLegalMove m) {
    if (c.busy || _playing) return;
    GameSfx.instance.play(GameSound.confirm);
    c.move(m);
    setState(_clearSelection);
  }

  void _throw() {
    if (c.busy || _playing) return;
    GameSfx.instance.play(GameSound.tap);
    c.throwSticks();
  }

  // ── 화면 ────────────────────────────────────────────────────────────────
  Color _colorOf(String player) => player == c.me ? _pal.me : _pal.opp;

  YutFigureSpec _specOf(String player) =>
      YutFigureSpec(character: c.characterOf(player));

  @override
  Widget build(BuildContext context) {
    final pal = _pal;
    final t = pal.theme;
    return YutPaletteScope(
      palette: pal,
      child: Scaffold(
        backgroundColor: t.backdrop.last,
        body: GameMenuListener(
          gameType: YutController.gameType,
          child: GameBackdrop(
            theme: t,
            frame: false,
            child: SafeArea(
              child: ListenableBuilder(
                listenable: Listenable.merge([c, _socket]),
                builder: (context, _) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _body()),
                        if (_goalBursts > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ConfettiBurst(
                                trigger: _goalBursts,
                                colors: [
                                  pal.acc,
                                  pal.opp,
                                  pal.yellow,
                                  Colors.white,
                                ],
                                count: 40,
                              ),
                            ),
                          ),
                        if (_showResult && c.result != null)
                          Positioned.fill(child: _resultOverlay(c.result!)),
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

  Widget _body() {
    final p = _pal;
    final v = c.view;
    final topBar = YutTopBar(
      title: '윷놀이',
      canRestart: v != null || c.result != null,
      restartWaiting: _socket.restartWaiting,
      onRequestRestart: c.requestRematch,
      onHelp: () => showGameHowTo(
        context,
        theme: p.theme,
        title: '윷놀이',
        emoji: '🎲',
        lines: _howToLines,
      ),
    );
    if (v == null) {
      return Column(
        children: [
          topBar,
          Expanded(child: _preparing()),
        ],
      );
    }
    final me = c.me;
    final opp = v.opponentOf(me);
    final sel = _selection(v);
    final myTurn = v.currentTurn == me && v.winner == null && c.result == null;
    final oppTurn =
        v.currentTurn == opp && v.winner == null && c.result == null;
    final deadline = GameDeadline.fromServer(
      deadlineMs: v.turnDeadline,
      serverNowMs: v.serverNow,
      total: Duration(milliseconds: v.turnMs),
      receivedAt: v.receivedAt,
    );
    final anim = _moveAnim;
    int waitingShown(String? pl) {
      var n = v.waitingOf(pl);
      if (anim != null &&
          anim.info.didCapture &&
          anim.info.capturedPlayer == pl &&
          _moveCtl.value < 0.96) {
        n -= anim.info.captured.length;
      }
      return math.max(0, n);
    }

    Widget card(String? player, bool mine, bool active) {
      final waiting = waitingShown(player);
      final home = v.finishedOf(player);
      return _PlayerCard(
        name: c.displayName(player),
        isMe: mine,
        active: active,
        team: _colorOf(player ?? ''),
        spec: _specOf(player ?? ''),
        waiting: waiting,
        onBoard: math.max(0, v.pieceCount - waiting - home),
        finished: home,
        deadline: active ? deadline : null,
        stickName: v.itemOf(player, 'yut_yut')?['name'] as String?,
        effectCount: v.effectsOf(player).chips(staked: v.stake > 0).length,
        onTapCard: () => _showEquipSheet(v, player),
        selectableWaiting: mine && sel.moves.any((m) => m.from == 0),
        waitingSelected:
            mine &&
            _pieceId != null &&
            sel.moves.any((m) => m.from == 0 && m.pieceIds.contains(_pieceId)),
        onTapWaiting: mine
            ? () {
                final rep = sel.moves.where((m) => m.from == 0);
                if (rep.isNotEmpty) _onPieceTap(rep.first.pieceId);
              }
            : null,
        bubble: ReactionBubble(
          theme: p.theme,
          forPlayer: player,
          gameType: YutController.gameType,
        ),
      );
    }

    return Column(
      children: [
        topBar,
        card(opp, false, oppTurn),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_moveCtl, _effectCtl]),
                  builder: (context, _) => YutBoardView(
                    view: v,
                    me: me,
                    selectable: sel.selectable,
                    selectedPieceId: _pieceId,
                    preview: sel.preview,
                    chosen: sel.chosen,
                    onTapPiece: _onPieceTap,
                    onTapDestination: (m) => _onDestinationTap(m, sel.chosen),
                    colorOf: _colorOf,
                    specOf: _specOf,
                    moveAnim: _moveAnim,
                    moveProgress: _moveCtl,
                    effect: _effect,
                    effectProgress: _effectCtl,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (((v.series?['games'] as num?)?.toInt() ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SeriesScore.fromMap(p.theme, v.series, c.me),
                        ),
                      if (!_showResult)
                        ReactionButton(
                          theme: p.theme,
                          gameType: YutController.gameType,
                        ),
                    ],
                  ),
                ),
                if (v.stake > 0)
                  Positioned(
                    left: 2,
                    top: 2,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        YutPill('판돈 ${v.stake}', size: 13),
                        if ((v.coinBonus[c.me] ?? 0) > 0)
                          YutPill('보너스 ${v.coinBonus[c.me]}', size: 13),
                      ],
                    ),
                  ),
                if (_stage != null) _stageOverlay(v),
                // 안내 알약과 아이템 효과 알약은 판 위쪽 가운데에(상대 카드를 가리지 않는다).
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Column(
                      children: [
                        YutToastPill(
                          id: _pillId,
                          text: _pillText,
                          strong: _pillStrong,
                        ),
                        for (final e in _itemEffects)
                          YutEffectPill(
                            key: ValueKey(e.id),
                            message: _effectMessage(
                              e.effect,
                              e.effect.player == c.me,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        card(me, true, myTurn),
        _throwArea(v, sel, myTurn),
        const SizedBox(height: 6),
      ],
    );
  }

  static String _effectMessage(YutItemEffect e, bool mine) {
    final who = mine ? '' : '상대 ';
    return switch (e.stat) {
      'yut_win_coin_pct' => '$who윷·모 보너스 +${e.amount}코인',
      'piece_catch_coin_bonus' ||
      'yut_catch_bonus' => '$who잡기 보너스 +${e.amount}코인',
      'yut_capture_protection' => '아이템 방어 발동! 말 ${e.amount}개가 무사해요',
      'yut_backdo_bonus_pct' => '$who아이템 효과 — 빽도 뒤 한 번 더',
      'yut_backdo_shield_pct' => '$who침착! 빽도를 다시 던졌어요',
      _ => '$who아이템 효과 발동',
    };
  }

  YutStickLook _lookOf(YutView v, String? player) =>
      YutStickLook.fromItem(v.itemOf(player, 'yut_yut'));

  Widget _stageOverlay(YutView v) {
    final stage = _stage!;
    final by = _stageBy;
    final look = _lookOf(v, by);
    final seq = _stageSeq;
    final action = YutAction(
      seq: seq,
      type: 'throw',
      by: by,
      auto: false,
      thrown: stage,
      move: null,
      turnPassed: false,
      discardedBackdo: 0,
      itemEffects: const [],
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = math.min(
              math.min(box.maxWidth, box.maxHeight) * 0.94,
              360.0,
            );
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: YutSticksStage(
                  key: ValueKey('stage$seq'),
                  thrown: stage,
                  seed: seq,
                  look: look,
                  throwerName: by == c.me ? '내' : c.displayName(by),
                  onLanded: () => _onSticksLanded(action),
                  onDone: () => _onSticksDone(
                    YutAction(
                      seq: seq,
                      type: 'throw',
                      by: by,
                      auto: _lastAutoFor(seq),
                      thrown: stage,
                      move: null,
                      turnPassed: false,
                      discardedBackdo: 0,
                      itemEffects: const [],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _lastAutoFor(int seq) {
    final a = c.view?.lastAction;
    return a != null && a.seq == seq && a.auto;
  }

  /// 캐릭터 능력치·윷 스킨·실제 적용 효과 전체(카드를 누르면).
  void _showEquipSheet(YutView v, String? player) {
    final p = _pal;
    final mine = player == c.me;
    final chips = v.effectsOf(player).chips(staked: v.stake > 0);
    final stick = v.itemOf(player, 'yut_yut');
    final character = c.characterOf(player);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => YutPaletteScope(
        palette: p,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: p.night ? p.panel : Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(color: p.panelEdge, offset: const Offset(0, 5)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mine ? '내' : c.displayName(player)} 장비',
                    style: p.display(size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${yutCharacterNames[character] ?? ''} · ${kYutCharacterBlurb[character] ?? ''}',
                    style: p.body(size: 14, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  YutStatBars(
                    stats: v.statsOf(player),
                    color: p.acc,
                    textColor: p.ink,
                    mutedColor: p.sub,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stick == null
                        ? '윷 스킨: 기본'
                        : '윷 스킨: ${stick['name'] ?? '아이템'} (${stick['grade'] ?? 'B'}등급)',
                    style: p.body(size: 14, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '이 판에 적용되는 효과',
                    style: p.body(size: 13, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (chips.isEmpty)
                    Text('적용되는 효과가 없어요.', style: p.body(size: 13, color: p.sub))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final label in chips) YutPill(label, size: 13),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '아이템 효과는 합쳐서 일정 한도까지만 적용되고, 코인 보너스는 판돈의 30%까지만 쌓여요.',
                    style: p.body(
                      size: 12,
                      color: p.sub,
                      height: 1.4,
                      weight: FontWeight.w500,
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

  /// 아래 줄: 윷 아이콘 + 던지기 결과 칩 + 꽉 찬 두툼한 버튼 하나(+ 조용한 보조 버튼).
  Widget _throwArea(YutView v, _Sel sel, bool myTurn) {
    final p = _pal;
    final pending = v.pendingMoves;
    final hide = _stage != null && !_stage!.nak && pending.isNotEmpty;
    final shown = hide ? pending.sublist(0, pending.length - 1) : pending;
    final chosen = sel.chosen;
    final canThrow = myTurn && v.canThrow && !_playing && !c.busy;
    final look = _lookOf(v, c.me);

    String label;
    var enabled = false;
    var busy = false;
    if (v.winner != null) {
      label = '판이 끝났어요';
    } else if (!myTurn) {
      label = '${c.displayName(v.currentTurn)}의 차례';
    } else if (_playing) {
      label = '윷가락이 구르는 중…';
      busy = true;
    } else if (chosen != null) {
      label = chosen.finish
          ? '골인시키기'
          : chosen.captures > 0
          ? '잡으러 가기'
          : '여기로 옮기기';
      enabled = !c.busy;
    } else if (sel.preview.length > 1) {
      label = '화살표를 골라요';
    } else if (v.canThrow) {
      label = pending.isEmpty ? '윷 던지기' : '한 번 더 던지기';
      enabled = canThrow;
    } else {
      label = '말을 눌러요';
    }
    final confirm = chosen != null && myTurn && !_playing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: Row(
              children: [
                _SticksIcon(look: look),
                const SizedBox(width: 10),
                Expanded(
                  child: shown.isEmpty
                      ? Text(
                          myTurn && !_playing ? '던진 결과가 여기에 쌓여요' : '',
                          style: p.body(
                            size: 13,
                            color: p.sub,
                            weight: FontWeight.w700,
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < shown.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _ThrowChip(
                                    steps: shown[i],
                                    selected:
                                        myTurn && sel.chip == i && !_playing,
                                    enabled: myTurn && !_playing,
                                    onTap: () => _onChipTap(i),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: YutChunkyButton(
                  label: label,
                  busy: busy,
                  icon: confirm
                      ? Icons.arrow_forward_rounded
                      : (v.canThrow && myTurn && !busy
                            ? Icons.casino_outlined
                            : null),
                  onPressed: !enabled
                      ? null
                      : confirm
                      ? () => _confirm(chosen)
                      : _throw,
                ),
              ),
              if (confirm && v.canThrow) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: YutChunkyButton(
                    label: '던지기',
                    ghost: true,
                    icon: Icons.casino_outlined,
                    onPressed: canThrow ? _throw : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _preparing() {
    final p = _pal;
    final isHost = _socket.lobbyHost != null && _socket.lobbyHost == c.me;
    final failed =
        c.syncStatus != null &&
        c.syncStatus != 'ok' &&
        c.syncStatus != 'no_game';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: p.night ? p.panel : Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: p.panelEdge, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎲', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(
                '윷판을 펴는 중…',
                textAlign: TextAlign.center,
                style: p.display(size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '판을 불러오지 못했어요. ${YutController.reasonMessages[c.syncStatus] ?? '연결 상태를 확인해 주세요.'}'
                    : '판을 준비하고 있어요. 잠시만 기다려 주세요.',
                textAlign: TextAlign.center,
                style: p.body(
                  size: 13.5,
                  color: p.sub,
                  height: 1.5,
                  weight: FontWeight.w500,
                ),
              ),
              if (c.syncing) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: p.acc,
                  ),
                ),
              ],
              if (isHost) ...[
                const SizedBox(height: 16),
                YutChunkyButton(
                  label: '다시 불러오기',
                  icon: Icons.refresh_rounded,
                  height: 48,
                  onPressed: c.sync,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultOverlay(YutResult r) {
    final me = c.me;
    final won = r.winner == me;
    final oppId = won ? r.loser : r.winner;
    final oppName = c.displayName(oppId);
    final reason = r.forfeit
        ? (won ? '$oppName의 시간 초과가 이어져 기권승이에요.' : '시간 초과가 이어져 기권패가 되었어요.')
        : (won
              ? '말 ${r.pieceCount}개를 먼저 모두 보냈어요'
              : '$oppName${josa(oppName, '이', '가')} 먼저 말을 모두 보냈어요');
    return YutResultView(
      palette: _pal,
      won: won,
      forfeit: r.forfeit,
      title: r.forfeit ? (won ? '기권승' : '기권패') : (won ? '승리' : '아쉬워요'),
      who:
          '${won ? '나' : c.displayName(r.winner)} · ${yutCharacterNames[c.characterOf(r.winner)] ?? ''}',
      reason: reason,
      winnerSpec: _specOf(r.winner),
      winnerTeam: _colorOf(r.winner),
      stake: r.stake,
      shownStake: r.shownStake,
      shownBonus: r.shownBonus,
      settlementFailed: r.settlementFailed,
      skinName: c.view?.itemOf(me, 'yut_yut')?['name'] as String?,
      finishedLine:
          '나 ${r.finished[me] ?? 0} : ${r.finished[oppId] ?? 0} ${oppId == null ? '상대' : c.displayName(oppId)}',
      series: r.series == null
          ? null
          : SeriesScore.fromMap(_pal.theme, r.series, me),
      resultId: r.gameId,
      rematchWaiting: _socket.restartWaiting,
      onRematch: c.requestRematch,
      onExit: () => Navigator.of(context).maybePop(),
    );
  }
}

// ── 작은 부품 ──────────────────────────────────────────────────────────────

/// 지금 고른 칩·말·목적지(서버 legalMoves에서 걸러낸 것).
class _Sel {
  final int? chip;
  final List<YutLegalMove> moves;
  final Set<int> selectable;
  final List<YutLegalMove> preview;
  final YutLegalMove? chosen;

  const _Sel({
    required this.chip,
    required this.moves,
    required this.selectable,
    required this.preview,
    required this.chosen,
  });
}

/// 위·아래 플레이어 카드: 카드 가장자리를 넘어 솟은 캐릭터 상반신, 이름, "내 차례"·"효과 N" 알약,
/// 말 상태 점, 남은 시간 링, 대기 말(누르면 고른다). 카드를 누르면 장비 창.
class _PlayerCard extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool active;
  final Color team;
  final YutFigureSpec spec;
  final int waiting;
  final int onBoard;
  final int finished;
  final GameDeadline? deadline;
  final String? stickName;
  final int effectCount;
  final VoidCallback onTapCard;
  final bool selectableWaiting;
  final bool waitingSelected;
  final VoidCallback? onTapWaiting;
  final Widget bubble;

  const _PlayerCard({
    required this.name,
    required this.isMe,
    required this.active,
    required this.team,
    required this.spec,
    required this.waiting,
    required this.onBoard,
    required this.finished,
    required this.deadline,
    required this.stickName,
    required this.effectCount,
    required this.onTapCard,
    required this.bubble,
    this.selectableWaiting = false,
    this.waitingSelected = false,
    this.onTapWaiting,
  });

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    final total = waiting + onBoard + finished;
    final charName = yutCharacterNames[spec.character] ?? '';
    final bustH = 76.0;
    // 상대는 오른쪽, 나는 왼쪽에 상반신이 걸친다.
    final bust = Positioned(
      top: -20,
      left: isMe ? 4 : null,
      right: isMe ? null : 4,
      child: IgnorePointer(
        child: YutBust(character: spec.character, height: bustH + 20),
      ),
    );
    final info = Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isMe ? 74 : 0, right: isMe ? 0 : 74),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    isMe ? charName : charName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.display(size: 20),
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  const YutPill('내 차례', filled: true),
                ],
                if (effectCount > 0) ...[
                  const SizedBox(width: 6),
                  YutPill('효과 $effectCount'),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 13,
                    height: 13,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < finished
                          ? p.acc
                          : i < finished + onBoard
                          ? p.acc.withValues(alpha: 0.3)
                          : Colors.transparent,
                      border: Border.all(
                        color: i < finished + onBoard
                            ? p.acc
                            : p.sub.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                  ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '도착 $finished/$total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.body(size: 12.5, color: p.sub),
                  ),
                ),
              ],
            ),
            Text(
              stickName ?? '기본 윷',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.body(
                size: 12,
                color: p.sub.withValues(alpha: 0.9),
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    final ring = deadline == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(left: 6),
            child: YutTimerRing(deadline: deadline, tick: isMe, size: 48),
          );
    final waitingGroup = SizedBox(
      width: 54,
      height: 56,
      child: waiting <= 0
          ? const SizedBox.shrink()
          : Semantics(
              button: selectableWaiting,
              label: '대기 말 $waiting개',
              child: GestureDetector(
                key: isMe ? const ValueKey('yut_waiting_piece') : null,
                behavior: HitTestBehavior.opaque,
                onTap: selectableWaiting ? onTapWaiting : null,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: YutFigure(
                    height: 50,
                    team: team,
                    spec: spec,
                    count: waiting,
                    selected: waitingSelected,
                    glow: selectableWaiting && !waitingSelected,
                  ),
                ),
              ),
            ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
      child: Semantics(
        button: true,
        label:
            '${isMe ? '나' : name}${active ? ', 차례' : ''}, 대기 $waiting, 판 위 $onBoard, 도착 $finished, 장비 보기',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapCard,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: p.night ? p.panel : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: active ? Border.all(color: p.acc, width: 3) : null,
                  boxShadow: [
                    BoxShadow(color: p.panelEdge, offset: const Offset(0, 4)),
                    if (active) BoxShadow(color: p.glow, blurRadius: 16),
                  ],
                ),
                child: Row(
                  children: isMe
                      ? [info, ring, const SizedBox(width: 2), waitingGroup]
                      : [waitingGroup, const SizedBox(width: 2), info, ring],
                ),
              ),
              bust,
              Positioned(left: isMe ? 78 : 12, top: -16, child: bubble),
            ],
          ),
        ),
      ),
    );
  }
}

/// 던지기 결과 칩: 두툼한 알약(선택하면 포인트색 + 아래 가장자리).
class _ThrowChip extends StatelessWidget {
  final int steps;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ThrowChip({
    required this.steps,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    final name = yutStepName(steps);
    final sub = steps < 0 ? '뒤로 1칸' : '$steps칸';
    final face = selected ? p.acc : (p.night ? p.panel : Colors.white);
    final edge = selected ? p.acc2 : p.panelEdge;
    final fg = selected ? p.onAcc : p.ink;
    return Semantics(
      button: enabled,
      selected: selected,
      label: '던지기 결과 $name, $sub',
      child: GestureDetector(
        key: ValueKey('yut_chip_$steps'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 58, minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: edge, offset: Offset(0, selected ? 4 : 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(name, style: p.display(size: 24, color: fg, height: 1.1)),
              const SizedBox(width: 4),
              Text(
                sub,
                style: p.body(
                  size: 12,
                  color: selected ? p.onAcc.withValues(alpha: 0.85) : p.sub,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 던진 결과 줄 맨 앞 작은 윷 아이콘(지금 장착한 윷 스킨 색).
class _SticksIcon extends StatelessWidget {
  final YutStickLook look;

  const _SticksIcon({required this.look});

  @override
  Widget build(BuildContext context) {
    final p = YutPalette.of(context);
    return Semantics(
      label: '윷가락',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: p.night ? p.panel : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: p.panelEdge, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                width: 6,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                transform: Matrix4.rotationZ((i - 1.5) * 0.06),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: look.flat,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: look.round.withValues(alpha: 0.6)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
