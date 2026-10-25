import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/features/badge/presentation/badge_content.dart';

import 'helpers.dart';

/// Badge goldens: phone + tablet, light + dark, normal + 200% font.
/// Regenerate with: flutter test --update-goldens test/badge_golden_test.dart
void main() {
  const sizes = {'phone': Size(390, 844), 'tablet': Size(1280, 800)};
  for (final entry in sizes.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final font = scale == 1.0 ? '1x' : '2x';
        final name = 'badge_${entry.key}_${brightness.name}_$font';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(testApp(
            BadgeContent(
              visitor: sampleVisitor,
              secondsLeft: 14,
              totalSeconds: 20,
              onDone: () {},
            ),
            brightness: brightness,
            textScale: scale,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'no overflow');
          await expectLater(
              find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
        });
      }
    }
  }
}
