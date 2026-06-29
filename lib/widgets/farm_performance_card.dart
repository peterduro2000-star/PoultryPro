import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'metric_card.dart';

class FarmPerformanceCard extends StatelessWidget {
  const FarmPerformanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, _) {
        final hasData = financeProvider.farmExpenses.isNotEmpty ||
            financeProvider.farmSales.isNotEmpty;

        return Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Farm Performance', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),
              if (financeProvider.isFarmFinanceLoading)
                const Center(child: CircularProgressIndicator())
              else if (!hasData)
                Center(
                  child: Text(
                    'No financial data yet',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary),
                  ),
                )
              else
                Wrap(
                  spacing: AppTheme.spacingMD,
                  runSpacing: AppTheme.spacingMD,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    MetricCard(
                      icon: Icons.trending_up,
                      label: 'Total Sales',
                      value: CurrencyFormatter.formatCompact(
                          financeProvider.farmTotalSales),
                      color: AppTheme.successColor,
                      width: 96,
                    ),
                    MetricCard(
                      icon: Icons.receipt_long,
                      label: 'Total Expenses',
                      value: CurrencyFormatter.formatCompact(
                          financeProvider.farmTotalExpenses),
                      color: AppTheme.errorColor,
                      width: 96,
                    ),
                    MetricCard(
                      icon: financeProvider.farmProfit >= 0
                          ? Icons.account_balance_wallet
                          : Icons.warning_amber,
                      label: 'Profit',
                      value: financeProvider.farmProfitDisplay,
                      color: financeProvider.farmProfit >= 0
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      width: 96,
                    ),
                    MetricCard(
                      icon: Icons.percent,
                      label: 'Profit Margin',
                      value: financeProvider.farmProfitMarginDisplay,
                      color: AppTheme.primaryColor,
                      width: 96,
                    ),
                    MetricCard(
                      icon: Icons.paid,
                      label: 'Cost Recovered',
                      value: financeProvider.farmRecoveryPercentage
                              .toStringAsFixed(1) +
                          '%',
                      color: AppTheme.secondaryColor,
                      width: 96,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
