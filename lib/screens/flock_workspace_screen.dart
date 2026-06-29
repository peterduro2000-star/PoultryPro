import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'batch_comparison_screen.dart';
import '../widgets/share_performance_card.dart';
import '../models/daily_record.dart';
import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alerts_panel.dart';
import '../services/database_service.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../providers/license_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'finance_screen.dart';
import 'health_screen.dart';
import 'records_screen.dart';
import 'stock_screen.dart';

class FlockWorkspaceScreen extends StatefulWidget {
  final Flock flock;

  const FlockWorkspaceScreen({
    super.key,
    required this.flock,
  });

  @override
  State<FlockWorkspaceScreen> createState() => _FlockWorkspaceScreenState();
}

class _FlockWorkspaceScreenState extends State<FlockWorkspaceScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  static final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkspaceData();
    });
  }

  Future<void> _loadWorkspaceData() async {
    if (!mounted) return;
    final flock = _currentFlock(context);
    final dailyRecordProvider = context.read<DailyRecordProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final alertsProvider = context.read<AlertsProvider>();

    await dailyRecordProvider.loadLatestRecords([flock.id]);
    await dailyRecordProvider.loadMortalityTotals([flock.id]);
    await financeProvider.loadFarmFinanceData();

    // Refresh alerts for this flock after records/finance are loaded
    final records = await DatabaseService().getDailyRecordsByFlock(flock.id);
    if (!mounted) return;

    final licenseProvider = context.read<LicenseProvider>();
    final recovery = financeProvider.recoveryPercentageForFlock(flock.id);
    await alertsProvider.refreshAlertsForFlock(
          flock: flock,
          records: records,
          recoveryPercentage: recovery,
          isPro: licenseProvider.isPro,
        );
  }

  Flock _currentFlock(BuildContext context) {
    final provider = context.read<FlockProvider>();
    return provider.flocks.firstWhere(
      (f) => f.id == widget.flock.id,
      orElse: () => widget.flock,
    );
  }

  // ── Bottom nav pushes module screens; each screen reads
  //    selected flock from FlockProvider — no flock: param needed.
  void _onBottomNavTapped(int index) {
    final screens = [
      const RecordsScreen(),
      const FinanceScreen(),
      const HealthScreen(),
      const StockScreen(),
    ];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screens[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<FlockProvider, DailyRecordProvider, FinanceProvider>(
      builder: (context, flockProvider, recordProvider, financeProvider, _) {
        final flock = flockProvider.flocks.firstWhere(
          (item) => item.id == widget.flock.id,
          orElse: () => widget.flock,
        );

        // Ensure this flock is the selected one so module screens
        // load the right data when pushed from here.
        if (flockProvider.selectedFlock?.id != flock.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            flockProvider.selectFlock(flock);
          });
        }

        final mortalityTotal = recordProvider.mortalityTotalFor(flock.id);
        final recovery = financeProvider.recoveryPercentageForFlock(flock.id);

        // Use the updated FinanceProvider signatures (no initialBirds/totalMortality)
        final breakEven = financeProvider.breakEvenPerBirdForFlockDisplay(
          flockId: flock.id,
          currentBirds: flock.birdCount,
        );
        final breakEvenValue = financeProvider.breakEvenPerBirdForFlock(
          flockId: flock.id,
          currentBirds: flock.birdCount,
        );

        final soldBirds = financeProvider
            .farmSalesForFlock(flock.id)
            .where((sale) =>
                sale.saleType.toLowerCase() == 'birds' ||
                sale.unit.toLowerCase() == 'birds')
            .fold<int>(0, (sum, sale) => sum + sale.quantity.toInt());
        final isSoldOut = flock.birdCount == 0 && soldBirds > 0;
        final latest = recordProvider.latestFor(flock.id);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(flock.name),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share results',
                onPressed: () => _shareResults(
                  flock: flock,
                  financeProvider: financeProvider,
                  mortalityTotal: mortalityTotal,
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadWorkspaceData,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                MediaQuery.paddingOf(context).bottom + AppTheme.spacingLG,
              ),
              children: [
                _buildHeader(flock, isSoldOut: isSoldOut),
                const SizedBox(height: AppTheme.spacingMD),
                AlertsPanel(flockId: flock.id),
                const SizedBox(height: AppTheme.spacingSM),
                _buildSnapshotCard(
                  flock: flock,
                  mortalityTotal: mortalityTotal,
                  recoveryPercentage: recovery,
                  breakEvenDisplay: breakEven,
                  breakEvenValue: breakEvenValue,
                  isSoldOut: isSoldOut,
                ),
                const SizedBox(height: AppTheme.spacingLG),
                _buildTodayActivity(flock, latest),
                const SizedBox(height: AppTheme.spacingLG),
                _buildInsightsCard(latest, recovery, breakEven),
                const SizedBox(height: AppTheme.spacingLG),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() => _currentIndex = index);
                  _onBottomNavTapped(index);
                },
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: Colors.grey.shade600,
                backgroundColor: Colors.white,
                elevation: 0,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.assignment_outlined),
                    activeIcon: Icon(Icons.assignment),
                    label: 'Records',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.payments_outlined),
                    activeIcon: Icon(Icons.payments),
                    label: 'Finance',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite_outline),
                    activeIcon: Icon(Icons.favorite),
                    label: 'Health',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.inventory_2_outlined),
                    activeIcon: Icon(Icons.inventory_2),
                    label: 'Stock',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareResults({
    required Flock flock,
    required FinanceProvider financeProvider,
    required int mortalityTotal,
  }) async {
    final totalExpenses = financeProvider.totalExpensesForFlock(flock.id);
    final totalSales = financeProvider.totalSalesForFlock(flock.id);
    final profit = totalSales - totalExpenses;
    final costPerBird = flock.birdCount > 0
        ? totalExpenses / flock.birdCount
        : flock.costPerBird;
    final mortalityRate = flock.initialBirdCount > 0
        ? mortalityTotal / flock.initialBirdCount * 100
        : 0.0;
    final breakEven = financeProvider.breakEvenPerBirdForFlockDisplay(
      flockId: flock.id,
      currentBirds: flock.birdCount,
    );
    final recovery = financeProvider.recoveryPercentageForFlock(flock.id);

    try {
      final imageBytes = await _screenshotController.captureFromLongWidget(
        SharePerformanceCard(
          flock: flock,
          totalExpenses: totalExpenses,
          totalSales: totalSales,
          profit: profit,
          mortalityRate: mortalityRate,
          costPerBird: costPerBird,
          breakEvenDisplay: breakEven,
          recoveryPercentage: recovery,
        ),
        pixelRatio: 2.0,
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/poultrypro_${flock.name.replaceAll(' ', '_')}.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${flock.name} batch results from PoultryPro 🐔',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildHeader(Flock flock, {required bool isSoldOut}) {
    final next = flock.nextVaccination;
    final daysLeft = next?.daysUntil(flock.currentAgeDays);
    final statusLabel = isSoldOut ? 'SOLD OUT' : flock.status.toUpperCase();
    final stageText = isSoldOut ? 'Completed' : flock.ageDisplay;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(Icons.groups, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flock.name,
                      style: AppTheme.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${flock.type} • ${_numberFormat.format(flock.birdCount)} birds • $stageText',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSoldOut
                      ? AppTheme.infoColor
                      : flock.status == FlockStatus.active
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (!isSoldOut && next != null && daysLeft != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${next.name} due in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSnapshotCard({
    required Flock flock,
    required int mortalityTotal,
    required double recoveryPercentage,
    required String breakEvenDisplay,
    required double breakEvenValue,
    required bool isSoldOut,
  }) {
    final mortalityRate = flock.initialBirdCount > 0
        ? mortalityTotal / flock.initialBirdCount * 100
        : 0.0;
    final mortalityLoss = mortalityTotal * breakEvenValue;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Flock Snapshot', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          Wrap(
            spacing: AppTheme.spacingMD,
            runSpacing: AppTheme.spacingMD,
            children: [
              _SnapshotItem('Current Birds', _numberFormat.format(flock.birdCount)),
              _SnapshotItem(
                  'Initial Birds', _numberFormat.format(flock.initialBirdCount)),
              _SnapshotItem(
                  'Status', isSoldOut ? 'Completed' : flock.ageDisplay),
              _SnapshotItem(
                  'Mortality', '${mortalityRate.toStringAsFixed(1)}%'),
              _SnapshotItem(
                  'Recovered', '${recoveryPercentage.toStringAsFixed(0)}%'),
              _SnapshotItem('Break-even', breakEvenDisplay),
              if (mortalityTotal > 0 && breakEvenValue > 0)
                _SnapshotItem(
                  'Mortality loss',
                  CurrencyFormatter.formatFull(mortalityLoss),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayActivity(Flock flock, DailyRecord? latest) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Flock Activity", style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          if (latest == null)
            Text(
              'No records yet today.',
              style: AppTheme.bodyMedium
                  .copyWith(color: AppTheme.textSecondary),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _SnapshotItem(
                    'Mortality',
                    _numberFormat.format(latest.mortalityCount ?? 0),
                  ),
                ),
                if (flock.isLayer)
                  Expanded(
                    child: _SnapshotItem(
                      'Eggs',
                      _numberFormat.format(latest.eggsCollected ?? 0),
                    ),
                  ),
                Expanded(
                  child: _SnapshotItem(
                    'Feed kg',
                    (latest.feedGiven ?? 0).toStringAsFixed(1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(
    DailyRecord? latest,
    double recoveryPercentage,
    String breakEvenDisplay,
  ) {
    final flockCount = context.read<FlockProvider>().flocks.length;
    final isPro = context.read<LicenseProvider>().isPro;
    final message = latest == null
        ? 'Start recording daily activity to see flock insights.'
        : 'Recovered ${recoveryPercentage.toStringAsFixed(0)}%. '
            'Break-even is $breakEvenDisplay per bird.';

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spacingSM),
              Text('Flock Insights', style: AppTheme.headingSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            message,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
          ),
          if (isPro && flockCount >= 2) ...[
            const SizedBox(height: AppTheme.spacingMD),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BatchComparisonScreen(),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Compare with another batch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingSM),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Snapshot Item ────────────────────────────────────────────────────────────

class _SnapshotItem extends StatelessWidget {
  final String label;
  final String value;

  const _SnapshotItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}