import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkspaceData();
    });
  }

  Future<void> _loadWorkspaceData() async {
    final flock = _currentFlock(context);
    await context.read<DailyRecordProvider>().loadLatestRecords([flock.id]);
    await context.read<DailyRecordProvider>().loadMortalityTotals([flock.id]);
    await context.read<FinanceProvider>().loadFarmFinanceData();
  }

  int _currentIndex = 0; // For bottom nav highlight

  Flock _currentFlock(BuildContext context) {
    final provider = context.read<FlockProvider>();
    return provider.flocks.firstWhere(
      (flock) => flock.id == widget.flock.id,
      orElse: () => widget.flock,
    );
  }

  void _onBottomNavTapped(int index) {
    final screens = [
      RecordsScreen(flock: widget.flock),
      FinanceScreen(flock: widget.flock),
      HealthScreen(flock: widget.flock),
      StockScreen(flock: widget.flock),
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
        final mortalityTotal = recordProvider.mortalityTotalFor(flock.id);
        final recovery = financeProvider.recoveryPercentageForFlock(flock.id);
        final breakEven = financeProvider.breakEvenPerBirdForFlockDisplay(
          flockId: flock.id,
          currentBirds: flock.birdCount,
          initialBirds: flock.initialBirdCount,
          totalMortality: mortalityTotal,
        );
        final breakEvenValue = financeProvider.breakEvenPerBirdForFlock(
          flockId: flock.id,
          currentBirds: flock.birdCount,
          initialBirds: flock.initialBirdCount,
          totalMortality: mortalityTotal,
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
                const SizedBox(height: AppTheme.spacingLG),
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
                  color: Colors.black.withOpacity(0.08),
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
                      '${flock.type} • ${flock.birdCount} birds • $stageText',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              _SnapshotItem('Current Birds', flock.birdCount.toString()),
              _SnapshotItem('Initial Birds', flock.initialBirdCount.toString()),
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
                  CurrencyFormatter.formatCompact(mortalityLoss),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Flock flock) {
    final actions = [
      _QuickActionData(
        icon: Icons.assignment_outlined,
        title: 'Records',
        onTap: () => _openModule(RecordsScreen(flock: flock)),
      ),
      _QuickActionData(
        icon: Icons.payments_outlined,
        title: 'Finance',
        onTap: () => _openModule(FinanceScreen(flock: flock)),
      ),
      _QuickActionData(
        icon: Icons.favorite_outline,
        title: 'Health',
        onTap: () => _openModule(HealthScreen(flock: flock)),
      ),
      _QuickActionData(
        icon: Icons.inventory_2_outlined,
        title: 'Stock',
        onTap: () => _openModule(StockScreen(flock: flock)),
      ),
    ];

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 5 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppTheme.spacingSM,
                  mainAxisSpacing: AppTheme.spacingSM,
                  childAspectRatio: columns == 5 ? 1.05 : 1.0,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _QuickActionTile(
                    icon: action.icon,
                    title: action.title,
                    onTap: action.onTap,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openModule(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
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
              style:
                  AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _SnapshotItem(
                    'Mortality',
                    (latest.mortalityCount ?? 0).toString(),
                  ),
                ),
                if (flock.isLayer)
                  Expanded(
                    child: _SnapshotItem(
                      'Eggs',
                      (latest.eggsCollected ?? 0).toString(),
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
    final message = latest == null
        ? 'Start recording daily activity to see flock insights.'
        : 'Recovered ${recoveryPercentage.toStringAsFixed(0)}%. Break-even is $breakEvenDisplay per bird.';

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: AppTheme.primaryColor),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flock Insights', style: AppTheme.headingSmall),
                const SizedBox(height: 2),
                Text(
                  message,
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
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _QuickActionData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSM,
            vertical: AppTheme.spacingSM,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
