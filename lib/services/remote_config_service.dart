import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches safe, JSON-only runtime settings from Supabase.
///
/// This is configuration delivery, not executable code delivery. Missing or
/// unreachable remote configuration never prevents the app from starting.
class RemoteConfigService {
  RemoteConfigService._();

  static final RemoteConfigService instance = RemoteConfigService._();

  static const Map<String, dynamic> _defaults = {
    'maintenance_mode': false,
    'announcement_enabled': false,
    'announcement_text': '',
    'minimum_supported_version': '1.0.0+1',
    'feature_calls_enabled': true,
    'feature_video_enabled': true,
    'feature_chat_enabled': true,
  };

  final ValueNotifier<Map<String, dynamic>> values =
      ValueNotifier<Map<String, dynamic>>(Map.unmodifiable(_defaults));

  bool getBool(String key, {bool fallback = false}) {
    final value = values.value[key];
    return value is bool ? value : fallback;
  }

  String getString(String key, {String fallback = ''}) {
    final value = values.value[key];
    return value is String ? value : fallback;
  }

  dynamic getValue(String key) => values.value[key];

  /// Refreshes configuration with a short timeout and retains safe defaults
  /// (or settings already loaded during this app session) if the network or backend is unavailable.
  Future<void> refresh({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from('app_remote_config')
          .select('config_key, config_value')
          .timeout(timeout);

      final next = Map<String, dynamic>.from(values.value);
      for (final row in rows) {
        final key = row['config_key'];
        if (key is String && key.isNotEmpty) {
          next[key] = row['config_value'];
        }
      }
      values.value = Map<String, dynamic>.unmodifiable(next);
    } catch (error) {
      // Remote configuration is deliberately fail-open: retain local values.
      debugPrint('HiCALL remote config unavailable; using cached defaults: $error');
    }
  }
}
