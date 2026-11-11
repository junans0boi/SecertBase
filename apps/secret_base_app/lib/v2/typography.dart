// 비밀기지 2.1 type scale: Pretendard (bundled, assets/fonts/pretendard).
// One family for everything, including big numbers (412일, D-26). [serif]
// is kept as an API for older call sites and now renders Pretendard
// ExtraBold, so the app has a single, plain typeface.
//
// Minimum sizes: body copy 13px (cap), labels 12px. Nothing smaller.
//
// Color: every style except [V2Text.cap] has NO color, so text inherits the
// ambient DefaultTextStyle (ink in light, light ink inside
// `V2Theme(dark: true)`). `cap` is [V2Colors.sub]; in dark screens use
// `V2Text.cap.copyWith(color: V2Palette.of(context).sub)`.
import 'package:flutter/material.dart';

import 'palettes.dart';
import 'tokens.dart';

abstract final class V2Text {
  /// Bundled family name (pubspec.yaml).
  static const family = 'Pretendard';

  /// Korean glyphs Pretendard lacks fall back to the platform font.
  static const fallback = <String>['Apple SD Gothic Neo', 'Noto Sans KR'];

  static TextStyle _sans(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
  );

  /// 30/36 w700. Big page moments (홈 "함께한 지 412일", 온보딩).
  static final TextStyle display = _sans(
    30,
    36,
    FontWeight.w700,
    letterSpacing: -0.8,
  );

  /// 26/32 w800. Tab page titles (놀이, 지도, 더보기), sheet titles.
  static final TextStyle title = _sans(
    26,
    32,
    FontWeight.w800,
    letterSpacing: -0.6,
  );

  /// 17/24 w700. Card titles, dialog titles, section heads.
  static final TextStyle head = _sans(
    17,
    24,
    FontWeight.w700,
    letterSpacing: -0.2,
  );

  /// 15/22 w500. Default body copy.
  static final TextStyle body = _sans(15, 22, FontWeight.w500);

  /// 15/20 w600. List-row titles, emphasized body.
  static final TextStyle bodyStrong = _sans(15, 20, FontWeight.w600);

  /// 13/18 w500 in the active theme's sub color. Captions, help text,
  /// subtitles.
  static TextStyle get cap =>
      _capCache[V2Palette.current] ??= _capBase.copyWith(color: V2Colors.sub);
  static final TextStyle _capBase = _sans(13, 18, FontWeight.w500);
  static final _capCache = <V2Palette, TextStyle>{};

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

  /// Big emotional numbers and result titles. Since 2.1 this is Pretendard
  /// ExtraBold with tight tracking (the serif face was dropped).
  ///
  /// ```dart
  /// Text('412', style: V2Text.serif(size: 46))
  /// ```
  static TextStyle serif({
    double size = 28,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    assert(size >= 12, '2.0 type never goes below 12px');
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? 1.2,
      letterSpacing: letterSpacing ?? -size * 0.03,
    );
  }

  /// Pretendard at an arbitrary size, for rare one-offs (stat numbers).
  /// Prefer the steps above.
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) {
    assert(size >= 12, '2.0 type never goes below 12px');
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallback,
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
  static TextTheme textTheme({Color? ink, Color? sub}) {
    final i = ink ?? V2Colors.ink;
    final s = sub ?? V2Colors.sub;
    return TextTheme(
      displayLarge: display.copyWith(color: i),
      displayMedium: display.copyWith(color: i),
      displaySmall: display.copyWith(color: i),
      headlineLarge: display.copyWith(color: i),
      headlineMedium: title.copyWith(color: i),
      headlineSmall: title.copyWith(color: i),
      titleLarge: head.copyWith(color: i),
      titleMedium: bodyStrong.copyWith(color: i),
      titleSmall: cap.copyWith(color: i, fontWeight: FontWeight.w700),
      bodyLarge: body.copyWith(color: i),
      bodyMedium: body.copyWith(color: i),
      bodySmall: cap.copyWith(color: s),
      labelLarge: button.copyWith(color: i),
      labelMedium: label.copyWith(color: i),
      labelSmall: label.copyWith(color: i),
    );
  }
}
