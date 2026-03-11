import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> signIn({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        phone: phone,
        password: password,
      );
    } on AuthException catch (e) {
      // If phone login is disabled, try finding the email associated with this phone in profile
      if (phone != null &&
          (e.message.toLowerCase().contains('disabled') ||
              e.message.toLowerCase().contains('invalid login'))) {
        // Strip prefix if any for lookup
        final cleanPhone = phone
            .replaceAll('+', '')
            .replaceAll(RegExp(r'^91'), '');

        final profile = await _client
            .from('profiles')
            .select('email')
            .eq('phone', cleanPhone)
            .maybeSingle();

        if (profile != null && profile['email'] != null) {
          // Try signing in with the email we found
          await _client.auth.signInWithPassword(
            email: profile['email'],
            password: password,
          );
          return;
        }
      }
      rethrow;
    }
  }

  User? get currentUser => _client.auth.currentUser;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
