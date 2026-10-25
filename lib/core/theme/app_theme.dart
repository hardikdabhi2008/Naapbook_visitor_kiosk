import 'package:flutter/material.dart';

/// Builds the app theme from the admin-chosen brand colour. Everything reads
/// from [ColorScheme], so changing the seed re-themes the whole app at once.
class AppTheme {
  const AppTheme._();

  static const brandChoices = <Color>[
    Color(0xFF1565C0),
    Color(0xFF00796B),
    Color(0xFF2E7D32),
    Color(0xFFEF6C00),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFFAD1457),
    Color(0xFF37474F),
  ];

  /// Bundled fonts for the non-Latin UI languages (see pubspec.yaml).
  static const fontFallback = <String>['NotoSansDevanagari', 'NotoSansGujarati'];

  static ThemeData build(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    const minTarget = Size(64, 48);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Latin text keeps the platform font; Devanagari / Gujarati glyphs fall
      // through to these bundled fonts, so they never render as empty boxes.
      fontFamilyFallback: fontFallback,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minTarget),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minTarget),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
