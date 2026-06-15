import 'package:flutter/material.dart';

/// Reading-comfort palettes. Three selectable themes (light / sepia / dark)
/// tuned to reduce eye strain:
///
///  - We avoid pure white (#FFFFFF) backgrounds and pure black (#000000) with
///    pure white text. Maximum contrast looks "crisp" but is the most tiring
///    and causes halation (text glow/smear), worse with astigmatism.
///  - Light uses a soft off-white; dark uses a dark gray with light-gray (not
///    white) text; sepia is the classic warm e-reader palette for long reads.
class AppTheme {
  AppTheme._();

  // --- Light (softened: off-white instead of pure #FFFFFF) ---
  static const Color background = Color(0xFFFAF8F4);
  static const Color surface = Color(0xFFEFEDE7);
  static const Color accent = Color(0xFF2B2B2B);
  static const Color textPrimary = Color(0xFF2B2B2B);
  static const Color textSecondary = Color(0xFF6B6B6B);

  // --- Dark (softened: dark gray bg + light-gray text, no pure black/white) ---
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkText = Color(0xFFD0D0D0);
  static const Color darkAccent = Color(0xFFE6E6E6);
  static const Color darkSecondary = Color(0xFF9A9A9A);

  // --- Sepia (warm e-reader palette, most comfortable for long sessions) ---
  static const Color sepiaBackground = Color(0xFFF5ECD8);
  static const Color sepiaSurface = Color(0xFFEFE4CC);
  static const Color sepiaText = Color(0xFF5B4636);
  static const Color sepiaAccent = Color(0xFF6F4A2F);
  static const Color sepiaSecondary = Color(0xFF8A7355);

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: background,
        surface: surface,
        accent: accent,
        onAccent: Colors.white,
        text: textPrimary,
        secondary: textSecondary,
      );

  static ThemeData get sepia => _build(
        brightness: Brightness.light,
        background: sepiaBackground,
        surface: sepiaSurface,
        accent: sepiaAccent,
        onAccent: sepiaBackground,
        text: sepiaText,
        secondary: sepiaSecondary,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: darkBackground,
        surface: darkSurface,
        accent: darkAccent,
        onAccent: Colors.black,
        text: darkText,
        secondary: darkSecondary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color accent,
    required Color onAccent,
    required Color text,
    required Color secondary,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: secondary,
      onSecondary: onAccent,
      surface: surface,
      onSurface: text,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      cardColor: surface,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 16,
          height: 1.85,
          color: text,
        ),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: secondary, fontSize: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
      ),
    );
  }
}
