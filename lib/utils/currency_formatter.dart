/// Single source of truth for all currency and number formatting.
/// Every screen must use these — never inline toStringAsFixed for money.
class CurrencyFormatter {
  CurrencyFormatter._();

  static const String _symbol = '\u20a6'; // ₦

  /// ₦1,234,567 — full format with thousands separator
  static String format(double value) {
    if (value < 0) return '-${_symbol}${_formatWithCommas(-value)}';
    return '$_symbol${_formatWithCommas(value)}';
  }

  /// ₦1,125 — full format with commas, no abbreviation.
  /// Use for: per-bird prices, individual transactions, suggested prices,
  /// any figure the farmer will act on directly.
  static String formatFull(double value) {
    final isNegative = value < 0;
    final abs = value.abs();
    final prefix = isNegative ? '-' : '';
    return '$prefix$_symbol${_formatWithCommas(abs)}';
  }

  /// ₦1,125 / ₦140k / ₦1.4M — compact for cards, abbreviates above 10k
  static String formatCompact(double value) {
    final abs = value.abs();
    final prefix = value < 0 ? '-' : '';
    if (abs >= 1000000) {
      return '$prefix$_symbol${(abs / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 10000) {
      return '$prefix$_symbol${(abs / 1000).toStringAsFixed(1)}k';
    }
    // Under 10,000 — show full to avoid ambiguity
    return '$prefix$_symbol${_formatWithCommas(abs)}';
  }

  /// +₦1.2M / -₦234k — for profit/loss display
  static String formatProfit(double value) {
    if (value > 0) return '+${formatCompact(value)}';
    if (value < 0) return '-${formatCompact(-value)}';
    return '${_symbol}0';
  }

  /// 1.2M / 234k / 999 — compact without symbol, for non-money numbers
  static String formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  static String _formatWithCommas(double value) {
    final parts = value.toStringAsFixed(0).split('');
    final result = StringBuffer();
    final len = parts.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) result.write(',');
      result.write(parts[i]);
    }
    return result.toString();
  }
}