import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'blackjack_controller.dart';
import 'blackjack_hand.dart';
import 'blackjack_result.dart';
import 'blackjack_rules.dart';
import 'blackjack_table.dart';

/// 블랙잭 2.0 화면(벨벳 라운지). 위 = 상대, 아래 = 나. 시작 버튼 없이 서버가 로비 시작 때
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
        showHowToOnce(
          context,
          prefKey: 'how_to_blackjack_v2',
          theme: _theme,
          title: '블랙잭 1:1',
          emoji: '🃏',
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
    if (name.isEmpty || name == id) return mine ? '플레이어' : '상대';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: t.backdrop.last,
      body: GameMenuListener(
        gameType: _gameType,
        child: GameBackdrop(
          theme: t,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _c,
              builder: (context, _) {
                final v = _c.view;
                return Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            GameTopBar(
                              theme: t,
                              title: '블랙잭',
                              gameType: _gameType,
                              canRestart: true,
                              restartWaiting: _sock.restartWaiting,
                              onRequestRestart: () =>
                                  _sock.requestRestart(_gameType),
                              onHelp: () => showGameHowTo(
                                context,
                                theme: t,
                                title: '블랙잭 1:1',
                                emoji: '🃏',
                                lines: blackjackHowTo,
                              ),
                            ),
                            if (v == null)
                              Expanded(child: _preparing())
                            else ...[
                              _hud(v),
                              Expanded(child: _table(v)),
                              _dock(v),
                            ],
                          ],
                        ),
                      ),
                    ),
                    GameTurnBanner(
                      theme: t,
                      id: _bannerId,
                      text: '내 차례!',
                      sub: '히트 또는 스탠드를 골라요',
                    ),
                    Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      child: GameToast(theme: t, id: _toastId, message: _toast),
                    ),
                    if (v != null && v.finished && _overlayFor == v.gameId)
                      Positioned.fill(child: _resultOverlay(v)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _preparing() {
    final t = _theme;
    return Center(
      child: GamePanel(
        theme: t,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: t.gold),
            ),
            const SizedBox(height: 12),
            Text('판을 준비하는 중…', style: t.body(size: 15)),
          ],
        ),
      ),
    );
  }

  Widget _hud(BlackjackView v) {
    final t = _theme;
    final me = v.me;
    final opp = v.opponent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundPips(
                theme: t,
                wins: v.winsOf(me),
                needed: v.winsNeeded,
                color: t.me,
                label: '나',
              ),
              const SizedBox(height: 2),
              Text('나', style: t.body(size: 11, color: t.subInk)),
            ],
          ),
          Expanded(
            child: Semantics(
              label: '${v.round}라운드, 최대 ${v.maxRounds}라운드',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${v.round}라운드',
                    style: t.display(size: 20, color: t.gold),
                  ),
                  Text(
                    '먼저 ${v.winsNeeded}승 · 최대 ${v.maxRounds}라운드',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body(size: 10.5, color: t.subInk),
                  ),
                ],
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundPips(
                theme: t,
                wins: v.winsOf(opp),
                needed: v.winsNeeded,
                color: t.opponent,
                label: '상대',
              ),
              const SizedBox(height: 2),
              Text('상대', style: t.body(size: 11, color: t.subInk)),
            ],
          ),
          const SizedBox(width: 10),
          TurnTimerRing(
            theme: t,
            size: 42,
            deadline: v.playing ? v.deadline : null,
            tickSound: v.isMyTurn,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: BlackjackFelt(
        theme: t,
        child: LayoutBuilder(
          builder: (context, box) {
            const seatH = 50.0;
            const pad = 10.0;
            final w = box.maxWidth;
            final h = box.maxHeight;
            final centerH = math.max(58.0, h * 0.13);
            final handH = math.max(
              40.0,
              (h - pad * 2 - seatH * 2 - centerH) / 2,
            );
            const shoeW = 44.0;
            final shoe = Offset(w - pad - 8 - shoeW / 2, h / 2);
            final oppCenter = Offset(w / 2, pad + seatH + handH / 2);
            final myCenter = Offset(w / 2, h - pad - seatH - handH / 2);
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(pad),
                  child: Column(
                    children: [
                      SizedBox(
                        height: seatH,
                        child: _seat(v, opp, mine: false, score: oppScore),
                      ),
                      SizedBox(
                        height: handH,
                        child: BlackjackHand(
                          theme: t,
                          cards: oppCards,
                          roundKey: key,
                          seat: oppFirst ? 0 : 1,
                          dealFrom: shoe - oppCenter,
                          flipDelay: Duration(
                            milliseconds: oppFirst ? 150 : 520,
                          ),
                          gold: oppScore == 21,
                          bust: v.statuses[opp] == 'bust',
                          semanticsLabel: '상대 카드 ${oppCards.length}장',
                        ),
                      ),
                      SizedBox(
                        height: centerH,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: shoeW),
                            child: BlackjackEmblem(
                              theme: t,
                              caption: _centerCaption(v),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: handH,
                        child: BlackjackHand(
                          theme: t,
                          cards: myCards,
                          roundKey: key,
                          seat: oppFirst ? 1 : 0,
                          dealFrom: shoe - myCenter,
                          markHole: !reveal,
                          gold: myScore == 21,
                          bust: v.statuses[me] == 'bust',
                          semanticsLabel: '내 카드 ${myCards.length}장, 합 $myScore',
                        ),
                      ),
                      SizedBox(
                        height: seatH,
                        child: _seat(v, me, mine: true, score: myScore),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: shoe.dx - shoeW / 2,
                  top: shoe.dy - shoeW * 1.15 / 2,
                  child: const BlackjackShoe(theme: _theme, width: shoeW),
                ),
                Positioned(
                  top: pad + seatH - 6,
                  left: 54,
                  child: ReactionBubble(
                    theme: t,
                    forPlayer: opp,
                    gameType: _gameType,
                  ),
                ),
                Positioned(
                  bottom: pad + seatH - 6,
                  left: 54,
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
      ),
    );
  }

  String _centerCaption(BlackjackView v) {
    if (v.roundOver) return '카드 공개';
    if (v.isMyTurn) return '내 차례';
    return '상대 차례';
  }

  /// 좌석 한 줄: 프로필 + 상태 + 점수.
  Widget _seat(BlackjackView v, String? id, {required bool mine, int? score}) {
    final t = _theme;
    final status = v.statuses[id];
    final natural = v.roundOver && isNaturalBlackjack(v.handOf(id));
    final active = v.playing && v.currentTurn == id;
    String sub;
    if (natural) {
      sub = '블랙잭!';
    } else if (status == 'bust') {
      sub = '버스트!';
    } else if (status == 'stand') {
      sub = '스탠드!';
    } else if (active) {
      sub = mine ? '고르는 중' : '고르는 중…';
    } else if (v.playing) {
      sub = '기다리는 중';
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
    final badge = PlayerBadge(
      theme: t,
      emoji: _c.emojiOf(id),
      name: _name(id, mine: mine),
      subtitle: sub.isEmpty ? null : sub,
      active: active,
      isMe: mine,
      compact: true,
      align: CrossAxisAlignment.start,
    );
    return Row(
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: badge),
        ),
        const SizedBox(width: 8),
        ScorePlaque(
          theme: t,
          value: value,
          caption: caption,
          color: status == 'bust'
              ? const Color(0xFFFF8A80)
              : (mine ? t.me : t.opponent),
          glow: score == 21,
        ),
      ],
    );
  }

  Widget _dock(BlackjackView v) {
    final t = _theme;
    final key = _roundKey(v);
    final showResult = v.showsRoundResult && _panelFor == key;
    final pending = _c.pending;
    final Widget info;
    final Widget actions;
    if (showResult) {
      info = BlackjackRoundHeadline(theme: t, view: v);
      actions = v.finished
          ? GamePrimaryButton(
              theme: t,
              height: 52,
              label: '최종 결과 보기',
              icon: Icons.emoji_events_rounded,
              onPressed: () {
                _overlayTimer?.cancel();
                _overlayTimer = null;
                setState(() => _overlayFor = v.gameId);
              },
            )
          : BlackjackReadyBar(
              theme: t,
              view: v,
              pending: pending,
              onReady: _c.nextRound,
            );
    } else {
      info = Text(
        _statusLine(v),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.body(
          size: 13.5,
          color: v.isMyTurn ? t.gold : t.subInk,
          weight: FontWeight.w800,
        ),
      );
      final canAct = !pending;
      actions = Row(
        children: [
          Expanded(
            child: GamePrimaryButton(
              theme: t,
              height: 56,
              label: '히트',
              icon: Icons.add_rounded,
              onPressed: v.canHit && canAct ? _c.hit : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GameSecondaryButton(
              theme: t,
              height: 56,
              label: '스탠드',
              icon: Icons.front_hand_rounded,
              onPressed: v.canStand && canAct ? _c.stand : null,
            ),
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 46,
            child: Row(
              children: [
                ReactionButton(theme: t, gameType: _gameType),
                const SizedBox(width: 10),
                Expanded(child: info),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(height: 56, child: Center(child: actions)),
        ],
      ),
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
    return GameResultOverlay(
      theme: t,
      outcome: draw
          ? GameOutcome.draw
          : (iWon ? GameOutcome.win : GameOutcome.lose),
      reason: draw
          ? '5라운드를 마쳤는데 승수가 같아요'
          : matchReasonText(v.result?['reason'] as String?, iWon: iWon),
      series: v.series,
      me: v.me,
      details: BlackjackRoundHistory(theme: t, view: v),
      onRematch: () => _sock.requestRestart(_gameType),
      rematchWaiting: _sock.restartWaiting,
      resultId: 'blackjack-${v.gameId}',
    );
  }
}
