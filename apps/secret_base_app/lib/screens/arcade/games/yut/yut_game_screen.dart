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
import 'yut_pieces.dart';
import 'yut_sticks.dart';

/// 윷놀이 2.0 — 한지 마당(GameTheme.hanji).
/// 서버가 로비 시작과 함께 판을 만든다. 이 화면에는 시작 버튼이 없다.
class YutGameScreen extends StatefulWidget {
  const YutGameScreen({super.key});

  @override
  State<YutGameScreen> createState() => _YutGameScreenState();
}

class _YutGameScreenState extends State<YutGameScreen>
    with TickerProviderStateMixin {
  static const _theme = GameTheme.hanji;
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

  String? _skinOf(String player) =>
      yutPieceEmojiFromItem(c.view?.itemOf(player, 'yut_piece'));

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
                      if (c.view != null && !_showResult)
                        Positioned(
                          right: 10,
                          top: 58,
                          child: ReactionButton(
                            theme: t,
                            gameType: YutController.gameType,
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

    return Column(
      children: [
        topBar,
        _infoRow(v),
        _PlayerStrip(
          theme: t,
          name: c.displayName(opp),
          emoji: c.emojiOf(opp),
          character: c.characterOf(opp),
          color: _colorOf(opp ?? ''),
          isMe: false,
          active: oppTurn,
          waiting: waitingShown(opp),
          finished: v.finishedOf(opp),
          total: v.pieceCount,
          skinEmoji: _skinOf(opp ?? ''),
          deadline: oppTurn ? deadline : null,
          items: _itemBadges(v, opp),
          bubble: ReactionBubble(
            theme: t,
            forPlayer: opp,
            gameType: YutController.gameType,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                    characterOf: c.characterOf,
                    skinOf: _skinOf,
                    moveAnim: _moveAnim,
                    moveProgress: _moveCtl,
                    effect: _effect,
                    effectProgress: _effectCtl,
                  ),
                ),
                if (_stage != null) _stageOverlay(v),
              ],
            ),
          ),
        ),
        _PlayerStrip(
          theme: t,
          name: c.displayName(me),
          emoji: c.emojiOf(me),
          character: c.characterOf(me),
          color: _colorOf(me ?? ''),
          isMe: true,
          active: myTurn,
          waiting: waitingShown(me),
          finished: v.finishedOf(me),
          total: v.pieceCount,
          skinEmoji: _skinOf(me ?? ''),
          deadline: myTurn ? deadline : null,
          items: const [],
          selectableWaiting: sel.moves.any((m) => m.from == 0),
          waitingSelected:
              _pieceId != null &&
              sel.moves.any(
                (m) => m.from == 0 && m.pieceIds.contains(_pieceId),
              ),
          onTapWaiting: () {
            final rep = sel.moves.where((m) => m.from == 0);
            if (rep.isNotEmpty) _onPieceTap(rep.first.pieceId);
          },
          bubble: ReactionBubble(
            theme: t,
            forPlayer: me,
            gameType: YutController.gameType,
          ),
        ),
        _chipTray(v, sel, myTurn),
        _actionRow(v, sel, myTurn),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _stageOverlay(YutView v) {
    final stage = _stage!;
    final by = _stageBy;
    final skin = yutSkinFromItem(v.itemOf(by, 'yut_yut'));
    final action = YutAction(
      seq: _stageSeq,
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
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.96,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: YutSticksStage(
              key: ValueKey('stage$_stageSeq'),
              thrown: stage,
              seed: _stageSeq,
              skin: skin,
              throwerName: by == c.me ? '내' : c.displayName(by),
              onLanded: () => _onSticksLanded(action),
              onDone: () => _onSticksDone(
                YutAction(
                  seq: _stageSeq,
                  type: 'throw',
                  by: by,
                  auto: _lastAutoFor(_stageSeq),
                  thrown: stage,
                  move: null,
                  turnPassed: false,
                  discardedBackdo: 0,
                  itemEffects: const [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _lastAutoFor(int seq) {
    final a = c.view?.lastAction;
    return a != null && a.seq == seq && a.auto;
  }

  Widget _infoRow(YutView v) {
    final t = _theme;
    final series = v.series;
    final hasSeries = ((series?['games'] as num?)?.toInt() ?? 0) > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 60, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GameChip(theme: t, leading: '🐎', label: '말 ${v.pieceCount}개'),
          if (v.stake > 0)
            GameChip(
              theme: t,
              leading: '🪙',
              label: '판돈 ${v.stake}',
              emphasized: true,
            ),
          if (v.stake > 0 && (v.coinBonus[c.me] ?? 0) > 0)
            GameChip(
              theme: t,
              leading: '🎁',
              label: '보너스 ${v.coinBonus[c.me]}',
            ),
          if (hasSeries) SeriesScore.fromMap(t, series, c.me),
        ],
      ),
    );
  }

  List<Widget> _itemBadges(YutView v, String? player) {
    final out = <Widget>[];
    for (final slot in const ['yut_yut', 'yut_piece']) {
      final item = v.itemOf(player, slot);
      if (item == null) continue;
      out.add(
        _ItemBadge(
          icon: '${item['icon'] ?? '🎁'}',
          grade: '${item['grade'] ?? 'B'}',
          onTap: () => _showItemSheet(item),
        ),
      );
    }
    return out;
  }

  void _showItemSheet(Map<String, dynamic> item) {
    final t = _theme;
    final stats = (item['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: GamePanel(
          theme: t,
          opaque: true,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${item['icon'] ?? '🎁'} ${item['name'] ?? '아이템'}',
                style: t.display(size: 20),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['grade'] ?? 'B'} 등급',
                style: t.body(size: 13, color: t.subInk),
              ),
              const SizedBox(height: 10),
              if (stats.isEmpty)
                Text('꾸미기 아이템이에요.', style: t.body(size: 13.5, color: t.subInk))
              else
                for (final e in stats.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${_statLabel(e.key)} ${e.value}',
                      style: t.body(size: 13.5),
                    ),
                  ),
              const SizedBox(height: 6),
              Text(
                '판돈 게임에서는 효과가 합쳐서 일정 한도까지만 적용돼요.',
                textAlign: TextAlign.center,
                style: t.body(size: 12, color: t.subInk, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statLabel(String key) =>
      const {
        'yut_control_pct': '윷 컨트롤 +%',
        'yut_mo_rate_pct': '모 확률 +%',
        'yut_backdo_bonus_pct': '빽도 보너스 던지기 %',
        'yut_win_coin_pct': '윷·모 추가 코인 %',
        'yut_overturn_pct': '역전 확률 +%',
        'piece_catch_resist_pct': '잡힘 방어 %',
        'piece_catch_coin_bonus': '잡기 추가 코인',
        'yut_catch_bonus': '잡기 보너스 코인',
        'piece_safe_zone_pct': '안전 착지 %',
        'piece_group_pct': '그룹 유지 %',
        'coin_bonus_pct': '코인 보너스 +%',
      }[key] ??
      '효과';

  Widget _chipTray(YutView v, _Sel sel, bool myTurn) {
    final t = _theme;
    var pending = v.pendingMoves;
    // 던지기 연출이 끝나기 전에는 새로 던진 칩을 숨긴다.
    final hide = _stage != null && !_stage!.nak && pending.isNotEmpty;
    final shown = hide ? pending.sublist(0, pending.length - 1) : pending;
    final chosenChip = sel.chip;
    String hint;
    if (v.winner != null) {
      hint = '판이 끝났어요';
    } else if (!myTurn) {
      hint = '${c.displayName(v.currentTurn)}의 차례예요';
    } else if (_playing) {
      hint = '윷가락이 굴러가는 중이에요';
    } else if (pending.isEmpty) {
      hint = '윷가락을 던져 주세요';
    } else if (_pieceId == null) {
      hint = shown.length > 1
          ? '던지기 결과를 고르고, 움직일 말을 눌러요'
          : '움직일 말을 눌러요 (대기 말은 아래 말판에서)';
    } else if (sel.preview.length > 1 && sel.chosen == null) {
      hint = '갈림길이에요. 가고 싶은 화살표를 눌러요';
    } else {
      hint = '붉은 길로 옮겨져요. 확인하고 눌러요';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      pending.isEmpty ? '던진 결과가 여기 쌓여요' : '…',
                      style: t.body(size: 12.5, color: t.subInk),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _ThrowChip(
                            steps: shown[i],
                            selected: myTurn && chosenChip == i && !_playing,
                            enabled: myTurn && !_playing,
                            onTap: () => _onChipTap(i),
                          ),
                        ),
                    ],
                  ),
          ),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: t.body(size: 12.5, color: t.subInk),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(YutView v, _Sel sel, bool myTurn) {
    final t = _theme;
    final chosen = sel.chosen;
    final canThrow = myTurn && v.canThrow && !_playing && !c.busy;
    final children = <Widget>[];
    if (chosen != null && myTurn && !_playing) {
      children.add(
        Expanded(
          flex: 3,
          child: GamePrimaryButton(
            theme: t,
            label: chosen.finish
                ? '골인시키기'
                : chosen.captures > 0
                ? '잡으러 가기'
                : '여기로 옮기기',
            icon: Icons.check_rounded,
            height: 50,
            onPressed: c.busy ? null : () => _confirm(chosen),
          ),
        ),
      );
      if (v.canThrow) {
        children
          ..add(const SizedBox(width: 8))
          ..add(
            Expanded(
              flex: 2,
              child: GameSecondaryButton(
                theme: t,
                label: '던지기',
                icon: Icons.casino_rounded,
                height: 50,
                onPressed: canThrow ? _throw : null,
              ),
            ),
          );
      }
    } else {
      final label = !myTurn
          ? '${c.displayName(v.currentTurn)}의 차례'
          : v.canThrow
          ? (v.pendingMoves.isEmpty ? '윷 던지기' : '한 번 더 던지기')
          : '말을 옮겨요';
      children.add(
        Expanded(
          child: GamePrimaryButton(
            theme: t,
            label: label,
            icon: myTurn && v.canThrow
                ? Icons.casino_rounded
                : Icons.hourglass_top_rounded,
            height: 50,
            onPressed: canThrow ? _throw : null,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Row(children: children),
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

/// 위·아래 플레이어 띠: 캐릭터 얼굴, 이름, 대기·도착 수, 대기 말, 남은 시간.
class _PlayerStrip extends StatelessWidget {
  final GameTheme theme;
  final String name;
  final String emoji;
  final String character;
  final Color color;
  final bool isMe;
  final bool active;
  final int waiting;
  final int finished;
  final int total;
  final String? skinEmoji;
  final GameDeadline? deadline;
  final List<Widget> items;
  final bool selectableWaiting;
  final bool waitingSelected;
  final VoidCallback? onTapWaiting;
  final Widget bubble;

  const _PlayerStrip({
    required this.theme,
    required this.name,
    required this.emoji,
    required this.character,
    required this.color,
    required this.isMe,
    required this.active,
    required this.waiting,
    required this.finished,
    required this.total,
    required this.skinEmoji,
    required this.deadline,
    required this.items,
    required this.bubble,
    this.selectableWaiting = false,
    this.waitingSelected = false,
    this.onTapWaiting,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: Semantics(
        label:
            '${isMe ? '나' : name}${active ? ', 차례' : ''}, 대기 말 $waiting개, 도착 $finished개',
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: active ? t.goldGradient : null,
                    color: active ? null : color.withValues(alpha: 0.75),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: t.gold.withValues(alpha: 0.7),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Obangsaek.white,
                    ),
                    child: YutCharacterFace(character: character, size: 43),
                  ),
                ),
                Positioned(left: 40, top: -10, child: bubble),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe && name != '나' ? '$name (나)' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body(size: 13.5, weight: FontWeight.w800),
                        ),
                      ),
                      for (final w in items) w,
                    ],
                  ),
                  Text(
                    '${yutCharacterNames[character] ?? ''} · 대기 $waiting · 도착 $finished/$total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(
                      size: 12,
                      color: t.subInk,
                      weight: FontWeight.w600,
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
            // 대기 말(나는 눌러서 고른다).
            SizedBox(
              width: 52,
              height: 52,
              child: waiting <= 0
                  ? const SizedBox.shrink()
                  : Semantics(
                      button: selectableWaiting,
                      label: '대기 말 $waiting개',
                      child: GestureDetector(
                        key: isMe ? const ValueKey('yut_waiting_piece') : null,
                        behavior: HitTestBehavior.opaque,
                        onTap: selectableWaiting ? onTapWaiting : null,
                        child: Center(
                          child: YutToken(
                            size: 40,
                            color: color,
                            character: character,
                            skinEmoji: skinEmoji,
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

class _ItemBadge extends StatelessWidget {
  final String icon;
  final String grade;
  final VoidCallback onTap;

  const _ItemBadge({
    required this.icon,
    required this.grade,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      'SSS' => const Color(0xFFD9541E),
      'SS' => const Color(0xFF8E3BA8),
      'S' => const Color(0xFF2F6FB5),
      'A' => const Color(0xFF3F8F4F),
      _ => const Color(0xFF7A7467),
    };
    return Semantics(
      button: true,
      label: '장착 아이템 $grade 등급',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$icon $grade',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.2,
              ),
            ),
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
      child: GameChip(theme: GameTheme.hanji, label: message, emphasized: true),
    );
  }
}
