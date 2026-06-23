import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/features/onboarding/onboarding_flow.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = DoseyAppScope.of(context).settings;

    return StreamBuilder<bool>(
      stream: settings.watchOnboardingCompleted(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!) {
          return const DoseyShell();
        }

        return const OnboardingFlow();
      },
    );
  }
}
