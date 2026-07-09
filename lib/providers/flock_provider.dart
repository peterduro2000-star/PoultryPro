import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/flock.dart';
import '../services/database_service.dart';
import '../providers/license_provider.dart';
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
  
  /// Returns true if the user has reached the free tier limit (1 flock)
  bool get hasReachedLimit => _flocks.length >= 1;

  // ─── Load Flocks ──────────────────────────────────────────────────────────
  Future<void> loadFlocks({String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final db = DatabaseService();
      _flocks = await db.getAllFlocks();

      // Restore a previously selected flock that BELONGS TO THE CURRENT USER.
      // Selection is persisted under a user-specific key so a flock selected
      // by one account can never leak into another account.
      final effectiveUserId =
          userId ?? Supabase.instance.client.auth.currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_selectedFlockKey(effectiveUserId));

      if (savedId != null) {
        final match = _flocks.where((f) => f.id == savedId);
        _selectedFlock = match.isNotEmpty
            ? match.first
            : (_flocks.isNotEmpty ? _flocks.first : null);
      } else if (_flocks.isNotEmpty) {
        _selectedFlock = _flocks.first;
      } else {
        _selectedFlock = null;
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

  // ─── Reset (on auth change) ────────────────────────────────────────────────
  /// Clears all in-memory state. Called when the authenticated user changes so
  /// that no flock/selection from the previous account is carried over.
  void reset() {
    _flocks = [];
    _selectedFlock = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  String _selectedFlockKey(String? userId) => 'selected_flock_$userId';

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
    required BuildContext context,
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
      final isPro = context.read<LicenseProvider>().isPro;

      if (!isPro && _flocks.length >= 1) {
        _error =
            'Free tier only allows 1 flock. Upgrade to Pro for unlimited flocks.';
        notifyListeners();
        return;
      }
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

      // Keep the selected flock in sync if the updated flock is currently selected.
      if (_selectedFlock?.id == flock.id) {
        _selectedFlock = flock;
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
    // Persist selection under the current user's key so it cannot bleed into
    // another account.
    final userId = Supabase.instance.client.auth.currentUser?.id;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_selectedFlockKey(userId), flock.id));
  }

  void clearSelection() {
    _selectedFlock = null;
    notifyListeners();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    SharedPreferences.getInstance()
        .then((p) => p.remove(_selectedFlockKey(userId)));
  }

  /// Removes any persisted flock selection for the CURRENT user.
  /// Call this on logout so the outgoing account's selection does not survive.
  Future<void> clearPersistedSelectionForCurrentUser() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedFlockKey(userId));
    await prefs.remove('selected_flock_id'); // legacy global key cleanup
  }

  // ─── Clear Error ──────────────────────────────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
