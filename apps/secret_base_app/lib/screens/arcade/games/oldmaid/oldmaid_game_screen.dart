import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'oldmaid_controller.dart';
import 'oldmaid_layout.dart';
import 'oldmaid_widgets.dart';

const _howToLines = [
  '조커 한 장이 섞인 카드를 나눠 갖고, 같은 숫자 두 장은 바로 버려요.',
  '내 차례에는 상대의 뒤집힌 카드 중 한 장을 골라요. 한 번 눌러 고르고, 한 번 더 누르면 뽑아요.',
  '뽑은 카드가 내 카드와 짝이 맞으면 둘 다 버림 더미로 가요.',
  '마지막까지 조커를 들고 있는 사람이 져요. 25초 안에 뽑지 않으면 무작위로 뽑혀요.',
  '😊 버튼으로 표정 연기를 해 보세요. 조커를 숨긴 채 능청 떨기!',
];

/// 도둑잡기 2.0 — 동화책 티파티. 한 화면(스크롤 없음)에 상대 부채꼴 → 가운데 → 내 부채꼴.
class OldMaidScreen extends StatefulWidget {
  const OldMaidScreen({super.key});

  @override
  State<OldMaidScreen> createState() => _OldMaidScreenState();
}

class _OldMaidScreenState extends State<OldMaidScreen>
    with TickerProviderStateMixin {
  static const _theme = GameTheme.storybook;
  static const _drawerFxTime = Duration(milliseconds: 1700);
  static const _victimFxTime = Duration(milliseconds: 1300);

  final _c = OldMaidController.instance;
  final _socket = SocketService();

  late final AnimationController _fx = AnimationController(vsync: this);
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  OldMaidDraw? _fxDraw;
  final Set<String> _cues = {};
  int _seenDrawSeq = 0;
  String? _seenGameId;
  int _seenNoticeSeq = 0;
  int? _selected;
  int? _hover;
  String? _caption;
  int _captionSeq = 0;
  Object? _bannerId;
  Object? _cuedBannerId;
  String? _toast;
  int _toastSeq = 0;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.tap,
      GameSound.select,
      GameSound.confirm,
      GameSound.turnMine,
      GameSound.tick,
      GameSound.win,
      GameSound.lose,
      GameSound.pop,
      GameSound.whoosh,
      GameSound.sparkle,
      GameSound.cardShuffle,
      GameSound.cardDeal,
      GameSound.cardFlip,
      GameSound.cardPlace,
      GameSound.cardPair,
      GameSound.joker,
    ]);
    _seenDrawSeq = _c.drawSeq;
    _seenNoticeSeq = _c.noticeSeq;
    _seenGameId = _c.gameId;
    // 이미 진행 중인 판에 다시 들어오면 나눠 주기 연출은 건너뛴다.
    if (_c.hasGame && !(_c.playing && _c.drawCount == 0)) {
      _deal.value = 1;
    } else if (_c.hasGame) {
      _startDeal();
    }
    _c.addListener(_onController);
    _fx.addListener(_onFxTick);
    _fx.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _fxDraw = null);
        _refreshBanner();
      }
    });
    _deal.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _refreshBanner();
    });
    _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'howto_oldmaid_v2',
        theme: _theme,
        title: '도둑잡기',
        emoji: '🃏',
        lines: _howToLines,
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _fx.dispose();
    _deal.dispose();
    super.dispose();
  }

  bool get _fxRunning => _fxDraw != null;

  void _startDeal() {
    GameSfx.instance.play(GameSound.cardShuffle);
    _deal.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) GameSfx.instance.play(GameSound.cardDeal);
    });
  }

  void _onController() {
    if (!mounted) return;
    if (_c.gameId != _seenGameId) {
      _seenGameId = _c.gameId;
      _fx.stop();
      _fxDraw = null;
      _selected = null;
      _hover = null;
      _caption = null;
      _seenDrawSeq = _c.drawSeq;
      if (_c.hasGame) _startDeal();
    }
    if (_c.drawSeq != _seenDrawSeq) {
      _seenDrawSeq = _c.drawSeq;
      final d = _c.lastDraw;
      if (d != null && !(d.role == 'spectator')) _startFx(d);
    }
    if (_c.noticeSeq != _seenNoticeSeq) {
      _seenNoticeSeq = _c.noticeSeq;
      _toast = _c.notice;
      _toastSeq++;
    }
    if (!_c.myTurn || (_selected != null && _selected! >= _c.oppCount)) {
      _selected = null;
      _hover = null;
    }
    setState(() {});
    _refreshBanner();
  }

  void _startFx(OldMaidDraw d) {
    _fxDraw = d;
    _cues.clear();
    _selected = null;
    _hover = null;
    _caption = _c.drawMessage(d);
    _captionSeq++;
    _fx.duration = d.isDrawer ? _drawerFxTime : _victimFxTime;
    _fx.forward(from: 0);
  }

  void _cue(String id, double at, GameSound sound) {
    if (_fx.value >= at && _cues.add(id)) GameSfx.instance.play(sound);
  }

  void _onFxTick() {
    final d = _fxDraw;
    if (d == null) return;
    if (d.isDrawer) {
      _cue('lift', 0, GameSound.whoosh);
      _cue('flip', 0.22, GameSound.cardFlip);
      if (d.jokerMoved) _cue('joker', 0.32, GameSound.joker);
      if (d.paired) {
        _cue('pair', 0.54, GameSound.cardPair);
        _cue('sparkle', 0.58, GameSound.sparkle);
      } else {
        _cue('land', 0.9, GameSound.cardPlace);
      }
    } else {
      _cue('lift', 0, GameSound.whoosh);
      if (d.jokerMoved) _cue('joker-gone', 0.4, GameSound.sparkle);
      if (d.paired) {
        _cue('pair', 0.7, GameSound.cardPair);
      } else {
        _cue('flip', 0.56, GameSound.cardFlip);
      }
    }
  }

  void _refreshBanner() {
    if (!mounted) return;
    final ready = !_fxRunning && !_deal.isAnimating;
    final id = (_c.myTurn && ready) ? '${_c.gameId}-${_c.drawCount}' : null;
    if (id != _bannerId) {
      setState(() => _bannerId = id);
      if (id != null && id != _cuedBannerId) {
        _cuedBannerId = id;
        GameSfx.instance.play(GameSound.turnMine);
      }
    }
  }

  bool get _canPick => _c.myTurn && !_fxRunning && !_c.sending;

  void _pick(int? index, {bool fromTap = true}) {
    if (!_canPick || index == null) return;
    if (fromTap && _selected == index) {
      _confirm();
      return;
    }
    if (_selected != index) GameSfx.instance.play(GameSound.select);
    setState(() => _selected = index);
  }

  void _confirm() {
    final slot = _selected;
    if (!_canPick || slot == null) return;
    GameSfx.instance.play(GameSound.confirm);
    _c.draw(slot);
  }

  void _showHelp() => showGameHowTo(
    context,
    theme: _theme,
    title: '도둑잡기',
    emoji: '🃏',
    lines: _howToLines,
  );

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: OldMaidController.gameType,
        child: GameBackdrop(
          theme: t,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([_socket, _fx, _deal]),
              builder: (context, _) => Stack(
                children: [
                  Column(
                    children: [
                      GameTopBar(
                        theme: t,
                        title: '도둑잡기',
                        gameType: OldMaidController.gameType,
                        canRestart: _c.hasGame,
                        restartWaiting: _socket.restartWaiting,
                        onRequestRestart: () =>
                            _socket.requestRestart(OldMaidController.gameType),
                        onHelp: _showHelp,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) =>
                              _table(OldMaidTableLayout.of(box.biggest)),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 58,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GameToast(
                        theme: t,
                        id: _toastSeq,
                        message: _toast,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GameTurnBanner(
                      theme: t,
                      id: _bannerId,
                      text: '내 차례!',
                      sub: '상대 카드를 한 장 뽑아요',
                    ),
                  ),
                  if (_c.finished && _c.result != null && !_fxRunning)
                    Positioned.fill(child: _resultOverlay()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 표 전체 ──────────────────────────────────────────────────────────────

  Widget _table(OldMaidTableLayout l) {
    if (!_c.hasGame) return _waiting();
    final d = _fxDraw;
    final p = _fx.value;
    final opp = _c.opponent;

    // 연출 중에는 상태보다 한 박자 늦게 보여 준다(카드가 날아가 도착한 뒤 손패가 바뀐다).
    var oppShown = _c.oppCount;
    var discardsShown = _c.discards;
    String? hiddenMine;
    if (d != null) {
      if (d.isVictim && p < 0.97) {
        oppShown = d.paired
            ? (p < 0.7 ? d.oppCountBefore : _c.oppCount)
            : d.oppCountBefore;
      }
      if (d.isDrawer && !d.paired && p < 0.96) hiddenMine = d.card?.id;
      if (d.paired && p < 0.96 && discardsShown.isNotEmpty) {
        discardsShown = discardsShown.sublist(0, discardsShown.length - 1);
      }
    }
    final hand = _c.sortedHand.where((c) => c.id != hiddenMine).toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._oppBar(l, opp),
        ..._oppFan(l, oppShown),
        _oppPicker(l, oppShown),
        ..._center(l, discardsShown, opp),
        ..._myFan(l, hand),
        ..._myBar(l, opp),
        if (d != null) ..._fxLayer(l, d, p),
      ],
    );
  }

  Widget _waiting() {
    final t = _theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: t.accent),
          ),
          const SizedBox(height: 14),
          Text('판을 준비하는 중…', style: t.body(size: 15, color: t.subInk)),
        ],
      ),
    );
  }

  // ── 상대 줄 ──────────────────────────────────────────────────────────────

  List<Widget> _oppBar(OldMaidTableLayout l, String? opp) {
    final t = _theme;
    final oppTurn = _c.playing && _c.turn != null && _c.turn == opp;
    return [
      Positioned.fromRect(
        rect: l.oppBar,
        child: Row(
          children: [
            Flexible(
              child: PlayerBadge(
                theme: t,
                emoji: _c.emojiOf(opp),
                name: _c.displayName(opp),
                subtitle: '카드 ${_c.oppCount}장',
                active: oppTurn,
                compact: true,
                align: CrossAxisAlignment.start,
              ),
            ),
            if (oppTurn) ...[
              const SizedBox(width: 8),
              TurnTimerRing(theme: t, deadline: _c.deadline, size: 36),
            ],
            const SizedBox(width: 8),
            if (_c.series != null) SeriesScore.fromMap(t, _c.series, _c.me),
          ],
        ),
      ),
      Positioned(
        left: l.oppBar.left + 30,
        top: l.oppBar.bottom - 10,
        child: ReactionBubble(
          theme: t,
          forPlayer: opp,
          gameType: OldMaidController.gameType,
        ),
      ),
    ];
  }

  // ── 상대 부채꼴(뒷면) ─────────────────────────────────────────────────────

  Rect _dealt(Rect target, int i, int n, Rect origin) {
    if (!_deal.isAnimating) return target;
    final delay = n <= 1 ? 0.0 : i / n * 0.55;
    final k = ((_deal.value - delay) / 0.45).clamp(0.0, 1.0);
    return Rect.lerp(origin, target, Curves.easeOutCubic.transform(k))!;
  }

  List<Widget> _oppFan(OldMaidTableLayout l, int count) {
    final geo = l.oppFanOf(count);
    final revealed = _c.finished ? _c.oppRevealed : const <OldMaidCard>[];
    return [
      for (var i = 0; i < count; i++)
        _placed(
          key: ValueKey('om-opp-$i'),
          rect: _dealt(
            geo.rectOf(
              i,
              lift: i == _selected
                  ? 18
                  : i == _hover
                  ? 7
                  : 0,
            ),
            i,
            count,
            l.stage,
          ),
          angle: geo.angleOf(i),
          child: i < revealed.length
              ? PlayingCard(
                  suit: revealed[i].suit,
                  rank: revealed[i].rank,
                  width: geo.cardW,
                  highlight: revealed[i].isJoker,
                  highlightColor: kJokerRed,
                )
              : PlayingCard(
                  faceUp: false,
                  width: geo.cardW,
                  back: kOldMaidBack,
                  highlight: i == _selected,
                ),
        ),
    ];
  }

  Widget _placed({
    Key? key,
    required Rect rect,
    double angle = 0,
    double opacity = 1,
    required Widget child,
  }) {
    return Positioned.fromRect(
      key: key,
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(angle: angle, child: child),
        ),
      ),
    );
  }

  /// 상대 부채꼴 위의 투명한 조작면: 탭(고르기·한 번 더 탭하면 뽑기), 손가락으로 훑기, 마우스 올리기.
  Widget _oppPicker(OldMaidTableLayout l, int count) {
    final geo = l.oppFanOf(count);
    int? at(Offset local) => geo.indexAt(local.dx + l.oppFan.left);
    final enabled = _canPick;
    return Positioned.fromRect(
      rect: l.oppFan,
      child: Semantics(
        button: enabled,
        label: enabled ? '상대 카드 $count장. 한 장을 골라 뽑으세요' : '상대 카드 $count장',
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onHover: enabled
              ? (e) {
                  final i = at(e.localPosition);
                  if (i != _hover) setState(() => _hover = i);
                }
              : null,
          onExit: (_) {
            if (_hover != null) setState(() => _hover = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled ? (e) => _pick(at(e.localPosition)) : null,
            onHorizontalDragUpdate: enabled
                ? (e) => _pick(at(e.localPosition), fromTap: false)
                : null,
          ),
        ),
      ),
    );
  }

  // ── 가운데: 안내 · 버린 짝 더미 · 공개 자리 · 문구 · 기록 ──────────────────

  List<Widget> _center(
    OldMaidTableLayout l,
    List<String> discards,
    String? opp,
  ) {
    final t = _theme;
    final oppName = _c.displayName(opp);
    final prompt = !_c.playing
        ? '판이 끝났어요'
        : _c.myTurn
        ? (_selected == null ? '상대 카드 한 장을 골라요' : '한 번 더 누르거나 아래 버튼으로 뽑아요')
        : '$oppName${subjectParticle(oppName)} 내 카드를 고르는 중…';
    final caption = l.caption;
    final showConfirm = _canPick && _selected != null;
    final logs = _c.log.reversed.take(3).toList();
    final pairGlow = _fxDraw != null && _fxDraw!.paired && _fx.value >= 0.96;
    return [
      Positioned(
        left: l.center.left,
        right: l.size.width - l.center.right,
        top: l.center.top + 2,
        height: 22,
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body(size: 13, color: t.subInk, weight: FontWeight.w700),
        ),
      ),
      // 공개 자리: 레이스 받침.
      Positioned.fromRect(
        rect: l.stage.inflate(6),
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(l.stageCardW * 0.16),
              border: Border.all(color: t.gold.withValues(alpha: 0.45)),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF9D83FF).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: l.discardPile.left,
        top: l.discardPile.top,
        child: OldMaidDiscardPile(
          theme: t,
          discards: discards,
          cardW: l.discardPile.width,
          glow: pairGlow,
        ),
      ),
      Positioned(
        right: l.size.width - l.center.right + 2,
        top: l.stage.center.dy - 34,
        child: OldMaidTeacup(theme: t, size: math.min(68, l.stageCardW * 0.8)),
      ),
      // 뽑기 결과 문구(뽑은 쪽/뺏긴 쪽이 서로 다르게 읽는다).
      Positioned(
        left: caption.left,
        width: caption.width,
        top: caption.top,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _caption == null
                ? const SizedBox(height: 32, key: ValueKey('no-caption'))
                : Container(
                    key: ValueKey(_captionSeq),
                    constraints: BoxConstraints(maxWidth: caption.width),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (_fxDraw?.jokerMoved ?? false)
                            ? kJokerRed
                            : t.gold.withValues(alpha: 0.7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _caption!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(size: 13.5, weight: FontWeight.w800),
                    ),
                  ),
          ),
        ),
      ),
      if (showConfirm)
        Positioned(
          left: caption.left,
          width: caption.width,
          top: caption.top + 40,
          child: Center(
            child: SizedBox(
              width: 190,
              child: GamePrimaryButton(
                theme: t,
                label: '이 카드 뽑기',
                icon: Icons.back_hand_rounded,
                height: 46,
                onPressed: _confirm,
              ),
            ),
          ),
        ),
      // 최근 기록(공개 정보만): 위가 최신.
      Positioned(
        left: l.center.left,
        right: l.size.width - l.center.right,
        bottom: l.size.height - l.center.bottom + 2,
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < logs.length; i++)
                Text(
                  _c.logLine(logs[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(
                    size: 11.5,
                    color: t.subInk.withValues(alpha: 1 - i * 0.28),
                    weight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  // ── 내 부채꼴(정렬, NEW, 조커 붉은 테두리) ───────────────────────────────

  List<Widget> _myFan(OldMaidTableLayout l, List<OldMaidCard> hand) {
    final geo = l.myFanOf(hand.length);
    final picking = _c.playing && !_c.myTurn;
    return [
      for (var i = 0; i < hand.length; i++)
        _placed(
          key: ValueKey('om-my-${hand[i].id}'),
          rect: _dealt(geo.rectOf(i), i, hand.length, l.stage),
          angle: geo.angleOf(i),
          child: PlayingCard(
            suit: hand[i].suit,
            rank: hand[i].rank,
            width: geo.cardW,
            highlight: hand[i].isJoker || hand[i].id == _c.newCardId,
            highlightColor: hand[i].isJoker
                ? kJokerRed
                : const Color(0xFFFFD36E),
            badge: hand[i].id == _c.newCardId ? 'NEW' : null,
          ),
        ),
      if (picking && hand.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          top: l.myFan.top - 6,
          child: Center(
            child: GameChip(
              theme: _theme,
              leading: '👀',
              label: '${_c.displayName(_c.opponent)} 고르는 중…',
              color: _theme.opponent,
              emphasized: true,
            ),
          ),
        ),
    ];
  }

  // ── 내 줄 ────────────────────────────────────────────────────────────────

  List<Widget> _myBar(OldMaidTableLayout l, String? opp) {
    final t = _theme;
    final me = _c.me;
    return [
      Positioned(
        left: l.myBar.left,
        top: l.myBar.top,
        height: l.myBar.height,
        width: math.max(0, l.myBar.width - 56),
        child: Row(
          children: [
            Flexible(
              child: PlayerBadge(
                theme: t,
                emoji: _c.emojiOf(me),
                name: _c.displayName(me),
                subtitle: '카드 ${_c.myHand.length}장',
                active: _c.myTurn,
                isMe: true,
                compact: true,
                align: CrossAxisAlignment.start,
              ),
            ),
            if (_c.myTurn) ...[
              const SizedBox(width: 8),
              TurnTimerRing(
                theme: t,
                deadline: _c.deadline,
                size: 38,
                tickSound: true,
              ),
            ],
          ],
        ),
      ),
      Positioned(
        left: l.myBar.left + 30,
        top: l.myBar.top - 34,
        child: ReactionBubble(
          theme: t,
          forPlayer: me,
          gameType: OldMaidController.gameType,
        ),
      ),
      Positioned(
        right: l.size.width - l.myBar.right,
        top: l.myBar.top + 3,
        child: ReactionButton(theme: t, gameType: OldMaidController.gameType),
      ),
    ];
  }

  // ── 뽑기 연출 ────────────────────────────────────────────────────────────

  static double _seg(double p, double a, double b) =>
      ((p - a) / (b - a)).clamp(0.0, 1.0);

  int _sortedIndex(List<OldMaidCard> hand, String? id) {
    final sorted = OldMaidController.sortHand(hand);
    final i = sorted.indexWhere((c) => c.id == id);
    return i < 0 ? sorted.length ~/ 2 : i;
  }

  List<Widget> _fxLayer(OldMaidTableLayout l, OldMaidDraw d, double p) {
    return d.isDrawer ? _drawerFx(l, d, p) : _victimFx(l, d, p);
  }

  List<Widget> _drawerFx(OldMaidTableLayout l, OldMaidDraw d, double p) {
    final t = _theme;
    final card = d.card;
    final stage = l.stage;
    final before = math.max(1, d.oppCountBefore);
    final oppGeo = l.oppFanOf(before);
    final slot = d.slot.clamp(0, before - 1);
    final from = oppGeo.rectOf(slot);
    final out = <Widget>[];

    // 짝이면 뽑은 카드는 왼쪽, 내 짝 카드는 오른쪽으로 나란히 선다.
    final side = stage.width * 0.32;
    final pairShift = d.paired
        ? Curves.easeOut.transform(_seg(p, 0.4, 0.56))
        : 0.0;
    final dest = d.paired
        ? l.discardPile
        : l.myFanOf(_c.myHand.length).rectOf(_sortedIndex(_c.myHand, card?.id));

    Rect rect;
    double angle = 0;
    double opacity = 1;
    if (p < 0.18) {
      final k = Curves.easeOutCubic.transform(_seg(p, 0, 0.18));
      rect = Rect.lerp(from, stage, k)!;
      angle = oppGeo.angleOf(slot) * (1 - k);
    } else if (p < 0.62) {
      rect = stage.shift(Offset(-side * pairShift, 0));
      if (d.jokerMoved && p > 0.32) {
        final decay = 1 - _seg(p, 0.32, 0.62);
        rect = rect.shift(Offset(math.sin(p * 140) * 6 * decay, 0));
        angle = math.sin(p * 90) * 0.05 * decay;
      }
    } else {
      final k = Curves.easeInOutCubic.transform(_seg(p, 0.62, 1));
      rect = Rect.lerp(stage.shift(Offset(-side * pairShift, 0)), dest, k)!;
      if (d.paired) opacity = 1 - _seg(p, 0.9, 1);
    }
    final flip = _seg(p, 0.18, 0.34);

    if (d.jokerMoved) {
      final ink = _seg(p, 0.3, 0.95);
      out.add(
        Positioned.fromRect(
          rect: stage.inflate(stage.width * 0.7),
          child: IgnorePointer(
            child: CustomPaint(painter: InkBleedPainter(progress: ink)),
          ),
        ),
      );
    }

    out.add(
      _placed(
        key: const ValueKey('om-fx-drawn'),
        rect: rect,
        angle: angle,
        opacity: opacity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            OldMaidFlipCard(
              card: card,
              width: rect.width,
              flip: flip,
              highlight: p > 0.3,
              highlightColor: d.jokerMoved ? kJokerRed : t.gold,
            ),
            if (d.jokerMoved && flip >= 1)
              Positioned.fill(
                child: CustomPaint(
                  painter: JokerGrinPainter(_seg(p, 0.36, 0.56)),
                ),
              ),
          ],
        ),
      ),
    );

    if (d.paired && d.matched != null) {
      final before = d.handBefore;
      final myGeo = l.myFanOf(before.length);
      final mi = _sortedIndex(before, d.matched!.id);
      final mFrom = myGeo.rectOf(mi);
      final beside = stage.shift(Offset(side, 0));
      Rect mRect;
      double mAngle = 0;
      if (p < 0.4) {
        mRect = mFrom;
        mAngle = myGeo.angleOf(mi);
      } else if (p < 0.62) {
        final k = Curves.easeOutCubic.transform(_seg(p, 0.4, 0.56));
        mRect = Rect.lerp(mFrom, beside, k)!;
        mAngle = myGeo.angleOf(mi) * (1 - k);
      } else {
        final k = Curves.easeInOutCubic.transform(_seg(p, 0.62, 1));
        mRect = Rect.lerp(beside, l.discardPile, k)!;
      }
      out.add(
        _placed(
          key: const ValueKey('om-fx-matched'),
          rect: mRect,
          angle: mAngle,
          opacity: p < 0.62 ? 1 : 1 - _seg(p, 0.9, 1),
          child: OldMaidFlipCard(
            card: d.matched,
            width: mRect.width,
            flip: 1,
            highlight: p > 0.5,
            highlightColor: t.gold,
          ),
        ),
      );
      out.add(
        Positioned.fromRect(
          rect: stage.inflate(stage.width * 0.8),
          child: IgnorePointer(
            child: CustomPaint(
              painter: SparklePainter(
                progress: _seg(p, 0.54, 0.92),
                color: t.gold,
              ),
            ),
          ),
        ),
      );
    }

    final word = d.jokerMoved ? '조커!' : (d.paired ? '짝!' : null);
    final wordIn = d.jokerMoved ? _seg(p, 0.32, 0.42) : _seg(p, 0.5, 0.6);
    final wordOut = _seg(p, 0.8, 0.9);
    if (word != null && wordIn > 0 && wordOut < 1) {
      out.add(
        Positioned(
          left: 0,
          right: 0,
          top: stage.top - 30,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 1 - wordOut,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(wordIn) * 0.9 + 0.1,
                  child: Text(
                    word,
                    style: t
                        .display(
                          size: 28,
                          color: d.jokerMoved ? kJokerRed : t.accent,
                        )
                        .copyWith(
                          shadows: [
                            const Shadow(color: Colors.white, blurRadius: 6),
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
    return out;
  }

  List<Widget> _victimFx(OldMaidTableLayout l, OldMaidDraw d, double p) {
    final t = _theme;
    final card = d.card;
    final before = d.handBefore;
    final myGeo = l.myFanOf(math.max(1, before.length));
    final i = _sortedIndex(before, card?.id);
    final from = myGeo.rectOf(i);
    final lifted = from.shift(const Offset(0, -26));
    final stage = Rect.fromCenter(
      center: l.stage.center,
      width: l.stageCardW * 0.86,
      height: l.stageCardH * 0.86,
    );
    final oppGeo = l.oppFanOf(math.max(1, d.oppCountBefore + 1));
    final dest = d.paired ? l.discardPile : oppGeo.rectOf(oppGeo.count ~/ 2);

    Rect rect;
    double angle = 0;
    if (p < 0.25) {
      final k = Curves.easeOutCubic.transform(_seg(p, 0, 0.25));
      rect = Rect.lerp(from, lifted, k)!;
      angle = myGeo.angleOf(i) * (1 - k);
    } else if (p < 0.55) {
      rect = Rect.lerp(
        lifted,
        stage,
        Curves.easeInOutCubic.transform(_seg(p, 0.25, 0.55)),
      )!;
    } else if (p < 0.7) {
      rect = stage;
    } else {
      final k = Curves.easeInCubic.transform(_seg(p, 0.7, 1));
      rect = Rect.lerp(stage, dest, k)!;
    }
    // 뺏긴 카드는 내 카드라 앞면으로 보여 주고, 상대 손으로 들어갈 때 뒷면으로 뒤집는다.
    final flip = d.paired ? 1.0 : 1 - _seg(p, 0.55, 0.7);
    final opacity = 1 - _seg(p, 0.88, 1);
    return [
      if (d.jokerMoved)
        Positioned.fromRect(
          rect: l.stage.inflate(l.stageCardW * 0.8),
          child: IgnorePointer(
            child: CustomPaint(
              painter: SparklePainter(
                progress: _seg(p, 0.4, 0.8),
                color: const Color(0xFF9D83FF),
              ),
            ),
          ),
        ),
      _placed(
        key: const ValueKey('om-fx-taken'),
        rect: rect,
        angle: angle,
        opacity: opacity,
        child: OldMaidFlipCard(
          card: card,
          width: rect.width,
          flip: flip,
          highlight: true,
          highlightColor: d.jokerMoved ? const Color(0xFF9D83FF) : t.opponent,
        ),
      ),
    ];
  }

  // ── 결과 ─────────────────────────────────────────────────────────────────

  Widget _resultOverlay() {
    final t = _theme;
    final won = _c.winner != null && _c.winner == _c.me;
    final oppName = _c.displayName(_c.opponent);
    final reason = switch ((_c.resultReason, won)) {
      ('timeout', true) =>
        '$oppName${subjectParticle(oppName)} 시간을 세 번 넘겨 이겼어요',
      ('timeout', false) => '시간을 세 번 넘겨 기권 처리됐어요',
      ('afk', true) => '$oppName${subjectParticle(oppName)} 자리를 비워 이겼어요',
      ('afk', false) => '오래 자리를 비워 기권 처리됐어요',
      (_, true) => '마지막 조커는 $oppName에게 남았어요',
      (_, false) => '마지막까지 조커를 들고 있었어요',
    };
    return GameResultOverlay(
      theme: t,
      outcome: won ? GameOutcome.win : GameOutcome.lose,
      title: won ? '조커를 피했어요!' : '조커가 내 손에…',
      reason: reason,
      series: _c.series,
      me: _c.me,
      resultId: _c.gameId,
      details: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayingCard(
            rank: 'JOKER',
            suit: '🃏',
            width: 40,
            highlight: true,
            highlightColor: kJokerRed,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '조커: ${_c.displayName(_c.loser)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body(size: 14, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
      onRematch: () => _socket.requestRestart(OldMaidController.gameType),
      rematchWaiting: _socket.restartWaiting,
    );
  }
}
