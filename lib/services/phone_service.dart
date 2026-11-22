import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneService {
  PhoneService._();
  static final instance = PhoneService._();

  final SupabaseClient _client = Supabase.instance.client;

  static String normalize(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(compact)) {
      throw const FormatException('Enter the full number with country code, for example +14155550123.');
    }
    return compact;
  }

  Future<void> requestVerification(String value) async {
    final phone = normalize(value);
    await _client.auth.updateUser(UserAttributes(phone: phone));
  }

  Future<void> verify(String value, String code) async {
    final phone = normalize(value);
    final otp = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const FormatException('Enter the six-digit code from your SMS.');
    }
    await _client.auth.verifyOTP(
      type: OtpType.phoneChange,
      phone: phone,
      token: otp,
    );
  }

  Future<Map<String, dynamic>?> ownVerifiedPhone() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
      .from('user_phone_numbers')
      .select('phone_e164, verified_at, discoverable')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> searchByPhone(String value) async {
    final phone = normalize(value);
    final result = await _client.functions.invoke(
      'search-users',
      body: {'phone': phone},
    );
    if (result.status < 200 || result.status >= 300) {
      final data = result.data;
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'Phone search failed (${result.status}).');
    }
    final data = Map<String, dynamic>.from(result.data as Map);
    final user = data['user'];
    return user is Map ? Map<String, dynamic>.from(user) : null;
  }

  Future<void> disableOwnPhoneDiscovery() async {
    final result = await _client.functions.invoke(
      'manage-phone',
      body: const {'action': 'remove'},
    );
    if (result.status < 200 || result.status >= 300) {
      final data = result.data;
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'Could not hide your number from search (${result.status}).');
    }
  }

  Future<void> enableOwnPhoneDiscovery() async {
    final result = await _client.functions.invoke(
      'manage-phone',
      body: const {'action': 'enable'},
    );
    if (result.status < 200 || result.status >= 300) {
      final data = result.data;
      final message = data is Map ? data['error'] : null;
      throw Exception(message?.toString() ?? 'Could not enable phone search (${result.status}).');
    }
  }
}
