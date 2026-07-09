import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color palette ─────────────────────────────────────────────────
const kBg = Color(0xFFFFFBFD);
const kSurface = Color(0xFFFFFFFF);
const kCard = Color(0xFFFFFFFF);
const kBorder = Color(0xFFF3DCE6);
const kPrimary = Color(0xFFFF6F9F);
const kPrimaryL = Color(0xFFFFA7C3);
const kAccent = Color(0xFFFF9670);
const kGold = Color(0xFFFFBE32);
const kTeal = Color(0xFF55BF8A);
const kText = Color(0xFF1E1E2E);
const kTextSub = Color(0xFF5A5A78);
const kTextMuted = Color(0xFFABABBC);
const kSuccess = Color(0xFF2EB872);
const kError = Color(0xFFE53935);

final kPrimaryGrad = const LinearGradient(
  colors: [Color(0xFFFF6F9F), Color(0xFFFF9670)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
final kWarmGrad = const LinearGradient(
  colors: [Color(0xFFFF9670), Color(0xFFFFBE32)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      secondary: kAccent,
      surface: kSurface,
      onSurface: kText,
      outline: kBorder,
    ),
    textTheme: GoogleFonts.notoSansTextTheme().apply(
      bodyColor: kText,
      displayColor: kText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSans(
        color: kText,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kPrimary.withAlpha(24),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return IconThemeData(color: sel ? kPrimary : kTextMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return GoogleFonts.notoSans(
          color: sel ? kPrimary : kTextMuted,
          fontSize: 11,
          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF5F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      labelStyle: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
      hintStyle: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dividerColor: kBorder,
    cardColor: kCard,
  );
}
