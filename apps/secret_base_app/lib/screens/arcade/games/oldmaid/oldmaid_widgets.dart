import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../widgets/play_kit/play_kit.dart';
import 'oldmaid_controller.dart';

/// 동화책 티파티 카드 뒷면(버건디 + 금박).
const kOldMaidBack = CardBackStyle.burgundy;

/// 연출 카드를 그리는 기준 폭(FittedBox로 실제 크기에 맞춘다).
const double kFxBaseWidth = 96;

/// 조커를 쥔 카드의 붉은 테두리 색.
const kJokerRed = Color(0xFFD23A4E);

/// 앞면/뒷면을 [flip](0=뒷면, 1=앞면) 진행도로 뒤집어 보여 주는 카드.
class OldMaidFlipCard extends StatelessWidget {
  final OldMaidCard? card;
  final double width;
  final double flip;
  final bool highlight;
  final Color highlightColor;
  final String? badge;

  const OldMaidFlipCard({
    super.key,
    required this.card,
    required this.width,
    required this.flip,
    this.highlight = false,
    this.highlightColor = const Color(0xFFFFD36E),
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final f = flip.clamp(0.0, 1.0);
    final showFace = card != null && f >= 0.5;
    final scaleX = math.max(0.02, (math.cos(f * math.pi)).abs());
    // 공용 카드는 폭이 바뀌면 크기를 천천히 따라가므로(AnimatedContainer), 날아가는 카드는
    // 고정 폭으로 그린 뒤 FittedBox로 늘리고 줄인다. 그래야 연출 위치와 정확히 겹친다.
    return SizedBox(
      width: width,
      height: width * 92 / 64,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(scaleX, 1, 1),
        child: FittedBox(
          fit: BoxFit.fill,
          child: PlayingCard(
            suit: showFace ? card!.suit : null,
            rank: showFace ? card!.rank : null,
            faceUp: showFace,
            width: kFxBaseWidth,
            back: kOldMaidBack,
            highlight: highlight,
            highlightColor: highlightColor,
            badge: showFace ? badge : null,
          ),
        ),
      ),
    );
  }
}

/// 버린 짝 더미: 맨 위 몇 쌍을 비스듬히 겹쳐 보여 주고 "N쌍"을 단다.
class OldMaidDiscardPile extends StatelessWidget {
  final GameTheme theme;
  final List<String> discards;
  final double cardW;
  final bool glow;

  const OldMaidDiscardPile({
    super.key,
    required this.theme,
    required this.discards,
    required this.cardW,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final n = discards.length;
    final shown = discards.length > 3
        ? discards.sublist(discards.length - 3)
        : discards;
    final h = cardW * 92 / 64;
    return Semantics(
      label: '버린 짝 $n쌍',
      child: SizedBox(
        width: cardW + 14,
        height: h + 30,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // 빈 자리: 레이스 받침 접시.
            Positioned(
              top: h * 0.08,
              child: Container(
                width: cardW + 10,
                height: h * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardW * 0.14),
                  border: Border.all(
                    color: t.gold.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  color: t.accentSoft,
                ),
              ),
            ),
            for (var i = 0; i < shown.length; i++)
              Positioned(
                top: 2.0 + i * 1.5,
                child: Transform.rotate(
                  angle: _tilt(n - shown.length + i),
                  child: PlayingCard(
                    rank: shown[i],
                    suit: _suitFor(n - shown.length + i),
                    width: cardW,
                    highlight: glow && i == shown.length - 1,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: t.gold.withValues(alpha: 0.7)),
                ),
                child: Text(
                  '$n쌍',
                  style: t.body(
                    size: 12,
                    color: t.accent,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 더미 카드는 랭크만 공개된다. 무늬는 보기 좋게 번갈아 그린다.
  static String _suitFor(int i) => const ['♥', '♠', '♦', '♣'][i % 4];
  static double _tilt(int i) => ((i * 37) % 11 - 5) * 0.035;
}

/// 가운데 오른쪽 장식: 김이 오르는 찻잔(동화책 티파티).
class OldMaidTeacup extends StatefulWidget {
  final GameTheme theme;
  final double size;

  const OldMaidTeacup({super.key, required this.theme, this.size = 64});

  @override
  State<OldMaidTeacup> createState() => _OldMaidTeacupState();
}

class _OldMaidTeacupState extends State<OldMaidTeacup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _TeacupPainter(widget.theme, _c.value),
          ),
        ),
      ),
    );
  }
}

class _TeacupPainter extends CustomPainter {
  final GameTheme theme;
  final double t;

  _TeacupPainter(this.theme, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 받침 접시.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.86),
        width: w * 0.9,
        height: h * 0.16,
      ),
      Paint()..color = theme.surface,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.86),
        width: w * 0.9,
        height: h * 0.16,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = theme.gold,
    );
    // 잔.
    final cup = Path()
      ..moveTo(w * 0.2, h * 0.46)
      ..lineTo(w * 0.8, h * 0.46)
      ..quadraticBezierTo(w * 0.78, h * 0.82, w * 0.5, h * 0.83)
      ..quadraticBezierTo(w * 0.22, h * 0.82, w * 0.2, h * 0.46)
      ..close();
    canvas.drawPath(
      cup,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, theme.surface, const Color(0xFFEDE3F7)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = theme.accent.withValues(alpha: 0.7),
    );
    // 금 테.
    canvas.drawLine(
      Offset(w * 0.21, h * 0.5),
      Offset(w * 0.79, h * 0.5),
      Paint()
        ..strokeWidth = 1.6
        ..color = theme.gold,
    );
    // 손잡이.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.83, h * 0.6),
        width: w * 0.18,
        height: h * 0.2,
      ),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = theme.accent.withValues(alpha: 0.7),
    );
    // 하트 무늬.
    canvas.drawPath(
      suitPath(
        Suit.heart,
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.64),
          width: w * 0.16,
          height: w * 0.16,
        ),
      ),
      Paint()..color = theme.accent.withValues(alpha: 0.75),
    );
    // 김: 위로 흘러가는 라일락 곡선 세 줄.
    for (var k = 0; k < 3; k++) {
      final phase = (t + k / 3) % 1.0;
      final x0 = w * (0.36 + k * 0.14);
      final path = Path()..moveTo(x0, h * 0.42);
      for (var s = 1; s <= 8; s++) {
        final y = h * 0.42 - s * h * 0.045;
        final x = x0 + math.sin(phase * math.pi * 2 + s * 0.9) * w * 0.035;
        path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(
            0xFF9D83FF,
          ).withValues(alpha: 0.45 * (1 - (phase - 0.5).abs())),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TeacupPainter old) => old.t != t;
}

/// 조커를 뽑았을 때 카드 둘레로 번지는 잉크.
class InkBleedPainter extends CustomPainter {
  final double progress;
  final Color color;

  InkBleedPainter({
    required this.progress,
    this.color = const Color(0xFF4A1028),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = size.center(Offset.zero);
    final base = size.shortestSide * 0.5;
    final rnd = math.Random(5);
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final fade = progress > 0.8 ? (1 - (progress - 0.8) / 0.2) : 1.0;
    for (var i = 0; i < 9; i++) {
      final ang = rnd.nextDouble() * math.pi * 2;
      final dist = base * (0.25 + rnd.nextDouble() * 0.65) * eased;
      final r = base * (0.18 + rnd.nextDouble() * 0.28) * eased;
      final center = c + Offset(math.cos(ang), math.sin(ang)) * dist;
      final path = Path();
      for (var s = 0; s <= 24; s++) {
        final a = s / 24 * math.pi * 2;
        final wobble = 1 + 0.18 * math.sin(a * 5 + i);
        final p = center + Offset(math.cos(a), math.sin(a)) * r * wobble;
        if (s == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.22 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant InkBleedPainter old) => old.progress != progress;
}

/// 조커 얼굴 위에 덧그리는 능청스러운 웃음(눈웃음 + 입꼬리 + 볼터치).
class JokerGrinPainter extends CustomPainter {
  final double progress;

  JokerGrinPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    final k = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    final face = Offset(w / 2, h * 0.58);
    // 얼굴을 덮어 원래 표정을 지운다.
    canvas.drawCircle(face, w * 0.2, Paint()..color = const Color(0xFFFFE9D6));
    final ink = Paint()
      ..color = kCardBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.03)
      ..strokeCap = StrokeCap.round;
    // 눈웃음 ^ ^
    for (final dx in [-0.075, 0.075]) {
      final e = Offset(face.dx + w * dx, face.dy - h * 0.03);
      canvas.drawArc(
        Rect.fromCenter(center: e, width: w * 0.07, height: h * 0.04 * k),
        math.pi,
        math.pi,
        false,
        ink,
      );
    }
    // 입꼬리가 올라간 큰 웃음.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(face.dx, face.dy + h * 0.02),
        width: w * (0.14 + 0.12 * k),
        height: h * (0.04 + 0.07 * k),
      ),
      0.15,
      math.pi - 0.3,
      false,
      ink,
    );
    // 볼터치.
    for (final dx in [-0.13, 0.13]) {
      canvas.drawCircle(
        Offset(face.dx + w * dx, face.dy + h * 0.02),
        w * 0.035,
        Paint()..color = kJokerRed.withValues(alpha: 0.35 * k),
      );
    }
  }

  @override
  bool shouldRepaint(covariant JokerGrinPainter old) =>
      old.progress != progress;
}

/// 짝이 맞았을 때 터지는 반짝이(네 갈래 별).
class SparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  SparklePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = 1 - progress;
    for (var i = 0; i < 12; i++) {
      final ang = i / 12 * math.pi * 2 + 0.3;
      final dist = size.shortestSide * 0.2 + size.shortestSide * 0.42 * eased;
      final p = c + Offset(math.cos(ang), math.sin(ang)) * dist;
      final r = (i.isEven ? 7.0 : 4.5) * (0.6 + 0.6 * fade);
      final star = Path()
        ..moveTo(p.dx, p.dy - r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r)
        ..close();
      canvas.drawPath(
        star,
        Paint()
          ..color = (i % 3 == 0 ? Colors.white : color).withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SparklePainter old) => old.progress != progress;
}
