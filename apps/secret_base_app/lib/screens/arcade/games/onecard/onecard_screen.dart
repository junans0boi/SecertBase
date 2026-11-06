import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'onecard_cards.dart';
import 'onecard_controller.dart';
import 'onecard_hand.dart';
import 'onecard_models.dart';
import 'onecard_panels.dart';
import 'onecard_table.dart';
import 'onecard_ui.dart';

/// 원카드 2.0 — 쇼타임(짙은 보라 무대 + 한 줄기 스포트라이트, OneCardUi).
/// 서버가 로비 시작과 함께 판을 만든다. 이 화면에는 시작 버튼이 없다(Q12).
class OneCardScreen extends StatefulWidget {
  const OneCardScreen({super.key});

  @override
  State<OneCardScreen> createState() => _OneCardScreenState();
}

class _Flight {
  final Widget child;
  final Offset from;
  final Offset to;
  final double size;
  final double spin;
  final AnimationController ctl;

  _Flight({
    required this.child,
    required this.from,
    required this.to,
    required this.size,
    required this.spin,
    required this.ctl,
  });
}

class _OneCardScreenState extends State<OneCardScreen>
    with TickerProviderStateMixin {
  static final _theme = OneCardUi.theme;
  static const _sounds = [
    GameSound.cardDeal,
    GameSound.cardPlace,
    GameSound.cardShuffle,
    GameSound.colorChange,
    GameSound.oneCardCall,
    GameSound.caught,
    GameSound.penaltyDraw,
    GameSound.skip,
    GameSound.reverse,
    GameSound.turnMine,
    GameSound.turnOpp,
    GameSound.tick,
    GameSound.whoosh,
    GameSound.sparkle,
    GameSound.start,
    GameSound.warn,
    GameSound.select,
    GameSound.win,
    GameSound.lose,
  ];

  final OneCardController c = OneCardController.instance;
  final SocketService _socket = SocketService();

  final _stackKey = GlobalKey();
  final _deckKey = GlobalKey();
  final _discardKey = GlobalKey();
  final _handKey = GlobalKey();
  final _oppKey = GlobalKey();

  final List<_Flight> _flights = [];
  final List<Timer> _timers = [];
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  String? _glowColor;

  String? _seenGame;
  int _seenSeq = -1;
  int _seenNotice = 0;
  bool _wasMyTurn = false;
  bool _couldCall = false;
  int _dealReveal = 1 << 20;
  Set<String> _fresh = {};

  Object? _toastId;
  String? _toast;
  bool _toastLive = false;
  int _toastSeq = 0;

  String? _resultFor;
  bool _showResult = false;
  int _syncRetries = 0;
  bool _colorSheetOpen = false;
  BuildContext? _colorSheetContext;

  final List<({int id, String stat})> _itemEffects = [];
  int _effectSeq = 0;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(_sounds);
    _seenNotice = c.noticeSeq;
    c.addListener(_onController);
    _socket.setItemEffectCallback(_onItemEffect);
    // 이미 받은 판이 있으면(재진입) 연출 없이 이어서 보여 준다.
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
        prefKey: 'onecard_howto_v2_seen',
        theme: _theme,
        title: '원카드',
        emoji: '🃏',
        lines: kOneCardHowToLines,
      );
    });
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _socket.setItemEffectCallback(null);
    for (final timer in _timers) {
      timer.cancel();
    }
    for (final f in _flights) {
      f.ctl.dispose();
    }
    _glow.dispose();
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

  void _onItemEffect(Map<String, dynamic> data) {
    if (!mounted) return;
    final id = _effectSeq++;
    setState(() => _itemEffects.add((id: id, stat: '${data['stat'] ?? ''}')));
    GameSfx.instance.play(GameSound.sparkle);
    _after(2600, () {
      setState(() => _itemEffects.removeWhere((e) => e.id == id));
    });
  }

  // ── 상태 변화 → 연출·소리 ─────────────────────────────────────────────────
  void _onController() {
    if (!mounted) return;
    // 색 고르기 창을 띄운 사이 차례가 넘어가면(시간 초과 등) 창을 닫는다.
    final sheet = _colorSheetContext;
    if (_colorSheetOpen && sheet != null && !c.isMyTurn && sheet.mounted) {
      Navigator.of(sheet).pop();
    }
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
        _fresh = {};
        if (v.lastAction?.type == 'deal') _startDeal(v);
      } else if (v.seq > _seenSeq) {
        _seenSeq = v.seq;
        final a = v.lastAction;
        if (a != null) _animateAction(a, v);
      }
      final mine = v.currentPlayer == c.me;
      if (mine && !_wasMyTurn && c.result == null) {
        _after(_dealReveal < 7 ? 1500 : 250, () {
          if (c.view?.currentPlayer != c.me || c.result != null) return;
          GameSfx.instance.play(GameSound.turnMine);
          // 내 차례는 판 위의 "내 차례" 알약으로 보여 준다.
        });
      }
      _wasMyTurn = mine;
    }
    final canCall = c.canCall;
    if (canCall && !_couldCall && c.result == null) {
      _showToast('한 장 남았어요! 잡히기 전에 외쳐요');
    }
    _couldCall = canCall;
    final r = c.result;
    if (r != null && r.gameId != _resultFor) {
      _resultFor = r.gameId;
      _showResult = false;
      if (r.reason == 'empty_hand') {
        _after(450, () {
          GameSfx.instance.play(GameSound.oneCardCall);
          _showToast('원카드! ${c.displayName(r.winner)} 승리');
        });
      }
      _after(r.reason == 'empty_hand' ? 1500 : 300, () {
        setState(() => _showResult = true);
      });
    }
    setState(() {});
  }

  void _showToast(String message) {
    final seq = ++_toastSeq;
    setState(() {
      _toastId = Object();
      _toast = message;
      _toastLive = true;
    });
    _after(2300, () {
      if (seq == _toastSeq) setState(() => _toastLive = false);
    });
  }

  Offset _centerOf(GlobalKey key, {Offset fallback = Offset.zero}) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null || !box.attached || !stack.attached) {
      return fallback;
    }
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  Size get _stackSize =>
      (_stackKey.currentContext?.findRenderObject() as RenderBox?)?.size ??
      const Size(390, 760);

  Offset _seatOf(String? player) {
    final size = _stackSize;
    return player == c.me
        ? _centerOf(
            _handKey,
            fallback: Offset(size.width / 2, size.height - 120),
          )
        : _centerOf(_oppKey, fallback: Offset(size.width / 2, 110));
  }

  void _fly(
    Widget child, {
    required Offset from,
    required Offset to,
    int delayMs = 0,
    int ms = 420,
    double size = 56,
    double spin = 0,
    VoidCallback? onStart,
  }) {
    void launch() {
      final ctl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      );
      final flight = _Flight(
        child: child,
        from: from,
        to: to,
        size: size,
        spin: spin,
        ctl: ctl,
      );
      setState(() => _flights.add(flight));
      onStart?.call();
      ctl.forward().whenCompleteOrCancel(() {
        if (mounted) setState(() => _flights.remove(flight));
        ctl.dispose();
      });
    }

    if (delayMs <= 0) {
      launch();
    } else {
      _after(delayMs, launch);
    }
  }

  void _startDeal(OneCardView v) {
    final deck = _centerOf(_deckKey, fallback: _stackSize.center(Offset.zero));
    final opp = v.opponentOf(c.me);
    final skinMe = _skinOf(c.me);
    final skinOpp = _skinOf(opp);
    GameSfx.instance.play(GameSound.cardShuffle);
    setState(() => _dealReveal = 0);
    for (var i = 0; i < 14; i++) {
      final toMe = i.isEven;
      _fly(
        OneCardBack(width: 52, skin: toMe ? skinMe : skinOpp),
        from: deck,
        to: _seatOf(toMe ? c.me : opp),
        delayMs: 200 + i * 85,
        ms: 340,
        spin: toMe ? 0.4 : -0.4,
        onStart: () => GameSfx.instance.play(GameSound.cardDeal, minGapMs: 30),
      );
      if (toMe) {
        _after(200 + i * 85 + 330, () {
          setState(() => _dealReveal = i ~/ 2 + 1);
        });
      }
    }
    _after(200 + 14 * 85 + 400, () {
      setState(() => _dealReveal = 1 << 20);
      GameSfx.instance.play(GameSound.start);
    });
  }

  String _skinOf(String? player) => OneCardBack.skinFromItem(
    (c.view?.equippedItems[player]?['onecard_cardback'] as Map?)
        ?.cast<String, dynamic>(),
  );

  void _animateAction(OneCardAction a, OneCardView v) {
    final sfx = GameSfx.instance;
    final deck = _centerOf(_deckKey, fallback: _stackSize.center(Offset.zero));
    final pile = _centerOf(
      _discardKey,
      fallback: _stackSize.center(Offset.zero),
    );
    final who = c.displayName(a.by);
    final mine = a.by == c.me;
    switch (a.type) {
      case 'play':
        final from = _seatOf(a.by);
        for (var i = 0; i < a.cards.length; i++) {
          _fly(
            OneCardFace(card: a.cards[i], width: 56),
            from: from + Offset((i - a.cards.length / 2) * 6, 0),
            to: pile,
            delayMs: i * 90,
            ms: 380,
            spin: mine ? -0.35 : 0.35,
            onStart: () => sfx.play(GameSound.cardPlace, minGapMs: 30),
          );
        }
        final settle = a.cards.length * 90 + 300;
        _after(settle, () {
          switch (a.effect) {
            case 'skip':
              sfx.play(GameSound.skip);
              _showToast(mine ? '건너뛰기! 한 번 더 내요' : '$who의 건너뛰기! 차례가 넘어가요');
            case 'reverse':
              sfx.play(GameSound.reverse);
              _showToast(mine ? '방향 바꾸기! 한 번 더 내요' : '$who의 방향 바꾸기!');
            case 'draw2':
              sfx.play(GameSound.whoosh);
              _showToast(mine ? '+2 공격!' : '$who의 +2 공격! 막거나 받아요');
            case 'draw4':
              sfx.play(GameSound.whoosh);
              if (!mine) _showToast('$who의 +4 공격!');
            case 'discard_all':
              sfx.play(GameSound.sparkle);
              _showToast('같은 색 ${a.cards.length}장을 모두 냈어요!');
          }
          if (a.colorChanged && a.declaredColor != null) {
            sfx.play(GameSound.colorChange);
            setState(() => _glowColor = a.declaredColor);
            _glow.forward(from: 0);
            if (a.effect == 'wild' || !mine) {
              _showToast('$who: 지금 색은 ${OneCardColors.name(a.declaredColor)}!');
            }
          }
        });
      case 'draw':
        final n = math.min(a.count, 8);
        for (var i = 0; i < n; i++) {
          _fly(
            OneCardBack(width: 50, skin: _skinOf(a.by)),
            from: deck,
            to: _seatOf(a.by),
            delayMs: i * 80,
            ms: 360,
            spin: mine ? 0.3 : -0.3,
            onStart: () => sfx.play(
              a.penalty ? GameSound.penaltyDraw : GameSound.cardDeal,
              minGapMs: 60,
            ),
          );
        }
        if (mine && a.cardIds.isNotEmpty) {
          _after(n * 80 + 300, () {
            setState(() => _fresh = a.cardIds.toSet());
          });
          _after(4500, () {
            if (setEquals(_fresh, a.cardIds.toSet())) {
              setState(() => _fresh = {});
            }
          });
        }
        if (a.auto) {
          _showToast(
            a.penalty
                ? '시간이 지나 $who${josa(who, '이', '가')} 벌칙 ${a.count}장을 받았어요'
                : '시간이 지나 $who${josa(who, '이', '가')} 한 장 뽑고 넘겼어요',
          );
        } else if (a.penalty) {
          _showToast(
            mine
                ? '벌칙 ${a.count}장을 받았어요'
                : '$who${josa(who, '이', '가')} 벌칙 ${a.count}장을 받았어요',
          );
        }
      case 'pass':
        if (a.auto) _showToast('시간이 지나 $who의 차례가 넘어갔어요');
      case 'call':
        sfx.play(GameSound.oneCardCall);
        _showToast('$who: 원카드!');
      case 'catch':
        final target = c.displayName(a.target);
        if (a.protectedCatch) {
          sfx.play(GameSound.sparkle);
          _showToast('잡혔지만 $target의 아이템이 막았어요!');
        } else {
          sfx.play(GameSound.caught);
          _showToast(a.target == c.me ? '잡혔어요! 2장을 받아요' : '잡았다! $target +2장');
          for (var i = 0; i < a.count; i++) {
            _fly(
              OneCardBack(width: 50, skin: _skinOf(a.target)),
              from: deck,
              to: _seatOf(a.target),
              delayMs: 120 + i * 90,
              ms: 360,
            );
          }
        }
      case 'challenge':
        final drawn = c.displayName(a.drawnPlayer);
        sfx.play(a.success ? GameSound.sparkle : GameSound.penaltyDraw);
        _showToast(
          a.success
              ? '도전 성공! $drawn${josa(drawn, '이', '가')} ${a.drawnCount}장을 받아요'
              : '도전 실패! $drawn${josa(drawn, '이', '가')} ${a.drawnCount}장을 받아요',
        );
        for (var i = 0; i < math.min(a.drawnCount, 6); i++) {
          _fly(
            OneCardBack(width: 50, skin: _skinOf(a.drawnPlayer)),
            from: deck,
            to: _seatOf(a.drawnPlayer),
            delayMs: 200 + i * 80,
            ms: 360,
          );
        }
        if (a.drawnPlayer == c.me && a.cardIds.isNotEmpty) {
          setState(() => _fresh = a.cardIds.toSet());
        }
    }
  }

  // ── 조작 ──────────────────────────────────────────────────────────────────
  Future<void> _onCardTap(OneCard card) async {
    final v = c.view;
    if (v == null || !c.isMyTurn) {
      _showToast('아직 내 차례가 아니에요.');
      return;
    }
    if (!v.playable.contains(card.id)) {
      _showToast(
        v.drawStack > 0
            ? '쌓인 벌칙을 막을 카드만 낼 수 있어요.'
            : v.drawnCardId != null
            ? '방금 뽑은 카드만 낼 수 있어요.'
            : '지금 색(${OneCardColors.name(v.currentColor)})이나 같은 숫자를 내요.',
      );
      return;
    }
    if (card.isWild) {
      if (_colorSheetOpen) return;
      setState(() => _colorSheetOpen = true);
      final color = await _pickColor(v);
      _colorSheetContext = null;
      if (mounted) setState(() => _colorSheetOpen = false);
      if (color == null || !mounted || !c.isMyTurn) return;
      c.play(card, color: color);
      return;
    }
    GameSfx.instance.play(GameSound.select);
    c.play(card);
  }

  Future<String?> _pickColor(OneCardView v) {
    final counts = <String, int>{};
    for (final card in v.hand) {
      final color = card.color;
      if (color != null) counts[color] = (counts[color] ?? 0) + 1;
    }
    String best = OneCardColors.order.first;
    var bestN = -1;
    for (final color in OneCardColors.order) {
      final n = counts[color] ?? 0;
      if (n > bestN) {
        best = color;
        bestN = n;
      }
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x9E0A0516),
      isScrollControlled: true,
      builder: (ctx) {
        _colorSheetContext = ctx;
        return OneCardColorSheet(counts: counts, initial: best);
      },
    );
  }

  // ── 화면 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OneCardUi.bg,
      body: GameMenuListener(
        gameType: OneCardController.gameType,
        child: OneCardBackdrop(
          child: ListenableBuilder(
            listenable: Listenable.merge([c, _socket]),
            builder: (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: SafeArea(
                    child: Stack(
                      key: _stackKey,
                      children: [
                        if (c.view != null)
                          const Positioned(
                            top: 56,
                            left: 0,
                            right: 0,
                            child: Center(child: OneCardSpot()),
                          ),
                        Positioned.fill(child: _body()),
                        Positioned.fill(
                          child: IgnorePointer(child: _flightLayer()),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(child: _glowLayer()),
                        ),
                        if (c.view == null)
                          Positioned(
                            top: 120,
                            left: 0,
                            right: 0,
                            child: OneCardToast(id: _toastId, message: _toast),
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
                                      stat: e.stat,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
    );
  }

  Widget _body() {
    final t = _theme;
    final v = c.view;
    final topBar = OneCardTopBar(
      tag: v == null ? '준비 중' : (v.mode == 'classic' ? '클래식' : '고와일드'),
      onHelp: () => showOneCardHowTo(context),
      trailing: GameMenuButton(
        hasRestart: v != null || c.result != null,
        restartWaiting: _socket.restartWaiting,
        onRequestRestart: c.requestRematch,
        iconColor: OneCardUi.sub,
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
    final myTurn = v.currentPlayer == me && c.result == null;
    final oppTurn = v.currentPlayer == opp && c.result == null;
    final deadline = GameDeadline.fromServer(
      deadlineMs: v.turnDeadline,
      serverNowMs: v.serverNow,
      total: Duration(milliseconds: v.turnMs),
      receivedAt: v.receivedAt,
    );
    final hand = [...v.hand]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final oppCount = v.countOf(opp);
    final oppName = c.displayName(opp);
    final playN = v.playable.length;
    final String mySub;
    OneCardSub mySubStyle = OneCardSub.plain;
    if (_colorSheetOpen) {
      mySub = '색을 골라 주세요';
      mySubStyle = OneCardSub.hi;
    } else if (myTurn && v.drawStack > 0) {
      mySub = playN > 0 ? '막을 수 있음 $playN장' : '막을 카드가 없어요';
      mySubStyle = OneCardSub.warn;
    } else if (myTurn && v.drawnCardId != null) {
      mySub = playN > 0 ? '방금 뽑은 카드를 낼 수 있어요' : '뽑은 카드는 낼 수 없어요';
      mySubStyle = OneCardSub.hi;
    } else if (myTurn && playN > 0) {
      mySub = '낼 수 있음 $playN장';
      mySubStyle = OneCardSub.hi;
    } else if (myTurn) {
      mySub = '낼 카드가 없어요';
    } else if (v.hand.length == 1) {
      mySub = '1장 남음';
      mySubStyle = OneCardSub.hi;
    } else {
      mySub = '손패 ${v.hand.length}장';
    }
    String? alert;
    if (v.drawStack > 0 && !_colorSheetOpen) {
      final plus = v.topCard?.value == 'wild_draw4' ? '+4' : '+2';
      alert = myTurn
          ? '$oppName의 $plus 공격! 막거나 받아요'
          : '벌칙이 ${v.drawStack}장 쌓였어요';
    }
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return LayoutBuilder(
      builder: (context, box) {
        // 목업의 넉넉한 간격은 화면 높이에 여유가 있을 때만 쓴다(없으면 판이 줄어든다).
        final handH = OneCardHandFan.heightFor(
          oneCardHandWidth(hand.length, box.maxWidth),
        );
        final tight =
            44 +
            12 +
            52 +
            16 +
            OneCardTable.frameH +
            8 +
            52 +
            8 +
            handH +
            14 +
            56 +
            16;
        final f = ((box.maxHeight - tight) / 52).clamp(0.0, 1.0);
        return Column(
          children: [
            topBar,
            const SizedBox(height: 12),
            // 위: 상대 캡슐 + 겹친 뒷면 부채
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        OneCardPlayerCap(
                          name: oppName,
                          sub: oppCount == 1 ? '1장 남음' : '손패 $oppCount장',
                          subStyle: oppCount == 1
                              ? OneCardSub.warn
                              : OneCardSub.plain,
                          active: oppTurn,
                          deadline: oppTurn ? deadline : null,
                        ),
                        Positioned(
                          left: 30,
                          top: -6,
                          child: ReactionBubble(
                            theme: t,
                            forPlayer: opp,
                            gameType: OneCardController.gameType,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  KeyedSubtree(
                    key: _oppKey,
                    child: OneCardOpponentFan(
                      count: oppCount,
                      skin: _skinOf(opp),
                      revealCount: _dealReveal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 가운데 판
            Expanded(
              child: Center(
                child: OneCardTable(
                  deckKey: _deckKey,
                  discardKey: _discardKey,
                  topCard: v.topCard,
                  recentDiscards: v.recentDiscards,
                  currentColor: v.currentColor,
                  declaredColor: v.declaredColor,
                  drawStack: v.drawStack,
                  deckCount: v.deckCount,
                  deckSkin: _skinOf(me),
                  canDraw: myTurn && v.drawnCardId == null,
                  onDraw: c.draw,
                  banner: myTurn && !_colorSheetOpen && v.drawStack == 0
                      ? '내 차례'
                      : null,
                  alert: alert,
                  toastLive: _toastLive,
                  toast: OneCardToast(id: _toastId, message: _toast),
                  corner: _showResult
                      ? null
                      : ReactionButton(
                          theme: t,
                          gameType: OneCardController.gameType,
                        ),
                ),
              ),
            ),
            SizedBox(height: 8 + 10 * f),
            // 내 캡슐(시간 링) + 원카드!/잡기!
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Flexible(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        OneCardPlayerCap(
                          name: '나',
                          sub: mySub,
                          subStyle: mySubStyle,
                          mine: true,
                          active: myTurn,
                          deadline: myTurn ? deadline : null,
                          tickSound: true,
                        ),
                        Positioned(
                          left: 30,
                          top: -30,
                          child: ReactionBubble(
                            theme: t,
                            forPlayer: me,
                            gameType: OneCardController.gameType,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OneCardCallButton(
                    label: '원카드!',
                    semantics: '원카드 외치기',
                    enabled: c.canCall,
                    primary: true,
                    compact: narrow,
                    onTap: () {
                      GameSfx.instance.play(GameSound.oneCardCall);
                      c.callOneCard();
                    },
                  ),
                  const SizedBox(width: 8),
                  OneCardCallButton(
                    label: '잡기!',
                    semantics: '원카드를 안 외친 상대 잡기',
                    enabled: c.canCatch,
                    primary: false,
                    compact: narrow,
                    onTap: c.catchOpponent,
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 + 4 * f),
            // 아래: 손패 부채
            KeyedSubtree(
              key: _handKey,
              child: OneCardHandFan(
                cards: hand,
                playable: v.playable,
                fresh: _fresh,
                active: myTurn,
                revealCount: _dealReveal,
                onTap: _onCardTap,
              ),
            ),
            SizedBox(height: 14 + 24 * f),
            _actionRow(v, myTurn),
            SizedBox(height: 16 + 14 * f),
          ],
        );
      },
    );
  }

  Widget _actionRow(OneCardView v, bool myTurn) {
    final buttons = <Widget>[];
    if (myTurn && v.canChallenge) {
      buttons.add(
        Expanded(
          child: OneCardMainButton(
            label: '도전!',
            style: OneCardButtonStyle.ghost,
            onPressed: c.challenge,
          ),
        ),
      );
    }
    if (myTurn && v.drawnCardId != null) {
      buttons.add(
        Expanded(
          child: OneCardMainButton(
            label: '넘기기',
            style: OneCardButtonStyle.ghost,
            onPressed: c.pass,
          ),
        ),
      );
    } else {
      final label = !myTurn
          ? '${c.displayName(v.currentPlayer)}의 차례'
          : v.drawStack > 0
          ? '벌칙 ${v.drawStack}장 받기'
          : v.playable.isEmpty
          ? '한 장 뽑기'
          : '뽑기';
      buttons.add(
        Expanded(
          flex: 2,
          child: OneCardMainButton(
            label: label,
            style: !myTurn
                ? OneCardButtonStyle.off
                : v.drawStack > 0
                ? OneCardButtonStyle.rose
                : v.playable.isEmpty
                ? OneCardButtonStyle.primary
                : OneCardButtonStyle.ghost,
            onPressed: myTurn ? c.draw : null,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            buttons[i],
          ],
        ],
      ),
    );
  }

  Widget _preparing() {
    final isHost = _socket.lobbyHost != null && _socket.lobbyHost == c.me;
    final failed =
        c.syncStatus != null &&
        c.syncStatus != 'ok' &&
        c.syncStatus != 'no_game';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: OneCardUi.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OneCardBack(width: 64),
              const SizedBox(height: 18),
              Text(
                '방장이 판을 준비하는 중…',
                textAlign: TextAlign.center,
                style: OneCardUi.sans(size: 17, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '판을 불러오지 못했어요. ${OneCardController.reasonMessages[c.syncStatus] ?? '연결 상태를 확인해 주세요.'}'
                    : '카드를 섞고 있어요. 잠시만 기다려 주세요.',
                textAlign: TextAlign.center,
                style: OneCardUi.sans(
                  size: 13,
                  color: OneCardUi.sub,
                  height: 1.5,
                ),
              ),
              if (c.syncing) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: OneCardUi.vio2,
                  ),
                ),
              ],
              if (isHost) ...[
                const SizedBox(height: 18),
                OneCardMainButton(
                  label: '다시 불러오기',
                  style: OneCardButtonStyle.ghost,
                  height: 48,
                  icon: Icons.refresh_rounded,
                  onPressed: c.sync,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _flightLayer() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final f in _flights)
          AnimatedBuilder(
            animation: f.ctl,
            builder: (context, child) {
              final k = Curves.easeInOutCubic.transform(f.ctl.value);
              final p = Offset.lerp(f.from, f.to, k)!;
              final lift = math.sin(k * math.pi) * -36;
              final w = f.size;
              final h = w * kOneCardAspect;
              return Positioned(
                left: p.dx - w / 2,
                top: p.dy - h / 2 + lift,
                child: Transform.rotate(
                  angle: f.spin * (1 - k),
                  child: Transform.scale(
                    scale: 0.92 + 0.16 * math.sin(k * math.pi),
                    child: child,
                  ),
                ),
              );
            },
            child: f.child,
          ),
      ],
    );
  }

  Widget _glowLayer() {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final v = _glow.value;
        if (_glowColor == null || v == 0 || v == 1) {
          return const SizedBox.shrink();
        }
        final a = math.sin(v * math.pi);
        final color = OneCardColors.of(_glowColor);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.95 + 0.25 * v,
              colors: [
                Colors.transparent,
                color.withValues(alpha: 0.05 * a),
                color.withValues(alpha: 0.55 * a),
              ],
              stops: const [0.5, 0.78, 1],
            ),
          ),
        );
      },
    );
  }

  Widget _resultOverlay(OneCardResult r) {
    final me = c.me;
    final won = r.winner == me;
    final opp = r.winner == me ? r.loser : r.winner;
    final reason = r.forfeit
        ? (won
              ? '${c.displayName(opp)}의 시간 초과가 이어져 기권승이에요.'
              : '시간 초과가 이어져 기권패가 되었어요.')
        : (won
              ? '손패를 모두 비웠어요!'
              : '${c.displayName(r.winner)}${josa(c.displayName(r.winner), '이', '가')} 먼저 손패를 비웠어요.');
    final loser = r.winner == me ? opp : me;
    final loserHand = r.hands[loser] ?? const <OneCard>[];
    final wins = (r.series?['wins'] as Map?) ?? const {};
    var myWins = 0, oppWins = 0;
    wins.forEach((k, n) {
      final count = (n as num?)?.toInt() ?? 0;
      if (k == me) {
        myWins = count;
      } else {
        oppWins += count;
      }
    });
    return OneCardResultSheet(
      won: won,
      title: r.forfeit ? (won ? '기권승!' : '기권패') : (won ? '승리!' : '아쉬운 패배'),
      reason: reason,
      stake: r.stake,
      loserLabel: loser == me ? '내 남은 손패' : '${c.displayName(loser)}의 남은 손패',
      loserHand: loserHand,
      myWins: myWins,
      oppWins: oppWins,
      draws: (r.series?['draws'] as num?)?.toInt() ?? 0,
      resultId: r.gameId,
      rematchWaiting: _socket.restartWaiting,
      onRematch: c.requestRematch,
    );
  }
}

class _ItemEffectBadge extends StatelessWidget {
  final String stat;
  const _ItemEffectBadge({super.key, required this.stat});

  static String message(String stat) => switch (stat) {
    'card_shield_pct' => '🛡️ 아이템 효과 — 벌칙을 막았어요!',
    'card_lucky_draw_pct' => '🍀 아이템 효과 — 한 장 덜 받아요!',
    'card_reverse_bonus' => '↩️ 아이템 효과 — 상대가 한 장 더 받아요!',
    'card_uno_protect_pct' => '🧿 아이템 효과 — 잡혀도 무사해요!',
    _ => '✨ 아이템 효과 발동!',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0x338E6CF2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0x4DB9A2FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message(stat),
              style: OneCardUi.sans(
                size: 12,
                color: OneCardUi.vio2,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
