import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_entitlement.dart';
import '../services/subscription_service.dart';

class LicenseProvider extends ChangeNotifier {
  static const String _cacheKey = 'cached_entitlement';

  final SubscriptionService _service = SubscriptionService();

  SubscriptionEntitlement? _entitlement;
  bool _isLoading = false;

  SubscriptionEntitlement? get entitlement => _entitlement;
  bool get isPro => _entitlement?.isPro ?? false;
  bool get isLoading => _isLoading;

  Future<void> loadCachedEntitlement() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final map = jsonDecode(cached) as Map<String, dynamic>;
        _entitlement = SubscriptionEntitlement(
          tier: map['tier']?.toString() ?? 'free',
          expiresAt: map['expiresAt'] != null
              ? DateTime.tryParse(map['expiresAt']!.toString())
              : null,
          isActive: map['isActive'] == true,
          provider: map['provider']?.toString(),
          providerSubscriptionId: map['providerSubscriptionId']?.toString(),
        );
        notifyListeners();
      } catch (_) {
        _entitlement = SubscriptionEntitlement.free;
        notifyListeners();
      }
    }
  }

  Future<void> loadEntitlement() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entitlement = await _service.loadCurrentEntitlement();
      await _persistEntitlement();
    } catch (_) {
      // Network or RPC failed — preserve existing in-memory entitlement.
      // A Pro user going offline must stay Pro.
      // Only fall back to cache if we have nothing in memory yet.
      if (_entitlement == null) {
        await loadCachedEntitlement();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _persistEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _entitlement?.toMap() ?? {};
      final serializable = <String, dynamic>{
        'tier': map['tier'] ?? 'free',
        'expiresAt': map['expires_at']?.toString(),
        'isActive': map['is_active'] ?? true,
        'provider': map['provider'],
        'providerSubscriptionId': map['provider_subscription_id'],
      };
      await prefs.setString(_cacheKey, jsonEncode(serializable));
    } catch (_) {}
  }
}
