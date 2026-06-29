import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/flock.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

/// Rendered off-screen by ScreenshotController — never shown directly.
/// Produces a 1080×1080 WhatsApp-ready card.
class SharePerformanceCard extends StatelessWidget {
  final Flock flock;
  final double totalExpenses;
  final double totalSales;
  final double profit;
  final double mortalityRate;
  final double costPerBird;
  final String breakEvenDisplay;
  final double recoveryPercentage;

  const SharePerformanceCard({
    super.key,
    required this.flock,
    required this.totalExpenses,
    required this.totalSales,
    required this.profit,
    required this.mortalityRate,
    required this.costPerBird,
    required this.breakEvenDisplay,
    required this.recoveryPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = profit >= 0;
    final numberFormat = NumberFormat.decimalPattern();

    final profitColor =
        isProfit ? AppTheme.successColor : AppTheme.errorColor;

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.egg_alt,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PoultryPro',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  flock.name,
                  style: AppTheme.headingMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${flock.type} • ${flock.ageDisplay}',
                  style: AppTheme.bodySmall.copyWith(
                      color: Colors.white70),
                ),
              ],
            ),
          ),

          // Profit hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 20, horizontal: 20),
            color: profitColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  isProfit
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: profitColor,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProfit ? 'Net Profit' : 'Net Loss',
                      style: AppTheme.bodySmall
                          .copyWith(color: profitColor),
                    ),
                    Text(
                      CurrencyFormatter.formatFull(profit.abs()),
                      style: AppTheme.headingLarge.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Recovery',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                    Text(
                      '${recoveryPercentage.toStringAsFixed(0)}%',
                      style: AppTheme.headingSmall.copyWith(
                        color: recoveryPercentage >= 100
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatBox(
                      label: 'Total Expenses',
                      value: CurrencyFormatter.formatFull(totalExpenses),
                      color: AppTheme.errorColor,
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Total Revenue',
                      value: CurrencyFormatter.formatFull(totalSales),
                      color: AppTheme.successColor,
                      icon: Icons.arrow_upward,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatBox(
                      label: 'Cost per Bird',
                      value: CurrencyFormatter.formatFull(
                          costPerBird),
                      color: AppTheme.primaryColor,
                      icon: Icons.calculate_outlined,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Mortality Rate',
                      value:
                          '${mortalityRate.toStringAsFixed(1)}%',
                      color: mortalityRate > 5
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      icon: Icons.warning_amber_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatBox(
                      label: 'Break-even Price',
                      value: breakEvenDisplay,
                      color: AppTheme.infoColor,
                      icon: Icons.balance,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Current Birds',
                      value: numberFormat.format(flock.birdCount),
                      color: AppTheme.secondaryColor,
                      icon: Icons.groups,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Powered by PoultryPro',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'by Proxima Novum',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTheme.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}