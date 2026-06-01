import '../models/daily_record.dart';
import '../models/flock.dart';
import '../models/stock.dart';

enum AlertLevel { info, warning, critical }

class FarmAlert {
  final String id;
  final String flockId;
  final String flockName;
  final AlertLevel level;
  final String title;
  final String message;
  final String? actionLabel;

  const FarmAlert({
    required this.id,
    required this.flockId,
    required this.flockName,
    required this.level,
    required this.title,
    required this.message,
    this.actionLabel,
  });
}

class AlertsService {
  AlertsService._();

  /// Generates all active alerts for a given flock.
  /// Call this whenever records, stock, or flock data changes.
  static List<FarmAlert> generateAlerts({
    required Flock flock,
    required List<DailyRecord> records,
    required List<Stock> stockItems,
    required double recoveryPercentage,
  }) {
    final alerts = <FarmAlert>[];

    alerts.addAll(_missedRecordAlerts(flock, records));
    alerts.addAll(_mortalitySpikeAlerts(flock, records));
    alerts.addAll(_vaccinationAlerts(flock));
    alerts.addAll(_breakEvenAlerts(flock, recoveryPercentage));
    alerts.addAll(_lowStockAlerts(flock, stockItems));
    alerts.addAll(_fcrAlerts(flock, records));

    // Sort: critical first, then warning, then info
    alerts.sort((a, b) => a.level.index.compareTo(b.level.index));
    return alerts;
  }

  // ─── Missed record alert ───────────────────────────────────────────────────

  static List<FarmAlert> _missedRecordAlerts(
      Flock flock, List<DailyRecord> records) {
    if (flock.status != 'active') return [];
    if (records.isEmpty) {
      return [
        FarmAlert(
          id: 'no_records_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: AlertLevel.warning,
          title: 'No records yet',
          message:
              'Start recording daily data for ${flock.name} to track performance.',
          actionLabel: 'Add Record',
        ),
      ];
    }

    final latest = records.first;
    final latestDate = DateTime.tryParse(latest.date);
    if (latestDate == null) return [];

    final daysMissed = DateTime.now()
        .difference(latestDate)
        .inDays;

    if (daysMissed >= 3) {
      return [
        FarmAlert(
          id: 'missed_records_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: daysMissed >= 5 ? AlertLevel.critical : AlertLevel.warning,
          title: '$daysMissed days without a record',
          message:
              '${flock.name} has not been recorded since ${latest.date}. '
              'Missing data affects your profit analysis.',
          actionLabel: 'Add Record',
        ),
      ];
    }
    return [];
  }

  // ─── Mortality spike alert ─────────────────────────────────────────────────

  static List<FarmAlert> _mortalitySpikeAlerts(
      Flock flock, List<DailyRecord> records) {
    if (records.length < 3) return [];

    // Today's mortality
    final todayRecord = records.first;
    final todayMortality = todayRecord.mortalityCount ?? 0;
    if (todayMortality == 0) return [];

    // 7-day average (excluding today)
    final previous = records.skip(1).take(7).toList();
    if (previous.isEmpty) return [];

    final avgMortality = previous.fold<int>(
            0, (sum, r) => sum + (r.mortalityCount ?? 0)) /
        previous.length;

    if (avgMortality <= 0) return [];

    final ratio = todayMortality / avgMortality;

    if (ratio >= 3) {
      return [
        FarmAlert(
          id: 'mortality_spike_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: ratio >= 5 ? AlertLevel.critical : AlertLevel.warning,
          title: 'Mortality spike detected',
          message:
              '${flock.name}: $todayMortality deaths today vs '
              '${avgMortality.toStringAsFixed(1)} daily average. '
              'Check for disease, feed quality, or ventilation issues.',
          actionLabel: 'Log Health Event',
        ),
      ];
    }
    return [];
  }

  // ─── Vaccination alerts ────────────────────────────────────────────────────

  static List<FarmAlert> _vaccinationAlerts(Flock flock) {
    if (flock.status != 'active') return [];

    final next = flock.nextVaccination;
    if (next == null) return [];

    final daysLeft = next.daysUntil(flock.currentAgeDays);

    if (daysLeft <= 0) {
      return [
        FarmAlert(
          id: 'vax_overdue_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: AlertLevel.critical,
          title: 'Vaccination overdue',
          message:
              '${flock.name}: ${next.name} was due '
              '${(-daysLeft)} day${-daysLeft == 1 ? '' : 's'} ago.',
          actionLabel: 'Log Health Event',
        ),
      ];
    }

    if (daysLeft <= 3) {
      return [
        FarmAlert(
          id: 'vax_due_soon_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: AlertLevel.warning,
          title: 'Vaccination due soon',
          message:
              '${flock.name}: ${next.name} due in '
              '$daysLeft day${daysLeft == 1 ? '' : 's'}.',
          actionLabel: 'View Schedule',
        ),
      ];
    }
    return [];
  }

  // ─── Break-even alert ──────────────────────────────────────────────────────

  static List<FarmAlert> _breakEvenAlerts(
      Flock flock, double recoveryPercentage) {
    if (flock.status != 'active') return [];

    // Only relevant after week 4 for broilers, week 18 for layers
    final isBroiler = flock.type.toLowerCase().contains('broiler');
    final warningWeek = isBroiler ? 4 : 18;

    if (flock.currentAgeWeeks < warningWeek) return [];
    if (recoveryPercentage >= 50) return [];

    return [
      FarmAlert(
        id: 'low_recovery_${flock.id}',
        flockId: flock.id,
        flockName: flock.name,
        level: AlertLevel.warning,
        title: 'Low cost recovery',
        message:
            '${flock.name} has only recovered '
            '${recoveryPercentage.toStringAsFixed(0)}% of costs '
            'at week ${flock.currentAgeWeeks}. '
            'Review your sales strategy.',
        actionLabel: 'View Finance',
      ),
    ];
  }

  // ─── Low stock alerts ──────────────────────────────────────────────────────

  static List<FarmAlert> _lowStockAlerts(
      Flock flock, List<Stock> stockItems) {
    return stockItems
        .where((s) => s.isLowStock && !s.deleted)
        .map((s) => FarmAlert(
              id: 'low_stock_${s.id}',
              flockId: flock.id,
              flockName: flock.name,
              level: s.quantity <= 0
                  ? AlertLevel.critical
                  : AlertLevel.warning,
              title: s.quantity <= 0
                  ? '${s.itemName} is out of stock'
                  : '${s.itemName} running low',
              message: s.quantity <= 0
                  ? '${flock.name}: ${s.itemName} is completely out. Restock immediately.'
                  : '${flock.name}: ${s.itemName} has ${s.quantity} ${s.unit} '
                      'remaining (min: ${s.minThreshold} ${s.unit}).',
              actionLabel: 'Restock',
            ))
        .toList();
  }

  // ─── FCR alert ────────────────────────────────────────────────────────────

  static List<FarmAlert> _fcrAlerts(
      Flock flock, List<DailyRecord> records) {
    if (records.length < 7) return [];
    if (!flock.type.toLowerCase().contains('broiler')) return [];

    // FCR = total feed given ÷ estimated weight gain
    // We use averageWeight if available, otherwise skip
    final withWeight =
        records.where((r) => r.averageWeight != null && r.averageWeight! > 0);
    if (withWeight.length < 2) return [];

    final totalFeed =
        records.fold<double>(0, (s, r) => s + (r.feedGiven ?? 0));
    final firstWeight = withWeight.last.averageWeight!;
    final latestWeight = withWeight.first.averageWeight!;
    final weightGainKg =
        (latestWeight - firstWeight) * flock.birdCount;

    if (weightGainKg <= 0) return [];

    final fcr = totalFeed / weightGainKg;

    // Benchmark: good broiler FCR is 1.6–2.0, poor is > 2.5
    if (fcr > 2.5) {
      return [
        FarmAlert(
          id: 'high_fcr_${flock.id}',
          flockId: flock.id,
          flockName: flock.name,
          level: AlertLevel.warning,
          title: 'High feed conversion ratio',
          message:
              '${flock.name} FCR is ${fcr.toStringAsFixed(2)} '
              '(target: below 2.0). '
              'Check feed quality, wastage, or bird health.',
          actionLabel: 'View Records',
        ),
      ];
    }
    return [];
  }
}