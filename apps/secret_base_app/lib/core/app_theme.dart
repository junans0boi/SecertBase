import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_design.dart';

// Legacy names remain available for game and settings screens. Shared values
// intentionally resolve to main_design.dart so app-wide meaning cannot drift.
const kBg = kMainBg;
const kSurface = kMainPaper;
const kCard = kMainPaper;
const kBorder = kMainLine;
const kPrimary = kMainRose;
const kPrimaryL = Color(0xFFFFA7C3);
const kAccent = kMainPeach;
const kGold = kMainHoney;
const kTeal = kMainSage;
const kText = kMainInk;
const kTextSub = kMainSub;
const kTextMuted = kMainMuted;
const kSuccess = kMainSuccess;
const kError = kMainError;

const kPrimaryGrad = kRoseGrad;
const kWarmGrad = LinearGradient(
  colors: [kMainPeach, kMainHoney],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: kMainBg,
    colorScheme: const ColorScheme.light(
      primary: kMainRose,
      secondary: kMainPeach,
      surface: kMainPaper,
      onSurface: kMainInk,
      outline: kMainLine,
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
      backgroundColor: kMainPaper,
      indicatorColor: kMainPaperSoft,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return IconThemeData(color: sel ? kMainInk : kMainMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final sel = s.contains(WidgetState.selected);
        return mainBody(
          size: 11,
          color: sel ? kMainInk : kMainMuted,
          weight: sel ? FontWeight.w800 : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kMainPaperSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kMainLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kMainLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kMainRose, width: 1.5),
      ),
      labelStyle: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
      hintStyle: GoogleFonts.notoSans(color: kTextMuted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
    ),
    outlinedButtonTheme: const OutlinedButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
    ),
    elevatedButtonTheme: const ElevatedButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
    ),
    dividerColor: kMainLine,
    cardColor: kMainPaper,
  );
}
