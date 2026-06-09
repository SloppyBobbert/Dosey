import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningIn = false;
  String? _authMessage;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StreamBuilder<AuthSession>(
          stream: dependencies.auth.watchSession(),
          builder: (context, snapshot) {
            final session = snapshot.data ?? const AuthSession.signedOut();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google login',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.user == null
                          ? 'Signed out. Google sign-in is local-only until cloud sync is chosen.'
                          : 'Signed in as ${session.user!.email}',
                    ),
                    if (_authMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_authMessage!),
                    ],
                    const SizedBox(height: 12),
                    if (session.isSignedIn)
                      OutlinedButton(
                        onPressed: () => dependencies.auth.signOut(),
                        child: const Text('Sign out'),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: _isSigningIn
                            ? null
                            : () async {
                                setState(() {
                                  _isSigningIn = true;
                                  _authMessage = null;
                                });
                                try {
                                  await dependencies.auth.signInWithGoogle();
                                } on Object catch (error) {
                                  setState(() {
                                    _authMessage =
                                        'Google sign-in is not configured yet: $error';
                                  });
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isSigningIn = false;
                                    });
                                  }
                                }
                              },
                        child: Text(
                          _isSigningIn
                              ? 'Signing in...'
                              : 'Sign in with Google',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<AppDeviceRole>(
          stream: dependencies.settings.watchDeviceRole(),
          builder: (context, snapshot) {
            final role = snapshot.data ?? AppDeviceRole.androidPersonal;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device role',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AppDeviceRole>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: AppDeviceRole.allowedFor(AppDevicePlatform.android)
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            ),
                          )
                          .toList(),
                      onChanged: (newRole) {
                        if (newRole != null) {
                          dependencies.settings.setDeviceRole(newRole);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('iOS can only be a personal phone.'),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<bool>(
          stream: dependencies.settings.watchSafetyAcknowledged(),
          builder: (context, snapshot) {
            final acknowledged = snapshot.data ?? false;
            return Card(
              child: CheckboxListTile(
                value: acknowledged,
                onChanged: (value) {
                  dependencies.settings.setSafetyAcknowledged(value ?? false);
                },
                title: const Text('I understand prototype safety rules'),
                subtitle: const Text(
                  'Test only with fake pills, candy, beads, dry beans, or vitamins.',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
