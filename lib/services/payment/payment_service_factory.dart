import 'payment_service.dart';
import 'paystack_payment_service.dart';
import 'play_billing_payment_service.dart';

/// Set to true when building the AAB for Play Store.
/// Set to false when building the APK for PalmStore.
const bool kIsPlayStoreBuild = bool.fromEnvironment(
  'PLAY_STORE_BUILD',
  defaultValue: false,
);

class PaymentServiceFactory {
  static PaymentService create() {
    if (kIsPlayStoreBuild) {
      return PlayBillingPaymentService();
    }
    return PaystackPaymentService();
  }
}