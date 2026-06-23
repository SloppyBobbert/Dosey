import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/features/onboarding/onboarding_gate.dart';
import 'package:flutter/material.dart';

class DoseyApp extends StatelessWidget {
  const DoseyApp({super.key, this.database});

  final DoseyDatabase? database;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6F5E);

    return DoseyAppScope(
      database: database,
      child: MaterialApp(
        title: 'Dosey',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
        ),
        home: const OnboardingGate(),
      ),
    );
  }
}
