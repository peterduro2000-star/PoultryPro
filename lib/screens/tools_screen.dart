import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Tools & Calculators')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          Text('Calculators', style: AppTheme.headingSmall),
          const SizedBox(height: AppTheme.spacingMD),
          _ToolCard(
            icon: Icons.calculate,
            title: 'FCR Calculator',
            subtitle: 'Feed Conversion Ratio',
            color: AppTheme.primaryColor,
            onTap: () => _showFCRCalculator(context),
          ),
          _ToolCard(
            icon: Icons.set_meal,
            title: 'Feed Cost Calculator',
            subtitle: 'Daily feed needs & cost',
            color: AppTheme.secondaryColor,
            onTap: () => _showFeedCostCalculator(context),
          ),
          _ToolCard(
            icon: Icons.egg,
            title: 'Egg Production Rate',
            subtitle: 'Laying percentage',
            color: AppTheme.accentColor,
            onTap: () => _showEggProductionCalculator(context),
          ),
          _ToolCard(
            icon: Icons.warning,
            title: 'Mortality Rate',
            subtitle: 'Death rate calculator',
            color: AppTheme.errorColor,
            onTap: () => _showMortalityCalculator(context),
          ),
          _ToolCard(
            icon: Icons.trending_up,
            title: 'Break-even Calculator',
            subtitle: 'Minimum selling price',
            color: AppTheme.infoColor,
            onTap: () => _showBreakEvenCalculator(context),
          ),
        ],
      ),
    );
  }

  // ─── FCR Calculator ────────────────────────────────────────────────────────

  void _showFCRCalculator(BuildContext context) {
    final feedController = TextEditingController();
    final weightController = TextEditingController();

    _showCalculatorSheet(
      context: context,
      title: 'FCR Calculator',
      subtitle: 'FCR = Total Feed Consumed ÷ Total Weight Gained',
      icon: Icons.calculate,
      color: AppTheme.primaryColor,
      fields: [
        _FieldConfig('Total Feed Consumed (kg)', feedController),
        _FieldConfig('Total Weight Gained (kg)', weightController),
      ],
      calculate: () {
        final feed = double.tryParse(feedController.text);
        final weight = double.tryParse(weightController.text);
        if (feed == null || weight == null || weight == 0) return null;
        final fcr = feed / weight;
        String rating;
        Color ratingColor;
        if (fcr < 1.8) {
          rating = 'Excellent';
          ratingColor = AppTheme.successColor;
        } else if (fcr < 2.2) {
          rating = 'Good';
          ratingColor = AppTheme.secondaryColor;
        } else if (fcr < 2.8) {
          rating = 'Average';
          ratingColor = AppTheme.warningColor;
        } else {
          rating = 'Poor';
          ratingColor = AppTheme.errorColor;
        }
        return _CalcResult(
          mainValue: fcr.toStringAsFixed(2),
          mainLabel: 'FCR',
          note: 'Rating: $rating',
          noteColor: ratingColor,
          explanation:
              'For every 1kg of weight gained, ${fcr.toStringAsFixed(2)}kg of feed was consumed.',
        );
      },
    );
  }

  // ─── Feed Cost Calculator ──────────────────────────────────────────────────

  void _showFeedCostCalculator(BuildContext context) {
    final birdsController = TextEditingController();
    final feedPerBirdController = TextEditingController();
    final costPerKgController = TextEditingController();

    _showCalculatorSheet(
      context: context,
      title: 'Feed Cost Calculator',
      subtitle: 'Daily feed requirement and cost',
      icon: Icons.set_meal,
      color: AppTheme.secondaryColor,
      fields: [
        _FieldConfig('Number of Birds', birdsController),
        _FieldConfig('Feed per Bird per Day (g)', feedPerBirdController),
        _FieldConfig('Feed Cost per kg (₦)', costPerKgController),
      ],
      calculate: () {
        final birds = double.tryParse(birdsController.text);
        final feedPerBird = double.tryParse(feedPerBirdController.text);
        final costPerKg = double.tryParse(costPerKgController.text);
        if (birds == null || feedPerBird == null || costPerKg == null) {
          return null;
        }
        final dailyFeedKg = (birds * feedPerBird) / 1000;
        final dailyCost = dailyFeedKg * costPerKg;
        final monthlyCost = dailyCost * 30;
        return _CalcResult(
          mainValue: CurrencyFormatter.format(dailyCost),
          mainLabel: 'Daily Feed Cost',
          note: 'Monthly estimate: ${CurrencyFormatter.format(monthlyCost)}',
          noteColor: AppTheme.secondaryColor,
          explanation:
              '${dailyFeedKg.toStringAsFixed(1)}kg of feed needed daily for ${birds.toInt()} birds.',
        );
      },
    );
  }

  // ─── Egg Production Rate ───────────────────────────────────────────────────

  void _showEggProductionCalculator(BuildContext context) {
    final eggsController = TextEditingController();
    final birdsController = TextEditingController();

    _showCalculatorSheet(
      context: context,
      title: 'Egg Production Rate',
      subtitle: 'Laying percentage = Eggs ÷ Birds × 100',
      icon: Icons.egg,
      color: AppTheme.accentColor,
      fields: [
        _FieldConfig('Eggs Collected Today', eggsController),
        _FieldConfig('Number of Laying Birds', birdsController),
      ],
      calculate: () {
        final eggs = double.tryParse(eggsController.text);
        final birds = double.tryParse(birdsController.text);
        if (eggs == null || birds == null || birds == 0) return null;
        final rate = (eggs / birds) * 100;
        String rating;
        Color ratingColor;
        if (rate >= 80) {
          rating = 'Excellent';
          ratingColor = AppTheme.successColor;
        } else if (rate >= 65) {
          rating = 'Good';
          ratingColor = AppTheme.secondaryColor;
        } else if (rate >= 50) {
          rating = 'Average';
          ratingColor = AppTheme.warningColor;
        } else {
          rating = 'Low — investigate';
          ratingColor = AppTheme.errorColor;
        }
        return _CalcResult(
          mainValue: '${rate.toStringAsFixed(1)}%',
          mainLabel: 'Laying Rate',
          note: 'Performance: $rating',
          noteColor: ratingColor,
          explanation:
              '${eggs.toInt()} eggs from ${birds.toInt()} birds today.',
        );
      },
    );
  }

  // ─── Mortality Rate ────────────────────────────────────────────────────────

  void _showMortalityCalculator(BuildContext context) {
    final deathsController = TextEditingController();
    final startingController = TextEditingController();
    final daysController = TextEditingController();

    _showCalculatorSheet(
      context: context,
      title: 'Mortality Rate',
      subtitle: 'Deaths ÷ Starting birds × 100',
      icon: Icons.warning,
      color: AppTheme.errorColor,
      fields: [
        _FieldConfig('Number of Deaths', deathsController),
        _FieldConfig('Starting Bird Count', startingController),
        _FieldConfig('Number of Days', daysController),
      ],
      calculate: () {
        final deaths = double.tryParse(deathsController.text);
        final starting = double.tryParse(startingController.text);
        final days = double.tryParse(daysController.text);
        if (deaths == null || starting == null || starting == 0) return null;
        final totalRate = (deaths / starting) * 100;
        final dailyRate = days != null && days > 0 ? totalRate / days : null;
        String rating;
        Color ratingColor;
        if (totalRate <= 2) {
          rating = 'Normal';
          ratingColor = AppTheme.successColor;
        } else if (totalRate <= 5) {
          rating = 'Acceptable';
          ratingColor = AppTheme.warningColor;
        } else {
          rating = 'High — take action';
          ratingColor = AppTheme.errorColor;
        }
        return _CalcResult(
          mainValue: '${totalRate.toStringAsFixed(2)}%',
          mainLabel: 'Mortality Rate',
          note: 'Status: $rating',
          noteColor: ratingColor,
          explanation: dailyRate != null
              ? 'Daily average: ${dailyRate.toStringAsFixed(3)}% over ${days!.toInt()} days.'
              : '${deaths.toInt()} deaths from ${starting.toInt()} birds.',
        );
      },
    );
  }

  // ─── Break-even Calculator ─────────────────────────────────────────────────

  void _showBreakEvenCalculator(BuildContext context) {
    final totalCostController = TextEditingController();
    final unitsController = TextEditingController();
    final unitTypeController = TextEditingController();

    _showCalculatorSheet(
      context: context,
      title: 'Break-even Calculator',
      subtitle: 'Minimum price to recover costs',
      icon: Icons.trending_up,
      color: AppTheme.infoColor,
      fields: [
        _FieldConfig('Total Cost (₦)', totalCostController),
        _FieldConfig('Expected Units to Sell', unitsController),
        _FieldConfig('Unit (e.g. crates, birds, kg)', unitTypeController,
            isNumber: false),
      ],
      calculate: () {
        final cost = double.tryParse(totalCostController.text);
        final units = double.tryParse(unitsController.text);
        final unitType =
            unitTypeController.text.isEmpty ? 'unit' : unitTypeController.text;
        if (cost == null || units == null || units == 0) return null;
        final breakEven = cost / units;
        final withProfit10 = breakEven * 1.10;
        final withProfit20 = breakEven * 1.20;
        return _CalcResult(
          mainValue: CurrencyFormatter.format(breakEven),
          mainLabel: 'Break-even per $unitType',
          note:
              '10% profit: ${CurrencyFormatter.format(withProfit10)} | 20% profit: ${CurrencyFormatter.format(withProfit20)}',
          noteColor: AppTheme.infoColor,
          explanation:
              'Sell at ${CurrencyFormatter.format(breakEven)} per $unitType to recover ${CurrencyFormatter.format(cost)} across ${units.toInt()} ${unitType}s.',
        );
      },
    );
  }

  // ─── Shared Calculator Sheet ───────────────────────────────────────────────

  void _showCalculatorSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<_FieldConfig> fields,
    required _CalcResult? Function() calculate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalculatorSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        fields: fields,
        calculate: calculate,
      ),
    );
  }
}

// ─── Tool Card ────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
        decoration: AppTheme.cardDecoration,
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Calculator Sheet ─────────────────────────────────────────────────────────

class _CalculatorSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_FieldConfig> fields;
  final _CalcResult? Function() calculate;

  const _CalculatorSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.fields,
    required this.calculate,
  });

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  _CalcResult? _result;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 24),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: AppTheme.headingSmall),
                      Text(widget.subtitle, style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLG),
            // Input fields
            ...widget.fields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                  child: TextField(
                    controller: field.controller,
                    decoration: AppTheme.inputDecoration(field.label),
                    keyboardType: field.isNumber
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    onChanged: (_) => setState(() => _result = null),
                  ),
                )),
            // Calculate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppTheme.primaryButtonStyle,
                onPressed: () {
                  setState(() => _result = widget.calculate());
                },
                child: const Text('Calculate'),
              ),
            ),
            // Result
            if (_result != null) ...[
              const SizedBox(height: AppTheme.spacingLG),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: widget.color.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      _result!.mainValue,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                    Text(_result!.mainLabel, style: AppTheme.bodySmall),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      _result!.note,
                      style: AppTheme.bodyMedium.copyWith(
                          color: _result!.noteColor,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      _result!.explanation,
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingMD),
          ],
        ),
      ),
    );
  }
}

// ─── Helper classes ───────────────────────────────────────────────────────────

class _FieldConfig {
  final String label;
  final TextEditingController controller;
  final bool isNumber;

  _FieldConfig(this.label, this.controller, {this.isNumber = true});
}

class _CalcResult {
  final String mainValue;
  final String mainLabel;
  final String note;
  final Color noteColor;
  final String explanation;

  _CalcResult({
    required this.mainValue,
    required this.mainLabel,
    required this.note,
    required this.noteColor,
    required this.explanation,
  });
}
