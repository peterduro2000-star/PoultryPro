// lib/screens/stock_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/stock_provider.dart';
import '../providers/flock_provider.dart';
import '../models/stock.dart';
import '../widgets/flock_header.dart';
import 'tools_screen.dart';
import '../utils/date_formatter.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _filterType = 'all';

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final flock = context.read<FlockProvider>().selectedFlock;
    if (flock != null) {
      context.read<StockProvider>().loadStock(flock.id);
    }
    context.read<FlockProvider>().addListener(_onFlockChanged);
  });
}

void _onFlockChanged() {
  final flock = context.read<FlockProvider>().selectedFlock;
  if (flock != null) {
    context.read<StockProvider>().loadStock(flock.id);
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
      appBar: AppBar(
  title: const Text('Stock'),
  actions: [
    IconButton(
      icon: const Icon(Icons.calculate_outlined),
      tooltip: 'Calculators',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ToolsScreen()),
      ),
    ),
  ],
),
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.4)),
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
                return Consumer<StockProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.error != null) {
                      return Center(
                          child: Text(provider.error!,
                              style: AppTheme.bodyMedium
                                  .copyWith(color: AppTheme.errorColor)));
                    }
                    if (provider.stocks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 80,
                                color:
                                          AppTheme.primaryColor.withValues(alpha: 0.3)),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text('No stock items yet',
                                style: AppTheme.headingSmall),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text('Tap + to add stock',
                                style: AppTheme.bodyMedium),
                          ],
                        ),
                      );
                    }

                    final filtered = _filterType == 'all'
                        ? provider.stocks
                        : _filterType == 'low'
                            ? provider.lowStockAlerts
                            : provider.stocks
                                .where((s) => s.itemType == _filterType)
                                .toList();

                    return Column(
                      children: [
                        // Summary bar
                        _SummaryBar(provider: provider),
                        // Filter chips
                        _FilterBar(
                          selected: _filterType,
                          onSelected: (type) =>
                              setState(() => _filterType = type),
                          alertCount: provider.alertCount,
                        ),
                        // Stock list
                        Expanded(
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.all(AppTheme.spacingMD),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) => _StockCard(
                              stock: filtered[index],
                              onRestock: () => _showRestockSheet(
                                  context, filtered[index], provider),
                            ),
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
              heroTag: 'stock_fab',
                onPressed: () => _showAddStockSheet(
                    context, provider.selectedFlock!.id),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  void _showAddStockSheet(BuildContext context, String flockId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddStockSheet(flockId: flockId),
    );
  }

  void _showRestockSheet(
      BuildContext context, Stock stock, StockProvider provider) {
    final quantityController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
            Text('Restock: ${stock.itemName}',
                style: AppTheme.headingSmall),
            Text('Current: ${stock.quantity} ${stock.unit}',
                style: AppTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: quantityController,
              decoration:
                  AppTheme.inputDecoration('Quantity to Add (${stock.unit})'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppTheme.primaryButtonStyle,
                onPressed: () async {
                  final qty = double.tryParse(quantityController.text);
                  if (qty == null) return;
                  final stockProvider = context.read<StockProvider>();
                  await stockProvider.updateStock(
                    stock.copyWith(
                    quantity: stock.quantity + qty,
                    lastRestockDate:
                      DateTime.now().toIso8601String().split('T').first,
                    ),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('Confirm Restock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Bar ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final StockProvider provider;
  const _SummaryBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.inventory_2,
            label: 'Items',
            value: '${provider.stocks.length}',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: AppTheme.spacingSM),
          _SummaryChip(
            icon: Icons.warning,
            label: 'Low Stock',
            value: '${provider.alertCount}',
            color: provider.hasAlerts
                ? AppTheme.errorColor
                : AppTheme.successColor,
          ),
          const SizedBox(width: AppTheme.spacingSM),
          _SummaryChip(
            icon: Icons.attach_money,
            label: 'Total Value',
            value: '₦${provider.totalStockValue.toStringAsFixed(0)}',
            color: AppTheme.secondaryColor,
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

  const _SummaryChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingSM, horizontal: AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(value,
                style: AppTheme.bodyLarge
                    .copyWith(color: color, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            Text(label, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Bar ───────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final int alertCount;

  const _FilterBar(
      {required this.selected,
      required this.onSelected,
      required this.alertCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMD, 0, AppTheme.spacingMD, AppTheme.spacingMD),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
                label: 'All',
                value: 'all',
                selected: selected,
                onSelected: onSelected),
            _FilterChip(
              label: '⚠ Low ($alertCount)',
                value: 'low',
                selected: selected,
                onSelected: onSelected,
                alertColor: alertCount > 0),
            _FilterChip(
                label: 'Feed',
                value: 'feed',
                selected: selected,
                onSelected: onSelected),
            _FilterChip(
                label: 'Medicine',
                value: 'medicine',
                selected: selected,
                onSelected: onSelected),
            _FilterChip(
                label: 'Supplies',
                value: 'supplies',
                selected: selected,
                onSelected: onSelected),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool alertColor;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
    this.alertColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final color =
        alertColor ? AppTheme.errorColor : AppTheme.primaryColor;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        margin: const EdgeInsets.only(right: AppTheme.spacingSM),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isSelected ? Colors.white : color,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final Stock stock;
  final VoidCallback onRestock;

  const _StockCard({required this.stock, required this.onRestock});

  Color get _typeColor {
    switch (stock.itemType) {
      case 'feed':
        return AppTheme.secondaryColor;
      case 'medicine':
        return AppTheme.errorColor;
      default:
        return AppTheme.infoColor;
    }
  }

  IconData get _typeIcon {
    switch (stock.itemType) {
      case 'feed':
        return Icons.set_meal;
      case 'medicine':
        return Icons.medication;
      default:
        return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLow = stock.isLowStock;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: isLow
            ? Border.all(color: AppTheme.errorColor, width: 1.5)
            : null,
        boxShadow: const [AppTheme.shadowMD],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(stock.itemName, style: AppTheme.bodyLarge),
                        if (isLow) ...[
                          const SizedBox(width: AppTheme.spacingSM),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('LOW',
                                style: AppTheme.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(stock.itemType.toUpperCase(),
                        style: AppTheme.bodySmall
                            .copyWith(color: _typeColor)),
                  ],
                ),
              ),
              // Restock button
              TextButton.icon(
                onPressed: onRestock,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Restock'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM),
                ),
              ),
            ],
          ),
          const Divider(height: AppTheme.spacingLG),
          Row(
            children: [
              _StockMetric(
                label: 'Quantity',
                value: '${stock.quantity} ${stock.unit}',
                color: isLow ? AppTheme.errorColor : AppTheme.successColor,
              ),
              _StockMetric(
                label: 'Min Level',
                value: '${stock.minThreshold} ${stock.unit}',
                color: AppTheme.textSecondary,
              ),
              _StockMetric(
                label: 'Value',
                value: '₦${stock.totalValue.toStringAsFixed(0)}',
                color: AppTheme.secondaryColor,
              ),
            ],
          ),
          if (stock.supplier != null || stock.expiryDate != null) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                if (stock.supplier != null)
                  _InfoTag(
                      icon: Icons.store, label: stock.supplier!),
                if (stock.expiryDate != null)
                  _InfoTag(
                      icon: Icons.event,
                      label: 'Exp: ${DateFormatter.formatShort(stock.expiryDate!)}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StockMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StockMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(
                  color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: AppTheme.spacingSM),
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─── Add Stock Sheet ──────────────────────────────────────────────────────────

class _AddStockSheet extends StatefulWidget {
  final String flockId;
  const _AddStockSheet({required this.flockId});

  @override
  State<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends State<_AddStockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minThresholdController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierController = TextEditingController();
  final _expiryController = TextEditingController();

  String _itemType = 'feed';
  String _unit = 'kg';
  bool _isSaving = false;

  final _itemTypes = ['feed', 'medicine', 'supplies'];
  final _units = ['kg', 'liters', 'units', 'packs', 'bags', 'bottles'];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _minThresholdController.dispose();
    _costController.dispose();
    _supplierController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await context.read<StockProvider>().addStock(
          flockId: widget.flockId,
          itemType: _itemType,
          itemName: _nameController.text,
          quantity: double.parse(_quantityController.text),
          unit: _unit,
          minThreshold: double.parse(_minThresholdController.text),
          costPerUnit: double.parse(_costController.text),
          supplier: _supplierController.text.isEmpty
              ? null
              : _supplierController.text,
          expiryDate: _expiryController.text.isEmpty
              ? null
              : _expiryController.text,
        );

    if (mounted) Navigator.pop(context);
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
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingMD,
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
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text('Add Stock Item', style: AppTheme.headingSmall),
              const SizedBox(height: AppTheme.spacingMD),
              // Type and unit row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _itemType,
                      decoration: AppTheme.inputDecoration('Type'),
                      items: _itemTypes
                          .map((t) =>
                              DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _itemType = v!),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                      decoration: AppTheme.inputDecoration('Unit'),
                      items: _units
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _nameController,
                decoration: AppTheme.inputDecoration('Item Name'),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter item name' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration:
                          AppTheme.inputDecoration('Current Quantity'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) =>
                          v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: TextFormField(
                      controller: _minThresholdController,
                      decoration:
                          AppTheme.inputDecoration('Min Threshold'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) =>
                          v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _costController,
                decoration:
                  AppTheme.inputDecoration('Cost per $_unit (₦)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _supplierController,
                decoration:
                    AppTheme.inputDecoration('Supplier (optional)'),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _expiryController,
                decoration: AppTheme.inputDecoration(
                    'Expiry Date (optional, e.g. 2026-12-31)'),
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
                      : const Text('Add Stock Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}