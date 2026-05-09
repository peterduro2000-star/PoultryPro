import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/flock.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlockProvider extends ChangeNotifier {
  List<Flock> _flocks = [];
  Flock? _selectedFlock;
  bool _isLoading = false;
  String? _error;

  List<Flock> get flocks => _flocks;
  Flock? get selectedFlock => _selectedFlock;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Computed properties
  int get activeFlockCount => _flocks.where((f) => f.status == 'active').length;
  int get totalBirds => _flocks.fold(0, (sum, f) => sum + f.birdCount);
  double get totalInitialCost =>
      _flocks.fold(0.0, (sum, f) => sum + f.initialCost);

  // ─── Load Flocks ──────────────────────────────────────────────────────────
  Future<void> loadFlocks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = DatabaseService();
      _flocks = await db.getAllFlocks();

      // Restore previously selected flock
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('selected_flock_id');
      if (savedId != null) {
        _selectedFlock = _flocks.firstWhere(
          (f) => f.id == savedId,
          orElse: () => _flocks.isNotEmpty ? _flocks.first : _selectedFlock!,
        );
      } else if (_flocks.isNotEmpty && _selectedFlock == null) {
        _selectedFlock = _flocks.first;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load flocks: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Create Flock (Full Object) ────────────────────────────────────────────
  Future<void> createFlock(Flock flock) async {
    try {
      final db = DatabaseService();
      await db.createFlock(flock);
      _flocks.add(flock);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create flock: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ─── Create Flock From Form ───────────────────────────────────────────────
  /// Creates a new Flock with all required and optional fields from form input.
  /// Generates UUID, startDate, and timestamps automatically.
  Future<void> createFlockFromForm({
    required String name,
    required String type,
    required int birdCount,
    required double costPerBird,
    required String startDate,
    int ageAtStocking = 0,
    String? breed,
    String? source,
    String? housingType,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final newFlock = Flock(
        id: const Uuid().v4(),
        name: name,
        type: type,
        birdCount: birdCount,
        initialBirdCount: birdCount,
        costPerBird: costPerBird,
        startDate: startDate,
        ageAtStocking: ageAtStocking,
        status: 'active',
        breed: breed,
        source: source,
        housingType: housingType,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        userId: null,
      );

      await createFlock(newFlock);
    } catch (e) {
      _error = 'Failed to create flock: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ─── Update Flock ─────────────────────────────────────────────────────────
  Future<void> updateFlock(Flock flock) async {
    try {
      final db = DatabaseService();
      await db.updateFlock(flock);

      // Update in local list
      final index = _flocks.indexWhere((f) => f.id == flock.id);
      if (index != -1) {
        _flocks[index] = flock;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update flock: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ─── Delete Flock ─────────────────────────────────────────────────────────
  Future<void> deleteFlock(String flockId) async {
    try {
      final db = DatabaseService();
      await db.deleteFlock(flockId);

      // Remove from local list
      _flocks.removeWhere((f) => f.id == flockId);

      // Clear selection if deleted flock was selected
      if (_selectedFlock?.id == flockId) {
        _selectedFlock = null;
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete flock: $e';
      notifyListeners();
      rethrow;
    }
  }

  // ─── Select Flock ─────────────────────────────────────────────────────────
  void selectFlock(Flock flock) {
    _selectedFlock = flock;
    notifyListeners();
    // persist selection
    SharedPreferences.getInstance()
        .then((p) => p.setString('selected_flock_id', flock.id));
  }

  void clearSelection() {
    _selectedFlock = null;
    notifyListeners();
  }

  // ─── Clear Error ──────────────────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
