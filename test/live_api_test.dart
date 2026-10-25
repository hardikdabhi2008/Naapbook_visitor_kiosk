import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/core/error/api_exception.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/data/host_repository_impl.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/data/visitor_repository_impl.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/domain/visitor.dart';

/// Runs the real repositories against the mock API.
///   node mock-api/server.js
///   LIVE_API=1 flutter test test/live_api_test.dart
/// The API fails ~5% of calls on purpose, so each call is retried a few times.
void main() {
  final live = Platform.environment['LIVE_API'] == '1';
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:4000'));
  final hosts = HostRepositoryImpl(dio);
  final visitors = VisitorRepositoryImpl(dio);

  Future<T> retry<T>(Future<T> Function() f) async {
    for (var i = 0;; i++) {
      try {
        return await f();
      } on ApiException catch (e) {
        if (e.kind != FailureKind.server || i >= 5) rethrow;
      }
    }
  }

  test('hosts + purposes', () async {
    final h = await retry(hosts.fetchHosts);
    expect(h, hasLength(500));
    final p = await retry(visitors.fetchPurposes);
    expect(p.map((e) => e.id), contains('meeting'));
  }, skip: !live);

  test('visitors are cursor-paged without duplicates', () async {
    final first = await retry(() => visitors.fetchVisitors(limit: 100));
    expect(first.items, hasLength(100));
    expect(first.nextCursor, isNotNull);
    final second =
        await retry(() => visitors.fetchVisitors(limit: 100, cursor: first.nextCursor));
    final ids = {...first.items.map((v) => v.id), ...second.items.map((v) => v.id)};
    expect(ids, hasLength(200));
  }, skip: !live);

  test('status filter', () async {
    final page = await retry(
        () => visitors.fetchVisitors(status: VisitorStatus.expected, limit: 20));
    expect(page.items.every((v) => v.status == VisitorStatus.expected), isTrue);
  }, skip: !live);

  test('check in, then check out, then 409 is treated as success', () async {
    final h = (await retry(hosts.fetchHosts)).first;
    final created = await retry(() => visitors.checkIn(NewVisitor(
          name: 'Live Test',
          mobile: '9876543210',
          company: null,
          purposeId: 'meeting',
          hostId: h.id,
          consent: true,
          // 1x1 PNG
          photoDataUrl:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        )));
    expect(created.status, VisitorStatus.checkedIn);
    expect(created.hasPhoto, isTrue);

    final out = await retry(() => visitors.checkOut(created.id));
    expect(out.status, VisitorStatus.checkedOut);

    final again = await retry(() => visitors.checkOut(created.id));
    expect(again.status, VisitorStatus.checkedOut);
  }, skip: !live);

  test('422 carries per-field messages', () async {
    try {
      await retry(() => visitors.checkIn(const NewVisitor(
            name: 'X',
            mobile: '123',
            company: null,
            purposeId: 'meeting',
            hostId: 'h_0001',
            consent: false,
          )));
      fail('expected a validation error');
    } on ApiException catch (e) {
      expect(e.kind, FailureKind.validation);
      expect(e.fields.keys, containsAll(['name', 'mobile', 'consent']));
    }
  }, skip: !live);
}
