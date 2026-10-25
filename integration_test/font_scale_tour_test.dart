import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naapbooks_visitor_kiosk/app.dart';
import 'package:naapbooks_visitor_kiosk/core/l10n/app_strings.dart';
import 'package:naapbooks_visitor_kiosk/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks the main screens at TEXT SCALE 2.0 in English, Hindi and Gujarati on the
/// real device (real fonts, real screen) and fails on any layout exception
/// (overflow stripes). Screenshots go to evidence/auto/ through the driver:
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/font_scale_tour_test.dart -d DEVICE_ID \
///     --dart-define=API_BASE_URL=http://localhost:4000      (after adb reverse tcp:4000 tcp:4000)
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } catch (_) {/* web / unsupported */}
  }

  testWidgets('200% font tour: en, hi, gu', (tester) async {
    try {
      await binding.convertFlutterSurfaceToImage(); // needed for screenshots on Android
    } catch (_) {}
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    for (final lang in ['en', 'hi', 'gu']) {
      String s(String key) => AppStrings.table[lang]![key]!;

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.setString('settings.language', lang);
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        retry: (_, _) => null,
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const KioskApp(),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: '$lang: start');

      // Check-in: submit an empty form so every error message is on screen.
      await tester.scrollUntilVisible(find.text(s('submit')), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(s('submit')));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull, reason: '$lang: check-in errors');
      await shot('$lang-1-checkin-errors-bottom');
      await tester.scrollUntilVisible(find.text(s('checkin_title')), -300,
          scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 300));
      await shot('$lang-2-checkin-top');

      // Today's visitors (real API).
      await tester.tap(find.text(s('nav_visitors')).last);
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (find.byTooltip(RegExp('.+')).evaluate().length < 3 &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 300));
        final retry = find.text(s('retry'));
        if (retry.evaluate().isNotEmpty) await tester.tap(retry.first, warnIfMissed: false);
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: '$lang: visitors');
      await shot('$lang-3-visitors');

      // Admin: PIN gate, then the settings.
      await tester.tap(find.text(s('nav_admin')).last);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull, reason: '$lang: admin pin');
      await shot('$lang-4-admin-pin');
      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(s('brand_colour')), findsOneWidget, reason: '$lang: unlocked');
      expect(tester.takeException(), isNull, reason: '$lang: admin');
      await shot('$lang-5-admin');
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
