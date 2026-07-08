import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../subscription_service.dart';
import 'payment_service.dart';

class PaystackPaymentService implements PaymentService {
  @override
  Future<String?> purchasePro({required String email}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('=== PaystackPaymentService: session is null');
        return null;
      }

      debugPrint('=== PaystackPaymentService: calling create-paystack-payment');

      final response = await Supabase.instance.client.functions.invoke(
        'create-paystack-payment',
        body: {'email': email},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      debugPrint('=== PaystackPaymentService: status=${response.status}');
      debugPrint('=== PaystackPaymentService: data=${response.data}');

      if (response.status != 200) return null;

      final raw = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final authUrl = raw['authorization_url'] as String?;
      final reference = raw['reference'] as String?;

      if (authUrl == null || reference == null) {
        debugPrint('=== PaystackPaymentService: missing authUrl or reference');
        return null;
      }

      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      return reference;
    } catch (e, st) {
      debugPrint('=== PaystackPaymentService ERROR: $e');
      debugPrint('$st');
      return null;
    }
  }

  @override
  Future<bool> verifyPayment(String reference) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('=== PaystackPaymentService.verifyPayment: session is null');
        return false;
      }

      debugPrint('=== PaystackPaymentService.verifyPayment: reference=$reference');

      final response = await Supabase.instance.client.functions.invoke(
        'verify-paystack',
        body: {'reference': reference},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      debugPrint('=== PaystackPaymentService.verifyPayment: httpStatus=${response.status}');
      debugPrint('=== PaystackPaymentService.verifyPayment: data=${response.data}');

      final bool httpOk = response.status == 200;

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final bool bodyOk = data['success'] != false;
        debugPrint('=== PaystackPaymentService.verifyPayment: bodySuccess=$bodyOk');
        return httpOk && bodyOk;
      }

      return httpOk;
    } catch (e, st) {
      debugPrint('=== PaystackPaymentService.verifyPayment ERROR: $e');
      debugPrint('$st');
      return false;
    }
  }

  @override
  Future<String?> getDisplayPrice() async => SubscriptionService.proPriceDisplay;
}