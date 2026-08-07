// lib/screens/health_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/health_provider.dart';
import '../providers/flock_provider.dart';
import '../models/health_event.dart';
import '../widgets/flock_header.dart';
import '../widgets/metric_card.dart';
import '../utils/date_formatter.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
 @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final flock = context.read<FlockProvider>().selectedFlock;
    if (flock != null) {
      context.read<HealthProvider>().loadHealthEvents(flock.id);
    }
    context.read<FlockProvider>().addListener(_onFlockChanged);
  });
}

void _onFlockChanged() {
  final flock = context.read<FlockProvider>().selectedFlock;
  if (flock != null) {
    context.read<HealthProvider>().loadHealthEvents(flock.id);
  }
}

@override
void dispose() {
  context.read<FlockProvider>().removeListener(_onFlockChanged);
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Health')),
      body: Column(
        children: [
          const FlockHeader(),
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
                            color: AppTheme.primaryColor.withValues(alpha: 102)),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text('No flock selected',
                            style: AppTheme.headingSmall),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text('Go to Home screen to select a flock',
                            style: AppTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                return Consumer<HealthProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.error != null) {
                      return Center(
                          child: Text(provider.error!,
                              style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.errorColor)));
                    }
                    if (provider.events.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.health_and_safety,
                                size: 80,
                                color: AppTheme.primaryColor.withValues(alpha: 77)),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text('No health events yet',
                                style: AppTheme.headingSmall),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text('Tap + to log a health event',
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
                            itemCount: provider.events.length,
                            itemBuilder: (context, index) =>
                                _HealthEventCard(event: provider.events[index]),
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
            : FloatingActionButton(
                heroTag: 'health_fab',
                onPressed: () => _showAddSheet(context, provider.selectedFlock!.id),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, String flockId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHealthEventSheet(flockId: flockId),
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final HealthProvider provider;
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
            child: MetricCard(
                icon: Icons.event_note,
                label: 'Total Events',
                value: '${provider.events.length}',
                color: AppTheme.primaryColor,
                tintBackground: true),
          ),
          Flexible(
            child: MetricCard(
                icon: Icons.warning,
                label: 'High Severity',
                value: '${provider.highSeverityEvents.length}',
                color: AppTheme.errorColor,
                tintBackground: true),
          ),
          Flexible(
            child: MetricCard(
                icon: Icons.people,
                label: 'Birds Affected',
                value: '${provider.totalAffectedBirds}',
                color: AppTheme.warningColor,
                tintBackground: true),
          ),
        ],
      ),
    );
  }
}



// ─── Health Event Card ────────────────────────────────────────────────────────

class _HealthEventCard extends StatelessWidget {
  final HealthEvent event;
  const _HealthEventCard({required this.event});

  Color get _severityColor {
    switch (event.severity?.toLowerCase()) {
      case 'high':
        return AppTheme.errorColor;
      case 'medium':
        return AppTheme.warningColor;
      default:
        return AppTheme.successColor;
    }
  }

  IconData get _eventIcon {
    switch (event.eventType.toLowerCase()) {
      case 'vaccination':
        return Icons.vaccines;
      case 'treatment':
        return Icons.medical_services;
      case 'disease':
        return Icons.coronavirus;
      default:
        return Icons.visibility;
    }
  }

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
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: 26),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(_eventIcon, color: _severityColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.eventType.toUpperCase(),
                        style: AppTheme.bodySmall.copyWith(color: _severityColor)),
                    Flexible(
                      child: Text(event.description,
                          style: AppTheme.bodyLarge,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ),
                  ],
                ),
              ),
              Text(DateFormatter.formatShort(event.date),
                  style: AppTheme.bodySmall),
            ],
          ),
          if (event.medicine != null || event.dosage != null || event.affectedBirds != null) ...[
            const Divider(height: AppTheme.spacingLG),
            Wrap(
              spacing: AppTheme.spacingSM,
              runSpacing: 8,
              children: [
                if (event.affectedBirds != null && event.affectedBirds! > 0)
                  _InfoChip(
                      icon: Icons.people,
                      label: '${event.affectedBirds} birds affected'),
                if (event.medicine != null)
                  _InfoChip(icon: Icons.medication, label: event.medicine!),
                if (event.dosage != null)
                  _InfoChip(icon: Icons.science, label: event.dosage!),
              ],
            ),
          ],
          if (event.notes != null && event.notes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Flexible(
              child: Text(event.notes!,
                  style: AppTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Add Health Event Sheet ───────────────────────────────────────────────────

class _AddHealthEventSheet extends StatefulWidget {
  final String flockId;
  const _AddHealthEventSheet({required this.flockId});

  @override
  State<_AddHealthEventSheet> createState() => _AddHealthEventSheetState();
}

class _AddHealthEventSheetState extends State<_AddHealthEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _medicineController = TextEditingController();
  final _dosageController = TextEditingController();
  final _affectedController = TextEditingController();
  final _notesController = TextEditingController();
  String _eventType = 'observation';
  String? _severity;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _dateAlreadyExists = false;

  final _eventTypes = ['vaccination', 'treatment', 'disease', 'observation'];
  final _severities = ['low', 'medium', 'high'];

  @override
  void dispose() {
    _descController.dispose();
    _medicineController.dispose();
    _dosageController.dispose();
    _affectedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<bool> _checkDateExists() async {
    final dateStr = _selectedDate.toIso8601String().split('T').first;
    final events = context.read<HealthProvider>().events;
    return events.any((e) => e.date == dateStr);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dateStr = _selectedDate.toIso8601String().split('T').first;
    final healthProvider = context.read<HealthProvider>();

    _dateAlreadyExists = await _checkDateExists();
    if (!mounted) return;
    if (_dateAlreadyExists) {
      final shouldOverwrite = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Date already logged'),
          content: Text('You have a health event for $dateStr. Overwrite?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Overwrite')),
          ],
        ),
      );

      if (shouldOverwrite != true) {
        setState(() => _isSaving = false);
        return;
      }
    }

    final affected = int.tryParse(_affectedController.text.trim()) ?? 0;

    await healthProvider.addHealthEvent(
          flockId: widget.flockId,
          date: dateStr,
          eventType: _eventType,
          description: _descController.text.trim(),
          severity: _severity,
          affectedBirds: affected,
          medicine: _medicineController.text.trim().isEmpty ? null : _medicineController.text.trim(),
          dosage: _dosageController.text.trim().isEmpty ? null : _dosageController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dateAlreadyExists
              ? 'Health event updated for $dateStr!'
              : 'Health event saved for $dateStr!'),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    setState(() => _isSaving = false);
  }

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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text('Log Health Event', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),

              GestureDetector(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (!mounted || picked == null) return;
                  setState(() => _selectedDate = picked);

                  final exists = await _checkDateExists();
                  if (!mounted) return;
                  if (exists) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Event already logged for ${DateFormatter.format(picked.toIso8601String().split('T').first)} — will overwrite if saved.',
                        ),
                        backgroundColor: AppTheme.warningColor,
                      ),
                    );
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
                      const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(DateFormatter.format(_selectedDate.toIso8601String().split('T').first),
                          style: AppTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      decoration: AppTheme.inputDecoration('Event Type *'),
                      items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _eventType = v!),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _severity,
                      decoration: AppTheme.inputDecoration('Severity (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._severities.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))),
                      ],
                      onChanged: (v) => setState(() => _severity = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),

              TextFormField(
                controller: _descController,
                decoration: AppTheme.inputDecoration('Description *'),
                validator: (v) => v!.trim().isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),

              TextFormField(
                controller: _affectedController,
                decoration: AppTheme.inputDecoration('Birds Affected (0 if none)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.spacingMD),

              TextFormField(
                controller: _medicineController,
                decoration: AppTheme.inputDecoration('Medicine Used (optional)'),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              TextFormField(
                controller: _dosageController,
                decoration: AppTheme.inputDecoration('Dosage (optional)'),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Photo stub (disabled for now — add image_picker later)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo upload coming soon!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 128)),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.camera_alt, color: AppTheme.textSecondary),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text('Add Photo (optional - coming soon)',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              TextFormField(
                controller: _notesController,
                decoration: AppTheme.inputDecoration('Notes (optional)'),
                maxLines: 3,
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Health Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}