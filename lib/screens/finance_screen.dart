// lib/screens/finance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../models/flock.dart';
import '../models/sale.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../widgets/flock_header.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── FIX 10: Replaced addPostFrameCallback listener pattern with
  // didChangeDependencies so there is no double-add risk on rebuild.
  // We track the last loaded flock id to avoid redundant DB calls.
  String? _loadedFlockId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flock = context.watch<FlockProvider>().selectedFlock;
    if (flock != null && flock.id != _loadedFlockId) {
      _loadedFlockId = flock.id;
      // Schedule after the current frame so we are not calling setState
      // during a build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<FinanceProvider>().loadFinanceData(flock.id);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text('Finance', style: AppTheme.headingSmall),
      ),
      body: Column(
        children: [
          const FlockHeader(),

          // ── FIX 3: Tab bar pill radius reduced to radiusSM (8) so the
          // active indicator never clips outside the container corners.
          Container(
            margin: const EdgeInsets.fromLTRB(
                AppTheme.spacingMD, AppTheme.spacingMD, AppTheme.spacingMD, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: const [AppTheme.shadowSM],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Sales'),
                Tab(text: 'Profit'),
              ],
            ),
          ),

          Expanded(
            child: Consumer<FlockProvider>(
              builder: (context, flockProvider, _) {
                final selectedFlock = flockProvider.selectedFlock;

                if (selectedFlock == null) {
                  return _EmptyFlockState();
                }

                return Consumer<FinanceProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor));
                    }
                    if (provider.error != null) {
                      return _ErrorState(message: provider.error!);
                    }
                    return Column(
                      children: [
                        // ── FIX 1: Summary bar now sits on backgroundColor
                        // with horizontal padding and a card shadow so it
                        // reads as distinct from the tab container above it.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingMD,
                              AppTheme.spacingMD,
                              AppTheme.spacingMD,
                              0),
                          child: _SummaryBar(provider: provider),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _ExpensesList(expenses: provider.expenses),
                              _SalesList(sales: provider.sales),
                              _ProfitTab(
                                provider: provider,
                                flock: selectedFlock,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ── FIX 9: FAB now has a tooltip and a contextual label so users
      // know exactly what the + button does on each tab.
      floatingActionButton: Consumer<FlockProvider>(
        builder: (context, provider, _) {
          if (provider.selectedFlock == null) return const SizedBox.shrink();
          return ListenableBuilder(
            listenable: _tabController,
            builder: (context, _) {
              if (_tabController.index == 2) return const SizedBox.shrink();
              final isExpenseTab = _tabController.index == 0;
              return FloatingActionButton.extended(
                heroTag: 'finance_fab',
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                tooltip: isExpenseTab ? 'Add Expense' : 'Record Sale',
                icon: const Icon(Icons.add),
                label: Text(isExpenseTab ? 'Add Expense' : 'Record Sale'),
                onPressed: () =>
                    _showAddSheet(context, provider.selectedFlock!.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, String flockId) {
    final flock = context.read<FlockProvider>().selectedFlock!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _tabController.index == 0
          ? _AddExpenseSheet(flockId: flockId)
          : _AddSaleSheet(flockId: flockId, birdCount: flock.birdCount),
    );
  }
}

// ─── Empty State: No Flock Selected ──────────────────────────────────────────

class _EmptyFlockState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: AppTheme.spacingMD),
          Text('No flock selected', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text('Go to Home to select a flock',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingMD),
            Text(message,
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.errorColor),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final FinanceProvider provider;
  const _SummaryBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isProfit = provider.profit >= 0;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: const [AppTheme.shadowSM],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── FIX 2: Each chip is now in an Expanded with a fixed
            // minimum height. The value text uses auto-sizing so it
            // shrinks gracefully instead of truncating with ellipsis.
            _SummaryChip(
              icon: Icons.arrow_downward,
              label: 'Expenses',
              value: CurrencyFormatter.formatCompact(provider.totalExpenses),
              color: AppTheme.errorColor,
            ),
            const VerticalDivider(width: AppTheme.spacingSM, thickness: 1),
            _SummaryChip(
              icon: Icons.arrow_upward,
              label: 'Sales',
              value: CurrencyFormatter.formatCompact(provider.totalSales),
              color: AppTheme.successColor,
            ),
            const VerticalDivider(width: AppTheme.spacingSM, thickness: 1),
            _SummaryChip(
              icon: isProfit ? Icons.trending_up : Icons.trending_down,
              label: isProfit ? 'Profit' : 'Loss',
              value: CurrencyFormatter.formatCompact(provider.profit.abs()),
              color: isProfit ? AppTheme.successColor : AppTheme.errorColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingSM, horizontal: AppTheme.spacingXS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            // FitWidth auto-shrinks the font when the number is large
            // so it never clips or shows ellipsis.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                    color: color, fontWeight: FontWeight.bold),
              ),
            ),
            Text(label,
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ─── Profit Tab ───────────────────────────────────────────────────────────────

class _ProfitTab extends StatelessWidget {
  final FinanceProvider provider;
  final Flock flock;

  const _ProfitTab({required this.provider, required this.flock});

  @override
  Widget build(BuildContext context) {
    final totalRevenue  = provider.totalSales;
    final totalExpenses = provider.totalExpenses;
    final netProfit     = provider.profit;
    final profitMargin  = provider.profitMargin;
    final isProfit      = netProfit >= 0;
    final currentBirds  = flock.birdCount;

    // Remaining unrecovered cost per bird (0 when in profit)
    final breakEvenPerBird =
        provider.breakEvenPerBird(currentBirds: currentBirds);

    // Net profit (or loss) per bird
    final profitPerBird =
        currentBirds > 0 ? netProfit / currentBirds : 0.0;

    // All-in cost = total expenditure divided by live birds
    final allInCostPerBird = currentBirds > 0
        ? totalExpenses / currentBirds
        : flock.costPerBird;

    // Suggested prices at three margin targets
    final suggestedAt20 = allInCostPerBird * 1.20;
    final suggestedAt30 = allInCostPerBird * 1.30;
    final suggestedAt50 = allInCostPerBird * 1.50;

    // ── FIX 5: Use context-aware labels for the hero pills.
    // "Margin: -14.6%" is replaced with "Loss Margin: 14.6%" when negative.
    final marginLabel = isProfit ? 'Margin' : 'Loss Margin';
    final marginValue = '${profitMargin.abs().toStringAsFixed(1)}%';
    final recoveryValue =
        '${provider.recoveryPercentage.toStringAsFixed(0)}%';

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        // ── Net Profit / Loss Hero ───────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isProfit
                  ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
                  : [const Color(0xFFE53935), const Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          child: Column(
            children: [
              Icon(
                isProfit ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                isProfit ? 'Net Profit' : 'Net Loss',
                style:
                    AppTheme.bodyLarge.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              // FittedBox prevents the hero number from overflowing on
              // very large values
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CurrencyFormatter.formatFull(netProfit.abs()),
                  style: AppTheme.headingLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.spacingMD,
                runSpacing: AppTheme.spacingSM,
                children: [
                  _HeroPill(
                      label: marginLabel, value: marginValue),
                  _HeroPill(
                      label: 'Recovery', value: recoveryValue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Revenue vs Expenses ──────────────────────────────────────────
        _Card(
          title: 'Revenue vs Expenses',
          children: [
            _ProfitRow(
              label: 'Total Revenue',
              value: CurrencyFormatter.formatFull(totalRevenue),
              color: AppTheme.successColor,
              icon: Icons.arrow_upward,
            ),
            const Divider(height: 1),
            _ProfitRow(
              label: 'Total Expenses',
              value: CurrencyFormatter.formatFull(totalExpenses),
              color: AppTheme.errorColor,
              icon: Icons.arrow_downward,
            ),
            const Divider(height: 1),
            _ProfitRow(
              label: isProfit ? 'Net Profit' : 'Net Loss',
              value: CurrencyFormatter.formatFull(netProfit.abs()),
              color: isProfit ? AppTheme.successColor : AppTheme.errorColor,
              icon: isProfit ? Icons.trending_up : Icons.trending_down,
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Per Bird Analysis ────────────────────────────────────────────
        // ── FIX 6: Break-even and Loss per bird now show different labels
        // and a contextual explanation so users understand why the numbers
        // can look the same. Break-even shows the minimum price needed;
        // loss-per-bird shows the actual loss already incurred.
        _Card(
          title: 'Per Bird Analysis',
          subtitle: 'Based on $currentBirds Live bird${currentBirds == 1 ? '' : 's'}'
              '${flock.initialBirdCount != currentBirds ? ' (started with ${flock.initialBirdCount})' : ''}',
          children: [
            _ProfitRow(
              label: 'Purchase cost per bird',
              value: CurrencyFormatter.formatFull(flock.costPerBird),
              color: AppTheme.warningColor,
              icon: Icons.egg_alt,
            ),
            const Divider(height: 1),
            _ProfitRow(
              label: 'All-in cost per bird',
              value: CurrencyFormatter.formatFull(allInCostPerBird),
              color: AppTheme.primaryColor,
              icon: Icons.calculate_outlined,
            ),
            const Divider(height: 1),
            if (!isProfit) ...[
              _ProfitRow(
                label: 'Min. selling price to break even',
                value: CurrencyFormatter.formatFull(breakEvenPerBird),
                color: AppTheme.infoColor,
                icon: Icons.balance,
              ),
              const Divider(height: 1),
              _ProfitRow(
                label: 'Current loss per bird',
                value: CurrencyFormatter.formatFull(profitPerBird.abs()),
                color: AppTheme.errorColor,
                icon: Icons.trending_down,
                bold: true,
              ),
            ] else ...[
              _ProfitRow(
                label: 'Cost fully recovered \u2713',
                value: CurrencyFormatter.formatFull(profitPerBird),
                color: AppTheme.successColor,
                icon: Icons.check_circle_outline,
                bold: true,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Suggested Selling Prices ─────────────────────────────────────
        _Card(
          title: 'Suggested Selling Prices',
          subtitle:
              'Based on all-in cost of ${CurrencyFormatter.formatCompact(allInCostPerBird)}/bird',
          children: [
            _PriceSuggestion(
              label: '20% margin',
              price: suggestedAt20,
              profitPerBird: suggestedAt20 - allInCostPerBird,
              color: AppTheme.infoColor,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _PriceSuggestion(
              label: '30% margin',
              price: suggestedAt30,
              profitPerBird: suggestedAt30 - allInCostPerBird,
              color: AppTheme.successColor,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _PriceSuggestion(
              label: '50% margin',
              price: suggestedAt50,
              profitPerBird: suggestedAt50 - allInCostPerBird,
              color: AppTheme.accentColor,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Cost Breakdown ───────────────────────────────────────────────
        if (provider.expensesByCategory.isNotEmpty)
          _CostBreakdown(
            expensesByCategory: provider.expensesByCategory,
            totalExpenses: totalExpenses,
          ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Data Warning ─────────────────────────────────────────────────
        if (totalRevenue == 0 || totalExpenses == 0)
          _DataWarningBanner(
            message: totalRevenue == 0
                ? 'No sales recorded yet. Add sales to see accurate profit.'
                : 'No expenses recorded yet. Add expenses for accurate analysis.',
          ),

        const SizedBox(height: 80), // space above FAB
      ],
    );
  }
}

// ─── Hero Pill ────────────────────────────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final String label;
  final String value;
  const _HeroPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.bodySmall.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Card Wrapper ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _Card({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.headingSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: AppTheme.spacingMD),
          ...children,
        ],
      ),
    );
  }
}

// ─── Profit Row ───────────────────────────────────────────────────────────────

class _ProfitRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool bold;

  const _ProfitRow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Text(
              label,
              style: bold
                  ? AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                  : AppTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Price Suggestion ─────────────────────────────────────────────────────────

class _PriceSuggestion extends StatelessWidget {
  final String label;
  final double price;
  final double profitPerBird;
  final Color color;

  const _PriceSuggestion({
    required this.label,
    required this.price,
    required this.profitPerBird,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(Icons.sell, color: color, size: 18),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${CurrencyFormatter.formatFull(price)}/bird',
                    style: AppTheme.bodyLarge
                        .copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Profit/bird',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary)),
              Text(
                '+${CurrencyFormatter.formatFull(profitPerBird)}',
                style: AppTheme.bodyMedium
                    .copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cost Breakdown ───────────────────────────────────────────────────────────

class _CostBreakdown extends StatelessWidget {
  final Map<String, double> expensesByCategory;
  final double totalExpenses;

  const _CostBreakdown({
    required this.expensesByCategory,
    required this.totalExpenses,
  });

  static const _colors = [
    AppTheme.primaryColor,
    AppTheme.secondaryColor,
    AppTheme.accentColor,
    AppTheme.infoColor,
    AppTheme.warningColor,
    AppTheme.successColor,
    AppTheme.errorColor,
  ];

  IconData _icon(String cat) {
    switch (cat) {
      case ExpenseCategory.feed:       return Icons.set_meal;
      case ExpenseCategory.medication: return Icons.medication;
      case ExpenseCategory.vaccine:    return Icons.vaccines;
      case ExpenseCategory.labor:      return Icons.people;
      case ExpenseCategory.utilities:  return Icons.bolt;
      case ExpenseCategory.equipment:  return Icons.handyman;
      case ExpenseCategory.chicks:     return Icons.egg_alt;
      default:                         return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cost Breakdown', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          ...sorted.asMap().entries.map((entry) {
            final color    = _colors[entry.key % _colors.length];
            final category = entry.value.key;
            final amount   = entry.value.value;
            final pct      = totalExpenses > 0
                ? amount / totalExpenses * 100
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child:
                            Icon(_icon(category), color: color, size: 16),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          ExpenseCategory.labelFor(category),
                          style: AppTheme.bodySmall
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        CurrencyFormatter.formatFull(amount),
                        style: AppTheme.bodyMedium.copyWith(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalExpenses > 0 ? amount / totalExpenses : 0,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Data Warning Banner ──────────────────────────────────────────────────────

class _DataWarningBanner extends StatelessWidget {
  final String message;
  const _DataWarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border:
            Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppTheme.warningColor, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Text(message,
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.warningColor)),
          ),
        ],
      ),
    );
  }
}

// ─── Expenses List ────────────────────────────────────────────────────────────

class _ExpensesList extends StatelessWidget {
  final List<Expense> expenses;
  const _ExpensesList({required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: AppTheme.spacingMD),
            Text('No expenses yet', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('Tap \u201CAdd Expense\u201D to get started',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    final categoryMap = <String, double>{};
    for (final e in expenses) {
      categoryMap[e.category] = (categoryMap[e.category] ?? 0) + e.amount;
    }
    final total = expenses.fold(0.0, (s, e) => s + e.amount);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // space above FAB
      itemCount: expenses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: _CostBreakdown(
                expensesByCategory: categoryMap, totalExpenses: total),
          );
        }
        final e = expenses[index - 1];
        return _ExpenseCard(expense: e);
      },
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppTheme.spacingMD, 0, AppTheme.spacingMD, AppTheme.spacingMD),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(Icons.arrow_downward,
                color: AppTheme.errorColor, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description, style: AppTheme.bodyLarge),
                Text(
                  '${ExpenseCategory.labelFor(expense.category)} \u2022 '
                  '${DateFormatter.formatShort(expense.date)}',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatFull(expense.amount),
            style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.errorColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Sales List ───────────────────────────────────────────────────────────────

class _SalesList extends StatelessWidget {
  final List<Sale> sales;
  const _SalesList({required this.sales});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: AppTheme.spacingMD),
            Text('No sales yet', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('Tap \u201CRecord Sale\u201D to get started',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacingMD,
          AppTheme.spacingMD, AppTheme.spacingMD, 80),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final s = sales[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(Icons.arrow_upward,
                    color: AppTheme.successColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.saleTypeLabel, style: AppTheme.bodyLarge),
                    Text(
                      '${s.quantity.toStringAsFixed(0)} ${s.unitLabel} \u2022 '
                      '${CurrencyFormatter.formatFull(s.pricePerUnit)}/unit \u2022 '
                      '${DateFormatter.formatShort(s.date)}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                    if (s.buyerName != null)
                      Text('Buyer: ${s.buyerName}',
                          style: AppTheme.bodySmall
                              .copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                CurrencyFormatter.formatFull(s.totalAmount),
                style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Add Expense Sheet ────────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final String flockId;
  const _AddExpenseSheet({required this.flockId});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _descController  = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController  = TextEditingController();
  String   _category      = ExpenseCategory.feed;
  String   _paymentMethod = PaymentMethod.cash;
  DateTime _selectedDate  = DateTime.now();
  bool     _isSaving      = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await context.read<FinanceProvider>().addExpense(
          flockId:       widget.flockId,
          category:      _category,
          description:   _descController.text.trim(),
          amount:        double.parse(_amountController.text),
          date:          _selectedDate.toIso8601String().split('T').first,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Add Expense',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DatePicker(
              selectedDate: _selectedDate,
              onDatePicked: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: AppTheme.inputDecoration('Category'),
              items: ExpenseCategory.all
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(ExpenseCategory.labelFor(c)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _descController,
              decoration: AppTheme.inputDecoration('Description'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _amountController,
              decoration: AppTheme.inputDecoration('Amount (\u20a6)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v!.trim().isEmpty) return 'Please enter an amount';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                if (double.parse(v) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: AppTheme.inputDecoration('Payment Method'),
              items: PaymentMethod.all
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(PaymentMethod.labelFor(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _notesController,
              decoration: AppTheme.inputDecoration('Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Sale Sheet ───────────────────────────────────────────────────────────

// ── FIX 7: Removed super.key from private widget constructor
class _AddSaleSheet extends StatefulWidget {
  final String flockId;
  final int birdCount;
  const _AddSaleSheet({required this.flockId, required this.birdCount});

  @override
  State<_AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<_AddSaleSheet> {
  final _formKey            = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController    = TextEditingController();
  final _buyerController    = TextEditingController();
  final _notesController    = TextEditingController();

  String   _saleType      = SaleType.eggs;
  late String _unit;
  String   _paymentMethod = PaymentMethod.cash;
  DateTime _selectedDate  = DateTime.now();
  bool     _isSaving      = false;

  @override
  void initState() {
    super.initState();
    _unit = SaleUnit.forSaleType(_saleType).first;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _buyerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSaleTypeChanged(String newType) {
    setState(() {
      _saleType = newType;
      _unit = SaleUnit.forSaleType(newType).first;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await context.read<FinanceProvider>().addSale(
          flockId:       widget.flockId,
          saleType:      _saleType,
          quantity:      double.parse(_quantityController.text),
          unit:          _unit,
          pricePerUnit:  double.parse(_priceController.text),
          date:          _selectedDate.toIso8601String().split('T').first,
          buyerName: _buyerController.text.trim().isEmpty
              ? null
              : _buyerController.text.trim(),
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          flockProvider: context.read<FlockProvider>(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final availableUnits = SaleUnit.forSaleType(_saleType);

    return _BottomSheet(
      title: 'Record Sale',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DatePicker(
              selectedDate: _selectedDate,
              onDatePicked: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: _saleType,
              decoration: AppTheme.inputDecoration('Sale Type'),
              items: SaleType.all
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(SaleType.labelFor(t)),
                      ))
                  .toList(),
              onChanged: (v) => _onSaleTypeChanged(v!),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: AppTheme.inputDecoration('Quantity'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v!.trim().isEmpty) return 'Required';
                      final qty = double.tryParse(v);
                      if (qty == null || qty <= 0) return 'Invalid';
                      if (_saleType == SaleType.birds &&
                          qty > widget.birdCount) {
                        return 'Max ${widget.birdCount}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: AppTheme.inputDecoration('Unit'),
                    items: availableUnits
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(SaleUnit.labelFor(u)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _priceController,
              decoration:
                  AppTheme.inputDecoration('Price Per Unit (\u20a6)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v!.trim().isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _buyerController,
              decoration:
                  AppTheme.inputDecoration('Buyer Name (optional)'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: AppTheme.inputDecoration('Payment Method'),
              items: PaymentMethod.all
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(PaymentMethod.labelFor(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _notesController,
              decoration: AppTheme.inputDecoration('Notes (optional)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDatePicked;
  const _DatePicker(
      {required this.selectedDate, required this.onDatePicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onDatePicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: AppTheme.spacingSM),
            Text(
              DateFormatter.format(
                  selectedDate.toIso8601String().split('T').first),
              style: AppTheme.bodyMedium,
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down,
                color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── FIX: _BottomSheet now takes a single child widget instead of
// List<Widget> children — callers wrap their content in a Column/Form
// themselves, which is cleaner and removes the spread operator overhead.
class _BottomSheet extends StatelessWidget {
  final String title;
  final bool isSaving;
  final VoidCallback onSave;
  final Widget child;

  const _BottomSheet({
    required this.title,
    required this.isSaving,
    required this.onSave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left:   AppTheme.spacingMD,
        right:  AppTheme.spacingMD,
        top:    AppTheme.spacingMD,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(title, style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingMD),
            child,
            const SizedBox(height: AppTheme.spacingLG),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppTheme.primaryButtonStyle,
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(title,
                        style: AppTheme.labelLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}