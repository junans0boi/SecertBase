// 비밀기지 2.0 design tokens.
//
// Source of truth for every 2.0 screen. Values are refined from the approved
// mockup (docs/design/v2/mockup/ds.css): a warmer blush neutral family, a
// plum-tinted crisp ink instead of blue-black, and pastel rose/peach/lilac
// accents that sit together without fighting.
//
// Contrast rule: every text/background pair listed in [V2Contrast.pairs] is
// WCAG 2.1 AA (>= 4.5:1 for body text). Ratios in the doc comments are
// measured against white (#FFFFFF) unless another background is named, and
// test/v2/v2_contrast_test.dart re-computes all of them.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Light palette. Use these, never raw `Color(0x...)` in 2.0 screens.
abstract final class V2Colors {
  // ─── Neutral ──────────────────────────────────────────────────────
  /// Page background, a warm blush white.
  static const bg = Color(0xFFFFFAFA);

  /// Cards, sheets, dialogs, list containers.
  static const surface = Color(0xFFFFFFFF);

  /// Soft fills: icon bubbles, soft cards, chips, skeleton highlight.
  static const soft = Color(0xFFFFF2F5);

  /// Slightly deeper fill: segmented track, progress track, skeleton base.
  static const soft2 = Color(0xFFFAEAEF);

  /// Hairline borders and list dividers (decorative, no contrast needed).
  static const line = Color(0xFFF0DCE3);

  /// Stronger divider, sheet handle, ghost button border.
  static const line2 = Color(0xFFE4CBD4);

  /// Text field border at rest (field always has a visible label above).
  static const fieldBorder = Color(0xFFD9BFCA);

  /// Boundary of toggles/checkboxes at rest: 3.27:1 on white, 3.16:1 on bg
  /// (WCAG 1.4.11 non-text contrast >= 3:1).
  static const control = Color(0xFF978A9C);

  /// Titles and body text. 16.93:1 on white, 16.37:1 on bg, 15.54:1 on soft.
  static const ink = Color(0xFF211A26);

  /// Secondary text. 7.92:1 on bg, 7.52:1 on soft, 7.05:1 on soft2.
  static const sub = Color(0xFF564B5E);

  /// Tertiary text (timestamps, hints). 5.25:1 on white, 5.08:1 on bg,
  /// 4.82:1 on soft. Do not use on soft2 or darker fills.
  static const muted = Color(0xFF73687C);

  /// Disabled text/icons only (WCAG exempts disabled controls).
  static const disabled = Color(0xFFBCB1C1);

  /// Scrim behind sheets and dialogs.
  static const scrim = Color(0x7514091A);

  /// Snackbar background. White text 15.6:1.
  static const snack = Color(0xFF2B2231);

  // ─── Brand rose ───────────────────────────────────────────────────
  /// Decorative rose: illustrations, gradients, icon tints on soft fills.
  /// 2.38:1 on white, so NEVER use for text or as a text background.
  static const rose = Color(0xFFFF7FA3);

  /// Primary actions and rose text. White on rose600 5.03:1, rose600 on
  /// white 5.03:1, on bg 4.86:1, on soft 4.62:1.
  static const rose600 = Color(0xFFC93468);

  /// Rose text on [roseSoft] (soft buttons, rose chips): 5.80:1.
  static const rose700 = Color(0xFFA3285A);

  /// Soft rose fill (soft button, rose chip, focus ring).
  static const roseSoft = Color(0xFFFFE3EB);

  // ─── Accents: base (decor) / soft (fill) / text (AA on soft) ──────
  static const sage = Color(0xFF63B98F);
  static const sageSoft = Color(0xFFE0F3E8);

  /// 5.48:1 on [sageSoft], 6.34:1 on white.
  static const sageText = Color(0xFF2B6B4C);

  static const sky = Color(0xFF6FA9DD);
  static const skySoft = Color(0xFFE1EEFA);

  /// 5.86:1 on [skySoft], 6.91:1 on white.
  static const skyText = Color(0xFF295D8C);

  static const honey = Color(0xFFEDB352);
  static const honeySoft = Color(0xFFFCEFD3);

  /// 6.21:1 on [honeySoft].
  static const honeyText = Color(0xFF77510F);

  static const lilac = Color(0xFFA48EEA);
  static const lilacSoft = Color(0xFFEDE8FE);

  /// 6.17:1 on [lilacSoft], 7.37:1 on white.
  static const lilacText = Color(0xFF5A43AE);

  static const peach = Color(0xFFFFA084);
  static const peachSoft = Color(0xFFFFE8DF);

  /// 5.43:1 on [peachSoft].
  static const peachText = Color(0xFF9C4523);

  // ─── Status ───────────────────────────────────────────────────────
  /// 4.68:1 on white (icons, large text).
  static const ok = Color(0xFF1E8455);
  static const okSoft = Color(0xFFDEF2E6);

  /// 5.97:1 on [okSoft].
  static const okText = Color(0xFF156640);

  /// 4.68:1 on white.
  static const warn = Color(0xFFA86400);
  static const warnSoft = Color(0xFFFFEFD1);

  /// 7.00:1 on [warnSoft].
  static const warnText = Color(0xFF764600);

  /// Danger buttons: white on err 5.20:1; err on white 5.20:1.
  static const err = Color(0xFFC9343B);
  static const errSoft = Color(0xFFFCE5E5);

  /// 6.14:1 on [errSoft].
  static const errText = Color(0xFFA3242B);
}

/// Dark palette for 마음관리 and photo viewing (wrap with
/// `V2Theme(dark: true, ...)`). Same names as [V2Colors] where meaningful.
abstract final class V2DarkColors {
  static const bg = Color(0xFF17121C);
  static const surface = Color(0xFF211A28);
  static const soft = Color(0xFF2A2233);
  static const soft2 = Color(0xFF312839);
  static const line = Color(0xFF3B3046);
  static const line2 = Color(0xFF4A3D55);
  static const control = Color(0xFF8C7F96);

  /// 16.59:1 on bg, 15.21:1 on surface.
  static const ink = Color(0xFFF8F1F6);

  /// 10.94:1 on surface.
  static const sub = Color(0xFFD8CCDD);

  /// 7.19:1 on bg, 6.59:1 on surface, 5.96:1 on soft.
  static const muted = Color(0xFFAA9DB4);
  static const disabled = Color(0xFF6F6479);

  /// Rose for text/buttons on dark: 8.61:1 on bg, 7.89:1 on surface.
  /// Button label on it uses [onRose] (8.61:1).
  static const rose = Color(0xFFFF8FB0);
  static const onRose = Color(0xFF17121C);
  static const roseSoft = Color(0xFF4A2236);

  /// 8.85:1 on [roseSoft].
  static const roseText = Color(0xFFFFC2D4);
  static const sageSoft = Color(0xFF17362A);
  static const skySoft = Color(0xFF173047);
  static const honeySoft = Color(0xFF3F3015);
  static const lilacSoft = Color(0xFF2D2650);
  static const peachSoft = Color(0xFF432719);
  static const err = Color(0xFFFF8A8A);
  static const errSoft = Color(0xFF4A1F22);
  static const ok = Color(0xFF7FD6A6);
  static const warn = Color(0xFFF2C46B);
}

/// Corner radii (ds.css --r-*).
abstract final class V2Radius {
  /// Controls: inputs, small buttons, icon bubbles.
  static const double ctl = 12;

  /// Primary buttons, banners, snackbars.
  static const double button = 14;

  /// Cards and lists.
  static const double card = 20;

  /// Bottom sheets (top corners), large dialogs.
  static const double sheet = 28;

  static const double pill = 999;

  static const ctlAll = BorderRadius.all(Radius.circular(ctl));
  static const buttonAll = BorderRadius.all(Radius.circular(button));
  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const sheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// 4pt spacing grid. Page side padding is [page] (20).
abstract final class V2Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;

  /// Horizontal page padding.
  static const double page = 20;

  /// Minimum tap target.
  static const double tap = 44;

  static const pagePadding = EdgeInsets.symmetric(horizontal: page);
}

/// Two elevation levels (ds.css --sh-1 / --sh-2), tinted plum not grey.
abstract final class V2Shadow {
  /// Cards and raised surfaces.
  static const level1 = [
    BoxShadow(color: Color(0x0D3C1428), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F3C1428), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Sheets, dialogs, snackbars, floating elements.
  static const level2 = [
    BoxShadow(color: Color(0x243C1428), blurRadius: 30, offset: Offset(0, 10)),
  ];
}

/// Gradients for heroes, illustrations and photo placeholders.
abstract final class V2Gradients {
  /// Home hero. White text >= 4.5:1 on every stop (4.72 / 5.40 / 4.78), so
  /// body-size white text is fine on it.
  static const hero = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFFCC3D6C), Color(0xFFBC3868), Color(0xFFC4475A)],
  );

  /// Rose to plum, for 우리 이해 / result cards. White text >= 4.72:1.
  static const berry = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCC3D6C), Color(0xFF9C3F86)],
  );

  /// Pastel blush → peach → lilac. Use [V2Colors.ink] text on it.
  static const heroSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE3EB), Color(0xFFFFEBE2), Color(0xFFEFE8FF)],
  );

  /// Decorative only (no text): illustration blobs, avatar rings.
  static const blossom = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9FBB), Color(0xFFFF7FA3), Color(0xFFFFA084)],
  );

  /// Dark care/viewer backdrop. Use [V2DarkColors.ink] text.
  static const dusk = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1F33), Color(0xFF17121C)],
  );

  /// Photo placeholder pairs (decorative). Pick with [placeholder].
  static const placeholders = [
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFD6E3), Color(0xFFFFE9D9)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE6DEFF), Color(0xFFFFDCE7)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFE6D6), Color(0xFFFFF3CF)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD9EDF9), Color(0xFFE6DEFF)],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDDF2E6), Color(0xFFFFF0D6)],
    ),
  ];

  /// Stable placeholder for any seed (e.g. a record id).
  static LinearGradient placeholder(Object? seed) =>
      placeholders[(seed.hashCode & 0x7fffffff) % placeholders.length];
}

/// Motion tokens. Always go through [of] so reduced motion is respected.
abstract final class V2Motion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  /// [Duration.zero] when the platform asks for reduced motion.
  static Duration of(BuildContext context, [Duration d = base]) =>
      reduced(context) ? Duration.zero : d;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Semantic color tones shared by chips, banners, icon bubbles.
enum V2Tone { neutral, rose, ok, warn, err, sky, lilac, sage, peach, honey }

/// Resolved colors for a [V2Tone].
class V2ToneColors {
  const V2ToneColors(this.base, this.soft, this.text);

  /// Decorative/icon color.
  final Color base;

  /// Fill color.
  final Color soft;

  /// Text color, AA on [soft].
  final Color text;

  static V2ToneColors of(V2Tone tone) => switch (tone) {
    V2Tone.neutral => const V2ToneColors(
      V2Colors.sub,
      V2Colors.soft,
      V2Colors.sub,
    ),
    V2Tone.rose => const V2ToneColors(
      V2Colors.rose600,
      V2Colors.roseSoft,
      V2Colors.rose700,
    ),
    V2Tone.ok => const V2ToneColors(
      V2Colors.ok,
      V2Colors.okSoft,
      V2Colors.okText,
    ),
    V2Tone.warn => const V2ToneColors(
      V2Colors.warn,
      V2Colors.warnSoft,
      V2Colors.warnText,
    ),
    V2Tone.err => const V2ToneColors(
      V2Colors.err,
      V2Colors.errSoft,
      V2Colors.errText,
    ),
    V2Tone.sky => const V2ToneColors(
      V2Colors.sky,
      V2Colors.skySoft,
      V2Colors.skyText,
    ),
    V2Tone.lilac => const V2ToneColors(
      V2Colors.lilac,
      V2Colors.lilacSoft,
      V2Colors.lilacText,
    ),
    V2Tone.sage => const V2ToneColors(
      V2Colors.sage,
      V2Colors.sageSoft,
      V2Colors.sageText,
    ),
    V2Tone.peach => const V2ToneColors(
      V2Colors.peach,
      V2Colors.peachSoft,
      V2Colors.peachText,
    ),
    V2Tone.honey => const V2ToneColors(
      V2Colors.honey,
      V2Colors.honeySoft,
      V2Colors.honeyText,
    ),
  };
}

/// WCAG contrast helper plus the registry of text/background pairs the
/// design system promises are AA.
abstract final class V2Contrast {
  /// WCAG 2.1 relative luminance contrast ratio (1..21).
  static double ratio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// (label, foreground, background, minimum ratio).
  static const pairs = <(String, Color, Color, double)>[
    ('ink/bg', V2Colors.ink, V2Colors.bg, 4.5),
    ('ink/surface', V2Colors.ink, V2Colors.surface, 4.5),
    ('ink/soft', V2Colors.ink, V2Colors.soft, 4.5),
    ('ink/soft2', V2Colors.ink, V2Colors.soft2, 4.5),
    ('sub/bg', V2Colors.sub, V2Colors.bg, 4.5),
    ('sub/surface', V2Colors.sub, V2Colors.surface, 4.5),
    ('sub/soft', V2Colors.sub, V2Colors.soft, 4.5),
    ('sub/soft2', V2Colors.sub, V2Colors.soft2, 4.5),
    ('muted/bg', V2Colors.muted, V2Colors.bg, 4.5),
    ('muted/surface', V2Colors.muted, V2Colors.surface, 4.5),
    ('muted/soft', V2Colors.muted, V2Colors.soft, 4.5),
    ('rose600/surface', V2Colors.rose600, V2Colors.surface, 4.5),
    ('rose600/bg', V2Colors.rose600, V2Colors.bg, 4.5),
    ('rose600/soft', V2Colors.rose600, V2Colors.soft, 4.5),
    ('white/rose600', Colors.white, V2Colors.rose600, 4.5),
    ('rose700/roseSoft', V2Colors.rose700, V2Colors.roseSoft, 4.5),
    ('sageText/sageSoft', V2Colors.sageText, V2Colors.sageSoft, 4.5),
    ('skyText/skySoft', V2Colors.skyText, V2Colors.skySoft, 4.5),
    ('honeyText/honeySoft', V2Colors.honeyText, V2Colors.honeySoft, 4.5),
    ('lilacText/lilacSoft', V2Colors.lilacText, V2Colors.lilacSoft, 4.5),
    ('peachText/peachSoft', V2Colors.peachText, V2Colors.peachSoft, 4.5),
    ('okText/okSoft', V2Colors.okText, V2Colors.okSoft, 4.5),
    ('warnText/warnSoft', V2Colors.warnText, V2Colors.warnSoft, 4.5),
    ('errText/errSoft', V2Colors.errText, V2Colors.errSoft, 4.5),
    ('white/err', Colors.white, V2Colors.err, 4.5),
    ('err/surface', V2Colors.err, V2Colors.surface, 4.5),
    ('ok/surface', V2Colors.ok, V2Colors.surface, 4.5),
    ('warn/surface', V2Colors.warn, V2Colors.surface, 4.5),
    ('white/snack', Colors.white, V2Colors.snack, 4.5),
    ('roseSoft/snack', V2Colors.roseSoft, V2Colors.snack, 4.5),
    ('white/ink', Colors.white, V2Colors.ink, 4.5),
    ('white/hero0', Colors.white, Color(0xFFCC3D6C), 4.5),
    ('white/hero1', Colors.white, Color(0xFFBC3868), 4.5),
    ('white/hero2', Colors.white, Color(0xFFC4475A), 4.5),
    ('white/berry1', Colors.white, Color(0xFF9C3F86), 4.5),
    ('control/surface', V2Colors.control, V2Colors.surface, 3.0),
    ('control/bg', V2Colors.control, V2Colors.bg, 3.0),
    ('dark ink/bg', V2DarkColors.ink, V2DarkColors.bg, 4.5),
    ('dark ink/surface', V2DarkColors.ink, V2DarkColors.surface, 4.5),
    ('dark sub/surface', V2DarkColors.sub, V2DarkColors.surface, 4.5),
    ('dark muted/bg', V2DarkColors.muted, V2DarkColors.bg, 4.5),
    ('dark muted/surface', V2DarkColors.muted, V2DarkColors.surface, 4.5),
    ('dark muted/soft', V2DarkColors.muted, V2DarkColors.soft, 4.5),
    ('dark rose/bg', V2DarkColors.rose, V2DarkColors.bg, 4.5),
    ('dark rose/surface', V2DarkColors.rose, V2DarkColors.surface, 4.5),
    ('dark onRose/rose', V2DarkColors.onRose, V2DarkColors.rose, 4.5),
    (
      'dark roseText/roseSoft',
      V2DarkColors.roseText,
      V2DarkColors.roseSoft,
      4.5,
    ),
    ('dark err/surface', V2DarkColors.err, V2DarkColors.surface, 4.5),
  ];
}
