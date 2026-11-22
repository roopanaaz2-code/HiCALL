import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingService {
  MessagingService._();
  static final instance = MessagingService._();

  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to use chat.');
    return id;
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final id = _userId;
    final rows = await _client
        .from('direct_conversations')
        .select('id, user_a, user_b, created_at')
        .or('user_a.eq.$id,user_b.eq.$id')
        .order('created_at', ascending: false)
        .limit(100);
    if (rows.isEmpty) return [];

    final conversations = List<Map<String, dynamic>>.from(rows);
    final otherIds = conversations
        .map((row) => row['user_a'] == id ? row['user_b'] as String : row['user_a'] as String)
        .toSet()
        .toList();
    final conversationIds = conversations.map((row) => row['id'] as String).toList();

    final profiles = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_path')
        .inFilter('id', otherIds);
    final profileById = {for (final row in profiles) row['id'] as String: Map<String, dynamic>.from(row)};

    final messages = await _client
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false)
        .limit(300);
    final latestByConversation = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final key = message['conversation_id'] as String;
      latestByConversation.putIfAbsent(key, () => Map<String, dynamic>.from(message));
    }

    return conversations.map((row) {
      final conversationId = row['id'] as String;
      final otherId = row['user_a'] == id ? row['user_b'] as String : row['user_a'] as String;
      return {
        ...row,
        'other_user_id': otherId,
        'other_profile': profileById[otherId],
        'latest_message': latestByConversation[conversationId],
      };
    }).where((row) => row['other_profile'] != null).toList();
  }

  Future<String> openConversation(String otherUserId) async {
    final currentId = _userId;
    if (currentId == otherUserId) throw const FormatException('You cannot chat with your own account.');
    final low = currentId.compareTo(otherUserId) < 0 ? currentId : otherUserId;
    final high = currentId.compareTo(otherUserId) < 0 ? otherUserId : currentId;

    final existing = await _client
        .from('direct_conversations')
        .select('id')
        .eq('user_a', low)
        .eq('user_b', high)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;

    try {
      final created = await _client
          .from('direct_conversations')
          .insert({'user_a': low, 'user_b': high})
          .select('id')
          .single();
      return created['id'] as String;
    } on PostgrestException {
      // A simultaneous open from the other account may have created the unique pair.
      final raced = await _client
          .from('direct_conversations')
          .select('id')
          .eq('user_a', low)
          .eq('user_b', high)
          .maybeSingle();
      if (raced != null) return raced['id'] as String;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select('id, conversation_id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    if (text.length > 4000) throw const FormatException('Messages must be 4,000 characters or fewer.');
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _userId,
      'body': text,
    });
  }

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic> message) onInsert,
  ) {
    return _client
        .channel('hicall-chat-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onInsert(Map<String, dynamic>.from(payload.newRecord)),
        )
        .subscribe();
  }

  Future<void> closeChannel(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
