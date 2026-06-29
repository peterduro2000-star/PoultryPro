import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double width;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.width = double.infinity,
  });

  // Senior approach: Cache the formatter as a static constant for performance.
  static final NumberFormat _commaFormatter = NumberFormat.decimalPattern();

  String _getFormattedValue() {
    if (value.isEmpty) return '0';
    // If value contains letters (e.g. ₦1.3M, ₦850k, +₦1.2M),
    // it's already formatted — return as-is.
    if (value.contains(RegExp(r'[a-zA-Z%]'))) return value;
    try {
      final num parsedValue = num.parse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      return _commaFormatter.format(parsedValue);
    } catch (e) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              _getFormattedValue(),
              style: AppTheme.bodyLarge.copyWith(
                color: color, 
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5, // Tighter spacing for large numbers
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            label,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
