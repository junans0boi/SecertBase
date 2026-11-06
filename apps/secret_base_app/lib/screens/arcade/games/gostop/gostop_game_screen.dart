import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/gostop_coach.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'gostop_card.dart';
import 'gostop_controller.dart';
import 'gostop_effects.dart';
import 'gostop_field.dart';
import 'gostop_hand.dart';
import 'gostop_models.dart';
import 'gostop_panels.dart';
import 'gostop_score.dart';
import 'gostop_shelf.dart';

/// 고스톱 2.0 — 초록 펠트 판(GameTheme.felt).
/// 서버가 로비 시작과 함께 판을 만든다. 이 화면에는 시작 버튼이 없다.
class GostopGameScreen extends StatefulWidget {
  const GostopGameScreen({super.key});

  @override
  State<GostopGameScreen> createState() => _GostopGameScreenState();
}

/// 화면 위를 지나가는 연출 하나. [build]는 시작 시점부터 흐른 ms(시작 전에는 음수)를 받는다.
class _Fx {
  final int id;
  final AnimationController ctl;
  final int delayMs;
  final int totalMs;
  final Widget Function(double ms) build;

  bool _disposed = false;

  _Fx(this.id, this.ctl, this.delayMs, this.totalMs, this.build);

  /// 화면이 먼저 닫혀도, 연출이 먼저 끝나도 한 번만 정리한다.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ctl.dispose();
  }
}

class _GostopGameScreenState extends State<GostopGameScreen>
    with TickerProviderStateMixin {
  static const _theme = GameTheme.felt;
  static const _sounds = [
    GameSound.cardDeal,
    GameSound.cardShuffle,
    GameSound.hwatuSlap,
    GameSound.hwatuFlip,
    GameSound.hwatuCapture,
    GameSound.ppeok,
    GameSound.sseul,
    GameSound.goCall,
    GameSound.coins,
    GameSound.turnMine,
    GameSound.turnOpp,
    GameSound.tick,
    GameSound.select,
    GameSound.whoosh,
    GameSound.sparkle,
    GameSound.pirateBoom,
    GameSound.start,
    GameSound.warn,
    GameSound.win,
    GameSound.lose,
    GameSound.draw,
  ];

  final GostopController c = GostopController.instance;
  final SocketService _socket = SocketService();

  final _stackKey = GlobalKey();
  final _pileKey = GlobalKey();
  final _handKey = GlobalKey();
  final _oppKey = GlobalKey();
  final _myShelfKey = GlobalKey();
  final _oppShelfKey = GlobalKey();
  final _fieldKey = GlobalKey();
  final Map<int, GlobalKey> _slotKeys = {
    for (var m = 1; m <= 12; m++) m: GlobalKey(debugLabel: 'slot$m'),
  };

  final List<_Fx> _fx = [];
  final List<Timer> _timers = [];
  int _fxSeq = 0;
  late final AnimationController _quake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  Set<String> _hidden = {};
  // 진행 중인 연출 수(0이면 한가함). 타이머로 세어서 테스트의 가짜 시계에서도 같게 동작한다.
  int _holds = 0;
  bool _resultQueued = false;
  String? _selectedId;
  bool _shakeOn = false;

  String? _seenGame;
  int _seenSeq = -1;
  int _seenNotice = 0;
  String? _lastTurnPlayer;
  int _dealReveal = 1 << 20;
  int _syncRetries = 0;

  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  Color? _bannerColor;
  Object? _toastId;
  String? _toast;

  String? _resultFor;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(_sounds);
    _seenNotice = c.noticeSeq;
    c.addListener(_onController);
    _seenGame = c.view?.gameId;
    _seenSeq = c.view?.seq ?? -1;
    _lastTurnPlayer = c.view?.current;
    if (c.result != null) {
      _resultFor = c.result!.gameId;
      _showResult = true;
    }
    c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'gostop_howto_v2_seen',
        theme: _theme,
        title: '고스톱 (맞고)',
        emoji: '🎴',
        lines: gostopHowToLines,
      );
    });
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    for (final t in _timers) {
      t.cancel();
    }
    for (final f in _fx) {
      f.dispose();
    }
    _quake.dispose();
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

  bool get _busy => _holds > 0;

  void _busyFor(int ms) {
    _holds++;
    _after(ms + 30, () {
      _holds--;
      if (_holds == 0) _showResultWhenIdle();
      setState(() {});
    });
  }

  // 결과는 마지막 연출(먹은 패가 날아가는 것 등)이 끝난 뒤에 보여 준다.
  void _showResultWhenIdle() {
    final r = c.result;
    if (r == null || _showResult || _resultQueued || _resultFor != r.gameId) {
      return;
    }
    _resultQueued = true;
    _after(700, () {
      _resultQueued = false;
      setState(() => _showResult = true);
    });
  }

  // ── 위치 ──────────────────────────────────────────────────────────────────
  Size get _stackSize =>
      (_stackKey.currentContext?.findRenderObject() as RenderBox?)?.size ??
      const Size(390, 760);

  Offset _centerOf(GlobalKey key, {Offset? fallback}) {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null || !box.attached || !stack.attached) {
      return fallback ?? _stackSize.center(Offset.zero);
    }
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  Offset _seatOf(String? player) {
    final size = _stackSize;
    return player == c.me
        ? _centerOf(
            _handKey,
            fallback: Offset(size.width / 2, size.height - 150),
          )
        : _centerOf(_oppKey, fallback: Offset(size.width / 2, 100));
  }

  Offset _shelfOf(String? player) {
    final size = _stackSize;
    return player == c.me
        ? _centerOf(
            _myShelfKey,
            fallback: Offset(size.width / 2, size.height - 260),
          )
        : _centerOf(_oppShelfKey, fallback: Offset(size.width / 2, 150));
  }

  Offset _slotOf(int month) => _centerOf(_slotKeys[month]!);

  // ── 연출 도구 ─────────────────────────────────────────────────────────────
  void _addFx({
    required int delayMs,
    required int durationMs,
    required Widget Function(double ms) build,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    final total = delayMs + durationMs;
    final ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    final fx = _Fx(_fxSeq++, ctl, delayMs, total, build);
    setState(() => _fx.add(fx));
    if (onStart != null) _after(delayMs, onStart);
    ctl.forward().whenCompleteOrCancel(() {
      onEnd?.call();
      if (mounted) setState(() => _fx.remove(fx));
      fx.dispose();
    });
    _busyFor(total);
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

  void _sound(GameSound s, [int delayMs = 0]) {
    if (delayMs <= 0) {
      GameSfx.instance.play(s);
    } else {
      _after(delayMs, () => GameSfx.instance.play(s));
    }
  }

  // ── 상태 변화 → 연출·소리 ─────────────────────────────────────────────────
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
        _selectedId = null;
        _shakeOn = false;
        _hidden = {};
        _startDeal(v);
      } else if (v.seq > _seenSeq) {
        _seenSeq = v.seq;
        final turn = v.lastTurn;
        if (turn != null) _animateTurn(v, turn);
      }
      if (_selectedId != null &&
          (v.current != c.me || !v.hand.any((h) => h.id == _selectedId))) {
        _selectedId = null;
        _shakeOn = false;
      }
      final mine = v.current == c.me && !v.ended;
      if (mine && _lastTurnPlayer != c.me && c.result == null) {
        _after(_busy ? 1700 : 250, () {
          if (c.view?.current != c.me || c.result != null) return;
          GameSfx.instance.play(GameSound.turnMine);
          _banner('내 차례!', color: _theme.me);
        });
      }
      _lastTurnPlayer = v.current;
    }
    final r = c.result;
    if (r != null && r.gameId != _resultFor) {
      _resultFor = r.gameId;
      _showResult = false;
      _resultQueued = false;
      if (!_busy) _showResultWhenIdle();
    }
    setState(() {});
  }

  void _startDeal(GostopView v) {
    GameSfx.instance.play(GameSound.cardShuffle);
    setState(() => _dealReveal = 0);
    final n = v.hand.length;
    for (var i = 1; i <= n; i++) {
      _after(300 + i * 85, () {
        GameSfx.instance.play(GameSound.cardDeal);
        setState(() => _dealReveal = i);
      });
    }
    _after(300 + n * 85 + 100, () => setState(() => _dealReveal = 1 << 20));
    _busyFor(300 + n * 85 + 200);
    if (v.redeals.isNotEmpty) {
      _after(900, () => _showToast('바닥 패나 총통이 겹쳐서 다시 나눴어요.'));
    }
  }

  void _animateTurn(GostopView v, HTurn t) {
    switch (t.kind) {
      case 'play':
      case 'bomb':
      case 'dotan':
        _playTurn(v, t);
      case 'go':
        _sound(GameSound.goCall);
        _banner('고!', sub: '${v.goOf(t.by)}고째', color: const Color(0xFFFF8A5B));
        _busyFor(900);
      case 'stop':
      case 'auto_stop':
        _banner(
          '스톱!',
          sub: t.auto ? '시간이 지나 자동으로 스톱했어요' : null,
          color: _theme.gold,
        );
        _busyFor(900);
      case 'chongtong':
        _sound(GameSound.sparkle);
        _banner('총통!', sub: '10점 즉시 승리', color: _theme.gold);
        _busyFor(900);
    }
  }

  void _playTurn(GostopView v, HTurn t) {
    final byMe = t.by == c.me;
    final other = v.players.firstWhere((p) => p != t.by, orElse: () => '');
    final seat = _seatOf(t.by);
    final pile = _centerOf(_pileKey);
    final shelf = _shelfOf(t.by);
    final victimShelf = _shelfOf(other);
    final capIds = {for (final x in t.captured) x.id};
    final shownIds = {for (final x in t.shown) x.id};
    final playedId = t.played?.id;
    final flippedId = t.flipped?.id;

    final all = <HCard>[
      ...t.shown,
      ?t.played,
      ?t.flipped,
      ...t.captured,
      ...t.stolen,
    ];
    final ids = {for (final x in all) x.id};
    setState(() => _hidden = {..._hidden, ...ids});

    const legSeat = 380;
    const legPile = 520;
    final flipStart = (t.played != null || t.kind == 'bomb') ? 440 : 80;
    final capStart = flipStart + (t.flipped != null ? legPile + 160 : 0) + 120;
    const stagger = 55;
    const legShelf = 430;
    var fly = 0;
    var latest = 0;
    final widths = (
      hand: GostopCardSize.hand.width,
      field: GostopCardSize.field.width,
      cap: GostopCardSize.capture.width,
    );

    void flight(
      HCard card, {
      required Offset from,
      Offset? via,
      Offset? to,
      required int delay,
      required int leg1,
      bool flip = false,
      double startW = 40,
      double midW = 40,
      double endW = 28,
    }) {
      final hold = to == null
          ? 0
          : math.max(0, capStart + fly * stagger - (delay + leg1));
      final leg2 = to == null ? 0 : legShelf;
      final dur = leg1 + hold + leg2;
      latest = math.max(latest, delay + dur);
      if (to != null) fly++;
      _addFx(
        delayMs: delay,
        durationMs: dur,
        build: (ms) {
          if (ms < 0) return const SizedBox.shrink();
          Offset p;
          double w;
          double flipT = 1;
          if (via != null && ms < leg1) {
            final k = Curves.easeInOutCubic.transform(ms / leg1);
            p = Offset.lerp(from, via, k)!;
            w = startW + (midW - startW) * k;
            flipT = flip ? k : 1;
            p = p.translate(0, math.sin(k * math.pi) * -26);
          } else if (to != null && ms >= leg1 + hold) {
            final k = Curves.easeInOutCubic.transform(
              ((ms - leg1 - hold) / leg2).clamp(0, 1),
            );
            final a = via ?? from;
            p = Offset.lerp(a, to, k)!;
            w =
                (via != null ? midW : startW) +
                (endW - (via != null ? midW : startW)) * k;
          } else {
            p = via ?? from;
            w = midW;
          }
          final h = gostopCardHeight(w);
          return Positioned(
            left: p.dx - w / 2,
            top: p.dy - h / 2,
            child: flip
                ? GostopFlipCard(card: card, width: w, t: flipT)
                : GostopCard(card: card, width: w, badge: false),
          );
        },
        onEnd: () {
          if (mounted) setState(() => _hidden = {..._hidden}..remove(card.id));
        },
      );
    }

    // 1) 손패(또는 폭탄·흔들기로 보인 패)가 바닥으로
    var i = 0;
    for (final s in t.shown.where(
      (s) => t.kind == 'bomb' && capIds.contains(s.id),
    )) {
      flight(
        s,
        from: seat,
        via: _slotOf(s.month),
        to: shelf,
        delay: 20 + i * 70,
        leg1: legSeat,
        startW: widths.hand,
        midW: widths.field,
        endW: widths.cap,
      );
      i++;
    }
    final played = t.played;
    if (played != null) {
      final stays = !capIds.contains(played.id);
      flight(
        played,
        from: seat,
        via: _slotOf(played.month),
        to: stays ? null : shelf,
        delay: 20,
        leg1: legSeat,
        startW: widths.hand,
        midW: widths.field,
        endW: widths.cap,
      );
      _sound(GameSound.hwatuSlap, 20 + legSeat - 60);
    }
    // 2) 더미 패가 3D로 뒤집혀 바닥으로
    final flipped = t.flipped;
    if (flipped != null) {
      final stays = !capIds.contains(flipped.id);
      flight(
        flipped,
        from: pile,
        via: _slotOf(flipped.month),
        to: stays ? null : shelf,
        delay: flipStart,
        leg1: legPile,
        flip: true,
        startW: widths.field,
        midW: widths.field,
        endW: widths.cap,
      );
      _sound(GameSound.hwatuFlip, flipStart);
      _sound(GameSound.hwatuSlap, flipStart + legPile - 70);
    }
    // 3) 바닥에 있던 패 중 먹힌 것은 바로 딴 패 쪽으로
    for (final x in t.captured) {
      if (x.id == playedId || x.id == flippedId || shownIds.contains(x.id)) {
        continue;
      }
      flight(
        x,
        from: _slotOf(x.month),
        to: shelf,
        delay: capStart + fly * stagger,
        leg1: 0,
        startW: widths.field,
        midW: widths.field,
        endW: widths.cap,
      );
    }
    if (t.captured.isNotEmpty) _sound(GameSound.hwatuCapture, capStart);
    // 4) 뺏은 피: 상대 딴 패에서 내 딴 패로 + 화살표 + "+피"
    var stealDelay = capStart + math.max(fly, 1) * stagger + 80;
    for (final x in t.stolen) {
      flight(
        x,
        from: victimShelf,
        to: shelf,
        delay: stealDelay,
        leg1: 0,
        startW: widths.cap,
        midW: widths.cap,
        endW: widths.cap,
      );
      stealDelay += stagger;
    }
    latest = math.max(latest, stealDelay + legShelf);
    if (t.stolen.isNotEmpty) {
      final at = capStart + math.max(fly, 1) * stagger + 80;
      _addFx(
        delayMs: at,
        durationMs: 800,
        build: (ms) {
          if (ms < 0) return const SizedBox.shrink();
          final k = (ms / 800).clamp(0.0, 1.0);
          final p = Offset.lerp(
            victimShelf,
            shelf,
            Curves.easeInOut.transform(k),
          )!;
          final up = shelf.dy < victimShelf.dy;
          return Positioned(
            left: p.dx - 17,
            top: p.dy - 17,
            child: GostopStealArrow(color: _theme.gold, pointsUp: up, t: k),
          );
        },
      );
      _sound(GameSound.whoosh, at);
      _floatText('+피 ${t.stolen.length}', shelf, at + 250, _theme.gold);
      _floatText(
        '-피 ${t.stolen.length}',
        victimShelf,
        at + 250,
        _theme.opponent,
      );
    }
    final pi = t.captured
        .where((x) => x.isJunk)
        .fold<int>(0, (s, x) => s + (x.isDoubleJunk ? 2 : 1));
    if (pi > 0) {
      _floatText('+피 $pi', shelf, capStart + 300, const Color(0xFFDDDDDD));
    }

    // 5) 이벤트: 도장·고리·흔들림·배너
    var evAt = 0;
    void announce(String label, {Color? color, String? sub}) {
      _after(evAt, () => _banner(label, color: color ?? _theme.gold, sub: sub));
      evAt += 760;
    }

    if (t.has('shake')) {
      announce('흔들기!', sub: '이기면 ×2', color: const Color(0xFFB98BFF));
    }
    if (t.has('bomb')) {
      _sound(GameSound.pirateBoom, 60);
      _quake.forward(from: 0);
      announce('폭탄!', color: const Color(0xFFFF6A4D));
    }
    if (t.has('ppeok') && played != null) {
      final at = flipStart + legPile;
      _sound(GameSound.ppeok, at);
      _addFx(
        delayMs: at,
        durationMs: 1200,
        build: (ms) {
          if (ms < 0) return const SizedBox.shrink();
          final p = _slotOf(played.month);
          return Positioned(
            left: p.dx - 44,
            top: p.dy - 34,
            child: GostopStamp(
              text: '뻑',
              color: const Color(0xFFFF5A5F),
              t: (ms / 1200).clamp(0.0, 1.0),
            ),
          );
        },
      );
      _after(
        at,
        () => _banner(
          '뻑!',
          color: const Color(0xFFFF5A5F),
          sub: '같은 월 세 장이 바닥에 남았어요',
        ),
      );
    }
    if (t.has('jjok')) announce('쪽!');
    if (t.has('ttadak')) announce('따닥!');
    if (t.has('ppeok_take')) announce('뻑 가져오기!');
    if (t.has('sseul')) {
      final at = capStart + 200;
      _sound(GameSound.sseul, at);
      _addFx(
        delayMs: at,
        durationMs: 1000,
        build: (ms) {
          if (ms < 0) return const SizedBox.shrink();
          final p = _centerOf(_fieldKey);
          return Positioned(
            left: p.dx - 110,
            top: p.dy - 110,
            child: GostopGoldRing(
              theme: _theme,
              t: (ms / 1000).clamp(0.0, 1.0),
            ),
          );
        },
      );
      _after(at, () => _banner('쓸!', color: _theme.gold, sub: '바닥을 모두 쓸었어요'));
    }
    if (t.auto && byMe) {
      _after(120, () => _showToast('시간이 지나 자동으로 냈어요'));
    }
    _busyFor(math.max(latest, evAt) + 120);
  }

  void _floatText(String text, Offset at, int delayMs, Color color) {
    _addFx(
      delayMs: delayMs,
      durationMs: 900,
      build: (ms) {
        if (ms < 0) return const SizedBox.shrink();
        return Positioned(
          left: at.dx - 40,
          top: at.dy - 14,
          width: 80,
          child: Center(
            child: GostopFloatLabel(
              theme: _theme,
              text: text,
              color: color,
              t: (ms / 900).clamp(0.0, 1.0),
            ),
          ),
        );
      },
    );
  }

  // ── 손패 조작 ─────────────────────────────────────────────────────────────
  bool get _canPlay {
    final v = c.view;
    return v != null &&
        v.phase == 'playing' &&
        v.current == c.me &&
        c.result == null &&
        !_busy;
  }

  void _onHandTap(HCard card) {
    final v = c.view;
    if (v == null) return;
    if (!_canPlay) {
      _showToast(v.current == c.me ? '잠깐만요, 연출이 끝나면 낼 수 있어요.' : '지금은 상대 차례예요.');
      return;
    }
    if (_selectedId == card.id) {
      _confirmPlay(card);
      return;
    }
    GameSfx.instance.play(GameSound.select);
    setState(() {
      _selectedId = card.id;
      _shakeOn = false;
    });
  }

  void _confirmPlay(HCard card) {
    final v = c.view;
    if (v == null || !_canPlay) return;
    final shake = _shakeOn && v.shakeable.contains(card.month);
    setState(() {
      _selectedId = null;
      _shakeOn = false;
    });
    c.play(card, shake: shake);
  }

  void _showCardInfo(HCard card) {
    final info = describeGostopCard(card.toJson());
    final t = _theme;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GamePanel(
          theme: t,
          opaque: true,
          radius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GostopCard(card: card, width: 76),
              const SizedBox(height: 10),
              Text(info.title, style: t.display(size: 18)),
              const SizedBox(height: 6),
              Text(
                info.description,
                textAlign: TextAlign.center,
                style: t.body(size: 13, height: 1.45),
              ),
              const SizedBox(height: 10),
              GameSecondaryButton(
                theme: t,
                label: '닫기',
                height: 42,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 화면 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: GostopController.gameType,
        child: GameBackdrop(
          theme: t,
          frame: false,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([c, _socket]),
              builder: (context, _) => Stack(
                key: _stackKey,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _quake,
                      builder: (context, child) {
                        final k = _quake.value;
                        final dx = k == 0 || k == 1
                            ? 0.0
                            : math.sin(k * math.pi * 12) * 7 * (1 - k);
                        return Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        );
                      },
                      child: _body(),
                    ),
                  ),
                  Positioned.fill(child: IgnorePointer(child: _fxLayer())),
                  ..._overlays(),
                  Positioned(
                    top: 96,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: GameTurnBanner(
                        theme: t,
                        id: _bannerId,
                        text: _bannerText,
                        sub: _bannerSub,
                        color: _bannerColor,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: GameToast(theme: t, id: _toastId, message: _toast),
                    ),
                  ),
                  if (c.view != null && !_showResult)
                    Positioned(
                      right: 10,
                      top: 58,
                      child: ReactionButton(
                        theme: t,
                        gameType: GostopController.gameType,
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

  GameDeadline? _deadline(GostopView v) => GameDeadline.fromServer(
    deadlineMs: v.turnDeadline,
    serverNowMs: v.serverNow,
    total: Duration(milliseconds: v.turnMs),
    receivedAt: v.receivedAt,
  );

  List<Widget> _overlays() {
    final v = c.view;
    if (v == null || c.result != null || v.ended || _busy) return const [];
    final t = _theme;
    final mine = v.current == c.me;
    final oppName = c.displayName(c.opponent);
    if (v.phase == 'go_stop' && mine) {
      return [
        Positioned.fill(
          child: GostopDecisionPanel(
            theme: t,
            view: v,
            me: c.me,
            oppName: oppName,
            deadline: _deadline(v),
            onGo: () => c.decide(true),
            onStop: () => c.decide(false),
          ),
        ),
      ];
    }
    if (v.phase == 'chongtong' && mine) {
      return [
        Positioned.fill(
          child: GostopChongtongPanel(
            theme: t,
            cards: [
              for (final h in v.hand)
                if (h.month == v.chongtongMonth) h,
            ],
            perPointBet: v.perPointBet,
            deadline: _deadline(v),
            onDeclare: () => c.chongtong(true),
            onDecline: () => c.chongtong(false),
          ),
        ),
      ];
    }
    if (v.phase == 'choice' && mine && v.pending != null) {
      return [
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: GostopChoicePanel(
            theme: t,
            pending: v.pending!,
            deadline: _deadline(v),
            onChoose: c.choose,
          ),
        ),
      ];
    }
    return const [];
  }

  Widget _fxLayer() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final f in _fx)
          AnimatedBuilder(
            animation: f.ctl,
            builder: (context, _) =>
                f.build(f.ctl.value * f.totalMs - f.delayMs),
          ),
      ],
    );
  }

  Widget _body() {
    final t = _theme;
    final v = c.view;
    final topBar = GameTopBar(
      theme: t,
      title: '고스톱',
      gameType: GostopController.gameType,
      canRestart: v != null || c.result != null,
      restartWaiting: _socket.restartWaiting,
      onRequestRestart: c.requestRematch,
      onHelp: () => showGameHowTo(
        context,
        theme: t,
        title: '고스톱 (맞고)',
        emoji: '🎴',
        lines: gostopHowToLines,
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
    final myTurn = v.current == me && !v.ended && c.result == null;
    final oppTurn = v.current == opp && !v.ended && c.result == null;
    final deadline = _deadline(v);
    final hand = [...v.hand]..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final selected = hand.where((h) => h.id == _selectedId).firstOrNull;
    final choiceIds = (v.phase == 'choice' && myTurn && v.pending != null)
        ? {for (final o in v.pending!.options) o.id}
        : <String>{};
    final fieldMonths = {for (final f in v.field) f.month};
    final oppName = c.displayName(opp);
    return Column(
      children: [
        topBar,
        // 위: 상대 칩 + 딴 패
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    KeyedSubtree(
                      key: _oppKey,
                      child: PlayerBadge(
                        theme: t,
                        emoji: c.emojiOf(opp),
                        name: oppName,
                        subtitle:
                            '손패 ${v.handCount[opp] ?? 0}장'
                            '${(v.shakes[opp] ?? const []).isNotEmpty ? ' · 흔들기' : ''}'
                            '${(v.bombs[opp] ?? 0) > 0 ? ' · 폭탄' : ''}',
                        active: oppTurn,
                        compact: true,
                        align: CrossAxisAlignment.start,
                      ),
                    ),
                    Positioned(
                      left: 30,
                      top: -6,
                      child: ReactionBubble(
                        theme: t,
                        forPlayer: opp,
                        gameType: GostopController.gameType,
                      ),
                    ),
                  ],
                ),
              ),
              if (oppTurn)
                TurnTimerRing(theme: t, deadline: deadline, size: 38),
              const SizedBox(width: 52),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
          child: KeyedSubtree(
            key: _oppShelfKey,
            child: GostopShelf(
              theme: t,
              cards: v.capturesOf(opp),
              hiddenIds: _hidden,
              semanticsLabel: '$oppName의 딴 패',
            ),
          ),
        ),
        // 가운데 판
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: box.maxWidth - 16,
                  child: KeyedSubtree(
                    key: _fieldKey,
                    child: GostopField(
                      theme: t,
                      field: v.field,
                      ppeok: v.ppeok,
                      me: me,
                      highlightMonth: selected?.month,
                      hiddenIds: _hidden,
                      slotKeys: _slotKeys,
                      pileKey: _pileKey,
                      deckCount: v.deckCount,
                      choiceIds: choiceIds,
                      onTapCard: choiceIds.isEmpty ? null : c.choose,
                      pileActive:
                          myTurn &&
                          v.phase == 'playing' &&
                          (v.dotan[me] ?? 0) > 0 &&
                          hand.isEmpty,
                      onTapPile:
                          myTurn &&
                              v.phase == 'playing' &&
                              (v.dotan[me] ?? 0) > 0
                          ? c.dotan
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // 점수판
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GostopScoreBoard(
            theme: t,
            view: v,
            me: me,
            opp: opp,
            myName: c.displayName(me),
            oppName: oppName,
          ),
        ),
        // 내 딴 패 + 힌트
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          child: KeyedSubtree(
            key: _myShelfKey,
            child: GostopShelf(
              theme: t,
              cards: v.capturesOf(me),
              hiddenIds: _hidden,
              semanticsLabel: '내 딴 패',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
          child: GostopHintChips(theme: t, captures: v.capturesOf(me)),
        ),
        // 내 손패 부채
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: KeyedSubtree(
            key: _handKey,
            child: GostopHandFan(
              theme: t,
              cards: hand,
              selectedId: _selectedId,
              recommendedId: myTurn && v.phase == 'playing'
                  ? v.coachCardId
                  : null,
              capturableMonths: fieldMonths,
              active: myTurn && v.phase == 'playing',
              revealCount: _dealReveal,
              hiddenIds: _hidden,
              onTap: _onHandTap,
              onLongPress: _showCardInfo,
            ),
          ),
        ),
        _actionRow(v, myTurn, selected, deadline),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _actionRow(
    GostopView v,
    bool myTurn,
    HCard? selected,
    GameDeadline? deadline,
  ) {
    final t = _theme;
    final me = c.me;
    final extras = <Widget>[];
    final main = <Widget>[];
    if (myTurn) {
      main.add(
        TurnTimerRing(theme: t, deadline: deadline, size: 40, tickSound: true),
      );
      main.add(const SizedBox(width: 8));
    }
    if (myTurn && v.phase == 'playing') {
      final shakeable =
          selected != null && v.shakeable.contains(selected.month);
      if (shakeable) {
        extras.add(
          Expanded(
            child: _ToggleChip(
              theme: t,
              label: '${selected.month}월 흔들기 ×2',
              on: _shakeOn,
              onTap: () => setState(() => _shakeOn = !_shakeOn),
            ),
          ),
        );
      }
      for (final m in v.bombable) {
        extras.add(
          Expanded(
            child: GameSecondaryButton(
              theme: t,
              label: '$m월 폭탄',
              icon: Icons.bolt_rounded,
              height: 40,
              onPressed: _canPlay ? () => c.bomb(m) : null,
            ),
          ),
        );
      }
      if ((v.dotan[me] ?? 0) > 0) {
        extras.add(
          Expanded(
            child: GameSecondaryButton(
              theme: t,
              label: '더미 뒤집기 (${v.dotan[me]})',
              icon: Icons.flip_rounded,
              height: 40,
              onPressed: _canPlay ? c.dotan : null,
            ),
          ),
        );
      }
      main.add(
        Expanded(
          child: GamePrimaryButton(
            theme: t,
            label: selected == null
                ? '패를 눌러 들어 보세요'
                : '${selected.month}월 패 내기',
            icon: selected == null
                ? Icons.touch_app_rounded
                : Icons.south_rounded,
            height: 46,
            onPressed: selected == null || !_canPlay
                ? null
                : () => _confirmPlay(selected),
          ),
        ),
      );
    } else {
      final who = c.displayName(c.opponent);
      final text = switch (v.phase) {
        'chongtong' when !myTurn => '$who님이 총통을 고르는 중…',
        'go_stop' when !myTurn => '$who님이 고/스톱을 고르는 중…',
        'choice' when !myTurn => '$who님이 패를 고르는 중…',
        'choice' => '위 패널에서 가져올 패를 고르세요',
        'go_stop' => '고 or 스톱?',
        _ => myTurn ? '연출이 끝나면 낼 수 있어요' : '${c.displayName(v.current)}님의 차례',
      };
      main.add(
        Expanded(
          child: GamePrimaryButton(
            theme: t,
            label: text,
            icon: Icons.hourglass_top_rounded,
            height: 46,
            onPressed: null,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (extras.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var i = 0; i < extras.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    extras[i],
                  ],
                ],
              ),
            ),
          Row(children: main),
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
              const GostopCard(card: null, width: 56),
              const SizedBox(height: 16),
              Text(
                '판을 준비하는 중…',
                textAlign: TextAlign.center,
                style: t.display(size: 21),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? '판을 불러오지 못했어요. ${GostopController.reasonMessages[c.syncStatus] ?? '연결 상태를 확인해 주세요.'}'
                    : '화투를 섞고 있어요. 잠시만 기다려 주세요.',
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

  Widget _resultOverlay(HResult r) {
    final t = _theme;
    final me = c.me;
    final won = r.winner == me;
    final draw = r.winner == null;
    final winnerName = c.displayName(r.winner);
    final outcome = draw
        ? GameOutcome.draw
        : (won ? GameOutcome.win : GameOutcome.lose);
    final title = switch (r.reason) {
      'nagari' => '나가리',
      'chongtong' => won ? '총통 승리!' : '상대의 총통',
      'forfeit' => won ? '기권승!' : '기권패',
      _ => null,
    };
    final reason = switch (r.reason) {
      'nagari' => '마지막 패까지 승부가 나지 않았어요.',
      'chongtong' =>
        won ? '같은 월 네 장으로 10점을 받았어요.' : '$winnerName님이 총통 10점으로 이겼어요.',
      'forfeit' => won ? '상대가 시간 초과로 기권했어요.' : '시간 초과가 이어져 기권패가 되었어요.',
      _ =>
        r.receipt.auto
            ? (won ? '시간이 지나 자동으로 스톱해서 이겼어요.' : '$winnerName님이 스톱했어요.')
            : (won
                  ? '스톱! ${r.receipt.total}점으로 이겼어요.'
                  : '$winnerName님이 ${r.receipt.total}점으로 스톱했어요.'),
    };
    if (!draw && r.receipt.transferred > 0) {
      _after(500, () => GameSfx.instance.play(GameSound.coins));
    }
    return GameResultOverlay(
      theme: t,
      outcome: outcome,
      title: title,
      reason: reason,
      series: r.series,
      me: me,
      resultId: r.gameId,
      details: GostopReceipt(
        theme: t,
        receipt: r.receipt,
        me: me,
        winnerName: winnerName,
      ),
      rematchWaiting: _socket.restartWaiting,
      onRematch: c.requestRematch,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final GameTheme theme;
  final String label;
  final bool on;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.theme,
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? const Color(0xFFB98BFF)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB98BFF), width: 1.4),
          ),
          child: Text(
            label,
            style: t.body(
              size: 12,
              weight: FontWeight.w900,
              color: on ? const Color(0xFF2A1450) : const Color(0xFFD9C2FF),
            ),
          ),
        ),
      ),
    );
  }
}
