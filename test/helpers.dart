import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naapbooks_visitor_kiosk/core/l10n/app_strings.dart';
import 'package:naapbooks_visitor_kiosk/core/storage/prefs_provider.dart';
import 'package:naapbooks_visitor_kiosk/core/theme/app_theme.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/domain/host.dart';
import 'package:naapbooks_visitor_kiosk/features/hosts/presentation/host_providers.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/domain/visitor.dart';
import 'package:naapbooks_visitor_kiosk/features/visitors/presentation/visitor_providers.dart';

final sampleVisitor = Visitor(
  id: 'v_000001',
  name: 'Riya Patel',
  mobile: '9876543210',
  company: 'Infosys',
  purposeId: 'meeting',
  hostId: 'h_0042',
  hostName: 'Kunal Mehta',
  status: VisitorStatus.checkedIn,
  checkInAt: DateTime(2026, 10, 24, 10, 30),
  checkOutAt: null,
  expectedAt: DateTime(2026, 10, 24, 10, 30),
  hasPhoto: false,
  badgeCode: 'NBV-4K9Q2X',
  consent: true,
);

class FakeHostRepo implements HostRepository {
  @override
  Future<List<Host>> fetchHosts() async => [
        for (var i = 0; i < 20; i++)
          Host(
            id: 'h_$i',
            name: 'Aarav Shah $i',
            designation: 'Sr. Manager',
            department: 'Engineering',
            floor: '2nd',
            email: 'a$i@example.in',
            available: i.isEven,
          ),
      ];
}

class FakeVisitorRepo implements VisitorRepository {
  @override
  Future<VisitorPage> fetchVisitors(
          {VisitorStatus? status, String? cursor, int limit = 50}) async =>
      VisitorPage([
        sampleVisitor,
        for (final s in [VisitorStatus.checkedOut, VisitorStatus.expected])
          Visitor(
            id: 'v_${s.name}',
            name: 'Meera Trivedi ${s.name}',
            mobile: '9876543211',
            company: 'Tata Consultancy',
            purposeId: 'vendor',
            hostId: 'h_1',
            hostName: 'Aarav Shah 1',
            status: s,
            checkInAt: DateTime(2026, 10, 24, 9),
            checkOutAt: DateTime(2026, 10, 24, 10),
            expectedAt: DateTime(2026, 10, 24, 9),
            hasPhoto: false,
            badgeCode: 'NBV-AAAAAA',
            consent: true,
          ),
      ], null);

  @override
  Future<Visitor> checkIn(NewVisitor visitor) async => sampleVisitor;
  @override
  Future<Visitor> checkOut(String id) async => sampleVisitor;
  @override
  Future<List<Purpose>> fetchPurposes() async =>
      const [Purpose('meeting', 'Meeting'), Purpose('vendor', 'Vendor / Contractor')];
  @override
  String photoUrl(String id) => '';
}

Future<List<Override>> testOverrides([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return [
    sharedPrefsProvider.overrideWithValue(p),
    hostRepositoryProvider.overrideWithValue(FakeHostRepo()),
    visitorRepositoryProvider.overrideWithValue(FakeVisitorRepo()),
  ];
}

/// Wraps [child] in a localised MaterialApp at the given text scale.
Widget testApp(
  Widget child, {
  String lang = 'en',
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: AppStrings.supported,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(const Color(0xFF1565C0), brightness),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(body: child),
    );
