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

  Future<CallCredentials> startCall({required String recipientId, required String callType}) async {
    final response = await _client.functions.invoke(AppConfig.callControlFunction,
      body: {'action': 'start', 'recipient_id': recipientId, 'call_type': callType});
    if (response.status < 200 || response.status >= 300) throw Exception('Call request failed (${response.status}).');
    return CallCredentials.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> endCall(String callId) async {
    final response = await _client.functions.invoke(AppConfig.callControlFunction,
      body: {'action': 'end', 'call_id': callId});
    if (response.status < 200 || response.status >= 300) throw Exception('Could not end call (${response.status}).');
  }
}
