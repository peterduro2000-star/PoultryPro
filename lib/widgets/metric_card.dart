import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool tintBackground;
  final double iconSize;
  final double width;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.tintBackground = false,
    this.iconSize = 20,
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
    final displayValue = _getFormattedValue();
    final card = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingSM),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
        const SizedBox(height: AppTheme.spacingXS),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            displayValue,
            style: AppTheme.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (tintBackground) {
      return Container(
        width: width,
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: card,
      );
    }
    return SizedBox(width: width, child: card);
  }
}
