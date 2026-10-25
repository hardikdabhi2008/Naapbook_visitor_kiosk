import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/core/error/api_exception.dart';
import 'package:naapbooks_visitor_kiosk/core/widgets/state_views.dart';
import 'package:naapbooks_visitor_kiosk/features/badge/presentation/badge_content.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/domain/visitor.dart';

import 'app_flow_test.dart' show SpyVisitors, boot;
import 'helpers.dart';

class _EmptyVisitors extends SpyVisitors {
  @override
  Future<VisitorPage> fetchVisitors(
          {VisitorStatus? status, String? cursor, int limit = 50}) async =>
      const VisitorPage([], null);
}

class _FailsOnce extends SpyVisitors {
  int calls = 0;
  @override
  Future<VisitorPage> fetchVisitors(
      {VisitorStatus? status, String? cursor, int limit = 50}) {
    if (calls++ == 0) throw const ApiException(FailureKind.server);
    return super.fetchVisitors(status: status, cursor: cursor, limit: limit);
  }
}

void main() {
  group('Today\'s visitors: loading, empty, error-with-retry and success', () {
    testWidgets('empty', (tester) async {
      await boot(tester, visitorsRepo: _EmptyVisitors());
      await tester.tap(find.text('Visitors'));
      await tester.pumpAndSettle();
      expect(find.text('No visitors here yet.'), findsOneWidget);
    });

    testWidgets('loading, then error with Retry, then success', (tester) async {
      final repo = _FailsOnce();
      await boot(tester, visitorsRepo: repo);
      await tester.tap(find.text('Visitors'));
      await tester.pump();
      expect(find.byType(LoadingView), findsOneWidget, reason: 'loading state');
      await tester.pumpAndSettle();
      expect(find.text('The server had a problem. Please retry.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.text('The server had a problem. Please retry.'), findsNothing);
      expect(find.text('Riya Patel'), findsOneWidget, reason: 'success state');
      expect(repo.calls, 2);
    });
  });

  group('Accessibility guidelines (Android tap targets, labels, contrast)', () {
    Future<void> check(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('check-in form', (tester) async {
      final handle = tester.ensureSemantics();
      await boot(tester, size: const Size(390, 1800));
      await check(tester);
      handle.dispose();
    });

    testWidgets('check-in form after a failed submit (all error messages showing)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await boot(tester, size: const Size(390, 2000));
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      await check(tester);
      handle.dispose();
    });

    testWidgets('visitors list', (tester) async {
      final handle = tester.ensureSemantics();
      await boot(tester, size: const Size(390, 1200));
      await tester.tap(find.text('Visitors'));
      await tester.pumpAndSettle();
      await check(tester);
      handle.dispose();
    });

    testWidgets('admin settings', (tester) async {
      final handle = tester.ensureSemantics();
      await boot(tester, size: const Size(390, 1400));
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('Brand colour'), findsOneWidget);
      await check(tester);
      handle.dispose();
    });

    testWidgets('visitor badge', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(BadgeContent(
        visitor: sampleVisitor,
        secondsLeft: 14,
        totalSeconds: 20,
        onDone: () {},
      )));
      await tester.pumpAndSettle();
      await check(tester);
      handle.dispose();
    });
  });
}
