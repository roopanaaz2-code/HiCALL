import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> hicallFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FirebasePushService {
  FirebasePushService._();
  static final instance = FirebasePushService._();

  final _openedCalls = StreamController<String>.broadcast();
  String? _pendingCallId;
  Stream<String> get openedCalls => _openedCalls.stream;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(hicallFirebaseBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_publishOpenedCall);
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _publishOpenedCall(initial);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_saveToken(token));
    });
  }

  String? takePendingCallId() {
    final id = _pendingCallId;
    _pendingCallId = null;
    return id;
  }

  void _publishOpenedCall(RemoteMessage message) {
    final id = message.data['call_id'];
    if (id is String && id.isNotEmpty) {
      _pendingCallId = id;
      _openedCalls.add(id);
    }
  }

  Future<void> registerForCurrentUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('call_device_tokens').upsert({
      'user_id': user.id,
      'fcm_token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'fcm_token');
  }

  Future<void> unregisterCurrentDevice() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client
        .from('call_device_tokens')
        .delete()
        .eq('user_id', user.id)
        .eq('fcm_token', token);
  }
}
