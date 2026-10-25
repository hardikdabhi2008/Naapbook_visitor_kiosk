import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/features/badge/presentation/badge_content.dart';

import 'helpers.dart';

/// Android 15+ draws apps edge-to-edge, so the system navigation bar overlaps the
/// bottom of the screen. Full-screen pages must keep their last control (the
/// badge's Done button) above it.
void main() {
  testWidgets('badge: Done button stays above the system navigation bar', (tester) async {
    const screen = Size(390, 640);
    const navBar = 56.0;
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: navBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navBar);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(
      BadgeContent(
        visitor: sampleVisitor,
        secondsLeft: 14,
        totalSeconds: 20,
        onDone: () {},
      ),
    ));
    await tester.pumpAndSettle();

    // The content is taller than the screen; scroll to the very end.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    final done = find.widgetWithText(FilledButton, 'Done');
    expect(done, findsOneWidget);
    final bottom = tester.getBottomLeft(done).dy;
    expect(bottom, lessThanOrEqualTo(screen.height - navBar),
        reason: 'Done ends at $bottom but the navigation bar starts at ${screen.height - navBar}');
    expect(tester.takeException(), isNull);
  });
}
