import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/app.dart';
import 'package:naapbooks_visitor_kiosk/core/error/api_exception.dart';
import 'package:naapbooks_visitor_kiosk/core/storage/prefs_provider.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_form.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/domain/host.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/presentation/host_directory.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/presentation/host_providers.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/domain/visitor.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/presentation/visitor_providers.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/presentation/visitors_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Records calls and can fail the first host fetch.
class SpyVisitors extends FakeVisitorRepo {
  int checkOuts = 0;
  int checkIns = 0;
  NewVisitor? lastNew;

  @override
  Future<Visitor> checkOut(String id) async {
    checkOuts++;
    return super.checkOut(id);
  }

  @override
  Future<Visitor> checkIn(NewVisitor visitor) async {
    checkIns++;
    lastNew = visitor;
    return super.checkIn(visitor);
  }
}

/// Like the real API's seeded day: a check-in made "now" is NOT on page 1 of
/// the list (it sorts further down), and checking in returns a brand-new visitor.
class NewPersonVisitors extends SpyVisitors {
  Visitor _make(NewVisitorLike v, VisitorStatus status) => Visitor(
        id: 'v_new',
        name: v.name,
        mobile: v.mobile,
        company: null,
        purposeId: 'meeting',
        hostId: v.hostId,
        hostName: 'Aarav Shah 1',
        status: status,
        checkInAt: DateTime(2026, 10, 24, 12),
        checkOutAt: status == VisitorStatus.checkedOut ? DateTime(2026, 10, 24, 13) : null,
        expectedAt: DateTime(2026, 10, 24, 12),
        hasPhoto: false,
        badgeCode: 'NBV-NEW123',
        consent: true,
      );

  late NewVisitorLike _created;

  @override
  Future<Visitor> checkIn(NewVisitor visitor) async {
    checkIns++;
    lastNew = visitor;
    _created = (name: visitor.name, mobile: visitor.mobile, hostId: visitor.hostId);
    return _make(_created, VisitorStatus.checkedIn);
  }

  @override
  Future<Visitor> checkOut(String id) async {
    checkOuts++;
    if (id != 'v_new') return super.checkOut(id);
    return _make(_created, VisitorStatus.checkedOut);
  }
}

typedef NewVisitorLike = ({String name, String mobile, String hostId});

/// The purposes request fails [failures] times (with [kind]) before it succeeds.
class FlakyPurposes extends SpyVisitors {
  FlakyPurposes(this.failures, {this.kind = FailureKind.server});
  final int failures;
  final FailureKind kind;
  int calls = 0;

  @override
  Future<List<Purpose>> fetchPurposes() async {
    if (calls++ < failures) throw ApiException(kind);
    return super.fetchPurposes();
  }
}

class FailingVisitors extends FakeVisitorRepo {
  FailingVisitors(this.error);
  ApiException? error;
  int calls = 0;

  @override
  Future<Visitor> checkIn(NewVisitor visitor) async {
    calls++;
    if (error != null) throw error!;
    return super.checkIn(visitor);
  }
}

class FlakyHosts extends FakeHostRepo {
  int calls = 0;

  @override
  Future<List<Host>> fetchHosts() {
    if (calls++ == 0) throw const ApiException(FailureKind.server);
    return super.fetchHosts();
  }
}

Future<(ProviderContainer, SpyVisitors, FlakyHosts)> boot(
  WidgetTester tester, {
  Size size = const Size(390, 1500),
  Map<String, Object> prefs = const {},
  double textScale = 1.0,
  SpyVisitors? visitorsRepo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final visitors = visitorsRepo ?? SpyVisitors();
  final hosts = FlakyHosts();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(p),
      hostRepositoryProvider.overrideWithValue(hosts),
      visitorRepositoryProvider.overrideWithValue(visitors),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KioskApp()));
  await tester.pumpAndSettle();
  return (container, visitors, hosts);
}

Future<void> pumpFor(WidgetTester tester, Duration d) async {
  for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 250)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('phone: pick host (search + highlight) -> fill form -> badge -> idle returns home',
      (tester) async {
    final (_, visitors, hosts) =
        await boot(tester, prefs: {'settings.idleSeconds': 10});
    hosts.calls = 1; // skip the deliberate first failure in this test

    // Host picker, debounced search
    await tester.tap(find.text('Choose who you are visiting'));
    await tester.pumpAndSettle();
    expect(find.byType(HostTile), findsWidgets);
    await tester.enterText(find.byType(TextField), 'shah 1');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('20 hosts'), findsOneWidget, reason: 'debounce: not applied yet');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('11 hosts'), findsOneWidget); // Shah 1, Shah 10..19
    await tester.tap(find.widgetWithText(HostTile, 'Aarav Shah 12')); // an available host
    await tester.pumpAndSettle();
    expect(find.text('Aarav Shah 12'), findsOneWidget); // now in the form

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Riya Patel');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile number'), '9876543210');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meeting').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(visitors.checkIns, 1);
    expect(visitors.lastNew!.mobile, '9876543210');
    expect(visitors.lastNew!.hostId, 'h_12');
    expect(find.text("You're checked in"), findsOneWidget);
    expect(find.textContaining('Returning to home in'), findsOneWidget);

    // Touch resets the countdown; otherwise idle returns to the form.
    await pumpFor(tester, const Duration(seconds: 6));
    await tester.tapAt(const Offset(10, 300));
    await pumpFor(tester, const Duration(seconds: 6));
    expect(find.text("You're checked in"), findsOneWidget, reason: 'timer was reset');
    await pumpFor(tester, const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Visitor check-in'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    // Form was cleared after the successful submit.
    expect(find.text('Riya Patel'), findsNothing);
  });

  testWidgets('submitting an empty form shows every required-field message, purpose included',
      (tester) async {
    final (_, visitors, _) = await boot(tester, size: const Size(390, 2000));
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name (2–80 characters).'), findsOneWidget);
    expect(find.text('Enter a valid 10-digit mobile number starting with 6–9.'), findsOneWidget);
    expect(find.text('Choose a purpose.'), findsOneWidget, reason: 'purpose dropdown error');
    expect(find.text('Choose a host.'), findsOneWidget);
    expect(find.text('Consent is required.'), findsOneWidget);
    expect(visitors.checkIns, 0);

    // Picking a purpose clears just that message.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meeting').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose a purpose.'), findsNothing);
  });

  testWidgets('a new check-in shows at the top of Today\'s visitors, even if the server sorts it lower',
      (tester) async {
    final (_, visitors, hosts) = await boot(tester,
        visitorsRepo: NewPersonVisitors(),
        prefs: {
          'draft.fields':
              '{"name":"Sneha Test","mobile":"9876543210","purposeId":"meeting","hostId":"h_2","hostName":"Aarav Shah 2","consent":true}',
        });
    hosts.calls = 1;
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(visitors.checkIns, 1);
    expect(find.text("You're checked in"), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<VisitorTile>(find.byType(VisitorTile)).toList();
    expect(tiles.first.visitor.name, 'Sneha Test',
        reason: 'new check-in is pinned on top; list = ${tiles.map((t) => t.visitor.name).toList()}');
    expect(tiles.first.visitor.status, VisitorStatus.checkedIn);
    expect(tiles.map((t) => t.visitor.name), contains('Riya Patel'),
        reason: 'the rest of the day is still listed below');
    expect(tiles.where((t) => t.visitor.id == 'v_new').length, 1, reason: 'no duplicate');

    // Checking the pinned visitor out keeps the row, now as Checked out.
    await tester.tap(find.byTooltip('Check out: Sneha Test'));
    await pumpFor(tester, const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(visitors.checkOuts, 1);
    final after = tester.widgetList<VisitorTile>(find.byType(VisitorTile)).first.visitor;
    expect(after.name, 'Sneha Test');
  });

  testWidgets('host status flips to Unavailable after a check-in and back after check-out',
      (tester) async {
    await boot(tester,
        size: const Size(1280, 1400),
        visitorsRepo: NewPersonVisitors(),
        prefs: {
          'draft.fields':
              '{"name":"Sneha Test","mobile":"9876543210","purposeId":"meeting","hostId":"h_2","hostName":"Aarav Shah 2","consent":true}',
        });
    // The directory's first load fails on purpose in this fake; retry it.
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    Finder status(String text) =>
        find.descendant(of: find.byKey(const ValueKey('h_2')), matching: find.text(text));
    expect(status('Available'), findsOneWidget, reason: 'h_2 starts available');

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("You're checked in"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(status('Unavailable'), findsOneWidget, reason: 'host is busy with the new visitor');
    expect(status('Available'), findsNothing);

    // Other hosts are untouched.
    expect(
        find.descendant(of: find.byKey(const ValueKey('h_4')), matching: find.text('Available')),
        findsOneWidget);

    // Checking the visitor out frees the host AT ONCE, not after the undo window.
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Check out: Sneha Test'));
    await tester.pump(const Duration(milliseconds: 500)); // well inside the 5 s window
    await tester.tap(find.text('Check-in'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(status('Available'), findsOneWidget, reason: 'freed immediately on check-out');
    expect(status('Unavailable'), findsNothing);

    // Undo (the snackbar is still showing) makes the host busy again.
    await tester.tap(find.text('Undo'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(status('Unavailable'), findsOneWidget, reason: 'undo restores the busy status');

    // A check-out that is allowed to complete leaves the host free.
    await tester.tap(find.text('Visitors'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Check out: Sneha Test'));
    await pumpFor(tester, const Duration(seconds: 7)); // window lapses, server call done
    await tester.tap(find.text('Check-in'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(status('Available'), findsOneWidget, reason: 'host stays free once checked out');
  });

  testWidgets('choosing an unavailable host shows an error and blocks check-in until another host is chosen',
      (tester) async {
    final (_, visitors, _) = await boot(tester,
        size: const Size(1280, 1400),
        prefs: {
          'draft.fields':
              '{"name":"Sneha Test","mobile":"9876543210","purposeId":"meeting","consent":true}',
        });
    await tester.tap(find.widgetWithText(FilledButton, 'Retry')); // first host load fails on purpose
    await tester.pumpAndSettle();

    const unavailableMsg = 'Aarav Shah 1 is unavailable right now. Please choose another host.';
    expect(find.text(unavailableMsg), findsNothing);

    // h_1 is marked unavailable in the fake host data.
    await tester.tap(find.byKey(const ValueKey('h_1')));
    await tester.pumpAndSettle();
    expect(find.text(unavailableMsg), findsOneWidget, reason: 'shown as soon as it is picked');

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(visitors.checkIns, 0, reason: 'check-in is blocked for an unavailable host');
    expect(find.text("You're checked in"), findsNothing);
    expect(find.text(unavailableMsg), findsOneWidget);

    // An available host (h_2) clears the error and the check-in goes through.
    await tester.tap(find.byKey(const ValueKey('h_2')));
    await tester.pumpAndSettle();
    expect(find.text(unavailableMsg), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(visitors.checkIns, 1);
    expect(visitors.lastNew!.hostId, 'h_2');
    expect(find.text("You're checked in"), findsOneWidget);
  });

  testWidgets('purposes: transient failures are retried quietly and the dropdown still loads',
      (tester) async {
    final repo = FlakyPurposes(2); // two 500s, then success
    await boot(tester, size: const Size(390, 2000), visitorsRepo: repo);
    await tester.pump(const Duration(seconds: 3)); // 400 ms + 800 ms back-off
    await tester.pumpAndSettle();
    expect(repo.calls, 3);
    expect(find.text("Couldn't load purposes."), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('purposes: when the server cannot be reached, say so and offer Retry',
      (tester) async {
    final repo = FlakyPurposes(100, kind: FailureKind.network); // never recovers
    await boot(tester, size: const Size(390, 2000), visitorsRepo: repo);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(repo.calls, 3, reason: 'gives up after 3 attempts');
    expect(find.text("Can't reach the server. Check your connection."), findsOneWidget);
    final retry = find.widgetWithText(TextButton, 'Retry');
    expect(retry, findsOneWidget);

    // Retry asks again (3 more attempts) and the error stays until it works.
    await tester.tap(retry);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(repo.calls, 6);
  });

  testWidgets('restored banner shows only for the startup draft, not after Clear',
      (tester) async {
    await boot(tester, prefs: {
      'draft.fields': '{"name":"Riya Patel","mobile":"98765","consent":false}',
    });
    expect(find.text('Your unfinished form was restored.'), findsOneWidget);
    expect(find.text('Riya Patel'), findsOneWidget);
    await tester.tap(find.text('Clear form'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'New Person');
    await tester.pump();
    expect(find.text('Your unfinished form was restored.'), findsNothing);
  });

  testWidgets('submit failures: 500 offers Retry, timeout warns about duplicates',
      (tester) async {
    final (container, visitors, hosts) = await boot(tester, prefs: {
      'draft.fields':
          '{"name":"Riya Patel","mobile":"9876543210","purposeId":"meeting","hostId":"h_2","hostName":"Aarav Shah 2","consent":true}',
    });
    hosts.calls = 1;
    final failing = FailingVisitors(const ApiException(FailureKind.server));
    // Swap the repo for one that fails, keeping everything else.
    final c2 = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPrefsProvider.overrideWithValue(container.read(sharedPrefsProvider)),
        hostRepositoryProvider.overrideWithValue(hosts),
        visitorRepositoryProvider.overrideWithValue(failing),
      ],
    );
    addTearDown(c2.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: c2, child: const KioskApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();
    expect(find.text('The server had a problem. Please retry.'), findsOneWidget);
    expect(failing.calls, 1);
    expect(find.text('Riya Patel'), findsOneWidget, reason: 'form data is kept on failure');

    failing.error = const ApiException(FailureKind.timeout);
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('may already be checked in'), findsOneWidget);
    expect(failing.calls, 2);

    failing.error = null; // server recovers
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(failing.calls, 3);
    expect(find.text("You're checked in"), findsOneWidget);
    expect(visitors.checkIns, 0);
  });

  testWidgets('hosts: error state with Retry, then success', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Choose who you are visiting'));
    await tester.pumpAndSettle();
    expect(find.text('The server had a problem. Please retry.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(HostTile), findsWidgets);
  });

  testWidgets('visitors: undo sends nothing; letting it lapse sends one check-out',
      (tester) async {
    final (_, visitors, _) = await boot(tester);
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    expect(find.text('Riya Patel'), findsOneWidget);

    await tester.tap(find.byTooltip('Check out: Riya Patel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Riya Patel'), findsNothing, reason: 'staged row is hidden');
    expect(find.text('Riya Patel checked out'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Riya Patel'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 7));
    expect(visitors.checkOuts, 0, reason: 'undo must never reach the server');

    await tester.tap(find.byTooltip('Check out: Riya Patel'));
    await pumpFor(tester, const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(visitors.checkOuts, 1);
  });

  testWidgets('visitors: swipe to check out', (tester) async {
    final (_, visitors, _) = await boot(tester);
    await tester.tap(find.text('Visitors'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Riya Patel'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Riya Patel'), findsNothing);
    await pumpFor(tester, const Duration(seconds: 7));
    expect(visitors.checkOuts, 1);
  });

  testWidgets('admin: PIN gate, brand colour, language persist', (tester) async {
    final (container, _, _) = await boot(tester);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pump();
    expect(find.text('Incorrect PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    expect(find.text('Brand colour'), findsOneWidget);

    Color primary() => Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme.primary;
    final before = primary();
    await tester.tap(find.bySemanticsLabel('Colour option 5'));
    await tester.pumpAndSettle();
    expect(primary(), isNot(before), reason: 'brand colour applies immediately');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, Brightness.dark);

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(find.text('एडमिन सेटिंग्स'), findsWidgets);
    expect(find.text('चेक-इन'), findsWidgets); // nav label localised

    final prefs = container.read(sharedPrefsProvider);
    expect(prefs.getString('settings.language'), 'hi');
    expect(prefs.getString('settings.themeMode'), 'dark');
  });

  testWidgets('tablet landscape: directory and form side by side', (tester) async {
    await boot(tester, size: const Size(1280, 800));
    expect(find.byType(HostDirectory), findsOneWidget);
    expect(find.byType(CheckinForm), findsOneWidget);
    // Directory errors first (deliberate flaky repo); retry it.
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(HostTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Aarav Shah 0'), findsNWidgets(2)); // row + form field
  });

  for (final lang in ['en', 'hi', 'gu']) {
    for (final size in [const Size(360, 740), const Size(1280, 800)]) {
      testWidgets('whole app at 200% font [$lang] ${size.width.toInt()}w', (tester) async {
        await boot(tester,
            size: size, textScale: 2.0, prefs: {'settings.language': lang});
        final tabs = {
          'en': ['Visitors', 'Admin', 'Check-in'],
          'hi': ['आगंतुक', 'एडमिन', 'चेक-इन'],
          'gu': ['મુલાકાતીઓ', 'એડમિન', 'ચેક-ઇન'],
        }[lang]!;
        for (final t in tabs) {
          await tester.tap(find.text(t).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $t');
        }
      });
    }
  }
}
