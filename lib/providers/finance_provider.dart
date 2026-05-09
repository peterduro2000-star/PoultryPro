// lib/providers/finance_provider.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/sale.dart';
import '../services/database_service.dart';
import '../providers/flock_provider.dart';
import '../utils/currency_formatter.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  List<Expense> _expenses = [];
  List<Sale> _sales = [];
  List<Expense> _farmExpenses = [];
  List<Sale> _farmSales = [];
  bool _isLoading = false;
  bool _isFarmFinanceLoading = false;
  String? _error;
  String? _farmFinanceError;

  List<Expense> get expenses => _expenses;
  List<Sale> get sales => _sales;
  List<Expense> get farmExpenses => _farmExpenses;
  List<Sale> get farmSales => _farmSales;
  bool get isLoading => _isLoading;
  bool get isFarmFinanceLoading => _isFarmFinanceLoading;
  String? get error => _error;
  String? get farmFinanceError => _farmFinanceError;

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get totalSales => _sales.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get profit => totalSales - totalExpenses;
  double get farmTotalExpenses =>
      _farmExpenses.fold(0.0, (sum, e) => sum + e.amount);
  double get farmTotalSales =>
      _farmSales.fold(0.0, (sum, s) => sum + s.totalAmount);
  double get farmProfit => farmTotalSales - farmTotalExpenses;

  String get profitDisplay {
    final p = profit;
    return CurrencyFormatter.formatSigned(p);
  }

  double get profitMargin => totalSales > 0 ? (profit / totalSales * 100) : 0.0;

  String get profitMarginDisplay => '${profitMargin.toStringAsFixed(1)}%';

  double get farmProfitMargin =>
      farmTotalSales > 0 ? (farmProfit / farmTotalSales * 100) : 0.0;

  String get farmProfitDisplay {
    final p = farmProfit;
    return CurrencyFormatter.formatSigned(p);
  }

  String get farmProfitMarginDisplay =>
      '${farmProfitMargin.toStringAsFixed(1)}%';

  double remainingCost() {
    final value = totalExpenses - totalSales;
    return value > 0 ? value : 0.0;
  }

  String get remainingCostDisplay => CurrencyFormatter.format(remainingCost());

  double recoveryPercentage() {
    if (totalExpenses <= 0) return 0.0;
    return totalSales / totalExpenses * 100;
  }

  String get recoveryPercentageDisplay =>
      '${recoveryPercentage().toStringAsFixed(1)}%';

  double farmRemainingCost() {
    final value = farmTotalExpenses - farmTotalSales;
    return value > 0 ? value : 0.0;
  }

  String get farmRemainingCostDisplay =>
      CurrencyFormatter.format(farmRemainingCost());

  double farmRecoveryPercentage() {
    if (farmTotalExpenses <= 0) return 0.0;
    return farmTotalSales / farmTotalExpenses * 100;
  }

  String get farmRecoveryPercentageDisplay =>
      '${farmRecoveryPercentage().toStringAsFixed(1)}%';

  List<Expense> farmExpensesForFlock(String flockId) {
    return _farmExpenses.where((e) => e.flockId == flockId).toList();
  }

  List<Sale> farmSalesForFlock(String flockId) {
    return _farmSales.where((s) => s.flockId == flockId).toList();
  }

  double totalExpensesForFlock(String flockId) {
    return farmExpensesForFlock(flockId).fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalSalesForFlock(String flockId) {
    return farmSalesForFlock(flockId)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  double remainingCostForFlock(String flockId) {
    final value = totalExpensesForFlock(flockId) - totalSalesForFlock(flockId);
    return value > 0 ? value : 0.0;
  }

  String remainingCostForFlockDisplay(String flockId) {
    return CurrencyFormatter.format(remainingCostForFlock(flockId));
  }

  double breakEvenPerBirdForFlock({
    required String flockId,
    required int currentBirds,
  }) {
    if (currentBirds <= 0) return 0.0;
    if (totalSalesForFlock(flockId) >= totalExpensesForFlock(flockId)) {
      return 0.0;
    }
    return remainingCostForFlock(flockId) / currentBirds;
  }

  String breakEvenPerBirdForFlockDisplay({
    required String flockId,
    required int currentBirds,
  }) {
    final value = breakEvenPerBirdForFlock(
      flockId: flockId,
      currentBirds: currentBirds,
    );
    return CurrencyFormatter.format(value);
  }

  double recoveryPercentageForFlock(String flockId) {
    final expenses = totalExpensesForFlock(flockId);
    if (expenses <= 0) return 0.0;
    return totalSalesForFlock(flockId) / expenses * 100;
  }

  String recoveryPercentageForFlockDisplay(String flockId) {
    return '${recoveryPercentageForFlock(flockId).toStringAsFixed(1)}%';
  }

  double breakEvenPerBird({
    required int initialBirds,
    required int currentBirds,
  }) {
    if (currentBirds <= 0) return 0.0;
    if (totalExpenses < totalSales) return 0.0;
    return remainingCost() / currentBirds;
  }

  String breakEvenPerBirdDisplay({
    required int initialBirds,
    required int currentBirds,
  }) {
    final value = breakEvenPerBird(
      initialBirds: initialBirds,
      currentBirds: currentBirds,
    );
    return CurrencyFormatter.format(value);
  }

  double mortalityLossValue({
    required int mortalityCount,
    required double breakEvenPerBird,
  }) {
    return mortalityCount * breakEvenPerBird;
  }

  String mortalityLossValueDisplay({
    required int mortalityCount,
    required double breakEvenPerBird,
  }) {
    final value = mortalityLossValue(
      mortalityCount: mortalityCount,
      breakEvenPerBird: breakEvenPerBird,
    );
    return CurrencyFormatter.format(value);
  }

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (var e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Map<String, double> get salesByType {
    final map = <String, double>{};
    for (var s in _sales) {
      map[s.saleType] = (map[s.saleType] ?? 0) + s.totalAmount;
    }
    return map;
  }

  // ─── Core Load & Refresh ────────────────────────────────────────────────────

  Future<void> loadFinanceData(String flockId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _db.getExpensesByFlock(flockId);
      _sales = await _db.getSalesByFlock(flockId);
      _error = null;
    } catch (e) {
      _error = 'Failed to load finance data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFarmFinanceData() async {
    _isFarmFinanceLoading = true;
    _farmFinanceError = null;
    notifyListeners();

    try {
      _farmExpenses = await _db.getAllExpenses();
      _farmSales = await _db.getAllSales();
      _farmFinanceError = null;
    } catch (e) {
      _farmFinanceError = 'Failed to load farm finance data: $e';
      debugPrint(_farmFinanceError);
    } finally {
      _isFarmFinanceLoading = false;
      notifyListeners();
    }
  }

  // Alias for convenience — call this after any change
  Future<void> refresh(String flockId) async {
    await loadFinanceData(flockId);
  }

  // ─── Add Operations ─────────────────────────────────────────────────────────

  Future<void> addExpense({
    required String flockId,
    required String category,
    required String description,
    required double amount,
    required String date,
    String? paymentMethod,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toIso8601String();
      final expense = Expense(
        id: const Uuid().v4(),
        flockId: flockId,
        category: category,
        description: description,
        amount: amount,
        date: date,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _db.createExpense(expense);
      _expenses.add(expense); // optimistic update
      _error = null;
    } catch (e) {
      _error = 'Failed to add expense: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
      // Refresh from DB to be 100% sure
      await refresh(flockId);
    }
  }

  Future<void> addSale({
    required String flockId,
    required String saleType,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required String date,
    String? buyerName,
    String? paymentMethod,
    String? notes,
    required FlockProvider flockProvider,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final totalAmount = quantity * pricePerUnit;
      final now = DateTime.now().toIso8601String();

      final sale = Sale(
        id: const Uuid().v4(),
        flockId: flockId,
        saleType: saleType,
        quantity: quantity,
        unit: unit,
        pricePerUnit: pricePerUnit,
        totalAmount: totalAmount,
        date: date,
        buyerName: buyerName,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await _db.createSale(sale);
      _sales.add(sale); // optimistic

      // Reduce bird count if selling birds
      if (saleType.toLowerCase() == 'birds') {
        final flock = flockProvider.flocks.firstWhere((f) => f.id == flockId,
            orElse: () => flockProvider.flocks.first);
        final newCount =
            (flock.birdCount - quantity.toInt()).clamp(0, flock.birdCount);
        await flockProvider.updateFlock(flock.copyWith(birdCount: newCount));
      }

      _error = null;
    } catch (e) {
      _error = 'Failed to add sale: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
      await refresh(flockId);
    }
  }

  // ─── Delete Operations ──────────────────────────────────────────────────────

  Future<void> deleteExpense(String expenseId, String flockId) async {
    try {
      await _db.deleteExpense(expenseId);
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
      await refresh(flockId);
    } catch (e) {
      _error = 'Failed to delete expense: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSale(String saleId, String flockId) async {
    try {
      await _db.deleteSale(saleId);
      _sales.removeWhere((s) => s.id == saleId);
      notifyListeners();
      await refresh(flockId);
    } catch (e) {
      _error = 'Failed to delete sale: $e';
      notifyListeners();
    }
  }

  // ─── Cleanup on Flock Delete ────────────────────────────────────────────────

  Future<void> clearForFlock(String flockId) async {
    _expenses.removeWhere((e) => e.flockId == flockId);
    _sales.removeWhere((s) => s.flockId == flockId);
    notifyListeners();
    // DB CASCADE should already remove them, but we clean in-memory
  }

  // ─── Per-flock Profit ───────────────────────────────────────────────────────

  double profitForFlock(String flockId) {
    final flockExpenses = _expenses
        .where((e) => e.flockId == flockId)
        .fold(0.0, (sum, e) => sum + e.amount);
    final flockSales = _sales
        .where((s) => s.flockId == flockId)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    return flockSales - flockExpenses;
  }

  String profitForFlockDisplay(String flockId) {
    final p = profitForFlock(flockId);
    return CurrencyFormatter.formatSigned(p);
  }
}
