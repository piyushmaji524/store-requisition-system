import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors matching Gunayatan Logo
  static const Color primaryGold = Color(0xFFD97706);      // Amber / Temple Gold
  static const Color primaryGoldDark = Color(0xFFB45309);  // Deep Gold
  static const Color primaryGoldLight = Color(0xFFF59E0B); // Bright Gold
  static const Color primaryGoldSoft = Color(0xFFFEF3C7);  // Soft Gold Tint

  static const Color saffron = Color(0xFFEA580C);          // Spiritual Saffron
  static const Color saffronDark = Color(0xFFC2410C);      // Deep Saffron
  static const Color saffronLight = Color(0xFFFB923C);     // Light Saffron
  static const Color saffronSoft = Color(0xFFFFEDD5);      // Soft Saffron Tint

  static const Color royalNavy = Color(0xFF0F172A);        // Deep Navy / Slate
  static const Color royalNavyLight = Color(0xFF1E293B);   // Medium Slate
  static const Color navyAccent = Color(0xFF1E3A8A);       // Royal Blue Accent

  // Background & Surface (Light Mode Only)
  static const Color bgPearl = Color(0xFFFAF8F5);          // Warm Pearl Background
  static const Color surfaceWhite = Color(0xFFFFFFFF);     // Pure White Surface
  static const Color surfaceCard = Color(0xFFFFFFFF);      // Card Surface
  static const Color surfaceMuted = Color(0xFFF1EFEA);     // Muted Surface

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);      // High Contrast Deep Slate
  static const Color textSecondary = Color(0xFF475569);    // Slate Subtext
  static const Color textMuted = Color(0xFF94A3B8);        // Muted Gray Text
  static const Color textGold = Color(0xFFB45309);         // Gold Accent Text

  // Functional Status Colors
  static const Color successGreen = Color(0xFF10B981);     // Emerald Green
  static const Color successGreenSoft = Color(0xFFDCFCE7); // Light Green
  static const Color dangerRed = Color(0xFFEF4444);        // Crimson Red
  static const Color dangerRedSoft = Color(0xFFFEE2E2);    // Light Red
  static const Color warningOrange = Color(0xFFF59E0B);    // Warning Orange
  static const Color infoBlue = Color(0xFF0284C7);         // Sky Info Blue
  static const Color infoBlueSoft = Color(0xFFE0F2FE);     // Light Sky Blue

  // Border & Divider
  static const Color borderColor = Color(0xFFE2D9CC);      // Subtle Warm Border
  static const Color borderSubtle = Color(0xFFEFE8DE);    // Soft Border

  // Gradients
  static const LinearGradient goldSaffronGradient = LinearGradient(
    colors: [primaryGold, saffron],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyGoldGradient = LinearGradient(
    colors: [royalNavy, royalNavyLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softGoldCardGradient = LinearGradient(
    colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryGold,
      scaffoldBackgroundColor: bgPearl,
      colorScheme: const ColorScheme.light(
        primary: primaryGold,
        onPrimary: Colors.white,
        secondary: saffron,
        onSecondary: Colors.white,
        surface: surfaceWhite,
        onSurface: textPrimary,
        error: dangerRed,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGold,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerRed, width: 1.2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
