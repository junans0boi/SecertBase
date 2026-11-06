import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widgets/play_kit/play_kit.dart';

/// 윷놀이 화면 색(낮·밤). 서버가 판마다 `theme: 'day'|'night'`를 정해 두 사람이 같은 화면을 본다.
@immutable
class YutPalette {
  final bool night;
  final GameTheme theme;

  final Color ink;
  final Color sub;
  final Color acc;
  final Color acc2; // 버튼 아래 5px 진한 가장자리
  final Color onAcc;
  final Color accText;
  final Color glow;
  final Color panel;
  final Color panelEdge;
  final Color glass;
  final Color glassEdge;
  final Color me;
  final Color opp;
  final Color shadow;

  // 판(타일)
  final Color tileRim;
  final Color tileField;
  final Color tileInner;
  final Color tileSide;
  final Color tileSide2;
  final Color tileLine;
  final Color tileLineHl;
  final Color pegTop;
  final Color pegSide;

  // 다섯 자리(청·적·백·흑·황)의 윗면/옆면
  final Map<String, (Color, Color)> station;

  // 던지는 돗자리·받침
  final Color mat;
  final Color matLine;
  final Color matEdge;
  final Color plate;
  final Color plateSide;
  final Color btnDisabled;
  final Color btnDisabledEdge;
  final Color ray;
  final Color scrim;
  final Color yellow;
  final Color stationLabel;

  const YutPalette._({
    required this.night,
    required this.theme,
    required this.ink,
    required this.sub,
    required this.acc,
    required this.acc2,
    required this.onAcc,
    required this.accText,
    required this.glow,
    required this.panel,
    required this.panelEdge,
    required this.glass,
    required this.glassEdge,
    required this.me,
    required this.opp,
    required this.shadow,
    required this.tileRim,
    required this.tileField,
    required this.tileInner,
    required this.tileSide,
    required this.tileSide2,
    required this.tileLine,
    required this.tileLineHl,
    required this.pegTop,
    required this.pegSide,
    required this.station,
    required this.mat,
    required this.matLine,
    required this.matEdge,
    required this.plate,
    required this.plateSide,
    required this.btnDisabled,
    required this.btnDisabledEdge,
    required this.ray,
    required this.scrim,
    required this.yellow,
    required this.stationLabel,
  });

  static const daylight = YutPalette._(
    night: false,
    theme: GameTheme.yutDay,
    ink: Color(0xFF26325A),
    sub: Color(0xFF6B7899),
    acc: Color(0xFFFF7043),
    acc2: Color(0xFFD4491C),
    onAcc: Colors.white,
    accText: Color(0xFFD9501F),
    glow: Color(0x8CFF7043),
    panel: Colors.white,
    panelEdge: Color(0xFFC6D9EA),
    glass: Color(0xB3FFFFFF),
    glassEdge: Color(0x4D6E8CB9),
    me: Color(0xFFFF7043),
    opp: Color(0xFF3F8CFF),
    shadow: Color(0x613C5F96),
    tileRim: Color(0xFFFFF9EE),
    tileField: Color(0xFFFFE8CC),
    tileInner: Color(0x73D6A064),
    tileSide: Color(0xFFE9C99F),
    tileSide2: Color(0xFFD6AE82),
    tileLine: Color(0xFFE5B67C),
    tileLineHl: Colors.white,
    pegTop: Colors.white,
    pegSide: Color(0xFFE7CFAC),
    station: {
      'blue': (Color(0xFF9DCCFF), Color(0xFF6AA3E6)),
      'red': (Color(0xFFFFB3A5), Color(0xFFE68576)),
      'white': (Color(0xFFFFFFFF), Color(0xFFCFD8E6)),
      'black': (Color(0xFF8993AC), Color(0xFF5B6684)),
      'yellow': (Color(0xFFFFE18C), Color(0xFFE5B953)),
    },
    mat: Color(0xFFBFE3D4),
    matLine: Color(0x59FFFFFF),
    matEdge: Color(0xFF8FC4B0),
    plate: Colors.white,
    plateSide: Color(0xFFD3DFEC),
    btnDisabled: Color(0xFFD8E2EC),
    btnDisabledEdge: Color(0xFFBCCADA),
    ray: Color(0x8CFFFFFF),
    scrim: Color(0x47284678),
    yellow: Color(0xFFFFD35A),
    stationLabel: Color(0xFF2B3358),
  );

  static const moonlight = YutPalette._(
    night: true,
    theme: GameTheme.yutNight,
    ink: Color(0xFFF3EEFF),
    sub: Color(0xFFABA9DC),
    acc: Color(0xFFFFB347),
    acc2: Color(0xFFD4851A),
    onAcc: Color(0xFF3A2200),
    accText: Color(0xFFFFC266),
    glow: Color(0x80FFB347),
    panel: Color(0xFF2C2F75),
    panelEdge: Color(0xFF171A47),
    glass: Color(0x1CFFFFFF),
    glassEdge: Color(0x29FFFFFF),
    me: Color(0xFFFFB347),
    opp: Color(0xFF8FA8FF),
    shadow: Color(0x99041C1C),
    tileRim: Color(0xFF7371C4),
    tileField: Color(0xFF43408F),
    tileInner: Color(0x4DFFC878),
    tileSide: Color(0xFF2C2A5C),
    tileSide2: Color(0xFF201F49),
    tileLine: Color(0xFFFFC878),
    tileLineHl: Color(0xFF2A2865),
    pegTop: Color(0xFFFFE8BA),
    pegSide: Color(0xFFC79B5C),
    station: {
      'blue': (Color(0xFF86A0FF), Color(0xFF4A63C9)),
      'red': (Color(0xFFFF9D8D), Color(0xFFC25B51)),
      'white': (Color(0xFFEEEBFF), Color(0xFFB1ACDC)),
      'black': (Color(0xFFAEB3D6), Color(0xFF6E7399)),
      'yellow': (Color(0xFFFFDB8E), Color(0xFFD9A340)),
    },
    mat: Color(0xFF30307D),
    matLine: Color(0x1FFFC878),
    matEdge: Color(0xFF1B1C52),
    plate: Color(0xFF4A4896),
    plateSide: Color(0xFF2A2961),
    btnDisabled: Color(0xFF2A2D6B),
    btnDisabledEdge: Color(0xFF191B48),
    ray: Color(0x33FFBE64),
    scrim: Color(0x73080828),
    yellow: Color(0xFFFFD35A),
    stationLabel: Color(0xFF26224F),
  );

  static YutPalette forTheme(String? theme) =>
      theme == 'night' ? moonlight : daylight;

  static YutPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<YutPaletteScope>()?.palette ??
      daylight;

  // ── 글꼴: 굵고 또렷한 한글(승리·윷·모가 다른 글자로 읽히지 않는 서체) ──
  /// 큰 순간(결과 글자·제목)용. 도현체는 "승리"가 또렷하게 읽힌다.
  TextStyle display({double size = 24, Color? color, double? height}) =>
      GoogleFonts.doHyeon(
        fontSize: size,
        color: color ?? ink,
        height: height ?? 1.1,
      );

  TextStyle body({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) => GoogleFonts.notoSansKr(
    fontSize: size,
    color: color ?? ink,
    fontWeight: weight,
    height: height,
  );
}

class YutPaletteScope extends InheritedWidget {
  final YutPalette palette;

  const YutPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  @override
  bool updateShouldNotify(YutPaletteScope old) => old.palette != palette;
}
