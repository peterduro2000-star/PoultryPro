import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:poultry_pro_new/services/subscription_service.dart';

void main() {
  late SubscriptionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SubscriptionService();
  });

  test('free plan allows 0 or 1 flock', () async {
    expect(await service.canCreateFlock(0), isTrue);
    expect(await service.canCreateFlock(1), isFalse);
    expect(await service.maxFlocks(), 1);
  });

  test('free plan blocks 2nd flock', () async {
    expect(await service.getPlan(), PlanType.free);
    expect(await service.canCreateFlock(1), isFalse);
  });

  test('pro plan allows multiple flocks', () async {
    await service.setPlan(PlanType.pro);

    expect(await service.isPro(), isTrue);
    expect(await service.maxFlocks(), isNull);
    expect(await service.canCreateFlock(1), isTrue);
    expect(await service.canCreateFlock(20), isTrue);
  });
}
