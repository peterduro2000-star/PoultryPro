// lib/screens/finance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../models/flock.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';
import '../utils/finance_calculator.dart';

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
                        _FinanceFlockHeader(
                            flock: flockProvider.selectedFlock!),
                        Container(
                          margin: const EdgeInsets.fromLTRB(
                            AppTheme.spacingMD,
                            AppTheme.spacingMD,
                            AppTheme.spacingMD,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            boxShadow: const [AppTheme.shadowSM],
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMD),
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
                        const SizedBox(height: AppTheme.spacingMD),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _ExpensesTab(
                                provider: provider,
                                flock: flockProvider.selectedFlock!,
                              ),
                              _SalesTab(sales: provider.sales),
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

// ─── Shared Flock Context ────────────────────────────────────────────────────

class _FinanceFlockHeader extends StatelessWidget {
  final Flock flock;

  const _FinanceFlockHeader({required this.flock});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: const Icon(Icons.egg_alt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Text(
                  flock.name,
                  style: AppTheme.headingSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: [
              _ContextPill(icon: Icons.category, text: flock.type),
              _ContextPill(
                  icon: Icons.groups, text: '${flock.birdCount} birds'),
              _ContextPill(icon: Icons.schedule, text: flock.ageDisplay),
              _ContextPill(icon: Icons.flag, text: flock.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContextPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(color: Colors.white),
          ),
        ],
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
    final analysis = FinanceAnalysis(
      initialFlockCost: flock.initialCost,
      totalExpenses: provider.totalExpenses,
      totalSales: provider.totalSales,
      currentBirds: flock.birdCount,
      originalCostPerBird: flock.costPerBird,
    );
    final isProfit = analysis.netProfit >= 0;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          decoration: BoxDecoration(
            color: isProfit
                ? AppTheme.successColor
                : AppTheme.errorColor.withOpacity(0.92),
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
                CurrencyFormatter.format(analysis.netProfit.abs()),
                style: AppTheme.headingLarge
                    .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.spacingMD,
                runSpacing: AppTheme.spacingSM,
                children: [
                  _HeroMetric(
                    label: 'Margin',
                    value: '${analysis.profitMargin.toStringAsFixed(1)}%',
                  ),
                  _HeroMetric(
                    label: 'Cost recovery',
                    value:
                        '${analysis.costRecoveryPercentage.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _FinanceSection(
          title: 'Profit Summary',
          children: [
            _ProfitRow(
              label: 'Total Sales',
              value: CurrencyFormatter.format(analysis.totalSales),
              color: AppTheme.successColor,
              icon: Icons.arrow_upward,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Total Expenses',
              value: CurrencyFormatter.format(analysis.totalExpenses),
              color: AppTheme.textPrimary,
              icon: Icons.receipt_long,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Initial Flock Investment',
              value: CurrencyFormatter.format(analysis.initialFlockCost),
              color: AppTheme.primaryColor,
              icon: Icons.egg_alt,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Unrecovered Cost',
              value: CurrencyFormatter.format(analysis.unrecoveredCost),
              color: analysis.unrecoveredCost > 0
                  ? AppTheme.errorColor
                  : AppTheme.successColor,
              icon: Icons.account_balance_wallet,
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _FinanceSection(
          title: 'Per Bird Analysis',
          subtitle: 'Based on ${flock.birdCount} current birds',
          children: [
            _ProfitRow(
              label: 'Original cost per bird',
              value: CurrencyFormatter.format(analysis.originalCostPerBird),
              color: AppTheme.primaryColor,
              icon: Icons.egg_alt,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Current cost per remaining bird',
              value: CurrencyFormatter.format(
                  analysis.currentCostPerRemainingBird),
              color: AppTheme.errorColor,
              icon: Icons.calculate,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Break-even price per remaining bird',
              value: CurrencyFormatter.format(
                  analysis.breakEvenPricePerRemainingBird),
              color: AppTheme.infoColor,
              icon: Icons.balance,
            ),
            const Divider(),
            _ProfitRow(
              label: isProfit ? 'Profit per bird' : 'Loss per bird',
              value: CurrencyFormatter.format(analysis.profitLossPerBird.abs()),
              color: isProfit ? AppTheme.successColor : AppTheme.errorColor,
              icon: isProfit ? Icons.trending_up : Icons.trending_down,
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _FinanceSection(
          title: 'Suggested Selling Prices',
          subtitle: 'Targets per remaining bird',
          children: [
            _PriceSuggestion(
              label: 'Break-even',
              price: analysis.sellingPriceForMargin(0),
              profitPerBird: 0,
              color: AppTheme.infoColor,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _PriceSuggestion(
              label: '10% margin',
              price: analysis.sellingPriceForMargin(10),
              profitPerBird: analysis.sellingPriceForMargin(10) -
                  analysis.breakEvenPricePerRemainingBird,
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _PriceSuggestion(
              label: '20% margin',
              price: analysis.sellingPriceForMargin(20),
              profitPerBird: analysis.sellingPriceForMargin(20) -
                  analysis.breakEvenPricePerRemainingBird,
              color: AppTheme.successColor,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            _PriceSuggestion(
              label: '30% margin',
              price: analysis.sellingPriceForMargin(30),
              profitPerBird: analysis.sellingPriceForMargin(30) -
                  analysis.breakEvenPricePerRemainingBird,
              color: AppTheme.accentColor,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _BusinessInsightCard(analysis: analysis),
        const SizedBox(height: AppTheme.spacingMD),
        const SizedBox(height: AppTheme.spacingLG),
      ],
    );
  }
}

// ─── Profit Row ───────────────────────────────────────────────────────────────

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: AppTheme.bodySmall.copyWith(color: Colors.white70),
    );
  }
}

class _FinanceSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _FinanceSection({
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
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              subtitle!,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacingMD),
          ...children,
        ],
      ),
    );
  }
}

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
          const SizedBox(width: AppTheme.spacingMD),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: AppTheme.bodyMedium.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInsightCard extends StatelessWidget {
  final FinanceAnalysis analysis;

  const _BusinessInsightCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final isProfit = analysis.netProfit >= 0;
    final insights = [
      'Sales have recovered ${analysis.costRecoveryPercentage.toStringAsFixed(1)}% of total cost.',
      if (analysis.currentCostPerRemainingBird > 0)
        'Remaining birds need to sell above ${CurrencyFormatter.format(analysis.currentCostPerRemainingBird)} each to avoid loss.',
      if (!isProfit)
        'Current position is a net loss until more birds are sold.'
      else
        'Current position is profitable after recovering flock and expense costs.',
    ];

    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        color: isProfit
            ? AppTheme.successColor.withOpacity(0.08)
            : AppTheme.warningColor.withOpacity(0.12),
        border: Border.all(
          color: isProfit
              ? AppTheme.successColor.withOpacity(0.25)
              : AppTheme.warningColor.withOpacity(0.35),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: isProfit ? AppTheme.successColor : AppTheme.primaryColor,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text('Business Insight', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          ...insights.take(2).map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Text(insight, style: AppTheme.bodyMedium),
                ),
              ),
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
              Text('Above break-even',
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
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (expensesByCategory.isEmpty) return const SizedBox.shrink();

    final sorted = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: AppTheme.cardDecoration,
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

// ─── Expenses Tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends StatelessWidget {
  final FinanceProvider provider;
  final Flock flock;

  const _ExpensesTab({required this.provider, required this.flock});

  @override
  Widget build(BuildContext context) {
    final expenses = provider.expenses;
    final totalExpenses = provider.totalExpenses;
    final expensePerBird =
        flock.birdCount > 0 ? totalExpenses / flock.birdCount : 0.0;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        _FinanceSection(
          title: 'Expense Tracking',
          children: [
            _ProfitRow(
              label: 'Total Expenses',
              value: CurrencyFormatter.format(totalExpenses),
              color: AppTheme.textPrimary,
              icon: Icons.receipt_long,
              bold: true,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Expense per current bird',
              value: CurrencyFormatter.format(expensePerBird),
              color: AppTheme.primaryColor,
              icon: Icons.calculate,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        if (provider.expensesByCategory.isNotEmpty) ...[
          _CategoryBreakdown(
            expensesByCategory: provider.expensesByCategory,
            totalExpenses: totalExpenses,
          ),
          const SizedBox(height: AppTheme.spacingMD),
        ],
        Text('Expense Records', style: AppTheme.headingSmall),
        const SizedBox(height: AppTheme.spacingMD),
        if (expenses.isEmpty)
          _EmptyRecords(
            icon: Icons.receipt_long,
            title: 'No expenses yet',
            message: 'Tap + to add an expense',
          )
        else
          ...expenses.map((expense) => _ExpenseRecord(expense: expense)),
        const SizedBox(height: AppTheme.spacingLG),
      ],
    );
  }
}

class _ExpenseRecord extends StatelessWidget {
  final Expense expense;

  const _ExpenseRecord({required this.expense});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(Icons.receipt_long,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.description, style: AppTheme.bodyLarge),
                Text(
                  '${expense.category} • ${DateFormatter.formatShort(expense.date)}',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Text(
            CurrencyFormatter.format(expense.amount),
            textAlign: TextAlign.right,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sales Tab ────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final List<Sale> sales;

  const _SalesTab({required this.sales});

  @override
  Widget build(BuildContext context) {
    final totalSales = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final birdSales = sales.where((sale) =>
        sale.saleType.toLowerCase() == 'birds' ||
        sale.unit.toLowerCase() == 'birds');
    final birdsSold = birdSales.fold(0.0, (sum, sale) => sum + sale.quantity);
    final birdSaleRevenue =
        birdSales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final averageBirdPrice = birdsSold > 0 ? birdSaleRevenue / birdsSold : 0.0;
    final birdsSoldText = birdsSold.truncateToDouble() == birdsSold
        ? birdsSold.toStringAsFixed(0)
        : birdsSold.toStringAsFixed(1);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        _FinanceSection(
          title: 'Income Tracking',
          children: [
            _ProfitRow(
              label: 'Total Sales/Income',
              value: CurrencyFormatter.format(totalSales),
              color: AppTheme.successColor,
              icon: Icons.point_of_sale,
              bold: true,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Birds sold',
              value: birdsSoldText,
              color: AppTheme.textPrimary,
              icon: Icons.groups,
            ),
            const Divider(),
            _ProfitRow(
              label: 'Average selling price per bird',
              value: CurrencyFormatter.format(averageBirdPrice),
              color: AppTheme.primaryColor,
              icon: Icons.sell,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Text('Sales Records', style: AppTheme.headingSmall),
        const SizedBox(height: AppTheme.spacingMD),
        if (sales.isEmpty)
          _EmptyRecords(
            icon: Icons.point_of_sale,
            title: 'No sales yet',
            message: 'Tap + to record a sale',
          )
        else
          ...sales.map((sale) => _SaleRecord(sale: sale)),
        const SizedBox(height: AppTheme.spacingLG),
      ],
    );
  }
}

class _SaleRecord extends StatelessWidget {
  final Sale sale;

  const _SaleRecord({required this.sale});

  @override
  Widget build(BuildContext context) {
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
                Text(sale.saleType, style: AppTheme.bodyLarge),
                Text(
                  '${sale.quantity} ${sale.unit} • ${CurrencyFormatter.format(sale.pricePerUnit)}/unit • ${DateFormatter.formatShort(sale.date)}',
                  style: AppTheme.bodySmall,
                ),
                if (sale.buyerName != null)
                  Text('Buyer: ${sale.buyerName}', style: AppTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Text(
            CurrencyFormatter.format(sale.totalAmount),
            textAlign: TextAlign.right,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyRecords({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.primaryColor.withOpacity(0.35)),
          const SizedBox(height: AppTheme.spacingMD),
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text(message, style: AppTheme.bodyMedium),
        ],
      ),
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
