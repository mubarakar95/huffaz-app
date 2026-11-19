import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // --- Primary Palette (Serene Path - Stitch Emerald Green) ---
  static const primary = Color(0xFF2D6A4F);      // deep emerald green
  static const primaryLight = Color(0xFF52B788);  // light emerald green
  static const primaryDark = Color(0xFF1B4332);   // dark emerald green

  // --- Semantic Colors ---
  static const success = Color(0xFF10B981);  // emerald-500
  static const warning = Color(0xFFF59E0B);  // amber-500
  static const danger  = Color(0xFFEF4444);  // red-500
  static const info    = Color(0xFF1D3557);  // midnight blue (used as info)

  // --- Light Theme Surfaces (Serene Path) ---
  static const backgroundLight = Color(0xFFF8FAF9); // Eucalyptus White
  static const surfaceLight     = Color(0xFFFFFFFF);
  static const surface2Light    = Color(0xFFECEFEF);
  static const borderLight      = Color(0xFFD8DFDE);
  static const textMainLight    = Color(0xFF1D3557); // Midnight Blue Text
  static const textMutedLight   = Color(0xFF455A64);
  static const textTertiaryLight= Color(0xFF78909C);

  // --- Dark Theme Surfaces ---
  static const backgroundDark = Color(0xFF101216);
  static const surfaceDark     = Color(0xFF1A1C20);
  static const surface2Dark    = Color(0xFF23262A);
  static const borderDark      = Color(0xFF2C2F34);
  static const textMainDark    = Color(0xFFECEFF1);
  static const textMutedDark   = Color(0xFFB0BEC5);
  static const textTertiaryDark= Color(0xFF78909C);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        surface: AppColors.surfaceLight,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      canvasColor: AppColors.backgroundLight,
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme).copyWith(
        headlineLarge: GoogleFonts.manrope(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textMainLight,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textMainLight,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMainLight,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMainLight,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textMainLight,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMutedLight,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiaryLight,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMainLight,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textMainLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMainLight,
        ),
        iconTheme: const IconThemeData(color: AppColors.textMainLight),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMutedLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMutedLight, size: 22);
        }),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Light,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.textTertiaryLight),
        labelStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderLight, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2Light,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        secondaryLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primaryLight,
        surface: AppColors.surfaceDark,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      canvasColor: AppColors.backgroundDark,
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.manrope(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textMainDark,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textMainDark,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMainDark,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMainDark,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textMainDark,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textMutedDark,
        ),
        bodySmall: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiaryDark,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMainDark,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textMainDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMainDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textMainDark),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primary.withOpacity(0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.manrope(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryLight,
            );
          }
          return GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMutedDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 24);
          }
          return const IconThemeData(color: AppColors.textMutedDark, size: 22);
        }),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2Dark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.textTertiaryDark),
        labelStyle: GoogleFonts.manrope(fontSize: 14, color: AppColors.textMutedDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderDark, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2Dark,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
        secondaryLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.borderDark),
      ),
    );
  }
}
