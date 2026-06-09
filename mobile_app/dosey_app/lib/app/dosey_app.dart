import 'package:dosey_app/features/home/dosey_home_screen.dart';
import 'package:flutter/material.dart';

class DoseyApp extends StatelessWidget {
  const DoseyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F6F5E);

    return MaterialApp(
      title: 'Dosey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      home: const DoseyHomeScreen(),
    );
  }
}
