import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/features/onboarding/onboarding_flow.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key, this.onboardingCompletedStream});

  final Stream<bool>? onboardingCompletedStream;

  @override
  Widget build(BuildContext context) {
    final onboardingCompleted =
        onboardingCompletedStream ??
        DoseyAppScope.of(context).settings.watchOnboardingCompleted();

    return StreamBuilder<bool>(
      stream: onboardingCompleted,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Setup could not load',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Close and reopen Dosey, then try again.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

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
