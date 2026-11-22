import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

class HiCallApp extends StatelessWidget {
  const HiCallApp({super.key});

  static const _brandBlue = Color(0xFF1678E8);
  static const _brandCyan = Color(0xFF05AFC7);

  ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandBlue,
      secondary: _brandCyan,
      brightness: brightness,
    );
    final page = isDark ? const Color(0xFF091326) : const Color(0xFFF3F7FC);
    final surface = isDark ? const Color(0xFF111E35) : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      appBarTheme: AppBarTheme(
        backgroundColor: page,
        foregroundColor: isDark ? Colors.white : const Color(0xFF14243B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF14243B),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _brandBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _brandBlue.withValues(alpha: isDark ? 0.25 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'HiCALL',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) => Supabase.instance.client.auth.currentSession == null
              ? const LoginScreen()
              : const HomeScreen(),
        ),
      );
}
