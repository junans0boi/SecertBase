// 비밀기지 2.1 color themes. The four white themes (코랄 · 블루 · 그린 ·
// 라벤더) share one neutral set and differ only in the accent.
//
// Every theme keeps the same shapes, spacing and type; only colors change.
// The user picks one in 설정 > 화면 테마. [V2Palette.current] is the active
// palette, and [V2Colors] / [V2Gradients] / [V2Text] read from it, so a theme
// switch only needs the app to rebuild (see [V2ThemeController]).
//
// Contrast rule (checked by test/v2/v2_themes_test.dart for every theme):
// ink/sub/muted on bg/surface/soft, onPrimary on primary, onPrimarySoft on
// primarySoft, every tone text on its soft, and onHeroStrong on heroStrong
// stops are all WCAG AA (4.5:1). control is 3:1 (non-text).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// The selectable color themes, in the order the picker shows them.
enum V2ThemeId {
  // Ids are stored on the device; labels changed in 2.1 but ids did not.
  blossom('코랄', '흰 바탕에 코랄 포인트 · 기본'),
  clean('블루', '흰 바탕에 파란 포인트'),
  sage('그린', '흰 바탕에 초록 포인트'),
  lavender('라벤더', '흰 바탕에 보라 포인트'),
  paper('종이', '종이색 바탕에 먹색과 테라코타'),
  butter('버터', '버터색 바탕에 체리, 또렷한 검정'),
  night('밤', '남색 밤하늘에 복숭아빛');

  const V2ThemeId(this.label, this.description);

  final String label;
  final String description;

  static V2ThemeId fromName(String? name) => V2ThemeId.values.firstWhere(
    (t) => t.name == name,
    orElse: () => V2ThemeId.blossom,
  );
}

/// Resolved colors for one theme. Also a [ThemeExtension], so
/// `V2Palette.of(context)` follows `V2Theme(dark: true)` subtrees.
@immutable
class V2Palette extends ThemeExtension<V2Palette> {
  const V2Palette({
    required this.id,
    required this.dark,
    required this.bg,
    required this.surface,
    required this.soft,
    required this.soft2,
    required this.line,
    required this.line2,
    required this.fieldBorder,
    required this.control,
    required this.ink,
    required this.sub,
    required this.muted,
    required this.disabled,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.point,
    required this.err,
    required this.errSoft,
    required this.errText,
    required this.snack,
    required this.snackAction,
    required this.scrim,
    required this.me,
    required this.partner,
    required this.heroWash,
    required this.heroStrong,
    required this.onHeroStrong,
    required this.blossom,
    required this.tones,
  });

  final V2ThemeId id;
  final bool dark;

  // Neutrals.
  final Color bg;
  final Color surface;
  final Color soft;
  final Color soft2;
  final Color line;
  final Color line2;
  final Color fieldBorder;
  final Color control;
  final Color ink;
  final Color sub;
  final Color muted;
  final Color disabled;

  /// Buttons, links, selected states. Text on it uses [onPrimary].
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;

  /// Accent text on [primarySoft] (chips, selected rows).
  final Color onPrimarySoft;

  /// Decorative accent (D-day prefix, hearts, badges' dot). Not for body text.
  final Color point;

  final Color err;
  final Color errSoft;
  final Color errText;
  final Color snack;
  final Color snackAction;
  final Color scrim;

  /// Avatar fills (white initial on top, >= 4.5:1).
  final Color me;
  final Color partner;

  /// Soft page-top wash (home hero). Use [ink] text on it.
  final LinearGradient heroWash;

  /// Strong accent gradient (hero cards). Use [onHeroStrong] text on it.
  final LinearGradient heroStrong;
  final Color onHeroStrong;

  /// Decorative only (illustration blobs, rings).
  final LinearGradient blossom;

  /// Semantic tones except rose/neutral/err, which derive from the fields
  /// above (see [tone]).
  final Map<V2Tone, V2ToneColors> tones;

  V2ToneColors tone(V2Tone t) => switch (t) {
    V2Tone.neutral => V2ToneColors(sub, soft, sub),
    V2Tone.rose => V2ToneColors(primary, primarySoft, onPrimarySoft),
    V2Tone.err => V2ToneColors(err, errSoft, errText),
    _ => tones[t]!,
  };

  /// Active app palette (set by [V2ThemeController]).
  static V2Palette current = V2Palettes.blossom;

  /// Palette for this subtree: the dark care palette inside
  /// `V2Theme(dark: true)`, otherwise the active theme.
  static V2Palette of(BuildContext context) =>
      Theme.of(context).extension<V2Palette>() ?? current;

  /// Kept for older call sites: the default light palette.
  static const light = V2Palettes.blossom;

  /// Kept for older call sites: the 마음관리 dark palette.
  static const darkSet = V2Palettes.care;

  @override
  V2Palette copyWith() => this;

  @override
  V2Palette lerp(covariant V2Palette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

const _lightTones = <V2Tone, V2ToneColors>{
  V2Tone.ok: V2ToneColors(
    Color(0xFF1E8455),
    Color(0xFFDEF2E6),
    Color(0xFF156640),
  ),
  V2Tone.warn: V2ToneColors(
    Color(0xFFA86400),
    Color(0xFFFFEFD1),
    Color(0xFF764600),
  ),
  V2Tone.sky: V2ToneColors(
    Color(0xFF6FA9DD),
    Color(0xFFE1EEFA),
    Color(0xFF295D8C),
  ),
  V2Tone.lilac: V2ToneColors(
    Color(0xFFA48EEA),
    Color(0xFFEDE8FE),
    Color(0xFF5A43AE),
  ),
  V2Tone.sage: V2ToneColors(
    Color(0xFF63B98F),
    Color(0xFFE0F3E8),
    Color(0xFF2B6B4C),
  ),
  V2Tone.peach: V2ToneColors(
    Color(0xFFFF8A6B),
    Color(0xFFFFE8DF),
    Color(0xFF9C4523),
  ),
  V2Tone.honey: V2ToneColors(
    Color(0xFFEDB352),
    Color(0xFFFCEFD3),
    Color(0xFF77510F),
  ),
};

/// Warmer, less saturated tones for the paper / sage themes.
const _earthTones = <V2Tone, V2ToneColors>{
  V2Tone.ok: V2ToneColors(
    Color(0xFF3E7A52),
    Color(0xFFE2ECDF),
    Color(0xFF2F5E3F),
  ),
  V2Tone.warn: V2ToneColors(
    Color(0xFF9A6418),
    Color(0xFFF4E7CF),
    Color(0xFF6E4610),
  ),
  V2Tone.sky: V2ToneColors(
    Color(0xFF6A8CA8),
    Color(0xFFE3E9EE),
    Color(0xFF3B5A73),
  ),
  V2Tone.lilac: V2ToneColors(
    Color(0xFF8E80A8),
    Color(0xFFE9E5EE),
    Color(0xFF55496E),
  ),
  V2Tone.sage: V2ToneColors(
    Color(0xFF6E9474),
    Color(0xFFE2EBDF),
    Color(0xFF3A5E41),
  ),
  V2Tone.peach: V2ToneColors(
    Color(0xFFC9765E),
    Color(0xFFF4E2D9),
    Color(0xFF8E4430),
  ),
  V2Tone.honey: V2ToneColors(
    Color(0xFFC79A45),
    Color(0xFFF3E8CF),
    Color(0xFF6E5214),
  ),
};

const _darkTones = <V2Tone, V2ToneColors>{
  V2Tone.ok: V2ToneColors(
    Color(0xFF7FD6A6),
    Color(0xFF17362A),
    Color(0xFFB6EBCD),
  ),
  V2Tone.warn: V2ToneColors(
    Color(0xFFF2C46B),
    Color(0xFF3F3015),
    Color(0xFFF7DDA6),
  ),
  V2Tone.sky: V2ToneColors(
    Color(0xFF8FB8F2),
    Color(0xFF173047),
    Color(0xFFC3DBF8),
  ),
  V2Tone.lilac: V2ToneColors(
    Color(0xFFB8A8F7),
    Color(0xFF2D2650),
    Color(0xFFD9D0FF),
  ),
  V2Tone.sage: V2ToneColors(
    Color(0xFF8EDBB4),
    Color(0xFF17362A),
    Color(0xFFBDEDD3),
  ),
  V2Tone.peach: V2ToneColors(
    Color(0xFFFFAE96),
    Color(0xFF432719),
    Color(0xFFFFD3C4),
  ),
  V2Tone.honey: V2ToneColors(
    Color(0xFFF2C46B),
    Color(0xFF3F3015),
    Color(0xFFF7DDA6),
  ),
};

/// Shared neutrals of the four white themes (2.1 design: white page, gray
/// cards, one accent). Checked for AA by test/v2/v2_themes_test.dart.
abstract final class _White {
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF5F6F8);
  static const soft2 = Color(0xFFEEF0F3);
  static const line = Color(0xFFF0F1F3);
  static const line2 = Color(0xFFE5E8EB);
  static const fieldBorder = Color(0xFFC4CAD2);
  static const control = Color(0xFF7F8996);
  static const ink = Color(0xFF191F28);
  static const sub = Color(0xFF4E5968);
  static const muted = Color(0xFF616C7A);
  static const disabled = Color(0xFFB0B8C1);
  static const me = Color(0xFFC9432A);
  static const partner = Color(0xFF2F64CC);
  static const wash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
}

/// The palettes. [care] is the 마음관리 dark variant, not user-selectable.
abstract final class V2Palettes {
  static const blossom = V2Palette(
    id: V2ThemeId.blossom,
    dark: false,
    bg: _White.bg,
    surface: _White.surface,
    soft: _White.soft,
    soft2: _White.soft2,
    line: _White.line,
    line2: _White.line2,
    fieldBorder: _White.fieldBorder,
    control: _White.control,
    ink: _White.ink,
    sub: _White.sub,
    muted: _White.muted,
    disabled: _White.disabled,
    primary: Color(0xFFC9432A),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFFFEFEA),
    onPrimarySoft: Color(0xFFB23A22),
    point: Color(0xFFFF5A3C),
    err: Color(0xFFD22F3A),
    errSoft: Color(0xFFFDECEC),
    errText: Color(0xFFB0222C),
    snack: Color(0xFF191F28),
    snackAction: Color(0xFFFFB4A3),
    scrim: Color(0x75101318),
    me: _White.me,
    partner: _White.partner,
    heroWash: _White.wash,
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC9432A), Color(0xFFB23A22)],
    ),
    onHeroStrong: Color(0xFFFFFFFF),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB4A3), Color(0xFFFF8466), Color(0xFFFF5A3C)],
    ),
    tones: _lightTones,
  );

  static const paper = V2Palette(
    id: V2ThemeId.paper,
    dark: false,
    bg: Color(0xFFF5F0E8),
    surface: Color(0xFFFFFDF8),
    soft: Color(0xFFF0E8DC),
    soft2: Color(0xFFE9DFD0),
    line: Color(0xFFE3D9CB),
    line2: Color(0xFFD6C9B7),
    fieldBorder: Color(0xFFC2B39E),
    control: Color(0xFF8F8377),
    ink: Color(0xFF2A2521),
    sub: Color(0xFF574E46),
    muted: Color(0xFF6B6158),
    disabled: Color(0xFFBDB3A6),
    primary: Color(0xFF2E2823),
    onPrimary: Color(0xFFFFFDF8),
    primarySoft: Color(0xFFF0E4D8),
    onPrimarySoft: Color(0xFF9A4129),
    point: Color(0xFFB4533A),
    err: Color(0xFFB3352E),
    errSoft: Color(0xFFF6E0DA),
    errText: Color(0xFF8F2A24),
    snack: Color(0xFF2A2521),
    snackAction: Color(0xFFF0C9B8),
    scrim: Color(0x751E1712),
    me: Color(0xFFA54A33),
    partner: Color(0xFF4F604E),
    heroWash: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFEDE3D5), Color(0xFFF5F0E8)],
    ),
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3A322C), Color(0xFF2A2521)],
    ),
    onHeroStrong: Color(0xFFFFFDF8),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE9C2AE), Color(0xFFD08A70), Color(0xFFB4533A)],
    ),
    tones: _earthTones,
  );

  static const clean = V2Palette(
    id: V2ThemeId.clean,
    dark: false,
    bg: _White.bg,
    surface: _White.surface,
    soft: _White.soft,
    soft2: _White.soft2,
    line: _White.line,
    line2: _White.line2,
    fieldBorder: _White.fieldBorder,
    control: _White.control,
    ink: _White.ink,
    sub: _White.sub,
    muted: _White.muted,
    disabled: _White.disabled,
    primary: Color(0xFF1F66DB),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEAF2FF),
    onPrimarySoft: Color(0xFF1A5BC4),
    point: Color(0xFF3478F6),
    err: Color(0xFFD22F3A),
    errSoft: Color(0xFFFDECEC),
    errText: Color(0xFFB0222C),
    snack: Color(0xFF191F28),
    snackAction: Color(0xFFA9C8FF),
    scrim: Color(0x75101318),
    me: _White.me,
    partner: _White.partner,
    heroWash: _White.wash,
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F66DB), Color(0xFF1A5BC4)],
    ),
    onHeroStrong: Color(0xFFFFFFFF),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA9C8FF), Color(0xFF6FA0F8), Color(0xFF3478F6)],
    ),
    tones: _lightTones,
  );

  static const night = V2Palette(
    id: V2ThemeId.night,
    dark: true,
    bg: Color(0xFF0F1022),
    surface: Color(0xFF1A1B33),
    soft: Color(0xFF23243F),
    soft2: Color(0xFF2B2C4A),
    line: Color(0xFF2E2F4D),
    line2: Color(0xFF3B3C5E),
    fieldBorder: Color(0xFF55567C),
    control: Color(0xFF8C88AE),
    ink: Color(0xFFF4F1FF),
    sub: Color(0xFFC9C4E4),
    muted: Color(0xFFA29DC4),
    disabled: Color(0xFF5D5A7D),
    primary: Color(0xFFFFB8A8),
    onPrimary: Color(0xFF1A1430),
    primarySoft: Color(0xFF3A2A45),
    onPrimarySoft: Color(0xFFFFC6B2),
    point: Color(0xFFFFCF94),
    err: Color(0xFFFF8A8A),
    errSoft: Color(0xFF4A1F22),
    errText: Color(0xFFFFC2C2),
    snack: Color(0xFF2B2C4A),
    snackAction: Color(0xFFFFC6B2),
    scrim: Color(0x99050614),
    me: Color(0xFFB8406A),
    partner: Color(0xFF4A5FC4),
    heroWash: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF242150), Color(0xFF0F1022)],
    ),
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFD0B0), Color(0xFFFF9EB5)],
    ),
    onHeroStrong: Color(0xFF1A1430),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFD29A), Color(0xFFFFA3BA), Color(0xFF8FA8FF)],
    ),
    tones: _darkTones,
  );

  static const lavender = V2Palette(
    id: V2ThemeId.lavender,
    dark: false,
    bg: _White.bg,
    surface: _White.surface,
    soft: _White.soft,
    soft2: _White.soft2,
    line: _White.line,
    line2: _White.line2,
    fieldBorder: _White.fieldBorder,
    control: _White.control,
    ink: _White.ink,
    sub: _White.sub,
    muted: _White.muted,
    disabled: _White.disabled,
    primary: Color(0xFF6A4CF0),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEFEBFF),
    onPrimarySoft: Color(0xFF5A3DD9),
    point: Color(0xFF7357F6),
    err: Color(0xFFD22F3A),
    errSoft: Color(0xFFFDECEC),
    errText: Color(0xFFB0222C),
    snack: Color(0xFF191F28),
    snackAction: Color(0xFFCFC4FF),
    scrim: Color(0x75101318),
    me: _White.me,
    partner: _White.partner,
    heroWash: _White.wash,
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6A4CF0), Color(0xFF5A3DD9)],
    ),
    onHeroStrong: Color(0xFFFFFFFF),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFCFC4FF), Color(0xFFA08CFA), Color(0xFF7357F6)],
    ),
    tones: _lightTones,
  );

  static const sage = V2Palette(
    id: V2ThemeId.sage,
    dark: false,
    bg: _White.bg,
    surface: _White.surface,
    soft: _White.soft,
    soft2: _White.soft2,
    line: _White.line,
    line2: _White.line2,
    fieldBorder: _White.fieldBorder,
    control: _White.control,
    ink: _White.ink,
    sub: _White.sub,
    muted: _White.muted,
    disabled: _White.disabled,
    primary: Color(0xFF1E7D5A),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE5F4EE),
    onPrimarySoft: Color(0xFF1A6F50),
    point: Color(0xFF22936A),
    err: Color(0xFFD22F3A),
    errSoft: Color(0xFFFDECEC),
    errText: Color(0xFFB0222C),
    snack: Color(0xFF191F28),
    snackAction: Color(0xFFA6E0C6),
    scrim: Color(0x75101318),
    me: _White.me,
    partner: _White.partner,
    heroWash: _White.wash,
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E7D5A), Color(0xFF1A6F50)],
    ),
    onHeroStrong: Color(0xFFFFFFFF),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA6E0C6), Color(0xFF5DBB93), Color(0xFF22936A)],
    ),
    tones: _lightTones,
  );

  static const butter = V2Palette(
    id: V2ThemeId.butter,
    dark: false,
    bg: Color(0xFFFFF3D6),
    surface: Color(0xFFFFFFFF),
    soft: Color(0xFFFFF8E6),
    soft2: Color(0xFFFFEFC2),
    line: Color(0xFFEADBB4),
    line2: Color(0xFFD8C48E),
    fieldBorder: Color(0xFF3D3A33),
    control: Color(0xFF7A7466),
    ink: Color(0xFF141414),
    sub: Color(0xFF3B3B3B),
    muted: Color(0xFF5A564C),
    disabled: Color(0xFFB5AE9C),
    primary: Color(0xFFFF4D62),
    onPrimary: Color(0xFF141414),
    primarySoft: Color(0xFFFFD3DA),
    onPrimarySoft: Color(0xFF8A1427),
    point: Color(0xFFFF4D62),
    err: Color(0xFFC62B3A),
    errSoft: Color(0xFFFFE0E0),
    errText: Color(0xFF9E1F2B),
    snack: Color(0xFF141414),
    snackAction: Color(0xFFFFD84D),
    scrim: Color(0x80141414),
    me: Color(0xFFC8283F),
    partner: Color(0xFF3D5BDB),
    heroWash: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFE7A8), Color(0xFFFFF3D6)],
    ),
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF4D62), Color(0xFFFF7A45)],
    ),
    onHeroStrong: Color(0xFF141414),
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFD84D), Color(0xFFFF9DB0), Color(0xFF9FD3FF)],
    ),
    tones: _lightTones,
  );

  /// 마음관리 / photo viewer dark palette (`V2Theme(dark: true)`).
  static const care = V2Palette(
    id: V2ThemeId.blossom,
    dark: true,
    bg: V2DarkColors.bg,
    surface: V2DarkColors.surface,
    soft: V2DarkColors.soft,
    soft2: V2DarkColors.soft2,
    line: V2DarkColors.line,
    line2: V2DarkColors.line2,
    fieldBorder: V2DarkColors.line2,
    control: V2DarkColors.control,
    ink: V2DarkColors.ink,
    sub: V2DarkColors.sub,
    muted: V2DarkColors.muted,
    disabled: V2DarkColors.disabled,
    primary: V2DarkColors.rose,
    onPrimary: V2DarkColors.onRose,
    primarySoft: V2DarkColors.roseSoft,
    onPrimarySoft: V2DarkColors.roseText,
    point: V2DarkColors.rose,
    err: V2DarkColors.err,
    errSoft: V2DarkColors.errSoft,
    errText: Color(0xFFFFC2C2),
    snack: V2DarkColors.soft2,
    snackAction: V2DarkColors.roseText,
    scrim: Color(0x99000000),
    me: Color(0xFFB8406A),
    partner: Color(0xFF2877BD),
    heroWash: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2A1F33), Color(0xFF17121C)],
    ),
    heroStrong: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF8FB0), Color(0xFFFFA98F)],
    ),
    onHeroStrong: V2DarkColors.onRose,
    blossom: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF9FBB), Color(0xFFFF7FA3), Color(0xFFFFA084)],
    ),
    tones: _darkTones,
  );

  static V2Palette byId(V2ThemeId id) => switch (id) {
    V2ThemeId.blossom => blossom,
    V2ThemeId.paper => paper,
    V2ThemeId.clean => clean,
    V2ThemeId.night => night,
    V2ThemeId.lavender => lavender,
    V2ThemeId.sage => sage,
    V2ThemeId.butter => butter,
  };

  static const all = [blossom, paper, clean, night, lavender, sage, butter];
}

/// Holds the chosen theme, persists it on this device, and keeps
/// [V2Palette.current] in sync. `MaterialApp` listens to it.
class V2ThemeController extends ValueNotifier<V2ThemeId> {
  V2ThemeController._() : super(V2ThemeId.blossom);

  static final instance = V2ThemeController._();
  static const prefsKey = 'v2_color_theme';

  V2Palette get palette => V2Palettes.byId(value);

  /// Reads the saved theme. Call before `runApp`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(V2ThemeId.fromName(prefs.getString(prefsKey)));
    } catch (_) {
      _apply(V2ThemeId.blossom);
    }
  }

  /// Switches theme immediately and saves the choice.
  Future<void> select(V2ThemeId id) async {
    _apply(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, id.name);
    } catch (_) {
      // Not saved; the theme still applies for this session.
    }
  }

  void _apply(V2ThemeId id) {
    V2Palette.current = V2Palettes.byId(id);
    value = id;
  }

  @visibleForTesting
  void debugReset() => _apply(V2ThemeId.blossom);
}
