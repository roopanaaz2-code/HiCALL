import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().length < 3) return [];
    final rows = await _client.from('profiles')
      .select('id, username, display_name, avatar_path')
      .ilike('username', '%${query.trim()}%')
      .neq('id', _client.auth.currentUser!.id).limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> myProfile() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return await _client.from('profiles')
      .select('id, username, display_name, avatar_path').eq('id', id).maybeSingle();
  }
}
