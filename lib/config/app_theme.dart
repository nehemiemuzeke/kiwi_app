import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KiwiColors {
  static const Color primary = Color(0xFF8AC926);
  static const Color defaultPrimary = Color(0xFF8AC926);
  static const Color primaryDark = Color(0xFF6EA31E);
  static const Color secondary = Color(0xFF1A1A2E);
  static const Color accent = Color(0xFFFFD60A);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color error = Color(0xFFFF6B6B);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFF6E6E80);
  static const Color divider = Color(0xFFE5E5EA);
  static const Color dividerLight = Color(0xFFE5E5EA);
  static const Color dividerDark = Color(0xFF2C2C2E);
  static const Color success = Color(0xFF34C759);

  static const List<Color> themeOptions = [
    Color(0xFF8AC926),
    Color(0xFFFF6B6B),
    Color(0xFF4D96FF),
    Color(0xFF9D4EDD),
    Color(0xFFFFB703),
    Color(0xFF06D6A0),
  ];
}

class KiwiTextStyles {
  static TextStyle get displayLarge => GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: KiwiColors.textPrimary);
  static TextStyle get displayMedium => GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: KiwiColors.textPrimary);
  static TextStyle get titleLarge => GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: KiwiColors.textPrimary);
  static TextStyle get titleMedium => GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: KiwiColors.textPrimary);
  static TextStyle get bodyLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: KiwiColors.textPrimary);
  static TextStyle get bodyMedium => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: KiwiColors.textPrimary);
  static TextStyle get bodySmall => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, color: KiwiColors.textSecondary);
  static TextStyle get button => GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static TextStyle get caption => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: KiwiColors.textSecondary);
}

class AppTheme {
  static ThemeData get lightTheme => getTheme(isDark: false, primaryColor: KiwiColors.primary);
  static ThemeData get darkTheme => getTheme(isDark: true, primaryColor: KiwiColors.primary);

  static ThemeData getTheme({required bool isDark, required Color primaryColor}) {
    final bgColor = isDark ? KiwiColors.backgroundDark : KiwiColors.backgroundLight;
    final surfaceColor = isDark ? KiwiColors.surfaceDark : KiwiColors.surfaceLight;
    final textPrimary = isDark ? KiwiColors.textPrimaryDark : KiwiColors.textPrimaryLight;
    final dividerColor = isDark ? KiwiColors.dividerDark : KiwiColors.dividerLight;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryColor,
        onPrimary: Colors.white,
        secondary: KiwiColors.accent,
        onSecondary: Colors.black,
        error: KiwiColors.error,
        onError: Colors.white,
        surface: surfaceColor,
        onSurface: textPrimary,
      ),
      textTheme: TextTheme(
        displayLarge: KiwiTextStyles.displayLarge.copyWith(color: textPrimary),
        displayMedium: KiwiTextStyles.displayMedium.copyWith(color: textPrimary),
        titleLarge: KiwiTextStyles.titleLarge.copyWith(color: textPrimary),
        titleMedium: KiwiTextStyles.titleMedium.copyWith(color: textPrimary),
        bodyLarge: KiwiTextStyles.bodyLarge.copyWith(color: textPrimary),
        bodyMedium: KiwiTextStyles.bodyMedium.copyWith(color: textPrimary),
        bodySmall: KiwiTextStyles.bodySmall.copyWith(color: KiwiColors.textSecondary),
        labelSmall: KiwiTextStyles.caption.copyWith(color: KiwiColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: KiwiTextStyles.titleLarge.copyWith(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: primaryColor, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: KiwiColors.error, width: 1.5)),
        hintStyle: KiwiTextStyles.bodyMedium.copyWith(color: KiwiColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: KiwiTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          side: BorderSide(color: dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: KiwiTextStyles.button.copyWith(color: textPrimary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: KiwiTextStyles.bodyMedium.copyWith(color: primaryColor, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: KiwiColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primaryColor, foregroundColor: Colors.white, elevation: 4),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : KiwiColors.secondary,
        contentTextStyle: KiwiTextStyles.bodyMedium.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}