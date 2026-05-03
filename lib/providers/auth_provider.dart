import 'package:flutter/foundation.dart';

import '../services/supabase_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _authService;

  AuthProvider({SupabaseAuthService? authService})
      : _authService = authService ?? SupabaseAuthService() {
    _userId = _authService.currentUserId;
  }

  String? _userId;
  bool _isLoading = false;
  String? _error;

  String? get userId => _userId;
  bool get isAuthenticated => _userId != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> sendOtp(String email) async {
    _setLoading();
    try {
      await _authService.signInWithEmailOtp(email);
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String email, String token) async {
    _setLoading();
    try {
      await _authService.verifyEmailOtp(email, token);
      _userId = _authService.currentUserId;
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _setLoading();
    try {
      await _authService.signOut();
      _userId = null;
      _error = null;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }
}
