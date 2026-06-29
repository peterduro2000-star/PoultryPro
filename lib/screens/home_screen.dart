import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/flock.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/flock_provider.dart';
import '../providers/license_provider.dart';
import '../screens/batch_comparison_screen.dart';
import '../screens/flock_workspace_screen.dart';
import '../screens/upgrade_screen.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../widgets/dashboard_summary_card.dart';
import '../widgets/farm_performance_card.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final flockProvider = context.read<FlockProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final recordProvider = context.read<DailyRecordProvider>();

    try {
      await flockProvider.loadFlocks();
      if (!mounted) return;
      setState(() => _initialLoadComplete = true);
      await financeProvider.loadFarmFinanceData();
      final flocks = flockProvider.flocks;
      if (flocks.isNotEmpty) {
        final flockIds = flocks.map((f) => f.id).toList();
        await recordProvider.loadLatestRecords(flockIds);
        await recordProvider.loadMortalityTotals(flockIds);
      }
    } catch (e) {
      if (mounted) setState(() => _initialLoadComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Poultry Pro'),
        elevation: 0,
      ),
      body: Consumer<FlockProvider>(
        builder: (context, flockProvider, _) {
          if (!_initialLoadComplete && flockProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (flockProvider.error != null &&
              flockProvider.flocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorColor
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text('Failed to load flocks',
                      style: AppTheme.headingMedium),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(flockProvider.error!,
                      style: AppTheme.bodyMedium
                          .copyWith(color: AppTheme.errorColor),
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppTheme.spacingLG),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: AppTheme.primaryButtonStyle,
                  ),
                ],
              ),
            );
          }

          if (flockProvider.flocks.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              final flockProvider = context.read<FlockProvider>();
              final financeProvider = context.read<FinanceProvider>();
              final recordProvider = context.read<DailyRecordProvider>();
              await flockProvider.loadFlocks();
              await financeProvider.loadFarmFinanceData();
              final flocks = flockProvider.flocks;
              if (flocks.isNotEmpty) {
                final ids = flocks.map((f) => f.id).toList();
                await recordProvider.loadLatestRecords(ids);
                await recordProvider.loadMortalityTotals(ids);
              }
            },
            child: Consumer<DailyRecordProvider>(
              builder: (context, recordProvider, _) {
                final isPro = context.read<LicenseProvider>().isPro;
                return ListView(
                  padding:
                      const EdgeInsets.all(AppTheme.spacingMD),
                  children: [
                    // Selected flock banner
                    if (flockProvider.selectedFlock != null)
                      _SelectedFlockBanner(
                          flock: flockProvider.selectedFlock!),
                    if (flockProvider.selectedFlock != null)
                      const SizedBox(height: AppTheme.spacingMD),

                    // Vaccination banner
                    if (flockProvider.selectedFlock != null &&
                        flockProvider.selectedFlock!
                                .nextVaccination !=
                            null)
                      _VaccinationBanner(
                          flock: flockProvider.selectedFlock!),

                    // Farm performance card
                    const FarmPerformanceCard(),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Dashboard summary + compare button
                    DashboardSummaryCard(
                      onCompareTap: isPro && flockProvider.flocks.length >= 2
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BatchComparisonScreen(),
                                ),
                              )
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Flocks header
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Flocks',
                            style: AppTheme.headingSmall),
                        Text('Tap a flockto open',
                            style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Flock grid
                    Consumer<FinanceProvider>(
                      builder: (context, financeProvider, _) =>
                          _buildFlockGrid(
                        flockProvider,
                        recordProvider.latestRecords,
                        financeProvider,
                        recordProvider,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Today's summary
                    _buildTodaySummary(recordProvider),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_fab',
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: () async {
          final flockProvider = context.read<FlockProvider>();
          final isPro = context.read<LicenseProvider>().isPro;

          if (!isPro && flockProvider.flocks.length >= 1) {
            _showProFlockGate(context);
            return;
          }

          _showCreateFlockDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: AppTheme.spacingMD),
          Text('No Flocks Yet', style: AppTheme.headingMedium),
          const SizedBox(height: AppTheme.spacingSM),
          Text('Create your first flock to get started',
              style: AppTheme.bodyMedium),
          const SizedBox(height: AppTheme.spacingLG),
          ElevatedButton.icon(
            onPressed: () => _showCreateFlockDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Flock'),
            style: AppTheme.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildFlockGrid(
    FlockProvider flockProvider,
    Map<String, DailyRecord?> latestRecords,
    FinanceProvider financeProvider,
    DailyRecordProvider recordProvider,
  ) {
    final flocks = flockProvider.flocks;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: flocks.length,
      itemBuilder: (context, index) {
        final flock = flocks[index];
        final latest = latestRecords[flock.id];
        final isSelected =
            flockProvider.selectedFlock?.id == flock.id;
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
          mortalityTotal: recordProvider.mortalityTotalFor(flock.id),
          breakEvenPerBird: breakEvenPerBird,
          breakEvenDisplay:
              financeProvider.breakEvenPerBirdForFlockDisplay(
            flockId: flock.id,
            currentBirds: flock.birdCount,
          ),
          recoveryPercentage: recoveryPercentage,
          onTap: () {
            flockProvider.selectFlock(flock);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FlockWorkspaceScreen(flock: flock),
              ),
            );
          },
          onEdit: () => _showEditFlockDialog(context, flock),
          onDelete: () => _confirmDelete(context, flock),
        );
      },
    );
  }

  Widget _buildTodaySummary(DailyRecordProvider recordProvider) {
    final records = recordProvider.latestRecords.values
        .whereType<DailyRecord>()
        .toList();
    final totalEggs =
        records.fold<int>(0, (s, r) => s + (r.eggsCollected ?? 0));
    final totalDeaths =
        records.fold<int>(0, (s, r) => s + (r.mortalityCount ?? 0));
    final totalFeed =
        records.fold<double>(0, (s, r) => s + (r.feedGiven ?? 0));
    final totalWater =
        records.fold<double>(0, (s, r) => s + (r.waterGiven ?? 0));
    final hasData = records.isNotEmpty;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Summary",
                  style: AppTheme.headingSmall),
              Text(
                hasData ? 'All flocks' : 'No records yet',
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (!hasData)
            Center(
              child: Text(
                "Add today's records to see summary",
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Row(
              children: [
                _TodayStatItem(
                  icon: Icons.egg,
                  label: 'Eggs',
                  value: totalEggs.toString(),
                  color: AppTheme.primaryColor,
                ),
                _TodayStatItem(
                  icon: Icons.warning_amber,
                  label: 'Deaths',
                  value: totalDeaths.toString(),
                  color: totalDeaths > 0
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
                _TodayStatItem(
                  icon: Icons.set_meal,
                  label: 'Feed kg',
                  value: totalFeed.toStringAsFixed(1),
                  color: AppTheme.primaryColor,
                ),
                _TodayStatItem(
                  icon: Icons.water_drop,
                  label: 'Water L',
                  value: totalWater.toStringAsFixed(1),
                  color: Colors.blue,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // removed unused helper: _formatNumber

  Widget _buildAgePreview(DateTime stockDate, int ageAtStocking) {
    final daysSinceStocking =
        DateTime.now().difference(stockDate).inDays;
    final currentAge = ageAtStocking + daysSinceStocking;
    final weeks = currentAge ~/ 7;
    String ageText;
    if (currentAge < 0) {
      ageText = 'Starts in ${-currentAge} days';
    } else if (currentAge < 7) {
      ageText = 'Currently $currentAge days old';
    } else {
      ageText =
          'Currently $weeks weeks old ($currentAge days)';
    }
    return Row(
      children: [
        const Icon(Icons.info_outline,
          size: 14, color: AppTheme.successColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(ageText,
              style: AppTheme.bodySmall
                  .copyWith(color: AppTheme.successColor)),
        ),
      ],
    );
  }

  void _showCreateFlockDialog(BuildContext context) {
    final nameController = TextEditingController();
    final birdCountController = TextEditingController();
    final costPerBirdController = TextEditingController();
    final sourceController = TextEditingController();
    final notesController = TextEditingController();
    final ageAtStockingController =
        TextEditingController(text: '0');

    String selectedType = 'Broilers';
    String? selectedBreed;
    String? selectedHousingType;
    DateTime? selectedDate;
    // expansion state not otherwise observed; no local tracking needed

    String? nameError;
    String? birdCountError;
    String? costPerBirdError;
    String? dateError;

    final typeOptions = [
      'Broilers',
      'Layers',
      'Noiler',
      'Local',
      'Mixed/Other'
    ];
    final breedOptions = [
      'Noiler',
      'Kuroiler',
      'Rhode Island Red',
      'Isa Brown',
      'Ross 308',
      'Cobb 500',
      'Local/Indigenous',
      'Other'
    ];
    final housingOptions = [
      'Deep litter',
      'Battery cage',
      'Free range',
      'Semi-intensive',
      'Other'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppTheme.spacingMD,
            right: AppTheme.spacingMD,
            top: AppTheme.spacingMD,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                AppTheme.spacingMD,
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
                Text('Create New Flock',
                    style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingSM),
                Text('Stock details for your birds',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: AppTheme.spacingLG),
                TextField(
                  controller: nameController,
                  decoration: AppTheme.inputDecoration(
                          'Flock Name *')
                      .copyWith(
                    errorText: nameError,
                    hintText:
                        'e.g., Broiler Batch 1, Layer House A',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration:
                      AppTheme.inputDecoration('Type of Birds *'),
                  items: typeOptions
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setSheetState(
                      () => selectedType = v ?? 'Broilers'),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: birdCountController,
                  decoration: AppTheme.inputDecoration(
                          'Number of Birds *')
                      .copyWith(
                    errorText: birdCountError,
                    hintText: '100, 500, 1000, etc.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: costPerBirdController,
                  decoration: AppTheme.inputDecoration(
                          'Cost per Bird (₦) *')
                      .copyWith(
                    errorText: costPerBirdError,
                    hintText: '800, 1500, 3000, etc.',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: dateError != null
                          ? AppTheme.errorColor
                          : AppTheme.textSecondary
                              .withValues(alpha: 0.3),
                      width: dateError != null ? 2 : 1,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  padding:
                      const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stocking Details *',
                          style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Age of birds when you got them + date you stocked',
                        style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageAtStockingController,
                              decoration:
                                  AppTheme.inputDecoration(
                                          'Age at stocking (days)')
                                      .copyWith(
                                hintText: '0 = day-old chicks',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) =>
                                  setSheetState(() {}),
                            ),
                          ),
                          const SizedBox(
                              width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Date stocked *'
                                      : DateFormatter.format(
                                          selectedDate!
                                              .toIso8601String()
                                              .split('T')
                                              .first),
                                  style: AppTheme.bodySmall
                                      .copyWith(
                                    color: selectedDate == null
                                        ? AppTheme.textSecondary
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: () async {
                                    final picked =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now()
                                          .subtract(const Duration(
                                              days: 365)),
                                      lastDate: DateTime.now().add(
                                          const Duration(days: 30)),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        selectedDate = picked;
                                        dateError = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                      Icons.calendar_today,
                                      size: 16),
                                  label: const Text('Pick date'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        AppTheme.primaryColor,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (selectedDate != null) ...[
                        const SizedBox(height: AppTheme.spacingSM),
                        _buildAgePreview(
                          selectedDate!,
                          int.tryParse(
                                  ageAtStockingController.text) ??
                              0,
                        ),
                      ],
                      if (dateError != null) ...[
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(dateError!,
                            style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.errorColor)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                ExpansionTile(
                  title:
                      const Text('Add more details (optional)'),
                  initiallyExpanded: false,
                    onExpansionChanged: (expanded) =>
                      setSheetState(() {}),
                  children: [
                    const SizedBox(height: AppTheme.spacingMD),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedBreed,
                      decoration:
                          AppTheme.inputDecoration('Bird Breed'),
                        items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Not specified')),
                        ...breedOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                        ],
                      onChanged: (v) =>
                          setSheetState(() => selectedBreed = v),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: sourceController,
                      decoration: AppTheme.inputDecoration(
                              'Source of Chicks')
                          .copyWith(
                        hintText:
                            'e.g., CHI Farms, Local market, Hatchery',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedHousingType,
                      decoration: AppTheme.inputDecoration(
                          'Housing System'),
                        items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Not specified')),
                        ...housingOptions.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                        ],
                      onChanged: (v) => setSheetState(
                          () => selectedHousingType = v),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: notesController,
                      decoration: AppTheme.inputDecoration(
                              'Notes / Comments')
                          .copyWith(
                        hintText:
                            'Any other details about this flock',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingLG),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () async {
                      setSheetState(() {
                        nameError = null;
                        birdCountError = null;
                        costPerBirdError = null;
                        dateError = null;
                      });

                      bool hasError = false;

                      if (nameController.text.trim().isEmpty) {
                        setSheetState(() =>
                            nameError = 'Flock name is required');
                        hasError = true;
                      }

                      final birdCountStr =
                          birdCountController.text.trim();
                      int? birdCount;
                      if (birdCountStr.isEmpty) {
                        setSheetState(() => birdCountError =
                            'Number of birds is required');
                        hasError = true;
                      } else {
                        birdCount = int.tryParse(birdCountStr);
                        if (birdCount == null || birdCount <= 0) {
                          setSheetState(() =>
                              birdCountError = 'Must be a number > 0');
                          hasError = true;
                        }
                      }

                      final costStr =
                          costPerBirdController.text.trim();
                      double? costPerBird;
                      if (costStr.isEmpty) {
                        setSheetState(() => costPerBirdError =
                            'Cost per bird is required');
                        hasError = true;
                      } else {
                        costPerBird = double.tryParse(costStr);
                        if (costPerBird == null ||
                            costPerBird <= 0) {
                          setSheetState(() => costPerBirdError =
                              'Must be a number > 0');
                          hasError = true;
                        }
                      }

                      if (selectedDate == null) {
                        setSheetState(() =>
                            dateError = 'Please select a stock date');
                        hasError = true;
                      }

                      if (hasError) return;

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final financeProvider = context.read<FinanceProvider>();
                      try {
                        final flockProvider =
                            context.read<FlockProvider>();
                        await flockProvider.createFlockFromForm(
                          context: context,
                          name: nameController.text.trim(),
                          type: selectedType,
                          birdCount: birdCount!,
                          costPerBird: costPerBird!,
                          startDate: selectedDate!
                              .toIso8601String()
                              .split('T')
                              .first,
                          ageAtStocking: int.tryParse(
                                  ageAtStockingController.text
                                      .trim()) ??
                              0,
                          breed: selectedBreed,
                          source:
                              sourceController.text.trim().isEmpty
                                  ? null
                                  : sourceController.text.trim(),
                          housingType: selectedHousingType,
                          notes:
                              notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                        );

                        final newFlock =
                            flockProvider.flocks.last;
                        await financeProvider
                            .addExpense(
                              flockId: newFlock.id,
                              category: 'chicks',
                              description:
                                  'Initial purchase: ${newFlock.name} '
                                  '(${newFlock.birdCount} birds)',
                              amount: newFlock.initialCost,
                              date: newFlock.startDate,
                              paymentMethod: 'cash',
                              notes:
                                  'Auto-generated from flock creation',
                            );

                        if (!mounted) return;
                        navigator.pop();
                        messenger
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                                '✓ "${nameController.text.trim()}" '
                                'created! Initial cost recorded.'),
                            duration:
                                const Duration(seconds: 3),
                            backgroundColor:
                                AppTheme.successColor,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content:
                                Text('Error creating flock: $e'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    },
                    child: const Text('Create Flock',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditFlockDialog(BuildContext context, Flock flock) {
    final nameController =
        TextEditingController(text: flock.name);
    final birdCountController =
        TextEditingController(text: flock.birdCount.toString());
    final sourceController =
        TextEditingController(text: flock.source ?? '');
    final notesController =
        TextEditingController(text: flock.notes ?? '');
    final ageAtStockingController =
        TextEditingController(text: flock.ageAtStocking.toString());
    String selectedType = flock.type;
    String selectedStatus = flock.status;
    String? selectedBreed = flock.breed;
    String? selectedHousingType = flock.housingType;

    final breedOptions = [
      'Noiler', 'Kuroiler', 'Rhode Island Red', 'Isa Brown',
      'Ross 308', 'Cobb 500', 'Local/Indigenous', 'Other'
    ];
    final housingOptions = [
      'Deep litter', 'Battery cage', 'Free range',
      'Semi-intensive', 'Other'
    ];

    String? nameError;
    String? birdCountError;
    String? ageError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppTheme.spacingMD,
            right: AppTheme.spacingMD,
            top: AppTheme.spacingMD,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                AppTheme.spacingMD,
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
                Text('Edit Flock', style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingMD),
                Container(
                  padding:
                      const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor
                        .withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                            const Icon(Icons.access_time,
                              size: 16,
                              color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(flock.ageDisplay,
                              style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStageColor(
                                      flock.productionStage)
                                  .withValues(alpha: 0.2),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              flock.productionStage,
                              style: AppTheme.bodySmall.copyWith(
                                color: _getStageColor(
                                    flock.productionStage),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: nameController,
                  decoration: AppTheme.inputDecoration(
                          'Flock Name *')
                      .copyWith(errorText: nameError),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration:
                      AppTheme.inputDecoration('Flock Type'),
                  items: [
                    'Broilers', 'Layers', 'Noiler',
                    'Local/Kienyeji', 'Mixed/Other'
                  ]
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setSheetState(
                      () => selectedType = v ?? flock.type),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration:
                      AppTheme.inputDecoration('Status'),
                  items: ['active', 'inactive', 'sold out', 'lost']
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheetState(
                      () => selectedStatus = v ?? flock.status),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: ageAtStockingController,
                  decoration: AppTheme.inputDecoration(
                          'Age at stocking (days)')
                      .copyWith(
                    hintText:
                        '0 for day-old, 18 for point-of-lay',
                    errorText: ageError,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: selectedBreed,
                  decoration: AppTheme.inputDecoration(
                      'Bird Breed (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('Not specified')),
                    ...breedOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (v) =>
                      setSheetState(() => selectedBreed = v),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: sourceController,
                  decoration: AppTheme.inputDecoration(
                      'Source of Chicks (optional)'),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String?>(
                  initialValue: selectedHousingType,
                  decoration: AppTheme.inputDecoration(
                      'Housing System (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('Not specified')),
                    ...housingOptions.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                  ],
                  onChanged: (v) => setSheetState(
                      () => selectedHousingType = v),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: birdCountController,
                  decoration: AppTheme.inputDecoration(
                      'Number of Birds').copyWith(errorText: birdCountError),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: notesController,
                  decoration: AppTheme.inputDecoration(
                      'Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppTheme.spacingLG),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: AppTheme.primaryButtonStyle,
                    onPressed: () async {
                      setSheetState(() {
                        nameError = null;
                        birdCountError = null;
                        ageError = null;
                      });

                      bool hasError = false;

                      if (nameController.text.trim().isEmpty) {
                        setSheetState(() =>
                            nameError = 'Flock name is required');
                        hasError = true;
                      }

                      final parsedBirdCount = int.tryParse(
                          birdCountController.text.trim());
                      if (parsedBirdCount == null ||
                          parsedBirdCount <= 0) {
                        setSheetState(() => birdCountError =
                            'Valid number > 0 required');
                        hasError = true;
                      }

                      final parsedAge = int.tryParse(
                          ageAtStockingController.text.trim());
                      if (parsedAge == null || parsedAge < 0) {
                        setSheetState(() => ageError =
                            'Age must be 0 or positive');
                        hasError = true;
                      }

                      if (hasError) return;

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await context
                            .read<FlockProvider>()
                            .updateFlock(
                              flock.copyWith(
                                name: nameController.text.trim(),
                                type: selectedType,
                                status: selectedStatus,
                                birdCount: parsedBirdCount ??
                                    flock.birdCount,
                                ageAtStocking: parsedAge ??
                                    flock.ageAtStocking,
                                breed: selectedBreed,
                                source: sourceController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : sourceController.text.trim(),
                                housingType: selectedHousingType,
                                notes: notesController.text
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : notesController.text.trim(),
                              ),
                            );
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Flock updated successfully'),
                              backgroundColor:
                                  AppTheme.successColor),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                              content:
                                  Text('Failed to update: $e'),
                              backgroundColor:
                                  AppTheme.errorColor),
                        );
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Flock flock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flock'),
        content: Text(
            'Delete "${flock.name}"? This also deletes all records, '
            'expenses, sales and health events.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await context
                    .read<FlockProvider>()
                    .deleteFlock(flock.id);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Flock deleted')),
                );
              } catch (e) {
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Failed to delete: $e')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

void _showProFlockGate(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium,
                size: 40, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Unlock Unlimited Flocks',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Free accounts are limited to 1 flock. '
            'Upgrade to Pro to manage as many flocks as you need.',
            style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // CTA button → goes straight to UpgradeScreen
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UpgradeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium),
              label: const Text('See plans'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}
}
class _FlockGridCard extends StatelessWidget {
  final Flock flock;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FlockGridCard({
    required this.flock,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    // Keep these in constructor for backward compat but don't display them
    required this.latestRecord,
    required this.mortalityTotal,
    required this.breakEvenPerBird,
    required this.breakEvenDisplay,
    required this.recoveryPercentage,
  });

  final DailyRecord? latestRecord;
  final int mortalityTotal;
  final double breakEvenPerBird;
  final String breakEvenDisplay;
  final double recoveryPercentage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 2)
              : null,
          boxShadow: [
            isSelected ? AppTheme.shadowLG : AppTheme.shadowMD
          ],
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status badge ──────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: flock.status == 'active'
                      ? AppTheme.successColor
                      : AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  flock.status.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Flock icon ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.egg_alt,
                  size: 22, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),

            // ── Flock name — auto-size ────────────────────────
            Text(
              flock.name,
              style: AppTheme.bodyLarge
                  .copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 4),

            // ── Bird count ────────────────────────────────────
            Row(
              children: [
                Icon(Icons.groups,
                    size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '${flock.birdCount} ${flock.type}',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Age ───────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 12, color: AppTheme.primaryColor),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    flock.ageDisplay,
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Edit / Delete ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: AppTheme.errorColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  final String label;
  const _ProChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.primaryColor)),
    );
  }
}
// ─── Stat Row ─────────────────────────────────────────────────────────────────

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
            child: Text(label,
                style: AppTheme.bodySmall,
                overflow: TextOverflow.ellipsis)),
        Text(value,
            style: AppTheme.bodySmall.copyWith(
                color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─── Today Stat Item ──────────────────────────────────────────────────────────

class _TodayStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TodayStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(value,
              style: AppTheme.bodyLarge.copyWith(
                  color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: AppTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Selected Flock Banner ────────────────────────────────────────────────────

class _SelectedFlockBanner extends StatelessWidget {
  final Flock flock;
  const _SelectedFlockBanner({required this.flock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: Colors.white, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Currently Viewing',
                    style: AppTheme.bodySmall
                        .copyWith(color: Colors.white70)),
                Text(flock.name,
                    style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${flock.birdCount} birds',
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white70)),
              Text(flock.ageDisplay,
                  style: AppTheme.bodySmall
                      .copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Vaccination Banner ───────────────────────────────────────────────────────

class _VaccinationBanner extends StatelessWidget {
  final Flock flock;
  const _VaccinationBanner({required this.flock});

  @override
  Widget build(BuildContext context) {
    final next = flock.nextVaccination!;
    final daysLeft = next.daysUntil(flock.currentAgeDays);
    final isOverdue = daysLeft <= 0;
    final isUrgent = daysLeft <= 3 && daysLeft > 0;

    final Color bgColor;
    final Color textColor;
    final String message;

    if (isOverdue) {
      bgColor = AppTheme.errorColor.withValues(alpha: 0.15);
      textColor = AppTheme.errorColor;
      message = 'Overdue: ${next.name} '
          '(${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago)';
    } else if (isUrgent) {
      bgColor = AppTheme.warningColor.withValues(alpha: 0.2);
      textColor = AppTheme.warningColor;
      message = 'Due soon: ${next.name} in '
          '$daysLeft day${daysLeft == 1 ? '' : 's'}';
    } else {
      bgColor = AppTheme.successColor.withValues(alpha: 0.15);
      textColor = AppTheme.successColor;
      message = 'Upcoming: ${next.name} in '
          '$daysLeft day${daysLeft == 1 ? '' : 's'}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border:
            Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue
                ? Icons.warning_amber_rounded
                : Icons.vaccines,
            color: textColor,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<String> benefits;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: color),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(subtitle, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: color),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(child: Text(benefit)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}