class FinanceAnalysis {
  final double initialFlockCost;
  final double totalExpenses;
  final double totalSales;
  final int currentBirds;
  final double originalCostPerBird;

  const FinanceAnalysis({
    required this.initialFlockCost,
    required this.totalExpenses,
    required this.totalSales,
    required this.currentBirds,
    required this.originalCostPerBird,
  });

  double get totalCostIncurred => initialFlockCost + totalExpenses;

  double get netProfit => totalSales - totalCostIncurred;

  double get unrecoveredCost {
    final value = totalCostIncurred - totalSales;
    return value > 0 ? value : 0.0;
  }

  double get profitMargin =>
      totalSales > 0 ? (netProfit / totalSales * 100) : 0.0;

  double get costRecoveryPercentage =>
      totalCostIncurred > 0 ? (totalSales / totalCostIncurred * 100) : 0.0;

  double get currentCostPerRemainingBird =>
      currentBirds > 0 ? unrecoveredCost / currentBirds : 0.0;

  double get breakEvenPricePerRemainingBird => currentCostPerRemainingBird;

  double get profitLossPerBird =>
      currentBirds > 0 ? netProfit / currentBirds : 0.0;

  double sellingPriceForMargin(double marginPercent) {
    return breakEvenPricePerRemainingBird * (1 + marginPercent / 100);
  }
}
