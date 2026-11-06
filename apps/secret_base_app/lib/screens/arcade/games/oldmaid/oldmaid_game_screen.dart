import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/modern_kit.dart';
import '../../../../widgets/play_kit/modern_result.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import '../../game_lobby_themed.dart' show ThiefHero;
import 'oldmaid_controller.dart';
import 'oldmaid_layout.dart';
import 'oldmaid_widgets.dart';

const oldMaidHowTo = [
  '조커 한 장이 섞인 카드를 나눠 갖고, 같은 숫자 두 장은 바로 버려요.',
  '내 차례에는 상대의 뒤집힌 카드 중 한 장을 골라요. 한 번 눌러 고르고, 한 번 더 누르면 뽑아요.',
  '뽑은 카드가 내 카드와 짝이 맞으면 둘 다 버림 더미로 가요.',
  '마지막까지 조커를 들고 있는 사람이 져요. 25초 안에 뽑지 않으면 무작위로 뽑혀요.',
  '😊 버튼으로 표정 연기를 해 보세요. 조커를 숨긴 채 능청 떨기!',
];

/// 도둑잡기 2.0 — 동화책 크림 종이. 한 화면(스크롤 없음)에 상대 부채꼴 → 가운데 무대 → 내 부채꼴 → 주 버튼.
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
      showModHowToOnce(
        context,
        prefKey: 'howto_oldmaid_v2',
        theme: _theme,
        title: '도둑잡기',
        lines: oldMaidHowTo,
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

  void _showHelp() =>
      showModHowTo(context, theme: _theme, title: '도둑잡기', lines: oldMaidHowTo);

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: OldMaidController.gameType,
        child: ListenableBuilder(
          listenable: Listenable.merge([_socket, _fx, _deal]),
          builder: (context, _) {
            final overlay = _c.finished && _c.result != null && !_fxRunning;
            return Stack(
              children: [
                ModBackdrop(
                  theme: t,
                  kind: ModBackdropKind.paper,
                  child: SafeArea(child: _content()),
                ),
                // 결과 화면은 안전 영역까지 덮는다(자체 SafeArea를 가진다).
                if (overlay) Positioned.fill(child: _resultOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content() {
    final t = _theme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stack(
          children: [
            Column(
              children: [
                ModTopBar(
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
            Align(
              alignment: const Alignment(0, -0.5),
              child: ModToast(theme: t, id: _toastSeq, message: _toast),
            ),
            ModTurnFlash(
              theme: t,
              id: _bannerId,
              text: '내 차례',
              sub: '상대 카드를 한 장 뽑아요',
              alignment: const Alignment(0, -0.1),
            ),
          ],
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
        ..._oppBar(l, opp, oppShown),
        ..._oppFan(l, oppShown),
        _oppPicker(l, oppShown),
        ..._center(l, discardsShown, opp),
        ..._myFan(l, hand),
        ..._myBar(l, opp),
        _dock(l, opp),
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
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: t.accent),
          ),
          const SizedBox(height: 14),
          Text(
            '판을 준비하는 중…',
            style: t.body(size: 15, color: t.subInk, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── 상대 줄 ──────────────────────────────────────────────────────────────

  List<Widget> _oppBar(OldMaidTableLayout l, String? opp, int shown) {
    final t = _theme;
    final oppTurn = _c.playing && _c.turn != null && _c.turn == opp;
    return [
      Positioned.fromRect(
        rect: l.oppBar,
        child: Center(
          child: ModCapsule(
            theme: t,
            name: _c.displayName(opp),
            sub: '카드 $shown장',
            mine: false,
            active: oppTurn,
            height: 48,
            minWidth: 186,
          ),
        ),
      ),
      Positioned(
        left: l.oppBar.center.dx + 70,
        top: l.oppBar.bottom - 6,
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
                  ? 16
                  : i == _hover
                  ? 7
                  : 0,
            ),
            i,
            count,
            l.stage,
          ),
          angle: geo.angleOf(i),
          pivot: geo.pivot,
          child: i < revealed.length
              ? PlayingCard(
                  suit: revealed[i].suit,
                  rank: revealed[i].rank,
                  width: geo.cardW,
                  style: kOldMaidStyle,
                  highlight: revealed[i].isJoker,
                  highlightColor: kJokerRed.withValues(alpha: 0.25),
                )
              : PlayingCard(
                  faceUp: false,
                  width: geo.cardW,
                  style: kOldMaidStyle,
                  highlight: i == _selected,
                  highlightColor: _theme.ink,
                ),
        ),
    ];
  }

  Widget _placed({
    Key? key,
    required Rect rect,
    double angle = 0,
    double opacity = 1,
    Alignment pivot = Alignment.center,
    required Widget child,
  }) {
    return Positioned.fromRect(
      key: key,
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.rotate(angle: angle, alignment: pivot, child: child),
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

  // ── 가운데 무대: 버린 짝 더미 · 안내 · 타이머 · 문구 ───────────────────────

  List<Widget> _center(
    OldMaidTableLayout l,
    List<String> discards,
    String? opp,
  ) {
    final t = _theme;
    final oppName = _c.displayName(opp);
    final playing = _c.playing;
    final prompt = !playing
        ? '판이 끝났어요'
        : _c.myTurn
        ? (_selected == null ? '상대 카드를 한 장 골라요' : '이 카드로 정했어요')
        : '$oppName${subjectParticle(oppName)} 내 카드를 고르는 중…';
    final pairGlow = _fxDraw != null && _fxDraw!.paired && _fx.value >= 0.96;
    final showText = _fxDraw == null;
    return [
      Positioned.fromRect(
        rect: l.panel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.hair),
            boxShadow: [
              BoxShadow(
                color: t.ink.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Center(
                    child: OldMaidDiscardStack(
                      theme: t,
                      pairs: discards.length,
                      cardW: l.discardPile.width,
                      glow: pairGlow,
                    ),
                  ),
                ),
                Expanded(
                  child: showText
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _stageText(t, prompt),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  width: 68,
                  child: playing && _c.deadline != null
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: ModTimerRing(
                            theme: t,
                            deadline: _c.deadline,
                            size: 52,
                            stroke: 3.4,
                            numberSize: 17,
                            tickSound: _c.myTurn,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      // 뽑기 결과 문구(뽑은 쪽/뺏긴 쪽이 서로 다르게 읽는다).
      Positioned.fromRect(
        rect: l.caption,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _caption == null
                ? const SizedBox(height: 22, key: ValueKey('no-caption'))
                : Text(
                    _caption!,
                    key: ValueKey(_captionSeq),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(
                      size: 13.5,
                      color: (_fxDraw?.jokerMoved ?? false)
                          ? t.accent
                          : const Color(0xFF527360),
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    ];
  }

  Widget _stageText(GameTheme t, String prompt) {
    final myTurn = _c.myTurn;
    final playing = _c.playing;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playing)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: myTurn ? t.accent : t.ink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  myTurn ? '내 차례' : '상대 차례',
                  style: t.body(
                    size: 13,
                    color: myTurn ? Colors.white : t.subInk,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            SizedBox(height: playing ? 10 : 0),
            Text(
              prompt,
              textAlign: TextAlign.center,
              style: t.display(size: 18).copyWith(height: 1.35),
            ),
            if (myTurn) ...[
              const SizedBox(height: 4),
              Text(
                '한 번 더 누르면 바로 뽑아요',
                textAlign: TextAlign.center,
                style: t.body(
                  size: 12.5,
                  color: t.subInk,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 내 부채꼴(정렬, NEW, 조커 베리 테두리) ───────────────────────────────

  List<Widget> _myFan(OldMaidTableLayout l, List<OldMaidCard> hand) {
    final geo = l.myFanOf(hand.length);
    return [
      for (var i = 0; i < hand.length; i++)
        _placed(
          key: ValueKey('om-my-${hand[i].id}'),
          rect: _dealt(geo.rectOf(i), i, hand.length, l.stage),
          angle: geo.angleOf(i),
          pivot: geo.pivot,
          child: PlayingCard(
            suit: hand[i].suit,
            rank: hand[i].rank,
            width: geo.cardW,
            style: kOldMaidStyle,
            highlight: hand[i].isJoker,
            highlightColor: kJokerRed.withValues(alpha: 0.25),
            badge: hand[i].id == _c.newCardId ? 'NEW' : null,
          ),
        ),
    ];
  }

  // ── 내 줄 · 주 버튼 ──────────────────────────────────────────────────────

  List<Widget> _myBar(OldMaidTableLayout l, String? opp) {
    final t = _theme;
    final me = _c.me;
    final hasJoker = _c.myHand.any((c) => c.isJoker);
    final sub = '카드 ${_c.myHand.length}장${hasJoker ? ' · 조커 보유' : ''}';
    return [
      Positioned.fromRect(
        rect: l.myBar,
        child: Center(
          child: ModCapsule(
            theme: t,
            name: _c.displayName(me),
            sub: sub,
            mine: true,
            active: _c.myTurn,
            height: 48,
            minWidth: 186,
          ),
        ),
      ),
      Positioned(
        left: l.myBar.center.dx + 70,
        top: l.myBar.top - 40,
        child: ReactionBubble(
          theme: t,
          forPlayer: me,
          gameType: OldMaidController.gameType,
        ),
      ),
      Positioned(
        right: 20,
        top: l.myBar.top + 1,
        child: ReactionButton(theme: t, gameType: OldMaidController.gameType),
      ),
    ];
  }

  Widget _dock(OldMaidTableLayout l, String? opp) {
    final t = _theme;
    final d = _fxDraw;
    final String label;
    VoidCallback? onTap;
    if (d != null) {
      label = d.paired ? '짝을 버리는 중…' : '카드를 옮기는 중…';
    } else if (!_c.playing) {
      label = '판이 끝났어요';
    } else if (_c.myTurn) {
      label = '이 카드 뽑기';
      if (_canPick && _selected != null) onTap = _confirm;
    } else {
      label = '${_c.displayName(opp)} 차례예요';
    }
    return Positioned.fromRect(
      rect: l.dock,
      child: ModButton(theme: t, label: label, onPressed: onTap),
    );
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
              highlight: d.jokerMoved && p > 0.3,
              highlightColor: kJokerRed,
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
            highlight: false,
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
          top: stage.top - 20,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 1 - wordOut,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(wordIn) * 0.9 + 0.1,
                  child: OldMaidStamp(
                    theme: t,
                    text: word,
                    joker: d.jokerMoved,
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
          highlightColor: d.jokerMoved ? kJokerRed : t.ink,
        ),
      ),
    ];
  }

  // ── 결과 ─────────────────────────────────────────────────────────────────

  Widget _resultOverlay() {
    final t = _theme;
    final won = _c.winner != null && _c.winner == _c.me;
    final opp = _c.opponent;
    final oppName = _c.displayName(opp);
    final loserId = _c.loser;
    final loserName = _c.displayName(loserId);
    final reason = switch ((_c.resultReason, won)) {
      ('timeout', true) =>
        '$oppName${subjectParticle(oppName)} 시간을 세 번 넘겨 이겼어요',
      ('timeout', false) => '시간을 세 번 넘겨 기권 처리됐어요',
      ('afk', true) => '$oppName${subjectParticle(oppName)} 자리를 비워 이겼어요',
      ('afk', false) => '오래 자리를 비워 기권 처리됐어요',
      (_, true) => '마지막 조커는 $oppName에게 남았어요',
      (_, false) => '마지막까지 조커를 들고 있었어요',
    };
    // 조커를 쥔 쪽의 마지막 손패.
    final lastHand = loserId == _c.me
        ? _c.sortedHand
        : OldMaidController.sortHand(_c.oppRevealed);
    return ModResultView(
      theme: t,
      backdrop: ModBackdropKind.paper,
      gameType: OldMaidController.gameType,
      outcome: won ? GameOutcome.win : GameOutcome.lose,
      hero: const ThiefHero(size: 80),
      title: won ? '도둑을 잡았어요!' : '조커가 내 손에…',
      titleSize: 30,
      why: reason,
      extra: lastHand.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final c in lastHand)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            5,
                            c.isJoker ? 0 : 8,
                            5,
                            c.isJoker ? 8 : 0,
                          ),
                          child: PlayingCard(
                            suit: c.suit,
                            rank: c.rank,
                            width: 54,
                            style: kOldMaidStyle,
                            highlight: c.isJoker,
                            highlightColor: kJokerRed.withValues(alpha: 0.25),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$loserName의 마지막 손패',
                  style: t.body(
                    size: 12.5,
                    color: t.subInk,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ),
      series: _c.series,
      me: _c.me,
      table: _recentMoments(t, oppName),
      onRematch: () => _socket.requestRestart(OldMaidController.gameType),
      rematchWaiting: _socket.restartWaiting,
      onHelp: _showHelp,
      resultId: _c.gameId,
    );
  }

  /// 마지막 순간들: 최근 뽑기 세 줄(위가 최신).
  Widget? _recentMoments(GameTheme t, String oppName) {
    final logs = _c.log.reversed.take(3).toList();
    if (logs.isEmpty) return null;
    Widget row(OldMaidLogEntry e) {
      final mine = e.by == _c.me;
      final rank = e.rank ?? '';
      final obj = objectParticle(rank);
      final String text;
      if (mine) {
        text = e.paired
            ? '내가 $oppName의 $rank$obj 뽑아 짝!'
            : '내가 $oppName의 카드를 뽑았어요';
      } else {
        text = e.paired
            ? '$oppName${subjectParticle(oppName)} 내 $rank$obj 뽑아 짝!'
            : '$oppName${subjectParticle(oppName)} 내 카드를 뽑았어요';
      }
      final dot = mine && e.paired ? kPairSage : (mine ? t.me : t.opponent);
      return SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body(size: 13.5, weight: FontWeight.w400),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                mine ? '나' : oppName,
                style: t.body(
                  size: 12,
                  color: t.subInk,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    TextStyle small() =>
        t.body(size: 12, color: t.subInk, weight: FontWeight.w400);
    return ModRowsCard(
      theme: t,
      header: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('마지막 순간들', style: small()),
              Text('버린 짝 ${_c.discards.length}쌍', style: small()),
            ],
          ),
        ),
      ),
      rows: [for (final e in logs) row(e)],
    );
  }
}
