import 'dart:math' as math;
import 'dart:ui' show PointMode;

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

/// 무늬 경로. 24×24 도안을 [box]에 맞춰 늘린다.
Path suitPath(Suit suit, Rect box) {
  final p = Path();
  switch (suit) {
    case Suit.heart:
      p
        ..moveTo(12, 21.2)
        ..cubicTo(5.2, 15.8, 2.6, 12.3, 2.6, 8.5)
        ..cubicTo(2.6, 5.6, 4.7, 3.6, 7.2, 3.6)
        ..relativeCubicTo(1.9, 0, 3.8, 1.1, 4.8, 3)
        ..relativeCubicTo(1, -1.9, 2.9, -3, 4.8, -3)
        ..relativeCubicTo(2.5, 0, 4.6, 2, 4.6, 4.9)
        ..relativeCubicTo(0, 3.8, -2.6, 7.3, -9.4, 12.7)
        ..close();
    case Suit.diamond:
      p
        ..moveTo(12, 2.4)
        ..relativeCubicTo(1.9, 3.6, 5.1, 6.8, 8.6, 9.6)
        ..relativeCubicTo(-3.5, 2.8, -6.7, 6, -8.6, 9.6)
        ..relativeCubicTo(-1.9, -3.6, -5.1, -6.8, -8.6, -9.6)
        ..cubicTo(6.9, 9.2, 10.1, 6, 12, 2.4)
        ..close();
    case Suit.spade:
      p
        ..moveTo(12, 2.5)
        ..cubicTo(8, 6.8, 3, 9.9, 3, 14.3)
        ..relativeCubicTo(0, 2.6, 2, 4.4, 4.4, 4.4)
        ..relativeCubicTo(1.7, 0, 3.1, -0.7, 3.9, -2)
        ..relativeCubicTo(-0.1, 2.3, -0.9, 3.9, -2.8, 5.3)
        ..relativeLineTo(7, 0)
        ..relativeCubicTo(-1.9, -1.4, -2.7, -3, -2.8, -5.3)
        ..relativeCubicTo(0.8, 1.3, 2.2, 2, 3.9, 2)
        ..relativeCubicTo(2.4, 0, 4.4, -1.8, 4.4, -4.4)
        ..cubicTo(21, 9.9, 16, 6.8, 12, 2.5)
        ..close();
    case Suit.club:
      p
        ..addOval(Rect.fromCircle(center: const Offset(12, 7.4), radius: 4.4))
        ..addOval(Rect.fromCircle(center: const Offset(6.8, 14), radius: 4.4))
        ..addOval(Rect.fromCircle(center: const Offset(17.2, 14), radius: 4.4))
        ..moveTo(12, 11.5)
        ..relativeLineTo(1.8, 10)
        ..relativeLineTo(-3.6, 0)
        ..close();
  }
  final m = Matrix4.identity()
    ..translateByDouble(box.left, box.top, 0, 1)
    ..scaleByDouble(box.width / 24, box.height / 24, 1, 1);
  return p.transform(m.storage);
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

const kCardRed = Color(0xFFB93A3A);
const kCardBlack = Color(0xFF1D2B29);

/// 카드 크기: 작은(손패 겹침용), 보통, 큰.
enum CardSize { small, medium, large }

extension CardSizeDims on CardSize {
  Size get dims => switch (this) {
    CardSize.small => const Size(46, 66),
    CardSize.medium => const Size(64, 92),
    CardSize.large => const Size(86, 124),
  };
}

/// 뒷면 무늬: 황동 사선 격자(라운지) 또는 점무늬(동화책).
enum CardBackPattern { lattice, dots }

/// 카드 한 벌의 모양(앞면 종이색·글자색·뒷면). 테마마다 하나.
@immutable
class CardStyle {
  final Color face;
  final Color? faceBorder;
  final Color red;
  final Color black;
  final Color shadow;
  final double shadowBlur;
  final double shadowDy;

  final Color backBase;
  final Color backBorder;
  final Color backLine;
  final Color backInner;
  final CardBackPattern pattern;

  /// 뒷면 가운데 표시: 비워 두면 열쇠 구멍.
  final String? backMark;
  final Color backMarkColor;

  /// 표식(숨은 카드·NEW)·조커 강조색.
  final Color accent;
  final Color onAccent;

  const CardStyle({
    required this.face,
    this.faceBorder,
    required this.red,
    required this.black,
    required this.shadow,
    required this.shadowBlur,
    required this.shadowDy,
    required this.backBase,
    required this.backBorder,
    required this.backLine,
    required this.backInner,
    required this.pattern,
    this.backMark,
    required this.backMarkColor,
    required this.accent,
    required this.onAccent,
  });

  /// 블랙잭: 상아 카드 + 짙은 에메랄드 뒷면에 황동 격자와 "?".
  static const lounge = CardStyle(
    face: Color(0xFFFBF6EA),
    red: Color(0xFFB93A3A),
    black: Color(0xFF1D2B29),
    shadow: Color(0x47000000),
    shadowBlur: 12,
    shadowDy: 5,
    backBase: Color(0xFF0A3830),
    backBorder: Color(0x8CE2BC6A),
    backLine: Color(0x21E2BC6A),
    backInner: Color(0x66E2BC6A),
    pattern: CardBackPattern.lattice,
    backMark: '?',
    backMarkColor: Color(0xFFE2BC6A),
    accent: Color(0xFFD9A441),
    onAccent: Color(0xFF2A1E05),
  );

  /// 도둑잡기: 크림 카드 + 베리색 뒷면에 점무늬와 열쇠 구멍.
  static const storybook = CardStyle(
    face: Color(0xFFFFFDF7),
    faceBorder: Color(0x333B2430),
    red: Color(0xFFA23B55),
    black: Color(0xFF3B2430),
    shadow: Color(0x243B2430),
    shadowBlur: 10,
    shadowDy: 4,
    backBase: Color(0xFFA23B55),
    backBorder: Color(0xFF7E2A40),
    backLine: Color(0x38FFF6E6),
    backInner: Color(0x8CFFF6E6),
    pattern: CardBackPattern.dots,
    backMarkColor: Color(0xFFFFF6E6),
    accent: Color(0xFFA23B55),
    onAccent: Colors.white,
  );
}

/// 벡터로 그린 트럼프 카드(앞면·뒷면·조커). 서버 카드 맵 {suit, rank}를 그대로 받는다.
class PlayingCard extends StatelessWidget {
  final String? suit;
  final String? rank;
  final bool faceUp;
  final CardSize size;
  final double? width;
  final CardStyle style;
  final bool highlight;
  final bool dimmed;

  /// 위쪽 가운데에 다는 작은 알약("숨은 카드", "NEW").
  final String? badge;
  final Color highlightColor;

  const PlayingCard({
    super.key,
    this.suit,
    this.rank,
    this.faceUp = true,
    this.size = CardSize.medium,
    this.width,
    this.style = CardStyle.lounge,
    this.highlight = false,
    this.dimmed = false,
    this.badge,
    this.highlightColor = const Color(0xFFD9A441),
  });

  /// 서버 카드 맵에서 만든다(`{suit, rank}`; 뒷면은 null).
  factory PlayingCard.fromMap(
    Map? card, {
    Key? key,
    CardSize size = CardSize.medium,
    double? width,
    CardStyle style = CardStyle.lounge,
    bool highlight = false,
    bool dimmed = false,
    String? badge,
    Color highlightColor = const Color(0xFFD9A441),
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
      style: style,
      highlight: highlight,
      dimmed: dimmed,
      badge: badge,
      highlightColor: highlightColor,
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
    final s = style;
    final radius = w * 0.14;
    final Widget content = !faceUp
        ? _CardBack(style: s, w: w, h: h)
        : isJoker
        ? _JokerFace(style: s, w: w, h: h)
        : _CardFace(
            style: s,
            w: w,
            h: h,
            suit: suitFrom(suit),
            rank: rank ?? '',
          );
    return Semantics(
      label: _label,
      excludeSemantics: true,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: dimmed ? 0.5 : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        color: s.shadow,
                        blurRadius: s.shadowBlur * w / 66,
                        offset: Offset(0, s.shadowDy * w / 66),
                      ),
                      if (highlight)
                        BoxShadow(color: highlightColor, spreadRadius: 1.5),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: content,
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -10,
                left: -20,
                right: -20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: s.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge!,
                      maxLines: 1,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: s.onAccent,
                        height: 1,
                      ),
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

class _CardFace extends StatelessWidget {
  final CardStyle style;
  final double w;
  final double h;
  final Suit? suit;
  final String rank;

  const _CardFace({
    required this.style,
    required this.w,
    required this.h,
    required this.suit,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final s = style;
    final color = suit != null && isRedSuit(suit!) ? s.red : s.black;
    final small = w * 0.227;
    final big = w * 0.455;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.face,
        border: s.faceBorder == null
            ? null
            : Border.all(color: s.faceBorder!, width: 1),
        borderRadius: BorderRadius.circular(w * 0.14),
      ),
      child: Stack(
        children: [
          Positioned(
            left: w * 0.12,
            top: h * 0.064,
            child: Text(
              rank,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.gowunBatang(
                fontSize: w * 0.318,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
          ),
          if (suit != null) ...[
            Positioned(
              left: w * 0.12,
              top: h * 0.32,
              child: SuitIcon(suit: suit!, size: small, color: color),
            ),
            Positioned(
              right: w * 0.106,
              bottom: h * 0.074,
              child: SuitIcon(suit: suit!, size: big, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final CardStyle style;
  final double w;
  final double h;

  const _CardBack({required this.style, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final s = style;
    final inset = w * (s.pattern == CardBackPattern.lattice ? 0.076 : 0.074);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.backBase,
        border: Border.all(color: s.backBorder),
        borderRadius: BorderRadius.circular(w * 0.14),
      ),
      child: CustomPaint(
        painter: s.pattern == CardBackPattern.lattice
            ? _LatticePainter(s, w)
            : null,
        child: Padding(
          padding: EdgeInsets.all(inset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: s.backInner),
              borderRadius: BorderRadius.circular(w * 0.09),
            ),
            child: s.pattern == CardBackPattern.dots
                ? CustomPaint(
                    painter: _DotsPainter(s, w),
                    child: Center(child: _mark(s, w)),
                  )
                : Center(child: _mark(s, w)),
          ),
        ),
      ),
    );
  }

  static Widget _mark(CardStyle s, double w) {
    if (s.backMark != null) {
      return Text(
        s.backMark!,
        style: GoogleFonts.gowunBatang(
          fontSize: w * 0.364,
          fontWeight: FontWeight.w700,
          color: s.backMarkColor,
          height: 1,
        ),
      );
    }
    return CustomPaint(
      size: Size.square(w * 0.48),
      painter: _KeyholePainter(s.backMarkColor),
    );
  }
}

class _LatticePainter extends CustomPainter {
  final CardStyle s;
  final double w;

  _LatticePainter(this.s, this.w);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = s.backLine
      ..strokeWidth = 1;
    // 사선 간격(수직 거리) 9px(카드 폭 66 기준).
    final step = 9 * w / 66 * math.sqrt2;
    final h = size.height;
    for (double d = -h; d < size.width + h; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + h, h), paint);
      canvas.drawLine(Offset(d, h), Offset(d + h, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LatticePainter old) => old.s != s || old.w != w;
}

class _DotsPainter extends CustomPainter {
  final CardStyle s;
  final double w;

  _DotsPainter(this.s, this.w);

  @override
  void paint(Canvas canvas, Size size) {
    final step = 7 * w / 54;
    final dots = <Offset>[];
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        dots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = s.backLine
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.s != s || old.w != w;
}

class _KeyholePainter extends CustomPainter {
  final Color color;

  _KeyholePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()..color = color;
    canvas.drawCircle(const Offset(12, 9.5), 4, p);
    canvas.drawPath(
      Path()
        ..moveTo(10.2, 12.5)
        ..lineTo(9, 19)
        ..lineTo(15, 19)
        ..lineTo(13.8, 12.5)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _KeyholePainter old) => old.color != color;
}

/// 조커 앞면: 가면 쓴 도둑 일러스트 + "조커".
class _JokerFace extends StatelessWidget {
  final CardStyle style;
  final double w;
  final double h;

  const _JokerFace({required this.style, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final s = style;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.face,
        border: Border.all(color: s.accent, width: 1.5),
        borderRadius: BorderRadius.circular(w * 0.14),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThiefIcon(size: w * 0.7),
            SizedBox(height: h * 0.012),
            Text(
              '조커',
              maxLines: 1,
              style: GoogleFonts.notoSansKr(
                fontSize: math.max(9, w * 0.22),
                fontWeight: FontWeight.w700,
                color: s.accent,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가면 쓴 도둑(조커·로비·결과 화면 공통 일러스트).
class ThiefIcon extends StatelessWidget {
  final double size;

  const ThiefIcon({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: const _ThiefPainter()),
  );
}

class _ThiefPainter extends CustomPainter {
  const _ThiefPainter();

  static const _berry = Color(0xFFA23B55);
  static const _ink = Color(0xFF3B2430);
  static const _skin = Color(0xFFFFF1DE);
  static const _gold = Color(0xFFC79A4B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // 얼굴.
    canvas.drawCircle(const Offset(32, 38), 16, fill..color = _skin);
    canvas.drawCircle(
      const Offset(32, 38),
      16,
      line
        ..color = _ink
        ..strokeWidth = 1.6,
    );
    // 모자.
    canvas.drawPath(
      Path()
        ..moveTo(15, 33)
        ..quadraticBezierTo(32, -2, 49, 33)
        ..close(),
      fill..color = _berry,
    );
    canvas.drawLine(
      const Offset(13, 33),
      const Offset(51, 33),
      line
        ..color = _ink
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(const Offset(32, 9.5), 3.5, fill..color = _gold);
    // 눈가리개.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 37, 30, 9),
        const Radius.circular(4.5),
      ),
      fill..color = _ink,
    );
    fill.color = _skin;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(25.5, 41.5),
        width: 6.4,
        height: 4.8,
      ),
      fill,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(38.5, 41.5),
        width: 6.4,
        height: 4.8,
      ),
      fill,
    );
    // 입.
    canvas.drawPath(
      Path()
        ..moveTo(27, 52)
        ..relativeQuadraticBezierTo(5, 3.5, 10, 0),
      line
        ..color = _ink
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _ThiefPainter old) => false;
}
