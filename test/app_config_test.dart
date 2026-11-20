import 'package:flutter_test/flutter_test.dart';
import 'package:hicall/config/app_config.dart';

void main() {
  test('HiCALL uses its dedicated Supabase project', () {
    expect(AppConfig.appName, 'HiCALL');
    expect(AppConfig.supabaseUrl, 'https://vytsirlyzeudwbjymthv.supabase.co');
    expect(AppConfig.supabasePublishableKey, startsWith('sb_publishable_'));
  });
}
