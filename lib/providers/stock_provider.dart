import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/stock.dart';
import '../services/database_service.dart';

class StockProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Stock> _stocks = [];
  List<Stock> _lowStockAlerts = [];
  bool _isLoading = false;
  String? _error;

  List<Stock> get stocks => _stocks;
  List<Stock> get lowStockAlerts => _lowStockAlerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Reset (on auth change) ────────────────────────────────────────────────
  /// Clears all in-memory stock state. Called when the authenticated user
  /// changes so no data leaks between accounts.
  void reset() {
    _stocks = [];
    _lowStockAlerts = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStock(String flockId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stocks = await _db.getStockByFlock(flockId);
      _lowStockAlerts = await _db.getLowStockAlerts(flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load stock: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStock({
    required String flockId,
    required String itemType,
    required String itemName,
    required double quantity,
    required String unit,
    required double minThreshold,
    required double costPerUnit,
    String? supplier,
    String? expiryDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      final stock = Stock(
        id: const Uuid().v4(),
        flockId: flockId,
        itemType: itemType,
        itemName: itemName,
        quantity: quantity,
        unit: unit,
        minThreshold: minThreshold,
        costPerUnit: costPerUnit,
        supplier: supplier,
        lastRestockDate: now,
        expiryDate: expiryDate,
        createdAt: now,
        updatedAt: now,
      );

      await _db.createStock(stock);
      _stocks.add(stock);
      
      if (stock.isLowStock) {
        _lowStockAlerts.add(stock);
      }
      
      _error = null;
    } catch (e) {
      _error = 'Failed to add stock: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStock(Stock stock) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updated = stock.copyWith(updatedAt: DateTime.now().toIso8601String());
      await _db.updateStock(updated);
      
      final index = _stocks.indexWhere((s) => s.id == stock.id);
      if (index != -1) {
        _stocks[index] = updated;
      }
      
      // Update low stock alerts
      _lowStockAlerts.removeWhere((s) => s.id == stock.id);
      if (updated.isLowStock) {
        _lowStockAlerts.add(updated);
      }
      
      _error = null;
    } catch (e) {
      _error = 'Failed to update stock: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get totalStockValue => _stocks.fold(0, (sum, s) => sum + s.totalValue);

  int get alertCount => _lowStockAlerts.length;

  bool get hasAlerts => _lowStockAlerts.isNotEmpty;
}
