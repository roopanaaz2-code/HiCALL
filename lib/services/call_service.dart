import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class CallCredentials {
  const CallCredentials({required this.callId, required this.roomName, required this.serverUrl, required this.token, required this.callType});
  final String callId, roomName, serverUrl, token, callType;
  factory CallCredentials.fromJson(Map<String, dynamic> json) => CallCredentials(
    callId: json['call_id'] as String, roomName: json['room_name'] as String,
    serverUrl: json['server_url'] as String, token: json['token'] as String,
    callType: json['call_type'] as String);
}

class CallService {
  CallService._();
  static final instance = CallService._();
  final _client = Supabase.instance.client;

  Future<CallCredentials> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(AppConfig.callControlFunction, body: body);
    if (response.status < 200 || response.status >= 300) {
      final message = response.data is Map ? (response.data as Map)['error'] : null;
      throw Exception(message ?? 'Call request failed (${response.status}).');
    }
    return CallCredentials.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<CallCredentials> startCall({required String recipientId, required String callType}) =>
    _invoke({'action': 'start', 'recipient_id': recipientId, 'call_type': callType});

  Future<CallCredentials> joinCall(String callId) => _invoke({'action': 'join', 'call_id': callId});

  Future<void> declineCall(String callId) async {
    final response = await _client.functions.invoke(AppConfig.callControlFunction,
      body: {'action': 'decline', 'call_id': callId});
    if (response.status < 200 || response.status >= 300) { throw Exception('Unable to decline call.'); }
  }

  RealtimeChannel watchCallStatus(
    String callId,
    void Function(String status) onStatus,
  ) {
    return _client
        .channel('hicall-call-state-$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null) onStatus(status);
          },
        )
        .subscribe();
  }

  Future<void> endCall(String callId) async {
    final response = await _client.functions.invoke(AppConfig.callControlFunction,
      body: {'action': 'end', 'call_id': callId});
    if (response.status < 200 || response.status >= 300) { throw Exception('Could not end call.'); }
  }
}
