import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/modern_kit.dart';
import '../../../../widgets/play_kit/modern_result.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'blackjack_controller.dart';
import 'blackjack_hand.dart';
import 'blackjack_result.dart';
import 'blackjack_rules.dart';
import 'blackjack_table.dart';

/// 블랙잭 2.0 화면(모던 라운지). 위 = 상대, 아래 = 나. 시작 버튼 없이 서버가 로비 시작 때
/// 만든 판을 `sync`로 받아 그린다.
class BlackjackGameScreen extends StatefulWidget {
  /// 화면이 열릴 때 서버에 현재 상태를 요청한다(테스트에서 끈다).
  final bool autoSync;

  /// 처음 한 번 규칙 요약을 띄운다(테스트에서 끈다).
  final bool showHowTo;

  const BlackjackGameScreen({
    super.key,
    this.autoSync = true,
    this.showHowTo = true,
  });

  @override
  State<BlackjackGameScreen> createState() => _BlackjackGameScreenState();
}

class _BlackjackGameScreenState extends State<BlackjackGameScreen> {
  static const _theme = GameTheme.lounge;
  static const _gameType = 'blackjack';
  static const _revealHold = Duration(milliseconds: 1100);
  static const _finalHold = Duration(milliseconds: 2000);

  final _c = BlackjackController.instance;
  final _sock = SocketService();

  BlackjackView? _prev;
  Object? _bannerId;
  Object? _toastId;
  String? _toast;
  int _seq = 0;

  /// 결과 패널이 보이는 라운드(공개 연출이 끝난 뒤), 결과 화면이 보이는 판.
  String? _panelFor;
  String? _overlayFor;
  Timer? _panelTimer;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.cardDeal,
      GameSound.cardFlip,
      GameSound.cardShuffle,
      GameSound.bust,
      GameSound.blackjack,
      GameSound.turnMine,
      GameSound.turnOpp,
      GameSound.tick,
      GameSound.chip,
      GameSound.pop,
      GameSound.win,
      GameSound.lose,
      GameSound.draw,
    ]);
    _c.addListener(_onState);
    _sock.addListener(_onSocket);
    _prev = _c.view;
    final v = _c.view;
    if (v != null) {
      // 이미 끝난 라운드/판을 열었으면 연출 없이 바로 보여 준다.
      if (v.showsRoundResult) _panelFor = _roundKey(v);
      if (v.finished) _overlayFor = v.gameId;
    }
    if (widget.autoSync) _c.sync();
    if (widget.showHowTo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModHowToOnce(
          context,
          prefKey: 'how_to_blackjack_v2',
          theme: _theme,
          title: '블랙잭 1:1',
          lines: blackjackHowTo,
        );
      });
    }
  }

  @override
  void dispose() {
    _panelTimer?.cancel();
    _overlayTimer?.cancel();
    _c.removeListener(_onState);
    _sock.removeListener(_onSocket);
    super.dispose();
  }

  void _onSocket() {
    if (mounted) setState(() {});
  }

  static String _roundKey(BlackjackView v) => '${v.gameId}-${v.round}';

  void _showToast(String message) {
    _toast = message;
    _toastId = ++_seq;
  }

  void _onState() {
    if (!mounted) return;
    final v = _c.view;
    final p = _prev;
    _prev = v;
    if (v == null) {
      _panelTimer?.cancel();
      _overlayTimer?.cancel();
      _panelFor = null;
      _overlayFor = null;
      setState(() {});
      return;
    }
    final key = _roundKey(v);
    final sameRound = p != null && _roundKey(p) == key;
    final me = v.me;
    final opp = v.opponent;

    // 새 판(재대결)이면 결과 화면을 내린다.
    if (p != null && p.gameId != v.gameId) {
      _overlayTimer?.cancel();
      _overlayFor = null;
    }
    if (!sameRound && v.playing) {
      GameSfx.instance.play(GameSound.cardShuffle);
      _panelTimer?.cancel();
    }

    if (v.playing) {
      final turnChanged = !sameRound || p.currentTurn != v.currentTurn;
      if (turnChanged && v.isMyTurn) {
        _bannerId = ++_seq;
        GameSfx.instance.play(GameSound.turnMine);
      } else if (turnChanged && v.currentTurn == opp) {
        GameSfx.instance.play(GameSound.turnOpp, volume: 0.6);
      }
      final myNow = v.myScore();
      final myBefore = sameRound ? p.myScore() : 0;
      if (myNow == 21 && myBefore != 21) {
        GameSfx.instance.play(GameSound.blackjack);
      }
    }

    // 버스트(라운드 결과와 같이 온다).
    for (final id in v.players) {
      final busted = v.statuses[id] == 'bust';
      final before = sameRound && p.statuses[id] == 'bust';
      if (busted && !before) {
        GameSfx.instance.play(GameSound.bust);
        if (id == opp) _showToast('${_name(opp, mine: false)}님 버스트!');
      }
    }

    // 시간 초과 자동 스탠드 안내.
    if (p != null && p.gameId == v.gameId) {
      for (final id in v.players) {
        final before = (p.raw['timeouts'] as Map?)?[id] as num? ?? 0;
        final now = (v.raw['timeouts'] as Map?)?[id] as num? ?? 0;
        if (now > before && !v.finished) {
          _showToast(
            id == me ? '시간이 지나 자동으로 스탠드했어요 ($now/3)' : '상대가 시간을 넘겨 자동 스탠드했어요',
          );
        }
      }
      if (v.phase == 'round_result' &&
          p.phase == 'round_result' &&
          v.ready[opp] == true &&
          p.ready[opp] != true &&
          v.ready[me] != true) {
        _showToast('상대가 다음 라운드를 기다려요');
      }
    }

    // 라운드가 끝났다: 홀카드 공개 연출 뒤 결과 패널, 판이 끝났으면 결과 화면.
    final newReveal =
        v.showsRoundResult &&
        (p == null || !p.showsRoundResult || _roundKey(p) != key);
    if (newReveal) {
      _panelTimer?.cancel();
      _panelTimer = Timer(_revealHold, () {
        if (!mounted) return;
        final r = _c.view?.lastRoundResult;
        final winner = r?['winner'];
        GameSfx.instance.play(
          winner == _c.view?.me ? GameSound.chip : GameSound.pop,
        );
        setState(() => _panelFor = key);
      });
    }
    if (v.finished && _overlayFor != v.gameId && _overlayTimer == null) {
      final gameId = v.gameId;
      _overlayTimer = Timer(
        v.showsRoundResult ? _finalHold : Duration.zero,
        () {
          _overlayTimer = null;
          if (mounted && _c.view?.gameId == gameId) {
            setState(() => _overlayFor = gameId);
          }
        },
      );
    }
    setState(() {});
  }

  String _name(String? id, {required bool mine}) {
    final name = _c.nameOf(id);
    if (name.isEmpty || name == id) return mine ? '나' : '상대';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: _gameType,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final v = _c.view;
            final overlay = v != null && v.finished && _overlayFor == v.gameId;
            return Stack(
              children: [
                ModBackdrop(
                  theme: t,
                  kind: ModBackdropKind.felt,
                  child: SafeArea(child: _content(v)),
                ),
                // 결과 화면은 안전 영역까지 덮는다(자체 SafeArea를 가진다).
                if (overlay) Positioned.fill(child: _resultOverlay(v)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(BlackjackView? v) {
    final t = _theme;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                ModTopBar(
                  theme: t,
                  title: '블랙잭',
                  gameType: _gameType,
                  canRestart: true,
                  restartWaiting: _sock.restartWaiting,
                  onRequestRestart: () => _sock.requestRestart(_gameType),
                  onHelp: _showHelp,
                ),
                if (v == null)
                  Expanded(child: _preparing())
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: BlackjackHud(
                      theme: t,
                      round: v.round,
                      maxRounds: v.maxRounds,
                      winsNeeded: v.winsNeeded,
                      myWins: v.winsOf(v.me),
                      oppWins: v.winsOf(v.opponent),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _table(v),
                    ),
                  ),
                  _dock(v),
                ],
              ],
            ),
          ),
        ),
        ModTurnFlash(
          theme: t,
          id: _bannerId,
          text: '내 차례',
          sub: '히트 또는 스탠드를 골라요',
          alignment: const Alignment(0, -0.12),
        ),
        // 안내는 테이블 가운데(남은 시간 위)에 잠깐 띄워 머리글을 가리지 않는다.
        Align(
          alignment: const Alignment(0, -0.12),
          child: ModToast(theme: t, id: _toastId, message: _toast),
        ),
      ],
    );
  }

  void _showHelp() => showModHowTo(
    context,
    theme: _theme,
    title: '블랙잭 1:1',
    lines: blackjackHowTo,
  );

  Widget _preparing() {
    final t = _theme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: t.gold),
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

  Widget _table(BlackjackView v) {
    final t = _theme;
    final me = v.me;
    final opp = v.opponent;
    final key = _roundKey(v);
    final reveal = v.roundOver;
    final oppCards = v.handOf(opp);
    final myCards = v.handOf(me);
    final oppScore = reveal
        ? (v.scores[opp] ?? blackjackScore(oppCards))
        : null;
    final myScore = v.myScore();
    final oppFirst = v.firstPlayer == opp;
    final panel = v.showsRoundResult && _panelFor == key;
    final String? winnerId = panel
        ? (v.lastRoundResult?['winner'] as String?)
        : null;
    return BlackjackFelt(
      theme: t,
      child: LayoutBuilder(
        builder: (context, box) {
          const seatH = 56.0;
          const midH = 52.0;
          final w = box.maxWidth;
          final h = box.maxHeight;
          // 다섯 줄(좌석·패·가운데·패·좌석)을 같은 간격으로 나눈다. 높이가 모자라면 카드부터 줄인다.
          final spare = h - seatH * 2 - midH;
          final handH = math.min(94.0, (spare - 4 * 8) / 2).clamp(40.0, 94.0);
          final gap = math.max(0.0, (spare - 2 * handH) / 4);
          // 카드는 테이블 오른쪽 가장자리 가운데에서 나눠 준다.
          final deal = Offset(w, h / 2);
          final oppCenter = Offset(w / 2, seatH + gap + handH / 2);
          final myCenter = Offset(w / 2, h - seatH - gap - handH / 2);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  SizedBox(
                    height: seatH,
                    child: _seat(
                      v,
                      opp,
                      mine: false,
                      score: oppScore,
                      winnerId: winnerId,
                      showResult: panel,
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: handH,
                    child: BlackjackHand(
                      theme: t,
                      cards: oppCards,
                      roundKey: key,
                      seat: oppFirst ? 0 : 1,
                      dealFrom: deal - oppCenter,
                      flipDelay: Duration(milliseconds: oppFirst ? 150 : 520),
                      gold: oppScore == 21,
                      bust: v.statuses[opp] == 'bust',
                      winner: winnerId != null && winnerId == opp,
                      semanticsLabel: '상대 카드 ${oppCards.length}장',
                    ),
                  ),
                  SizedBox(height: gap),
                  BlackjackMidRow(theme: t, center: _center(v, panel)),
                  SizedBox(height: gap),
                  SizedBox(
                    height: handH,
                    child: BlackjackHand(
                      theme: t,
                      cards: myCards,
                      roundKey: key,
                      seat: oppFirst ? 1 : 0,
                      dealFrom: deal - myCenter,
                      markHole: !reveal,
                      gold: myScore == 21,
                      bust: v.statuses[me] == 'bust',
                      winner: winnerId != null && winnerId == me,
                      semanticsLabel: '내 카드 ${myCards.length}장, 합 $myScore',
                    ),
                  ),
                  SizedBox(height: gap),
                  SizedBox(
                    height: seatH,
                    child: _seat(
                      v,
                      me,
                      mine: true,
                      score: myScore,
                      winnerId: winnerId,
                      showResult: panel,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: seatH - 6,
                left: 44,
                child: ReactionBubble(
                  theme: t,
                  forPlayer: opp,
                  gameType: _gameType,
                ),
              ),
              Positioned(
                bottom: seatH - 6,
                left: 44,
                child: ReactionBubble(
                  theme: t,
                  forPlayer: me,
                  gameType: _gameType,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 가운데: 진행 중에는 남은 시간 링, 끝나면 "패배  18 : 20" 같은 알약.
  Widget _center(BlackjackView v, bool panel) {
    final t = _theme;
    if (v.playing && v.deadline != null) {
      // 링은 56px, 줄은 52px: 위아래로 2px씩 걸쳐 그린다.
      return SizedBox(
        width: 56,
        height: 52,
        child: OverflowBox(
          maxHeight: 56,
          child: ModTimerRing(
            theme: t,
            deadline: v.deadline,
            size: 56,
            stroke: 3,
            numberSize: 19,
            tickSound: v.isMyTurn,
          ),
        ),
      );
    }
    if (v.playing) {
      return BlackjackChip(theme: t, text: v.isMyTurn ? '내 차례' : '상대 차례');
    }
    if (panel) {
      final winner = v.lastRoundResult?['winner'];
      final tie = winner == null || winner == 'tie';
      final iWon = winner == v.me;
      final mine = v.scores[v.me] ?? blackjackScore(v.handOf(v.me));
      final theirs =
          v.scores[v.opponent] ?? blackjackScore(v.handOf(v.opponent));
      return BlackjackChip(
        theme: t,
        text: '${tie ? '무승부' : (iWon ? '승리' : '패배')}  $mine : $theirs',
        lose: !tie && !iWon,
      );
    }
    return BlackjackChip(theme: t, text: '카드 공개');
  }

  /// 좌석 한 줄: 캡슐(이름 + 상태) + 합계 플라크.
  Widget _seat(
    BlackjackView v,
    String? id, {
    required bool mine,
    int? score,
    String? winnerId,
    required bool showResult,
  }) {
    final t = _theme;
    final status = v.statuses[id];
    final natural = v.roundOver && isNaturalBlackjack(v.handOf(id));
    final active = v.playing && v.currentTurn == id;
    final won = winnerId != null && winnerId == id;
    final String sub;
    if (showResult && score != null) {
      final tail = natural
          ? '블랙잭'
          : won
          ? '승리'
          : status == 'bust'
          ? '버스트'
          : (winnerId == null || winnerId == 'tie')
          ? '무승부'
          : '스탠드';
      sub = '$score · $tail';
    } else if (natural) {
      sub = '블랙잭!';
    } else if (status == 'bust') {
      sub = '버스트!';
    } else if (status == 'stand') {
      sub = '스탠드!';
    } else if (active) {
      sub = mine ? '고르는 중' : '고르는 중…';
    } else if (v.playing) {
      sub = '기다리는 중';
    } else if (v.phase == 'round_result' && v.ready[id] == true) {
      sub = '다음 라운드 준비 완료';
    } else {
      sub = '';
    }
    final String value;
    final String caption;
    if (mine) {
      value = '$score';
      caption = natural ? '블랙잭' : '내 합';
    } else if (score != null) {
      value = '$score';
      caption = natural ? '블랙잭' : '상대 합';
    } else {
      value = '${v.visibleScores[id] ?? 0}+?';
      caption = '공개 합';
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ModCapsule(
          theme: t,
          name: _name(id, mine: mine),
          sub: sub,
          mine: mine,
          active: active,
          height: 56,
          minWidth: 172,
        ),
        ScorePlaque(
          theme: t,
          value: value,
          caption: caption,
          win: won,
          bust: status == 'bust',
        ),
      ],
    );
  }

  Widget _dock(BlackjackView v) {
    final t = _theme;
    final key = _roundKey(v);
    final showResult = v.showsRoundResult && _panelFor == key;
    final pending = _c.pending;
    final Widget top;
    final Widget actions;
    if (showResult) {
      top = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BlackjackRoundHeadline(theme: t, view: v),
      );
      if (v.finished) {
        actions = ModButton(
          theme: t,
          label: '최종 결과 보기',
          onPressed: () {
            _overlayTimer?.cancel();
            _overlayTimer = null;
            setState(() => _overlayFor = v.gameId);
          },
        );
      } else {
        final iReady = v.ready[v.me] == true;
        actions = ModButton(
          theme: t,
          label: iReady ? '상대를 기다리는 중…' : '다음 라운드 준비',
          onPressed: iReady || pending ? null : _c.nextRound,
        );
      }
    } else {
      top = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ReactionButton(theme: t, gameType: _gameType),
                ),
              ),
              Expanded(
                child: Text(
                  _statusLine(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.body(
                    size: 14,
                    color: v.isMyTurn ? t.gold : t.subInk,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      );
      final canAct = !pending;
      actions = Row(
        children: [
          Expanded(
            child: ModButton(
              theme: t,
              label: '히트',
              sub: '카드 한 장 더',
              onPressed: v.canHit && canAct ? _c.hit : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ModButton(
              theme: t,
              label: '스탠드',
              sub: '여기서 멈추기',
              kind: ModButtonKind.outline,
              onPressed: v.canStand && canAct ? _c.stand : null,
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [top, actions]),
    );
  }

  String _statusLine(BlackjackView v) {
    if (v.roundOver) return '숨은 카드를 공개해요…';
    if (v.isMyTurn) {
      return v.myScore() == 21 ? '21! 스탠드로 지켜요' : '내 차례 — 히트 또는 스탠드';
    }
    return '${_name(v.opponent, mine: false)}님이 고르는 중…';
  }

  Widget _resultOverlay(BlackjackView v) {
    final t = _theme;
    final winner = v.result?['winner'] as String?;
    final draw = winner == null || winner == 'tie';
    final iWon = winner == v.me;
    final outcome = draw
        ? GameOutcome.draw
        : (iWon ? GameOutcome.win : GameOutcome.lose);
    return ModResultView(
      theme: t,
      backdrop: ModBackdropKind.felt,
      gameType: _gameType,
      outcome: outcome,
      hero: BlackjackResultMark(theme: t, outcome: outcome),
      title: draw ? '무승부' : (iWon ? '승리' : '패배'),
      titleColor: draw ? t.ink : (iWon ? t.gold : t.lose),
      titleSize: 44,
      why: draw
          ? '5라운드를 마쳤는데 승수가 같아요'
          : matchReasonText(v.result?['reason'] as String?, iWon: iWon),
      series: v.series,
      me: v.me,
      table: BlackjackRoundHistory(theme: t, view: v),
      onRematch: () => _sock.requestRestart(_gameType),
      rematchWaiting: _sock.restartWaiting,
      onHelp: _showHelp,
      resultId: 'blackjack-${v.gameId}',
    );
  }
}
