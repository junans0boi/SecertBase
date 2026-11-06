// 화투 앞면·뒷면 CustomPainter와 카드별 그림 캐시.
//
// 카드 그림(테두리·바탕·월 그림)은 id마다 한 번 [ui.Picture]로 기록해 두고,
// 그릴 때는 비례 확대 후 재생만 한다. 크기에 따라 달라지는 모서리 배지와
// 월 숫자만 실제 픽셀 크기로 그린다(작은 크기에서도 또렷하도록).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'hwatu_deck.dart';
import 'hwatu_kit.dart';
import 'months/hwatu_autumn.dart';
import 'months/hwatu_spring.dart';
import 'months/hwatu_summer.dart';

/// id별 카드 그림 캐시. 같은 id는 앱 수명 동안 한 번만 기록한다.
abstract final class HwatuPictureCache {
  static final Map<String, ui.Picture> _faces = {};
  static ui.Picture? _back;

  static ui.Picture face(HwatuCardSpec spec) =>
      _faces[spec.id] ??= _record((canvas) => _paintFace(canvas, spec));

  static ui.Picture get back => _back ??= _record(_paintBack);

  static ui.Picture _record(void Function(Canvas canvas) draw) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, kHwatuUnitW, kHwatuUnitH),
    );
    draw(canvas);
    return recorder.endRecording();
  }
}

const _outer = RRect.fromLTRBXY(0, 0, kHwatuUnitW, kHwatuUnitH, 6.5, 6.5);
final RRect _inner = RRect.fromLTRBXY(
  kHwatuRim,
  kHwatuRim,
  kHwatuUnitW - kHwatuRim,
  kHwatuUnitH - kHwatuRim,
  4,
  4,
);

void _paintFace(Canvas canvas, HwatuCardSpec spec) {
  canvas.drawRRect(_outer, fillOf(HwatuInk.crimson));
  canvas.drawRRect(_inner, fillOf(HwatuInk.ivory));
  canvas.save();
  canvas.clipRRect(_inner);
  // 종이 질감 대신 아주 옅은 아래쪽 그늘.
  canvas.drawRect(
    Rect.fromLTRB(0, kHwatuUnitH * 0.55, kHwatuUnitW, kHwatuUnitH),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, kHwatuUnitH * 0.55),
        const Offset(0, kHwatuUnitH),
        [HwatuInk.ivory.withValues(alpha: 0), const Color(0x14A0763A)],
      ),
  );
  if (spec.isSecondJunk) {
    // 같은 달 두 번째 피는 좌우 반전으로 변주한다.
    canvas.translate(kHwatuUnitW, 0);
    canvas.scale(-1, 1);
  }
  switch (spec.month) {
    case 1:
      paintMonth1(canvas, spec);
    case 2:
      paintMonth2(canvas, spec);
    case 3:
      paintMonth3(canvas, spec);
    case 4:
      paintMonth4(canvas, spec);
    case 5:
      paintMonth5(canvas, spec);
    case 6:
      paintMonth6(canvas, spec);
    case 7:
      paintMonth7(canvas, spec);
    case 8:
      paintMonth8(canvas, spec);
    case 9:
      paintMonth9(canvas, spec);
    case 10:
      paintMonth10(canvas, spec);
    case 11:
      paintMonth11(canvas, spec);
    case 12:
      paintMonth12(canvas, spec);
  }
  canvas.restore();
  // 안쪽 금빛 실선 테두리.
  canvas.drawRRect(
    _inner.deflate(1.3),
    strokeOf(HwatuInk.gold.withValues(alpha: 0.75), 0.6),
  );
}

void _paintBack(Canvas canvas) {
  const w = kHwatuUnitW;
  const h = kHwatuUnitH;
  const c = Offset(w / 2, h / 2);
  canvas.drawRRect(_outer, fillOf(HwatuInk.crimsonDark));
  final field = _outer.deflate(2.2);
  canvas.drawRRect(
    field,
    Paint()
      ..shader = ui.Gradient.radial(c, h * 0.62, const [
        Color(0xFFB01B2A),
        HwatuInk.crimson,
        Color(0xFF6A0E18),
      ], const [0, 0.55, 1]),
  );
  canvas.save();
  canvas.clipRRect(field);
  // 금박 마름모 격자.
  final lattice = strokeOf(HwatuInk.gold.withValues(alpha: 0.38), 0.7);
  const step = 12.5;
  for (var x = -h; x < w + h; x += step) {
    canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
    canvas.drawLine(Offset(x, 0), Offset(x - h, h), lattice);
  }
  // 격자 교차점의 작은 금점.
  final dot = fillOf(HwatuInk.gold.withValues(alpha: 0.55));
  for (var y = 0.0; y <= h + step; y += step / 2) {
    final odd = ((y / (step / 2)).round()).isOdd;
    for (var x = odd ? step / 2 : 0.0; x <= w + step; x += step) {
      canvas.drawCircle(Offset(x, y), 0.9, dot);
    }
  }
  canvas.restore();
  // 이중 금 테두리.
  canvas.drawRRect(field.deflate(3), strokeOf(HwatuInk.gold, 1.1));
  canvas.drawRRect(
    field.deflate(5),
    strokeOf(HwatuInk.goldLight.withValues(alpha: 0.6), 0.5),
  );
  // 모서리 꽃장식.
  for (final corner in [
    const Offset(10, 10),
    const Offset(w - 10, 10),
    const Offset(10, h - 10),
    const Offset(w - 10, h - 10),
  ]) {
    canvas.drawCircle(corner, 3.4, fillOf(HwatuInk.crimsonDark));
    canvas.drawCircle(corner, 3.4, strokeOf(HwatuInk.gold, 0.8));
    canvas.drawCircle(corner, 1.3, fillOf(HwatuInk.goldLight));
  }
  // 가운데 메달리온.
  canvas.drawCircle(c, 27, fillOf(HwatuInk.crimsonDark));
  canvas.drawCircle(c, 27, strokeOf(HwatuInk.gold, 1.6));
  canvas.drawCircle(c, 23.5, strokeOf(HwatuInk.goldLight.withValues(alpha: 0.7), 0.6));
  final rays = strokeOf(HwatuInk.gold.withValues(alpha: 0.5), 0.6);
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi / 12;
    canvas.drawLine(polar(c, 24.8, a), polar(c, 26.2, a), rays);
  }
  // 여덟 잎 꽃(금박).
  final petal = fillOf(HwatuInk.gold);
  final petalLine = strokeOf(HwatuInk.goldLight, 0.6);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 - math.pi / 2;
    final p = leafPath(c, a, 20, 9.5);
    canvas.drawPath(p, petal);
    canvas.drawPath(p, petalLine);
  }
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 - math.pi / 2 + math.pi / 8;
    canvas.drawPath(leafPath(c, a, 12, 6), fillOf(HwatuInk.crimson));
  }
  canvas.drawCircle(c, 6.5, fillOf(HwatuInk.crimsonDark));
  canvas.drawCircle(c, 6.5, strokeOf(HwatuInk.goldLight, 1));
  canvas.drawCircle(c, 3, fillOf(HwatuInk.goldLight));
  // 위아래 작은 마름모 장식.
  for (final y in [c.dy - 42, c.dy + 42]) {
    final d = Path()
      ..moveTo(c.dx, y - 6)
      ..lineTo(c.dx + 6, y)
      ..lineTo(c.dx, y + 6)
      ..lineTo(c.dx - 6, y)
      ..close();
    canvas.drawPath(d, fillOf(HwatuInk.crimsonDark));
    canvas.drawPath(d, strokeOf(HwatuInk.gold, 0.9));
    canvas.drawCircle(Offset(c.dx, y), 1.6, fillOf(HwatuInk.goldLight));
  }
}

/// 크기와 상관없이 같은 비율로 쓰는 카드 모서리 반지름(픽셀).
double hwatuCornerRadius(double width) => width * 6.5 / kHwatuUnitW;

/// 카드 앞면 painter. 카드 그림은 캐시된 Picture를 재생하고, 모서리 색인
/// (종류 배지 + 월 숫자)만 실제 크기에 맞춰 그린다.
class HwatuFacePainter extends CustomPainter {
  HwatuFacePainter(this.spec, {this.highlighted = false, this.dimmed = false});

  final HwatuCardSpec spec;
  final bool highlighted;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / kHwatuUnitW;
    if (highlighted) _paintGlow(canvas, size);
    canvas.save();
    canvas.scale(s);
    canvas.drawPicture(HwatuPictureCache.face(spec));
    canvas.restore();
    paintHwatuIndex(canvas, size.width, spec);
    if (dimmed) _paintDim(canvas, size);
    if (highlighted) _paintHighlightRing(canvas, size);
  }

  @override
  bool shouldRepaint(HwatuFacePainter old) =>
      old.spec.id != spec.id ||
      old.highlighted != highlighted ||
      old.dimmed != dimmed;
}

/// 카드 뒷면 painter.
class HwatuBackPainter extends CustomPainter {
  HwatuBackPainter({this.highlighted = false, this.dimmed = false});

  final bool highlighted;
  final bool dimmed;

  @override
  void paint(Canvas canvas, Size size) {
    if (highlighted) _paintGlow(canvas, size);
    canvas.save();
    canvas.scale(size.width / kHwatuUnitW);
    canvas.drawPicture(HwatuPictureCache.back);
    canvas.restore();
    if (dimmed) _paintDim(canvas, size);
    if (highlighted) _paintHighlightRing(canvas, size);
  }

  @override
  bool shouldRepaint(HwatuBackPainter old) =>
      old.highlighted != highlighted || old.dimmed != dimmed;
}

RRect _cardRRect(Size size) => RRect.fromRectAndRadius(
  Offset.zero & size,
  Radius.circular(hwatuCornerRadius(size.width)),
);

void _paintGlow(Canvas canvas, Size size) {
  final blur = math.max(3.0, size.width * 0.09);
  canvas.drawRRect(
    _cardRRect(size).inflate(blur * 0.25),
    Paint()
      ..color = HwatuInk.goldLight.withValues(alpha: 0.85)
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blur),
  );
}

void _paintHighlightRing(Canvas canvas, Size size) {
  final w = math.max(1.5, size.width * 0.035);
  canvas.drawRRect(
    _cardRRect(size).deflate(w / 2),
    strokeOf(HwatuInk.goldLight, w),
  );
}

void _paintDim(Canvas canvas, Size size) {
  canvas.drawRRect(_cardRRect(size), fillOf(const Color(0x8C14100F)));
}

// ── 모서리 색인 ────────────────────────────────────────────────

final Map<String, TextPainter> _textCache = {};

TextPainter _glyph(String text, double fontSize, Color color, {Paint? stroke}) {
  final key =
      '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}|'
      '${stroke == null ? '' : stroke.strokeWidth.toStringAsFixed(1)}';
  final cached = _textCache[key];
  if (cached != null) return cached;
  if (_textCache.length > 400) _textCache.clear();
  final style = stroke == null
      ? TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.04 * fontSize,
        )
      : TextStyle(
          foreground: stroke,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -0.04 * fontSize,
        );
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return _textCache[key] = tp;
}

void _drawCentered(Canvas canvas, TextPainter tp, Offset c) {
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

/// 종류 배지 지름(픽셀). 26dp에서 약 9px, 120dp에서 약 24px.
double hwatuBadgeSize(double width) => 5 + 0.16 * width;

/// 왼쪽 위 모서리 색인(종류 배지 + 월 숫자)을 그린다.
///
/// 배지는 색과 함께 모양으로도 종류를 구분한다(색맹 고려):
/// 광=주홍 원+금테, 열=먹색 둥근 네모, 띠=띠 색 세로 네모(홍단·청단은 금띠),
/// 피=흰 원+먹 테, 쌍피=먹 원+금 이중테와 "2".
void paintHwatuIndex(Canvas canvas, double width, HwatuCardSpec spec) {
  final d = hwatuBadgeSize(width);
  final inset = width * 0.045 + 0.5;
  final c = Offset(inset + d / 2, inset + d / 2);
  final ring = math.max(0.8, d * 0.085);
  final shadow = fillOf(const Color(0x40000000));

  late final String glyph;
  late final Color glyphColor;
  switch (spec.type) {
    case HwatuType.bright:
      canvas.drawCircle(c + Offset(0, d * 0.05), d / 2, shadow);
      canvas.drawCircle(c, d / 2, fillOf(HwatuInk.vermilion));
      canvas.drawCircle(c, d / 2 - ring / 2, strokeOf(HwatuInk.goldLight, ring));
      glyph = '광';
      glyphColor = HwatuInk.white;
    case HwatuType.animal:
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: d * 0.92, height: d * 0.92),
        Radius.circular(d * 0.2),
      );
      canvas.drawRRect(r.shift(Offset(0, d * 0.05)), shadow);
      canvas.drawRRect(r, fillOf(HwatuInk.ink));
      canvas.drawRRect(r.deflate(ring / 2), strokeOf(HwatuInk.gold, ring * 0.8));
      glyph = '열';
      glyphColor = HwatuInk.goldLight;
    case HwatuType.ribbon:
      final kind = spec.ribbon!;
      final color = kind == HwatuRibbon.cheong ? HwatuInk.blue : HwatuInk.red;
      final rect = Rect.fromCenter(center: c, width: d * 0.8, height: d * 1.04);
      final r = RRect.fromRectAndRadius(rect, Radius.circular(d * 0.12));
      canvas.drawRRect(r.shift(Offset(0, d * 0.05)), shadow);
      canvas.drawRRect(r, fillOf(color));
      if (kind != HwatuRibbon.cho) {
        canvas.save();
        canvas.clipRRect(r);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.top, rect.width, d * 0.2),
          fillOf(HwatuInk.goldLight),
        );
        canvas.restore();
      }
      glyph = '띠';
      glyphColor = HwatuInk.white;
    case HwatuType.junk:
      if (spec.isDouble) {
        canvas.drawCircle(c + Offset(0, d * 0.05), d / 2, shadow);
        canvas.drawCircle(c, d / 2, fillOf(HwatuInk.ink));
        canvas.drawCircle(c, d / 2 - ring / 2, strokeOf(HwatuInk.gold, ring));
        canvas.drawCircle(
          c,
          d / 2 - ring * 1.9,
          strokeOf(HwatuInk.gold, math.max(0.5, ring * 0.45)),
        );
        glyph = '2';
        glyphColor = HwatuInk.goldLight;
      } else {
        canvas.drawCircle(c + Offset(0, d * 0.05), d / 2, shadow);
        canvas.drawCircle(c, d / 2, fillOf(HwatuInk.white));
        canvas.drawCircle(c, d / 2 - ring / 2, strokeOf(HwatuInk.ink, ring));
        glyph = '피';
        glyphColor = HwatuInk.ink;
      }
  }
  final glyphSize = spec.type == HwatuType.junk && spec.isDouble
      ? d * 0.66
      : d * 0.56;
  _drawCentered(
    canvas,
    _glyph(glyph, glyphSize, glyphColor),
    c + Offset(0, spec.type == HwatuType.ribbon ? d * 0.06 : 0),
  );

  // 월 숫자: 배지 아래, 상아색 테두리 글씨.
  final numSize = d * 0.6;
  final label = '${spec.month}';
  final halo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, numSize * 0.28)
    ..strokeJoin = StrokeJoin.round
    ..color = HwatuInk.ivory;
  final top = c.dy + d / 2 + d * 0.12;
  final numberCenter = Offset(c.dx, top + numSize / 2);
  _drawCentered(canvas, _glyph(label, numSize, HwatuInk.ivory, stroke: halo), numberCenter);
  _drawCentered(canvas, _glyph(label, numSize, HwatuInk.ink), numberCenter);
}
