import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';
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

  Flock _currentFlock(BuildContext context) {
    final provider = context.read<FlockProvider>();
    return provider.flocks.firstWhere(
      (flock) => flock.id == widget.flock.id,
      orElse: () => widget.flock,
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
        );
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
                _buildHeader(flock),
                const SizedBox(height: AppTheme.spacingLG),
                _buildSnapshotCard(
                  flock: flock,
                  mortalityTotal: mortalityTotal,
                  recoveryPercentage: recovery,
                  breakEvenDisplay: breakEven,
                ),
                const SizedBox(height: AppTheme.spacingLG),
                _buildQuickActions(),
                const SizedBox(height: AppTheme.spacingLG),
                _buildTodayActivity(latest),
                const SizedBox(height: AppTheme.spacingLG),
                _buildInsightsCard(latest, recovery, breakEven),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Flock flock) {
    final next = flock.nextVaccination;
    final daysLeft = next?.daysUntil(flock.currentAgeDays);

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
                  color: AppTheme.primaryColor.withOpacity(0.1),
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
                      '${flock.type} • ${flock.birdCount} birds • ${flock.ageDisplay}',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: flock.status == 'active'
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  flock.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (next != null && daysLeft != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.12),
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
  }) {
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
              _SnapshotItem('Age', flock.ageDisplay),
              _SnapshotItem('Mortality', mortalityTotal.toString()),
              _SnapshotItem(
                  'Recovered', '${recoveryPercentage.toStringAsFixed(0)}%'),
              _SnapshotItem('Break-even', breakEvenDisplay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: AppTheme.headingSmall),
        const SizedBox(height: AppTheme.spacingMD),
        _ModuleCard(
          icon: Icons.assignment_outlined,
          title: 'Daily Records',
          subtitle: 'Record feed, mortality, eggs, and daily activity',
          onTap: () => _openModule(const RecordsScreen()),
        ),
        _ModuleCard(
          icon: Icons.payments_outlined,
          title: 'Finance',
          subtitle: 'Manage expenses, sales, break-even, and recovery',
          onTap: () => _openModule(const FinanceScreen()),
        ),
        _ModuleCard(
          icon: Icons.favorite_outline,
          title: 'Health',
          subtitle: 'Track health events and vaccination schedule',
          onTap: () => _openModule(const HealthScreen()),
        ),
        _ModuleCard(
          icon: Icons.inventory_2_outlined,
          title: 'Stock / Feed',
          subtitle: 'Manage feed and farm stock for this flock',
          onTap: () => _openModule(const StockScreen()),
        ),
        _ModuleCard(
          icon: Icons.vaccines_outlined,
          title: 'Vaccination Schedule',
          subtitle: 'Review vaccination activity for this flock',
          onTap: () => _openModule(const HealthScreen()),
        ),
      ],
    );
  }

  void _openModule(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildTodayActivity(DailyRecord? latest) {
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

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
