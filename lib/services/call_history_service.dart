import 'package:supabase_flutter/supabase_flutter.dart';

class CallHistoryService {
  CallHistoryService._();
  static final instance = CallHistoryService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> clear() async {
    final response = await _client.functions.invoke('call-history', body: const {'action': 'clear'});
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Unable to clear call history.');
    }
  }

  Future<List<Map<String, dynamic>>> load() async {
    final response = await _client.functions.invoke('call-history', body: const {});
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'Call history failed (${response.status}).');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    return List<Map<String, dynamic>>.from(data['calls'] as List? ?? const []);
  }
}
