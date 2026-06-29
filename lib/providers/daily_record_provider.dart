// lib/providers/daily_record_provider.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_record.dart';
import '../services/database_service.dart';

class DailyRecordProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<DailyRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  List<DailyRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final Map<String, DailyRecord?> _latestRecords = {};
  final Map<String, int> _mortalityTotals = {};

  Map<String, DailyRecord?> get latestRecords =>
      Map.unmodifiable(_latestRecords);
  Map<String, int> get mortalityTotals => Map.unmodifiable(_mortalityTotals);

  DailyRecord? latestFor(String flockId) => _latestRecords[flockId];
  int mortalityTotalFor(String flockId) => _mortalityTotals[flockId] ?? 0;

  Future<void> loadRecords(String flockId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _records = await _db.getDailyRecordsByFlock(flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load records: $e';
      if (kDebugMode) debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLatestRecords(List<String> flockIds) async {
    if (flockIds.isEmpty) return;

    try {
      final futures = flockIds.map((flockId) async {
        try {
          final latest = await _db.getLatestRecordByFlock(flockId);
          _latestRecords[flockId] = latest;
        } catch (e) {
          _latestRecords[flockId] = null;
          if (kDebugMode) debugPrint('Failed latest for $flockId: $e');
        }
      });

      await Future.wait(futures);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('loadLatestRecords failed: $e');
      notifyListeners();
    }
  }

  Future<void> loadMortalityTotals(List<String> flockIds) async {
    if (flockIds.isEmpty) return;

    try {
      final futures = flockIds.map((flockId) async {
        try {
          _mortalityTotals[flockId] =
              (await _db.getTotalMortalityByFlock(flockId)).toInt();
        } catch (e) {
          _mortalityTotals[flockId] = 0;
          if (kDebugMode) debugPrint('Failed mortality total for $flockId: $e');
        }
      });

      await Future.wait(futures);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('loadMortalityTotals failed: $e');
      notifyListeners();
    }
  }

  Future<void> refreshLatest(String flockId) async {
    try {
      final latest = await _db.getLatestRecordByFlock(flockId);
      if (_latestRecords[flockId] != latest) {
        _latestRecords[flockId] = latest;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshMortalityTotal(String flockId) async {
    try {
      final totalResult = await _db.getTotalMortalityByFlock(flockId);
      final total = totalResult.toInt();
      if (_mortalityTotals[flockId] != total) {
        _mortalityTotals[flockId] = total;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addRecord({
    required String flockId,
    required String date,
    double? feedGiven,
    double? waterGiven,
    int? eggsCollected,
    int? mortalityCount,
    String? healthObservations,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();

      final safeFeed = feedGiven ?? 0.0;
      final safeWater = waterGiven ?? 0.0;
      final safeEggs = eggsCollected ?? 0;
      final safeMortality = mortalityCount ?? 0;

      final record = DailyRecord(
        id: const Uuid().v4(),
        flockId: flockId,
        date: date,
        feedGiven: safeFeed,
        waterGiven: safeWater,
        eggsCollected: safeEggs,
        mortalityCount: safeMortality,
        healthObservations: healthObservations?.trim().isEmpty ?? true
            ? null
            : healthObservations!.trim(),
        notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _db.createDailyRecord(record);
      _records.insert(0, record);
      await refreshLatest(flockId);
      await refreshMortalityTotal(flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to add record: $e';
      if (kDebugMode) debugPrint('ADD RECORD ERROR: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateRecord(DailyRecord record) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = record.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        feedGiven: record.feedGiven ?? 0.0,
        waterGiven: record.waterGiven ?? 0.0,
        eggsCollected: record.eggsCollected ?? 0,
        mortalityCount: record.mortalityCount ?? 0,
      );

      await _db.updateDailyRecord(updated);

      final index = _records.indexWhere((r) => r.id == record.id);
      if (index != -1) _records[index] = updated;

      await refreshLatest(record.flockId);
      await refreshMortalityTotal(record.flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to update record: $e';
      if (kDebugMode) debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String recordId, String flockId) async {
    try {
      await _db.deleteDailyRecord(recordId);
      _records.removeWhere((r) => r.id == recordId);
      await refreshLatest(flockId);
      await refreshMortalityTotal(flockId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete record: $e';
      notifyListeners();
    }
  }

  // ── Computed stats (safe against nulls) ────────────────────────────────────
  int get totalMortality =>
      _records.fold(0, (sum, r) => sum + (r.mortalityCount ?? 0));

  int get totalEggs =>
      _records.fold(0, (sum, r) => sum + (r.eggsCollected ?? 0));

  double get totalFeed =>
      _records.fold(0.0, (sum, r) => sum + (r.feedGiven ?? 0.0));

  double get totalWater =>
      _records.fold(0.0, (sum, r) => sum + (r.waterGiven ?? 0.0));

  double get avgFeedPerRecord =>
      _records.isEmpty ? 0.0 : totalFeed / _records.length;

  double get mortalityRatePercent {
    if (_records.isEmpty) return 0.0;
    final totalMortalityCount = totalMortality;
    // Approximate initial birds (rough: sum of mortalities + average daily birds)
    final approxInitial =
        _records.fold(0, (sum, r) => sum + (r.mortalityCount ?? 0) + 100);
    return (totalMortalityCount / approxInitial) * 100;
  }
}
