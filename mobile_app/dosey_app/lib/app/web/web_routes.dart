import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter/material.dart';

import 'dosey_web_app.dart';
import 'dosey_web_dependencies.dart';
import 'web_auth_gate.dart';
import 'web_household_gate.dart';

abstract final class WebRoutes {
  static const root = '/';
  static const signIn = '/sign-in/';
  static const household = '/household/';
  static const today = '/app/today/';
  static const medications = '/app/medications/';
  static const schedules = '/app/schedules/';
  static const account = '/app/account/';

  static const protected = <String>{
    household,
    today,
    medications,
    schedules,
    account,
  };
}

Route<void> buildWebRoute(
  RouteSettings settings,
  DoseyWebDependencies dependencies,
) {
  final name = settings.name ?? WebRoutes.root;
  final page = switch (name) {
    WebRoutes.root => const WebLandingScreen(),
    WebRoutes.signIn => WebAuthGate(
      key: ValueKey(dependencies.config.appOrigin),
      dependencies: dependencies,
    ),
    _ when WebRoutes.protected.contains(name) => WebAuthGate(
      dependencies: dependencies,
      authenticatedBuilder: (context, identity) =>
          _protectedPage(name, identity, dependencies),
    ),
    _ => const WebNotFoundScreen(),
  };
  return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
}

Widget _protectedPage(
  String route,
  CloudIdentity identity,
  DoseyWebDependencies dependencies,
) {
  if (route == WebRoutes.account) {
    return DoseyPersonalHome(
      identity: identity,
      isStaging: dependencies.config.isStaging,
      onSignOut: dependencies.identity.signOut,
    );
  }
  return WebHouseholdGate(dependencies: dependencies, route: route);
}

class WebLandingScreen extends StatelessWidget {
  const WebLandingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DoseyMark(),
                const SizedBox(height: 48),
                Text(
                  'Medication care, shared clearly.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: const Color(0xFF174C4F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'See today’s plan, keep schedules current, and help your household stay in sync.',
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, WebRoutes.signIn),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class WebNotFoundScreen extends StatelessWidget {
  const WebNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page not found'),
          TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              WebRoutes.root,
              (_) => false,
            ),
            child: const Text('Back to Dosey'),
          ),
        ],
      ),
    ),
  );
}
