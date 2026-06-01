import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'flock_workspace_screen.dart';

typedef CreateFlockCallback = void Function(BuildContext context);
typedef EditFlockCallback = void Function(BuildContext context, Flock flock);
typedef DeleteFlockCallback = void Function(BuildContext context, Flock flock);

class FlocksScreen extends StatefulWidget {
  final CreateFlockCallback onCreateFlock;
  final EditFlockCallback onEditFlock;
  final DeleteFlockCallback onDeleteFlock;

  const FlocksScreen({
    super.key,
    required this.onCreateFlock,
    required this.onEditFlock,
    required this.onDeleteFlock,
  });

  @override
  State<FlocksScreen> createState() => _FlocksScreenState();
}

class _FlocksScreenState extends State<FlocksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFlockDetails();
    });
  }

  Future<void> _loadFlockDetails() async {
    final flockProvider = context.read<FlockProvider>();
    final recordProvider = context.read<DailyRecordProvider>();
    final financeProvider = context.read<FinanceProvider>();

    if (flockProvider.flocks.isEmpty) {
      await flockProvider.loadFlocks();
    }
    final flockIds = flockProvider.flocks.map((flock) => flock.id).toList();
    if (flockIds.isNotEmpty) {
      await recordProvider.loadLatestRecords(flockIds);
      await recordProvider.loadMortalityTotals(flockIds);
    }
    await financeProvider.loadFarmFinanceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Flocks'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFlockDetails,
        child: Consumer3<FlockProvider, DailyRecordProvider, FinanceProvider>(
          builder:
              (context, flockProvider, recordProvider, financeProvider, _) {
            if (flockProvider.flocks.isEmpty) {
              return _buildEmptyState(context);
            }

            return GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                MediaQuery.paddingOf(context).bottom + 56 + AppTheme.spacingLG,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnCountForWidth(
                  MediaQuery.sizeOf(context).width,
                ),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 300,
              ),
              itemCount: flockProvider.flocks.length,
              itemBuilder: (context, index) {
                final flock = flockProvider.flocks[index];
                final latest = recordProvider.latestRecords[flock.id];
                final isSelected = flockProvider.selectedFlock?.id == flock.id;
                final mortalityTotal =
                    recordProvider.mortalityTotalFor(flock.id);
                final breakEvenPerBird =
    financeProvider.breakEvenPerBirdForFlock(
  flockId: flock.id,
  currentBirds: flock.birdCount,
);
                final recoveryPercentage =
                    financeProvider.recoveryPercentageForFlock(flock.id);

                return _FlockGridCard(
                  flock: flock,
                  latestRecord: latest,
                  isSelected: isSelected,
                  mortalityTotal: mortalityTotal,
                  breakEvenPerBird: breakEvenPerBird,
                  breakEvenDisplay:
    financeProvider.breakEvenPerBirdForFlockDisplay(
  flockId: flock.id,
  currentBirds: flock.birdCount,
),
                  recoveryPercentage: recoveryPercentage,
                  onTap: () => _openFlockWorkspace(context, flock),
                  onEdit: () => widget.onEditFlock(context, flock),
                  onDelete: () => widget.onDeleteFlock(context, flock),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'flocks_fab',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => widget.onCreateFlock(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  int _columnCountForWidth(double width) {
    if (width >= 900) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        Icon(Icons.pets,
            size: 80, color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        const SizedBox(height: AppTheme.spacingMD),
        Text(
          'No Flocks Yet',
          style: AppTheme.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Text(
          'Create your first flock to start tracking batches.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingLG),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => widget.onCreateFlock(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Flock'),
            style: AppTheme.primaryButtonStyle,
          ),
        ),
      ],
    );
  }

  void _openFlockWorkspace(BuildContext context, Flock flock) {
    context.read<FlockProvider>().selectFlock(flock);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlockWorkspaceScreen(flock: flock),
      ),
    );
  }
}

Color _getStageColor(String stage) {
  switch (stage.toLowerCase()) {
    case 'brooding':
    case 'chick':
      return Colors.blue;
    case 'growing':
    case 'pullet':
    case 'grower':
      return Colors.green;
    case 'finishing':
    case 'laying':
      return Colors.orange;
    case 'ready for harvest':
      return Colors.deepOrange;
    case 'spent':
      return Colors.grey;
    default:
      return AppTheme.textSecondary;
  }
}

class _FlockGridCard extends StatelessWidget {
  final Flock flock;
  final DailyRecord? latestRecord;
  final bool isSelected;
  final int mortalityTotal;
  final double breakEvenPerBird;
  final String breakEvenDisplay;
  final double recoveryPercentage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlockGridCard({
    required this.flock,
    required this.latestRecord,
    required this.isSelected,
    required this.mortalityTotal,
    required this.breakEvenPerBird,
    required this.breakEvenDisplay,
    required this.recoveryPercentage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nextVax = flock.nextVaccination;
    final daysToNext =
        nextVax != null ? nextVax.daysUntil(flock.currentAgeDays) : null;
    final costRecovered = recoveryPercentage >= 100;
    final mortalityBase = flock.initialBirdCount;
    final mortalityPercentage =
        mortalityBase > 0 ? mortalityTotal / mortalityBase * 100 : 0.0;
    final mortalityLoss = mortalityTotal * breakEvenPerBird;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: isSelected
              ? Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  width: 1,
                )
              : null,
          boxShadow: const [AppTheme.shadowMD],
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    flock.name,
                    style: AppTheme.bodyLarge
                        .copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: flock.status == FlockStatus.active
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    flock.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SELECTED',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text('${flock.birdCount} ${flock.type}', style: AppTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text(
                  flock.ageDisplay,
                  style:
                      AppTheme.bodySmall.copyWith(color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStageColor(flock.productionStage)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                flock.productionStage,
                style: AppTheme.bodySmall.copyWith(
                  color: _getStageColor(flock.productionStage),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (daysToNext != null) ...[
              const SizedBox(height: 6),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysToNext <= 3
                        ? AppTheme.errorColor.withValues(alpha: 0.15)
                        : AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Next vax: ${nextVax!.name} (${daysToNext} day${daysToNext == 1 ? '' : 's'})',
                    style: AppTheme.bodySmall.copyWith(
                      color: daysToNext <= 3
                          ? AppTheme.errorColor
                          : AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
            const Divider(height: AppTheme.spacingLG),
            if (latestRecord != null) ...[
              if (flock.isLayer) ...[
                _StatRow(
                  icon: Icons.egg,
                  label: 'Eggs today',
                  value: '${latestRecord!.eggsCollected ?? 0}',
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 4),
              ],
              _StatRow(
                icon: Icons.warning,
                label: 'Mortality',
                value: mortalityTotal > 0
                    ? '${mortalityPercentage.toStringAsFixed(1)}%'
                    : '0%',
                color: mortalityTotal > 0
                    ? AppTheme.errorColor
                    : AppTheme.successColor,
              ),
            ] else ...[
              Text(
                'No records yet',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 4),
            _StatRow(
              icon: costRecovered ? Icons.check_circle : Icons.price_check,
              label: costRecovered ? 'Cost recovered' : 'Break-even',
              value: costRecovered
                  ? '${recoveryPercentage.toStringAsFixed(0)}%'
                  : breakEvenDisplay,
              color:
                  costRecovered ? AppTheme.successColor : AppTheme.accentColor,
            ),
            if (!costRecovered)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Recovered ${recoveryPercentage.toStringAsFixed(0)}%',
                  style: AppTheme.bodySmall.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (mortalityTotal > 0 && breakEvenPerBird > 0) ...[
              const SizedBox(height: 4),
              _StatRow(
                icon: Icons.money_off,
                label: 'Mortality loss',
                value: CurrencyFormatter.formatCompact(mortalityLoss),
                color: AppTheme.errorColor,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Flock actions',
                  icon: Icon(Icons.more_horiz, color: AppTheme.textSecondary),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          const Text('Edit flock'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AppTheme.errorColor),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            'Delete flock',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTheme.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
