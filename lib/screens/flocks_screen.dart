import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/flock_grid_card.dart';
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

                return FlockGridCard(
                  flock: flock,
                  showDetailedStats: true,
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


