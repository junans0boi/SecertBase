// 비밀기지 2.0 ThemeData, so plain Material widgets already look 2.0.
//
// This is the global app theme (`MaterialApp.theme`), games included; game
// screens layer their own explicit styling on top. [V2Theme] is still useful
// for the dark variant (마음관리, photo viewing) and is harmless elsewhere.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'palettes.dart';

export 'palettes.dart';

import 'tokens.dart';
import 'typography.dart';

final _cache = <V2Palette, ThemeData>{};

/// The 2.0 [ThemeData] for [palette] (default: the active theme), or the
/// 마음관리 dark variant when [dark] is true. Cached per palette.
ThemeData buildV2Theme({bool dark = false, V2Palette? palette}) {
  final p = dark
      ? ((palette ?? V2Palette.current).dark
            ? (palette ?? V2Palette.current)
            : V2Palettes.care)
      : (palette ?? V2Palette.current);
  return _cache[p] ??= _build(p);
}

ThemeData _build(V2Palette p) {
  final dark = p.dark;
  final bg = p.bg;
  final surface = p.surface;
  final soft = p.soft;
  final soft2 = p.soft2;
  final line = p.line;
  final line2 = p.line2;
  final ink = p.ink;
  final sub = p.sub;
  final muted = p.muted;
  final disabled = p.disabled;
  final primary = p.primary;
  final onPrimary = p.onPrimary;
  final primarySoft = p.primarySoft;
  final onPrimarySoft = p.onPrimarySoft;
  final err = p.err;
  final errSoft = p.errSoft;
  final control = p.control;
  final lilac = p.tone(V2Tone.lilac);
  final ok = p.tone(V2Tone.ok);

  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primarySoft,
    onPrimaryContainer: onPrimarySoft,
    secondary: lilac.text,
    onSecondary: dark ? bg : Colors.white,
    secondaryContainer: lilac.soft,
    onSecondaryContainer: lilac.text,
    tertiary: ok.text,
    onTertiary: dark ? bg : Colors.white,
    error: err,
    onError: dark ? bg : Colors.white,
    errorContainer: errSoft,
    onErrorContainer: p.errText,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: sub,
    surfaceContainerLowest: surface,
    surfaceContainerLow: bg,
    surfaceContainer: soft,
    surfaceContainerHigh: soft2,
    surfaceContainerHighest: soft2,
    outline: control,
    outlineVariant: line,
    shadow: const Color(0xFF3C1428),
    scrim: p.scrim,
    inverseSurface: p.snack,
    onInverseSurface: Colors.white,
    inversePrimary: p.snackAction,
    surfaceTint: Colors.transparent,
  );

  final text = V2Text.textTheme(ink: ink, sub: sub);
  const btnShape = RoundedRectangleBorder(borderRadius: V2Radius.buttonAll);

  ButtonStyle base({
    required Color bgc,
    required Color fg,
    BorderSide? side,
  }) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(44, 52)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
    shape: const WidgetStatePropertyAll(btnShape),
    textStyle: WidgetStatePropertyAll(V2Text.button),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? soft2 : bgc,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled) ? disabled : fg,
    ),
    overlayColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.pressed)) return fg.withValues(alpha: 0.12);
      if (s.contains(WidgetState.hovered)) return fg.withValues(alpha: 0.06);
      if (s.contains(WidgetState.focused)) return fg.withValues(alpha: 0.10);
      return null;
    }),
    side: side == null ? null : WidgetStatePropertyAll(side),
  );

  OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: V2Radius.ctlAll,
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    extensions: [p],
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    cardColor: surface,
    dividerColor: line,
    disabledColor: disabled,
    hintColor: muted,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: text,
    primaryTextTheme: text,
    iconTheme: IconThemeData(color: ink, size: 24),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primary,
      selectionColor: primarySoft,
      selectionHandleColor: primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 52,
      titleTextStyle: V2Text.title.copyWith(color: ink),
      iconTheme: IconThemeData(color: ink, size: 24),
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base(bgc: primary, fg: onPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base(bgc: primary, fg: onPrimary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base(
        bgc: Colors.transparent,
        fg: ink,
        side: BorderSide(color: line2, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base(bgc: Colors.transparent, fg: sub).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        textStyle: WidgetStatePropertyAll(
          V2Text.buttonSm.copyWith(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        foregroundColor: WidgetStatePropertyAll(ink),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: V2Text.body.copyWith(color: muted, fontSize: 16),
      labelStyle: V2Text.cap.copyWith(color: sub, fontWeight: FontWeight.w600),
      floatingLabelStyle: V2Text.cap.copyWith(color: primary),
      helperStyle: V2Text.cap.copyWith(color: sub),
      errorStyle: V2Text.cap.copyWith(color: err),
      border: border(p.fieldBorder),
      enabledBorder: border(p.fieldBorder),
      focusedBorder: border(primary, 2),
      errorBorder: border(err),
      focusedErrorBorder: border(err, 2),
      disabledBorder: border(line),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      side: BorderSide(color: control, width: 2),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : surface,
      ),
      checkColor: WidgetStatePropertyAll(onPrimary),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : control,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : control,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: soft,
      selectedColor: ink,
      labelStyle: V2Text.cap.copyWith(color: sub, fontWeight: FontWeight.w600),
      secondaryLabelStyle: V2Text.cap.copyWith(
        color: bg,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: V2Radius.cardAll,
        side: BorderSide(color: line),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 10,
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      iconColor: primary,
      textColor: ink,
      titleTextStyle: V2Text.bodyStrong.copyWith(color: ink),
      subtitleTextStyle: V2Text.cap.copyWith(color: sub),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      modalBarrierColor: p.scrim,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.sheetTop),
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 560),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: p.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: V2Text.head.copyWith(color: ink),
      contentTextStyle: V2Text.body.copyWith(color: sub),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.snack,
      contentTextStyle: V2Text.buttonSm.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: p.snackAction,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.buttonAll),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.snack, borderRadius: V2Radius.ctlAll),
      textStyle: V2Text.cap.copyWith(color: Colors.white),
      waitDuration: const Duration(milliseconds: 400),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: soft2,
      circularTrackColor: soft2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary : muted,
          size: 26,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => V2Text.label.copyWith(
          color: s.contains(WidgetState.selected) ? primary : muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Gives a subtree the 2.0 default text style. With [dark] it switches the
/// subtree to the dark palette (마음관리, photo viewing); otherwise it keeps
/// the app's active color theme.
///
/// ```dart
/// return V2Theme(child: Scaffold(appBar: V2Header(title: '더보기'), ...));
/// ```
class V2Theme extends StatelessWidget {
  const V2Theme({super.key, required this.child, this.dark = false});

  final Widget child;

  /// Dark variant for 마음관리 and photo viewing.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (!dark) {
      final theme = Theme.of(context);
      return DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium,
        child: child,
      );
    }
    final theme = buildV2Theme(dark: true);
    return Theme(
      data: theme,
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium,
        child: child,
      ),
    );
  }
}
