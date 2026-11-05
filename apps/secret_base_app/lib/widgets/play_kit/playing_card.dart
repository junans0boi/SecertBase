import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 트럼프 무늬. 서버는 '♠♥♦♣' 글자를 쓰지만 화면은 글꼴과 무관하게 `Path`로 그린다.
enum Suit { spade, heart, diamond, club }

Suit? suitFrom(String? raw) => switch (raw) {
  '♠' || 'S' || 's' || 'spade' || 'spades' => Suit.spade,
  '♥' || 'H' || 'h' || 'heart' || 'hearts' => Suit.heart,
  '♦' || 'D' || 'd' || 'diamond' || 'diamonds' => Suit.diamond,
  '♣' || 'C' || 'c' || 'club' || 'clubs' => Suit.club,
  _ => null,
};

bool isRedSuit(Suit s) => s == Suit.heart || s == Suit.diamond;

/// 무늬 경로(1×1 상자 기준). [size]로 늘려 쓴다.
Path suitPath(Suit suit, Rect box) {
  final p = Path();
  final x = box.left, y = box.top, w = box.width, h = box.height;
  Offset o(double fx, double fy) => Offset(x + fx * w, y + fy * h);
  switch (suit) {
    case Suit.heart:
      p.moveTo(o(0.5, 0.95).dx, o(0.5, 0.95).dy);
      p.cubicTo(
        o(0.1, 0.62).dx,
        o(0.1, 0.62).dy,
        o(-0.08, 0.28).dx,
        o(-0.08, 0.28).dy,
        o(0.24, 0.1).dx,
        o(0.24, 0.1).dy,
      );
      p.cubicTo(
        o(0.38, 0.03).dx,
        o(0.38, 0.03).dy,
        o(0.48, 0.12).dx,
        o(0.48, 0.12).dy,
        o(0.5, 0.24).dx,
        o(0.5, 0.24).dy,
      );
      p.cubicTo(
        o(0.52, 0.12).dx,
        o(0.52, 0.12).dy,
        o(0.62, 0.03).dx,
        o(0.62, 0.03).dy,
        o(0.76, 0.1).dx,
        o(0.76, 0.1).dy,
      );
      p.cubicTo(
        o(1.08, 0.28).dx,
        o(1.08, 0.28).dy,
        o(0.9, 0.62).dx,
        o(0.9, 0.62).dy,
        o(0.5, 0.95).dx,
        o(0.5, 0.95).dy,
      );
      p.close();
    case Suit.diamond:
      p.moveTo(o(0.5, 0.02).dx, o(0.5, 0.02).dy);
      p.quadraticBezierTo(
        o(0.68, 0.32).dx,
        o(0.68, 0.32).dy,
        o(0.92, 0.5).dx,
        o(0.92, 0.5).dy,
      );
      p.quadraticBezierTo(
        o(0.68, 0.68).dx,
        o(0.68, 0.68).dy,
        o(0.5, 0.98).dx,
        o(0.5, 0.98).dy,
      );
      p.quadraticBezierTo(
        o(0.32, 0.68).dx,
        o(0.32, 0.68).dy,
        o(0.08, 0.5).dx,
        o(0.08, 0.5).dy,
      );
      p.quadraticBezierTo(
        o(0.32, 0.32).dx,
        o(0.32, 0.32).dy,
        o(0.5, 0.02).dx,
        o(0.5, 0.02).dy,
      );
      p.close();
    case Suit.spade:
      p.moveTo(o(0.5, 0.03).dx, o(0.5, 0.03).dy);
      p.cubicTo(
        o(0.68, 0.24).dx,
        o(0.68, 0.24).dy,
        o(1.06, 0.42).dx,
        o(1.06, 0.42).dy,
        o(0.86, 0.66).dx,
        o(0.86, 0.66).dy,
      );
      p.cubicTo(
        o(0.74, 0.8).dx,
        o(0.74, 0.8).dy,
        o(0.58, 0.74).dx,
        o(0.58, 0.74).dy,
        o(0.53, 0.66).dx,
        o(0.53, 0.66).dy,
      );
      p.quadraticBezierTo(
        o(0.56, 0.86).dx,
        o(0.56, 0.86).dy,
        o(0.7, 0.97).dx,
        o(0.7, 0.97).dy,
      );
      p.lineTo(o(0.3, 0.97).dx, o(0.3, 0.97).dy);
      p.quadraticBezierTo(
        o(0.44, 0.86).dx,
        o(0.44, 0.86).dy,
        o(0.47, 0.66).dx,
        o(0.47, 0.66).dy,
      );
      p.cubicTo(
        o(0.42, 0.74).dx,
        o(0.42, 0.74).dy,
        o(0.26, 0.8).dx,
        o(0.26, 0.8).dy,
        o(0.14, 0.66).dx,
        o(0.14, 0.66).dy,
      );
      p.cubicTo(
        o(-0.06, 0.42).dx,
        o(-0.06, 0.42).dy,
        o(0.32, 0.24).dx,
        o(0.32, 0.24).dy,
        o(0.5, 0.03).dx,
        o(0.5, 0.03).dy,
      );
      p.close();
    case Suit.club:
      p.addOval(Rect.fromCircle(center: o(0.5, 0.27), radius: w * 0.21));
      p.addOval(Rect.fromCircle(center: o(0.26, 0.56), radius: w * 0.21));
      p.addOval(Rect.fromCircle(center: o(0.74, 0.56), radius: w * 0.21));
      final stem = Path()
        ..moveTo(o(0.46, 0.5).dx, o(0.46, 0.5).dy)
        ..lineTo(o(0.54, 0.5).dx, o(0.54, 0.5).dy)
        ..quadraticBezierTo(
          o(0.56, 0.84).dx,
          o(0.56, 0.84).dy,
          o(0.72, 0.97).dx,
          o(0.72, 0.97).dy,
        )
        ..lineTo(o(0.28, 0.97).dx, o(0.28, 0.97).dy)
        ..quadraticBezierTo(
          o(0.44, 0.84).dx,
          o(0.44, 0.84).dy,
          o(0.46, 0.5).dx,
          o(0.46, 0.5).dy,
        )
        ..close();
      p.addPath(stem, Offset.zero);
      p.addRect(
        Rect.fromLTRB(
          o(0.42, 0.36).dx,
          o(0.42, 0.36).dy,
          o(0.58, 0.62).dx,
          o(0.58, 0.62).dy,
        ),
      );
  }
  return p;
}

/// 무늬 하나를 그리는 위젯.
class SuitIcon extends StatelessWidget {
  final Suit suit;
  final double size;
  final Color? color;

  const SuitIcon({super.key, required this.suit, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _SuitPainter(
      suit,
      color ?? (isRedSuit(suit) ? kCardRed : kCardBlack),
    ),
  );
}

class _SuitPainter extends CustomPainter {
  final Suit suit;
  final Color color;

  _SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(suitPath(suit, Offset.zero & size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SuitPainter old) =>
      old.suit != suit || old.color != color;
}

const kCardRed = Color(0xFFC8243B);
const kCardBlack = Color(0xFF1F1A24);
const kCardIvory = Color(0xFFFFFCF4);

/// 카드 크기: 작은(손패 겹침용), 보통, 큰.
enum CardSize { small, medium, large }

extension CardSizeDims on CardSize {
  Size get dims => switch (this) {
    CardSize.small => const Size(46, 66),
    CardSize.medium => const Size(64, 92),
    CardSize.large => const Size(86, 124),
  };
}

/// 뒷면 스타일(게임 테마에 맞춤).
@immutable
class CardBackStyle {
  final Color base;
  final Color deep;
  final Color trim;
  final String emblem;

  const CardBackStyle({
    required this.base,
    required this.deep,
    required this.trim,
    this.emblem = '♥',
  });

  static const burgundy = CardBackStyle(
    base: Color(0xFF8E2C48),
    deep: Color(0xFF5C1630),
    trim: Color(0xFFE2BC6A),
  );
  static const emerald = CardBackStyle(
    base: Color(0xFF15604F),
    deep: Color(0xFF0A3A30),
    trim: Color(0xFFE2BC6A),
  );
  static const plum = CardBackStyle(
    base: Color(0xFF5A2A7A),
    deep: Color(0xFF32124A),
    trim: Color(0xFFE8C27A),
  );
}

/// 벡터로 그린 트럼프 카드(앞면·뒷면·조커). 서버 카드 맵 {suit, rank}를 그대로 받는다.
class PlayingCard extends StatelessWidget {
  final String? suit;
  final String? rank;
  final bool faceUp;
  final CardSize size;
  final double? width;
  final CardBackStyle back;
  final bool highlight;
  final bool dimmed;
  final String? badge;
  final Color highlightColor;

  const PlayingCard({
    super.key,
    this.suit,
    this.rank,
    this.faceUp = true,
    this.size = CardSize.medium,
    this.width,
    this.back = CardBackStyle.burgundy,
    this.highlight = false,
    this.dimmed = false,
    this.badge,
    this.highlightColor = const Color(0xFFFFD36E),
  });

  /// 서버 카드 맵에서 만든다(`{suit, rank}`; 뒷면은 null).
  factory PlayingCard.fromMap(
    Map? card, {
    Key? key,
    CardSize size = CardSize.medium,
    double? width,
    CardBackStyle back = CardBackStyle.burgundy,
    bool highlight = false,
    bool dimmed = false,
    String? badge,
  }) {
    final rank = card?['rank']?.toString();
    final suit = card?['suit']?.toString();
    final hidden =
        card == null ||
        card['hidden'] == true ||
        (rank == null && suit == null);
    return PlayingCard(
      key: key,
      suit: suit,
      rank: rank,
      faceUp: !hidden,
      size: size,
      width: width,
      back: back,
      highlight: highlight,
      dimmed: dimmed,
      badge: badge,
    );
  }

  bool get isJoker => (rank ?? '').toUpperCase() == 'JOKER';

  String get _label {
    if (!faceUp) return '뒷면 카드';
    if (isJoker) return '조커';
    const names = {
      Suit.spade: '스페이드',
      Suit.heart: '하트',
      Suit.diamond: '다이아',
      Suit.club: '클로버',
    };
    final s = suitFrom(suit);
    return '${s == null ? '' : names[s]} $rank';
  }

  @override
  Widget build(BuildContext context) {
    final base = size.dims;
    final w = width ?? base.width;
    final h = w * base.height / base.width;
    return Semantics(
      label: _label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.11),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: w * 0.12,
              offset: Offset(0, w * 0.05),
            ),
            if (highlight)
              BoxShadow(
                color: highlightColor.withValues(alpha: 0.85),
                blurRadius: w * 0.28,
                spreadRadius: w * 0.02,
              ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: dimmed ? 0.5 : 1,
                child: CustomPaint(
                  painter: faceUp
                      ? _CardFacePainter(
                          suit: suitFrom(suit),
                          rank: rank ?? '',
                          joker: isJoker,
                        )
                      : _CardBackPainter(back),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -h * 0.08,
                right: -w * 0.1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.08,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.notoSans(
                      fontSize: math.max(9, w * 0.16),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3A2400),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardFacePainter extends CustomPainter {
  final Suit? suit;
  final String rank;
  final bool joker;

  _CardFacePainter({
    required this.suit,
    required this.rank,
    required this.joker,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.11),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFEF9), kCardIvory, Color(0xFFF5EEDC)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      r.deflate(w * 0.045),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.012)
        ..color = const Color(0x66C9A55A),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x22000000),
    );
    if (joker) {
      _joker(canvas, size);
      return;
    }
    final s = suit;
    if (s == null) return;
    final color = isRedSuit(s) ? kCardRed : kCardBlack;
    final paint = Paint()..color = color;
    // 모서리 표기(왼쪽 위 + 180° 회전한 오른쪽 아래).
    void corner() {
      final tp = TextPainter(
        text: TextSpan(
          text: rank,
          style: GoogleFonts.gowunBatang(
            fontSize: w * (rank.length > 1 ? 0.24 : 0.27),
            fontWeight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = w * 0.16;
      tp.paint(canvas, Offset(cx - tp.width / 2, h * 0.06));
      final sw = w * 0.17;
      canvas.drawPath(
        suitPath(
          s,
          Rect.fromLTWH(cx - sw / 2, h * 0.06 + tp.height + h * 0.01, sw, sw),
        ),
        paint,
      );
    }

    corner();
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(math.pi);
    corner();
    canvas.restore();

    final face = const {'J', 'Q', 'K'}.contains(rank);
    if (face) {
      _faceCard(canvas, size, s, color);
    } else if (rank == 'A' || w < 56) {
      final big = w * (rank == 'A' ? 0.5 : 0.42);
      canvas.drawPath(
        suitPath(
          s,
          Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: big,
            height: big,
          ),
        ),
        paint,
      );
    } else {
      _pips(canvas, size, s, paint);
    }
  }

  void _pips(Canvas canvas, Size size, Suit s, Paint paint) {
    final n = int.tryParse(rank) ?? 0;
    final w = size.width, h = size.height;
    final l = w * 0.34, c = w * 0.5, r = w * 0.66;
    final t = h * 0.22, b = h * 0.78, m = h * 0.5;
    final q1 = h * 0.36, q3 = h * 0.64;
    final layouts = <int, List<Offset>>{
      2: [Offset(c, t), Offset(c, b)],
      3: [Offset(c, t), Offset(c, m), Offset(c, b)],
      4: [Offset(l, t), Offset(r, t), Offset(l, b), Offset(r, b)],
      5: [Offset(l, t), Offset(r, t), Offset(c, m), Offset(l, b), Offset(r, b)],
      6: [
        Offset(l, t),
        Offset(r, t),
        Offset(l, m),
        Offset(r, m),
        Offset(l, b),
        Offset(r, b),
      ],
      7: [
        Offset(l, t),
        Offset(r, t),
        Offset(c, q1),
        Offset(l, m),
        Offset(r, m),
        Offset(l, b),
        Offset(r, b),
      ],
      8: [
        Offset(l, t),
        Offset(r, t),
        Offset(c, q1),
        Offset(l, m),
        Offset(r, m),
        Offset(c, q3),
        Offset(l, b),
        Offset(r, b),
      ],
      9: [
        Offset(l, t),
        Offset(r, t),
        Offset(l, q1 + h * 0.02),
        Offset(r, q1 + h * 0.02),
        Offset(c, m),
        Offset(l, q3 - h * 0.02),
        Offset(r, q3 - h * 0.02),
        Offset(l, b),
        Offset(r, b),
      ],
      10: [
        Offset(l, t),
        Offset(r, t),
        Offset(c, h * 0.31),
        Offset(l, q1 + h * 0.04),
        Offset(r, q1 + h * 0.04),
        Offset(l, q3 - h * 0.04),
        Offset(r, q3 - h * 0.04),
        Offset(c, h * 0.69),
        Offset(l, b),
        Offset(r, b),
      ],
    };
    final pts = layouts[n] ?? [Offset(c, m)];
    final ps = w * (n >= 9 ? 0.17 : 0.2);
    for (final p in pts) {
      final flip = p.dy > m + 1;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      if (flip) canvas.rotate(math.pi);
      canvas.drawPath(
        suitPath(
          s,
          Rect.fromCenter(center: Offset.zero, width: ps, height: ps),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _faceCard(Canvas canvas, Size size, Suit s, Color color) {
    final w = size.width, h = size.height;
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.27, h * 0.2, w * 0.73, h * 0.8),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.10),
            const Color(0x33E2BC6A),
            color.withValues(alpha: 0.10),
          ],
        ).createShader(frame.outerRect),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.015)
        ..color = const Color(0xAAC9A55A),
    );
    // 왕관 장식.
    final cw = w * 0.3, top = h * 0.27;
    final crown = Path()
      ..moveTo(w / 2 - cw / 2, top + cw * 0.5)
      ..lineTo(w / 2 - cw / 2, top + cw * 0.12)
      ..lineTo(w / 2 - cw / 4, top + cw * 0.32)
      ..lineTo(w / 2, top)
      ..lineTo(w / 2 + cw / 4, top + cw * 0.32)
      ..lineTo(w / 2 + cw / 2, top + cw * 0.12)
      ..lineTo(w / 2 + cw / 2, top + cw * 0.5)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFD9A441));
    final tp = TextPainter(
      text: TextSpan(
        text: rank,
        style: GoogleFonts.gowunBatang(
          fontSize: w * 0.36,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.47));
    final ss = w * 0.14;
    canvas.drawPath(
      suitPath(
        s,
        Rect.fromCenter(center: Offset(w / 2, h * 0.72), width: ss, height: ss),
      ),
      Paint()..color = color,
    );
  }

  void _joker(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h * 0.5);
    // 광대 모자(세 갈래) + 얼굴.
    final hat = Path()
      ..moveTo(c.dx - w * 0.26, c.dy - h * 0.02)
      ..quadraticBezierTo(
        c.dx - w * 0.34,
        c.dy - h * 0.22,
        c.dx - w * 0.3,
        c.dy - h * 0.3,
      )
      ..quadraticBezierTo(
        c.dx - w * 0.14,
        c.dy - h * 0.18,
        c.dx,
        c.dy - h * 0.34,
      )
      ..quadraticBezierTo(
        c.dx + w * 0.14,
        c.dy - h * 0.18,
        c.dx + w * 0.3,
        c.dy - h * 0.3,
      )
      ..quadraticBezierTo(
        c.dx + w * 0.34,
        c.dy - h * 0.22,
        c.dx + w * 0.26,
        c.dy - h * 0.02,
      )
      ..close();
    canvas.drawPath(
      hat,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7E3FB0), kCardRed, Color(0xFF2E7D6B)],
        ).createShader(Offset.zero & size),
    );
    for (final dx in [-0.3, 0.0, 0.3]) {
      canvas.drawCircle(
        Offset(c.dx + w * dx, c.dy - h * (dx == 0 ? 0.34 : 0.3)),
        w * 0.045,
        Paint()..color = const Color(0xFFD9A441),
      );
    }
    canvas.drawCircle(
      Offset(c.dx, c.dy + h * 0.08),
      w * 0.2,
      Paint()..color = const Color(0xFFFFE9D6),
    );
    final ink = Paint()
      ..color = kCardBlack
      ..strokeWidth = math.max(1, w * 0.025)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(c.dx - w * 0.07, c.dy + h * 0.05),
      w * 0.022,
      Paint()..color = kCardBlack,
    );
    canvas.drawCircle(
      Offset(c.dx + w * 0.07, c.dy + h * 0.05),
      w * 0.022,
      Paint()..color = kCardBlack,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + h * 0.1),
        width: w * 0.2,
        height: h * 0.1,
      ),
      0.2,
      math.pi - 0.4,
      false,
      ink,
    );
    canvas.drawCircle(
      Offset(c.dx, c.dy + h * 0.1),
      w * 0.03,
      Paint()..color = kCardRed,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'JOKER',
        style: GoogleFonts.gowunBatang(
          fontSize: w * 0.15,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF7E3FB0),
          letterSpacing: w * 0.01,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.8));
  }

  @override
  bool shouldRepaint(covariant _CardFacePainter old) =>
      old.suit != suit || old.rank != rank || old.joker != joker;
}

class _CardBackPainter extends CustomPainter {
  final CardBackStyle style;

  _CardBackPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(w * 0.11),
    );
    canvas.drawRRect(r, Paint()..color = kCardIvory);
    final inner = r.deflate(w * 0.06);
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = RadialGradient(
          colors: [style.base, style.deep],
          radius: 0.9,
        ).createShader(inner.outerRect),
    );
    // 금박 격자.
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, w * 0.01)
      ..color = style.trim.withValues(alpha: 0.38);
    final step = w * 0.14;
    for (double d = -h; d < w + h; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), lattice);
      canvas.drawLine(Offset(d, h), Offset(d + h, 0), lattice);
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.02)
        ..color = style.trim,
    );
    // 가운데 엠블럼(하트).
    final ew = w * 0.36;
    final center = Offset(w / 2, h / 2);
    canvas.drawCircle(center, ew * 0.72, Paint()..color = style.deep);
    canvas.drawCircle(
      center,
      ew * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.018)
        ..color = style.trim,
    );
    canvas.drawPath(
      suitPath(
        Suit.heart,
        Rect.fromCenter(center: center, width: ew * 0.8, height: ew * 0.8),
      ),
      Paint()..color = style.trim,
    );
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter old) => old.style != style;
}
