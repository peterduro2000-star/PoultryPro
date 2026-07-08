import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Id of the currently authenticated Supabase user, or null if anonymous /
  /// unauthenticated. The cache is only ever trusted for this exact id.
  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  Future<void> loadCachedEntitlement() async {
    // Never apply a cache without a known authenticated user.
    final userId = _currentUserId;
    if (userId == null) {
      _entitlement = SubscriptionEntitlement.free;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;

    try {
      final map = jsonDecode(cached) as Map<String, dynamic>;

      // Ignore (and discard) a cache that does not belong to this user.
      if (map['userId']?.toString() != userId) {
        await prefs.remove(_cacheKey);
        _entitlement = SubscriptionEntitlement.free;
        notifyListeners();
        return;
      }

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

  Future<void> loadEntitlement() async {
    // Anonymous / unauthenticated users are always Free.
    final userId = _currentUserId;
    if (userId == null) {
      _entitlement = SubscriptionEntitlement.free;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _entitlement = await _service.loadCurrentEntitlement();
      await _persistEntitlement();
    } catch (_) {
      // Network or RPC failed — preserve existing in-memory entitlement.
      // A Pro user going offline must stay Pro.
      // Only fall back to cache if we have nothing in memory yet AND it
      // belongs to the current user (validated inside loadCachedEntitlement).
      if (_entitlement == null) {
        await loadCachedEntitlement();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Forces the provider back to Free and removes any persisted cache.
  /// Used when the current user is anonymous / not authenticated.
  Future<void> clearEntitlement() async {
    _entitlement = SubscriptionEntitlement.free;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persistEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _entitlement?.toMap() ?? {};
      final serializable = <String, dynamic>{
        'userId': _currentUserId,
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
