import 'package:flutter/material.dart';

enum MarbleTileType {
  start,    // 임무개시
  jail,     // 블랙사이트
  tax,      // 운영본부
  gate,     // 비밀게이트
  property, // 도시
  tourist,  // 관광지 (비밀의 섬/해변)
  card,     // 작전카드
}

class MarbleTile {
  final int pos;
  final MarbleTileType type;
  final String name;
  final String emoji;
  final Color color;
  final int price; // 구매가 (MM)

  const MarbleTile({
    required this.pos,
    required this.type,
    required this.name,
    required this.emoji,
    required this.color,
    this.price = 0,
  });
}

// ── Color palette ────────────────────────────────────────────────────────────
const _kRed    = Color(0xFFE8305A);
const _kOrange = Color(0xFFEA7D27);
const _kGreen  = Color(0xFF16A34A);
const _kBlue   = Color(0xFF2563EB);
const _kPurple = Color(0xFF7C3AED);
const _kGold   = Color(0xFFF59E0B);
const _kTourist = Color(0xFFEC4899);
const _kCard   = Color(0xFF0EA5E9);

// ── 24-tile board (clockwise from bottom-left corner) ───────────────────────
//
//  Layout:
//   pos  0 = 임무개시 (START, bottom-left corner)
//   pos  1 = 방콕      (red)
//   pos  2 = 카이로    (red)
//   pos  3 = 작전카드  (card)
//   pos  4 = 뭄바이    (orange)
//   pos  5 = 자카르타  (orange)
//   pos  6 = 블랙사이트 (JAIL, bottom-right corner)
//   pos  7 = 시드니    (green)
//   pos  8 = 비밀의섬  (tourist)
//   pos  9 = 작전카드  (card)
//   pos 10 = 베를린    (green)
//   pos 11 = 모스크바  (green)
//   pos 12 = 운영본부  (TAX, top-right corner)
//   pos 13 = 도쿄      (blue)
//   pos 14 = 상하이    (blue)
//   pos 15 = 작전카드  (card)
//   pos 16 = 뉴욕      (purple)
//   pos 17 = 비밀의해변 (tourist)
//   pos 18 = 비밀게이트 (GATE, top-left corner)
//   pos 19 = 파리      (purple)
//   pos 20 = 런던      (gold)
//   pos 21 = 작전카드  (card)
//   pos 22 = 두바이    (gold)
//   pos 23 = 서울      (gold)
//
const List<MarbleTile> kBoardTiles = [
  // ── Corners ──
  MarbleTile(pos:  0, type: MarbleTileType.start,   name: '임무개시',  emoji: '🚀', color: Color(0xFF22C55E)),
  MarbleTile(pos:  6, type: MarbleTileType.jail,    name: '블랙사이트', emoji: '⛓️', color: Color(0xFF6B7280)),
  MarbleTile(pos: 12, type: MarbleTileType.tax,     name: '운영본부',  emoji: '🏦', color: Color(0xFF6B7280)),
  MarbleTile(pos: 18, type: MarbleTileType.gate,    name: '비밀게이트', emoji: '🌀', color: Color(0xFF0891B2)),

  // ── Bottom side (pos 1–5) ──
  MarbleTile(pos: 1, type: MarbleTileType.property, name: '방콕',    emoji: '🏯', color: _kRed,    price: 500000),
  MarbleTile(pos: 2, type: MarbleTileType.property, name: '카이로',  emoji: '🐪', color: _kRed,    price: 500000),
  MarbleTile(pos: 3, type: MarbleTileType.card,     name: '작전카드', emoji: '🃏', color: _kCard),
  MarbleTile(pos: 4, type: MarbleTileType.property, name: '뭄바이',  emoji: '🕌', color: _kOrange, price: 700000),
  MarbleTile(pos: 5, type: MarbleTileType.property, name: '자카르타', emoji: '🌴', color: _kOrange, price: 700000),

  // ── Right side (pos 7–11) ──
  MarbleTile(pos:  7, type: MarbleTileType.property, name: '시드니',   emoji: '🦘', color: _kGreen,   price: 1000000),
  MarbleTile(pos:  8, type: MarbleTileType.tourist,  name: '비밀의섬', emoji: '🏝️', color: _kTourist, price: 1000000),
  MarbleTile(pos:  9, type: MarbleTileType.card,     name: '작전카드', emoji: '🃏', color: _kCard),
  MarbleTile(pos: 10, type: MarbleTileType.property, name: '베를린',   emoji: '🧱', color: _kGreen,   price: 1000000),
  MarbleTile(pos: 11, type: MarbleTileType.property, name: '모스크바', emoji: '🏛️', color: _kGreen,   price: 1000000),

  // ── Top side (pos 13–17) ──
  MarbleTile(pos: 13, type: MarbleTileType.property, name: '도쿄',     emoji: '⛩️', color: _kBlue,    price: 1300000),
  MarbleTile(pos: 14, type: MarbleTileType.property, name: '상하이',   emoji: '🏙️', color: _kBlue,    price: 1300000),
  MarbleTile(pos: 15, type: MarbleTileType.card,     name: '작전카드', emoji: '🃏', color: _kCard),
  MarbleTile(pos: 16, type: MarbleTileType.property, name: '뉴욕',     emoji: '🗽', color: _kPurple,  price: 1600000),
  MarbleTile(pos: 17, type: MarbleTileType.tourist,  name: '비밀의해변', emoji: '🏖️', color: _kTourist, price: 1000000),

  // ── Left side (pos 19–23) ──
  MarbleTile(pos: 19, type: MarbleTileType.property, name: '파리',   emoji: '🗼', color: _kPurple, price: 1600000),
  MarbleTile(pos: 20, type: MarbleTileType.property, name: '런던',   emoji: '🎡', color: _kGold,   price: 2000000),
  MarbleTile(pos: 21, type: MarbleTileType.card,     name: '작전카드', emoji: '🃏', color: _kCard),
  MarbleTile(pos: 22, type: MarbleTileType.property, name: '두바이', emoji: '🌆', color: _kGold,   price: 2000000),
  MarbleTile(pos: 23, type: MarbleTileType.property, name: '서울',   emoji: '🏙️', color: _kGold,   price: 2000000),
];

final Map<int, MarbleTile> kTileByPos = {
  for (final t in kBoardTiles) t.pos: t,
};

// ── Board geometry (logical 560×560 coordinate space) ──────────────────────
//
//  24-tile board: 4 corners + 5 non-corner tiles per side.
//  Corners at pos 0(BL), 6(BR), 12(TR), 18(TL).
//
const double kBoardUnit  = 560.0;
const double kCornerSize = 70.0;
const double kSideLength = 84.0; // (560 - 70*2) / 5 = 84 exactly

// Returns the normalized center [0.0, 1.0] of each tile.
Offset marbleNormalizedCenter(int pos) {
  const double c  = kCornerSize / kBoardUnit; // 70/560 ≈ 0.125
  const double s  = kSideLength / kBoardUnit; // 84/560 = 0.15
  const double ch = c / 2;                    // corner half
  const double sh = s / 2;                    // side half

  // Corners
  if (pos ==  0) return Offset(ch, 1.0 - ch);           // bottom-left
  if (pos ==  6) return Offset(1.0 - ch, 1.0 - ch);     // bottom-right
  if (pos == 12) return Offset(1.0 - ch, ch);            // top-right
  if (pos == 18) return Offset(ch, ch);                  // top-left

  // Bottom side (pos 1–5, left→right)
  if (pos >= 1 && pos <= 5)   return Offset(c + (pos - 1) * s + sh, 1.0 - ch);

  // Right side (pos 7–11, bottom→top)
  if (pos >= 7 && pos <= 11)  return Offset(1.0 - ch, 1.0 - c - (pos - 6) * s + sh);

  // Top side (pos 13–17, right→left)
  if (pos >= 13 && pos <= 17) return Offset(1.0 - c - (pos - 12) * s + sh, ch);

  // Left side (pos 19–23, top→bottom)
  if (pos >= 19 && pos <= 23) return Offset(ch, c + (pos - 19) * s + sh);

  return const Offset(0.5, 0.5);
}

// Returns the bounding Rect for each tile in the 560×560 logical space.
Rect? marbleTileRect(int pos) {
  const double c = kCornerSize; // 70
  const double s = kSideLength; // 84
  const double b = kBoardUnit;  // 560

  // Corners
  if (pos ==  0) return Rect.fromLTWH(0,       b - c, c,     c);
  if (pos ==  6) return Rect.fromLTWH(b - c,   b - c, c,     c);
  if (pos == 12) return Rect.fromLTWH(b - c,   0,     c,     c);
  if (pos == 18) return const Rect.fromLTWH(0, 0,     70,   70);

  // Bottom side (pos 1–5)
  if (pos >= 1  && pos <= 5)  return Rect.fromLTWH(c + (pos - 1) * s,          b - c, s, c);

  // Right side (pos 7–11)
  if (pos >= 7  && pos <= 11) return Rect.fromLTWH(b - c, b - c - (pos - 6)  * s, c, s);

  // Top side (pos 13–17)
  if (pos >= 13 && pos <= 17) return Rect.fromLTWH(b - c - (pos - 12) * s,    0,   s, c);

  // Left side (pos 19–23)
  if (pos >= 19 && pos <= 23) return Rect.fromLTWH(0, c + (pos - 19) * s,         c, s);

  return null;
}

// ── Economy helpers ──────────────────────────────────────────────────────────

const _kBuildCosts = {
  'red':    [200000,   500000,  1000000],
  'orange': [300000,   700000,  1400000],
  'green':  [400000,  1000000,  2000000],
  'blue':   [600000,  1300000,  2600000],
  'purple': [800000,  1600000,  3200000],
  'gold':  [1000000,  2000000,  4000000],
};

const _kTolls = {
  'red':    [20000,   80000,  250000,   700000],
  'orange': [30000,  120000,  380000,  1000000],
  'green':  [50000,  180000,  550000,  1500000],
  'blue':   [70000,  250000,  780000,  2100000],
  'purple': [90000,  320000, 1000000,  2700000],
  'gold':  [120000,  450000, 1400000,  3800000],
};

String tileColorOf(int pos) {
  final t = kTileByPos[pos];
  if (t == null) return '';
  if (t.type == MarbleTileType.property) {
    if (t.color == _kRed)    return 'red';
    if (t.color == _kOrange) return 'orange';
    if (t.color == _kGreen)  return 'green';
    if (t.color == _kBlue)   return 'blue';
    if (t.color == _kPurple) return 'purple';
    if (t.color == _kGold)   return 'gold';
  }
  return '';
}

/// Build cost (MM) for targetLevel: 1=house, 2=building, 3=landmark.
int buildCostFor(int pos, int targetLevel) {
  final color = tileColorOf(pos);
  final costs = _kBuildCosts[color];
  if (costs == null || targetLevel < 1 || targetLevel > 3) return 0;
  return costs[targetLevel - 1];
}

/// Toll (MM) for visiting pos at level (0=land, 1=house, 2=building, 3=landmark).
int tollFor(int pos, int level) {
  final t = kTileByPos[pos];
  if (t == null) return 0;
  if (t.type == MarbleTileType.tourist) return 800000; // 관광지 고정
  final color = tileColorOf(pos);
  final tolls = _kTolls[color];
  if (tolls == null) return 0;
  return tolls[level.clamp(0, 3)];
}

/// Acquisition cost = (price + invested buildCosts up to currentLevel) × 2
int acquireCostFor(int pos, int currentLevel) {
  final t = kTileByPos[pos];
  if (t == null || t.type == MarbleTileType.tourist) return 0;
  final color = tileColorOf(pos);
  final costs = _kBuildCosts[color] ?? [];
  int invested = t.price;
  for (int i = 0; i < currentLevel && i < costs.length; i++) {
    invested += costs[i];
  }
  return invested * 2;
}

/// Display price string, e.g. "50만 MM" or "500만 MM"
String formatMM(int amount) {
  if (amount == 0) return '0 MM';
  final man = amount ~/ 10000;
  if (man >= 100) return '${man ~/ 100}백만 MM';
  return '$man만 MM';
}
