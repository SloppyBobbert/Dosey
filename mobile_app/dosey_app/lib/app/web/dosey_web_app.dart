import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter/material.dart';

import 'dosey_web_dependencies.dart';
import 'web_routes.dart';

class DoseyWebApp extends StatelessWidget {
  const DoseyWebApp({super.key, required this.dependencies, this.initialRoute});

  final DoseyWebDependencies dependencies;
  final String? initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(
        '${initialRoute ?? 'platform'}:${dependencies.config.appOrigin}',
      ),
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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) => buildWebRoute(settings, dependencies),
    );
  }
}

class DoseyPersonalHome extends StatefulWidget {
  const DoseyPersonalHome({
    super.key,
    required this.identity,
    required this.onSignOut,
    required this.isStaging,
  });

  final CloudIdentity identity;
  final Future<void> Function() onSignOut;
  final bool isStaging;

  @override
  State<DoseyPersonalHome> createState() => _DoseyPersonalHomeState();
}

class _DoseyPersonalHomeState extends State<DoseyPersonalHome> {
  bool _busy = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'That did not work. Check your connection and try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const DoseyMark(),
                const SizedBox(height: 56),
                if (widget.isStaging) const _StagingBanner(),
                Text(
                  'Dosey Personal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF174C4F),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.identity.email ?? 'Signed-in account',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 30),
                const _InfoCard(),
                const SizedBox(height: 30),
                OutlinedButton(
                  onPressed: _busy ? null : _signOut,
                  child: const Text('Sign out'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFE7EFEB),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'This is the first web lane for Dosey Personal. It is a place to validate account access and the shape of the experience. Medication schedules, device controls, and reminders are not available here yet.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
      ),
    ),
  );
}

class _StagingBanner extends StatelessWidget {
  const _StagingBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE0B2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text('Staging environment · account access is for testing'),
  );
}

class DoseyMark extends StatelessWidget {
  const DoseyMark({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFE08A5B),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'dosey',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: const Color(0xFF174C4F),
        ),
      ),
    ],
  );
}
