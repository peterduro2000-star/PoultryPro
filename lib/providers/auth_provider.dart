import 'package:flutter/foundation.dart';
import '../services/supabase_auth_service.dart';

enum AuthStatus { unknown, anonymous, verified }

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;

  AuthProvider({SupabaseAuthService? authService})
      : _authService = authService ?? SupabaseAuthService() {
    _resolveStatus();
  }

  String? _userId;
  String? _pendingPhone;
  AuthStatus _status = AuthStatus.unknown;
  bool _isLoading = false;
  String? _error;

  String?    get userId          => _userId;
  String?    get pendingPhone    => _pendingPhone;
  AuthStatus get status          => _status;
  bool       get isAuthenticated => _userId != null;
  bool       get isAnonymous     => _status == AuthStatus.anonymous;
  bool       get isVerified      => _status == AuthStatus.verified;
  bool       get isLoading       => _isLoading;
  String?    get error           => _error;

  // ─── Initialisation ────────────────────────────────────────────────────────

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

  /// Called once at app startup from _AppBootstrap.
  /// Signs in anonymously if no session exists yet.
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

  // ─── Phone OTP upgrade ─────────────────────────────────────────────────────

  /// Step 1 — sends OTP to [phone] (E.164: +2348012345678).
  /// Returns true on success so callers can advance the UI step.
  Future<bool> sendOtp(String phone) async {
    _setLoading();
    try {
      await _authService.sendPhoneOtp(phone);
      _pendingPhone = phone;
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
  /// On success, anonymous account is upgraded to phone-verified.
  /// User ID stays the same — all existing data is preserved.
  Future<bool> verifyOtp(String token) async {
    _setLoading();
    try {
      final phone = _pendingPhone;
      if (phone == null) {
        throw Exception('No pending phone number. Request a code first.');
      }
      await _authService.verifyPhoneOtp(phone, token);
      _userId = _authService.currentUserId;
      _status = AuthStatus.verified;
      _pendingPhone = null;
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

  // ─── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    _setLoading();
    try {
      await _authService.signOut();
      _userId = null;
      _pendingPhone = null;
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
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid') && msg.contains('phone')) {
      return 'Enter a valid phone number with country code, e.g. +2348012345678';
    }
    if (msg.contains('expired') || msg.contains('invalid otp')) {
      return 'Code expired or incorrect. Tap Resend and try again.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection. Check your data or WiFi.';
    }
    return 'Something went wrong. Please try again.';
  }
}