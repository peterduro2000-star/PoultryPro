import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pro_new/utils/finance_calculator.dart';

void main() {
  test('current cost per remaining bird includes initial cost and sales', () {
    const analysis = FinanceAnalysis(
      initialFlockCost: 100000,
      totalExpenses: 10090,
      totalSales: 16000,
      currentBirds: 90,
      originalCostPerBird: 1000,
    );

    expect(analysis.totalCostIncurred, 110090);
    expect(analysis.unrecoveredCost, 94090);
    expect(analysis.currentCostPerRemainingBird, closeTo(1045.44, 0.01));
  });
}
