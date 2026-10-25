import 'package:flutter_test/flutter_test.dart';
import 'package:naapbooks_visitor_kiosk/core/l10n/app_strings.dart';
import 'package:naapbooks_visitor_kiosk/core/utils/validators.dart';

void main() {
  test('every string key exists in en, hi and gu', () {
    final en = AppStrings.table['en']!.keys.toSet();
    for (final lang in ['hi', 'gu']) {
      final keys = AppStrings.table[lang]!.keys.toSet();
      expect(en.difference(keys), isEmpty, reason: '$lang is missing keys');
      expect(keys.difference(en), isEmpty, reason: '$lang has extra keys');
    }
  });

  test('placeholders are the same in every language', () {
    final ph = RegExp(r'\{(\w+)\}');
    AppStrings.table['en']!.forEach((k, v) {
      final want = ph.allMatches(v).map((m) => m.group(1)).toSet();
      for (final lang in ['hi', 'gu']) {
        final got =
            ph.allMatches(AppStrings.table[lang]![k]!).map((m) => m.group(1)).toSet();
        expect(got, want, reason: '$lang/$k');
      }
    });
  });

  test('mobile validator: 10 digits starting 6-9', () {
    expect(Validators.mobile('9876543210'), isNull);
    expect(Validators.mobile('6000000000'), isNull);
    expect(Validators.mobile('5876543210'), 'v_mobile');
    expect(Validators.mobile('987654321'), 'v_mobile');
    expect(Validators.mobile(''), 'v_mobile');
  });

  test('name validator: 2-80 chars after trim', () {
    expect(Validators.name('A'), 'v_name');
    expect(Validators.name('  A  '), 'v_name');
    expect(Validators.name('Al'), isNull);
    expect(Validators.name('x' * 81), 'v_name');
  });
}
