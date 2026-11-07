// Illustrated faces for the 22 major-arcana tarot cards and the card back.
//
// Everything is painted in the mockup's 120x200 viewBox units
// (docs/design/v2/mockup/us.html) and scaled to the requested width, so the
// same art works from a 36px thumbnail up to a 220px hero card. Emblems are
// authored as compact SVG path strings inside a 60x60 box and parsed once.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:secret_base_app/v2/v2.dart';

/// Static description of one major-arcana card.
class TarotCardInfo {
  const TarotCardInfo({
    required this.key,
    required this.number,
    required this.roman,
    required this.name,
    required this.keywords,
  });

  /// Server key, e.g. `the_star`.
  final String key;

  /// 0..21.
  final int number;

  /// Roman numeral shown at the top of the face ("0" for the fool).
  final String roman;

  /// Korean display name (softened per the 2.0 copy notes).
  final String name;

  /// 2-3 gentle noun keywords.
  final List<String> keywords;
}

/// Keys used by the server: the_fool, the_magician, the_high_priestess,
/// the_empress, the_emperor, the_hierophant, the_lovers, the_chariot,
/// strength, the_hermit, wheel_of_fortune, justice, the_hanged_man, death,
/// temperance, the_devil, the_tower, the_star, the_moon, the_sun, judgement,
/// the_world.
const List<TarotCardInfo> kTarotCards = [
  TarotCardInfo(
    key: 'the_fool',
    number: 0,
    roman: '0',
    name: '바보',
    keywords: ['시작', '호기심', '가벼움'],
  ),
  TarotCardInfo(
    key: 'the_magician',
    number: 1,
    roman: 'I',
    name: '마법사',
    keywords: ['의지', '재능', '표현'],
  ),
  TarotCardInfo(
    key: 'the_high_priestess',
    number: 2,
    roman: 'II',
    name: '여사제',
    keywords: ['직감', '고요', '마음속'],
  ),
  TarotCardInfo(
    key: 'the_empress',
    number: 3,
    roman: 'III',
    name: '여황제',
    keywords: ['돌봄', '풍요', '다정함'],
  ),
  TarotCardInfo(
    key: 'the_emperor',
    number: 4,
    roman: 'IV',
    name: '황제',
    keywords: ['안정', '책임', '든든함'],
  ),
  TarotCardInfo(
    key: 'the_hierophant',
    number: 5,
    roman: 'V',
    name: '교황',
    keywords: ['믿음', '배움', '조언'],
  ),
  TarotCardInfo(
    key: 'the_lovers',
    number: 6,
    roman: 'VI',
    name: '연인',
    keywords: ['선택', '조화', '마음'],
  ),
  TarotCardInfo(
    key: 'the_chariot',
    number: 7,
    roman: 'VII',
    name: '전차',
    keywords: ['전진', '용기', '방향'],
  ),
  TarotCardInfo(
    key: 'strength',
    number: 8,
    roman: 'VIII',
    name: '힘',
    keywords: ['부드러운 힘', '인내', '다독임'],
  ),
  TarotCardInfo(
    key: 'the_hermit',
    number: 9,
    roman: 'IX',
    name: '은둔자',
    keywords: ['성찰', '쉼', '나만의 시간'],
  ),
  TarotCardInfo(
    key: 'wheel_of_fortune',
    number: 10,
    roman: 'X',
    name: '운명의 수레바퀴',
    keywords: ['흐름', '변화', '타이밍'],
  ),
  TarotCardInfo(
    key: 'justice',
    number: 11,
    roman: 'XI',
    name: '정의',
    keywords: ['균형', '솔직함', '공정'],
  ),
  TarotCardInfo(
    key: 'the_hanged_man',
    number: 12,
    roman: 'XII',
    name: '매달린 사람',
    keywords: ['멈춤', '새 시선', '기다림'],
  ),
  TarotCardInfo(
    key: 'death',
    number: 13,
    roman: 'XIII',
    name: '끝과 시작',
    keywords: ['마무리', '전환', '새 출발'],
  ),
  TarotCardInfo(
    key: 'temperance',
    number: 14,
    roman: 'XIV',
    name: '절제',
    keywords: ['조율', '균형', '차분함'],
  ),
  TarotCardInfo(
    key: 'the_devil',
    number: 15,
    roman: 'XV',
    name: '얽매임',
    keywords: ['집착', '습관', '풀어내기'],
  ),
  TarotCardInfo(
    key: 'the_tower',
    number: 16,
    roman: 'XVI',
    name: '탑',
    keywords: ['깨달음', '변화', '다시 짓기'],
  ),
  TarotCardInfo(
    key: 'the_star',
    number: 17,
    roman: 'XVII',
    name: '별',
    keywords: ['희망', '회복', '천천히'],
  ),
  TarotCardInfo(
    key: 'the_moon',
    number: 18,
    roman: 'XVIII',
    name: '달',
    keywords: ['불안', '상상', '감정'],
  ),
  TarotCardInfo(
    key: 'the_sun',
    number: 19,
    roman: 'XIX',
    name: '태양',
    keywords: ['기쁨', '활력', '따뜻함'],
  ),
  TarotCardInfo(
    key: 'judgement',
    number: 20,
    roman: 'XX',
    name: '부름',
    keywords: ['깨어남', '응답', '다시 시작'],
  ),
  TarotCardInfo(
    key: 'the_world',
    number: 21,
    roman: 'XXI',
    name: '세계',
    keywords: ['완성', '하나됨', '여정'],
  ),
];

/// Looks up a card by its server key; null when unknown.
TarotCardInfo? tarotCardInfo(String key) {
  for (final card in kTarotCards) {
    if (card.key == key) return card;
  }
  return null;
}

/// Illustrated face of a major-arcana card. Height is `width * 5 / 3`.
///
/// [title] overrides the printed Korean name when non-empty. Unknown keys
/// render a generic sparkle emblem.
class TarotCardFace extends StatelessWidget {
  const TarotCardFace({
    super.key,
    required this.cardKey,
    this.title,
    this.width = 120,
  });

  final String cardKey;
  final String? title;
  final double width;

  @override
  Widget build(BuildContext context) {
    final info = tarotCardInfo(cardKey);
    final custom = title?.trim() ?? '';
    final name = custom.isNotEmpty ? custom : (info?.name ?? '타로');
    final roman = info?.roman ?? '';
    final label = roman.isEmpty ? '$name 카드' : '$roman $name 카드';
    return Semantics(
      container: true,
      image: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width * 5 / 3,
        child: CustomPaint(
          painter: _TarotFacePainter(
            cardKey: cardKey,
            roman: roman,
            name: name,
            palette: _paletteFor(info?.number ?? 3),
          ),
        ),
      ),
    );
  }
}

/// The face-down card back (lilac gradient, star medallion).
class TarotCardBack extends StatelessWidget {
  const TarotCardBack({
    super.key,
    this.width = 120,
    this.excludeSemantics = false,
  });

  final double width;

  /// Hide the "뒤집힌 타로 카드" label, e.g. when a parent button labels it.
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final art = SizedBox(
      width: width,
      height: width * 5 / 3,
      child: CustomPaint(painter: _TarotBackPainter()),
    );
    if (excludeSemantics) return ExcludeSemantics(child: art);
    return Semantics(
      container: true,
      image: true,
      label: '뒤집힌 타로 카드',
      child: art,
    );
  }
}

// ---------------------------------------------------------------------------
// Palettes (derived from 2.0 tokens; no raw colors)

class _Palette {
  _Palette(Color soft, Color base, Color text)
    : top = soft,
      bottom = Color.lerp(soft, base, 0.45)!,
      ink = Color.lerp(text, V2Colors.ink, 0.25)!,
      accent = Color.lerp(base, text, 0.35)!;

  final Color top;
  final Color bottom;
  final Color ink;
  final Color accent;
}

final List<_Palette> _palettes = [
  _Palette(V2Colors.peachSoft, V2Colors.peach, V2Colors.peachText),
  _Palette(V2Colors.sageSoft, V2Colors.sage, V2Colors.sageText),
  _Palette(V2Colors.lilacSoft, V2Colors.lilac, V2Colors.lilacText),
  _Palette(V2Colors.skySoft, V2Colors.sky, V2Colors.skyText),
  _Palette(V2Colors.honeySoft, V2Colors.honey, V2Colors.honeyText),
  _Palette(V2Colors.roseSoft, V2Colors.rose, V2Colors.rose700),
];

_Palette _paletteFor(int number) => _palettes[number % _palettes.length];

// ---------------------------------------------------------------------------
// Emblems (60x60 box, mockup stroke style)

class _Shape {
  const _Shape(
    this.d, {
    this.fill = 0,
    this.stroke = true,
    this.inkFill = false,
  });

  final String d;

  /// Accent fill opacity; 0 = no fill.
  final double fill;
  final bool stroke;

  /// Fill with the ink color instead of the accent.
  final bool inkFill;
}

String _f(double v) => v.toStringAsFixed(2);

String _circle(double cx, double cy, double r) =>
    'M${_f(cx - r)} ${_f(cy)}A${_f(r)} ${_f(r)} 0 1 0 ${_f(cx + r)} ${_f(cy)}'
    'A${_f(r)} ${_f(r)} 0 1 0 ${_f(cx - r)} ${_f(cy)}Z';

Offset _polar(double cx, double cy, double r, double deg) {
  final a = deg * math.pi / 180;
  return Offset(cx + r * math.cos(a), cy + r * math.sin(a));
}

/// n-pointed star polygon (2n vertices), first tip pointing up.
String _star(double cx, double cy, double outer, double inner, int n) {
  final b = StringBuffer();
  for (var i = 0; i < n * 2; i++) {
    final p = _polar(cx, cy, i.isEven ? outer : inner, -90 + i * 180 / n);
    b.write('${i == 0 ? 'M' : 'L'}${_f(p.dx)} ${_f(p.dy)}');
  }
  b.write('Z');
  return b.toString();
}

/// Radial line segments from r1 to r2.
String _rays(double cx, double cy, double r1, double r2, List<double> degrees) {
  final b = StringBuffer();
  for (final d in degrees) {
    final a = _polar(cx, cy, r1, d);
    final z = _polar(cx, cy, r2, d);
    b.write('M${_f(a.dx)} ${_f(a.dy)}L${_f(z.dx)} ${_f(z.dy)}');
  }
  return b.toString();
}

List<double> _every(double step, {double start = 0, double end = 360}) => [
  for (var d = start; d < end - 0.001; d += step) d,
];

/// Mockup heart (empress), centered at (cx, cy) and scaled by s.
String _heart(double cx, double cy, double s) {
  String p(double dx, double dy) => '${_f(cx + dx * s)} ${_f(cy + dy * s)}';
  return 'M${p(0, 20)}C${p(-24, 4)} ${p(-21, -20)} ${p(0, -7)}'
      'C${p(21, -20)} ${p(24, 4)} ${p(0, 20)}Z';
}

String _drop(double x, double y, double s) {
  String p(double dx, double dy) => '${_f(x + dx * s)} ${_f(y + dy * s)}';
  return 'M${p(0, 0)}C${p(3, 4)} ${p(3, 7)} ${p(0, 7)}'
      'C${p(-3, 7)} ${p(-3, 4)} ${p(0, 0)}Z';
}

/// Lens-shaped leaf from a to b.
String _leaf(Offset a, Offset b, double bulge) {
  final mid = (a + b) / 2;
  final d = b - a;
  final n = Offset(-d.dy, d.dx) / d.distance * bulge;
  final c1 = mid + n;
  final c2 = mid - n;
  return 'M${_f(a.dx)} ${_f(a.dy)}Q${_f(c1.dx)} ${_f(c1.dy)} ${_f(b.dx)} ${_f(b.dy)}'
      'Q${_f(c2.dx)} ${_f(c2.dy)} ${_f(a.dx)} ${_f(a.dy)}Z';
}

String _wreathLeaves() {
  final b = StringBuffer();
  for (final deg in _every(36, start: 18)) {
    final a = _polar(30, 30, 20, deg);
    final z = _polar(30, 30, 26, deg + 16);
    b.write(_leaf(a, z, 2.6));
  }
  return b.toString();
}

const String _infinityTop =
    'M18 14C18 8 26 8 30 14C34 20 42 20 42 14C42 8 34 8 30 14C26 20 18 20 18 14Z';
const String _infinitySmall =
    'M22 12C22 8.5 27 8.5 30 12C33 15.5 38 15.5 38 12C38 8.5 33 8.5 30 12'
    'C27 15.5 22 15.5 22 12Z';

final List<_Shape> _genericEmblem = [
  _Shape(_star(30, 30, 18, 5, 4), fill: 0.6),
  _Shape(_star(12, 12, 6, 1.8, 4), fill: 1, stroke: false),
  _Shape(_star(48, 48, 6, 1.8, 4), fill: 1, stroke: false),
];

final Map<String, List<_Shape>> _emblems = {
  // Bundle on a stick, cliff edge.
  'the_fool': [
    const _Shape('M12 44L38 16'),
    _Shape(_circle(42, 13, 7), fill: 0.6),
    const _Shape('M2 50H34L40 58'),
    _Shape(_star(14, 14, 5, 1.5, 4), fill: 1, stroke: false),
  ],
  // Wand under an infinity sign.
  'the_magician': [
    const _Shape(_infinityTop, fill: 0.5),
    const _Shape('M30 29V51'),
    _Shape(_circle(30, 26, 3), fill: 0.8),
    _Shape(_circle(30, 54, 3), fill: 0.8),
    const _Shape('M10 38H18M14 34V42M42 38H50M46 34V42'),
  ],
  // Crescent between two pillars.
  'the_high_priestess': [
    const _Shape('M8 54V16M4 16H12M4 54H12M52 54V16M48 16H56M48 54H56'),
    const _Shape('M34 18A13 13 0 1 0 34 42A14 14 0 0 1 34 18Z', fill: 0.6),
  ],
  // Heart-leaf with three dots (mockup).
  'the_empress': [
    const _Shape('M30 52C6 36 9 12 30 25C51 12 54 36 30 52Z', fill: 0.7),
    _Shape(_circle(10, 8, 1.8), fill: 1),
    _Shape(_circle(50, 8, 1.8), fill: 1),
    _Shape(_circle(30, 6, 1.8), fill: 1),
  ],
  // Crown on a throne base.
  'the_emperor': [
    const _Shape('M12 40L10 18L22 28L30 14L38 28L50 18L48 40Z', fill: 0.6),
    const _Shape('M10 48H50M16 48V55M44 48V55'),
    _Shape(_circle(10, 15, 2), inkFill: true, fill: 1),
    _Shape(_circle(30, 11, 2), inkFill: true, fill: 1),
    _Shape(_circle(50, 15, 2), inkFill: true, fill: 1),
  ],
  // Key.
  'the_hierophant': [
    _Shape(_circle(30, 16, 9), fill: 0.5),
    _Shape(_circle(30, 16, 3)),
    const _Shape('M30 25V54M30 44H38M30 50H36'),
  ],
  // Two hearts.
  'the_lovers': [
    _Shape(_heart(22, 30, 0.55), fill: 0.65),
    _Shape(_heart(38, 36, 0.55), fill: 0.35),
    const _Shape('M30 6V12M27 9H33'),
  ],
  // Wheel and banner.
  'the_chariot': [
    _Shape(_circle(22, 42, 11), fill: 0.25),
    _Shape(_rays(22, 42, 2.5, 11, _every(45))),
    _Shape(_circle(22, 42, 2.5), inkFill: true, fill: 1),
    const _Shape('M44 54V8'),
    const _Shape('M44 10L57 15L44 20Z', fill: 0.6),
  ],
  // Paw with a small infinity.
  'strength': [
    const _Shape(_infinitySmall, fill: 0.4),
    const _Shape(
      'M30 54C20 54 18 46 22 42C26 38 34 38 38 42C42 46 40 54 30 54Z',
      fill: 0.6,
    ),
    _Shape(_circle(18, 34, 4), fill: 0.6),
    _Shape(_circle(25.5, 28, 4), fill: 0.6),
    _Shape(_circle(34.5, 28, 4), fill: 0.6),
    _Shape(_circle(42, 34, 4), fill: 0.6),
  ],
  // Lantern with a flame.
  'the_hermit': [
    const _Shape('M30 6V12M22 18L30 12L38 18'),
    const _Shape('M22 18H38V42H22Z', fill: 0.25),
    const _Shape('M30 24C34 29 34 35 30 37C26 35 26 29 30 24Z', fill: 0.75),
    const _Shape('M20 42H40V47H20Z', fill: 0.5),
    const _Shape(
      'M10 30H15M45 30H50M13 20L17 23M47 20L43 23M13 40L17 37M47 40L43 37',
    ),
  ],
  // Eight-spoke wheel.
  'wheel_of_fortune': [
    _Shape(_circle(30, 30, 22)),
    _Shape(_circle(30, 30, 15), fill: 0.3),
    _Shape(_rays(30, 30, 4, 22, _every(45))),
    _Shape(_circle(30, 30, 4), fill: 0.8),
  ],
  // Scales (mockup).
  'justice': [
    const _Shape('M30 6V54M10 16H50M20 54H40'),
    const _Shape('M10 16L3 34H17ZM50 16L43 34H57Z', fill: 0.5),
  ],
  // Leaf hanging from a branch.
  'the_hanged_man': [
    const _Shape('M8 10H52M30 10V20'),
    const _Shape('M30 20C42 28 42 44 30 54C18 44 18 28 30 20Z', fill: 0.6),
    const _Shape('M30 25V48'),
    _Shape(_circle(14, 38, 1.8), fill: 1),
    _Shape(_circle(46, 38, 1.8), fill: 1),
  ],
  // Sunrise over the horizon.
  'death': [
    const _Shape('M16 44A14 14 0 0 1 44 44Z', fill: 0.6),
    _Shape(_rays(30, 44, 18, 24, [-162, -126, -90, -54, -18])),
    const _Shape('M4 44H56M14 50H24M36 50H46M22 55H38'),
  ],
  // Two cups with a flowing stream.
  'temperance': [
    const _Shape('M8 12H24L22 24H10Z', fill: 0.5),
    const _Shape('M36 40H52L50 52H38Z', fill: 0.5),
    const _Shape('M23 18C34 20 30 34 42 38'),
    _Shape(_drop(32, 26, 0.6), fill: 0.7),
  ],
  // Two linked rings.
  'the_devil': [
    _Shape(_circle(23, 30, 12), fill: 0.5),
    _Shape(_circle(37, 30, 12), fill: 0.25),
    const _Shape('M30 6V11M27.5 8.5H32.5M30 49V54M27.5 51.5H32.5'),
  ],
  // Tower struck by lightning.
  'the_tower': [
    const _Shape('M14 54L17 22H31L34 54Z', fill: 0.35),
    const _Shape('M15 22V16H19V19H22V16H26V19H29V16H33V22'),
    const _Shape('M21 54V47A3 3 0 0 1 27 47V54'),
    const _Shape('M22 30H26V36H22Z'),
    const _Shape('M6 54H54'),
    const _Shape('M50 4L41 18H47L39 32L54 14H47L52 4Z', fill: 0.7),
  ],
  // Star over water (mockup).
  'the_star': [
    _Shape(_star(30, 26, 20, 8, 8), fill: 0.6),
    const _Shape('M6 52q6-5 12 0t12 0 12 0 12 0'),
  ],
  // Crescent and falling drops.
  'the_moon': [
    const _Shape('M36 8A19 19 0 1 0 36 44A24 24 0 0 1 36 8Z', fill: 0.6),
    _Shape(_drop(14, 47, 1), fill: 0.5),
    _Shape(_drop(26, 51, 1), fill: 0.5),
    _Shape(_drop(46, 49, 1), fill: 0.5),
  ],
  // Sun with 12 rays (mockup).
  'the_sun': [
    _Shape(_circle(30, 30, 10), fill: 1, stroke: false),
    _Shape(_rays(30, 30, 15, 23, _every(30))),
  ],
  // Bell with sound waves.
  'judgement': [
    const _Shape('M18 42C18 30 20 14 30 14C40 14 42 30 42 42Z', fill: 0.6),
    const _Shape('M14 42H46M30 14V10'),
    _Shape(_circle(30, 7.5, 2.5)),
    _Shape(_circle(30, 47, 3), inkFill: true, fill: 1),
    const _Shape('M8 24C5 28 5 34 8 38M52 24C55 28 55 34 52 38'),
  ],
  // Laurel wreath around a sparkle.
  'the_world': [
    _Shape(_circle(30, 30, 20)),
    _Shape(_wreathLeaves(), fill: 0.55),
    _Shape(_star(30, 30, 9, 2.6, 4), fill: 0.7),
  ],
};

// ---------------------------------------------------------------------------
// Tiny SVG path-data parser (M L H V C S Q T A Z, absolute + relative)

final Map<String, Path> _pathCache = {};

Path _svgPath(String d) => _pathCache.putIfAbsent(d, () => _parseSvgPath(d));

final RegExp _pathToken = RegExp(
  r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
);
final RegExp _isCommand = RegExp(r'^[A-Za-z]$');

Path _parseSvgPath(String d) {
  final toks = [for (final m in _pathToken.allMatches(d)) m.group(0)!];
  final path = Path();
  var i = 0;
  var cmd = 'M';
  var last = '';
  double x = 0, y = 0, startX = 0, startY = 0;
  double c2x = 0, c2y = 0, qx = 0, qy = 0;
  double n() => double.parse(toks[i++]);

  while (i < toks.length) {
    if (_isCommand.hasMatch(toks[i])) cmd = toks[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0;
    final oy = rel ? y : 0.0;
    final upper = cmd.toUpperCase();
    switch (upper) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
      case 'C':
        final x1 = ox + n(), y1 = oy + n();
        c2x = ox + n();
        c2y = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, c2x, c2y, x, y);
      case 'S':
        final smooth = last == 'C' || last == 'S';
        final x1 = smooth ? 2 * x - c2x : x;
        final y1 = smooth ? 2 * y - c2y : y;
        c2x = ox + n();
        c2y = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, c2x, c2y, x, y);
      case 'Q':
        qx = ox + n();
        qy = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(qx, qy, x, y);
      case 'T':
        final smooth = last == 'Q' || last == 'T';
        qx = smooth ? 2 * x - qx : x;
        qy = smooth ? 2 * y - qy : y;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(qx, qy, x, y);
      case 'A':
        final rx = n(), ry = n(), rot = n();
        final large = n() != 0, sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        // Stray numbers after Z are invalid; stop instead of looping.
        if (i < toks.length && !_isCommand.hasMatch(toks[i])) return path;
      default:
        return path;
    }
    last = upper;
  }
  return path;
}

// ---------------------------------------------------------------------------
// Painters

void _paintCentered(
  Canvas canvas,
  String text,
  TextStyle style, {
  required double baseline,
  double maxWidth = 98,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth * 1.6);
  // Letter spacing trails the last glyph; nudge it back to true center.
  final trailing = style.letterSpacing ?? 0;
  final width = tp.width - (trailing > 0 ? trailing : 0);
  final scale = width > maxWidth ? maxWidth / width : 1.0;
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  canvas
    ..save()
    ..translate(60, baseline)
    ..scale(scale);
  tp.paint(canvas, Offset(-width / 2, -base));
  canvas.restore();
  tp.dispose();
}

/// Scales the canvas so (0,0)-(120,200) fills [size], centered.
void _enterViewBox(Canvas canvas, Size size) {
  final s = math.min(size.width / 120, size.height / 200);
  canvas
    ..translate((size.width - 120 * s) / 2, (size.height - 200 * s) / 2)
    ..scale(s);
}

class _TarotFacePainter extends CustomPainter {
  _TarotFacePainter({
    required this.cardKey,
    required this.roman,
    required this.name,
    required this.palette,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  final String cardKey;
  final String roman;
  final String name;
  final _Palette palette;

  static final Path _arch = _parseSvgPath('M20 160V78A40 40 0 0 1 100 78V160Z');

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ink = palette.ink;
    canvas.save();
    _enterViewBox(canvas, size);

    final outer = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, 1.5, 117, 197),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.top, palette.bottom],
        ).createShader(outer.outerRect),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ink.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 106, 186),
        const Radius.circular(8),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.25),
    );

    canvas
      ..drawPath(
        _arch,
        Paint()..color = V2Colors.surface.withValues(alpha: 0.5),
      )
      ..drawPath(
        _arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink.withValues(alpha: 0.35),
      );

    _paintEmblem(canvas, _emblems[cardKey] ?? _genericEmblem);

    // Below ~56px the type is unreadable; the art alone carries the card.
    if (size.width >= 56) {
      if (roman.isNotEmpty) {
        _paintCentered(
          canvas,
          roman,
          V2Text.serif(
            size: 13,
            weight: FontWeight.w400,
            color: ink,
            letterSpacing: 3,
            height: 1,
          ),
          baseline: 27,
        );
      }
      _paintCentered(
        canvas,
        name,
        V2Text.serif(size: 14, color: ink, height: 1),
        baseline: 180,
      );
    }
    canvas.restore();
  }

  void _paintEmblem(Canvas canvas, List<_Shape> shapes) {
    canvas
      ..save()
      ..translate(24, 70)
      ..scale(1.2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = palette.ink;
    for (final shape in shapes) {
      final path = _svgPath(shape.d);
      if (shape.fill > 0) {
        final base = shape.inkFill ? palette.ink : palette.accent;
        canvas.drawPath(
          path,
          Paint()..color = base.withValues(alpha: shape.fill),
        );
      }
      if (shape.stroke) canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TarotFacePainter old) =>
      old.cardKey != cardKey ||
      old.name != name ||
      old.roman != roman ||
      old.palette != palette;
}

class _TarotBackPainter extends CustomPainter {
  static final Path _star16 = _svgPath(_star(60, 100, 34, 14, 8));
  static final List<Path> _sparkles = [
    for (final c in const [
      Offset(24, 24),
      Offset(96, 24),
      Offset(24, 176),
      Offset(96, 176),
    ])
      _svgPath(_star(c.dx, c.dy, 6, 2.4, 4)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    _enterViewBox(canvas, size);
    final white = V2Colors.surface;

    final outer = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1.5, 1.5, 117, 197),
      const Radius.circular(12),
    );
    canvas
      ..drawRRect(
        outer,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [V2Colors.lilac, V2Colors.lilacText],
          ).createShader(outer.outerRect),
      )
      ..drawRRect(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = white.withValues(alpha: 0.6),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 104, 184),
          const Radius.circular(8),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = white.withValues(alpha: 0.45),
      )
      ..drawCircle(
        const Offset(60, 100),
        44,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = white.withValues(alpha: 0.5),
      );

    // Dashed ring (2 on, 4 off).
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = white.withValues(alpha: 0.25);
    const r = 50.0;
    final ring = Rect.fromCircle(center: const Offset(60, 100), radius: r);
    final count = (2 * math.pi * r / 6).floor();
    final step = 2 * math.pi / count;
    for (var k = 0; k < count; k++) {
      canvas.drawArc(ring, k * step, 2 / r, false, dash);
    }

    canvas
      ..drawPath(
        _star16,
        Paint()..color = V2Colors.roseSoft.withValues(alpha: 0.92),
      )
      ..drawCircle(const Offset(60, 100), 6, Paint()..color = V2Colors.lilac);
    final sparkle = Paint()..color = white.withValues(alpha: 0.8);
    for (final p in _sparkles) {
      canvas.drawPath(p, sparkle);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TarotBackPainter old) => false;
}
