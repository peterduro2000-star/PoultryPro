import '../models/subscription_entitlement.dart';

class FeatureGateException implements Exception {
  final String message;
  const FeatureGateException(this.message);

  @override
  String toString() => message;
}

class FlockLimitException extends FeatureGateException {
  const FlockLimitException()
      : super('Free tier only allows 1 flock. Upgrade to Pro for unlimited flocks.');
}

class CloudFeatureException extends FeatureGateException {
  const CloudFeatureException()
      : super('Cloud backup and sync require an active Pro subscription.');
}

class FeatureGate {
  FeatureGate._();

  static const int freeFlockLimit = 1;

  static bool canCreateFlocks({
    required SubscriptionEntitlement entitlement,
    required int existingFlockCount,
    int newFlockCount = 1,
  }) {
    if (entitlement.isPro) return true;
    return existingFlockCount + newFlockCount <= freeFlockLimit;
  }

  static void assertCanCreateFlocks({
    required SubscriptionEntitlement entitlement,
    required int existingFlockCount,
    int newFlockCount = 1,
  }) {
    if (!canCreateFlocks(
      entitlement: entitlement,
      existingFlockCount: existingFlockCount,
      newFlockCount: newFlockCount,
    )) {
      throw const FlockLimitException();
    }
  }

  static bool canUseCloud(SubscriptionEntitlement entitlement) =>
      entitlement.isPro;

  static void assertCanUseCloud(SubscriptionEntitlement entitlement) {
    if (!canUseCloud(entitlement)) {
      throw const CloudFeatureException();
    }
  }
}
