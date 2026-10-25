import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_form.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_providers.dart';

import 'helpers.dart';

void main() {
  testWidgets('half-filled form is restored from the saved draft', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final overrides = await testOverrides({
      'draft.fields': '{"name":"Riya Patel","mobile":"98765","company":"","consent":true}',
    });
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: testApp(const CheckinForm()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Riya Patel'), findsOneWidget);
    expect(find.text('98765'), findsOneWidget);
    expect(find.text('Your unfinished form was restored.'), findsOneWidget);
  });

  testWidgets('typing writes through to the draft; submit is blocked without consent',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: await testOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(const CheckinForm()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Riya Patel');
    expect(container.read(checkinProvider).name, 'Riya Patel');

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(find.text('Consent is required.'), findsOneWidget);
    expect(find.text('Enter a valid 10-digit mobile number starting with 6–9.'),
        findsOneWidget);
  });
}
