import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const deepBerry = Color(0xFFB70043);

  // Neutrals
  static const snow = Color(0xFFFFFFFF);
  static const lightCrust = Color(0xFFF9F6F2);
  static const paleGray = Color(0xFFE0E0E0);
  static const midnight = Color(0xFF0F080C);
  static const darkPlum = Color(0xFF1C0F16);
  static const ink = Color(0xFF2A1B24);

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

  // Dark Theme UI Colors (Based on design-system.md)
  static const darkFigBackground = Color(0xFF4A2C40); // Our main dark background
  static const darkSurface = Color(0xFF5A3C50); // For cards, appbars, etc.

  // Brighter "Dark Mode" Brand & Semantic Colors
  // These are required for accessible contrast on dark backgrounds
  static const brightBerry = Color(0xFFE73A7B);
  static const brightGreen = Color(0xFF00E0A3);
  static const brightWarmSpice = Color(0xFFFF8A4D);

  // Dark Theme Text
  static const darkTextPrimary = Color(0xFFFFFFFF); // Replaces Snow
  static const darkTextSecondary = Color(0xFFE0E0E0); // Replaces Pale Gray
  static const darkTextDisabled = Color(0x80FFFFFF); // Snow @ 50%
  static const darkBorder = Color(0x4DE0E0E0); // Pale Gray @ 30%
}
