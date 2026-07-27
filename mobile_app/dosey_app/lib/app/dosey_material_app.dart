import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';

class DoseyMaterialApp extends StatelessWidget {
  const DoseyMaterialApp({super.key, required this.home});

  static const _seed = Color(0xFF2F6F5E);

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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _seed,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _seed,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: home,
        );
      },
    );
  }
}
