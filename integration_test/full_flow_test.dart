import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naapbooks_visitor_kiosk/app.dart';
import 'package:naapbooks_visitor_kiosk/core/storage/prefs_provider.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_form.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_providers.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/presentation/host_directory.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end run of the whole kiosk against the REAL mock API
/// (`node server.js`, 300-1500 ms latency, ~5 % random 500s). Layout-agnostic:
/// it detects phone (single pane) vs tablet/web (two panes) and takes the
/// matching path, so the same file runs at any window size or on a device.
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/full_flow_test.dart -d chrome --browser-dimension=390,844
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> launch(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KioskApp()));
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  /// Pumps until [finder] matches. The mock API fails ~5 % of calls on purpose,
  /// so any visible "Retry" button is tapped along the way (that is the flow a
  /// guard would follow too).
  Future<void> until(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 40), String? what}) async {
    final end = DateTime.now().add(timeout);
    var sinceRetry = 0;
    var retries = 0;
    String? lastRetryError;
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
      sinceRetry++;
      final retry = find.ancestor(
          of: find.text('Retry'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      if (retry.evaluate().isNotEmpty && sinceRetry > 2) {
        sinceRetry = 0;
        retries++;
        try {
          await tester.ensureVisible(retry.first);
          await tester.tap(retry.first);
        } catch (e) {
          lastRetryError = '$e';
        }
      }
    }
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((s) => s.isNotEmpty)
        .take(25)
        .join(' | ');
    fail('Timed out waiting for ${what ?? finder.describeMatch(Plurality.one)}. '
        'Retries tapped: $retries, last retry error: $lastRetryError. '
        'Screen shows: $texts');
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200,
          scrollable: find
              .descendant(of: find.byType(CheckinForm), matching: find.byType(Scrollable))
              .first);
    }
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Types like a person: bring the field on screen, tap it to focus, then type.
  Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
    await reveal(tester, field);
    await tester.tap(field);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } catch (_) {/* screenshots are web/driver only */}
  }

  testWidgets('full kiosk flow against the live mock API', (tester) async {
    final semantics = tester.ensureSemantics();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // ---- 1. App starts on the check-in screen ---------------------------
    var container = await launch(tester);
    expect(find.text('Visitor check-in'), findsOneWidget);
    final twoPane = find.byType(HostDirectory).evaluate().isNotEmpty;
    // ignore: avoid_print
    print('LAYOUT: ${twoPane ? "two-pane (tablet/web)" : "single-pane (phone)"} '
        '${tester.view.physicalSize}');
    await shot('01-home');

    // ---- 2. Half-filled form survives the app being killed --------------
    await typeInto(tester, find.widgetWithText(TextFormField, 'Full name'), 'Riya Patel');
    await tester.pump(const Duration(milliseconds: 300));
    container.dispose();
    container = await launch(tester); // new provider tree == process restart
    expect(find.text('Your unfinished form was restored.'), findsOneWidget);
    expect(find.text('Riya Patel'), findsOneWidget);

    // ---- 3. Host directory: load, debounced search, pick ----------------
    if (!twoPane) {
      await reveal(tester, find.text('Choose who you are visiting'));
      await tester.tap(find.text('Choose who you are visiting'));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await until(tester, find.byType(HostTile), what: 'host list');
    await shot('02-hosts');
    final search = find.descendant(
        of: find.byType(HostDirectory), matching: find.byType(TextField));
    await typeInto(tester, search.first, 'shah');
    await tester.pump(const Duration(milliseconds: 700)); // > 300 ms debounce
    await until(tester, find.byType(HostTile), what: 'search results');
    await shot('03-host-search');
    await tester.tap(find.byType(HostTile).first);
    await tester.pump(const Duration(seconds: 1));
    if (!twoPane) {
      await until(tester, find.widgetWithText(TextFormField, 'Full name'),
          what: 'back on the form', timeout: const Duration(seconds: 8));
    }
    expect(find.text('Choose who you are visiting'), findsNothing,
        reason: 'the picked host is shown in the form');

    // ---- 4. Fill the form ------------------------------------------------
    // invalid mobile + no consent must block the submit
    await reveal(tester, find.widgetWithText(TextFormField, 'Mobile number'));
    await typeInto(tester, find.widgetWithText(TextFormField, 'Mobile number'), '5123456789');
    await reveal(tester, find.widgetWithText(FilledButton, 'Check in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Enter a valid 10-digit mobile number starting with 6–9.'),
        findsOneWidget);
    expect(find.text("You're checked in"), findsNothing);
    await shot('04-validation');

    await reveal(tester, find.widgetWithText(TextFormField, 'Mobile number'));
    await typeInto(tester, find.widgetWithText(TextFormField, 'Mobile number'), '9876543210');
    await tester.pump(const Duration(milliseconds: 300));
    final editable = tester.widget<EditableText>(find.descendant(
        of: find.widgetWithText(TextFormField, 'Mobile number'),
        matching: find.byType(EditableText)));
    expect(find.text('Enter a valid 10-digit mobile number starting with 6–9.'), findsNothing,
        reason: 'error clears once the number is valid; controller="${editable.controller.text}" '
            'hasFocus=${editable.focusNode.hasFocus} '
            'primaryFocus=${FocusManager.instance.primaryFocus?.debugLabel} '
            'draft=${container.read(checkinProvider).mobile}');
    await reveal(tester, find.byType(DropdownButtonFormField<String>));
    await until(tester, find.byType(DropdownButtonFormField<String>), what: 'purposes');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Meeting').last);
    await tester.pump(const Duration(milliseconds: 600));
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('05-form-filled');

    // ---- 5. Submit -> badge ----------------------------------------------
    final d = container.read(checkinProvider);
    expect(
        '${d.name}|${d.mobile}|${d.purposeId != null}|${d.hostId != null}|${d.consent}',
        'Riya Patel|9876543210|true|true|true',
        reason: 'draft before submit');
    await reveal(tester, find.widgetWithText(FilledButton, 'Check in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await until(tester, find.text("You're checked in"), what: 'badge screen');
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Returning to home in'), findsOneWidget);
    expect(find.textContaining('Riya Patel'), findsWidgets);
    await shot('06-badge');

    // ---- 6. Idle timeout (default 20 s) returns home, form cleared -------
    await until(tester, find.text('Visitor check-in'),
        timeout: const Duration(seconds: 30), what: 'return home after idle');
    expect(find.text('Riya Patel'), findsNothing);
    expect(find.text('Your unfinished form was restored.'), findsNothing);
    await shot('07-after-idle');

    // ---- 7. Today's visitors: load, undo, check-out, refresh, paging ----
    await tester.tap(find.text('Visitors').first);
    final checkoutBtn = find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').startsWith('Check out:'));
    await until(tester, checkoutBtn, what: 'visitor list');
    await shot('08-visitors');
    final tip = (checkoutBtn.evaluate().first.widget as Tooltip).message!;
    final name = tip.substring('Check out: '.length);

    await tester.ensureVisible(checkoutBtn.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(checkoutBtn.first);
    await until(tester, find.text('$name checked out'),
        timeout: const Duration(seconds: 6), what: 'undo snackbar');
    await shot('09-undo-snackbar');
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(name), findsWidgets, reason: 'undo restores the row');

    // Repeated runs leave several checked-in visitors with the same name on the
    // server, so assert exactly one fewer row rather than none.
    final sameName = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Check out: $name');
    final rowsBefore = sameName.evaluate().length;
    await tester.tap(sameName.first);
    await tester.pump(const Duration(seconds: 7)); // undo window lapses -> POST
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining("Couldn't check out"), findsNothing);
    expect(sameName.evaluate().length, rowsBefore - 1,
        reason: 'the checked-out row is gone and stays gone');

    // pull to refresh, then scroll for the next page
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1500);
    await tester.pump(const Duration(seconds: 3));
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -1500), 3000);
      await tester.pump(const Duration(seconds: 2));
    }
    expect(tester.takeException(), isNull);
    await shot('10-visitors-scrolled');

    // ---- 8. Admin: PIN, colour, dark, language, restore -------------------
    await tester.tap(find.text('Admin').first);
    await tester.pump(const Duration(milliseconds: 600));
    await typeInto(tester, find.byType(TextField).first, '0000');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Incorrect PIN'), findsOneWidget);
    await typeInto(tester, find.byType(TextField).first, '1234');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Brand colour'), findsOneWidget);

    Color primary() =>
        Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary;
    final before = primary();
    await tester.tap(find.bySemanticsLabel('Colour option 5'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(primary(), isNot(before), reason: 'brand colour applies immediately');
    await tester.tap(find.text('Dark'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    await shot('11-admin-dark');
    await tester.tap(find.text('ગુજરાતી'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ચેક-ઇન'), findsWidgets);
    await shot('12-admin-gujarati');
    await until(tester, find.text('English'),
        timeout: const Duration(seconds: 6), what: 'English language option');
    await tester.ensureVisible(find.text('English'));
    await tester.tap(find.text('English'));
    await until(tester, find.text('Light'),
        timeout: const Duration(seconds: 6), what: 'Light option after switching to English');
    await tester.ensureVisible(find.text('Light'));
    await tester.tap(find.text('Light'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Check-in'), findsWidgets);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
