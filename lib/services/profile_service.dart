import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final value = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(value)) return [];
    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_path')
        .ilike('username', value)
        .neq('id', _client.auth.currentUser!.id)
        .limit(1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> myProfile() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return await _client
        .from('profiles')
        .select('id, username, display_name, avatar_path')
        .eq('id', id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> updateMyProfile({
    required String username,
    required String displayName,
  }) async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to edit your profile.');
    final cleanUsername = username.trim();
    final cleanDisplayName = displayName.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch(cleanUsername)) {
      throw const FormatException('Username must be 3–24 characters using letters, numbers or underscore.');
    }
    if (cleanDisplayName.isEmpty || cleanDisplayName.length > 60) {
      throw const FormatException('Display name must contain 1–60 characters.');
    }
    final row = await _client
        .from('profiles')
        .update({
          'username': cleanUsername,
          'display_name': cleanDisplayName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select('id, username, display_name, avatar_path')
        .single();
    return Map<String, dynamic>.from(row);
  }
}
