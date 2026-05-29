import 'package:shared_preferences/shared_preferences.dart';

enum PlanType { free, pro }

class FlockLimitException implements Exception {
  final String message;

  const FlockLimitException(this.message);

  @override
  String toString() => message;
}

class SubscriptionService {
  static const String _planKey = 'subscription_plan';
  static const int freeMaxFlocks = 1;
  static const String upgradeMessage =
      'Free plan supports 1 flock. Upgrade to Pro to manage unlimited flocks, advanced reports, reminders, and business insights.';

  Future<PlanType> getPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_planKey);
    return PlanType.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => PlanType.free,
    );
  }

  Future<void> setPlan(PlanType plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, plan.name);
  }

  Future<bool> isPro() async => await getPlan() == PlanType.pro;

  Future<int?> maxFlocks() async {
    return await isPro() ? null : freeMaxFlocks;
  }

  Future<bool> canCreateFlock(int currentFlockCount) async {
    final limit = await maxFlocks();
    return limit == null || currentFlockCount < limit;
  }
}
