class FinanceAnalysis {
  final double totalExpenses;
  final double totalSales;
  final int initialBirds;
  final int totalMortality;
  final int totalBirdsSold;
  final int currentBirds;
  final double originalCostPerBird;

  const FinanceAnalysis({
    required this.totalExpenses,
    required this.totalSales,
    required this.initialBirds,
    required this.totalMortality,
    required this.totalBirdsSold,
    required this.currentBirds,
    required this.originalCostPerBird,
  });

  // Chick/bird purchase cost is included in totalExpenses through the
  // "chicks" expense category. Do not add initial flock cost again here.
  double get totalCostIncurred => totalExpenses;

  double get netProfit => totalSales - totalCostIncurred;

  double get unrecoveredCost {
    final value = totalCostIncurred - totalSales;
    return value > 0 ? value : 0.0;
  }

  double get profitMargin =>
      totalSales > 0 ? (netProfit / totalSales * 100) : 0.0;

  double get costRecoveryPercentage =>
      totalCostIncurred > 0 ? (totalSales / totalCostIncurred * 100) : 0.0;

  int get calculatedCurrentBirds {
    final value = initialBirds - totalMortality - totalBirdsSold;
    return value > 0 ? value : 0;
  }

  double get mortalityRate =>
      initialBirds > 0 ? totalMortality / initialBirds * 100 : 0.0;

  int get saleableBirds {
    final value = initialBirds - totalMortality;
    return value > 0 ? value : 0;
  }

  double get trueCostPerBird =>
      saleableBirds > 0 ? totalCostIncurred / saleableBirds : 0.0;

  double get currentCostPerRemainingBird =>
      currentBirds > 0 ? unrecoveredCost / currentBirds : 0.0;

  double get breakEvenPricePerBird => trueCostPerBird;

  double get averageSellingPrice =>
      totalBirdsSold > 0 ? totalSales / totalBirdsSold : 0.0;

  double get profitPerBirdSold => averageSellingPrice - trueCostPerBird;

  double sellingPriceForMargin(double marginPercent) {
    return trueCostPerBird * (1 + marginPercent / 100);
  }
}
