import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
    final sent = await auth.sendSignInOtp(_emailController.text.trim());
    if (sent && mounted) {
      setState(() => _otpSent = true);
    } else if (mounted) {
      _showError(auth.error ?? 'Failed to send code');
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifySignInOtp(_otpController.text.trim());
    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      _showError(auth.error ?? 'Incorrect code');
    }
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sign In'),
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
                        Icons.person_outlined,
                        size: 44,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),

                  Text('Sign in to your account',
                      style: AppTheme.headingMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Enter the email linked to your existing Poultry Pro account. '
                    'We\'ll send you a verification code.',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  if (!_otpSent) ...[
                    Text('Email address',
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
                            : const Text('Verify and sign in'),
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
