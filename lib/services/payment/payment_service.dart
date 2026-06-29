abstract class PaymentService {
  Future<String?> purchasePro({required String email});
  Future<bool> verifyPayment(String reference);

  /// Returns the store's current display price for the Pro plan,
  /// e.g. "₦5,000" for Paystack or Google Play's live localized price
  /// once fetched via queryProductDetails(). May return null if it
  /// can't be determined yet (e.g. store unreachable).
  Future<String?> getDisplayPrice();
}