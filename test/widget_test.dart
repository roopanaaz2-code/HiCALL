import 'package:flutter_test/flutter_test.dart';
import 'package:hicall/config/app_config.dart';

void main() {
  test('HiCALL client points at its dedicated backend', () {
    expect(AppConfig.appName, 'HiCALL');
    expect(AppConfig.supabaseUrl, 'https://vytsirlyzeudwbjymthv.supabase.co');
    expect(AppConfig.supabasePublishableKey, startsWith('sb_publishable_'));
  });
}
