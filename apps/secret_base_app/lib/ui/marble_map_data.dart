import 'package:flutter/material.dart';

enum MarbleTileType { start, jail, event, free, property, shortcut, center }

class MarbleTile {
  final int pos;
  final MarbleTileType type;
  final String name;
  final String emoji;
  final Color color;
  final int price;

  const MarbleTile({
    required this.pos,
    required this.type,
    required this.name,
    required this.emoji,
    required this.color,
    this.price = 0,
  });
}

const _kPink   = Color(0xFFE8305A);
const _kOrange = Color(0xFFF97316);
const _kPurple = Color(0xFF7C3AED);
const _kGreen  = Color(0xFF16A34A);
const _kBrown  = Color(0xFF92400E);
const _kTeal   = Color(0xFF0891B2);
const _kGold   = Color(0xFFD97706);
const _kSlate  = Color(0xFF374151);
const _kBlue   = Color(0xFF0284C7);
const _kEmerald = Color(0xFF059669);

const List<MarbleTile> kClassicWorldTiles = [
  // Corners
  MarbleTile(pos: 0,  type: MarbleTileType.start, name: '출발',    emoji: '🚀', color: _kGold),
  MarbleTile(pos: 5,  type: MarbleTileType.jail,  name: '감옥섬',  emoji: '⛓️', color: _kSlate),
  MarbleTile(pos: 10, type: MarbleTileType.event, name: '황금도시', emoji: '🌟', color: _kBlue),
  MarbleTile(pos: 15, type: MarbleTileType.free,  name: '자유여행', emoji: '🏝️', color: _kEmerald),

  // Bottom side — Korean cities (pink)
  MarbleTile(pos: 1, type: MarbleTileType.property, name: '제주',  emoji: '🌸', color: _kPink,   price: 100),
  MarbleTile(pos: 2, type: MarbleTileType.property, name: '부산',  emoji: '🐟', color: _kPink,   price: 130),
  MarbleTile(pos: 3, type: MarbleTileType.property, name: '경주',  emoji: '🏯', color: _kPink,   price: 160),
  MarbleTile(pos: 4, type: MarbleTileType.property, name: '인천',  emoji: '✈️', color: _kPink,   price: 200),

  // Right side — East Asian cities (orange)
  MarbleTile(pos: 6, type: MarbleTileType.property, name: '도쿄',    emoji: '⛩️', color: _kOrange, price: 250),
  MarbleTile(pos: 7, type: MarbleTileType.property, name: '상하이',  emoji: '🏮', color: _kOrange, price: 300),
  MarbleTile(pos: 8, type: MarbleTileType.property, name: '홍콩',    emoji: '🌃', color: _kOrange, price: 350),
  MarbleTile(pos: 9, type: MarbleTileType.property, name: '싱가포르', emoji: '🦁', color: _kOrange, price: 400),

  // Top side — Global cities (purple)
  MarbleTile(pos: 11, type: MarbleTileType.property, name: '두바이', emoji: '🕌', color: _kPurple, price: 500),
  MarbleTile(pos: 12, type: MarbleTileType.property, name: '파리',   emoji: '🗼', color: _kPurple, price: 600),
  MarbleTile(pos: 13, type: MarbleTileType.property, name: '런던',   emoji: '🎡', color: _kPurple, price: 700),
  MarbleTile(pos: 14, type: MarbleTileType.property, name: '뉴욕',   emoji: '🗽', color: _kPurple, price: 800),

  // Left side — Americas / Pacific (green)
  MarbleTile(pos: 16, type: MarbleTileType.property, name: '하와이',    emoji: '🌺', color: _kGreen, price: 700),
  MarbleTile(pos: 17, type: MarbleTileType.property, name: '시드니',    emoji: '🦘', color: _kGreen, price: 600),
  MarbleTile(pos: 18, type: MarbleTileType.property, name: '라스베가스', emoji: '🎰', color: _kGreen, price: 500),
  MarbleTile(pos: 19, type: MarbleTileType.property, name: '서울',      emoji: '🌸', color: _kGreen, price: 400),

  // Diagonal A: 5 → 21 → 22 → 23 → 28 → 29 → 15  (brown)
  MarbleTile(pos: 21, type: MarbleTileType.shortcut, name: '이스탄불', emoji: '🕌', color: _kBrown, price: 300),
  MarbleTile(pos: 22, type: MarbleTileType.shortcut, name: '모스크바', emoji: '⭐', color: _kBrown, price: 350),
  MarbleTile(pos: 28, type: MarbleTileType.shortcut, name: '취리히',   emoji: '🏔️', color: _kBrown, price: 350),
  MarbleTile(pos: 29, type: MarbleTileType.shortcut, name: '빈',       emoji: '🎼', color: _kBrown, price: 300),

  // Diagonal B: 10 → 24 → 25 → 23 → 26 → 27 → 0  (teal)
  MarbleTile(pos: 24, type: MarbleTileType.shortcut, name: '멕시코',   emoji: '🌵', color: _kTeal, price: 250),
  MarbleTile(pos: 25, type: MarbleTileType.shortcut, name: '리우',     emoji: '🎭', color: _kTeal, price: 300),
  MarbleTile(pos: 26, type: MarbleTileType.shortcut, name: '바르셀로나', emoji: '⛵', color: _kTeal, price: 400),
  MarbleTile(pos: 27, type: MarbleTileType.shortcut, name: '로마',     emoji: '🏛️', color: _kTeal, price: 450),

  // Center
  MarbleTile(pos: 23, type: MarbleTileType.center, name: '세계중심', emoji: '🌐', color: Color(0xFF6B21A8)),
];

final Map<int, MarbleTile> kTileByPos = {
  for (final t in kClassicWorldTiles) t.pos: t,
};

// Board geometry (logical 560×560 coordinate space)
const double kBoardUnit = 560.0;
const double kCornerSize = 80.0;
const double kSideLength = (kBoardUnit - kCornerSize * 2) / 4; // = 100

// Returns the normalized center (0.0–1.0) for a board position
Offset marbleNormalizedCenter(int pos) {
  const double c = kCornerSize / kBoardUnit;     // 80/560 ≈ 0.143
  const double s = kSideLength / kBoardUnit;     // 100/560 ≈ 0.179
  const double ch = c / 2;                       // half corner
  const double sh = s / 2;                       // half side tile

  switch (pos) {
    // Perimeter — bottom side (left→right)
    case 0: case 20: return Offset(ch, 1.0 - ch);
    case 1:  return Offset(c + sh,         1.0 - ch);
    case 2:  return Offset(c + s + sh,     1.0 - ch);
    case 3:  return Offset(c + s * 2 + sh, 1.0 - ch);
    case 4:  return Offset(c + s * 3 + sh, 1.0 - ch);
    case 5:  return Offset(1.0 - ch,       1.0 - ch);

    // Right side (bottom→top)
    case 6:  return Offset(1.0 - ch, 1.0 - c - sh);
    case 7:  return Offset(1.0 - ch, 1.0 - c - s - sh);
    case 8:  return Offset(1.0 - ch, 1.0 - c - s * 2 - sh);
    case 9:  return Offset(1.0 - ch, 1.0 - c - s * 3 - sh);
    case 10: return Offset(1.0 - ch, ch);

    // Top side (right→left)
    case 11: return Offset(1.0 - c - sh,         ch);
    case 12: return Offset(1.0 - c - s - sh,     ch);
    case 13: return Offset(1.0 - c - s * 2 - sh, ch);
    case 14: return Offset(1.0 - c - s * 3 - sh, ch);
    case 15: return Offset(ch, ch);

    // Left side (top→bottom)
    case 16: return Offset(ch, c + sh);
    case 17: return Offset(ch, c + s + sh);
    case 18: return Offset(ch, c + s * 2 + sh);
    case 19: return Offset(ch, c + s * 3 + sh);

    // Diagonal A: 5 → 21 → 22 → 23 → 28 → 29 → 15
    case 21: return const Offset(440 / kBoardUnit, 440 / kBoardUnit);
    case 22: return const Offset(360 / kBoardUnit, 360 / kBoardUnit);
    case 28: return const Offset(200 / kBoardUnit, 200 / kBoardUnit);
    case 29: return const Offset(120 / kBoardUnit, 120 / kBoardUnit);

    // Diagonal B: 10 → 24 → 25 → 23 → 26 → 27 → 0
    case 24: return const Offset(440 / kBoardUnit, 120 / kBoardUnit);
    case 25: return const Offset(360 / kBoardUnit, 200 / kBoardUnit);
    case 26: return const Offset(200 / kBoardUnit, 360 / kBoardUnit);
    case 27: return const Offset(120 / kBoardUnit, 440 / kBoardUnit);

    // Center crossroads
    case 23: return const Offset(0.5, 0.5);

    default: return const Offset(0.5, 0.5);
  }
}

// Returns the bounding Rect for perimeter tiles (corners/properties) in logical space.
// Returns null for diagonal / center positions.
Rect? marbleTileRect(int pos) {
  const double c = kCornerSize;
  const double s = kSideLength;

  // Bottom side
  if (pos == 0 || pos == 20) return const Rect.fromLTWH(0,             480, c, c);
  if (pos == 1)  return Rect.fromLTWH(c,             480, s, c);
  if (pos == 2)  return Rect.fromLTWH(c + s,         480, s, c);
  if (pos == 3)  return Rect.fromLTWH(c + s * 2,     480, s, c);
  if (pos == 4)  return Rect.fromLTWH(c + s * 3,     480, s, c);
  if (pos == 5)  return const Rect.fromLTWH(480,      480, c, c);

  // Right side (rotated; width is c, height is s)
  if (pos == 6)  return Rect.fromLTWH(480, 380, c, s);
  if (pos == 7)  return Rect.fromLTWH(480, 280, c, s);
  if (pos == 8)  return Rect.fromLTWH(480, 180, c, s);
  if (pos == 9)  return Rect.fromLTWH(480, 80,  c, s);
  if (pos == 10) return const Rect.fromLTWH(480, 0, c, c);

  // Top side
  if (pos == 11) return Rect.fromLTWH(380, 0, s, c);
  if (pos == 12) return Rect.fromLTWH(280, 0, s, c);
  if (pos == 13) return Rect.fromLTWH(180, 0, s, c);
  if (pos == 14) return Rect.fromLTWH(80,  0, s, c);
  if (pos == 15) return const Rect.fromLTWH(0, 0, c, c);

  // Left side
  if (pos == 16) return Rect.fromLTWH(0, 80,  c, s);
  if (pos == 17) return Rect.fromLTWH(0, 180, c, s);
  if (pos == 18) return Rect.fromLTWH(0, 280, c, s);
  if (pos == 19) return Rect.fromLTWH(0, 380, c, s);

  return null; // diagonals / center have no fixed rect
}
