import 'package:supabase_flutter/supabase_flutter.dart';

class ContactService {
  ContactService._();
  static final instance = ContactService._();

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) { throw const AuthException('Sign in to manage contacts.'); }
    return id;
  }

  Future<List<Map<String, dynamic>>> listContacts() async {
    final rows = await _client
        .from('user_contacts')
        .select('contact_id, created_at')
        .eq('owner_id', _userId)
        .order('created_at', ascending: false)
        .limit(200);
    final ids = rows.map((row) => row['contact_id'] as String).toList();
    if (ids.isEmpty) { return []; }
    final profiles = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_path')
        .inFilter('id', ids);
    final byId = {for (final row in profiles) row['id'] as String: Map<String, dynamic>.from(row)};
    return ids.where(byId.containsKey).map((id) => byId[id]!).toList();
  }

  Future<void> addContact(String contactId) async {
    if (contactId == _userId) { throw const FormatException('You cannot add your own account.'); }
    await _client.from('user_contacts').insert({'owner_id': _userId, 'contact_id': contactId});
  }

  Future<void> removeContact(String contactId) async {
    await _client
        .from('user_contacts')
        .delete()
        .eq('owner_id', _userId)
        .eq('contact_id', contactId);
  }

  Future<bool> isContact(String contactId) async {
    final row = await _client
        .from('user_contacts')
        .select('contact_id')
        .eq('owner_id', _userId)
        .eq('contact_id', contactId)
        .maybeSingle();
    return row != null;
  }
}
