import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pro_new/utils/finance_calculator.dart';

void main() {
  test('production cost uses saleable birds and keeps sales separate', () {
    const analysis = FinanceAnalysis(
      totalExpenses: 1364000,
      totalSales: 1800000,
      initialBirds: 200,
      totalMortality: 20,
      totalBirdsSold: 180,
      currentBirds: 0,
      originalCostPerBird: 1500,
    );

    expect(analysis.calculatedCurrentBirds, 0);
    expect(analysis.mortalityRate, closeTo(10, 0.01));
    expect(analysis.trueCostPerBird, closeTo(7577.78, 0.01));
    expect(analysis.totalCostIncurred, 1364000);
    expect(analysis.breakEvenPricePerBird, closeTo(7577.78, 0.01));
    expect(analysis.sellingPriceForMargin(20), closeTo(9093.33, 0.01));
    expect(analysis.sellingPriceForMargin(30), closeTo(9851.11, 0.01));
    expect(analysis.sellingPriceForMargin(50), closeTo(11366.67, 0.01));
    expect(analysis.netProfit, 436000);
    expect(analysis.profitMargin, closeTo(24.2, 0.1));
    expect(analysis.costRecoveryPercentage, closeTo(132, 0.1));
    expect(analysis.averageSellingPrice, 10000);
    expect(analysis.profitPerBirdSold, closeTo(2422.22, 0.01));
  });
}
