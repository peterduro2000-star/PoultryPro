import 'package:flutter/foundation.dart';

import '../models/flock.dart';
import '../models/daily_record.dart';
import '../services/alerts_service.dart';
import '../services/database_service.dart';

class AlertsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  final Map<String, List<FarmAlert>> _alertsByFlock = {};
  bool _isLoading = false;

  List<FarmAlert> alertsForFlock(String flockId) =>
      _alertsByFlock[flockId] ?? [];

  List<FarmAlert> get allAlerts => _alertsByFlock.values
      .expand((alerts) => alerts)
      .toList()
    ..sort((a, b) => a.level.index.compareTo(b.level.index));

  int get criticalCount =>
      allAlerts.where((a) => a.level == AlertLevel.critical).length;

  int get totalCount => allAlerts.length;
  bool get hasAlerts => allAlerts.isNotEmpty;
  bool get hasCritical => criticalCount > 0;
  bool get isLoading => _isLoading;

  // ─── Reset (on auth change) ────────────────────────────────────────────────
  /// Clears all in-memory alert state. Called when the authenticated user
  /// changes so no data leaks between accounts.
  void reset() {
    _alertsByFlock.clear();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAlertsForFlock({
    required Flock flock,
    required List<DailyRecord> records,
    required double recoveryPercentage,
    bool isPro = false,
  }) async {
    try {
      final stockItems = await _db.getStockByFlock(flock.id);
      _alertsByFlock[flock.id] = AlertsService.generateAlerts(
        flock: flock,
        records: records,
        stockItems: stockItems,
        recoveryPercentage: recoveryPercentage,
        isPro: isPro,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('AlertsProvider: failed for ${flock.id}: $e');
    }
  }

  Future<void> refreshAllAlerts({
    required List<Flock> flocks,
    required Map<String, List<DailyRecord>> recordsByFlock,
    required Map<String, double> recoveryByFlock,
    bool isPro = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    for (final flock in flocks) {
      await refreshAlertsForFlock(
        flock: flock,
        records: recordsByFlock[flock.id] ?? [],
        recoveryPercentage: recoveryByFlock[flock.id] ?? 0,
        isPro: isPro,
      );
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearForFlock(String flockId) {
    _alertsByFlock.remove(flockId);
    notifyListeners();
  }
}