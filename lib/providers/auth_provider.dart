import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
enum AuthStatus { unknown, anonymous, verified }

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;

  AuthProvider({SupabaseAuthService? authService})
      : _authService = authService ?? SupabaseAuthService() {
    _resolveStatus();
  }

  String? _userId;
  String? _pendingEmail; // ← was _pendingPhone
  AuthStatus _status = AuthStatus.unknown;
  bool _isFirstLaunch = true;
  bool _isLoading = false;
  String? _error;

  String?    get userId         => _userId;
  String?    get pendingEmail   => _pendingEmail; // ← was pendingPhone
  bool       get isFirstLaunch  => _isFirstLaunch;
  AuthStatus get status         => _status;
  bool       get isAuthenticated => _userId != null;
  bool       get isAnonymous    => _status == AuthStatus.anonymous;
  bool       get isVerified     => _status == AuthStatus.verified;
  bool       get isLoading      => _isLoading;
  String?    get error          => _error;

  // ─── Initialisation ────────────────────────────────────────────────────────

  Future<void> checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    _isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    _isFirstLaunch = false;
    notifyListeners();
  }

  void _resolveStatus() {
    if (!_authService.isAuthenticated) {
      _status = AuthStatus.unknown;
    } else if (_authService.isAnonymous) {
      _status = AuthStatus.anonymous;
      _userId = _authService.currentUserId;
    } else {
      _status = AuthStatus.verified;
      _userId = _authService.currentUserId;
    }
  }

  Future<void> initSession() async {
    _setLoading();
    try {
      if (!_authService.isAuthenticated) {
        await _authService.signInAnonymously();
      }
      _userId = _authService.currentUserId;
      _status = _authService.isAnonymous
          ? AuthStatus.anonymous
          : AuthStatus.verified;
      _error = null;
    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('AuthProvider.initSession: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Email OTP upgrade ─────────────────────────────────────────────────────

  /// Step 1 — sends OTP to [email].
  Future<bool> sendOtp(String email) async {
    _setLoading();
    try {
      await _authService.sendEmailOtp(email);
      _pendingEmail = email;
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('AuthProvider.sendOtp: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step 2 — verifies the 6-digit OTP.
  /// Upgrades anonymous account to email-verified.
  /// User ID stays the same — all existing data is preserved.
  Future<bool> verifyOtp(String token) async {
    _setLoading();

    try {
      final email = _pendingEmail;

      if (email == null) {
        throw Exception('No pending email.');
      }

      await _authService.verifyEmailOtp(email, token);
      await Supabase.instance.client.auth.refreshSession();

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Session not created after verification');
      }

      _userId = user.id;
      _status = AuthStatus.verified;
      _pendingEmail = null;
      _error = null;

      return true;

    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('AuthProvider.verifyOtp: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendSignInOtp(String email) async {
    _setLoading();
    try {
      await _authService.sendSignInOtp(email);
      _pendingEmail = email;
      _error = null;
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('AuthProvider.sendSignInOtp: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifySignInOtp(String token) async {
    _setLoading();
    try {
      final email = _pendingEmail;

      if (email == null) {
        throw Exception('No pending email.');
      }

      await _authService.verifySignInOtp(email, token);
      await Supabase.instance.client.auth.refreshSession();

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Session not created after verification');
      }

      _userId = user.id;
      _status = AuthStatus.verified;
      _pendingEmail = null;
      _error = null;

      return true;

    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('AuthProvider.verifySignInOtp: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // ─── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _setLoading();
    try {
      await _authService.signOut();
      _userId = null;
      _pendingEmail = null;
      _status = AuthStatus.unknown;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('AuthProvider.signOut: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final raw = e.toString().toLowerCase();
    debugPrint('AuthProvider._friendlyError raw: $e');

    if (raw.contains('already registered') || raw.contains('already exists') ||
        (raw.contains('email') && raw.contains('taken'))) {
      return 'This email is already linked to another PoultryPro account. '
          'Please use a different email, or contact support if this is your account.';
    }
    if (raw.contains('invalid') && raw.contains('email')) {
      return 'Enter a valid email address.';
    }
    if (raw.contains('expired') || raw.contains('invalid otp')) {
      return 'Code expired or incorrect. Tap Resend and try again.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'No internet connection. Check your data or WiFi.';
    }
    if (raw.contains('user not found') || raw.contains('no user') ||
        raw.contains('invalid login') || raw.contains('no account')) {
      return 'No account found for this email. Choose "Protect My Data" to create a backup, or use a different email.';
    }
    if (raw.contains('otp') || raw.contains('code') || raw.contains('verification')) {
      return 'Unable to send verification code. Please try again.';
    }
    if (raw.contains('not authenticated') || raw.contains('no session') ||
        raw.contains('unauthorized')) {
      return 'Session expired. Please restart the app and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}