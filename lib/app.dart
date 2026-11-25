import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/remote_config_service.dart';


class _GlowingButtonTheme extends StatefulWidget {
  const _GlowingButtonTheme({required this.child});

  final Widget child;

  @override
  State<_GlowingButtonTheme> createState() => _GlowingButtonThemeState();
}

class _GlowingButtonThemeState extends State<_GlowingButtonTheme>
    with SingleTickerProviderStateMixin {
  static const _electricBlue = Color(0xFF168BFF);
  static const _warmGold = Color(0xFFFFC247);

  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) {
          final glow = Color.lerp(
            _electricBlue,
            _warmGold,
            Curves.easeInOut.transform(_glowController.value),
          )!;
          final buttonStyle = ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            shadowColor: WidgetStatePropertyAll(glow),
            elevation: const WidgetStatePropertyAll(7),
            overlayColor: WidgetStatePropertyAll(glow.withValues(alpha: 0.14)),
            side: WidgetStatePropertyAll(
              BorderSide(color: glow.withValues(alpha: 0.82), width: 1.1),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );

          return Theme(
            data: Theme.of(context).copyWith(
              elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
              filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
              outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
              textButtonTheme: TextButtonThemeData(style: buttonStyle),
              iconButtonTheme: IconButtonThemeData(style: buttonStyle),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 7,
                focusElevation: 9,
                hoverElevation: 9,
                highlightElevation: 10,
                splashColor: glow.withValues(alpha: 0.16),
                shape: CircleBorder(
                  side: BorderSide(color: glow.withValues(alpha: 0.82), width: 1.1),
                ),
              ),
            ),
            child: widget.child,
          );
        },
      );
}

Widget _backgroundFallback(BuildContext context, Object error, StackTrace? stackTrace) =>
    const ColoredBox(color: Color(0xFF071326));

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
      scaffoldBackgroundColor: Colors.transparent,
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
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        builder: (context, child) => ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: RemoteConfigService.instance.values,
          builder: (context, config, _) {
            final maintenance = config['maintenance_mode'] == true;
            final announcementEnabled = config['announcement_enabled'] == true;
            final announcement = config['announcement_text'];
            return Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF071326)),
                ),
                const Positioned.fill(
                  child: Image(
                    image: NetworkImage('https://vytsirlyzeudwbjymthv.supabase.co/storage/v1/object/public/hicall-avatars/hicall_assests/file_0000000030608208b214178208b745c3.png'),
                    fit: BoxFit.cover,
                    errorBuilder: _backgroundFallback,
                  ),
                ),
                const Positioned.fill(
                  child: ColoredBox(color: Color(0x66051020)),
                ),
                _GlowingButtonTheme(child: child ?? const SizedBox.shrink()),
                if (announcementEnabled &&
                    announcement is String &&
                    announcement.trim().isNotEmpty &&
                    !maintenance)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: const Color(0xFF164A77),
                      borderRadius: BorderRadius.circular(12),
                      elevation: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          announcement,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (maintenance)
                  const Positioned.fill(
                    child: Material(
                      color: Color(0xF2091020),
                      child: SafeArea(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.construction, color: Colors.white, size: 52),
                                SizedBox(height: 18),
                                Text(
                                  'HiCALL is temporarily unavailable',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Please try again shortly.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) => Supabase.instance.client.auth.currentSession == null
              ? const LoginScreen()
              : const HomeScreen(),
        ),
      );
}
