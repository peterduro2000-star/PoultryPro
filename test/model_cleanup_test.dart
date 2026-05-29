import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pro_new/models/daily_record.dart';
import 'package:poultry_pro_new/models/flock.dart';
import 'package:poultry_pro_new/models/sale.dart';

void main() {
  test('vaccination daysUntil returns negative values for overdue vaccines',
      () {
    const milestone = VaccinationMilestone(
      day: 7,
      name: 'Gumboro',
      done: false,
    );

    expect(milestone.daysUntil(3), 4);
    expect(milestone.daysUntil(7), 0);
    expect(milestone.daysUntil(10), -3);
  });

  test('nullable copyWith fields can be cleared', () {
    final record = DailyRecord(
      id: 'record-1',
      flockId: 'flock-1',
      date: '2026-05-18',
      healthObservations: 'Sneezing',
      notes: 'Watch closely',
      createdAt: '2026-05-18T00:00:00.000',
      updatedAt: '2026-05-18T00:00:00.000',
    );

    final cleared = record.copyWith(
      healthObservations: null,
      notes: null,
    );

    expect(cleared.healthObservations, isNull);
    expect(cleared.notes, isNull);
  });

  test('sale total amount recalculates when quantity or price changes', () {
    final sale = Sale(
      id: 'sale-1',
      flockId: 'flock-1',
      saleType: 'birds',
      quantity: 10,
      unit: 'birds',
      pricePerUnit: 1000,
      totalAmount: 1,
      date: '2026-05-18',
      createdAt: '2026-05-18T00:00:00.000',
      updatedAt: '2026-05-18T00:00:00.000',
    );

    final updated = sale.copyWith(quantity: 12, pricePerUnit: 1500);

    expect(updated.totalAmount, 18000);
  });

  test('flock status constants preserve sold-out status string', () {
    expect(FlockStatus.active, 'active');
    expect(FlockStatus.soldOut, 'sold out');
    expect(FlockStatus.lost, 'lost');
    expect(FlockStatus.inactive, 'inactive');

    final flock = Flock(
      id: 'flock-1',
      name: 'Broiler Batch',
      type: 'Broilers',
      birdCount: 0,
      initialBirdCount: 200,
      costPerBird: 1500,
      startDate: '2026-05-18',
      status: FlockStatus.soldOut,
      createdAt: '2026-05-18T00:00:00.000',
      updatedAt: '2026-05-18T00:00:00.000',
    );

    expect(flock.status, 'sold out');
  });
}
