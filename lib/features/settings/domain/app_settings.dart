import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';

class AppSettings {
  const AppSettings({
    this.brandColor = const Color(AppConfig.defaultBrandColor),
    this.themeMode = ThemeMode.system,
    this.languageCode = 'en',
    this.idleSeconds = AppConfig.defaultIdleSeconds,
  });

  final Color brandColor;
  final ThemeMode themeMode;
  final String languageCode;
  final int idleSeconds;

  AppSettings copyWith({
    Color? brandColor,
    ThemeMode? themeMode,
    String? languageCode,
    int? idleSeconds,
  }) =>
      AppSettings(
        brandColor: brandColor ?? this.brandColor,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
        idleSeconds: idleSeconds ?? this.idleSeconds,
      );
}

abstract interface class SettingsRepository {
  AppSettings load();
  Future<void> save(AppSettings settings);
}
