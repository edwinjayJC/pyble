import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';

class AppTheme {
  // ---
  //
  // LIGHT THEME (PERFECTED)
  //
  // ---
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.deepBerry,
        secondary: AppColors.deepBerry,
        surface: AppColors.snow, // Card backgrounds
        background: AppColors.snow, // Scaffold background
        error: AppColors.warmSpice,
        onPrimary: AppColors.snow, // Text on DeepBerry
        onSecondary: AppColors.snow, // Text on DeepBerry
        onSurface: AppColors.darkFig, // Main text on cards
        onBackground: AppColors.darkFig, // Main text on scaffold
        onError: AppColors.snow,
      ),

      scaffoldBackgroundColor: AppColors.snow,

      // AppBar Theme (Clean White)
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.snow,
        foregroundColor: AppColors.darkFig, // Icon color
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
      textTheme: baseTextTheme
          .copyWith(
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
          )
          .apply(bodyColor: AppColors.darkFig, displayColor: AppColors.darkFig),

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
          shadowColor: AppColors.deepBerry.withOpacity(
            0.2,
          ), // Fixed typo: withValues -> withOpacity
          disabledBackgroundColor: AppColors.paleGray,
          disabledForegroundColor: AppColors.disabledText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepBerry,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return const BorderSide(color: AppColors.paleGray, width: 2);
                }
                return const BorderSide(color: AppColors.deepBerry, width: 2);
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.disabledText;
                }
                return AppColors.deepBerry;
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepBerry,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  // ---
  //
  // DARK THEME (FIXED & ALIGNED)
  //
  // ---
  // ---
  //
  // DARK THEME (REMASTERED)
  //
  // ---
  static ThemeData get darkTheme {
    // Use the Light Crust color for text so it's not harsh white
    final baseTextTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.darkTextPrimary,
      displayColor: AppColors.darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brightBerry,
        secondary: AppColors.brightBerry,
        surface: AppColors.darkSurface, // Ink
        background: AppColors.darkBackground, // Dark Plum
        error: AppColors.brightWarmSpice,
        onPrimary:
            AppColors.darkPlum, // Dark text on bright buttons is easier to read
        onSecondary: AppColors.darkPlum,
        onSurface: AppColors.darkTextPrimary,
        onBackground: AppColors.darkTextPrimary,
        onError: AppColors.darkPlum,
      ),

      scaffoldBackgroundColor: AppColors.darkBackground, // Dark Plum (#1C0F16)
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground, // Blend with background
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // Text Theme
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
          letterSpacing: 0.2,
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brightBerry,
          foregroundColor: AppColors
              .darkPlum, // Black/Plum text on Neon Pink button = High Legibility
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            ),
          elevation: 0,
          disabledBackgroundColor: AppColors.darkSurface,
          disabledForegroundColor: AppColors.darkTextDisabled,
        ),
      ),

      // Outlined Button (Needs high contrast borders in dark mode)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.brightBerry,
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.allMd,
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return const BorderSide(
                    color: AppColors.darkBorder,
                    width: 1,
                  );
                }
                return const BorderSide(
                  color: AppColors.brightBerry,
                  width: 1.5,
                );
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.darkTextDisabled;
                }
                return AppColors.brightBerry;
              }),
            ),
      ),

      // Text Buttons (match light theme structure to avoid lerp issues)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brightBerry,
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      // Input Decoration (Subtle borders, clear fill)
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface, // Ink
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: TextStyle(color: AppColors.darkTextDisabled),
        // Borders
        border: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.brightBerry, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.brightWarmSpice, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.allMd,
          borderSide: BorderSide(color: AppColors.brightWarmSpice, width: 1.5),
        ),
        errorStyle: TextStyle(color: AppColors.brightWarmSpice),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
