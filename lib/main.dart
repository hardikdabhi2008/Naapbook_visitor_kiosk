import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    // Riverpod 3 retries failed providers automatically. Turn that off: the
    // brief wants a visible error state with a manual Retry button.
    retry: (_, _) => null,
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const KioskApp(),
  ));
}
