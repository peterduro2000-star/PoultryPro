import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class BatchComparisonScreen extends StatefulWidget {
  const BatchComparisonScreen({super.key});

  @override
  State<BatchComparisonScreen> createState() =>
      _BatchComparisonScreenState();
}

class _BatchComparisonScreenState extends State<BatchComparisonScreen> {
  Flock? _flockA;
  Flock? _flockB;
  _BatchStats? _statsA;
  _BatchStats? _statsB;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectFlocks();
    });
  }

  void _autoSelectFlocks() {
    final flocks = context.read<FlockProvider>().flocks;
    if (flocks.length >= 2) {
      setState(() {
        _flockA = flocks[0];
        _flockB = flocks[1];
      });
      _loadStats();
    } else if (flocks.length == 1) {
      setState(() => _flockA = flocks[0]);
    }
  }

  Future<void> _loadStats() async {
    if (_flockA == null || _flockB == null) return;
    setState(() => _loading = true);

    final db = DatabaseService();
    final financeProvider = context.read<FinanceProvider>();

    final recordsA = await db.getDailyRecordsByFlock(_flockA!.id);
    final recordsB = await db.getDailyRecordsByFlock(_flockB!.id);

    final mortalityA =
        await db.getTotalMortalityByFlock(_flockA!.id);
    final mortalityB =
        await db.getTotalMortalityByFlock(_flockB!.id);

    final expensesA =
        financeProvider.totalExpensesForFlock(_flockA!.id);
    final expensesB =
        financeProvider.totalExpensesForFlock(_flockB!.id);

    final salesA = financeProvider.totalSalesForFlock(_flockA!.id);
    final salesB = financeProvider.totalSalesForFlock(_flockB!.id);

    final recoveryA =
        financeProvider.recoveryPercentageForFlock(_flockA!.id);
    final recoveryB =
        financeProvider.recoveryPercentageForFlock(_flockB!.id);

    // FCR calculation
    double _calcFcr(Flock flock, records) {
      final totalFeed = records.fold<double>(
          0, (s, r) => s + (r.feedGiven ?? 0));
      final withWeight =
          records.where((r) => r.averageWeight != null).toList();
      if (withWeight.length < 2 || totalFeed <= 0) return 0;
      final weightGain =
          (withWeight.first.averageWeight! - withWeight.last.averageWeight!) *
              flock.birdCount;
      if (weightGain <= 0) return 0;
      return totalFeed / weightGain;
    }

    final fcrA = _calcFcr(_flockA!, recordsA);
    final fcrB = _calcFcr(_flockB!, recordsB);

    // Duration in days
    final startA = DateTime.tryParse(_flockA!.startDate);
    final startB = DateTime.tryParse(_flockB!.startDate);
    final durationA = startA != null
        ? DateTime.now().difference(startA).inDays
        : 0;
    final durationB = startB != null
        ? DateTime.now().difference(startB).inDays
        : 0;

    final profitA = salesA - expensesA;
    final profitB = salesB - expensesB;

    final mortalityRateA = _flockA!.initialBirdCount > 0
        ? mortalityA / _flockA!.initialBirdCount * 100
        : 0.0;
    final mortalityRateB = _flockB!.initialBirdCount > 0
        ? mortalityB / _flockB!.initialBirdCount * 100
        : 0.0;

    final costPerBirdA = _flockA!.initialBirdCount > 0
        ? expensesA / _flockA!.initialBirdCount
        : 0.0;
    final costPerBirdB = _flockB!.initialBirdCount > 0
        ? expensesB / _flockB!.initialBirdCount
        : 0.0;

    final profitPerBirdA = _flockA!.initialBirdCount > 0
        ? profitA / _flockA!.initialBirdCount
        : 0.0;
    final profitPerBirdB = _flockB!.initialBirdCount > 0
        ? profitB / _flockB!.initialBirdCount
        : 0.0;

    setState(() {
      _statsA = _BatchStats(
        flock: _flockA!,
        totalExpenses: expensesA,
        totalSales: salesA,
        profit: profitA,
        profitPerBird: profitPerBirdA,
        costPerBird: costPerBirdA,
        mortalityRate: mortalityRateA,
        mortalityCount: mortalityA,
        recoveryPercentage: recoveryA,
        fcr: fcrA,
        durationDays: durationA,
        recordCount: recordsA.length,
      );
      _statsB = _BatchStats(
        flock: _flockB!,
        totalExpenses: expensesB,
        totalSales: salesB,
        profit: profitB,
        profitPerBird: profitPerBirdB,
        costPerBird: costPerBirdB,
        mortalityRate: mortalityRateB,
        mortalityCount: mortalityB,
        recoveryPercentage: recoveryB,
        fcr: fcrB,
        durationDays: durationB,
        recordCount: recordsB.length,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final flocks = context.watch<FlockProvider>().flocks;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Batch Comparison'),
        elevation: 0,
      ),
      body: flocks.isEmpty
          ? _buildNoFlocks()
          : flocks.length == 1
              ? _buildOneFlockState()
              : _buildComparison(flocks),
    );
  }

  Widget _buildNoFlocks() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: AppTheme.spacingMD),
          Text('No flocks yet', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text('Create at least two flocks to compare batches.',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildOneFlockState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: AppTheme.spacingMD),
          Text('Need one more batch', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'You have one flock. Create or complete a second batch to compare performance.',
            style: AppTheme.bodyMedium
                .copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparison(List<Flock> flocks) {
    return Column(
      children: [
        // ── Flock selectors ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Expanded(
                child: _FlockSelector(
                  label: 'Batch A',
                  selected: _flockA,
                  flocks: flocks,
                  color: AppTheme.primaryColor,
                  onChanged: (f) {
                    setState(() => _flockA = f);
                    _loadStats();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD),
                child: Icon(Icons.compare_arrows,
                    color: AppTheme.textSecondary),
              ),
              Expanded(
                child: _FlockSelector(
                  label: 'Batch B',
                  selected: _flockB,
                  flocks: flocks,
                  color: AppTheme.secondaryColor,
                  onChanged: (f) {
                    setState(() => _flockB = f);
                    _loadStats();
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _flockA == null || _flockB == null
                  ? Center(
                      child: Text('Select two batches to compare',
                          style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary)))
                  : _statsA == null || _statsB == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildStats(),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final a = _statsA!;
    final b = _statsB!;

    // Determine overall winner by profit
    final aWins = a.profit >= b.profit;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      children: [
        // ── Winner banner ────────────────────────────────────────────────
        if (a.totalSales > 0 || b.totalSales > 0)
          _WinnerBanner(
            winnerName: aWins ? a.flock.name : b.flock.name,
            winnerColor:
                aWins ? AppTheme.primaryColor : AppTheme.secondaryColor,
            profit: aWins ? a.profit : b.profit,
          ),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Column headers ───────────────────────────────────────────────
        _ComparisonHeader(statsA: a, statsB: b),
        const SizedBox(height: AppTheme.spacingMD),

        // ── Metrics ──────────────────────────────────────────────────────
        _ComparisonCard(
          title: 'Financial Performance',
          rows: [
            _ComparisonRow(
              label: 'Total Expenses',
              valueA: CurrencyFormatter.formatCompact(a.totalExpenses),
              valueB: CurrencyFormatter.formatCompact(b.totalExpenses),
              // Lower is better for expenses
              aIsBetter: a.totalExpenses <= b.totalExpenses,
              lowerIsBetter: true,
              hasData: a.totalExpenses > 0 || b.totalExpenses > 0,
            ),
            _ComparisonRow(
              label: 'Total Revenue',
              valueA: CurrencyFormatter.formatCompact(a.totalSales),
              valueB: CurrencyFormatter.formatCompact(b.totalSales),
              aIsBetter: a.totalSales >= b.totalSales,
              lowerIsBetter: false,
              hasData: a.totalSales > 0 || b.totalSales > 0,
            ),
            _ComparisonRow(
              label: 'Net Profit / Loss',
              valueA: CurrencyFormatter.formatProfit(a.profit),
              valueB: CurrencyFormatter.formatProfit(b.profit),
              aIsBetter: a.profit >= b.profit,
              lowerIsBetter: false,
              hasData: a.totalSales > 0 || b.totalSales > 0,
              highlight: true,
            ),
            _ComparisonRow(
              label: 'Profit per Bird',
              valueA: CurrencyFormatter.formatFull(a.profitPerBird),
              valueB: CurrencyFormatter.formatFull(b.profitPerBird),
              aIsBetter: a.profitPerBird >= b.profitPerBird,
              lowerIsBetter: false,
              hasData: a.totalSales > 0 || b.totalSales > 0,
            ),
            _ComparisonRow(
              label: 'Cost Recovery',
              valueA:
                  '${a.recoveryPercentage.toStringAsFixed(1)}%',
              valueB:
                  '${b.recoveryPercentage.toStringAsFixed(1)}%',
              aIsBetter:
                  a.recoveryPercentage >= b.recoveryPercentage,
              lowerIsBetter: false,
              hasData: a.totalExpenses > 0 || b.totalExpenses > 0,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        _ComparisonCard(
          title: 'Cost Efficiency',
          rows: [
            _ComparisonRow(
              label: 'All-in Cost per Bird',
              valueA: CurrencyFormatter.formatFull(a.costPerBird),
              valueB: CurrencyFormatter.formatFull(b.costPerBird),
              aIsBetter: a.costPerBird <= b.costPerBird,
              lowerIsBetter: true,
              hasData: a.totalExpenses > 0 || b.totalExpenses > 0,
            ),
            _ComparisonRow(
              label: 'Purchase Cost per Bird',
              valueA: CurrencyFormatter.formatFull(
                  a.flock.costPerBird),
              valueB: CurrencyFormatter.formatFull(
                  b.flock.costPerBird),
              aIsBetter:
                  a.flock.costPerBird <= b.flock.costPerBird,
              lowerIsBetter: true,
              hasData: true,
            ),
            _ComparisonRow(
              label: 'Initial Flock Size',
              valueA:
                  '${a.flock.initialBirdCount} birds',
              valueB:
                  '${b.flock.initialBirdCount} birds',
              aIsBetter: a.flock.initialBirdCount >=
                  b.flock.initialBirdCount,
              lowerIsBetter: false,
              hasData: true,
              neutral: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        _ComparisonCard(
          title: 'Flock Health',
          rows: [
            _ComparisonRow(
              label: 'Mortality Rate',
              valueA:
                  '${a.mortalityRate.toStringAsFixed(1)}%',
              valueB:
                  '${b.mortalityRate.toStringAsFixed(1)}%',
              aIsBetter: a.mortalityRate <= b.mortalityRate,
              lowerIsBetter: true,
              hasData: a.mortalityCount > 0 || b.mortalityCount > 0,
            ),
            _ComparisonRow(
              label: 'Total Deaths',
              valueA: '${a.mortalityCount} birds',
              valueB: '${b.mortalityCount} birds',
              aIsBetter: a.mortalityCount <= b.mortalityCount,
              lowerIsBetter: true,
              hasData: true,
            ),
            _ComparisonRow(
              label: 'Current Birds',
              valueA: '${a.flock.birdCount} birds',
              valueB: '${b.flock.birdCount} birds',
              aIsBetter:
                  a.flock.birdCount >= b.flock.birdCount,
              lowerIsBetter: false,
              hasData: true,
              neutral: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),

        _ComparisonCard(
          title: 'Feed & Growth',
          rows: [
            _ComparisonRow(
              label: 'Feed Conversion Ratio',
              valueA: a.fcr > 0
                  ? a.fcr.toStringAsFixed(2)
                  : 'No data',
              valueB: b.fcr > 0
                  ? b.fcr.toStringAsFixed(2)
                  : 'No data',
              aIsBetter: a.fcr > 0 && b.fcr > 0
                  ? a.fcr <= b.fcr
                  : a.fcr > 0,
              lowerIsBetter: true,
              hasData: a.fcr > 0 || b.fcr > 0,
            ),
            _ComparisonRow(
              label: 'Days Active',
              valueA: '${a.durationDays} days',
              valueB: '${b.durationDays} days',
              aIsBetter: true,
              lowerIsBetter: false,
              hasData: true,
              neutral: true,
            ),
            _ComparisonRow(
              label: 'Records Logged',
              valueA: '${a.recordCount} days',
              valueB: '${b.recordCount} days',
              aIsBetter:
                  a.recordCount >= b.recordCount,
              lowerIsBetter: false,
              hasData: true,
              neutral: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingLG),

        // ── Insight summary ──────────────────────────────────────────────
        _InsightSummary(statsA: a, statsB: b),
        const SizedBox(height: AppTheme.spacingLG),
      ],
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _BatchStats {
  final Flock flock;
  final double totalExpenses;
  final double totalSales;
  final double profit;
  final double profitPerBird;
  final double costPerBird;
  final double mortalityRate;
  final int mortalityCount;
  final double recoveryPercentage;
  final double fcr;
  final int durationDays;
  final int recordCount;

  const _BatchStats({
    required this.flock,
    required this.totalExpenses,
    required this.totalSales,
    required this.profit,
    required this.profitPerBird,
    required this.costPerBird,
    required this.mortalityRate,
    required this.mortalityCount,
    required this.recoveryPercentage,
    required this.fcr,
    required this.durationDays,
    required this.recordCount,
  });
}

// ─── Winner Banner ────────────────────────────────────────────────────────────

class _WinnerBanner extends StatelessWidget {
  final String winnerName;
  final Color winnerColor;
  final double profit;

  const _WinnerBanner({
    required this.winnerName,
    required this.winnerColor,
    required this.profit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            winnerColor,
            winnerColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Better Performing Batch',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white70),
                ),
                Text(
                  winnerName,
                  style: AppTheme.headingSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (profit > 0)
                  Text(
                    'Profit: ${CurrencyFormatter.formatCompact(profit)}',
                    style: AppTheme.bodySmall
                        .copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comparison Header ────────────────────────────────────────────────────────

class _ComparisonHeader extends StatelessWidget {
  final _BatchStats statsA;
  final _BatchStats statsB;

  const _ComparisonHeader(
      {required this.statsA, required this.statsB});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 140),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              statsA.flock.name,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              statsB.flock.name,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Comparison Card ──────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final String title;
  final List<_ComparisonRow> rows;

  const _ComparisonCard({
    required this.title,
    required this.rows,
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
          const SizedBox(height: AppTheme.spacingMD),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(
                    bottom: AppTheme.spacingSM),
                child: row,
              )),
        ],
      ),
    );
  }
}

// ─── Comparison Row ───────────────────────────────────────────────────────────

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String valueA;
  final String valueB;
  final bool aIsBetter;
  final bool lowerIsBetter;
  final bool hasData;
  final bool highlight;
  final bool neutral;

  const _ComparisonRow({
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.aIsBetter,
    required this.lowerIsBetter,
    required this.hasData,
    this.highlight = false,
    this.neutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorA = neutral || !hasData
        ? AppTheme.textPrimary
        : aIsBetter
            ? AppTheme.successColor
            : AppTheme.errorColor;

    final colorB = neutral || !hasData
        ? AppTheme.textPrimary
        : !aIsBetter
            ? AppTheme.successColor
            : AppTheme.errorColor;

    return Container(
      padding: highlight
          ? const EdgeInsets.symmetric(
              vertical: 6, horizontal: 8)
          : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSM),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: highlight
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!neutral && hasData && aIsBetter)
                  const Icon(Icons.arrow_upward,
                      size: 12, color: AppTheme.successColor),
                Text(
                  valueA,
                  style: AppTheme.bodySmall.copyWith(
                    color: colorA,
                    fontWeight: highlight || (!neutral && aIsBetter)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!neutral && hasData && !aIsBetter)
                  const Icon(Icons.arrow_upward,
                      size: 12, color: AppTheme.successColor),
                Text(
                  valueB,
                  style: AppTheme.bodySmall.copyWith(
                    color: colorB,
                    fontWeight:
                        highlight || (!neutral && !aIsBetter)
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flock Selector ───────────────────────────────────────────────────────────

class _FlockSelector extends StatelessWidget {
  final String label;
  final Flock? selected;
  final List<Flock> flocks;
  final Color color;
  final ValueChanged<Flock> onChanged;

  const _FlockSelector({
    required this.label,
    required this.selected,
    required this.flocks,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: DropdownButton<Flock>(
            value: selected,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: AppTheme.bodySmall
                .copyWith(color: AppTheme.textPrimary),
            hint: Text('Select batch',
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary)),
            items: flocks
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(
                        f.name,
                        style: AppTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (f) => f != null ? onChanged(f) : null,
          ),
        ),
      ],
    );
  }
}

// ─── Insight Summary ──────────────────────────────────────────────────────────

class _InsightSummary extends StatelessWidget {
  final _BatchStats statsA;
  final _BatchStats statsB;

  const _InsightSummary(
      {required this.statsA, required this.statsB});

  @override
  Widget build(BuildContext context) {
    final insights = <String>[];

    // Profit insight
    if (statsA.profit != 0 || statsB.profit != 0) {
      final diff = (statsA.profit - statsB.profit).abs();
      final better =
          statsA.profit >= statsB.profit ? statsA : statsB;
      final worse =
          statsA.profit >= statsB.profit ? statsB : statsA;
      if (diff > 0) {
        insights.add(
          '${better.flock.name} made ${CurrencyFormatter.formatCompact(diff)} '
          'more profit than ${worse.flock.name}.',
        );
      }
    }

    // Mortality insight
    if (statsA.mortalityRate != statsB.mortalityRate) {
      final better = statsA.mortalityRate <= statsB.mortalityRate
          ? statsA
          : statsB;
      final worse = statsA.mortalityRate <= statsB.mortalityRate
          ? statsB
          : statsA;
      insights.add(
        '${better.flock.name} had better survival — '
        '${better.mortalityRate.toStringAsFixed(1)}% mortality vs '
        '${worse.mortalityRate.toStringAsFixed(1)}% for ${worse.flock.name}.',
      );
    }

    // Cost per bird insight
    if (statsA.costPerBird > 0 && statsB.costPerBird > 0) {
      final diff =
          (statsA.costPerBird - statsB.costPerBird).abs();
      if (diff > 100) {
        final cheaper = statsA.costPerBird <= statsB.costPerBird
            ? statsA
            : statsB;
        insights.add(
          '${cheaper.flock.name} cost ${CurrencyFormatter.formatFull(diff)} '
          'less per bird to raise.',
        );
      }
    }

    // FCR insight
    if (statsA.fcr > 0 && statsB.fcr > 0) {
      final better =
          statsA.fcr <= statsB.fcr ? statsA : statsB;
      final worse =
          statsA.fcr <= statsB.fcr ? statsB : statsA;
      insights.add(
        '${better.flock.name} converted feed more efficiently '
        '(FCR ${better.fcr.toStringAsFixed(2)} vs ${worse.fcr.toStringAsFixed(2)}).',
      );
    }

    if (insights.isEmpty) {
      insights.add(
          'Add financial records to both batches to see detailed insights.');
    }

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: AppTheme.spacingSM),
              Text('Key Insights', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(
                  bottom: AppTheme.spacingSM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Text(insight,
                        style: AppTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}