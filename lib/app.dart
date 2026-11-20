import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class HiCallApp extends StatelessWidget {
  const HiCallApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HiCALL', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF070D22),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12C8F4), brightness: Brightness.dark),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF111D3B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF087DE0), foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
    ),
    home: StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) => Supabase.instance.client.auth.currentSession == null
        ? const LoginScreen() : const HomeScreen(),
    ),
  );
}
