import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs_provider.dart';
import '../data/settings_repository_impl.dart';
import '../domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(sharedPrefsProvider)),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  void _update(AppSettings next) {
    state = next;
    ref.read(settingsRepositoryProvider).save(next);
  }

  void setBrandColor(Color c) => _update(state.copyWith(brandColor: c));
  void setThemeMode(ThemeMode m) => _update(state.copyWith(themeMode: m));
  void setLanguage(String code) => _update(state.copyWith(languageCode: code));
  void setIdleSeconds(int s) => _update(state.copyWith(idleSeconds: s));
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
