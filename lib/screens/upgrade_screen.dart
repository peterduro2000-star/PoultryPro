import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment/play_billing_payment_service.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/payment_service_factory.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import 'backup_screen.dart';

class UpgradeScreen extends StatefulWidget {
  /// Optional override for tests / future payment swaps (e.g. a
  /// PlayBillingPaymentService for the Play Store build). Defaults
  /// to Paystack when not supplied.
  final PaymentService? paymentService;

  const UpgradeScreen({super.key, this.paymentService});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isLoading = false;
  late final PaymentService _paymentService;
  String? _displayPrice;

  @override
  void initState() {
    super.initState();
    _paymentService = widget.paymentService ?? PaymentServiceFactory.create();
    _loadDisplayPrice();
  }

  Future<void> _loadDisplayPrice() async {
    final price = await _paymentService.getDisplayPrice();
    if (mounted && price != null) {
      setState(() => _displayPrice = price);
    }
  }

  /// The price actually shown in the UI. Falls back to the static
  /// Paystack constant until the live store price (Play Billing) has
  /// loaded, or if it never loads.
  String get _priceLabel => _displayPrice ?? SubscriptionService.proPriceDisplay;

  bool get _isPlayBilling =>
    _paymentService is PlayBillingPaymentService;

  Future<void> _handleUpgrade() async {
    final user = Supabase.instance.client.auth.currentUser;

    assert(() {
      debugPrint('=== UPGRADE: user=$user');
      debugPrint('=== UPGRADE: isAnonymous=${user?.isAnonymous}');
      debugPrint('=== UPGRADE: authProvider.userId=${context.read<AuthProvider>().userId}');
      debugPrint('=== UPGRADE: authProvider.status=${context.read<AuthProvider>().status}');
      return true;
    }());

    if (user == null) {
      _showError('Something went wrong. Please try again.');
      return;
    }

    if (user.isAnonymous) {
      final shouldVerify = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verify your email first'),
          content: const Text(
            'To subscribe, we need your email address to send '
            'your receipt and manage your account.\n\n'
            '✅ Your existing farm data will NOT be lost — '
            'verifying your email simply secures your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verify Email'),
            ),
          ],
        ),
      );

      if (shouldVerify != true) return;

      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const BackupScreen()),
      );
      if (verified != true) return;

      final updatedUser = Supabase.instance.client.auth.currentUser;
      if (updatedUser == null || updatedUser.isAnonymous) {
        _showError('Verification succeeded but user is still anonymous. Please try again.');
        return;
      }

      await _performUpgrade(updatedUser);
      return;
    }

    await _performUpgrade(user);
  }

  Future<void> _performUpgrade(User user) async {
    debugPrint(
      'Current user: ${Supabase.instance.client.auth.currentUser?.id}',
    );
    debugPrint(
      'Email: ${Supabase.instance.client.auth.currentUser?.email}',
    );
    debugPrint(
      'Anonymous: ${Supabase.instance.client.auth.currentUser?.isAnonymous}',
    );
    if (user.email == null) {
      _showError('Email not available. Please verify your account first.');
      return;
    }
    final email = user.email!;

    setState(() => _isLoading = true);

    try {
      assert(() {
        debugPrint('=== _performUpgrade: starting payment for $email');
        return true;
      }());

      final reference = await _paymentService.purchasePro(email: email);

      assert(() {
        debugPrint('=== _performUpgrade: reference=$reference');
        return true;
      }());

      if (reference == null || !mounted) {
        setState(() => _isLoading = false);
        _showError('Could not start payment. Please try again.');
        return;
      }

      // Drop the screen-level spinner while the confirmation dialog
      // (which has its own progress indicator) is in front of it.
      setState(() => _isLoading = false);

      final verified = await _waitForPaymentConfirmation(
  reference,
  isPlayBilling: _isPlayBilling,
);

      if (!mounted || !verified) return;

      setState(() => _isLoading = true);

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        _showError('Session expired. Please sign in again.');
        setState(() => _isLoading = false);
        return;
      }

      bool subscriptionConfirmed = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        await context.read<LicenseProvider>().loadEntitlement();
        if (!mounted) return;
        final lp = context.read<LicenseProvider>();
        debugPrint(
          '=== verify attempt ${attempt + 1}: '
          'tier=${lp.entitlement?.tier}, '
          'isActive=${lp.entitlement?.isActive}, '
          'expiresAt=${lp.entitlement?.expiresAt}, '
          'isPro=${lp.isPro}',
        );
        if (lp.isPro) {
          subscriptionConfirmed = true;
          break;
        }
        if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
      }

      if (!mounted) return;

      if (!subscriptionConfirmed) {
        _showError(
          'Payment processed but license activation failed.\n'
          'Please take a screenshot and contact support.',
        );
        setState(() => _isLoading = false);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to Poultry Pro!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.of(context).pop();
    } catch (e, st) {
      assert(() {
        debugPrint('=== _performUpgrade ERROR: $e');
        debugPrint('=== STACK: $st');
        return true;
      }());
      if (mounted) _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a dialog that polls [_verifyPaystackReference] in the
  /// background until it succeeds, the user cancels, or it times out.
  /// Returns true only on an actual verified success.
  Future<bool> _waitForPaymentConfirmation(
  String reference, {
  required bool isPlayBilling,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentConfirmationDialog(
      isPlayBilling: isPlayBilling,
      onVerify: () => _paymentService.verifyPayment(reference),
    ),
  );

  return result ?? false;
}
 
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<LicenseProvider>().isPro;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Upgrade to Poultry Pro')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // Current plan banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPro
                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                  : AppTheme.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPro
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPro ? Icons.workspace_premium : Icons.lock_open_outlined,
                  color: isPro ? AppTheme.primaryColor : AppTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPro
                        ? 'You are on the Pro plan'
                        : 'You are currently on the Free plan',
                    style: AppTheme.bodyMedium.copyWith(
                      color: isPro ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          Text(
            SubscriptionService.upgradeMessage,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLG),

          _PlanCard(
            title: 'Free',
            subtitle: 'For getting started',
            color: AppTheme.textSecondary,
            benefits: SubscriptionService.freeBenefits,
            isCurrent: !isPro,
          ),
          const SizedBox(height: AppTheme.spacingMD),

          _PlanCard(
            title: 'Pro',
            subtitle: 'For growing poultry businesses',
            color: AppTheme.primaryColor,
            benefits: SubscriptionService.proBenefits,
            isCurrent: isPro,
          ),
          const SizedBox(height: AppTheme.spacingLG),

          if (!isPro)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upgrade Now',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Secure payment. Annual Pro subscription — '
                      '$_priceLabel/year.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _handleUpgrade,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.workspace_premium),
                        label: Text(
                          _isLoading
                              ? 'Processing...'
                              : 'Pay $_priceLabel — Upgrade to Pro',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (isPro)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You already have full Pro access. Enjoy all features!',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.successColor),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppTheme.spacingLG),
        ],
      ),
    );
  }
}

/// Polls [onVerify] in the background and pops with `true` the moment
/// it succeeds. "Check now" only forces an immediate check — it never
/// confirms anything by itself.
class _PaymentConfirmationDialog extends StatefulWidget {
  final Future<bool> Function() onVerify;
  final bool isPlayBilling;

  const _PaymentConfirmationDialog({
    required this.onVerify,
    required this.isPlayBilling,
  });

  @override
  State<_PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<_PaymentConfirmationDialog> {
  static const _pollInterval = Duration(seconds: 5);
  static const _maxAutoAttempts = 24; // ~2 minutes of auto-polling

  Timer? _pollTimer;
  bool _checking = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _check());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);

    bool ok = false;
    try {
      ok = await widget.onVerify();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;

    if (ok) {
      _pollTimer?.cancel();
      Navigator.of(context).pop(true);
      return;
    }

    _attempts++;
    if (_attempts >= _maxAutoAttempts) {
      _pollTimer?.cancel();
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final timedOut = _attempts >= _maxAutoAttempts;

    return AlertDialog(
      title: const Text('Confirming your payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timedOut
                ? 'We still haven\'t seen your payment come through. '
                  'If you completed it, tap "Check now" — otherwise '
                  'you can cancel and try again.'
                : widget.isPlayBilling
    ? 'Complete your purchase in Google Play. '
      'This screen will confirm automatically.'
    : 'Complete the payment in your browser. '
      'This screen will confirm automatically.',
          ),
          if (!timedOut) ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _checking ? null : _check,
          child: Text(_checking ? 'Checking...' : 'Check now'),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<String> benefits;
  final bool isCurrent;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.benefits,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: color, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: color),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(subtitle, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ...benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: color),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}