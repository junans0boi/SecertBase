// 비밀기지 2.0 type scale: six steps of Noto Sans KR plus a Gowun Batang
// serif for emotional numbers and titles (D+412, result titles).
//
// Minimum sizes: body copy 13px (cap), labels 12px. Nothing smaller.
//
// Color: every style except [V2Text.cap] has NO color, so text inherits the
// ambient DefaultTextStyle (ink in light, light ink inside
// `V2Theme(dark: true)`). `cap` is [V2Colors.sub]; in dark screens use
// `V2Text.cap.copyWith(color: V2Palette.of(context).sub)`.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class V2Text {
  static TextStyle _sans(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
    Color? color,
  }) => GoogleFonts.notoSansKr(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// 28/34 w800. Big page moments (온보딩, 홈 히어로 숫자 옆 제목).
  static final TextStyle display = _sans(
    28,
    34,
    FontWeight.w800,
    letterSpacing: -0.56,
  );

  /// 22/28 w800. Tab page titles, sheet titles.
  static final TextStyle title = _sans(
    22,
    28,
    FontWeight.w800,
    letterSpacing: -0.33,
  );

  /// 18/24 w700. Card titles, dialog titles, section heads.
  static final TextStyle head = _sans(18, 24, FontWeight.w700);

  /// 15/22 w500. Default body copy.
  static final TextStyle body = _sans(15, 22, FontWeight.w500);

  /// 15/20 w600. List-row titles, emphasized body.
  static final TextStyle bodyStrong = _sans(15, 20, FontWeight.w600);

  /// 13/18 w500 in [V2Colors.sub]. Captions, help text, subtitles.
  static final TextStyle cap = _sans(
    13,
    18,
    FontWeight.w500,
    color: V2Colors.sub,
  );

  /// 12/16 w700. Overlines, badges, tab labels. Smallest allowed size.
  static final TextStyle label = _sans(
    12,
    16,
    FontWeight.w700,
    letterSpacing: 0.24,
  );

  /// 16 w700. Primary button label.
  static final TextStyle button = _sans(16, 20, FontWeight.w700);

  /// 14 w700. Small button label.
  static final TextStyle buttonSm = _sans(14, 18, FontWeight.w700);

  /// 17/24 w700. Centered title of a back-style header.
  static final TextStyle headerBack = _sans(17, 24, FontWeight.w700);

  /// Gowun Batang serif, only for emotional numbers and result titles.
  ///
  /// ```dart
  /// Text('D+412', style: V2Text.serif(size: 40, color: Colors.white))
  /// ```
  static TextStyle serif({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
    double letterSpacing = -0.2,
  }) {
    assert(size >= 12, '2.0 type never goes below 12px');
    return GoogleFonts.gowunBatang(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.25,
      letterSpacing: letterSpacing,
    );
  }

  /// Noto Sans KR at an arbitrary size, for rare one-offs (stat numbers).
  /// Prefer the six steps above.
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) {
    assert(size >= 12, '2.0 type never goes below 12px');
    return GoogleFonts.notoSansKr(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Korean "keep-all" line breaking: Flutter breaks Hangul between any two
  /// syllables ("드려\n요."). This joins the letters of each word with
  /// U+2060 WORD JOINER so lines only break at spaces. Use it for short
  /// centered copy (empty-state titles, hero lines). Note `find.text` in
  /// tests must then match the joined string, so keep it opt-in.
  static String keepAll(String text) =>
      text.split(' ').map((w) => w.characters.join('\u2060')).join(' ');

  /// Material [TextTheme] mapped onto the 2.0 scale.
  static TextTheme textTheme({Color ink = V2Colors.ink, Color? sub}) {
    final s = sub ?? V2Colors.sub;
    return TextTheme(
      displayLarge: display.copyWith(color: ink),
      displayMedium: display.copyWith(color: ink),
      displaySmall: display.copyWith(color: ink),
      headlineLarge: display.copyWith(color: ink),
      headlineMedium: title.copyWith(color: ink),
      headlineSmall: title.copyWith(color: ink),
      titleLarge: head.copyWith(color: ink),
      titleMedium: bodyStrong.copyWith(color: ink),
      titleSmall: cap.copyWith(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(color: ink),
      bodyMedium: body.copyWith(color: ink),
      bodySmall: cap.copyWith(color: s),
      labelLarge: button.copyWith(color: ink),
      labelMedium: label.copyWith(color: ink),
      labelSmall: label.copyWith(color: ink),
    );
  }
}
