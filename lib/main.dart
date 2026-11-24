import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'services/firebase_push_service.dart';
import 'services/remote_config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  unawaited(RemoteConfigService.instance.refresh());
  await FirebasePushService.instance.initialize();
  runApp(const HiCallApp());
}
