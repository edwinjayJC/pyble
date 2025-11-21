import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const deepBerry = Color(0xFFB70043);

  // Neutrals (The "Bones" of the app)
  static const snow = Color(0xFFFFFFFF);
  static const lightCrust = Color(0xFFF9F6F2);
  static const paleGray = Color(0xFFE0E0E0);

  // Dark Neutrals (Use these for backgrounds!)
  static const midnight = Color(0xFF0F080C); // Nearly black, hint of red
  static const darkPlum = Color(0xFF1C0F16); // Deep brownish-purple
  static const ink = Color(0xFF2A1B24); // Lighter purple-black

  // Text
  static const darkFig = Color(0xFF4A2C40);
  static const disabledText = Color(0x804A2C40);
  static const softLilac = Color(0xFFE2D1DA);
  static const dusk = Color(0xFFAC8BA0);

  // Semantic
  static const lushGreen = Color(0xFF008A64);
  static const warmSpice = Color(0xFFD95300);

  // Tints (UI Accents)
  static const lightBerry = Color(0xFFFFF8FB);
  static const lightGreen = Color(0xFFE6F4F0);
  static const lightWarmSpice = Color(0xFFFFF0E6);

  // --- DARK THEME MAPPING (FIXED) ---

  // Background: Use Dark Plum, not Dark Fig.
  // It is much easier on the eyes while keeping the "Fig" vibe.
  static const darkBackground = darkPlum;

  // Surface: Use Ink or Dark Fig for cards/modals so they sit "above" the background.
  static const darkSurface = ink;

  // Brighter accents for visibility on dark backgrounds
  static const brightBerry = Color(
    0xFFFF4D8C,
  ); // Slightly punched up from E73A7B
  static const brightGreen = Color(0xFF00E0A3);
  static const brightWarmSpice = Color(0xFFFF8A4D);

  // Dark Theme Text
  static const darkTextPrimary = Color(
    0xFFF9F6F2,
  ); // Light Crust (Warmer than pure white)
  static const darkTextSecondary = Color(0xFFAC8BA0); // Dusk (Good subtext)
  static const darkTextDisabled = Color(0x66F9F6F2);
  static const darkBorder = Color(
    0xFF4A2C40,
  ); // Dark Fig makes a great subtle border in dark mode
}
