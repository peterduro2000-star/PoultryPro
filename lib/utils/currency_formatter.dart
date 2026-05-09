import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _naira = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  static String format(num value) => _naira.format(value);

  static String formatSigned(num value) {
    if (value > 0) return '+${format(value)}';
    if (value < 0) return '-${format(value.abs())}';
    return format(0);
  }
}
