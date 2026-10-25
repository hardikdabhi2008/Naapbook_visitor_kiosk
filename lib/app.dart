import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/settings_controller.dart';

class KioskApp extends ConsumerWidget {
  const KioskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.tr('app_title'),
      routerConfig: ref.watch(routerProvider),
      locale: Locale(settings.languageCode),
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Rebuilt from the brand colour, so the whole app re-themes instantly.
      theme: AppTheme.build(settings.brandColor, Brightness.light),
      darkTheme: AppTheme.build(settings.brandColor, Brightness.dark),
      themeMode: settings.themeMode,
    );
  }
}
