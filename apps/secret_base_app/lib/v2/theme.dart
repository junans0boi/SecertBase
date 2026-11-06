// 비밀기지 2.0 ThemeData, so plain Material widgets already look 2.0.
//
// IMPORTANT: this is NOT the global app theme. Game screens (arcade, play
// kit, hwatu...) still rely on the legacy `buildAppTheme()` for their
// AlertDialogs, SnackBars and buttons, so `MaterialApp.theme` stays legacy.
// 2.0 screens opt in by wrapping their root in [V2Theme]. The `showV2*`
// helpers apply the 2.0 theme themselves, so they look right from anywhere.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData? _light;
ThemeData? _dark;

/// The 2.0 [ThemeData]. Cached; cheap to call repeatedly.
ThemeData buildV2Theme({bool dark = false}) =>
    dark ? (_dark ??= _build(dark: true)) : (_light ??= _build(dark: false));

ThemeData _build({required bool dark}) {
  final bg = dark ? V2DarkColors.bg : V2Colors.bg;
  final surface = dark ? V2DarkColors.surface : V2Colors.surface;
  final soft = dark ? V2DarkColors.soft : V2Colors.soft;
  final soft2 = dark ? V2DarkColors.soft2 : V2Colors.soft2;
  final line = dark ? V2DarkColors.line : V2Colors.line;
  final line2 = dark ? V2DarkColors.line2 : V2Colors.line2;
  final ink = dark ? V2DarkColors.ink : V2Colors.ink;
  final sub = dark ? V2DarkColors.sub : V2Colors.sub;
  final muted = dark ? V2DarkColors.muted : V2Colors.muted;
  final disabled = dark ? V2DarkColors.disabled : V2Colors.disabled;
  final primary = dark ? V2DarkColors.rose : V2Colors.rose600;
  final onPrimary = dark ? V2DarkColors.onRose : Colors.white;
  final primarySoft = dark ? V2DarkColors.roseSoft : V2Colors.roseSoft;
  final onPrimarySoft = dark ? V2DarkColors.roseText : V2Colors.rose700;
  final err = dark ? V2DarkColors.err : V2Colors.err;
  final errSoft = dark ? V2DarkColors.errSoft : V2Colors.errSoft;
  final control = dark ? V2DarkColors.control : V2Colors.control;

  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primarySoft,
    onPrimaryContainer: onPrimarySoft,
    secondary: dark ? V2DarkColors.roseText : V2Colors.lilacText,
    onSecondary: dark ? V2DarkColors.bg : Colors.white,
    secondaryContainer: dark ? V2DarkColors.lilacSoft : V2Colors.lilacSoft,
    onSecondaryContainer: dark ? V2DarkColors.ink : V2Colors.lilacText,
    tertiary: dark ? V2DarkColors.ok : V2Colors.sageText,
    onTertiary: dark ? V2DarkColors.bg : Colors.white,
    error: err,
    onError: dark ? V2DarkColors.bg : Colors.white,
    errorContainer: errSoft,
    onErrorContainer: dark ? V2DarkColors.ink : V2Colors.errText,
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
    scrim: V2Colors.scrim,
    inverseSurface: dark ? V2DarkColors.ink : V2Colors.snack,
    onInverseSurface: dark ? V2DarkColors.bg : Colors.white,
    inversePrimary: dark ? V2Colors.rose600 : V2Colors.roseSoft,
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
      border: border(dark ? line2 : V2Colors.fieldBorder),
      enabledBorder: border(dark ? line2 : V2Colors.fieldBorder),
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
      modalBarrierColor: V2Colors.scrim,
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
      barrierColor: V2Colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: V2Text.head.copyWith(color: ink),
      contentTextStyle: V2Text.body.copyWith(color: sub),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? V2DarkColors.soft2 : V2Colors.snack,
      contentTextStyle: V2Text.buttonSm.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: dark ? V2DarkColors.roseText : V2Colors.roseSoft,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const RoundedRectangleBorder(borderRadius: V2Radius.buttonAll),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dark ? V2DarkColors.soft2 : V2Colors.snack,
        borderRadius: V2Radius.ctlAll,
      ),
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

/// Opt-in wrapper that gives a subtree the 2.0 theme and default text style.
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
    final theme = buildV2Theme(dark: dark);
    return Theme(
      data: theme,
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium,
        child: child,
      ),
    );
  }
}

/// Light/dark-resolved neutral + brand colors. 2.0 widgets read colors
/// through this so they work inside `V2Theme(dark: true)`.
///
/// ```dart
/// final p = V2Palette.of(context);
/// Text('메모', style: V2Text.cap.copyWith(color: p.sub));
/// ```
class V2Palette {
  const V2Palette._({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.soft,
    required this.soft2,
    required this.line,
    required this.line2,
    required this.control,
    required this.ink,
    required this.sub,
    required this.muted,
    required this.disabled,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.err,
    required this.errSoft,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color soft;
  final Color soft2;
  final Color line;
  final Color line2;
  final Color control;
  final Color ink;
  final Color sub;
  final Color muted;
  final Color disabled;

  /// Buttons / rose text (rose600 in light, rose in dark).
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final Color err;
  final Color errSoft;

  static const light = V2Palette._(
    dark: false,
    bg: V2Colors.bg,
    surface: V2Colors.surface,
    soft: V2Colors.soft,
    soft2: V2Colors.soft2,
    line: V2Colors.line,
    line2: V2Colors.line2,
    control: V2Colors.control,
    ink: V2Colors.ink,
    sub: V2Colors.sub,
    muted: V2Colors.muted,
    disabled: V2Colors.disabled,
    primary: V2Colors.rose600,
    onPrimary: Colors.white,
    primarySoft: V2Colors.roseSoft,
    onPrimarySoft: V2Colors.rose700,
    err: V2Colors.err,
    errSoft: V2Colors.errSoft,
  );

  static const darkSet = V2Palette._(
    dark: true,
    bg: V2DarkColors.bg,
    surface: V2DarkColors.surface,
    soft: V2DarkColors.soft,
    soft2: V2DarkColors.soft2,
    line: V2DarkColors.line,
    line2: V2DarkColors.line2,
    control: V2DarkColors.control,
    ink: V2DarkColors.ink,
    sub: V2DarkColors.sub,
    muted: V2DarkColors.muted,
    disabled: V2DarkColors.disabled,
    primary: V2DarkColors.rose,
    onPrimary: V2DarkColors.onRose,
    primarySoft: V2DarkColors.roseSoft,
    onPrimarySoft: V2DarkColors.roseText,
    err: V2DarkColors.err,
    errSoft: V2DarkColors.errSoft,
  );

  static V2Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSet : light;
}
