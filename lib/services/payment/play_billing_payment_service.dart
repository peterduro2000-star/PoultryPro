import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_service.dart';

class PlayBillingPaymentService implements PaymentService {
  final InAppPurchase _iap = InAppPurchase.instance;

  // TODO: confirm this matches the exact product ID configured for the
  // pro_annual base plan in Play Console → Monetize → Products. If it
  // doesn't match, queryProductDetails() will silently return empty and
  // both purchasePro() and getDisplayPrice() will fail.
  static const _productId = 'poultry_pro_yearly';

  // Completes with the purchase token once Play billing confirms the purchase.
  // purchasePro() sets this up; verifyPayment() awaits it.
  Completer<String>? _purchaseTokenCompleter;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  // Cached product details from the last successful queryProductDetails()
  // call, so getDisplayPrice() doesn't need to hit the store again if
  // purchasePro() already fetched it.
  ProductDetails? _cachedProduct;

  PlayBillingPaymentService() {
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Acknowledge the purchase so Google doesn't refund it
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
        // Hand the token to verifyPayment()
        _purchaseTokenCompleter?.complete(
          purchase.verificationData.serverVerificationData,
        );
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _purchaseTokenCompleter?.completeError(
          purchase.error ?? Exception('Purchase cancelled'),
        );
      }
    }
  }

  @override
  Future<String?> purchasePro({required String email}) async {
    try {
      final available = await _iap.isAvailable();
      if (!available) {
        assert(() { debugPrint('=== PlayBilling: store unavailable'); return true; }());
        return null;
      }

      final response = await _iap.queryProductDetails({_productId});

debugPrint('=== PRODUCTS FOUND: ${response.productDetails.map((e) => e.id)}');
debugPrint('=== PRODUCTS NOT FOUND: ${response.notFoundIDs}');

      if (response.productDetails.isEmpty) {
        assert(() { debugPrint('=== PlayBilling: product not found'); return true; }());
        return null;
      }

      _cachedProduct = response.productDetails.first;

      // Set up completer BEFORE launching the purchase flow
      _purchaseTokenCompleter = Completer<String>();

      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: _cachedProduct!,
        ),
      );

      debugPrint('=== PURCHASE STARTED: $started');

if (!started) {
        assert(() { debugPrint('=== PlayBilling: failed starting purchase'); return true; }());
        _purchaseTokenCompleter = null;
        return null;
      }

      // Return the product ID as the "reference" — verifyPayment()
      // will wait for the actual token from the purchase stream
      return _productId;
    } catch (e, st) {
      assert(() { debugPrint('=== PlayBilling ERROR: $e\n$st'); return true; }());
      _purchaseTokenCompleter = null;
      return null;
    }
  }

  @override
  Future<bool> verifyPayment(String reference) async {
    try {
      // Wait for the purchase stream to deliver the token (30s timeout)
      final token = await _purchaseTokenCompleter?.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Play Billing timed out'),
      );

      if (token == null) return false;

      // Verify server-side via your existing Edge Function
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return false;

      final response = await Supabase.instance.client.functions.invoke(
  'verify-google-play',
  body: {
    'purchaseToken': token,
    'productId': reference,
  },
  headers: {
    'Authorization': 'Bearer ${session.accessToken}',
  },
);

      assert(() {
        debugPrint('=== PlayBilling verify status=${response.status}');
        return true;
      }());

      return response.status == 200;
    } catch (e, st) {
      assert(() { debugPrint('=== PlayBilling verifyPayment ERROR: $e\n$st'); return true; }());
      return false;
    }
  }

  @override
  Future<String?> getDisplayPrice() async {
    if (_cachedProduct != null) return _cachedProduct!.price;
    try {
      final available = await _iap.isAvailable();
      if (!available) return null;

      final response = await _iap.queryProductDetails({_productId});
      if (response.productDetails.isNotEmpty) {
        _cachedProduct = response.productDetails.first;
        return _cachedProduct!.price;
      }
    } catch (e, st) {
      assert(() { debugPrint('=== PlayBilling getDisplayPrice ERROR: $e\n$st'); return true; }());
    }
    return null;
  }

  void dispose() {
    _subscription.cancel();
  }
}