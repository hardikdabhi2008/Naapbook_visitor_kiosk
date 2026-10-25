import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naapbooks_visitor_kiosk/app.dart';
import 'package:naapbooks_visitor_kiosk/core/storage/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Frame timings while scrolling Today's visitors (real API, real list).
///
/// MUST be run in profile mode on a real device to mean anything:
///   flutter drive --profile --no-dds -d DEVICE_ID \
///     --driver=test_driver/perf_driver.dart \
///     --target=integration_test/scroll_perf_test.dart \
///     --dart-define=API_BASE_URL=http://localhost:4000
/// The driver writes evidence/perf/visitors_scroll.timeline_summary.json.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scroll Today\'s visitors', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const KioskApp(),
    ));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Visitors').first);
    // Wait for the first page (the API is slow and fails ~5% of calls on purpose).
    final end = DateTime.now().add(const Duration(seconds: 40));
    while (find.byTooltip(RegExp('^Check out')).evaluate().isEmpty &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
      final retry = find.text('Retry');
      if (retry.evaluate().isNotEmpty) await tester.tap(retry.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(seconds: 1));

    final list = find.byType(Scrollable).first;
    await binding.traceAction(() async {
      // Down through ~3 pages (more pages load from the API as we go), then back up.
      for (var i = 0; i < 12; i++) {
        await tester.fling(list, const Offset(0, -700), 2600);
        await tester.pump(const Duration(milliseconds: 900));
      }
      for (var i = 0; i < 12; i++) {
        await tester.fling(list, const Offset(0, 700), 2600);
        await tester.pump(const Duration(milliseconds: 900));
      }
    }, reportKey: 'visitors_scroll');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
