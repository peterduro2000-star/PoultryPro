// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/flock_provider.dart';
import '../providers/daily_record_provider.dart';
import '../providers/finance_provider.dart'; // Added import
import '../models/flock.dart';
import '../models/daily_record.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';
import '../services/subscription_service.dart';
import 'flocks_screen.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';

// Top-level helper function (visible everywhere in this file)
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

  TextStyle get _dashboardSectionTitleStyle {
    return Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ) ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    context.read<FlockProvider>().loadFlocks().then((_) {
      if (mounted) {
        setState(() => _initialLoadComplete = true);
        context.read<FinanceProvider>().loadFarmFinanceData();
        final flocks = context.read<FlockProvider>().flocks;
        if (flocks.isNotEmpty) {
          final recordProvider = context.read<DailyRecordProvider>();
          final flockIds = flocks.map((f) => f.id).toList();
          recordProvider.loadLatestRecords(flockIds);
          recordProvider.loadMortalityTotals(flockIds);
        }
      }
    }).catchError((e) {
      if (mounted) setState(() => _initialLoadComplete = true);
    });
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
          // Show loading only during initial app load
          if (!_initialLoadComplete && flockProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state when flocks failed to load
          if (flockProvider.error != null && flockProvider.flocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: AppTheme.errorColor.withOpacity(0.5)),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text('Failed to load flocks', style: AppTheme.headingMedium),
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

          // Main content with refresh
          return RefreshIndicator(
            onRefresh: () async {
              final flockProvider = context.read<FlockProvider>();
              final financeProvider = context.read<FinanceProvider>();
              final recordProvider = context.read<DailyRecordProvider>();

              await flockProvider.loadFlocks();
              await financeProvider.loadFarmFinanceData();
              final flocks = flockProvider.flocks;
              if (flocks.isNotEmpty) {
                final flockIds = flocks.map((f) => f.id).toList();
                await recordProvider.loadLatestRecords(flockIds);
                await recordProvider.loadMortalityTotals(flockIds);
              }
            },
            child: Consumer<DailyRecordProvider>(
              builder: (context, recordProvider, _) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.spacingMD,
                    AppTheme.spacingMD,
                    AppTheme.spacingMD,
                    MediaQuery.paddingOf(context).bottom +
                        56 +
                        AppTheme.spacingLG +
                        AppTheme.spacingMD,
                  ),
                  children: [
                    // Farm-wide business performance
                    Consumer<FinanceProvider>(
                      builder: (context, financeProvider, _) =>
                          _buildFarmPerformanceCard(
                        flockProvider,
                        financeProvider,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    _buildFarmAlertsCard(flockProvider),
                    const SizedBox(height: AppTheme.spacingLG),

                    _buildTodaySummary(recordProvider),
                    const SizedBox(height: AppTheme.spacingLG),

                    _buildNavigationCards(flockProvider),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFarmPerformanceCard(
    FlockProvider flockProvider,
    FinanceProvider financeProvider,
  ) {
    final hasData = financeProvider.farmExpenses.isNotEmpty ||
        financeProvider.farmSales.isNotEmpty;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Farm Performance', style: _dashboardSectionTitleStyle),
          const SizedBox(height: 2),
          Text(
            'All flocks combined',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (financeProvider.isFarmFinanceLoading)
            const Center(child: CircularProgressIndicator())
          else if (!hasData && flockProvider.flocks.isEmpty)
            Center(
              child: Text(
                'No financial data yet',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: AppTheme.spacingMD,
              runSpacing: AppTheme.spacingMD,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _buildFarmMetricItem(
                  Icons.home_work_outlined,
                  'Active Flocks',
                  flockProvider.activeFlockCount.toString(),
                  AppTheme.primaryColor,
                ),
                _buildFarmMetricItem(
                  Icons.groups,
                  'Total Birds',
                  flockProvider.totalBirds.toString(),
                  AppTheme.secondaryColor,
                ),
                _buildFarmMetricItem(
                  Icons.trending_up,
                  'Total Sales',
                  CurrencyFormatter.formatCompact(
                      financeProvider.farmTotalSales),
                  AppTheme.successColor,
                ),
                _buildFarmMetricItem(
                  Icons.receipt_long,
                  'Total Expenses',
                  CurrencyFormatter.formatCompact(
                      financeProvider.farmTotalExpenses),
                  AppTheme.errorColor,
                ),
                _buildFarmMetricItem(
                  financeProvider.farmProfit >= 0
                      ? Icons.account_balance_wallet
                      : Icons.warning_amber,
                  'Profit',
                  CurrencyFormatter.formatCompact(financeProvider.farmProfit),
                  financeProvider.farmProfit >= 0
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
                _buildFarmMetricItem(
                  Icons.paid,
                  'Cost Recovered',
                  '${financeProvider.farmRecoveryPercentage().toStringAsFixed(1)}%',
                  AppTheme.secondaryColor,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFarmAlertsCard(FlockProvider flockProvider) {
    final upcoming = flockProvider.flocks
        .where((flock) => flock.nextVaccination != null)
        .toList()
      ..sort((a, b) => a.nextVaccination!
          .daysUntil(a.currentAgeDays)
          .compareTo(b.nextVaccination!.daysUntil(b.currentAgeDays)));

    final alertText = upcoming.isEmpty
        ? 'No farm-wide vaccination reminders right now'
        : _farmVaccinationAlertText(upcoming.first);

    return Container(
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
            child: Icon(Icons.notifications_active_outlined,
                color: AppTheme.successColor),
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Farm Alerts', style: _dashboardSectionTitleStyle),
                const SizedBox(height: 2),
                Text(
                  alertText,
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

  String _farmVaccinationAlertText(Flock flock) {
    final next = flock.nextVaccination!;
    final daysLeft = next.daysUntil(flock.currentAgeDays);
    if (daysLeft <= 0) {
      return '${flock.name}: ${next.name} is overdue';
    }
    return '${flock.name}: ${next.name} due in $daysLeft day${daysLeft == 1 ? '' : 's'}';
  }

  Widget _buildFarmMetricItem(
      IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTheme.bodyLarge
                    .copyWith(color: color, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Text(
            label,
            style: AppTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCards(FlockProvider flockProvider) {
    return Column(
      children: [
        _buildFlocksNavigationCard(flockProvider),
        const SizedBox(height: AppTheme.spacingMD),
        _buildNavigationCard(
          icon: Icons.analytics_outlined,
          title: 'Reports / Analytics',
          subtitle: 'Advanced farm reports coming soon',
          meta: 'Soon',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reports coming soon')),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacingMD),
        _buildNavigationCard(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Manage app preferences and backup',
          meta: '',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFlocksNavigationCard(FlockProvider flockProvider) {
    final flockCount = flockProvider.flocks.length;

    return _buildNavigationCard(
      icon: Icons.groups,
      title: 'My Flocks',
      subtitle: 'View and manage all flock batches',
      meta: '$flockCount ${flockCount == 1 ? 'flock' : 'flocks'}',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FlocksScreen(
              onCreateFlock: _showCreateFlockDialog,
              onEditFlock: _showEditFlockDialog,
              onDeleteFlock: _confirmDelete,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String meta,
    required VoidCallback onTap,
  }) {
    return Material(
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
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(icon, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _dashboardSectionTitleStyle),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (meta.isNotEmpty) ...[
                Text(
                  meta,
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
              ],
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummary(DailyRecordProvider recordProvider) {
    final records =
        recordProvider.latestRecords.values.whereType<DailyRecord>().toList();

    final totalEggs =
        records.fold<int>(0, (sum, r) => sum + (r.eggsCollected ?? 0));
    final totalDeaths =
        records.fold<int>(0, (sum, r) => sum + (r.mortalityCount ?? 0));
    final totalFeed =
        records.fold<double>(0, (sum, r) => sum + (r.feedGiven ?? 0));
    final totalWater =
        records.fold<double>(0, (sum, r) => sum + (r.waterGiven ?? 0));

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
              Text("Today's Summary", style: _dashboardSectionTitleStyle),
              Text(
                hasData ? 'All flocks' : 'No records yet',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (!hasData)
            Center(
              child: Text(
                'Add today\'s records to see summary',
                style:
                    AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
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

  Widget _buildAgePreview(DateTime stockDate, int ageAtStocking) {
    final daysSinceStocking = DateTime.now().difference(stockDate).inDays;
    final currentAge = ageAtStocking + daysSinceStocking;
    final weeks = currentAge ~/ 7;
    String ageText;
    if (currentAge < 0) {
      ageText = 'Starts in ${-currentAge} days';
    } else if (currentAge < 7) {
      ageText = 'Currently $currentAge days old';
    } else {
      ageText = 'Currently $weeks weeks old ($currentAge days)';
    }
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: AppTheme.successColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(ageText,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.successColor)),
        ),
      ],
    );
  }

  void _showCreateFlockDialog(BuildContext context) {
    final parentContext = context;
    final nameController = TextEditingController();
    final birdCountController = TextEditingController();
    final costPerBirdController = TextEditingController();
    final sourceController = TextEditingController();
    final notesController = TextEditingController();
    final ageAtStockingController = TextEditingController(text: '0');

    String selectedType = 'Broilers';
    String? selectedBreed;
    String? selectedHousingType;
    DateTime? selectedDate;
    bool showOptionalFields = false;

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppTheme.spacingMD,
            right: AppTheme.spacingMD,
            top: AppTheme.spacingMD,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingMD,
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
                Text('Create New Flock', style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingSM),
                Text('Stock details for your birds',
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: AppTheme.spacingLG),
                TextField(
                  controller: nameController,
                  decoration: AppTheme.inputDecoration('Flock Name *').copyWith(
                    errorText: nameError,
                    hintText: 'e.g., Broiler Batch 1, Layer House A',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: AppTheme.inputDecoration('Type of Birds *'),
                  items: typeOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedType = v ?? 'Broilers'),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: birdCountController,
                  decoration:
                      AppTheme.inputDecoration('Number of Birds *').copyWith(
                    errorText: birdCountError,
                    hintText: '100, 500, 1000, etc.',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: costPerBirdController,
                  decoration:
                      AppTheme.inputDecoration('Cost per Bird (₦) *').copyWith(
                    errorText: costPerBirdError,
                    hintText: '800, 1500, 3000, etc.',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: dateError != null
                          ? AppTheme.errorColor
                          : AppTheme.textSecondary.withOpacity(0.3),
                      width: dateError != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stocking Details *',
                          style: AppTheme.bodySmall
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Age of birds when you got them + date you stocked',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ageAtStockingController,
                              decoration: AppTheme.inputDecoration(
                                      'Age at stocking (days)')
                                  .copyWith(
                                hintText: '0 = day-old chicks',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setSheetState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Date stocked *'
                                      : DateFormatter.format(selectedDate!
                                          .toIso8601String()
                                          .split('T')
                                          .first),
                                  style: AppTheme.bodySmall.copyWith(
                                    color: selectedDate == null
                                        ? AppTheme.textSecondary
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now()
                                          .subtract(const Duration(days: 365)),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 30)),
                                    );
                                    if (picked != null) {
                                      setSheetState(() {
                                        selectedDate = picked;
                                        dateError = null;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today,
                                      size: 16),
                                  label: const Text('Pick date'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
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
                          int.tryParse(ageAtStockingController.text) ?? 0,
                        ),
                      ],
                      if (dateError != null) ...[
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(dateError!,
                            style: AppTheme.bodySmall
                                .copyWith(color: AppTheme.errorColor)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                ExpansionTile(
                  title: const Text('Add more details (optional)'),
                  initiallyExpanded: false,
                  onExpansionChanged: (expanded) =>
                      setSheetState(() => showOptionalFields = expanded),
                  children: [
                    const SizedBox(height: AppTheme.spacingMD),
                    DropdownButtonFormField<String?>(
                      value: selectedBreed,
                      decoration: AppTheme.inputDecoration('Bird Breed'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Not specified')),
                        ...breedOptions
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                      ],
                      onChanged: (v) => setSheetState(() => selectedBreed = v),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: sourceController,
                      decoration:
                          AppTheme.inputDecoration('Source of Chicks').copyWith(
                        hintText: 'e.g., CHI Farms, Local market, Hatchery',
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    DropdownButtonFormField<String?>(
                      value: selectedHousingType,
                      decoration: AppTheme.inputDecoration('Housing System'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Not specified')),
                        ...housingOptions
                            .map((h) =>
                                DropdownMenuItem(value: h, child: Text(h)))
                            .toList(),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => selectedHousingType = v),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    TextField(
                      controller: notesController,
                      decoration:
                          AppTheme.inputDecoration('Notes / Comments').copyWith(
                        hintText: 'Any other details about this flock',
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
                        setSheetState(
                            () => nameError = 'Flock name is required');
                        hasError = true;
                      }

                      final birdCountStr = birdCountController.text.trim();
                      int? birdCount;
                      if (birdCountStr.isEmpty) {
                        setSheetState(() =>
                            birdCountError = 'Number of birds is required');
                        hasError = true;
                      } else {
                        birdCount = int.tryParse(birdCountStr);
                        if (birdCount == null || birdCount <= 0) {
                          setSheetState(
                              () => birdCountError = 'Must be a number > 0');
                          hasError = true;
                        }
                      }

                      final costStr = costPerBirdController.text.trim();
                      double? costPerBird;
                      if (costStr.isEmpty) {
                        setSheetState(() =>
                            costPerBirdError = 'Cost per bird is required');
                        hasError = true;
                      } else {
                        costPerBird = double.tryParse(costStr);
                        if (costPerBird == null || costPerBird <= 0) {
                          setSheetState(
                              () => costPerBirdError = 'Must be a number > 0');
                          hasError = true;
                        }
                      }

                      if (selectedDate == null) {
                        setSheetState(
                            () => dateError = 'Please select a stock date');
                        hasError = true;
                      }

                      if (hasError) return;

                      try {
                        final flockProvider = context.read<FlockProvider>();
                        await flockProvider.createFlockFromForm(
                          name: nameController.text.trim(),
                          type: selectedType,
                          birdCount: birdCount!,
                          costPerBird: costPerBird!,
                          startDate:
                              selectedDate!.toIso8601String().split('T').first,
                          ageAtStocking: int.tryParse(
                                  ageAtStockingController.text.trim()) ??
                              0,
                          breed: selectedBreed,
                          source: sourceController.text.trim().isEmpty
                              ? null
                              : sourceController.text.trim(),
                          housingType: selectedHousingType,
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                        );

                        // NEW: Automatically add initial cost as Expense
                        final newFlock = flockProvider
                            .flocks.last; // assuming last added is the new one
                        final initialCost = newFlock.initialCost;
                        await context.read<FinanceProvider>().addExpense(
                              flockId: newFlock.id,
                              category: 'chicks',
                              description:
                                  'Initial purchase: ${newFlock.name} (${newFlock.birdCount} birds)',
                              amount: initialCost,
                              date: newFlock.startDate,
                              paymentMethod:
                                  'cash', // can make configurable later
                              notes: 'Auto-generated from flock creation',
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✓ "${nameController.text.trim()}" flock created! Initial cost recorded.'),
                              duration: const Duration(seconds: 3),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          if (e is FlockLimitException) {
                            await showDialog<void>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        color: AppTheme.accentColor),
                                    const SizedBox(width: AppTheme.spacingSM),
                                    const Expanded(
                                      child: Text('Free Plan Limit Reached'),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                        'The Free plan supports 1 flock.'),
                                    const SizedBox(height: AppTheme.spacingMD),
                                    Text('Upgrade to Pro to unlock:',
                                        style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: AppTheme.spacingSM),
                                    const Text(
                                      '• Unlimited flocks\n'
                                      '• Advanced reports\n'
                                      '• Smart business insights\n'
                                      '• Reminders',
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Maybe Later'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      Navigator.pop(context);
                                      if (parentContext.mounted) {
                                        Navigator.push(
                                          parentContext,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const UpgradeScreen(),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Upgrade'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error creating flock: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
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
    final nameController = TextEditingController(text: flock.name);
    final birdCountController =
        TextEditingController(text: flock.birdCount.toString());
    final sourceController = TextEditingController(text: flock.source ?? '');
    final notesController = TextEditingController(text: flock.notes ?? '');
    final ageAtStockingController =
        TextEditingController(text: flock.ageAtStocking.toString());
    String selectedType = flock.type;
    String selectedStatus = flock.status;
    String? selectedBreed = flock.breed;
    String? selectedHousingType = flock.housingType;

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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppTheme.spacingMD,
            right: AppTheme.spacingMD,
            top: AppTheme.spacingMD,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingMD,
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
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: AppTheme.primaryColor),
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
                              color: _getStageColor(flock.productionStage)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              flock.productionStage,
                              style: AppTheme.bodySmall.copyWith(
                                color: _getStageColor(flock.productionStage),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (flock.nextVaccination != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: flock.nextVaccination!
                                            .daysUntil(flock.currentAgeDays) <=
                                        3
                                    ? AppTheme.errorColor.withOpacity(0.2)
                                    : AppTheme.warningColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Next: ${flock.nextVaccination!.name} (${flock.nextVaccination!.daysUntil(flock.currentAgeDays)} days)',
                                style: AppTheme.bodySmall.copyWith(
                                  color: flock.nextVaccination!.daysUntil(
                                              flock.currentAgeDays) <=
                                          3
                                      ? AppTheme.errorColor
                                      : AppTheme.warningColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: nameController,
                  decoration: AppTheme.inputDecoration('Flock Name *').copyWith(
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: AppTheme.inputDecoration('Flock Type'),
                  items: [
                    'Broilers',
                    'Layers',
                    'Noiler',
                    'Local/Kienyeji',
                    'Mixed/Other'
                  ]
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedType = v ?? flock.type),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: AppTheme.inputDecoration('Status'),
                  items: ['active', 'inactive', 'sold']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedStatus = v ?? flock.status),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: ageAtStockingController,
                  decoration: AppTheme.inputDecoration('Age at stocking (days)')
                      .copyWith(
                    hintText: '0 for day-old, 18 for point-of-lay, etc.',
                    errorText: ageError,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String?>(
                  value: selectedBreed,
                  decoration: AppTheme.inputDecoration('Bird Breed (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Not specified')),
                    ...breedOptions
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                  ],
                  onChanged: (v) => setSheetState(() => selectedBreed = v),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: sourceController,
                  decoration:
                      AppTheme.inputDecoration('Source of Chicks (optional)')
                          .copyWith(
                    hintText: 'e.g., CHI Farms, Local market, Hatchery',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                DropdownButtonFormField<String?>(
                  value: selectedHousingType,
                  decoration:
                      AppTheme.inputDecoration('Housing System (optional)'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Not specified')),
                    ...housingOptions
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                  ],
                  onChanged: (v) =>
                      setSheetState(() => selectedHousingType = v),
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: birdCountController,
                  decoration: AppTheme.inputDecoration('Number of Birds'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: notesController,
                  decoration: AppTheme.inputDecoration('Notes (optional)'),
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
                        setSheetState(
                            () => nameError = 'Flock name is required');
                        hasError = true;
                      }

                      final parsedBirdCount =
                          int.tryParse(birdCountController.text.trim());
                      if (parsedBirdCount == null || parsedBirdCount <= 0) {
                        setSheetState(
                            () => birdCountError = 'Valid number > 0 required');
                        hasError = true;
                      }

                      final parsedAge =
                          int.tryParse(ageAtStockingController.text.trim());
                      if (parsedAge == null || parsedAge < 0) {
                        setSheetState(
                            () => ageError = 'Age must be 0 or positive');
                        hasError = true;
                      }

                      if (hasError) return;

                      try {
                        await context.read<FlockProvider>().updateFlock(
                              flock.copyWith(
                                name: nameController.text.trim(),
                                type: selectedType,
                                status: selectedStatus,
                                birdCount: parsedBirdCount ?? flock.birdCount,
                                ageAtStocking: parsedAge ?? flock.ageAtStocking,
                                breed: selectedBreed,
                                source: sourceController.text.trim().isEmpty
                                    ? null
                                    : sourceController.text.trim(),
                                housingType: selectedHousingType,
                                notes: notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                              ),
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Flock updated successfully'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to update: $e'),
                                backgroundColor: AppTheme.errorColor),
                          );
                        }
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
            'Are you sure you want to delete "${flock.name}"? This will also delete all associated records, expenses, sales and health events.'),
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
              try {
                await context.read<FlockProvider>().deleteFlock(flock.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Flock deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(value,
              style: AppTheme.bodyLarge
                  .copyWith(color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
          Text(label, style: AppTheme.bodySmall, textAlign: TextAlign.center),
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

    Color bgColor;
    Color textColor;
    String message;

    if (isOverdue) {
      bgColor = AppTheme.errorColor.withOpacity(0.15);
      textColor = AppTheme.errorColor;
      message =
          'Overdue: ${next.name} (was due ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago)';
    } else if (isUrgent) {
      bgColor = AppTheme.warningColor.withOpacity(0.2);
      textColor = AppTheme.warningColor;
      message =
          'Urgent: ${next.name} in $daysLeft day${daysLeft == 1 ? '' : 's'}';
    } else {
      bgColor = AppTheme.successColor.withOpacity(0.15);
      textColor = AppTheme.successColor;
      message =
          'Upcoming: ${next.name} in $daysLeft day${daysLeft == 1 ? '' : 's'}';
    }

    return GestureDetector(
      onTap: () {
        _showFullScheduleDialog(context, flock);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: textColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.vaccines,
              color: textColor,
              size: 28,
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to see full vaccination schedule for ${flock.name}',
                    style: AppTheme.bodySmall
                        .copyWith(color: textColor.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: textColor, size: 16),
          ],
        ),
      ),
    );
  }

  void _showFullScheduleDialog(BuildContext context, Flock flock) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Vaccination Schedule – ${flock.name} (${flock.ageDisplay})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: flock.vaccinationSchedule.length,
            itemBuilder: (context, index) {
              final v = flock.vaccinationSchedule[index];
              final daysUntil = v.daysUntil(flock.currentAgeDays);
              final isDone = v.done;
              final isUpcoming = daysUntil > 0 && daysUntil <= 7;
              final isOverdue = daysUntil <= 0 && !isDone;

              return ListTile(
                leading: Icon(
                  isDone ? Icons.check_circle : Icons.schedule,
                  color: isDone
                      ? AppTheme.successColor
                      : isOverdue
                          ? AppTheme.errorColor
                          : isUpcoming
                              ? AppTheme.warningColor
                              : AppTheme.textSecondary,
                ),
                title: Text(v.name),
                subtitle: Text(
                  isDone
                      ? 'Done'
                      : daysUntil <= 0
                          ? 'Overdue by ${-daysUntil} day${-daysUntil == 1 ? '' : 's'}'
                          : 'Due in $daysUntil day${daysUntil == 1 ? '' : 's'} (day ${v.day})',
                ),
                trailing: isUpcoming || isOverdue
                    ? Text(
                        'Day ${v.day}',
                        style: TextStyle(
                          color: isOverdue
                              ? AppTheme.errorColor
                              : AppTheme.warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
