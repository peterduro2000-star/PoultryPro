import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/health_event.dart';
import '../services/database_service.dart';

class HealthProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<HealthEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  List<HealthEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Reset (on auth change) ────────────────────────────────────────────────
  /// Clears all in-memory health state. Called when the authenticated user
  /// changes so no data leaks between accounts.
  void reset() {
    _events = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadHealthEvents(String flockId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _events = await _db.getHealthEventsByFlock(flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load health events: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addHealthEvent({
    required String flockId,
    required String date,
    required String eventType,
    required String description,
    String? severity,
    int? affectedBirds,
    String? medicine,
    String? dosage,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      final event = HealthEvent(
        id: const Uuid().v4(),
        flockId: flockId,
        date: date,
        eventType: eventType,
        description: description,
        severity: severity,
        affectedBirds: affectedBirds,
        medicine: medicine,
        dosage: dosage,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _db.createHealthEvent(event);
      _events.insert(0, event);
      _error = null;
    } catch (e) {
      _error = 'Failed to add health event: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<HealthEvent> get recentEvents => _events.take(10).toList();

  List<HealthEvent> get highSeverityEvents => _events.where((e) => e.severity == 'high').toList();

  int get totalAffectedBirds => _events.fold(0, (sum, e) => sum + (e.affectedBirds ?? 0));
}
