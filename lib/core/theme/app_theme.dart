import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.deepBerry,
        secondary: AppColors.deepBerry,
        surface: AppColors.snow,
        error: AppColors.warmSpice,
        onPrimary: AppColors.snow,
        onSecondary: AppColors.snow,
        onSurface: AppColors.darkFig,
        onError: AppColors.snow,
      ),

      scaffoldBackgroundColor: AppColors.snow,

      // AppBar Theme (Clean White)
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.snow,
        foregroundColor: AppColors.darkFig,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.paleGray,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFig,
        ),
      ),

      // Text Theme
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkFig,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFig,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFig,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.darkFig,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.darkFig,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFig,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkFig,
          letterSpacing: 0.2,
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBerry,
          foregroundColor: AppColors.snow,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 1,
          shadowColor: AppColors.deepBerry.withValues(alpha: 0.2),
          disabledBackgroundColor: AppColors.paleGray,
          disabledForegroundColor: AppColors.disabledText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepBerry,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: const BorderSide(color: AppColors.deepBerry, width: 2),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return const BorderSide(color: AppColors.paleGray, width: 2);
              }
              return const BorderSide(color: AppColors.deepBerry, width: 2);
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return AppColors.disabledText;
              }
              return AppColors.deepBerry;
            },
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepBerry,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.snow,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: AppColors.darkFig),
        hintStyle: TextStyle(color: AppColors.disabledText),
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.paleGray, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.paleGray, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.deepBerry, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.warmSpice, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.warmSpice, width: 2),
        ),
        errorStyle: TextStyle(color: AppColors.warmSpice),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.paleGray,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
