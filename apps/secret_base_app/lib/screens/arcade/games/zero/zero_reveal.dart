import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';
import 'zero_hand.dart';
import 'zero_models.dart';

/// 공개 연출 한 번의 길이. 서버는 6초 동안 다음 라운드 시간을 세지 않는다.
const Duration kZeroRevealDuration = Duration(milliseconds: 5400);

/// 공개 연출 구간(0~1).
class ZeroRevealTimeline {
  ZeroRevealTimeline._();
  static const chantEnd = 0.24;
  static const focusStart = 0.2;
  static const focusEnd = 0.34;
  static const handsStart = 0.26;
  static const countStart = 0.32;
  static const countEnd = 0.5;
  static const equation = 0.5;
  static const verdict = 0.6;
  static const points = 0.64;

  static double span(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);
}

/// 판정 한 줄(01-grilling Q31).
String zeroVerdict(
  ZeroRound r,
  String? me,
  String? opponent,
  String Function(String?) name,
) {
  if (r.bothExact) return '둘 다 정확히 적중! 각각 +2';
  for (final id in [me, opponent]) {
    if (r.exact[id] == true) return '${name(id)} 정확히 적중! +2';
  }
  if (r.isDraw) return '둘 다 같은 거리 · 이번엔 무득점';
  final winner = r.roundWinner;
  final d = r.distance[winner] ?? 0;
  return '둘 다 빗나갔어요 · ${name(winner)}, $d 차이로 더 가까워요 +1';
}

/// "하나~ 둘~ 셋!" → 조명이 좁혀짐 → 두 손이 올라와 손가락이 하나씩 펴짐 →
/// "3 + 2 = 5" → 판정 한 줄과 점수.
class ZeroRevealStage extends StatefulWidget {
  final GameTheme theme;
  final ZeroRound round;
  final String? me;
  final String? opponent;
  final String Function(String?) nameOf;
  final Animation<double> progress;

  const ZeroRevealStage({
    super.key,
    required this.theme,
    required this.round,
    required this.me,
    required this.opponent,
    required this.nameOf,
    required this.progress,
  });

  @override
  State<ZeroRevealStage> createState() => _ZeroRevealStageState();
}

class _ZeroRevealStageState extends State<ZeroRevealStage> {
  final Set<String> _played = {};
  int _lastCount = -1;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_sounds);
    _sounds();
  }

  @override
  void didUpdateWidget(covariant ZeroRevealStage old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      old.progress.removeListener(_sounds);
      widget.progress.addListener(_sounds);
    }
    if (old.round.round != widget.round.round) {
      _played.clear();
      _lastCount = -1;
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_sounds);
    super.dispose();
  }

  void _once(String key, double at, GameSound sound) {
    if (widget.progress.value >= at && _played.add(key)) {
      GameSfx.instance.play(sound);
    }
  }

  void _sounds() {
    final r = widget.round;
    _once('drum', 0, GameSound.drumroll);
    _once('whoosh', ZeroRevealTimeline.focusStart, GameSound.whoosh);
    final c = ZeroRevealTimeline.span(
      widget.progress.value,
      ZeroRevealTimeline.countStart,
      ZeroRevealTimeline.countEnd,
    );
    final most = math.max(
      r.fingers[widget.me] ?? 0,
      r.fingers[widget.opponent] ?? 0,
    );
    final count = math.min((c * kZeroMaxFingers).floor(), most);
    if (c > 0 && count != _lastCount) {
      _lastCount = count;
      GameSfx.instance.play(GameSound.tap, volume: 0.6);
    }
    _once('reveal', ZeroRevealTimeline.equation, GameSound.reveal);
    _once(
      'points',
      ZeroRevealTimeline.points,
      r.anyExact
          ? GameSound.sparkle
          : r.isDraw
          ? GameSound.pop
          : GameSound.confirm,
    );
  }

  /// 두 손이 같은 박자로 손가락을 하나씩 편다(틱 소리 한 번 = 손가락 하나).
  static double _extended(int fingers, double count) =>
      math.min(fingers.toDouble(), count * kZeroMaxFingers);

  /// 마지막 손가락이 펴지는 순간 손이 한 번 통 튄다(0~1).
  static double _bounce(double v, int fingers) {
    final at =
        ZeroRevealTimeline.countStart +
        (ZeroRevealTimeline.countEnd - ZeroRevealTimeline.countStart) *
            fingers /
            kZeroMaxFingers;
    return ZeroRevealTimeline.span(v, at, at + 0.07);
  }

  /// 점수를 얻은 손에만 반짝임이 지나간다.
  static double _sparkle(double v, int points) => points <= 0
      ? 0
      : ZeroRevealTimeline.span(
          v,
          ZeroRevealTimeline.points,
          ZeroRevealTimeline.points + 0.16,
        );

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final r = widget.round;
    final me = widget.me;
    final opp = widget.opponent;
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) {
        final v = widget.progress.value;
        final rise = Curves.easeOutCubic.transform(
          ZeroRevealTimeline.span(v, ZeroRevealTimeline.handsStart, 0.36),
        );
        final count = ZeroRevealTimeline.span(
          v,
          ZeroRevealTimeline.countStart,
          ZeroRevealTimeline.countEnd,
        );
        final eq = Curves.easeOutBack.transform(
          ZeroRevealTimeline.span(v, ZeroRevealTimeline.equation, 0.58),
        );
        final verdict = ZeroRevealTimeline.span(
          v,
          ZeroRevealTimeline.verdict,
          0.7,
        );
        final pts = Curves.elasticOut.transform(
          ZeroRevealTimeline.span(v, ZeroRevealTimeline.points, 0.76),
        );
        final myF = r.fingers[me] ?? 0;
        final opF = r.fingers[opp] ?? 0;

        return Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Center(
                    child: v < ZeroRevealTimeline.equation
                        ? _Chant(theme: t, v: v)
                        : Opacity(
                            opacity: eq.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.7 + 0.3 * eq,
                              child: _Equation(
                                theme: t,
                                a: myF,
                                b: opF,
                                total: r.total,
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Opacity(
                    opacity: rise,
                    child: FractionalTranslation(
                      translation: Offset(0, (1 - rise) * 0.35),
                      child: Row(
                        children: [
                          Expanded(
                            child: _RevealHand(
                              theme: t,
                              name: widget.nameOf(me),
                              color: t.me,
                              fingers: _extended(myF, count),
                              shownCount: _extended(myF, count).floor(),
                              bounce: _bounce(v, myF),
                              sparkle: _sparkle(v, r.points[me] ?? 0),
                              guess: r.guesses[me] ?? 0,
                              exact: r.exact[me] == true,
                              distance: r.distance[me] ?? 0,
                              points: r.points[me] ?? 0,
                              auto: r.auto[me] == true,
                              pointsAnim: pts,
                              showGuess: verdict > 0,
                              mirrored: false,
                            ),
                          ),
                          Expanded(
                            child: _RevealHand(
                              theme: t,
                              name: widget.nameOf(opp),
                              color: t.opponent,
                              fingers: _extended(opF, count),
                              shownCount: _extended(opF, count).floor(),
                              bounce: _bounce(v, opF),
                              sparkle: _sparkle(v, r.points[opp] ?? 0),
                              guess: r.guesses[opp] ?? 0,
                              exact: r.exact[opp] == true,
                              distance: r.distance[opp] ?? 0,
                              points: r.points[opp] ?? 0,
                              auto: r.auto[opp] == true,
                              pointsAnim: pts,
                              showGuess: verdict > 0,
                              mirrored: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 54,
                  child: Opacity(
                    opacity: verdict,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GamePanel(
                        theme: t,
                        radius: 16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        glow: r.anyExact ? t.gold : null,
                        child: Center(
                          child: Text(
                            zeroVerdict(r, me, opp, widget.nameOf),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.body(size: 14, weight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Chant extends StatelessWidget {
  final GameTheme theme;
  final double v;

  const _Chant({required this.theme, required this.v});

  @override
  Widget build(BuildContext context) {
    // 한 번에 한 글자만 그린다(글자 겹침 없음). 단계마다 살짝 튀어나온다.
    const words = ['하나~', '둘~', '셋!'];
    final step = (v / (ZeroRevealTimeline.chantEnd / 3)).floor().clamp(0, 2);
    final local =
        (v - step * ZeroRevealTimeline.chantEnd / 3) /
        (ZeroRevealTimeline.chantEnd / 3);
    final pop = 1 + 0.25 * math.max(0.0, 1 - local.clamp(0.0, 1.0) * 3);
    return Transform.scale(
      scale: pop,
      child: Text(
        words[step],
        key: ValueKey('zero-chant-$step'),
        style: theme.display(size: 34, color: theme.gold),
      ),
    );
  }
}

class _Equation extends StatelessWidget {
  final GameTheme theme;
  final int a;
  final int b;
  final int total;

  const _Equation({
    required this.theme,
    required this.a,
    required this.b,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final shadow = [
      Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
    ];
    TextStyle s(Color c) =>
        t.display(size: 40, color: c).copyWith(shadows: shadow);
    return Semantics(
      label: '$a 더하기 $b는 $total',
      child: FittedBox(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$a', style: s(t.me)),
              TextSpan(text: ' + ', style: s(t.ink)),
              TextSpan(text: '$b', style: s(t.opponent)),
              TextSpan(text: ' = ', style: s(t.ink)),
              TextSpan(text: '$total', style: s(t.gold)),
            ],
          ),
          key: const ValueKey('zero-equation'),
        ),
      ),
    );
  }
}

class _RevealHand extends StatelessWidget {
  final GameTheme theme;
  final String name;
  final Color color;
  final double fingers;
  final int shownCount;
  final int guess;
  final bool exact;
  final int distance;
  final int points;
  final bool auto;
  final double pointsAnim;
  final bool showGuess;
  final bool mirrored;
  final double bounce;
  final double sparkle;

  const _RevealHand({
    required this.theme,
    required this.name,
    required this.color,
    required this.fingers,
    required this.shownCount,
    required this.guess,
    required this.exact,
    required this.distance,
    required this.points,
    required this.auto,
    required this.pointsAnim,
    required this.showGuess,
    required this.mirrored,
    required this.bounce,
    required this.sparkle,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // 살짝 눌렸다가(가로로 퍼짐) 튀어 오르는 작은 바운스.
    final b = math.sin(math.pi * bounce);
    final squash = bounce < 0.35 ? b * 0.06 : -b * 0.04;
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.body(size: 13, color: color, weight: FontWeight.w800),
        ),
        Expanded(
          child: FittedBox(
            child: SizedBox(
              width: 150,
              height: 176,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 15,
                    top: 22,
                    child: Transform.translate(
                      offset: Offset(0, -10 * b),
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(
                          1 + squash,
                          1 - squash,
                          1,
                        ),
                        child: ZeroHand(
                          fingers: fingers,
                          trim: color,
                          mirrored: mirrored,
                          size: 140,
                          sparkle: sparkle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Text(
                      textAlign: TextAlign.center,
                      '$shownCount',
                      style: t
                          .display(size: 30, color: Colors.white)
                          .copyWith(
                            shadows: [
                              Shadow(color: color, blurRadius: 12),
                              const Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                    ),
                  ),
                  if (points > 0 && pointsAnim > 0)
                    Positioned(
                      top: 0,
                      right: mirrored ? 0 : null,
                      left: mirrored ? null : 0,
                      child: Transform.scale(
                        scale: pointsAnim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: t.goldGradient,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: t.gold.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Text(
                            '+$points',
                            style: t.display(
                              size: 18,
                              color: const Color(0xFF3A1240),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: showGuess ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            exact
                ? '예측 $guess · 정확!'
                : '예측 $guess · $distance 차이${auto ? ' (자동)' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.body(
              size: 12.5,
              color: exact ? t.gold : t.subInk,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
