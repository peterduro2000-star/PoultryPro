import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single icon + label + value row, right-aligned value.
/// Previously duplicated identically in flocks_screen.dart and
/// home_screen.dart as private `_StatRow` classes — consolidated here.
class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}