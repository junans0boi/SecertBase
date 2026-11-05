import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 탱크 대작전 공통 데이터: 서버(fortress-engine.js)와 맞춰야 하는 상수, 전차·무기·
// 테마 정보, 전투 화면 팔레트와 글꼴.
// ─────────────────────────────────────────────────────────────────────────────

const int kTerrainW = 100;
const int kTerrainH = 40;
const double kTankSpeedScale = 0.35;
const double kTankGravity = 12.0;
const double kTankWindScale = 1.5;
const double kTankDt = 0.02;
const int kTankTurnMs = 30000;
const int kTankFinalTurn = 30;

/// 전투 화면 팔레트(앱의 파스텔 톤과 분리된 어두운 전투형 UI).
class TankUi {
  TankUi._();
  static const panel = Color(0xE0101624);
  static const panelSolid = Color(0xFF101624);
  static const panelHi = Color(0xFF1B2335);
  static const panelLine = Color(0x33FFFFFF);
  static const text = Color(0xFFF4F7FF);
  static const sub = Color(0xFFB4BED6);
  static const muted = Color(0xFF7783A0);
  static const me = Color(0xFF3DDC97);
  static const enemy = Color(0xFFFF5A5F);
  static const gold = Color(0xFFFFC94A);
  static const cyan = Color(0xFF4FC3F7);
  static const purple = Color(0xFFB18CFF);
  static const danger = Color(0xFFFF3B3B);
  static const fireA = Color(0xFFFF8A3D);
  static const fireB = Color(0xFFFF3D6E);
}

/// 굵은 제목·숫자용(전투 분위기).
TextStyle tankDisplay({
  double size = 20,
  Color color = TankUi.text,
  double letterSpacing = 0,
  List<Shadow>? shadows,
}) {
  return GoogleFonts.blackHanSans(
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.1,
    shadows: shadows,
  );
}

/// 본문용.
TextStyle tankBody({
  double size = 12,
  Color color = TankUi.sub,
  FontWeight weight = FontWeight.w500,
  double height = 1.35,
}) {
  return GoogleFonts.notoSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
  );
}

// ── 전차 ─────────────────────────────────────────────────────────────────────

class TankClassInfo {
  final String id;
  final String name;
  final int hp;
  final int fuel;
  final String special;
  final String passive;
  final String tagline;
  const TankClassInfo({
    required this.id,
    required this.name,
    required this.hp,
    required this.fuel,
    required this.special,
    required this.passive,
    required this.tagline,
  });
}

const Map<String, TankClassInfo> kTankClasses = {
  'rhino': TankClassInfo(
    id: 'rhino',
    name: '코뿔소',
    hp: 130,
    fuel: 24,
    special: 'quake',
    passive: '받는 피해 10% 감소',
    tagline: '두꺼운 장갑의 중전차',
  ),
  'falcon': TankClassInfo(
    id: 'falcon',
    name: '매',
    hp: 90,
    fuel: 45,
    special: 'shotgun',
    passive: '이동 연료 절반',
    tagline: '빠르게 치고 빠지는 경전차',
  ),
  'mole': TankClassInfo(
    id: 'mole',
    name: '땅굴이',
    hp: 105,
    fuel: 30,
    special: 'drill',
    passive: '낙하 피해 면역',
    tagline: '땅을 파고드는 공병 전차',
  ),
  'turtle': TankClassInfo(
    id: 'turtle',
    name: '거북',
    hp: 115,
    fuel: 28,
    special: 'wall',
    passive: '내 턴마다 HP 3 회복',
    tagline: '버티며 진지를 쌓는 방어 전차',
  ),
};

const List<String> kTankClassOrder = ['rhino', 'falcon', 'mole', 'turtle'];

// ── 무기 ─────────────────────────────────────────────────────────────────────

class TankWeaponInfo {
  final String id;
  final String name;
  final String desc;
  final IconData icon;
  final Color color;
  const TankWeaponInfo(this.id, this.name, this.desc, this.icon, this.color);
}

const Map<String, TankWeaponInfo> kTankWeapons = {
  'basic': TankWeaponInfo(
    'basic',
    '기본탄',
    '무제한 · 표준 폭발',
    Icons.circle,
    Color(0xFFFFD54F),
  ),
  'heavy': TankWeaponInfo(
    'heavy',
    '대형탄',
    '피해 55 · 큰 폭발',
    Icons.local_fire_department,
    Color(0xFFFF7043),
  ),
  'triple': TankWeaponInfo(
    'triple',
    '3연발탄',
    '3발 부채꼴 발사',
    Icons.scatter_plot,
    Color(0xFFFFB74D),
  ),
  'cluster': TankWeaponInfo(
    'cluster',
    '집속탄',
    '정점에서 4개로 분열',
    Icons.bubble_chart,
    Color(0xFF90A4AE),
  ),
  'teleport': TankWeaponInfo(
    'teleport',
    '순간이동탄',
    '떨어진 곳으로 내 전차 이동',
    Icons.blur_on,
    Color(0xFFB18CFF),
  ),
  'quake': TankWeaponInfo(
    'quake',
    '지진탄',
    '전용 · 넓은 범위 파괴',
    Icons.waves,
    Color(0xFFBCAAA4),
  ),
  'shotgun': TankWeaponInfo(
    'shotgun',
    '산탄',
    '전용 · 5발 확산',
    Icons.grain,
    Color(0xFFFFE082),
  ),
  'drill': TankWeaponInfo(
    'drill',
    '드릴탄',
    '전용 · 땅을 뚫고 폭발',
    Icons.construction,
    Color(0xFFCFD8DC),
  ),
  'wall': TankWeaponInfo(
    'wall',
    '방벽탄',
    '전용 · 흙 언덕 생성',
    Icons.landscape,
    Color(0xFF8BC34A),
  ),
};

const List<String> kTankWeaponOrder = [
  'basic',
  'heavy',
  'triple',
  'cluster',
  'teleport',
  'quake',
  'shotgun',
  'drill',
  'wall',
];

const Map<String, String> kTankCrateNames = {
  'repair': '수리 키트',
  'power': '화력 강화',
  'shield': '보호막',
  'fuel': '연료 통',
  'ammo': '탄약 상자',
};

// ── 테마 ─────────────────────────────────────────────────────────────────────

enum TankWeather { leaves, sand, snow, stars }

class TankThemeLook {
  final String id;
  final String name;
  final String hint;

  /// 하늘 위→아래 세 색.
  final List<Color> sky;
  final Color groundTop;
  final Color ground;
  final Color groundDeep;
  final Color surface;
  final Color far;
  final Color near;
  final Color cloud;
  final Color celestial;
  final TankWeather weather;
  const TankThemeLook({
    required this.id,
    required this.name,
    required this.hint,
    required this.sky,
    required this.groundTop,
    required this.ground,
    required this.groundDeep,
    required this.surface,
    required this.far,
    required this.near,
    required this.cloud,
    required this.celestial,
    required this.weather,
  });
}

const Map<String, TankThemeLook> kTankThemes = {
  'meadow': TankThemeLook(
    id: 'meadow',
    name: '초원',
    hint: '바람 보통',
    sky: [Color(0xFF4FA3E0), Color(0xFF8CCBF0), Color(0xFFE3F4FF)],
    groundTop: Color(0xFF6DA544),
    ground: Color(0xFF5B7F33),
    groundDeep: Color(0xFF3B4A22),
    surface: Color(0xFF9BD65A),
    far: Color(0xFF9CC7C2),
    near: Color(0xFF6FA88E),
    cloud: Color(0xFFFFFFFF),
    celestial: Color(0xFFFFF3B0),
    weather: TankWeather.leaves,
  ),
  'desert': TankThemeLook(
    id: 'desert',
    name: '사막',
    hint: '언덕이 높고 바람이 세요',
    sky: [Color(0xFFE0703A), Color(0xFFF4A65C), Color(0xFFFFE1A8)],
    groundTop: Color(0xFFE2A85E),
    ground: Color(0xFFC88A47),
    groundDeep: Color(0xFF7E5128),
    surface: Color(0xFFF5CD8A),
    far: Color(0xFFE9B67F),
    near: Color(0xFFD8995E),
    cloud: Color(0xFFFFE9C9),
    celestial: Color(0xFFFFF0C2),
    weather: TankWeather.sand,
  ),
  'snow': TankThemeLook(
    id: 'snow',
    name: '설원',
    hint: '바람이 매우 강해요',
    sky: [Color(0xFF6F8FB8), Color(0xFFA9C1DD), Color(0xFFEFF5FC)],
    groundTop: Color(0xFFDCE6F0),
    ground: Color(0xFFA9B8C8),
    groundDeep: Color(0xFF65748A),
    surface: Color(0xFFFFFFFF),
    far: Color(0xFFC9D7E6),
    near: Color(0xFFAFC1D6),
    cloud: Color(0xFFF4F8FC),
    celestial: Color(0xFFFFFDF2),
    weather: TankWeather.snow,
  ),
  'moon': TankThemeLook(
    id: 'moon',
    name: '달',
    hint: '중력이 약하고 바람이 없어요',
    sky: [Color(0xFF070616), Color(0xFF16133A), Color(0xFF2E2A58)],
    groundTop: Color(0xFFA3A3B4),
    ground: Color(0xFF77778A),
    groundDeep: Color(0xFF414152),
    surface: Color(0xFFCACAD8),
    far: Color(0xFF2F2C5A),
    near: Color(0xFF433F72),
    cloud: Color(0x00000000),
    celestial: Color(0xFF4FA3E0),
    weather: TankWeather.stars,
  ),
};

TankThemeLook tankThemeOf(Map<String, dynamic>? state) =>
    kTankThemes[state?['theme'] as String? ?? 'meadow'] ??
    kTankThemes['meadow']!;
