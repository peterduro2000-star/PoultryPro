import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pro_new/utils/currency_formatter.dart';
import 'package:poultry_pro_new/utils/date_formatter.dart';

void main() {
  test('date-only strings are formatted without timezone shifting', () {
    expect(DateFormatter.format('2026-05-18'), 'May 18, 2026');
    expect(DateFormatter.formatShort('2026-05-18'), 'May 18');
  });

  test('compact currency keeps values under ten thousand fully formatted', () {
    expect(CurrencyFormatter.formatCompact(9999), '₦9,999');
    expect(CurrencyFormatter.formatCompact(10000), '₦10K');
  });
}
