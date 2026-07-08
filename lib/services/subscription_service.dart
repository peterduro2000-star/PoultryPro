import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_entitlement.dart';

class SubscriptionService {
  final _client = Supabase.instance.client;

  static const String upgradeMessage =
      'Upgrade to PoultryPro Plus and unlock unlimited flocks';

  static const String proPriceDisplay = '₦5,000';

  static const List<String> freeBenefits = [
    'Manage 1 flock',
    'Track basic flock records',
    'Record expenses and sales',
    'Backup and restore local data',
  ];

  static const List<String> proBenefits = [
    'Unlimited flocks',
    'Advanced reports',
    'Reminders & smart alerts',
    'Cloud backup',
    'Business insights',
    'Flock comparison',
  ];

  Future<SubscriptionEntitlement> loadCurrentEntitlement() async {
    try {
      final response = await _client
          .rpc('get_current_license')
          .select()
          .maybeSingle();

      debugPrint(
        'RPC get_current_license response: $response',
      );

      debugPrint('=== SubscriptionService.loadCurrentEntitlement: response=$response');

      if (response == null) {
        debugPrint('=== SubscriptionService.loadCurrentEntitlement: null → free');
        return SubscriptionEntitlement.free;
      }
      final entitlement = SubscriptionEntitlement.fromLicenseRow(response);
      debugPrint(
        '=== SubscriptionService.loadCurrentEntitlement: '
        'tier=${entitlement.tier}, isActive=${entitlement.isActive}, '
        'expiresAt=${entitlement.expiresAt}, isPro=${entitlement.isPro}',
      );
      return entitlement;
    } catch (e, st) {
      debugPrint('=== get_current_license FAILED ===');
      debugPrint(e.toString());
      debugPrint(st.toString());
      return SubscriptionEntitlement.free;
    }
  }

  Future<bool> checkIfPro(String userId) async {
    final entitlement = await loadCurrentEntitlement();
    return entitlement.isPro;
  }

  Future<void> activateSubscription({
    required String userId,
    required String reference,
    required String provider,
  }) async {
    final now = DateTime.now();
    final expiry = DateTime(now.year + 1, now.month, now.day);

    await _client.rpc('activate_license_from_iap', params: {
      'p_user_id': userId,
      'p_tier': 'pro',
      'p_expires_at': expiry.toIso8601String(),
      'p_provider': provider,
      'p_order_id': reference,
      'p_purchase_token': reference,
      'p_subscription_id': 'poultry_pro_yearly',
    });
  }
}
