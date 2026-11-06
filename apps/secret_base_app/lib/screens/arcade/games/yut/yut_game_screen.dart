import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../core/yut_audio.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'yut_board_view.dart';
import 'yut_controller.dart';
import 'yut_models.dart';
import 'yut_figures.dart';
import 'yut_sticks.dart';

/// 윷놀이 2.0 — 햇살 풀밭(GameTheme.meadow).
/// 서버가 로비 시작과 함께 판을 만든다. 이 화면에는 시작 버튼이 없다.
class YutGameScreen extends StatefulWidget {
  const YutGameScreen({super.key});

  @override
  State<YutGameScreen> createState() => _YutGameScreenState();
}

class _YutGameScreenState extends State<YutGameScreen>
    with TickerProviderStateMixin {
  static const _theme = GameTheme.meadow;
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
  // 작은 통나무에 놓여 있는 마지막 던지기(연출이 끝나면 갱신).
  YutThrow? _lastShown;
  String? _lastShownBy;
  int _lastShownSeq = 1;
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

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  Color? _bannerColor;
  Object? _toastId;
  String? _toast;

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
        theme: _theme,
        title: '윷놀이',
        emoji: '🎲',
        lines: _howToLines,
      );
    });
  }

  @override
  void dispose() {
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
        _lastShown = null;
        _lastShownBy = null;
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
          _banner('내 차례!', color: _theme.me);
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

  void _banner(String text, {String? sub, Color? color}) {
    setState(() {
      _bannerId = Object();
      _bannerText = text;
      _bannerSub = sub;
      _bannerColor = color;
    });
  }

  void _showToast(String message) {
    setState(() {
      _toastId = Object();
      _toast = message;
    });
  }

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
    _lastShown = t;
    _lastShownBy = a.by;
    _lastShownSeq = a.seq;
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
  Color _colorOf(String player) => player == c.me ? _theme.me : _theme.opponent;

  YutFigureSpec _specOf(String player) => YutFigureSpec.of(
    c.characterOf(player),
    c.view?.itemOf(player, 'yut_piece'),
  );

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: YutController.gameType,
        child: GameBackdrop(
          theme: t,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([c, _socket]),
              builder: (context, _) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _body()),
                      Positioned(
                        top: 96,
                        left: 0,
                        right: 0,
                        child: GameTurnBanner(
                          theme: t,
                          id: _bannerId,
                          text: _bannerText,
                          sub: _bannerSub,
                          color: _bannerColor,
                        ),
                      ),
                      Positioned(
                        top: 56,
                        left: 16,
                        right: 16,
                        child: GameToast(
                          theme: t,
                          id: _toastId,
                          message: _toast,
                        ),
                      ),
                      if (_itemEffects.isNotEmpty)
                        Positioned(
                          top: 150,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Column(
                              children: [
                                for (final e in _itemEffects)
                                  _ItemEffectBadge(
                                    key: ValueKey(e.id),
                                    effect: e.effect,
                                    mine: e.effect.player == c.me,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      if (_goalBursts > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ConfettiBurst(
                              trigger: _goalBursts,
                              colors: const [
                                Obangsaek.blue,
                                Obangsaek.red,
                                Obangsaek.yellow,
                                Obangsaek.white,
                                Obangsaek.black,
                              ],
                              count: 60,
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
    );
  }

  Widget _body() {
    final t = _theme;
    final v = c.view;
    final topBar = GameTopBar(
      theme: t,
      title: '윷놀이',
      gameType: YutController.gameType,
      canRestart: v != null || c.result != null,
      restartWaiting: _socket.restartWaiting,
      onRequestRestart: c.requestRematch,
      onHelp: () => showGameHowTo(
        context,
        theme: t,
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
    int waitingShown(String? p) {
      var n = v.waitingOf(p);
      if (anim != null &&
          anim.info.didCapture &&
          anim.info.capturedPlayer == p &&
          _moveCtl.value < 0.96) {
        n -= anim.info.captured.length;
      }
      return math.max(0, n);
    }

    Widget card(String? player, bool mine, bool active) => _PlayerCard(
      theme: t,
      name: c.displayName(player),
      isMe: mine,
      active: active,
      team: _colorOf(player ?? ''),
      spec: _specOf(player ?? ''),
      waiting: waitingShown(player),
      finished: v.finishedOf(player),
      total: v.pieceCount,
      deadline: active ? deadline : null,
      stick: v.itemOf(player, 'yut_yut'),
      piece: v.itemOf(player, 'yut_piece'),
      effects: v.effectsOf(player).chips(staked: v.stake > 0),
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
        theme: t,
        forPlayer: player,
        gameType: YutController.gameType,
      ),
    );

    return Column(
      children: [
        topBar,
        card(opp, false, oppTurn),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  right: 4,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (((v.series?['games'] as num?)?.toInt() ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: SeriesScore.fromMap(t, v.series, c.me),
                        ),
                      if (!_showResult)
                        ReactionButton(
                          theme: t,
                          gameType: YutController.gameType,
                        ),
                    ],
                  ),
                ),
                if (v.stake > 0)
                  Positioned(
                    left: 6,
                    top: 0,
                    child: Wrap(
                      spacing: 6,
                      children: [
                        GameChip(
                          theme: t,
                          leading: '🪙',
                          label: '판돈 ${v.stake}',
                          emphasized: true,
                        ),
                        if ((v.coinBonus[c.me] ?? 0) > 0)
                          GameChip(
                            theme: t,
                            leading: '🎁',
                            label: '보너스 ${v.coinBonus[c.me]}',
                          ),
                      ],
                    ),
                  ),
                if (_stage != null) _stageOverlay(v),
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
              math.min(box.maxWidth, box.maxHeight) * 0.86,
              330.0,
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

  /// 장착 아이템과 실제 적용 효과를 보여 주는 창(카드를 누르면).
  void _showEquipSheet(YutView v, String? player) {
    final t = _theme;
    final mine = player == c.me;
    final chips = v.effectsOf(player).chips(staked: v.stake > 0);
    Widget itemBlock(String slotLabel, Map<String, dynamic>? item) {
      if (item == null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$slotLabel: 기본',
            style: t.body(size: 13.5, color: t.subInk),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(
              '${item['icon'] ?? '🎁'}',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$slotLabel: ${item['name'] ?? '아이템'} (${item['grade'] ?? 'B'}등급)',
                style: t.body(size: 13.5, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: GamePanel(
          theme: t,
          opaque: true,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mine ? '내' : c.displayName(player)} 장비',
                style: t.display(size: 20),
              ),
              const SizedBox(height: 10),
              itemBlock('말', v.itemOf(player, 'yut_piece')),
              itemBlock('윷', v.itemOf(player, 'yut_yut')),
              const SizedBox(height: 4),
              Text(
                '이 판에 적용되는 효과',
                style: t.body(size: 13, weight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (chips.isEmpty)
                Text('적용되는 효과가 없어요.', style: t.body(size: 13, color: t.subInk))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final label in chips)
                      GameChip(theme: t, label: label, emphasized: true),
                  ],
                ),
              const SizedBox(height: 10),
              Text(
                '아이템 효과는 합쳐서 일정 한도까지만 적용되고, 코인 보너스는 판돈의 30%까지만 쌓여요.',
                style: t.body(size: 12, color: t.subInk, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  YutThrow? _restingThrow(YutView v) {
    if (_lastShown != null) return _lastShown;
    if (v.turnThrows.isNotEmpty) return v.turnThrows.last;
    return v.lastAction?.thrown;
  }

  /// 아래 줄: 통나무 던지는 자리 + 던지기 결과 칩 + 던지기·옮기기 버튼.
  Widget _throwArea(YutView v, _Sel sel, bool myTurn) {
    final t = _theme;
    final pending = v.pendingMoves;
    final hide = _stage != null && !_stage!.nak && pending.isNotEmpty;
    final shown = hide ? pending.sublist(0, pending.length - 1) : pending;
    final chosen = sel.chosen;
    final canThrow = myTurn && v.canThrow && !_playing && !c.busy;
    final resting = _restingThrow(v);
    final by = _lastShownBy ?? v.lastAction?.by ?? c.me;

    String label;
    var enabled = false;
    if (v.winner != null) {
      label = '판이 끝났어요';
    } else if (!myTurn) {
      label = '${c.displayName(v.currentTurn)}의 차례';
    } else if (_playing) {
      label = '윷가락이 구르는 중…';
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
    } else if (_pieceId == null) {
      label = '말을 눌러요';
    } else {
      label = '말을 눌러요';
    }
    final confirm = chosen != null && myTurn && !_playing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
      child: SizedBox(
        height: 108,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: Semantics(
                label: '윷가락이 놓인 통나무',
                child: YutSlab(
                  sticks: resting?.sticks ?? const [0, 0, 0, 0],
                  seed: _lastShownSeq,
                  look: _lookOf(v, by),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 56,
                    child: shown.isEmpty
                        ? Center(
                            child: Text(
                              myTurn && !_playing
                                  ? '던진 결과가 여기 쌓여요'
                                  : pending.isEmpty
                                  ? ''
                                  : '…',
                              style: t.body(size: 12.5, color: t.subInk),
                            ),
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            children: [
                              for (var i = 0; i < shown.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: GamePrimaryButton(
                          theme: t,
                          label: label,
                          icon: confirm
                              ? Icons.check_rounded
                              : v.canThrow && myTurn
                              ? Icons.casino_rounded
                              : Icons.hourglass_top_rounded,
                          height: 46,
                          onPressed: !enabled
                              ? null
                              : confirm
                              ? () => _confirm(chosen)
                              : _throw,
                        ),
                      ),
                      if (confirm && v.canThrow) ...[
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 52,
                          child: GameSecondaryButton(
                            theme: t,
                            label: '',
                            icon: Icons.casino_rounded,
                            height: 46,
                            onPressed: canThrow ? _throw : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preparing() {
    final t = _theme;
    final isHost = _socket.lobbyHost != null && _socket.lobbyHost == c.me;
    final failed =
        c.syncStatus != null &&
        c.syncStatus != 'ok' &&
        c.syncStatus != 'no_game';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: GamePanel(
          theme: t,
          radius: 26,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎲', style: TextStyle(fontSize: 46)),
              const SizedBox(height: 14),
              Text(
                '윷판을 펴는 중…',
                textAlign: TextAlign.center,
                style: t.display(size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '판을 불러오지 못했어요. ${YutController.reasonMessages[c.syncStatus] ?? '연결 상태를 확인해 주세요.'}'
                    : '멍석을 깔고 있어요. 잠시만 기다려 주세요.',
                textAlign: TextAlign.center,
                style: t.body(size: 13.5, color: t.subInk, height: 1.45),
              ),
              if (c.syncing) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: t.accent,
                  ),
                ),
              ],
              if (isHost) ...[
                const SizedBox(height: 16),
                GameSecondaryButton(
                  theme: t,
                  label: '다시 불러오기',
                  icon: Icons.refresh_rounded,
                  height: 46,
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
    final t = _theme;
    final me = c.me;
    final won = r.winner == me;
    final oppId = won ? r.loser : r.winner;
    final oppName = c.displayName(oppId);
    final reason = r.forfeit
        ? (won ? '$oppName의 시간 초과가 이어져 기권승이에요.' : '시간 초과가 이어져 기권패가 되었어요.')
        : (won
              ? '말 ${r.pieceCount}개를 먼저 모두 보냈어요!'
              : '$oppName${josa(oppName, '이', '가')} 먼저 말을 모두 보냈어요.');
    final mine = r.finished[me] ?? 0;
    final theirs = r.finished[oppId] ?? 0;
    return GameResultOverlay(
      theme: t,
      outcome: won ? GameOutcome.win : GameOutcome.lose,
      title: r.forfeit ? (won ? '기권승!' : '기권패') : null,
      reason: reason,
      series: r.series,
      me: me,
      resultId: r.gameId,
      details: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              key: const ValueKey('yut_result_figures'),
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                YutFigure(
                  height: 104,
                  team: _colorOf(r.winner),
                  spec: _specOf(r.winner),
                  badge: false,
                  glow: true,
                ),
                if (oppId != null) ...[
                  const SizedBox(width: 14),
                  YutFigure(
                    height: 72,
                    team: _colorOf(oppId),
                    spec: _specOf(oppId),
                    badge: false,
                    dimmed: true,
                  ),
                ],
              ],
            ),
          ),
          if (r.stake > 0 && r.settlementFailed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameChip(theme: t, leading: '⏳', label: '코인 정산이 지연되고 있어요'),
            )
          else if (r.stake > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameChip(
                theme: t,
                leading: '🪙',
                label: won
                    ? '판돈 ${r.shownStake}코인을 얻었어요'
                    : '판돈 ${r.shownStake}코인을 잃었어요',
                emphasized: won,
              ),
            ),
          if (won && r.shownBonus > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GameChip(
                theme: t,
                leading: '🎁',
                label: '아이템 보너스 +${r.shownBonus}코인',
                emphasized: true,
              ),
            ),
          Text(
            '도착한 말  나 $mine : $theirs 상대',
            style: t.body(size: 13, color: t.subInk),
          ),
        ],
      ),
      rematchWaiting: _socket.restartWaiting,
      onRematch: c.requestRematch,
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

/// 위·아래 플레이어 카드: 서 있는 말(캐릭터 또는 상점 동물 말), 이름, 대기·도착 수,
/// 장착한 윷·말 이름과 실제 적용 "효과" 칩, 남은 시간, 대기 말. 카드를 누르면 장비 창.
class _PlayerCard extends StatelessWidget {
  final GameTheme theme;
  final String name;
  final bool isMe;
  final bool active;
  final Color team;
  final YutFigureSpec spec;
  final int waiting;
  final int finished;
  final int total;
  final GameDeadline? deadline;
  final Map<String, dynamic>? stick;
  final Map<String, dynamic>? piece;
  final List<String> effects;
  final VoidCallback onTapCard;
  final bool selectableWaiting;
  final bool waitingSelected;
  final VoidCallback? onTapWaiting;
  final Widget bubble;

  const _PlayerCard({
    required this.theme,
    required this.name,
    required this.isMe,
    required this.active,
    required this.team,
    required this.spec,
    required this.waiting,
    required this.finished,
    required this.total,
    required this.deadline,
    required this.stick,
    required this.piece,
    required this.effects,
    required this.onTapCard,
    required this.bubble,
    this.selectableWaiting = false,
    this.waitingSelected = false,
    this.onTapWaiting,
  });

  Widget _chip(String text, {Color? color}) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: (color ?? theme.accent).withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: (color ?? theme.accent).withValues(alpha: 0.7)),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: theme.body(size: 12, weight: FontWeight.w800, height: 1.15),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final charName = yutCharacterNames[spec.character] ?? '';
    final who = spec.isSkin ? (spec.skinName ?? '동물 말') : charName;
    final chips = <Widget>[
      if (stick != null)
        _chip(
          '${stick!['icon'] ?? ''} ${stick!['name'] ?? ''}',
          color: yutGradeColor('${stick!['grade'] ?? 'B'}') == Colors.white
              ? t.subInk
              : yutGradeColor('${stick!['grade'] ?? 'B'}'),
        ),
      if (effects.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(
            child: Text(
              '효과',
              style: t.body(size: 12, weight: FontWeight.w900, color: t.accent),
            ),
          ),
        ),
      for (final e in effects) _chip(e),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Semantics(
        button: true,
        label:
            '${isMe ? '나' : name}${active ? ', 차례' : ''}, 대기 말 $waiting개, 도착 $finished개, 장비 보기',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapCard,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: active ? 0.88 : 0.66),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? t.gold : t.surfaceBorder.withValues(alpha: 0.5),
                width: active ? 2.2 : 1,
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: t.gold.withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    YutFigure(
                      key: ValueKey('yut_card_figure_${isMe ? 'me' : 'opp'}'),
                      height: 58,
                      team: team,
                      spec: spec,
                      badge: false,
                    ),
                    Positioned(left: 44, top: -12, child: bubble),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMe && name != '나' ? '$name (나)' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body(size: 13.5, weight: FontWeight.w800),
                      ),
                      Text(
                        '$who · 대기 $waiting · 도착 $finished/$total',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body(
                          size: 12,
                          color: t.subInk,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (chips.isNotEmpty)
                        SizedBox(
                          height: 24,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: chips),
                          ),
                        ),
                    ],
                  ),
                ),
                if (deadline != null) ...[
                  TurnTimerRing(
                    theme: t,
                    deadline: deadline,
                    size: 40,
                    tickSound: isMe,
                  ),
                  const SizedBox(width: 6),
                ],
                SizedBox(
                  width: 54,
                  height: 58,
                  child: waiting <= 0
                      ? const SizedBox.shrink()
                      : Semantics(
                          button: selectableWaiting,
                          label: '대기 말 $waiting개',
                          child: GestureDetector(
                            key: isMe
                                ? const ValueKey('yut_waiting_piece')
                                : null,
                            behavior: HitTestBehavior.opaque,
                            onTap: selectableWaiting ? onTapWaiting : null,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: YutFigure(
                                height: 52,
                                team: team,
                                spec: spec,
                                count: waiting,
                                selected: waitingSelected,
                                glow: selectableWaiting && !waitingSelected,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 던지기 결과 칩(한지 쪽지): 윷·모는 색 띠, 선택하면 올라온다.
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
    final name = yutStepName(steps);
    final sub = steps < 0 ? '뒤로 1칸' : '$steps칸';
    final accent = switch (steps) {
      4 => Obangsaek.red,
      5 => Obangsaek.blue,
      -1 => Obangsaek.black,
      _ => Obangsaek.yellow,
    };
    return Semantics(
      button: enabled,
      selected: selected,
      label: '던지기 결과 $name, $sub',
      child: GestureDetector(
        key: ValueKey('yut_chip_$steps'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF8EA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Obangsaek.red : const Color(0xAA2A2623),
              width: selected ? 2.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.3 : 0.14),
                blurRadius: selected ? 10 : 4,
                offset: Offset(0, selected ? 5 : 2),
              ),
              if (selected)
                BoxShadow(
                  color: Obangsaek.yellow.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 4,
                width: 26,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: GoogleFonts.gowunBatang(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Obangsaek.black,
                  height: 1.1,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6D6254),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemEffectBadge extends StatelessWidget {
  final YutItemEffect effect;
  final bool mine;

  const _ItemEffectBadge({super.key, required this.effect, required this.mine});

  String get message {
    final who = mine ? '' : '상대 ';
    return switch (effect.stat) {
      'yut_win_coin_pct' => '💰 $who윷·모 보너스 +${effect.amount}코인이 쌓였어요',
      'piece_catch_coin_bonus' ||
      'yut_catch_bonus' => '⚡ $who잡기 보너스 +${effect.amount}코인이 쌓였어요',
      'yut_capture_protection' => '🛡️ 아이템 방어 발동! 말 ${effect.amount}개가 무사해요',
      'yut_backdo_bonus_pct' => '🎲 $who아이템 효과 — 빽도 뒤 한 번 더 던져요',
      _ => '✨ $who아이템 효과 발동!',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GameChip(
        theme: GameTheme.meadow,
        label: message,
        emphasized: true,
      ),
    );
  }
}
