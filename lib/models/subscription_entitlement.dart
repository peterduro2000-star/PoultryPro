class SubscriptionEntitlement {
  final String tier;
  final DateTime? expiresAt;
  final bool isActive;
  final String? provider;
  final String? providerSubscriptionId;

  const SubscriptionEntitlement({
    required this.tier,
    required this.expiresAt,
    required this.isActive,
    this.provider,
    this.providerSubscriptionId,
  });

  static const free = SubscriptionEntitlement(
    tier: 'free',
    expiresAt: null,
    isActive: true,
  );

  bool get isPro {
    if (tier != 'pro' || !isActive) return false;
    return expiresAt == null || expiresAt!.isAfter(DateTime.now());
  }

  factory SubscriptionEntitlement.fromLicenseRow(Map<String, dynamic> row) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SubscriptionEntitlement(
      tier: row['tier']?.toString() ?? 'free',
      expiresAt: parseDate(row['expires_at']),
      isActive: row['is_active'] == true,
      provider: row['provider']?.toString(),
      providerSubscriptionId: row['provider_subscription_id']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tier': tier,
        'expires_at': expiresAt?.toIso8601String(),
        'is_active': isActive,
        'provider': provider,
        'provider_subscription_id': providerSubscriptionId,
      };
}
