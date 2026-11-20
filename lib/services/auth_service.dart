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
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'username': username.trim(), 'display_name': displayName.trim()},
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
