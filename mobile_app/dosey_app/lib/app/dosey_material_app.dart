import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';

class DoseyMaterialApp extends StatelessWidget {
  const DoseyMaterialApp({super.key, required this.home});

  static const _navy = Color(0xFF102A43);
  static const _cyan = Color(0xFF00A8E8);

  final Widget home;

  @override
  Widget build(BuildContext context) {
    final settings = DoseyAppScope.of(context).settings;
    return StreamBuilder<AppThemePreference>(
      stream: settings.watchThemePreference(),
      initialData: AppThemePreference.dark,
      builder: (context, snapshot) {
        final preference = snapshot.data ?? AppThemePreference.dark;
        return MaterialApp(
          title: 'Dosey',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [doseyRouteObserver],
          themeMode: switch (preference) {
            AppThemePreference.dark => ThemeMode.dark,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.system => ThemeMode.system,
          },
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: home,
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _navy, brightness: brightness).copyWith(
          primary: _cyan,
          onPrimary: const Color(0xFF00263A),
          primaryContainer: brightness == Brightness.light
              ? const Color(0xFFD5F4FF)
              : const Color(0xFF004D6C),
          onPrimaryContainer: brightness == Brightness.light
              ? const Color(0xFF00344B)
              : const Color(0xFFD5F4FF),
          secondary: _navy,
          surface: brightness == Brightness.light
              ? const Color(0xFFF8FAFC)
              : const Color(0xFF101923),
          surfaceContainerHighest: brightness == Brightness.light
              ? const Color(0xFFE8EEF3)
              : const Color(0xFF263442),
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
