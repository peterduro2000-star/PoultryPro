import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared plan/benefits card. upgrade_screen.dart had a version with
/// `isCurrent` highlighting; home_screen.dart had a near-identical
/// `_PlanCard` with no `isCurrent` support that, as far as this codebase
/// shows, isn't actually referenced anywhere in that file's build methods
/// (dead code left over from an earlier layout). This consolidates both
/// into one widget — `isCurrent` defaults to false so call sites that
/// don't care about it don't need to pass it.
class PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<String> benefits;
  final bool isCurrent;

  const PlanCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.benefits,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: isCurrent ? color : Colors.transparent,
          width: 2,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: color),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTheme.bodyLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(subtitle, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ...benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: color),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(benefit, style: AppTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}