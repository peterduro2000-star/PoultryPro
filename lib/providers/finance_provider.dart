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

  // ─── State ─────────────────────────────────────────────────────────────────

  /// Finance data scoped to the currently selected flock.
  List<Expense> _expenses = [];
  List<Sale>    _sales    = [];

  /// Finance data across the entire farm (all flocks).
  List<Expense> _farmExpenses = [];
  List<Sale>    _farmSales    = [];

  bool    _isLoading          = false;
  bool    _isFarmFinanceLoading = false;
  String? _error;
  String? _farmFinanceError;

  // ─── Getters ───────────────────────────────────────────────────────────────

  List<Expense> get expenses      => _expenses;
  List<Sale>    get sales         => _sales;
  List<Expense> get farmExpenses  => _farmExpenses;
  List<Sale>    get farmSales     => _farmSales;
  bool          get isLoading     => _isLoading;
  bool          get isFarmFinanceLoading => _isFarmFinanceLoading;
  String?       get error         => _error;
  String?       get farmFinanceError => _farmFinanceError;

  // ─── Flock-scoped totals ───────────────────────────────────────────────────

  double get totalExpenses => _expenses.fold(0.0, (s, e) => s + e.amount);
  double get totalSales    => _sales.fold(0.0, (s, e) => s + e.totalAmount);
  double get profit        => totalSales - totalExpenses;

  double get profitMargin =>
      totalSales > 0 ? (profit / totalSales * 100) : 0.0;

  String get profitDisplay        => _formatProfit(profit);
  String get profitMarginDisplay  => '${profitMargin.toStringAsFixed(1)}%';

  double get remainingCost =>
      totalExpenses > totalSales ? totalExpenses - totalSales : 0.0;

  String get remainingCostDisplay => _formatNgn(remainingCost);

  double get recoveryPercentage =>
      totalExpenses > 0 ? (totalSales / totalExpenses * 100) : 0.0;

  String get recoveryPercentageDisplay =>
      '${recoveryPercentage.toStringAsFixed(1)}%';

  // ─── Farm-wide totals ──────────────────────────────────────────────────────

  double get farmTotalExpenses =>
      _farmExpenses.fold(0.0, (s, e) => s + e.amount);
  double get farmTotalSales =>
      _farmSales.fold(0.0, (s, e) => s + e.totalAmount);
  double get farmProfit => farmTotalSales - farmTotalExpenses;

  double get farmProfitMargin =>
      farmTotalSales > 0 ? (farmProfit / farmTotalSales * 100) : 0.0;

  String get farmProfitDisplay       => _formatProfit(farmProfit);
  String get farmProfitMarginDisplay => '${farmProfitMargin.toStringAsFixed(1)}%';

  double get farmRemainingCost =>
      farmTotalExpenses > farmTotalSales
          ? farmTotalExpenses - farmTotalSales
          : 0.0;

  String get farmRemainingCostDisplay => _formatNgn(farmRemainingCost);

  double get farmRecoveryPercentage =>
      farmTotalExpenses > 0
          ? (farmTotalSales / farmTotalExpenses * 100)
          : 0.0;

  String get farmRecoveryPercentageDisplay =>
      '${farmRecoveryPercentage.toStringAsFixed(1)}%';

  // ─── Per-flock helpers (using farm lists) ─────────────────────────────────

  List<Expense> farmExpensesForFlock(String flockId) =>
      _farmExpenses.where((e) => e.flockId == flockId).toList();

  List<Sale> farmSalesForFlock(String flockId) =>
      _farmSales.where((s) => s.flockId == flockId).toList();

  double totalExpensesForFlock(String flockId) =>
      farmExpensesForFlock(flockId).fold(0.0, (s, e) => s + e.amount);

  double totalSalesForFlock(String flockId) =>
      farmSalesForFlock(flockId).fold(0.0, (s, e) => s + e.totalAmount);

  double remainingCostForFlock(String flockId) {
    final diff = totalExpensesForFlock(flockId) - totalSalesForFlock(flockId);
    return diff > 0 ? diff : 0.0;
  }

  String remainingCostForFlockDisplay(String flockId) =>
      _formatNgn(remainingCostForFlock(flockId));

  double recoveryPercentageForFlock(String flockId) {
    final exp = totalExpensesForFlock(flockId);
    if (exp <= 0) return 0.0;
    return totalSalesForFlock(flockId) / exp * 100;
  }

  String recoveryPercentageForFlockDisplay(String flockId) =>
      '${recoveryPercentageForFlock(flockId).toStringAsFixed(1)}%';

  double profitForFlock(String flockId) =>
      totalSalesForFlock(flockId) - totalExpensesForFlock(flockId);

  String profitForFlockDisplay(String flockId) =>
      _formatProfit(profitForFlock(flockId));

  // ─── Break-even helpers ────────────────────────────────────────────────────

  double breakEvenPerBirdForFlock({
    required String flockId,
    required int currentBirds,
  }) {
    if (currentBirds <= 0) return 0.0;
    final remaining = remainingCostForFlock(flockId);
    if (remaining <= 0) return 0.0;
    return remaining / currentBirds;
  }

  String breakEvenPerBirdForFlockDisplay({
    required String flockId,
    required int currentBirds,
  }) =>
      _formatNgn(breakEvenPerBirdForFlock(
          flockId: flockId, currentBirds: currentBirds));

  /// Break-even using the currently loaded flock-scoped data.
  double breakEvenPerBird({required int currentBirds}) {
    if (currentBirds <= 0) return 0.0;
    if (remainingCost <= 0) return 0.0;
    return remainingCost / currentBirds;
  }

  String breakEvenPerBirdDisplay({required int currentBirds}) =>
      _formatNgn(breakEvenPerBird(currentBirds: currentBirds));

  double mortalityLossValue({
    required int mortalityCount,
    required double breakEvenPerBirdValue,
  }) =>
      mortalityCount * breakEvenPerBirdValue;

  String mortalityLossValueDisplay({
    required int mortalityCount,
    required double breakEvenPerBirdValue,
  }) =>
      _formatNgn(mortalityLossValue(
          mortalityCount: mortalityCount,
          breakEvenPerBirdValue: breakEvenPerBirdValue));

  // ─── Category/type breakdowns ──────────────────────────────────────────────

  /// Expense totals grouped by [ExpenseCategory] constant.
  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Sale totals grouped by [SaleType] constant.
  Map<String, double> get salesByType {
    final map = <String, double>{};
    for (final s in _sales) {
      map[s.saleType] = (map[s.saleType] ?? 0) + s.totalAmount;
    }
    return map;
  }

  // ─── Reset (on auth change) ────────────────────────────────────────────────
  /// Clears all in-memory finance state. Called when the authenticated user
  /// changes so no data leaks between accounts.
  void reset() {
    _expenses = [];
    _sales = [];
    _farmExpenses = [];
    _farmSales = [];
    _error = null;
    _farmFinanceError = null;
    _isLoading = false;
    _isFarmFinanceLoading = false;
    notifyListeners();
  }

  // ─── Load & Refresh ────────────────────────────────────────────────────────

  /// Loads finance data for a single flock.
  Future<void> loadFinanceData(String flockId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await _db.getExpensesByFlock(flockId);
      _sales    = await _db.getSalesByFlock(flockId);
      _error    = null;
    } catch (e, st) {
      _error = 'Failed to load finance data: $e';
      debugPrint('$_error\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads finance data for the entire farm (all flocks combined).
  Future<void> loadFarmFinanceData() async {
    _isFarmFinanceLoading = true;
    _farmFinanceError = null;
    notifyListeners();

    try {
      _farmExpenses    = await _db.getAllExpenses();
      _farmSales       = await _db.getAllSales();
      _farmFinanceError = null;
    } catch (e, st) {
      _farmFinanceError = 'Failed to load farm finance data: $e';
      debugPrint('$_farmFinanceError\n$st');
    } finally {
      _isFarmFinanceLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes BOTH flock-scoped and farm-wide data.
  /// Call this after any create / update / delete operation.
  Future<void> refresh(String flockId) async {
    await Future.wait([
      loadFinanceData(flockId),
      loadFarmFinanceData(),
    ]);
  }

  // ─── Add Operations ────────────────────────────────────────────────────────

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
      final now = DateTime.now().toUtc().toIso8601String();
      final expense = Expense(
        id:            const Uuid().v4(),
        flockId:       flockId,
        category:      category,
        description:   description,
        amount:        amount,
        date:          date,
        paymentMethod: paymentMethod,
        notes:         notes,
        createdAt:     now,
        updatedAt:     now,
      );

      await _db.createExpense(expense);
      _error = null;
    } catch (e, st) {
      _error = 'Failed to add expense: $e';
      debugPrint('$_error\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
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
      final now = DateTime.now().toUtc().toIso8601String();

      final sale = Sale(
        id:            const Uuid().v4(),
        flockId:       flockId,
        saleType:      saleType,
        quantity:      quantity,
        unit:          unit,
        pricePerUnit:  pricePerUnit,
        totalAmount:   totalAmount,
        date:          date,
        buyerName:     buyerName,
        paymentMethod: paymentMethod,
        notes:         notes,
        createdAt:     now,
        updatedAt:     now,
      );

      await _db.createSale(sale);

      // Only reduce bird count when the sale type explicitly removes live birds.
      // We use Sale.reducesBirdCount (= saleType == SaleType.birds) so the
      // logic lives in one place and this provider never hardcodes 'birds'.
      if (sale.reducesBirdCount) {
        // BUG FIX: look up the flock by id first; throw clearly if not found
        // instead of silently falling back to flocks.first and corrupting
        // the wrong flock's bird count.
        final flock = flockProvider.flocks.cast<dynamic>().firstWhere(
              (f) => f.id == flockId,
              orElse: () => null,
            );

        if (flock == null) {
          throw PoultryDbException(
              'Cannot reduce bird count — flock $flockId not found in provider.');
        }

        final newCount =
            (flock.birdCount - quantity.toInt()).clamp(0, flock.birdCount);
        await flockProvider.updateFlock(flock.copyWith(birdCount: newCount));
      }

      _error = null;
    } catch (e, st) {
      _error = 'Failed to add sale: $e';
      debugPrint('$_error\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
      await refresh(flockId);
    }
  }

  // ─── Update Operations ────────────────────────────────────────────────────

  Future<void> updateExpense(Expense expense) async {
    try {
      await _db.updateExpense(expense);
      await refresh(expense.flockId);
    } catch (e, st) {
      _error = 'Failed to update expense: $e';
      debugPrint('$_error\n$st');
      notifyListeners();
    }
  }

  Future<void> updateSale(Sale sale) async {
    try {
      await _db.updateSale(sale);
      await refresh(sale.flockId);
    } catch (e, st) {
      _error = 'Failed to update sale: $e';
      debugPrint('$_error\n$st');
      notifyListeners();
    }
  }

  // ─── Delete Operations ────────────────────────────────────────────────────

  Future<void> deleteExpense(String expenseId, String flockId) async {
    try {
      // Soft-delete via DatabaseService — sets deleted=1, syncStatus='pending'
      await _db.deleteExpense(expenseId);
      // Optimistic removal from in-memory list
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
      await refresh(flockId);
    } catch (e, st) {
      _error = 'Failed to delete expense: $e';
      debugPrint('$_error\n$st');
      notifyListeners();
    }
  }

  Future<void> deleteSale(String saleId, String flockId) async {
    try {
      await _db.deleteSale(saleId);
      _sales.removeWhere((s) => s.id == saleId);
      notifyListeners();
      await refresh(flockId);
    } catch (e, st) {
      _error = 'Failed to delete sale: $e';
      debugPrint('$_error\n$st');
      notifyListeners();
    }
  }

  // ─── Cleanup on Flock Delete ──────────────────────────────────────────────

  /// Call this when a flock is deleted to clean up in-memory lists.
  /// The DB soft-delete on the flock will be picked up by SyncService;
  /// the FK cascade handles child rows on hard-delete in import/clear.
  void clearForFlock(String flockId) {
    _expenses.removeWhere((e) => e.flockId == flockId);
    _sales.removeWhere((s) => s.flockId == flockId);
    _farmExpenses.removeWhere((e) => e.flockId == flockId);
    _farmSales.removeWhere((s) => s.flockId == flockId);
    notifyListeners();
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  String _formatNgn(double value) => CurrencyFormatter.formatFull(value);

  String _formatProfit(double p) => CurrencyFormatter.formatProfit(p);
}