import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../core/socket_service.dart';
import '../../../../widgets/game_menu.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'pirate_barrel.dart';
import 'pirate_controller.dart';
import 'pirate_panels.dart';

const _theme = GameTheme.pirateNight;
const kPirateHowToLines = [
  '통에 난 구멍 중 하나에 폭탄이 숨어 있어요.',
  '번갈아 구멍을 하나씩 골라 칼을 꽂아요. 한 차례는 20초!',
  '폭탄 구멍을 찌르면 해적이 하늘로 날아가고, 찌른 사람이 져요.',
];

/// 해적 룰렛 2.0 화면(해적선 야경). 판은 로비 시작 때 서버가 만든다.
class PirateGameScreen extends StatefulWidget {
  /// 테스트에서 컨트롤러 상태를 직접 넣을 때 false.
  final bool syncOnOpen;

  const PirateGameScreen({super.key, this.syncOnOpen = true});

  @override
  State<PirateGameScreen> createState() => _PirateGameScreenState();
}

class _PirateGameScreenState extends State<PirateGameScreen>
    with TickerProviderStateMixin {
  final _c = PirateController.instance;
  final _socket = SocketService();

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  String? _gameId;
  int _stabSerial = 0;
  int _explosionSerial = 0;
  bool _wasMyTurn = false;
  int _lastRisk = 0;

  /// 폭발 연출이 끝나 결과 카드를 보여도 되는지.
  bool _showResult = false;
  bool _awaitingExplosion = false;

  String? _toast;
  int _toastId = 0;

  @override
  void initState() {
    super.initState();
    GameSfx.instance.init(const [
      GameSound.knifeStab,
      GameSound.barrelCreak,
      GameSound.pirateBoom,
      GameSound.pirateFly,
      GameSound.heartbeat,
      GameSound.turnMine,
      GameSound.tick,
      GameSound.select,
      GameSound.confirm,
      GameSound.sparkle,
      GameSound.warn,
      GameSound.win,
      GameSound.lose,
      GameSound.pop,
    ]);
    _stabSerial = _c.stabSerial;
    _explosionSerial = _c.explosionSerial;
    _c.addListener(_onChange);
    _adopt(initial: true);
    if (widget.syncOnOpen) _c.sync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHowToOnce(
        context,
        prefKey: 'how_to_pirate_v2',
        theme: _theme,
        title: '해적 룰렛',
        lines: kPirateHowToLines,
        emoji: '🏴‍☠️',
      );
    });
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _say(String message) {
    _toast = message;
    _toastId++;
  }

  /// 컨트롤러 변화에서 소리·안내·단계 전환을 끌어낸다.
  void _onChange() {
    if (!mounted) return;
    _adopt();
    setState(() {});
  }

  void _adopt({bool initial = false}) {
    final s = _c.state;
    if (s == null) return;
    if (s.gameId != _gameId) {
      _gameId = s.gameId;
      _awaitingExplosion = false;
      // 복원으로 이미 끝난 판에 들어왔으면 바로 결과.
      _showResult = s.exploded;
      _stabSerial = _c.stabSerial;
      _explosionSerial = _c.explosionSerial;
      _lastRisk = s.riskPct;
      _wasMyTurn = _c.isMyTurn;
      if (!initial && _c.isMyTurn) GameSfx.instance.play(GameSound.turnMine);
      return;
    }
    if (_c.stabSerial != _stabSerial) {
      _stabSerial = _c.stabSerial;
      final stab = _c.lastStab;
      if (stab != null && stab.auto) {
        final who = _c.displayName(stab.by);
        _say(
          stab.by == _c.me
              ? '시간이 지나서 대신 ${stab.slot + 1}번 구멍을 찔렀어요'
              : '시간이 지나 $who 대신 ${stab.slot + 1}번 구멍을 찔렀어요',
        );
      }
    }
    if (_c.explosionSerial != _explosionSerial) {
      _explosionSerial = _c.explosionSerial;
      _awaitingExplosion = true;
      _showResult = false;
    }
    if (s.exploded && !_awaitingExplosion) _showResult = true;
    final myTurn = _c.isMyTurn;
    if (myTurn && !_wasMyTurn) GameSfx.instance.play(GameSound.turnMine);
    _wasMyTurn = myTurn;
    if (s.playing &&
        s.riskPct != _lastRisk &&
        s.riskPct >= PirateRiskGauge.highRisk) {
      GameSfx.instance.play(GameSound.heartbeat, volume: 0.9);
    }
    _lastRisk = s.riskPct;
  }

  void _onExplosionStart() {
    _shake.forward(from: 0);
    _flash.forward(from: 0);
  }

  void _onExplosionEnd() {
    final gameId = _c.state?.gameId;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _c.state?.gameId != gameId) return;
      setState(() {
        _awaitingExplosion = false;
        _showResult = true;
      });
    });
  }

  void _help() => showGameHowTo(
    context,
    theme: _theme,
    title: '해적 룰렛',
    lines: kPirateHowToLines,
    emoji: '🏴‍☠️',
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _socket]),
      builder: (context, _) {
        final s = _c.state;
        return Scaffold(
          backgroundColor: _theme.backdrop.last,
          body: GameMenuListener(
            gameType: 'pirate',
            child: GameBackdrop(
              theme: _theme,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) {
                    final t = _shake.value;
                    final dx = _shake.isAnimating
                        ? math.sin(t * math.pi * 12) * (1 - t) * 9
                        : 0.0;
                    final dy = _shake.isAnimating
                        ? math.cos(t * math.pi * 10) * (1 - t) * 5
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: child,
                    );
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          GameTopBar(
                            theme: _theme,
                            title: '해적 룰렛',
                            gameType: 'pirate',
                            canRestart: s?.exploded == true,
                            restartWaiting: _socket.restartWaiting,
                            onRequestRestart: _c.requestRestart,
                            onHelp: _help,
                          ),
                          Expanded(child: s == null ? _preparing() : _board(s)),
                        ],
                      ),
                      if (s != null) ..._overlays(s),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _preparing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GamePanel(
          theme: _theme,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏴‍☠️', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text('판을 준비하는 중…', style: _theme.display(size: 22)),
              const SizedBox(height: 12),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: _theme.gold,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _c.syncing ? null : _c.sync,
                child: Text(
                  '다시 불러오기',
                  style: _theme.body(size: 13, color: _theme.subInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _board(PirateState s) {
    final me = _c.me;
    final opp = _c.opponent;
    final myName = _c.displayName(me);
    final oppName = _c.displayName(opp);
    String sub(String? id) {
      if (s.exploded) return id == s.loser ? '해적 발사!' : '살았다!';
      if (s.currentTurn == id) return '찌르는 차례';
      return '기다리는 중';
    }

    final hint = s.exploded
        ? '${_c.displayName(s.loser)}${josaIGa(_c.displayName(s.loser))} 해적을 날려 보냈어요!'
        : _c.isMyTurn
        ? '구멍을 하나 골라 칼을 꽂아요'
        : '$oppName${josaIGa(oppName)} 구멍을 고르는 중…';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PlayerBadge(
                    theme: _theme,
                    emoji: _c.emojiOf(me),
                    name: myName,
                    subtitle: sub(me),
                    active: s.playing && s.currentTurn == me,
                    isMe: true,
                    compact: true,
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                height: 50,
                child: s.playing
                    ? Center(
                        child: TurnTimerRing(
                          theme: _theme,
                          deadline: s.deadline,
                          size: 46,
                          tickSound: _c.isMyTurn,
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PlayerBadge(
                    theme: _theme,
                    emoji: _c.emojiOf(opp),
                    name: oppName,
                    subtitle: sub(opp),
                    active: s.playing && s.currentTurn == opp,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: s.playing
              ? PirateRiskGauge(
                  theme: _theme,
                  riskPct: s.riskPct,
                  remaining: s.remaining,
                )
              : GameChip(
                  theme: _theme,
                  leading: '💥',
                  label: s.bombSlot == null
                      ? '판이 끝났어요'
                      : '${s.bombSlot! + 1}번 구멍에 폭탄이 있었어요',
                  emphasized: true,
                  color: _theme.accent,
                ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              const hintH = 30.0;
              final byHeight = (box.maxHeight - hintH - 8) / 1.4;
              final width = math
                  .min(math.min(box.maxWidth * 0.86, 340.0), byHeight)
                  .clamp(150.0, 340.0)
                  .toDouble();
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PirateBarrel(
                    width: width,
                    slots: s.slots,
                    pickedSlots: s.pickedSlots,
                    bombSlot: s.bombSlot,
                    riskPct: s.riskPct,
                    exploded: s.exploded,
                    canPick: _c.isMyTurn && !_c.sendingPick,
                    onPick: (slot) {
                      GameSfx.instance.play(GameSound.select, volume: 0.6);
                      _c.pick(slot);
                    },
                    stabSerial: _c.stabSerial,
                    lastStabSlot: _c.lastStab?.slot,
                    explosionSerial: _c.explosionSerial,
                    onExplosionStart: _onExplosionStart,
                    onExplosionEnd: _onExplosionEnd,
                  ),
                  SizedBox(
                    height: hintH,
                    child: Center(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _theme.body(
                          size: 14,
                          color: _c.isMyTurn ? _theme.gold : _theme.ink,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              ReactionButton(theme: _theme, gameType: 'pirate'),
              const Spacer(),
              GameChip(theme: _theme, leading: '🛢️', label: '구멍 ${s.slots}개'),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _overlays(PirateState s) {
    final me = _c.me;
    final loserName = _c.displayName(s.loser);
    return [
      Positioned(
        top: 108,
        left: 16,
        child: ReactionBubble(theme: _theme, forPlayer: me, gameType: 'pirate'),
      ),
      Positioned(
        top: 108,
        right: 16,
        child: ReactionBubble(
          theme: _theme,
          forPlayer: _c.opponent,
          gameType: 'pirate',
        ),
      ),
      Positioned.fill(
        child: GameTurnBanner(
          theme: _theme,
          id: _c.isMyTurn ? '${s.gameId}:${s.seq}' : null,
          text: '내 차례!',
          sub: '구멍 하나를 골라 칼을 꽂아요',
          color: _theme.accent,
        ),
      ),
      Positioned(
        top: 56,
        left: 0,
        right: 0,
        child: GameToast(theme: _theme, id: _toastId, message: _toast),
      ),
      // 폭발 번쩍임(진 사람에게는 붉게)
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _flash,
            builder: (context, _) {
              if (!_flash.isAnimating) return const SizedBox.shrink();
              final a = (1 - _flash.value) * 0.75;
              final color = s.loser == me
                  ? const Color(0xFFFF3B2F)
                  : const Color(0xFFFFE6B0);
              return ColoredBox(color: color.withValues(alpha: a));
            },
          ),
        ),
      ),
      if (s.exploded && _showResult)
        Positioned.fill(
          child: GameResultOverlay(
            theme: _theme,
            outcome: s.winner == me ? GameOutcome.win : GameOutcome.lose,
            title: s.winner == me ? '살았다!' : '해적이 날아갔어요',
            reason: _reason(s, loserName),
            series: s.series,
            me: me,
            resultId: s.gameId,
            onRematch: _c.requestRestart,
            rematchWaiting: _socket.restartWaiting,
          ),
        ),
    ];
  }

  String _reason(PirateState s, String loserName) {
    final ga = josaIGa(loserName);
    return switch (s.reason) {
      'timeout' => '$loserName$ga 세 번 연속 시간을 넘겨 기권했어요',
      'afk' => '$loserName$ga 오래 자리를 비워 기권했어요',
      _ => '$loserName$ga ${(s.bombSlot ?? 0) + 1}번 폭탄 구멍을 찔렀어요',
    };
  }
}
