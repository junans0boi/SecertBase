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
import 'onecard_table.dart';

/// 원카드 2.0 — 자정의 카드 살롱(GameTheme.salon).
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
  static const _theme = GameTheme.salon;
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
  int _dealReveal = 1 << 20;
  Set<String> _fresh = {};

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  Color? _bannerColor;

  Object? _toastId;
  String? _toast;

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
        lines: _howToLines,
      );
    });
  }

  static const _howToLines = [
    '지금 색이나 같은 숫자·기호 카드를 내요. 먼저 손패를 비우면 승리!',
    '낼 카드가 없으면 더미에서 한 장 뽑아요. 낼 수 있으면 바로 내거나 넘겨요.',
    '건너뛰기·방향 바꾸기 카드는 한 번 더, +2·+4는 상대에게 벌칙. 고와일드에선 벌칙을 쌓아 넘길 수 있어요.',
    '◐ 색 바꾸기와 +4는 원하는 색을 골라요. "모두"는 같은 색 카드를 한꺼번에 내요.',
    '한 장 남으면 "원카드!"를 눌러요. 먼저 "잡기!"를 당하면 2장을 받아요.',
    '+4는 그 색이 있었는데 냈다면 "도전!"으로 잡을 수 있어요. 20초가 지나면 자동으로 한 장 뽑고 넘어가요.',
  ];

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
          _banner('내 차례!', color: _theme.me);
        });
      }
      _wasMyTurn = mine;
    }
    final r = c.result;
    if (r != null && r.gameId != _resultFor) {
      _resultFor = r.gameId;
      _showResult = false;
      if (r.reason == 'empty_hand') {
        _after(450, () {
          GameSfx.instance.play(GameSound.oneCardCall);
          _banner(
            '원카드!',
            sub: '${c.displayName(r.winner)} 승리',
            color: _theme.gold,
          );
        });
      }
      _after(r.reason == 'empty_hand' ? 1500 : 300, () {
        setState(() => _showResult = true);
      });
    }
    setState(() {});
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
                ? '시간이 지나 $who이(가) 벌칙 ${a.count}장을 받았어요'
                : '시간이 지나 $who이(가) 한 장 뽑고 넘겼어요',
          );
        } else if (a.penalty) {
          _showToast(
            mine ? '벌칙 ${a.count}장을 받았어요' : '$who이(가) 벌칙 ${a.count}장을 받았어요',
          );
        }
      case 'pass':
        if (a.auto) _showToast('시간이 지나 $who의 차례가 넘어갔어요');
      case 'call':
        sfx.play(GameSound.oneCardCall);
        _banner('원카드!', sub: who, color: _theme.gold);
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
              ? '도전 성공! $drawn이(가) ${a.drawnCount}장을 받아요'
              : '도전 실패! $drawn이(가) ${a.drawnCount}장을 받아요',
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
      _colorSheetOpen = true;
      final color = await _pickColor(v);
      _colorSheetOpen = false;
      _colorSheetContext = null;
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
    String? best;
    counts.forEach((k, n) {
      if (best == null || n > counts[best]!) best = k;
    });
    final t = _theme;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        _colorSheetContext = ctx;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GamePanel(
              theme: t,
              radius: 26,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('어떤 색으로 바꿀까요?', style: t.display(size: 21)),
                  const SizedBox(height: 4),
                  Text(
                    '상대도 바뀐 색을 바로 봐요',
                    style: t.body(size: 12.5, color: t.subInk),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final color in OneCardColors.order)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ColorButton(
                              color: color,
                              count: counts[color] ?? 0,
                              suggested: color == best,
                              onTap: () => Navigator.of(ctx).pop(color),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('취소', style: t.body(size: 14, color: t.subInk)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 화면 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: OneCardController.gameType,
        child: GameBackdrop(
          theme: t,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([c, _socket]),
              builder: (context, _) => Stack(
                key: _stackKey,
                children: [
                  Positioned.fill(child: _body()),
                  Positioned.fill(child: IgnorePointer(child: _flightLayer())),
                  Positioned.fill(child: IgnorePointer(child: _glowLayer())),
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
                    child: GameToast(theme: t, id: _toastId, message: _toast),
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
                  if (c.view != null && !_showResult)
                    Positioned(
                      right: 10,
                      top: 58,
                      child: ReactionButton(
                        theme: t,
                        gameType: OneCardController.gameType,
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
    );
  }

  Widget _body() {
    final t = _theme;
    final v = c.view;
    final topBar = GameTopBar(
      theme: t,
      title: '원카드',
      gameType: OneCardController.gameType,
      canRestart: v != null || c.result != null,
      restartWaiting: _socket.restartWaiting,
      onRequestRestart: c.requestRematch,
      onHelp: () => showGameHowTo(
        context,
        theme: t,
        title: '원카드',
        emoji: '🃏',
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
    return Column(
      children: [
        topBar,
        // 위: 상대 칩 + 겹친 뒷면 부채
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PlayerBadge(
                      theme: t,
                      emoji: c.emojiOf(opp),
                      name: c.displayName(opp),
                      subtitle: '손패 $oppCount장',
                      active: oppTurn,
                      compact: true,
                      align: CrossAxisAlignment.start,
                      extra: oppCount == 1
                          ? Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: GameChip(
                                theme: t,
                                label: '1장 남음',
                                color: const Color(0xFFFF8FA8),
                                emphasized: true,
                              ),
                            )
                          : null,
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
              if (oppTurn)
                TurnTimerRing(theme: t, deadline: deadline, size: 40),
              const SizedBox(width: 52),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: KeyedSubtree(
            key: _oppKey,
            child: OneCardOpponentFan(
              count: oppCount,
              skin: _skinOf(opp),
              revealCount: _dealReveal,
            ),
          ),
        ),
        // 가운데 판
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: OneCardTable(
              theme: t,
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
              mode: v.mode,
            ),
          ),
        ),
        // 내 칩 + 시간 링 + 원카드!/잡기!
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PlayerBadge(
                      theme: t,
                      emoji: c.emojiOf(me),
                      name: c.displayName(me),
                      subtitle: myTurn ? '내 차례' : '손패 ${v.hand.length}장',
                      active: myTurn,
                      isMe: true,
                      compact: true,
                      align: CrossAxisAlignment.start,
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
              if (myTurn) ...[
                TurnTimerRing(
                  theme: t,
                  deadline: deadline,
                  size: 40,
                  tickSound: true,
                ),
                const SizedBox(width: 6),
              ],
              _CallButton(
                label: '원카드!',
                semantics: '원카드 외치기',
                enabled: c.canCall,
                gold: true,
                onTap: () {
                  GameSfx.instance.play(GameSound.oneCardCall);
                  c.callOneCard();
                },
              ),
              const SizedBox(width: 6),
              _CallButton(
                label: '잡기!',
                semantics: '원카드를 안 외친 상대 잡기',
                enabled: c.canCatch,
                gold: false,
                onTap: c.catchOpponent,
              ),
            ],
          ),
        ),
        // 아래: 손패 부채
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: KeyedSubtree(
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
        ),
        _actionRow(v, myTurn),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _actionRow(OneCardView v, bool myTurn) {
    final t = _theme;
    final buttons = <Widget>[];
    if (myTurn && v.canChallenge) {
      buttons.add(
        Expanded(
          child: GameSecondaryButton(
            theme: t,
            label: '도전!',
            icon: Icons.gavel_rounded,
            height: 46,
            onPressed: c.challenge,
          ),
        ),
      );
    }
    if (myTurn && v.drawnCardId != null) {
      buttons.add(
        Expanded(
          child: GameSecondaryButton(
            theme: t,
            label: '넘기기',
            icon: Icons.skip_next_rounded,
            height: 46,
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
          child: GamePrimaryButton(
            theme: t,
            label: label,
            icon: myTurn ? Icons.style_rounded : Icons.hourglass_top_rounded,
            height: 46,
            color: v.drawStack > 0 && myTurn ? const Color(0xFFD9466F) : null,
            onPressed: myTurn ? c.draw : null,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
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
              const OneCardBack(width: 64),
              const SizedBox(height: 16),
              Text(
                '방장이 판을 준비하는 중…',
                textAlign: TextAlign.center,
                style: t.display(size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '판을 불러오지 못했어요. ${OneCardController.reasonMessages[c.syncStatus] ?? '연결 상태를 확인해 주세요.'}'
                    : '카드를 섞고 있어요. 잠시만 기다려 주세요.',
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
                    color: t.gold,
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
    final t = _theme;
    final me = c.me;
    final won = r.winner == me;
    final opp = r.winner == me ? r.loser : r.winner;
    final reason = r.forfeit
        ? (won
              ? '${c.displayName(opp)}의 시간 초과가 이어져 기권승이에요.'
              : '시간 초과가 이어져 기권패가 되었어요.')
        : (won
              ? '손패를 모두 비웠어요!'
              : '${c.displayName(r.winner)}이(가) 먼저 손패를 비웠어요.');
    final oppHand = r.hands[opp] ?? const <OneCard>[];
    final myHand = r.hands[me] ?? const <OneCard>[];
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
          if (r.stake > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GameChip(
                theme: t,
                leading: '🪙',
                label: won ? '판돈 ${r.stake}코인을 얻었어요' : '판돈 ${r.stake}코인을 잃었어요',
                emphasized: won,
              ),
            ),
          _RemainingHand(
            title: '${c.displayName(opp)} 남은 손패 ${oppHand.length}장',
            cards: oppHand,
          ),
          const SizedBox(height: 8),
          _RemainingHand(title: '내 남은 손패 ${myHand.length}장', cards: myHand),
        ],
      ),
      rematchWaiting: _socket.restartWaiting,
      onRematch: c.requestRematch,
    );
  }
}

class _RemainingHand extends StatelessWidget {
  final String title;
  final List<OneCard> cards;

  const _RemainingHand({required this.title, required this.cards});

  @override
  Widget build(BuildContext context) {
    final t = GameTheme.salon;
    final shown = cards.take(12).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.body(size: 12, color: t.subInk)),
        const SizedBox(height: 4),
        if (shown.isEmpty)
          Text('없음', style: t.body(size: 12.5, color: t.gold))
        else
          SizedBox(
            height: 26 * kOneCardAspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final step = shown.length <= 1
                    ? 0.0
                    : math.min(
                        20.0,
                        (constraints.maxWidth - 26) / (shown.length - 1),
                      );
                final total = 26 + step * (shown.length - 1);
                return Center(
                  child: SizedBox(
                    width: total,
                    child: Stack(
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          Positioned(
                            left: i * step,
                            child: OneCardFace(card: shown[i], width: 26),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final String label;
  final String semantics;
  final bool enabled;
  final bool gold;
  final VoidCallback onTap;

  const _CallButton({
    required this.label,
    required this.semantics,
    required this.enabled,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = GameTheme.salon;
    final base = gold ? t.gold : const Color(0xFFFF8FA8);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semantics,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: enabled ? 1.06 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.42,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: enabled
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(base, Colors.white, 0.35)!, base],
                      )
                    : null,
                color: enabled ? null : const Color(0xFF2A1640),
                border: Border.all(color: t.gold.withValues(alpha: 0.7)),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: base.withValues(alpha: 0.6),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: t.body(
                  size: 14,
                  weight: FontWeight.w900,
                  color: enabled ? const Color(0xFF2A1208) : t.subInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String color;
  final int count;
  final bool suggested;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.count,
    required this.suggested,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = GameTheme.salon;
    final c = OneCardColors.of(color);
    final name = OneCardColors.name(color);
    return Semantics(
      button: true,
      label: '$name으로 바꾸기, 손에 $count장',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                OneCardColors.light(color),
                c,
                OneCardColors.deep(color),
              ],
            ),
            border: Border.all(
              color: suggested ? Colors.white : t.gold.withValues(alpha: 0.7),
              width: suggested ? 2.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: t.body(
                  size: 15,
                  weight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count장',
                style: t.body(
                  size: 11.5,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              if (suggested)
                Text(
                  '추천',
                  style: t.body(
                    size: 10.5,
                    weight: FontWeight.w900,
                    color: Colors.white,
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
    final t = GameTheme.salon;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GameChip(theme: t, label: message(stat), emphasized: true),
    );
  }
}
