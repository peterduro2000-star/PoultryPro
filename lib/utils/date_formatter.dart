class DateFormatter {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String format(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${_months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return isoDate; // fallback to raw string if parsing fails
    }
  }

  static String formatShort(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${_months[date.month - 1]} ${date.day}';
    } catch (_) {
      return isoDate;
    }
  }
}