import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'metric_card.dart';

class DashboardSummaryCard extends StatelessWidget {
  final VoidCallback? onCompareTap;

  const DashboardSummaryCard({super.key, this.onCompareTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<FlockProvider>(
      builder: (context, flockProvider, _) {
        return Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overview', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  MetricCard(
                    icon: Icons.groups,
                    label: 'Active Flocks',
                    value: flockProvider.activeFlockCount.toString(),
                    color: AppTheme.primaryColor,
                    width: 96,
                  ),
                  MetricCard(
                    icon: Icons.egg_alt,
                    label: 'Total Birds',
                    value: flockProvider.totalBirds.toString(),
                    color: AppTheme.secondaryColor,
                    width: 96,
                  ),
                  MetricCard(
                    icon: Icons.savings,
                    label: 'Total Cost',
                    value: CurrencyFormatter.formatCompact(
                        flockProvider.totalInitialCost),
                    color: AppTheme.primaryColor,
                    width: 96,
                  ),
                ],
              ),
              if (onCompareTap != null) ...[
                const SizedBox(height: AppTheme.spacingMD),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingMD),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCompareTap,
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    label: const Text('Compare Batches'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
