import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../domain/app_settings.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _color = 'settings.brandColor';
  static const _theme = 'settings.themeMode';
  static const _lang = 'settings.language';
  static const _idle = 'settings.idleSeconds';

  @override
  AppSettings load() {
    final mode = _prefs.getString(_theme);
    final lang = _prefs.getString(_lang);
    return AppSettings(
      brandColor: Color(_prefs.getInt(_color) ?? AppConfig.defaultBrandColor),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
      languageCode: const ['en', 'hi', 'gu'].contains(lang) ? lang! : 'en',
      idleSeconds: (_prefs.getInt(_idle) ?? AppConfig.defaultIdleSeconds)
          .clamp(AppConfig.minIdleSeconds, AppConfig.maxIdleSeconds),
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_color, s.brandColor.toARGB32());
    await _prefs.setString(_theme, s.themeMode.name);
    await _prefs.setString(_lang, s.languageCode);
    await _prefs.setInt(_idle, s.idleSeconds);
  }
}
