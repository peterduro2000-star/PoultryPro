import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _naira = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );

  static String format(num value) => _naira.format(value);

  static String formatCompact(num value) {
    final sign = value < 0 ? '-' : '';
    final absValue = value.abs();

    if (absValue >= 1000000) {
      return '$sign₦${_trimCompact(absValue / 1000000)}M';
    }
    if (absValue >= 10000) {
      return '$sign₦${_trimCompact(absValue / 1000)}K';
    }
    return '$sign₦${NumberFormat('#,##0', 'en_NG').format(absValue)}';
  }

  static String formatSigned(num value) {
    if (value > 0) return '+${format(value)}';
    if (value < 0) return '-${format(value.abs())}';
    return format(0);
  }

  static String _trimCompact(num value) {
    final formatted = value.toStringAsFixed(1);
    return formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
  }
}
