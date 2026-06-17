import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color palette ─────────────────────────────────────────────────
const kBg        = Color(0xFFFFF5F8);   // 연한 블러시 화이트
const kSurface   = Color(0xFFFFFFFF);
const kCard      = Color(0xFFFFFFFF);
const kBorder    = Color(0xFFFFD6E5);   // 소프트 핑크 테두리
const kPrimary   = Color(0xFFD63384);   // 딥 로즈
const kPrimaryL  = Color(0xFFFF80AB);   // 라이트 핑크
const kAccent    = Color(0xFFFF6B9D);
const kGold      = Color(0xFFFF8C42);   // 웜 오렌지골드
const kTeal      = Color(0xFF00BFA5);
const kText      = Color(0xFF1A0A1E);
const kTextSub   = Color(0xFF5A4060);
const kTextMuted = Color(0xFFB097BC);
const kSuccess   = Color(0xFF2EB872);
const kError     = Color(0xFFE53935);

final kPrimaryGrad = const LinearGradient(
  colors: [Color(0xFFD63384), Color(0xFFFF6B9D)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
final kWarmGrad = const LinearGradient(
  colors: [Color(0xFFFF6B9D), Color(0xFFFFAD8A)],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
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
        color: kText, fontSize: 17, fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kPrimary.withAlpha(30),
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
      fillColor: const Color(0xFFFFF0F5),
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
