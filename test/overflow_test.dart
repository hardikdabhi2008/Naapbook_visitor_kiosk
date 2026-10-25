import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/features/badge/presentation/badge_content.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_form.dart';
import 'package:naapbooks_visitor_kiosk/features/checkin/presentation/checkin_page.dart';
import 'package:naapbooks_visitor_kiosk/features/settings/presentation/admin_screen.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/presentation/visitors_screen.dart';

import 'helpers.dart';

/// 200% text scale in every language must not produce layout overflow.
void main() {
  final screens = <String, Widget Function()>{
    'check-in form': () => const CheckinForm(),
    'two-pane check-in': () => const CheckinPage(),
    'visitors': () => const VisitorsScreen(),
    'admin pin': () => const AdminScreen(),
    'badge': () => BadgeContent(
          visitor: sampleVisitor,
          secondsLeft: 20,
          totalSeconds: 20,
          onDone: () {},
        ),
  };
  const phone = Size(360, 740);
  const tablet = Size(1280, 800);

  for (final lang in ['en', 'hi', 'gu']) {
    for (final e in screens.entries) {
      final size = e.key == 'two-pane check-in' ? tablet : phone;
      testWidgets('${e.key} @ 2.0x [$lang] ${size.width.toInt()}w', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          overrides: await testOverrides(),
          child: testApp(e.value(), lang: lang, textScale: 2.0),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
