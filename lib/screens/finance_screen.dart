// lib/screens/finance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../models/flock.dart';
import '../widgets/flock_header.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FlockProvider? _flockProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_flockProvider != null) return;

    _flockProvider = context.read<FlockProvider>();
    _flockProvider!.addListener(_onFlockChanged);

    final flock = _flockProvider!.selectedFlock;
    if (flock != null) {
      context.read<FinanceProvider>().loadFinanceData(flock.id);
    }
  }

  void _onFlockChanged() {
    final flock = _flockProvider?.selectedFlock;
    if (flock != null && mounted) {
      context.read<FinanceProvider>().loadFinanceData(flock.id);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flockProvider?.removeListener(_onFlockChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Finance'),
      ),
      body: Column(
        children: [
          const FlockHeader(),

          // ── Visible Tab Selector ─────────────────────────────────────
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
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
                if (flockProvider.selectedFlock == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home,
                            size: 48,
                            color: AppTheme.primaryColor.withOpacity(0.4)),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text('No flock selected', style: AppTheme.headingSmall),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text('Go to Home screen to select a flock',
                            style: AppTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                return Consumer<FinanceProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.error != null) {
                      return Center(
                          child: Text(provider.error!,
                              style: AppTheme.bodyMedium
                                  .copyWith(color: AppTheme.errorColor)));
                    }
                    return Column(
                      children: [
                        const SizedBox(height: AppTheme.spacingMD),
                        _SummaryBar(provider: provider),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _ExpensesList(expenses: provider.expenses),
                              _SalesList(sales: provider.sales),
                              _ProfitTab(
                                provider: provider,
                                flock: flockProvider.selectedFlock!,
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
      floatingActionButton: Consumer<FlockProvider>(
        builder: (context, provider, _) => provider.selectedFlock == null
            ? const SizedBox.shrink()
            : ListenableBuilder(
                listenable: _tabController,
                builder: (context, _) => _tabController.index == 2
                    ? const SizedBox.shrink()
                    : FloatingActionButton(
                        heroTag: 'finance_fab',
                        onPressed: () =>
                            _showAddSheet(context, provider.selectedFlock!.id),
                        child: const Icon(Icons.add),
                      ),
              ),
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

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final FinanceProvider provider;
  const _SummaryBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isProfit = provider.profit >= 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          _SummaryChip(
              icon: Icons.arrow_downward,
              label: 'Expenses',
              value: CurrencyFormatter.format(provider.totalExpenses),
              color: AppTheme.errorColor),
          const SizedBox(width: AppTheme.spacingSM),
          _SummaryChip(
              icon: Icons.arrow_upward,
              label: 'Sales',
              value: CurrencyFormatter.format(provider.totalSales),
              color: AppTheme.successColor),
          const SizedBox(width: AppTheme.spacingSM),
          _SummaryChip(
              icon: isProfit ? Icons.trending_up : Icons.trending_down,
              label: 'Profit',
              value: CurrencyFormatter.format(provider.profit),
              color: isProfit ? AppTheme.successColor : AppTheme.errorColor),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingSM, horizontal: AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(value,
                style: AppTheme.bodyMedium
                    .copyWith(color: color, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            Text(label, style: AppTheme.bodySmall),
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

  String _formatN(double v) => CurrencyFormatter.format(v);

  @override
  Widget build(BuildContext context) {
    final totalRevenue = provider.totalSales;
    final totalExpenses = provider.totalExpenses;
    final netProfit = provider.profit;
    final profitMargin = provider.profitMargin;
    final isProfit = netProfit >= 0;

    // Bird cost accounting
    final initialBirdCost = flock.initialCost;
    final currentBirdCount = flock.birdCount;
    final costPerBird = flock.costPerBird;

    // Suggested selling prices
    final suggestedAt20 = costPerBird * 1.20;
    final suggestedAt30 = costPerBird * 1.30;
    final suggestedAt50 = costPerBird * 1.50;

    // Profit per bird
    final profitPerBird =
        currentBirdCount > 0 ? netProfit / currentBirdCount : 0.0;

    // Break-even price per bird
    final breakEvenPerBird =
        currentBirdCount > 0 ? totalExpenses / currentBirdCount : 0.0;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        // ── Net Profit Hero Card ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: isProfit ? AppTheme.successColor : AppTheme.errorColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
              Text(
                _formatN(netProfit.abs()),
                style: AppTheme.headingLarge
                    .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Margin: ${profitMargin.toStringAsFixed(1)}%',
                style: AppTheme.bodySmall.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Revenue vs Expenses ──────────────────────────────────────────
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revenue vs Expenses', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),
              _ProfitRow(
                label: 'Total Revenue',
                value: _formatN(totalRevenue),
                color: AppTheme.successColor,
                icon: Icons.arrow_upward,
              ),
              const Divider(),
              _ProfitRow(
                label: 'Total Expenses',
                value: _formatN(totalExpenses),
                color: AppTheme.errorColor,
                icon: Icons.arrow_downward,
              ),
              const Divider(),
              _ProfitRow(
                label: 'Initial Bird Cost',
                value: _formatN(initialBirdCost),
                color: AppTheme.warningColor,
                icon: Icons.egg_alt,
              ),
              const Divider(),
              _ProfitRow(
                label: isProfit ? 'Net Profit' : 'Net Loss',
                value: _formatN(netProfit.abs()),
                color: isProfit ? AppTheme.successColor : AppTheme.errorColor,
                icon: isProfit ? Icons.trending_up : Icons.trending_down,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Per Bird Analysis ────────────────────────────────────────────
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Per Bird Analysis', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingSM),
              Text('Based on ${flock.birdCount} current birds',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacingMD),
              _ProfitRow(
                label: 'Cost price per bird',
                value: _formatN(costPerBird),
                color: AppTheme.warningColor,
                icon: Icons.egg_alt,
              ),
              const Divider(),
              _ProfitRow(
                label: 'Break-even price per bird',
                value: _formatN(breakEvenPerBird),
                color: AppTheme.infoColor,
                icon: Icons.balance,
              ),
              const Divider(),
              _ProfitRow(
                label: isProfit ? 'Profit per bird' : 'Loss per bird',
                value: _formatN(profitPerBird.abs()),
                color: profitPerBird >= 0
                    ? AppTheme.successColor
                    : AppTheme.errorColor,
                icon: profitPerBird >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Suggested Selling Prices ─────────────────────────────────────
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suggested Bird Selling Prices',
                  style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Based on cost price of ${_formatN(costPerBird)}/bird',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              _PriceSuggestion(
                label: '20% margin',
                price: suggestedAt20,
                profitPerBird: suggestedAt20 - costPerBird,
                color: AppTheme.infoColor,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              _PriceSuggestion(
                label: '30% margin',
                price: suggestedAt30,
                profitPerBird: suggestedAt30 - costPerBird,
                color: AppTheme.successColor,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              _PriceSuggestion(
                label: '50% margin',
                price: suggestedAt50,
                profitPerBird: suggestedAt50 - costPerBird,
                color: AppTheme.accentColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Cost Breakdown ───────────────────────────────────────────────
        if (provider.expensesByCategory.isNotEmpty)
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cost Breakdown', style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingMD),
                ...provider.expensesByCategory.entries
                    .toList()
                    .sorted((a, b) => b.value.compareTo(a.value))
                    .asMap()
                    .entries
                    .map((entry) {
                  final category = entry.value.key;
                  final amount = entry.value.value;
                  final pct =
                      totalExpenses > 0 ? (amount / totalExpenses * 100) : 0.0;
                  final colors = [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                    AppTheme.accentColor,
                    AppTheme.infoColor,
                    AppTheme.warningColor,
                    AppTheme.successColor,
                    AppTheme.errorColor,
                  ];
                  final color = colors[entry.key % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        Expanded(
                          child: Text(category.toUpperCase(),
                              style: AppTheme.bodySmall),
                        ),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: AppTheme.bodySmall
                                .copyWith(color: AppTheme.textSecondary)),
                        const SizedBox(width: AppTheme.spacingSM),
                        Text(_formatN(amount),
                            style: AppTheme.bodySmall
                                .copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Data completeness warning ────────────────────────────────────
        if (totalRevenue == 0 || totalExpenses == 0)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.warningColor.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppTheme.warningColor, size: 20),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    totalRevenue == 0
                        ? 'No sales recorded yet. Add sales to see accurate profit.'
                        : 'No expenses recorded yet. Add expenses for accurate profit.',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppTheme.spacingLG),
      ],
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
            child: Text(label,
                style: bold
                    ? AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                    : AppTheme.bodyMedium),
          ),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Price Suggestion Card ────────────────────────────────────────────────────

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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
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
                Text('${CurrencyFormatter.format(price)}/bird',
                    style: AppTheme.bodyLarge
                        .copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Profit/bird',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary)),
              Text(CurrencyFormatter.formatSigned(profitPerBird),
                  style: AppTheme.bodyMedium
                      .copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Category Breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> expensesByCategory;
  final double totalExpenses;

  const _CategoryBreakdown({
    required this.expensesByCategory,
    required this.totalExpenses,
  });

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'feed':
        return Icons.set_meal;
      case 'medicine':
        return Icons.medication;
      case 'labor':
        return Icons.people;
      case 'utilities':
        return Icons.bolt;
      case 'equipment':
        return Icons.handyman;
      case 'chicks':
        return Icons.egg_alt;
      default:
        return Icons.category;
    }
  }

  Color _categoryColor(int index) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      AppTheme.infoColor,
      AppTheme.warningColor,
      AppTheme.successColor,
      AppTheme.errorColor,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    final sorted = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense Breakdown', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          ...sorted.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value.key;
            final amount = entry.value.value;
            final percentage =
                totalExpenses > 0 ? (amount / totalExpenses * 100) : 0.0;
            final color = _categoryColor(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: Icon(_categoryIcon(category),
                            color: color, size: 16),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          category.toUpperCase(),
                          style: AppTheme.bodySmall
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        CurrencyFormatter.format(amount),
                        style: AppTheme.bodyMedium.copyWith(
                            color: color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalExpenses > 0 ? amount / totalExpenses : 0,
                      backgroundColor: color.withOpacity(0.1),
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
                size: 64, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingMD),
            Text('No expenses yet', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('Tap + to add an expense', style: AppTheme.bodyMedium),
          ],
        ),
      );
    }

    final categoryMap = <String, double>{};
    for (final e in expenses) {
      categoryMap[e.category] = (categoryMap[e.category] ?? 0) + e.amount;
    }
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: expenses.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CategoryBreakdown(
            expensesByCategory: categoryMap,
            totalExpenses: totalExpenses,
          );
        }
        final e = expenses[index - 1];
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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
                    Text(e.description, style: AppTheme.bodyLarge),
                    Text('${e.category} • ${DateFormatter.formatShort(e.date)}',
                        style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Text(CurrencyFormatter.format(e.amount),
                  style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
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
                size: 64, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingMD),
            Text('No sales yet', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingSM),
            Text('Tap + to record a sale', style: AppTheme.bodyMedium),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
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
                  color: AppTheme.successColor.withOpacity(0.1),
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
                    Text(s.saleType, style: AppTheme.bodyLarge),
                    Text(
                        '${s.quantity} ${s.unit} • ${CurrencyFormatter.format(s.pricePerUnit)}/unit • ${DateFormatter.formatShort(s.date)}',
                        style: AppTheme.bodySmall),
                    if (s.buyerName != null)
                      Text('Buyer: ${s.buyerName}', style: AppTheme.bodySmall),
                  ],
                ),
              ),
              Text(CurrencyFormatter.format(s.totalAmount),
                  style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold)),
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
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = 'feed';
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final _categories = [
    'feed',
    'medicine',
    'labor',
    'utilities',
    'equipment',
    'chicks',
    'other'
  ];
  final _paymentMethods = ['cash', 'mobile_money', 'bank'];

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
          flockId: widget.flockId,
          category: _category,
          description: _descController.text,
          amount: double.parse(_amountController.text),
          date: _selectedDate.toIso8601String().split('T').first,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Add Expense',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _DatePicker(
                  selectedDate: _selectedDate,
                  onDatePicked: (d) => setState(() => _selectedDate = d)),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: AppTheme.inputDecoration('Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descController,
                decoration: AppTheme.inputDecoration('Description'),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _amountController,
                decoration: AppTheme.inputDecoration('Amount (₦)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'Please enter an amount' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: AppTheme.inputDecoration('Payment Method'),
                items: _paymentMethods
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
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
      ],
    );
  }
}

// ─── Add Sale Sheet ───────────────────────────────────────────────────────────

class _AddSaleSheet extends StatefulWidget {
  final String flockId;
  final int birdCount;
  const _AddSaleSheet(
      {super.key, required this.flockId, required this.birdCount});

  @override
  State<_AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<_AddSaleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _buyerController = TextEditingController();
  final _notesController = TextEditingController();
  String _saleType = 'eggs';
  String _unit = 'crates';
  String _paymentMethod = 'cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final _saleTypes = ['eggs', 'birds', 'manure'];
  final _units = ['crates', 'units', 'kg', 'bags'];
  final _paymentMethods = ['cash', 'mobile_money', 'bank'];

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _buyerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await context.read<FinanceProvider>().addSale(
          flockId: widget.flockId,
          saleType: _saleType,
          quantity: double.parse(_quantityController.text),
          unit: _unit,
          pricePerUnit: double.parse(_priceController.text),
          date: _selectedDate.toIso8601String().split('T').first,
          buyerName:
              _buyerController.text.isEmpty ? null : _buyerController.text,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          flockProvider: context.read<FlockProvider>(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheet(
      title: 'Record Sale',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              _DatePicker(
                  selectedDate: _selectedDate,
                  onDatePicked: (d) => setState(() => _selectedDate = d)),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<String>(
                value: _saleType,
                decoration: AppTheme.inputDecoration('Sale Type'),
                items: _saleTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _saleType = v!),
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
                        if (v!.isEmpty) return 'Required';
                        if (_saleType == 'birds') {
                          final qty = double.tryParse(v);
                          if (qty == null) return 'Invalid number';
                          if (qty > widget.birdCount) {
                            return 'Only ${widget.birdCount} birds available';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: AppTheme.inputDecoration('Unit'),
                      items: _units
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _priceController,
                decoration: AppTheme.inputDecoration('Price Per Unit (₦)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _buyerController,
                decoration: AppTheme.inputDecoration('Buyer Name (optional)'),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: AppTheme.inputDecoration('Payment Method'),
                items: _paymentMethods
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
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
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDatePicked;
  const _DatePicker({required this.selectedDate, required this.onDatePicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onDatePicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            const SizedBox(width: AppTheme.spacingSM),
            Text(selectedDate.toIso8601String().split('T').first,
                style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final String title;
  final bool isSaving;
  final VoidCallback onSave;
  final List<Widget> children;

  const _BottomSheet(
      {required this.title,
      required this.isSaving,
      required this.onSave,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spacingMD,
        right: AppTheme.spacingMD,
        top: AppTheme.spacingMD,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingMD,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(title, style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingMD),
            ...children,
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
                            color: Colors.white, strokeWidth: 2))
                    : Text(title),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List extension ───────────────────────────────────────────────────────────

extension _SortedList<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}
