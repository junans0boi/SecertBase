import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'telepathy_controller.dart';
import 'telepathy_models.dart';
import 'telepathy_result.dart';
import 'telepathy_widgets.dart';

const _kGameType = 'telepathy';

/// 공개 연출 길이(서버의 revealMs 3.5초보다 조금 짧게).
const Duration kTelepathyRevealDuration = Duration(milliseconds: 3300);

const _kHowToLines = [
  '매 문제마다 둘 중 마음에 드는 쪽을 몰래 골라요.',
  '두 사람이 같은 쪽을 고르면 "통했어요!" 별이 하나 켜져요.',
  '연속으로 통하면 🔥 연속 기록이 쌓여요.',
  '한 문제는 15초(첫 문제는 규칙을 읽도록 더 길어요). 시간이 지나면 그 문제는 엇갈린 걸로 넘어가요.',
  '연속 3문제를 고르지 않으면 판이 끝나요. 이기고 지는 건 없어요.',
];

/// 공개 연출 타임라인(0→1). 잠깐 멈춤 → 두 카드가 함께 뒤집힘 → 판정 → 빛줄기.
class TelepathyReveal {
  static const double flipStart = 0.10;
  static const double flipEnd = 0.38;
  static const double verdict = 0.42;
  static const double beamEnd = 0.68;
}

/// 텔레파시 2.0: 별빛 편지. 서버가 로비 시작과 함께 판을 만든다(시작 버튼 없음).
class TelepathyGameScreen extends StatefulWidget {
  const TelepathyGameScreen({super.key});

  @override
  State<TelepathyGameScreen> createState() => _TelepathyGameScreenState();
}

class _TelepathyGameScreenState extends State<TelepathyGameScreen>
    with TickerProviderStateMixin {
  static const GameTheme theme = GameTheme.starlight;

  final _c = TelepathyController.instance;
  final _socket = SocketService();

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: kTelepathyRevealDuration,
  )..addStatusListener(_onRevealStatus);
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  String? _gameId;
  int _shownRound = 0;
  TelepathyRound? _revealing;
  Object? _bannerId;
  String _bannerText = '';
  String? _bannerSub;
  int _toastSeq = 0;
  String? _toast;
  final Set<int> _soundsPlayed = {};

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.tap,
      GameSound.select,
      GameSound.confirm,
      GameSound.tick,
      GameSound.warn,
      GameSound.whoosh,
      GameSound.cardFlip,
      GameSound.sparkle,
      GameSound.pop,
      GameSound.aww,
      GameSound.cheer,
      GameSound.win,
      GameSound.draw,
    ]);
    _reveal.addListener(_onRevealTick);
    _c.addListener(_onState);
    _absorbState();
    _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'howto_telepathy_v2',
        theme: theme,
        title: '텔레파시 규칙',
        emoji: '💫',
        lines: _kHowToLines,
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onState);
    _reveal.removeListener(_onRevealTick);
    _reveal.dispose();
    _sway.dispose();
    super.dispose();
  }

  // ── 상태 변화 ────────────────────────────────────────────────────────────

  void _onState() {
    if (!mounted) return;
    setState(_absorbState);
  }

  /// 새 판이면 화면 상태를 비우고, 새로 공개된 문제가 있으면 연출을 시작한다.
  void _absorbState() {
    final s = _c.state;
    if (s == null) return;
    if (s.gameId != _gameId) {
      final first = _gameId == null;
      _gameId = s.gameId;
      _shownRound = s.lastRound?.round ?? 0;
      _revealing = null;
      _soundsPlayed.clear();
      _reveal.reset();
      if (!first && s.playing) _banner('새 판 시작!', '${s.rounds}문제');
    } else if (_revealing == null &&
        s.lastRound != null &&
        s.lastRound!.round > _shownRound) {
      _startReveal(s.lastRound!);
    }
  }

  void _startReveal(TelepathyRound r) {
    _revealing = r;
    _soundsPlayed.clear();
    HapticFeedback.mediumImpact();
    _reveal.forward(from: 0);
  }

  /// 연출 진행에 맞춰 소리를 한 번씩만 낸다.
  void _onRevealTick() {
    final r = _revealing;
    if (r == null) return;
    final v = _reveal.value;
    void once(int key, double at, VoidCallback f) {
      if (v >= at && _soundsPlayed.add(key)) f();
    }

    once(0, 0.02, () => GameSfx.instance.play(GameSound.whoosh));
    once(
      1,
      TelepathyReveal.flipStart,
      () => GameSfx.instance.play(GameSound.cardFlip),
    );
    once(2, TelepathyReveal.verdict, () {
      if (r.matched) {
        GameSfx.instance.play(GameSound.sparkle);
        HapticFeedback.heavyImpact();
        if (r.streak >= 3) GameSfx.instance.play(GameSound.cheer);
      } else {
        GameSfx.instance.play(r.timedOut ? GameSound.warn : GameSound.aww);
      }
    });
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final r = _revealing;
    if (r == null) return;
    final s = _c.state;
    setState(() {
      _shownRound = r.round;
      _revealing = null;
      if (s == null) return;
      final mine = s.timeouts[_c.me] ?? 0;
      if (s.playing && mine >= 2) {
        _toast = '한 번 더 안 고르면 판이 끝나요';
        _toastSeq++;
        GameSfx.instance.play(GameSound.warn);
      } else if (s.playing && r.picks[_c.me] == null) {
        _toast = '시간이 지나 넘어갔어요';
        _toastSeq++;
      }
      // 연출 중에 다음 문제가 또 끝났으면 이어서 보여 준다.
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

  void _pick(String choice) {
    if (_revealing != null) return;
    GameSfx.instance.play(GameSound.confirm);
    HapticFeedback.selectionClick();
    _c.pick(choice);
  }

  void _help() => showGameHowTo(
    context,
    theme: theme,
    title: '텔레파시 규칙',
    emoji: '💫',
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
          frame: false,
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
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GameTopBar(
                    theme: theme,
                    title: '텔레파시',
                    gameType: _kGameType,
                    canRestart: true,
                    restartWaiting: _socket.restartWaiting,
                    onRequestRestart: () => _socket.requestRestart(_kGameType),
                    onHelp: _help,
                  ),
                ),
                if (s == null)
                  Expanded(child: _Preparing(sway: _sway))
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, box) =>
                            _content(s, me, opp, compact: box.maxHeight < 560),
                      ),
                    ),
                  ),
              ],
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
          top: 130,
          right: 20,
          child: ReactionBubble(
            theme: theme,
            forPlayer: opp,
            gameType: _kGameType,
          ),
        ),
        Positioned(
          top: 130,
          left: 20,
          child: ReactionBubble(
            theme: theme,
            forPlayer: me,
            gameType: _kGameType,
          ),
        ),
        if (s != null && s.playing)
          Positioned(
            right: 14,
            bottom: 10,
            child: ReactionButton(theme: theme, gameType: _kGameType),
          ),
        if (showResult)
          Positioned.fill(
            child: TelepathyResultPage(
              state: s,
              me: me,
              partner: opp,
              nameOf: _c.displayName,
              onRematch: () => _socket.requestRestart(_kGameType),
              rematchWaiting: _socket.restartWaiting,
            ),
          ),
      ],
    );
  }

  // ── 연출 값 ──────────────────────────────────────────────────────────────

  bool get _afterVerdict =>
      _revealing != null && _reveal.value >= TelepathyReveal.verdict;

  Widget _content(
    TelepathyState s,
    String? me,
    String? opp, {
    required bool compact,
  }) {
    final r = _revealing;
    final q = r?.question ?? s.question ?? s.lastRound?.question;
    // 연출 중에는 방금 공개된 문제를 아직 점·점수에 넣지 않는다.
    final visible = r == null
        ? s.history
        : s.history.where((h) => h.round < r.round).toList();
    return AnimatedBuilder(
      animation: Listenable.merge([_reveal, _sway]),
      builder: (context, _) => Column(
        children: [
          SizedBox(height: compact ? 4 : 8),
          _players(s, me, opp),
          SizedBox(height: compact ? 8 : 14),
          TelepathyProgressRow(
            current: r?.round ?? s.round,
            total: s.rounds,
            results: [for (final h in visible) h.matched],
            score: visible.where((h) => h.matched).length,
            currentHit: r != null && r.matched && _afterVerdict,
          ),
          SizedBox(height: compact ? 8 : 16),
          if (q != null) ...[
            TelepathyCategoryChip(
              label: q.categoryLabel,
              adultOnly: s.adultOnly,
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              '더 끌리는 쪽은?',
              textAlign: TextAlign.center,
              style: tpSerif(size: compact ? 22 : 25, height: 1.3),
            ),
          ],
          SizedBox(height: compact ? 10 : 20),
          Expanded(
            child: q == null
                ? const SizedBox()
                : _stage(s, q, r, me, opp, compact),
          ),
        ],
      ),
    );
  }

  /// 나 ── (타이머/통함/엇갈림) ── 상대. 통하면 연결선이 금빛 실선으로 이어진다.
  Widget _players(TelepathyState s, String? me, String? opp) {
    final r = _revealing;
    final verdict = _afterVerdict;
    final iPicked = _c.iPicked;
    final oppPicked = _c.partnerPicked;
    String? myStatus;
    String? oppStatus;
    var myGold = false;
    var oppGold = false;
    if (r != null && verdict) {
      String of(String? id) {
        final c = r.picks[id];
        return c == null ? '시간 초과' : r.question.textOf(c);
      }

      myStatus = of(me);
      oppStatus = of(opp);
    } else if (s.playing && r == null) {
      myStatus = iPicked ? '골랐어요' : '고르는 중…';
      oppStatus = oppPicked ? '골랐어요' : '고르는 중…';
      myGold = iPicked;
      oppGold = oppPicked;
    }
    final matched = r != null && r.matched && verdict;
    final missed = r != null && !r.matched && verdict;
    final beam = matched
        ? Curves.easeOutCubic.transform(
            telepathySpan(
              _reveal.value,
              TelepathyReveal.verdict,
              TelepathyReveal.beamEnd,
            ),
          )
        : 0.0;
    final tone = matched
        ? TelepathyLinkTone.gold
        : missed
        ? TelepathyLinkTone.broken
        : TelepathyLinkTone.idle;
    final mode = matched
        ? TelepathyRingMode.match
        : missed
        ? TelepathyRingMode.miss
        : (r == null && s.playing
              ? TelepathyRingMode.timer
              : TelepathyRingMode.idle);
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TelepathyCapsule(
              name: _c.displayName(me),
              mine: true,
              status: myStatus,
              statusGold: myGold,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TelepathyLink(tone: tone, progress: beam),
            ),
          ),
          TelepathyRing(
            mode: mode,
            deadline: _c.deadline,
            tickSound: s.playing && r == null && !iPicked,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TelepathyLink(tone: tone, progress: beam, fromRight: true),
            ),
          ),
          Expanded(
            flex: 5,
            child: TelepathyCapsule(
              name: _c.displayName(opp),
              mine: false,
              status: oppStatus,
              statusGold: oppGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(
    TelepathyState s,
    TelepathyQuestion q,
    TelepathyRound? r,
    String? me,
    String? opp,
    bool compact,
  ) {
    final reveal = r != null;
    final verdict = _afterVerdict;
    // 카드 아래: 여백 26 + 안내/판정(약 56) + 다음 문제 안내(22) + 아래 여백.
    final below = compact ? 104.0 : 130.0;
    return LayoutBuilder(
      builder: (context, box) {
        final cardsH = (box.maxHeight - below).clamp(150.0, 262.0).toDouble();
        return Column(
          children: [
            SizedBox(
              height: cardsH,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${s.gameId}_${q.id}'),
                  child: _cards(s, q, r, me, opp),
                ),
              ),
            ),
            SizedBox(height: compact ? 14 : 26),
            if (reveal && verdict)
              _verdict(r)
            else if (reveal)
              const SizedBox(height: 48)
            else
              _hint(s),
            const Spacer(),
            SizedBox(
              height: 22,
              child: reveal
                  ? Text(
                      s.finished
                          ? '곧 결과가 나와요'
                          : '다음 문제까지 ${((1 - _reveal.value) * kTelepathyRevealDuration.inMilliseconds / 1000).ceil().clamp(1, 9)}초',
                      style: tpSans(size: 12.5, color: kTpSub),
                    )
                  : null,
            ),
            SizedBox(height: compact ? 8 : 24),
          ],
        );
      },
    );
  }

  Widget _hint(TelepathyState s) {
    final second = !_c.iPicked
        ? '고르면 바로 확정돼요'
        : _c.partnerPicked
        ? '둘 다 골랐어요. 곧 공개!'
        : '상대가 고르는 중이에요…';
    return Column(
      children: [
        Text(
          '내가 고른 건 상대에게 보이지 않아요',
          textAlign: TextAlign.center,
          style: tpSans(size: 13.5, color: kTpSub, height: 1.5),
        ),
        const SizedBox(height: 2),
        Text(
          second,
          textAlign: TextAlign.center,
          style: tpSans(
            size: 12,
            color: _c.iPicked && _c.partnerPicked ? kTpGold : kTpSub,
          ),
        ),
      ],
    );
  }

  Widget _verdict(TelepathyRound r) {
    if (r.matched) {
      return TelepathyVerdict(
        matched: true,
        title: '통했어요!',
        sub: '마음이 같네요',
        streak: r.streak,
      );
    }
    if (r.timedOut) {
      return const TelepathyVerdict(
        matched: false,
        title: '시간이 지났어요',
        sub: '이번 문제는 넘어가요',
      );
    }
    return const TelepathyVerdict(
      matched: false,
      title: '이번엔 엇갈렸어요',
      sub: '다음엔 통할 거예요',
    );
  }

  /// 좌우 카드 + 가운데 VS 메달. 공개 때 두 카드가 함께 뒤집힌다.
  Widget _cards(
    TelepathyState s,
    TelepathyQuestion q,
    TelepathyRound? r,
    String? me,
    String? opp,
  ) {
    final v = _reveal.value;
    final flip = r == null
        ? 0.0
        : Curves.easeInOutCubic.transform(
            telepathySpan(
              v,
              TelepathyReveal.flipStart,
              TelepathyReveal.flipEnd,
            ),
          );
    final back = r != null && flip > 0.5;
    final verdict = _afterVerdict;
    final myName = _c.displayName(me);
    final oppName = _c.displayName(opp);
    TelepathyMark myMark() => TelepathyMark(
      initial: telepathyInitial(myName),
      mine: true,
      name: myName,
    );
    TelepathyMark oppMark() => TelepathyMark(
      initial: telepathyInitial(oppName),
      mine: false,
      name: oppName,
    );

    TelepathyOptionCard card(String letter) {
      var state = TelepathyCardState.idle;
      final marks = <TelepathyMark>[];
      if (r == null || !back) {
        // 고르는 중(또는 뒤집히기 전): 내가 고른 쪽만 금색 테두리 + 체크 + 내 표시.
        if (_c.iPicked && _c.myPick == letter) {
          state = TelepathyCardState.selected;
          marks.add(myMark());
        }
      } else {
        final mineHere = r.picks[me] == letter;
        final theirsHere = r.picks[opp] == letter;
        if (mineHere) marks.add(myMark());
        if (theirsHere) marks.add(oppMark());
        if (r.matched) {
          state = mineHere ? TelepathyCardState.hit : TelepathyCardState.dim;
        } else if (mineHere) {
          state = TelepathyCardState.mine;
        } else if (theirsHere) {
          state = TelepathyCardState.theirs;
        }
      }
      return TelepathyOptionCard(
        letter: letter,
        emoji: q.emojiOf(letter),
        text: q.textOf(letter),
        cardState: state,
        flip: flip,
        marks: marks,
        onTap: r == null && s.playing && !_c.iPicked
            ? () => _pick(letter)
            : null,
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: card('A')),
            const SizedBox(width: 12),
            Expanded(child: card('B')),
          ],
        ),
        TelepathyVsMedallion(
          hit: r != null && r.matched && verdict,
          off: r != null && !r.matched && verdict,
        ),
      ],
    );
  }
}

class _Preparing extends StatelessWidget {
  final Animation<double> sway;

  const _Preparing({required this.sway});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sway,
      builder: (context, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.6 + sway.value * 0.4,
              child: const TelepathySigil(size: 72, overlap: 0.35),
            ),
            const SizedBox(height: 18),
            Text('판을 준비하는 중', style: tpSerif(size: 24)),
            const SizedBox(height: 4),
            Text('곧 첫 질문이 열려요', style: tpSans(size: 13, color: kTpSub)),
          ],
        ),
      ),
    );
  }
}
