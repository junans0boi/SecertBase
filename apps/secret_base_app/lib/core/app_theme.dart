import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kBg = Color(0xFF090912);
const kSurface = Color(0xFF12121E);
const kCard = Color(0xFF1A1A2C);
const kBorder = Color(0xFF2A2A42);
const kPrimary = Color(0xFF7C5CFC);
const kPrimaryLight = Color(0xFF9B7FFF);
const kAccent = Color(0xFFFF6B9D);
const kGold = Color(0xFFFFD166);
const kTeal = Color(0xFF06D6A0);
const kText = Color(0xFFE8E8F0);
const kTextMuted = Color(0xFF7777A0);
const kSuccess = Color(0xFF4CAF82);
const kError = Color(0xFFFF5252);

final kPrimaryGrad = LinearGradient(
  colors: [kPrimary, kPrimaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final kAccentGrad = LinearGradient(
  colors: [kAccent, Color(0xFFFF9ABF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildAppTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kPrimary,
      secondary: kAccent,
      surface: kSurface,
      onSurface: kText,
      outline: kBorder,
    ),
    textTheme: GoogleFonts.notoSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.notoSans(
        color: kText, fontSize: 32, fontWeight: FontWeight.bold,
      ),
      headlineLarge: GoogleFonts.notoSans(
        color: kText, fontSize: 24, fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.notoSans(
        color: kText, fontSize: 20, fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.notoSans(
        color: kText, fontSize: 18, fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.notoSans(
        color: kText, fontSize: 15, fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.notoSans(color: kText, fontSize: 15),
      bodyMedium: GoogleFonts.notoSans(color: kTextMuted, fontSize: 13),
      labelLarge: GoogleFonts.notoSans(
        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSans(
        color: kText, fontSize: 17, fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kPrimary.withOpacity(0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary, size: 24);
        }
        return const IconThemeData(color: kTextMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.notoSans(
          color: selected ? kPrimary : kTextMuted,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
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
