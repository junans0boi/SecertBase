import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';

/// 구간 [a, b]에서 [v]가 0→1로 변하는 값.
double telepathySpan(double v, double a, double b) =>
    ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();

/// A 카드(보라)와 B 카드(호박)의 색. 나/상대 색(하늘·분홍)과 겹치지 않게 고른다.
const Color kTelepathyColorA = Color(0xFFA891FF);
const Color kTelepathyColorB = Color(0xFFFFC27A);

Color telepathyChoiceColor(String choice) =>
    choice == 'A' ? kTelepathyColorA : kTelepathyColorB;

/// 카드 뒷면(공개 후)에 붙는 "누가 골랐나" 표시.
class TelepathyMark {
  final String emoji;
  final bool mine;
  final String name;

  const TelepathyMark({
    required this.emoji,
    required this.mine,
    required this.name,
  });
}

enum TelepathyCardMode { idle, picked, dimmed }

/// 선택지 카드 한 장. [flip]이 0→1로 가면 가로 축으로 뒤집혀 공개 면(누가 골랐나)이 보인다.
class TelepathyCard extends StatelessWidget {
  final GameTheme theme;
  final String letter;
  final String emoji;
  final String text;
  final TelepathyCardMode mode;
  final VoidCallback? onTap;
  final double flip;
  final List<TelepathyMark> marks;

  /// 공개 면에서 두 사람이 이 카드를 함께 골랐다(금빛으로 빛난다).
  final bool glow;

  /// 공개 면에서 아무도 고르지 않은 카드는 흐리게.
  final bool faded;

  /// 카드의 최소 높이(남는 화면 높이에 맞춰 키운다).
  final double minHeight;

  const TelepathyCard({
    super.key,
    required this.theme,
    required this.letter,
    required this.emoji,
    required this.text,
    this.mode = TelepathyCardMode.idle,
    this.onTap,
    this.flip = 0,
    this.marks = const [],
    this.glow = false,
    this.faded = false,
    this.minHeight = 88,
  });

  @override
  Widget build(BuildContext context) {
    final back = flip > 0.5;
    final angle = flip * math.pi;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(back ? angle - math.pi : angle);
    final lift = math.sin(flip * math.pi) * 6;
    return Semantics(
      button: onTap != null,
      selected: mode == TelepathyCardMode.picked,
      excludeSemantics: true,
      label: '선택지 $letter, $text',
      child: Transform.translate(
        offset: Offset(0, -lift),
        child: Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: _face(back),
          ),
        ),
      ),
    );
  }

  Widget _face(bool back) {
    final t = theme;
    final tint = telepathyChoiceColor(letter);
    final picked = mode == TelepathyCardMode.picked;
    final dimmed = mode == TelepathyCardMode.dimmed;
    final lit = back ? glow : picked;
    final borderColor = lit ? t.gold : tint.withValues(alpha: 0.55);
    final base = Color.alphaBlend(tint.withValues(alpha: 0.16), t.surface);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: back ? (faded ? 0.5 : 1) : (dimmed ? 0.55 : 1),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: picked && !back ? 1.025 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.white, 0.1)!,
                Color.lerp(base, Colors.black, 0.18)!,
              ],
            ),
            border: Border.all(color: borderColor, width: lit ? 2.2 : 1.4),
            boxShadow: [
              BoxShadow(
                color: (lit ? t.gold : tint).withValues(
                  alpha: lit ? 0.5 : 0.22,
                ),
                blurRadius: lit ? 26 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: tint.withValues(alpha: 0.5)),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 38)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        letter,
                        style: t.body(
                          size: 11.5,
                          color: tint,
                          weight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.display(size: 23).copyWith(height: 1.18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _trailing(back, picked),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(bool back, bool picked) {
    final t = theme;
    if (back) {
      if (marks.isEmpty) return const SizedBox(width: 4);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in marks)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Semantics(
                label: '${m.name}이(가) 고른 쪽',
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF14123E),
                    border: Border.all(
                      color: m.mine ? t.me : t.opponent,
                      width: 2.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (m.mine ? t.me : t.opponent).withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(m.emoji, style: const TextStyle(fontSize: 21)),
                ),
              ),
            ),
        ],
      );
    }
    if (picked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: t.gold, size: 26),
          const SizedBox(height: 2),
          Text('내 선택', style: t.body(size: 11, color: t.gold)),
        ],
      );
    }
    return Icon(
      Icons.touch_app_rounded,
      color: t.subInk.withValues(alpha: 0.5),
      size: 22,
    );
  }
}

/// 두 카드 사이의 VS 메달.
class TelepathyVsMedallion extends StatelessWidget {
  final GameTheme theme;
  final String? label;
  final bool lit;
  final double pulse;

  const TelepathyVsMedallion({
    super.key,
    required this.theme,
    this.label,
    this.lit = false,
    this.pulse = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final glowAlpha = lit ? 0.75 : 0.28 + pulse * 0.18;
    return Semantics(
      label: label == null ? '대결' : '결과',
      child: Container(
        width: 58,
        height: 58,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: t.goldGradient,
          boxShadow: [
            BoxShadow(
              color: t.gold.withValues(alpha: glowAlpha),
              blurRadius: lit ? 30 : 16,
              spreadRadius: lit ? 4 : 0,
            ),
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF312C86), Color(0xFF0E0D33)],
            ),
          ),
          child: label != null
              ? Text(label!, style: const TextStyle(fontSize: 26))
              : Text('VS', style: t.display(size: 21, color: t.gold)),
        ),
      ),
    );
  }
}

/// 위쪽 아바타 한 명(프로필 이모지 + 이름 + 상태).
class TelepathyAvatar extends StatelessWidget {
  final GameTheme theme;
  final String emoji;
  final String name;
  final String? status;
  final bool mine;
  final bool glowing;

  const TelepathyAvatar({
    super.key,
    required this.theme,
    required this.emoji,
    required this.name,
    required this.mine,
    this.status,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final ring = mine ? t.me : t.opponent;
    return Semantics(
      label: '$name${status == null ? '' : ', $status'}',
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: glowing ? t.goldGradient : null,
                color: glowing ? null : ring.withValues(alpha: 0.65),
                boxShadow: [
                  BoxShadow(
                    color: (glowing ? t.gold : ring).withValues(
                      alpha: glowing ? 0.7 : 0.3,
                    ),
                    blurRadius: glowing ? 18 : 10,
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF16143F),
                ),
                child: Text(
                  emoji.isEmpty ? '🙂' : emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              mine ? '$name (나)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.body(size: 12, weight: FontWeight.w800),
            ),
            SizedBox(
              height: 15,
              child: status == null
                  ? null
                  : Text(
                      status!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body(
                        size: 11,
                        color: glowing ? t.gold : t.subInk,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 두 아바타 사이의 끈. 평소엔 희미한 별가루 점선, 통했을 때는 양쪽에서 빛줄기가 뻗어 가운데서 만난다.
class TelepathyBeamPainter extends CustomPainter {
  final GameTheme theme;

  /// 0→1: 빛줄기가 양쪽에서 가운데로 뻗는 정도.
  final double beam;

  /// 가운데 아래로 떨어지는 반짝임(0→1).
  final double shimmer;

  TelepathyBeamPainter({
    required this.theme,
    required this.beam,
    required this.shimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = 24.0;
    final w = size.width;
    final dot = Paint()..color = theme.subInk.withValues(alpha: 0.28);
    for (double x = 6; x < w - 4; x += 9) {
      canvas.drawCircle(Offset(x, y), 1.4, dot);
    }
    if (beam <= 0) return;
    final reach = w / 2 * beam;
    final left = Rect.fromLTRB(0, y - 3, reach, y + 3);
    final right = Rect.fromLTRB(w - reach, y - 3, w, y + 3);
    void line(Rect r, Color from, Color to, bool rtl) {
      final shader = LinearGradient(
        colors: rtl ? [to, from] : [from, to],
      ).createShader(r);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.inflate(5), const Radius.circular(8)),
        Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = Colors.white.withValues(alpha: 0.7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..shader = shader,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(r.left, y - 0.9, r.right, y + 0.9),
          const Radius.circular(1),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
    }

    line(left, theme.me, theme.gold, false);
    line(right, theme.opponent, theme.gold, true);
    // 빛줄기를 따라 흐르는 반짝이.
    final spark = Paint()..color = Colors.white;
    final rnd = math.Random(5);
    for (int i = 0; i < 14; i++) {
      final f = (rnd.nextDouble() + shimmer) % 1.0;
      final dx = f * reach;
      final dy = (rnd.nextDouble() - 0.5) * 16;
      final r = 0.8 + rnd.nextDouble() * 1.3;
      canvas.drawCircle(Offset(dx, y + dy), r, spark);
      canvas.drawCircle(Offset(w - dx, y + dy), r, spark);
    }
    if (beam >= 1) {
      canvas.drawCircle(
        Offset(w / 2, y),
        16 + shimmer * 6,
        Paint()
          ..color = theme.gold.withValues(alpha: 0.35 * (1 - shimmer))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TelepathyBeamPainter old) =>
      old.beam != beam || old.shimmer != shimmer || old.theme.id != theme.id;
}

/// 진행 점: 통한 문제는 별, 엇갈린 문제는 흐린 점, 지금 문제는 테두리.
class TelepathyProgressDots extends StatelessWidget {
  final GameTheme theme;
  final int total;
  final int current;
  final List<bool?> results; // 지난 문제 결과(true 통함 / false 불일치)

  const TelepathyProgressDots({
    super.key,
    required this.theme,
    required this.total,
    required this.current,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final done = results.where((r) => r != null).length;
    return Semantics(
      label: '$total문제 중 ${current.clamp(1, total)}번째, $done문제 지남',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < total; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: total > 10 ? 2.5 : 3.5),
              child: _dot(t, i),
            ),
        ],
      ),
    );
  }

  Widget _dot(GameTheme t, int i) {
    final r = i < results.length ? results[i] : null;
    final now = i == current - 1 && r == null;
    final size = now ? 12.0 : 9.0;
    if (r == true) {
      return SizedBox(
        width: 12,
        height: 12,
        child: Icon(Icons.star_rounded, size: 14, color: t.gold),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: r == false
            ? t.subInk.withValues(alpha: 0.35)
            : now
            ? t.accent.withValues(alpha: 0.9)
            : Colors.transparent,
        border: Border.all(
          color: r == false
              ? Colors.transparent
              : (now ? t.accent : t.subInk.withValues(alpha: 0.45)),
          width: 1.3,
        ),
        boxShadow: now
            ? [BoxShadow(color: t.accent.withValues(alpha: 0.6), blurRadius: 8)]
            : null,
      ),
    );
  }
}
