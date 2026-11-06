import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/game_sfx/game_sfx.dart';
import '../../../../widgets/play_kit/play_kit.dart';

/// 별빛 편지 디자인 토큰(모던 클래식 목업 B안). 색은 [GameTheme.starlight]와 같다.
const Color kTpBg = Color(0xFF0D0F2B);
const Color kTpCard = Color(0xFF171B47);
const Color kTpLine = Color(0x29BEC8FF); // rgba(190,200,255,.16)
const Color kTpInk = Color(0xFFF3F1FF);
const Color kTpSub = Color(0xFFA9ADD6);
const Color kTpGold = Color(0xFFF0CF86);
const Color kTpPeri = Color(0xFF9DB1FF);

/// 19+ 안내에만 쓰는 경고색(그 밖에는 금색 하나만 강조로 쓴다).
const Color kTpWarn = Color(0xFFFF9C8F);

/// 본문·UI: Noto Sans KR.
TextStyle tpSans({
  double size = 14,
  Color color = kTpInk,
  FontWeight weight = FontWeight.w500,
  double? height,
}) => GoogleFonts.notoSansKr(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: -size * 0.01,
);

/// 제목·숫자·문제: Gowun Batang.
TextStyle tpSerif({
  double size = 20,
  Color color = kTpInk,
  FontWeight weight = FontWeight.w700,
  double? height,
}) => GoogleFonts.gowunBatang(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);

/// 구간 [a, b]에서 [v]가 0→1로 변하는 값.
double telepathySpan(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// 이름의 첫 글자(동그라미 안에 쓴다). 이름을 모르면 빈 문자열.
String telepathyInitial(String name) {
  final t = name.trim();
  if (t.isEmpty) return '';
  return String.fromCharCode(t.runes.first);
}

// ── 플레이어 캡슐 ───────────────────────────────────────────────────────────

/// 이니셜 동그라미: 나는 금색, 상대는 새벽 청색 링.
class TelepathyInitialDot extends StatelessWidget {
  final String initial;
  final bool mine;
  final double size;
  final double ring;

  const TelepathyInitialDot({
    super.key,
    required this.initial,
    required this.mine,
    this.size = 36,
    this.ring = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final color = mine ? kTpGold : kTpPeri;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: mine ? const Color(0x24F0CF86) : const Color(0x249DB1FF),
        border: Border.all(color: color, width: ring),
      ),
      child: Text(
        initial,
        style: tpSerif(size: size * 0.42, color: color),
      ),
    );
  }
}

/// 위쪽 플레이어 캡슐(이니셜 + 이름 + 상태). [mine]이 아니면 오른쪽 정렬로 뒤집힌다.
class TelepathyCapsule extends StatelessWidget {
  final String name;
  final String? status;
  final bool statusGold;
  final bool mine;

  const TelepathyCapsule({
    super.key,
    required this.name,
    required this.mine,
    this.status,
    this.statusGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // 좁은 화면(360폭)에서는 동그라미와 여백을 줄여 이름이 잘리지 않게 한다.
        final tight = box.maxWidth < 120;
        final dot = TelepathyInitialDot(
          initial: telepathyInitial(name),
          mine: mine,
          size: tight ? 30 : 36,
        );
        final gap = SizedBox(width: tight ? 6 : 9);
        final texts = Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: mine
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                mine ? '$name (나)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tpSans(size: tight ? 12.5 : 13, weight: FontWeight.w700),
              ),
              SizedBox(
                height: 16,
                child: status == null
                    ? null
                    : Text(
                        status!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tpSans(
                          size: 12,
                          color: statusGold ? kTpGold : kTpSub,
                        ),
                      ),
              ),
            ],
          ),
        );
        final edge = tight ? 6.0 : 8.0;
        final inner = tight ? 10.0 : 12.0;
        return Semantics(
          label: '${mine ? '나' : name}${status == null ? '' : ', $status'}',
          child: ExcludeSemantics(
            child: Container(
              height: 52,
              padding: mine
                  ? EdgeInsets.fromLTRB(edge, 0, inner, 0)
                  : EdgeInsets.fromLTRB(inner, 0, edge, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: kTpLine),
                color: const Color(0x0AFFFFFF),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: mine ? [dot, gap, texts] : [texts, gap, dot],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum TelepathyLinkTone { idle, gold, broken }

/// 두 캡슐 사이의 연결선. 평소엔 점선, 통하면 금빛 실선이 [progress]만큼 그려지고, 엇갈리면 끊어진 점선.
class TelepathyLink extends StatelessWidget {
  final TelepathyLinkTone tone;
  final double progress;
  final bool fromRight;

  const TelepathyLink({
    super.key,
    this.tone = TelepathyLinkTone.idle,
    this.progress = 1,
    this.fromRight = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: CustomPaint(
      painter: _LinkPainter(tone, progress, fromRight),
      size: const Size(double.infinity, 12),
    ),
  );
}

class _LinkPainter extends CustomPainter {
  final TelepathyLinkTone tone;
  final double progress;
  final bool fromRight;

  _LinkPainter(this.tone, this.progress, this.fromRight);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final w = size.width;
    switch (tone) {
      case TelepathyLinkTone.gold:
        final len = w * progress;
        final x0 = fromRight ? w - len : 0.0;
        final r = Rect.fromLTWH(x0, y - 1, len, 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(4)),
          Paint()
            ..color = kTpGold.withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(1)),
          Paint()..color = kTpGold,
        );
      case TelepathyLinkTone.idle:
        _dashes(canvas, w, y, 6, 4, 0.28);
      case TelepathyLinkTone.broken:
        _dashes(canvas, w, y, 1.4, 3, 0.2);
    }
  }

  void _dashes(
    Canvas c,
    double w,
    double y,
    double dash,
    double gap,
    double a,
  ) {
    final p = Paint()
      ..color = const Color(0xFFBEC8FF).withValues(alpha: a)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (double x = 0; x < w; x += dash + gap) {
      c.drawLine(Offset(x, y), Offset(math.min(x + dash, w), y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _LinkPainter old) =>
      old.tone != tone ||
      old.progress != progress ||
      old.fromRight != fromRight;
}

enum TelepathyRingMode { timer, match, miss, idle }

/// 가운데 60px 링: 남은 시간(금색 호 + 숫자) / 통함(금빛 후광 + 별) / 엇갈림(× 표시).
class TelepathyRing extends StatefulWidget {
  final TelepathyRingMode mode;
  final GameDeadline? deadline;
  final bool tickSound;

  const TelepathyRing({
    super.key,
    required this.mode,
    this.deadline,
    this.tickSound = false,
  });

  @override
  State<TelepathyRing> createState() => _TelepathyRingState();
}

class _TelepathyRingState extends State<TelepathyRing> {
  Timer? _timer;
  int _lastSecond = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || widget.mode != TelepathyRingMode.timer) return;
      final d = widget.deadline;
      if (d != null && widget.tickSound) {
        final s = d.remaining().inSeconds;
        if (s != _lastSecond && s <= 5 && s >= 1) {
          GameSfx.instance.play(GameSound.tick);
        }
        _lastSecond = s;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deadline;
    final left = d?.remaining().inMilliseconds ?? 0;
    final total = d?.total.inMilliseconds ?? 1;
    final frac = d == null ? 0.0 : (left / math.max(1, total)).clamp(0.0, 1.0);
    final secs = (left / 1000).ceil();
    final mode = widget.mode;
    final Widget center = switch (mode) {
      TelepathyRingMode.timer => Text(
        d == null ? '' : '$secs',
        style: tpSerif(
          size: 21,
          color: d != null && secs <= 5 ? kTpWarn : kTpInk,
        ),
      ),
      TelepathyRingMode.match => const Icon(
        Icons.star_rounded,
        size: 28,
        color: kTpGold,
      ),
      TelepathyRingMode.miss => const Icon(
        Icons.close_rounded,
        size: 24,
        color: kTpSub,
      ),
      TelepathyRingMode.idle => const SizedBox.shrink(),
    };
    return Semantics(
      label: switch (mode) {
        TelepathyRingMode.timer => d == null ? '시간 제한 없음' : '남은 시간 $secs초',
        TelepathyRingMode.match => '통했어요',
        TelepathyRingMode.miss => '엇갈렸어요',
        TelepathyRingMode.idle => '',
      },
      child: ExcludeSemantics(
        child: SizedBox(
          width: 60,
          height: 60,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: mode == TelepathyRingMode.match
                  ? const RadialGradient(
                      colors: [Color(0x29F0CF86), Color(0x00F0CF86)],
                    )
                  : null,
            ),
            child: CustomPaint(
              painter: _RingPainter(
                frac: mode == TelepathyRingMode.timer ? frac : 1,
                color: mode == TelepathyRingMode.match
                    ? kTpGold
                    : (mode == TelepathyRingMode.miss
                          ? kTpLine
                          : (d != null && secs <= 5 ? kTpWarn : kTpGold)),
                track: mode == TelepathyRingMode.miss
                    ? const Color(0x4DBEC8FF)
                    : const Color(0x24BEC8FF),
                glow: mode == TelepathyRingMode.match,
              ),
              child: Center(child: center),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  final Color track;
  final bool glow;

  _RingPainter({
    required this.frac,
    required this.color,
    required this.track,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = track,
    );
    if (frac <= 0) return;
    if (glow) {
      canvas.drawArc(
        arc,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * frac,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.frac != frac || old.color != color || old.glow != glow;
}

// ── 진행 줄 ─────────────────────────────────────────────────────────────────

/// `5 / 10` · 진행 점 · `★ 3` 한 줄.
class TelepathyProgressRow extends StatelessWidget {
  final int current;
  final int total;

  /// 지난 문제 결과(true 통함 / false 불일치).
  final List<bool> results;
  final int score;

  /// 방금 공개된 문제가 통했을 때 현재 점을 금빛으로 켠다.
  final bool currentHit;

  const TelepathyProgressRow({
    super.key,
    required this.current,
    required this.total,
    required this.results,
    required this.score,
    this.currentHit = false,
  });

  @override
  Widget build(BuildContext context) {
    final cur = current.clamp(1, total);
    return Semantics(
      label: '$total문제 중 $cur번째, 통한 문제 $score개',
      child: ExcludeSemantics(
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  '$cur / $total',
                  style: tpSans(size: 13, weight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < total; i++)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: total > 10 ? 2.6 : 3.5,
                        ),
                        child: _dot(i),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: kTpGold),
                    const SizedBox(width: 3),
                    Text(
                      '$score',
                      style: tpSans(
                        size: 13,
                        color: kTpGold,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int i) {
    final r = i < results.length ? results[i] : null;
    final now = i == cur - 1 && r == null;
    final size = now ? 12.0 : 9.0;
    final hit = r == true || (now && currentHit);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hit
            ? kTpGold
            : r == false
            ? const Color(0x47BEC8FF)
            : Colors.transparent,
        border: Border.all(
          color: now
              ? kTpInk
              : hit
              ? kTpGold
              : r == false
              ? Colors.transparent
              : const Color(0x4DBEC8FF),
          width: now ? 2 : 1.3,
        ),
        boxShadow: now && currentHit
            ? [const BoxShadow(color: Color(0x40F0CF86), spreadRadius: 3)]
            : null,
      ),
    );
  }

  int get cur => current.clamp(1, total);
}

// ── 문제 머리 ───────────────────────────────────────────────────────────────

/// 분야 라벨(+ 19+ 판이면 작은 🔞 19+ 표시).
class TelepathyCategoryChip extends StatelessWidget {
  final String label;
  final bool adultOnly;

  const TelepathyCategoryChip({
    super.key,
    required this.label,
    this.adultOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color color, {String? semantic}) => Semantics(
      label: semantic ?? text,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            text,
            style: tpSans(size: 12, color: color, weight: FontWeight.w700),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(label, kTpPeri),
        if (adultOnly) ...[
          const SizedBox(width: 6),
          chip('🔞 19+', kTpWarn, semantic: '19세 이상 전용'),
        ],
      ],
    );
  }
}

// ── 선택지 카드 ─────────────────────────────────────────────────────────────

enum TelepathyCardState { idle, selected, hit, dim, mine, theirs }

/// 이름 한 글자 표시(누가 이 카드를 골랐나).
class TelepathyMark {
  final String initial;
  final bool mine;
  final String name;

  const TelepathyMark({
    required this.initial,
    required this.mine,
    required this.name,
  });
}

/// 선택지 카드(좌우 배치): 이모지 → A/B 동그라미 → 보기 글자, 아래쪽에 고른 사람 표시.
/// [flip]이 0→1로 가면 세로축으로 한 번 뒤집히며 공개 면으로 바뀐다.
class TelepathyOptionCard extends StatelessWidget {
  final String letter;
  final String emoji;
  final String text;
  final TelepathyCardState cardState;
  final VoidCallback? onTap;
  final double flip;
  final List<TelepathyMark> marks;

  const TelepathyOptionCard({
    super.key,
    required this.letter,
    required this.emoji,
    required this.text,
    this.cardState = TelepathyCardState.idle,
    this.onTap,
    this.flip = 0,
    this.marks = const [],
  });

  static double _textSize(String t) {
    final n = t.runes.length;
    if (n <= 5) return 22;
    if (n <= 9) return 20;
    return 18;
  }

  @override
  Widget build(BuildContext context) {
    final back = flip > 0.5;
    final angle = flip * math.pi;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateY(back ? angle - math.pi : angle);
    return Semantics(
      button: onTap != null,
      selected:
          cardState == TelepathyCardState.selected ||
          cardState == TelepathyCardState.hit,
      excludeSemantics: true,
      label: '선택지 $letter, $text',
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _face(),
        ),
      ),
    );
  }

  Widget _face() {
    final s = cardState;
    final gold =
        s == TelepathyCardState.selected || s == TelepathyCardState.hit;
    final Color border = switch (s) {
      TelepathyCardState.selected || TelepathyCardState.hit => kTpGold,
      TelepathyCardState.mine => const Color(0xB3F0CF86),
      TelepathyCardState.theirs => const Color(0xB39DB1FF),
      _ => kTpLine,
    };
    final Color fill = switch (s) {
      TelepathyCardState.selected => const Color(0xFF1D2152),
      TelepathyCardState.hit => const Color(0xFF1F2254),
      TelepathyCardState.mine ||
      TelepathyCardState.theirs => const Color(0xFF1B1F4F),
      _ => kTpCard,
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: s == TelepathyCardState.dim ? 0.42 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: gold ? 1.5 : 1),
          boxShadow: s == TelepathyCardState.hit
              ? const [
                  BoxShadow(color: Color(0x12F0CF86), spreadRadius: 6),
                  BoxShadow(
                    color: Color(0x1FF0CF86),
                    blurRadius: 40,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 64),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 58, height: 1.1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold ? kTpGold : kTpLine),
                      ),
                      child: Text(
                        letter,
                        style: tpSans(
                          size: 12,
                          color: gold ? kTpGold : kTpSub,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tpSans(
                        size: _textSize(text),
                        weight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (s == TelepathyCardState.selected)
              const Positioned(
                top: 16,
                right: 16,
                child: Icon(Icons.check_rounded, size: 20, color: kTpGold),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: SizedBox(
                height: 34,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < marks.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 22,
                          height: 2,
                          decoration: const BoxDecoration(
                            color: kTpGold,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xCCF0CF86),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      Semantics(
                        label: '${marks[i].name}이(가) 고른 쪽',
                        child: TelepathyInitialDot(
                          initial: marks[i].initial,
                          mine: marks[i].mine,
                          size: 34,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 카드 사이 한가운데의 VS 메달: 평소 `VS`, 통하면 금색 별, 엇갈리면 `≠`.
class TelepathyVsMedallion extends StatelessWidget {
  final bool hit;
  final bool off;

  const TelepathyVsMedallion({super.key, this.hit = false, this.off = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hit ? '통했어요' : (off ? '엇갈렸어요' : '대결'),
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hit ? kTpGold : kTpBg,
            border: Border.all(
              color: hit
                  ? kTpGold
                  : off
                  ? const Color(0x4DBEC8FF)
                  : const Color(0xB3F0CF86),
              width: 1.5,
            ),
            boxShadow: [
              const BoxShadow(color: kTpBg, spreadRadius: 5),
              if (hit)
                const BoxShadow(color: Color(0x80F0CF86), blurRadius: 24),
            ],
          ),
          alignment: Alignment.center,
          child: hit
              ? const Icon(Icons.star_rounded, size: 24, color: kTpBg)
              : Text(
                  off ? '≠' : 'VS',
                  style: tpSerif(
                    size: off ? 20 : 15,
                    color: off ? kTpSub : kTpGold,
                    weight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 공개 뒤 카드 아래의 판정: 제목(세리프) + 한 줄 + (연속 알약).
class TelepathyVerdict extends StatelessWidget {
  final bool matched;
  final String title;
  final String sub;
  final int streak;

  const TelepathyVerdict({
    super.key,
    required this.matched,
    required this.title,
    required this.sub,
    this.streak = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: tpSerif(size: 21, color: matched ? kTpGold : kTpInk),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: tpSans(size: 13, color: kTpSub),
              ),
            ],
          ),
        ),
        if (matched && streak >= 2) ...[
          const SizedBox(width: 14),
          Semantics(
            label: '$streak연속',
            child: ExcludeSemantics(
              child: Container(
                height: 32,
                padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x80F0CF86)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: kTpGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streak연속',
                      style: tpSans(
                        size: 13,
                        color: kTpGold,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 두 개의 겹친 원(+ 가운데 별/점) 문양. 로비 머리와 결과 등급에 쓴다.
class TelepathySigil extends StatelessWidget {
  final double size;

  /// 0(멀리)~1(완전히 겹침).
  final double overlap;
  final bool star;

  const TelepathySigil({
    super.key,
    this.size = 64,
    this.overlap = 0.35,
    this.star = true,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.62,
    child: CustomPaint(painter: _SigilPainter(overlap, star)),
  );
}

class _SigilPainter extends CustomPainter {
  final double overlap;
  final bool star;

  _SigilPainter(this.overlap, this.star);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2 - 1;
    final cy = size.height / 2;
    final gap = (2 * r) * (1 - overlap * 0.75);
    final cx1 = size.width / 2 - gap / 2;
    final cx2 = size.width / 2 + gap / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx1, cy), r, p..color = kTpGold);
    canvas.drawCircle(Offset(cx2, cy), r, p..color = kTpPeri);
    final dot = Paint()..color = kTpGold;
    if (star) {
      final c = Offset(size.width / 2, cy);
      final path = Path();
      for (int i = 0; i < 10; i++) {
        final rr = i.isEven ? r * 0.5 : r * 0.22;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, dot);
    } else {
      canvas.drawCircle(Offset(cx1, cy), r * 0.26, dot);
      canvas.drawCircle(Offset(cx2, cy), r * 0.26, Paint()..color = kTpPeri);
    }
  }

  @override
  bool shouldRepaint(covariant _SigilPainter old) =>
      old.overlap != overlap || old.star != star;
}
