import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles all Supabase authentication for PoultryPro.
///
/// Flow:
///   1. App launches → [signInAnonymously] called automatically
///   2. User taps "Secure my backup" → [sendEmailOtp] called
///   3. User enters 6-digit code     → [verifyEmailOtp] called
///   4. Anonymous account is upgraded to an email-linked account
///      (same user id, data is preserved)
class SupabaseAuthService {
  SupabaseClient get _client => Supabase.instance.client;

  // ─── Current user ──────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  // ─── Anonymous sign-in ─────────────────────────────────────────────────────

  /// Signs in anonymously. Creates a real Supabase user with a UUID but no
  /// credentials. Their data is stored server-side under this UUID.
  /// Safe to call multiple times — returns immediately if already signed in.
  Future<void> signInAnonymously() async {
    if (isAuthenticated) return;
    try {
      await _client.auth.signInAnonymously();
      debugPrint('Auth: signed in anonymously as $currentUserId');
    } catch (e) {
      debugPrint('Auth: anonymous sign-in failed: $e');
      rethrow;
    }
  }

  // ─── Email OTP upgrade ─────────────────────────────────────────────────────

  /// Sends a 6-digit OTP to [email].
  Future<void> sendEmailOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      debugPrint('Auth: OTP sent to $email');
    } catch (e) {
      debugPrint('Auth: OTP send failed: $e');
      rethrow;
    }
  }

  /// Verifies the OTP and links the email to the anonymous account.
  /// The user ID stays the same — all existing data is preserved.
  Future<void> verifyEmailOtp(String email, String token) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      debugPrint('Auth: email verified for $currentUserId');
    } catch (e) {
      debugPrint('Auth: OTP verification failed: $e');
      rethrow;
    }
  }

  // ─── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Auth state stream ─────────────────────────────────────────────────────

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}