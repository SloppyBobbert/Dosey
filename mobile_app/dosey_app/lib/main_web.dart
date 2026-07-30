import 'package:dosey_app/app/web/dosey_web_app.dart';
import 'package:dosey_app/app/web/dosey_web_dependencies.dart';
import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:dosey_app/core/cloud/cloud_gateway_factory.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = WebAuthConfiguration.fromEnvironment;
    final cloudConfiguration = CloudConfiguration.fromEnvironment;
    final gateways = createWebCloudGateways(cloudConfiguration);
    runApp(
      DoseyWebApp(
        dependencies: DoseyWebDependencies(
          identity: gateways.identity,
          config: config,
          household: gateways.household,
          householdManagement: gateways.householdManagement,
          caregiver: gateways.caregiver,
        ),
      ),
    );
  } catch (error) {
    runApp(DoseyWebStartupError(diagnostic: error.toString()));
  }
}

class DoseyWebStartupError extends StatelessWidget {
  const DoseyWebStartupError({super.key, required this.diagnostic});

  final String diagnostic;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Dosey',
    theme: ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F1E8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF174C4F),
        primary: const Color(0xFF174C4F),
        secondary: const Color(0xFFE08A5B),
        surface: const Color(0xFFFFFCF5),
      ),
      fontFamily: 'Georgia',
    ),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Dosey couldn’t start',
                      style: TextStyle(
                        color: Color(0xFF174C4F),
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Check the web configuration and reload this page.',
                      style: TextStyle(fontSize: 17, height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    SelectableText(diagnostic),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
