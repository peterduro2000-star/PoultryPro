import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// "Secure your backup" screen — upgrades anonymous → email-verified account.
/// User ID stays the same; all data is preserved.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _emailController = TextEditingController(); // ← was phone
  final _otpController   = TextEditingController();
  final _formKey         = GlobalKey<FormState>();

  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.sendOtp(_emailController.text.trim());
    if (auth.error == null && mounted) {
      setState(() => _otpSent = true);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(_otpController.text.trim());
    if (success && mounted) {

  await Future.delayed(
    const Duration(milliseconds: 500),
  );

  Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
  children: [
    Icon(Icons.check_circle, color: Colors.white, size: 18),
    SizedBox(width: 8),
    Expanded(                                       // ← takes remaining width
      child: Text('Your data is now backed up securely!'),
    ),
  ],
),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Secure Your Data'),
        elevation: 0,
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.spacingLG,
              AppTheme.spacingLG,
              AppTheme.spacingLG,
              MediaQuery.paddingOf(context).bottom + AppTheme.spacingLG,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_done_outlined,
                        size: 44,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),

                  Text('Keep your farm data safe',
                      style: AppTheme.headingMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Your records, flocks, and finances are currently '
                    'stored only on this phone. If your phone is lost or '
                    'damaged, your data is gone.\n\n'
                    'Link your email to back up automatically — '
                    'no password needed.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  if (!_otpSent) ...[
                    Text('Your email address',
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: AppTheme.inputDecoration(
                              'e.g. yourname@gmail.com')
                          .copyWith(
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email address';
                        }
                        if (!v.trim().contains('@') ||
                            !v.trim().contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    if (auth.error != null) _ErrorBanner(auth.error!),
                    const SizedBox(height: AppTheme.spacingSM),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _sendOtp,
                        style: AppTheme.primaryButtonStyle,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send verification code'),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Code sent to ${auth.pendingEmail}',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Text('Enter the 6-digit code',
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration:
                          AppTheme.inputDecoration('6-digit code').copyWith(
                        prefixIcon: const Icon(Icons.lock_outline),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length != 6) {
                          return 'Enter the 6-digit code from your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    if (auth.error != null) _ErrorBanner(auth.error!),
                    const SizedBox(height: AppTheme.spacingSM),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _verifyOtp,
                        style: AppTheme.primaryButtonStyle,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify and secure my data'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Center(
                      child: TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                }),
                        child: Text(
                          'Wrong email? Go back',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacingXL),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.secondaryColor.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 18, color: AppTheme.secondaryColor),
                        const SizedBox(width: AppTheme.spacingSM),
                        Expanded(
                          child: Text(
                            'Your email is only used to protect your '
                            'account. We never share it or send marketing messages.',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
          const SizedBox(width: AppTheme.spacingSM),
          Expanded(
            child: Text(
              message,
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}