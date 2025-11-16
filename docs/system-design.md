# Pyble Design System

**Version:** 1.0
**Theme:** "Warm, Clear & Trustworthy"

This document defines the complete visual design language for the Pyble app. This design system emphasizes trust, clarity, warmth, and a unique, accessible user experience.

---

## 1. Color Palette

### Primary Colors

* **Deep Berry (Brand & Action):** `#B70043`
    * *Usage:* Primary buttons, logos, active states, links, and all core interactive elements.
* **Snow (Main Background):** `#FFFFFF`
    * *Usage:* Main app background, card surfaces. Provides max clarity and contrast.
* **Light Crust (Accent Background):** `#F9F6F2`
    * *Usage:* Secondary backgrounds (e.g., "Your Total" panel), input field backgrounds, subtle hover states.

### Neutral Colors

* **Dark Fig (Main Text):** `#4A2C40`
    * *Usage:* All text (Headings, body, labels). Replaces pure black for a softer, on-brand feel. (9.4:1 contrast on Snow).
* **Pale Gray (Borders & Inactive):** `#E0E0E0`
    * *Usage:* Subtle separators, card borders, dividers, inactive component *backgrounds*.
* **Disabled Text:** `Color(0x804A2C40)` (`Dark Fig` at 50% Opacity)
    * *Usage:* All disabled text and icons. **Do not use `Pale Gray` for text.**

### Semantic Colors

* **Lush Green (Positive):** `#008A64`
    * *Usage:* "Settled," "Paid," success confirmations. (4.55:1 contrast).
* **Warm Spice (Negative/Alert):** `#D95300`
    * *Usage:* "You Owe," errors, alerts, delete actions, "Pending" status. (4.5:1 contrast).

### Tints (UI Accents)

* **Light Berry (Highlight):** `#FFF8FB`
    * *Usage:* Background for "claimed" items, active menu items.
* **Light Green (Positive BG):** `#E6F4F0`
    * *Usage:* Background for "Settled" badges.
* **Light Warm Spice (Negative BG):** `#FFF0E6`
    * *Usage:* Background for "Pending" badges, error states.

---

## 2. Typography

* **Font Family:** **Inter** (from Google Fonts).
* **Text Color:** All text defaults to `Dark Fig (#4A2C40)`.

| Style | Size (sp) | Weight | Letter Spacing | Usage |
|:------|:----------|:-------|:---------------|:------|
| **Display** | 32 | Bold (700) | -0.5 | Hero totals, large table codes |
| **Heading 1** | 24 | Semibold (600) | 0 | Screen titles ("History") |
| **Heading 2** | 20 | Semibold (600) | 0 | Section headers ("Participants") |
| **Body Large** | 16 | Regular (400) | 0 | Main body text, item names |
| **Body Small** | 14 | Regular (400) | 0 | Secondary text, helper text |
| **Button** | 16 | Semibold (600) | 0 | All button text |
| **Caption** | 12 | Medium (500) | +0.2 | Small labels, timestamps |

#### Special Case: Numerals

All prices and numbers *must* use tabular figures for alignment.

```dart
// Flutter Implementation for prices
Text(
  'R 120.50',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600, // Semibold for clarity
    color: AppColors.darkFig,
    fontFeatures: [
      FontFeature.tabularFigures(),
    ],
  ),
)
```

---

## 3. Spacing & Layout

* **Grid System:** 8-point grid. All spacing/padding is a multiple of 4.
* **Core Unit:** `8.0`
  * `xs`: 4.0
  * `sm`: 8.0
  * `md`: 16.0
  * `lg`: 24.0
  * `xl`: 32.0
* **Screen Padding:** `EdgeInsets.symmetric(horizontal: 16.0)`
* **Touch Targets:** Minimum `48x48` dp for all interactive elements.

---

## 4. Components

### Buttons

**Primary Button (Deep Berry)**

* **Use:** "Create Table," "Pay in App," "Confirm."
* **Background:** `AppColors.deepBerry`
* **Text:** `AppColors.snow`
* **Disabled BG:** `AppColors.paleGray`
* **Disabled Text:** `AppColors.darkFig.withOpacity(0.5)`

**Secondary Button (Outline)**

* **Use:** "Paid Outside App," "Retake," "Cancel."
* **Outline:** `AppColors.deepBerry` (2px width)
* **Text:** `AppColors.deepBerry`
* **Disabled Outline:** `AppColors.paleGray`
* **Disabled Text:** `AppColors.darkFig.withOpacity(0.5)`

**Destructive Button (Text)**

* **Use:** "Sign Out," "Delete Account."
* **Text:** `AppColors.warmSpice`
* **Icon:** `AppColors.warmSpice`

### Bill Item Row

* **Container:** `InkWell` with `onTap` for claiming.
* **Default State:** `Snow` background.
* **Claimed State:** `Light Berry` background, with a `4px Deep Berry` left border.
* **Divider:** `1px Pale Gray` divider between items.
* **Text:** `Body Large` (16sp) for name.
* **Price:** `16sp Semibold` with `tabularFigures()`.

### Status Badges (Pills)

* **Settled / Paid:**
  * **BG:** `Light Green`
  * **Text:** `Lush Green`
* **Pending / Awaiting:**
  * **BG:** `Light Warm Spice`
  * **Text:** `Warm Spice`

### Input Fields

* **BG:** `Snow`
* **Border:** `1.5px Pale Gray`
* **Focused Border:** `2px Deep Berry`
* **Error Border:** `2px Warm Spice`
* **Error BG:** `Light Warm Spice`
* **Text:** `Dark Fig`

### Drawer

* **BG:** `Snow`
* **Header:** `Deep Berry` (or gradient) to display user info.
* **Menu Item (Active):** `Light Berry` background, `4px Deep Berry` left border.
* **Menu Item (Inactive):** `Snow` background.
* **Destructive Item (Sign Out):** `Warm Spice` text and icon.

---

## 5. Flutter Implementation

### `AppColors` Class

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const deepBerry = Color(0xFFB70043);
  
  // Neutrals
  static const snow = Color(0xFFFFFFFF);
  static const lightCrust = Color(0xFFF9F6F2);
  static const paleGray = Color(0xFFE0E0E0); // Inactive BG / Border
  
  // Text
  static const darkFig = Color(0xFF4A2C40);
  static const disabledText = Color(0x804A2C40); // Dark Fig @ 50%

  // Semantic
  static const lushGreen = Color(0xFF008A64);  // Positive
  static const warmSpice = Color(0xFFD95300);  // Negative

  // Tints (UI Accents)
  static const lightBerry = Color(0xFFFFF8FB);
  static const lightGreen = Color(0xFFE6F4F0);
  static const lightWarmSpice = Color(0xFFFFF0E6);
}
```

### `AppRadius` Class

```dart
import 'package:flutter/material.dart';

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;

  static const Radius circularSm = Radius.circular(sm);
  static const Radius circularMd = Radius.circular(md);
  static const Radius circularLg = Radius.circular(lg);

  static const BorderRadius allSm = BorderRadius.all(circularSm);
  static const BorderRadius allMd = BorderRadius.all(circularMd);
  static const BorderRadius allLg = BorderRadius.all(circularLg);
}
```

### `AppTheme` Class (ThemeData)

```dart
import 'package:flutter/material.dart';
// Make sure to import your AppColors and AppRadius files
// import 'app_colors.dart';
// import 'app_radius.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: AppColors.deepBerry,
        secondary: AppColors.deepBerry,
        surface: AppColors.snow,
        background: AppColors.snow, // Main app background
        error: AppColors.warmSpice,
        onPrimary: AppColors.snow,
        onSecondary: AppColors.snow,
        onSurface: AppColors.darkFig,
        onBackground: AppColors.darkFig,
        onError: AppColors.snow,
      ),

      scaffoldBackgroundColor: AppColors.snow,

      // AppBar Theme (Clean White)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.snow,
        foregroundColor: AppColors.darkFig, // For icons
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.paleGray,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkFig,
          fontFamily: 'Inter',
        ),
      ),
      
      // (Alternative: Branded Berry AppBar)
      // appBarTheme: const AppBarTheme(
      //   backgroundColor: AppColors.deepBerry,
      //   foregroundColor: AppColors.snow,
      //   ...
      // ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.darkFig, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkFig),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkFig),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.darkFig),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.darkFig),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkFig), // For Buttons
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkFig, letterSpacing: 0.2),
      ).apply(
        bodyColor: AppColors.darkFig,
        displayColor: AppColors.darkFig,
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBerry,
          foregroundColor: AppColors.snow,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          elevation: 1,
          shadowColor: AppColors.deepBerry.withOpacity(0.2),
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.allMd),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ).copyWith(
          side: MaterialStateProperty.resolveWith<BorderSide?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return const BorderSide(color: AppColors.paleGray, width: 2);
              }
              return const BorderSide(color: AppColors.deepBerry, width: 2);
            },
          ),
          foregroundColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
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
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
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
```
