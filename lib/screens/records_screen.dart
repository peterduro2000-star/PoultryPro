// lib/screens/records_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/daily_record_provider.dart';
import '../providers/flock_provider.dart';
import '../models/daily_record.dart';
import '../widgets/flock_header.dart';
import '../utils/date_formatter.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  FlockProvider? _flockProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_flockProvider != null) return;

    _flockProvider = context.read<FlockProvider>();
    _flockProvider!.addListener(_onFlockChanged);

    final flock = _flockProvider!.selectedFlock;
    if (flock != null) {
      context.read<DailyRecordProvider>().loadRecords(flock.id);
    }
  }

  void _onFlockChanged() {
    final flock = _flockProvider?.selectedFlock;
    if (flock != null && mounted) {
      context.read<DailyRecordProvider>().loadRecords(flock.id);
    }
  }

  @override
  void dispose() {
    _flockProvider?.removeListener(_onFlockChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Daily Records')),
      body: Column(
        children: [
          const FlockHeader(),
          Expanded(
            child: Consumer<FlockProvider>(
              builder: (context, flockProvider, _) {
                if (flockProvider.selectedFlock == null) {
                  return _buildNoFlockSelected();
                }
                return _buildRecordsList();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<FlockProvider>(
        builder: (context, provider, _) => provider.selectedFlock == null
            ? const SizedBox.shrink()
            : FloatingActionButton(
                heroTag: 'record_fab',
                onPressed: () =>
                    _showAddRecordSheet(context, provider.selectedFlock!.id),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  Widget _buildNoFlockSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home,
              size: 48, color: AppTheme.primaryColor.withOpacity(0.4)),
          const SizedBox(height: AppTheme.spacingMD),
          Text('No flock selected', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingSM),
          Text('Go to Home screen to select a flock',
              style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return Consumer<DailyRecordProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          return Center(
            child: Text(provider.error!,
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.errorColor)),
          );
        }
        if (provider.records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note,
                    size: 80, color: AppTheme.primaryColor.withOpacity(0.3)),
                const SizedBox(height: AppTheme.spacingMD),
                Text('No records yet', style: AppTheme.headingSmall),
                const SizedBox(height: AppTheme.spacingSM),
                Text('Tap + to add today\'s record',
                    style: AppTheme.bodyMedium),
              ],
            ),
          );
        }
        return Column(
          children: [
            _SummaryBar(provider: provider),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: provider.records.length,
                itemBuilder: (context, index) =>
                    _RecordCard(record: provider.records[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddRecordSheet(BuildContext context, String flockId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRecordSheet(flockId: flockId),
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final DailyRecordProvider provider;
  const _SummaryBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: _SummaryChip(
                icon: Icons.egg,
                label: 'Eggs',
                value: '${provider.totalEggs}',
                color: AppTheme.accentColor),
          ),
          Flexible(
            child: _SummaryChip(
                icon: Icons.warning,
                label: 'Mortality',
                value: '${provider.totalMortality}',
                color: AppTheme.errorColor),
          ),
          Flexible(
            child: _SummaryChip(
                icon: Icons.set_meal,
                label: 'Feed (kg)',
                value: provider.totalFeed.toStringAsFixed(1),
                color: AppTheme.secondaryColor),
          ),
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

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: AppTheme.bodyLarge
                  .copyWith(color: color, fontWeight: FontWeight.bold)),
          Text(label,
              style: AppTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Record Card ──────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final DailyRecord record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  DateFormatter.format(record.date),
                  style:
                      AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.calendar_today,
                  size: 16, color: AppTheme.textSecondary),
            ],
          ),
          const Divider(height: AppTheme.spacingLG),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                  icon: Icons.egg,
                  label: 'Eggs',
                  value: '${record.eggsCollected ?? 0}',
                  color: AppTheme.accentColor),
              _StatItem(
                  icon: Icons.warning,
                  label: 'Deaths',
                  value: '${record.mortalityCount ?? 0}',
                  color: AppTheme.errorColor),
              _StatItem(
                  icon: Icons.set_meal,
                  label: 'Feed kg',
                  value: record.feedGiven?.toStringAsFixed(1) ?? '0.0',
                  color: AppTheme.secondaryColor),
              _StatItem(
                  icon: Icons.water_drop,
                  label: 'Water L',
                  value: record.waterGiven?.toStringAsFixed(1) ?? '0.0',
                  color: AppTheme.infoColor),
            ],
          ),
          if (record.healthObservations != null &&
              record.healthObservations!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.health_and_safety,
                    size: 16, color: AppTheme.warningColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    record.healthObservations!,
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    record.notes!,
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Add Record Sheet ─────────────────────────────────────────────────────────

class _AddRecordSheet extends StatefulWidget {
  final String flockId;
  const _AddRecordSheet({required this.flockId});

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _eggsController = TextEditingController();
  final _mortalityController = TextEditingController();
  final _feedController = TextEditingController();
  final _waterController = TextEditingController();
  final _healthController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _dateAlreadyExists = false;

  @override
  void dispose() {
    _eggsController.dispose();
    _mortalityController.dispose();
    _feedController.dispose();
    _waterController.dispose();
    _healthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _checkDateExists() async {
    final dateStr = _selectedDate.toIso8601String().split('T').first;
    final records = context.read<DailyRecordProvider>().records;
    return records.any((r) => r.date == dateStr);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dateStr = _selectedDate.toIso8601String().split('T').first;

    _dateAlreadyExists = await _checkDateExists();
    if (_dateAlreadyExists) {
      final shouldOverwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Date already recorded'),
          content:
              Text('You already have a record for $dateStr. Overwrite it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );

      if (shouldOverwrite != true) {
        setState(() => _isSaving = false);
        return;
      }
    }

    final mortality = int.tryParse(_mortalityController.text.trim()) ?? 0;
    final flock = context.read<FlockProvider>().selectedFlock;
    final currentBirds = flock?.birdCount ?? 0;

    if (mortality > currentBirds) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot record $mortality deaths — only $currentBirds birds alive'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await context.read<DailyRecordProvider>().addRecord(
          flockId: widget.flockId,
          date: dateStr,
          eggsCollected: int.tryParse(_eggsController.text.trim()) ?? 0,
          mortalityCount: mortality,
          feedGiven: double.tryParse(_feedController.text.trim()) ?? 0.0,
          waterGiven: double.tryParse(_waterController.text.trim()) ?? 0.0,
          healthObservations: _healthController.text.trim().isEmpty
              ? null
              : _healthController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (mortality > 0) {
      final flockProvider = context.read<FlockProvider>();
      final flock = flockProvider.selectedFlock;
      if (flock != null) {
        final newCount =
            (flock.birdCount - mortality).clamp(0, flock.birdCount);
        await flockProvider.updateFlock(flock.copyWith(birdCount: newCount));
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dateAlreadyExists
              ? 'Daily record updated for $dateStr!'
              : 'Daily record saved for $dateStr!'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final flock = context.read<FlockProvider>().selectedFlock;
    final currentBirds = flock?.birdCount ?? 0;

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
      child: Form(
        key: _formKey,
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
              Text('Add / Update Daily Record', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    final exists = await _checkDateExists();
                    if (exists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Record already exists for ${DateFormatter.format(picked.toIso8601String().split('T').first)} — will overwrite if saved.'),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        DateFormatter.format(
                            _selectedDate.toIso8601String().split('T').first),
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _eggsController,
                      decoration:
                          AppTheme.inputDecoration('Eggs Collected Today'),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: TextFormField(
                      controller: _mortalityController,
                      decoration:
                          AppTheme.inputDecoration('Mortality Today').copyWith(
                        hintText: '0 — $currentBirds birds alive',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feedController,
                      decoration: AppTheme.inputDecoration('Feed Given (kg)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: TextFormField(
                      controller: _waterController,
                      decoration: AppTheme.inputDecoration('Water Given (L)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _healthController,
                decoration:
                    AppTheme.inputDecoration('Health Observations (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _notesController,
                decoration: AppTheme.inputDecoration('Notes (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
