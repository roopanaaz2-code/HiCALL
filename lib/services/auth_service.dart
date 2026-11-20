import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  final _client = Supabase.instance.client;
  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp({required String email, required String password, required String username, required String displayName}) async {
    final result = await _client.auth.signUp(email: email.trim(), password: password);
    final user = result.user;
    if (user == null) throw const AuthException('Account could not be created.');
    if (result.session == null) return; // Email confirmation is enabled.
    await _client.from('profiles').upsert({'id': user.id, 'username': username.trim(), 'display_name': displayName.trim()});
  }

  Future<void> signOut() => _client.auth.signOut();
}
