import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseAuthService {
  SupabaseClient? get _client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  User? get currentUser => _client?.auth.currentUser;

  String? get currentUserId => currentUser?.id;

  bool get isSignedIn => currentUser != null;

  Future<void> signInWithEmailOtp(String email) async {
    final client = _requireClient();
    await client.auth.signInWithOtp(email: email.trim());
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    final client = _requireClient();
    await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured yet.');
    }
    return client;
  }
}
