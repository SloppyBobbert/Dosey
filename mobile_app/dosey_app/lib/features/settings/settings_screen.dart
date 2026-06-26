import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
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
    final platform = currentAppDevicePlatform();
    final usesAppleSignIn = platform == AppDevicePlatform.ios;
    final providerName = usesAppleSignIn ? 'Apple' : 'Google';

    return StreamBuilder<AuthSession>(
      stream: dependencies.auth.watchSession(),
      builder: (context, authSnapshot) {
        final session = authSnapshot.data ?? const AuthSession.signedOut();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _ProfileSummaryCard(session: session),
            const SizedBox(height: 12),
            _SettingsSectionCard(
              icon: Icons.account_circle_outlined,
              title: 'Account',
              children: [
                Text(
                  session.user == null
                      ? 'Signed out. $providerName sign-in is local-only until cloud sync is chosen.'
                      : 'Signed in as ${session.user!.email}',
                ),
                const SizedBox(height: 8),
                const Text('Cloud sync is not active yet.'),
                if (_authMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_authMessage!),
                ],
                const SizedBox(height: 12),
                if (session.isSignedIn)
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _isSigningIn ? null : _signIn,
                    icon: Icon(usesAppleSignIn ? Icons.apple : Icons.login),
                    label: Text(
                      _isSigningIn
                          ? 'Signing in...'
                          : 'Sign in with $providerName',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DeviceModeCard(platform: platform),
            const SizedBox(height: 12),
            const _SafetyCard(),
            const SizedBox(height: 12),
            _SettingsSectionCard(
              icon: Icons.restart_alt,
              title: 'Setup',
              children: [
                const Text(
                  'Show the first-run safety notice and mode selection again.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetSetup,
                  icon: const Icon(Icons.replay_outlined),
                  label: const Text('Start over setup'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _signIn() async {
    final dependencies = DoseyAppScope.of(context);
    final usesAppleSignIn = currentAppDevicePlatform() == AppDevicePlatform.ios;
    final providerName = usesAppleSignIn ? 'Apple' : 'Google';
    setState(() {
      _isSigningIn = true;
      _authMessage = null;
    });
    try {
      if (usesAppleSignIn) {
        await dependencies.auth.signInWithApple();
      } else {
        await dependencies.auth.signInWithGoogle();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _authMessage = '$providerName sign-in is not configured yet: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await DoseyAppScope.of(context).auth.signOut();
      if (!mounted) return;
      setState(() => _authMessage = null);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _authMessage = 'Sign out failed: $error';
      });
    }
  }

  Future<void> _resetSetup() async {
    try {
      await DoseyAppScope.of(context).settings.resetSetupState();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Setup reset failed: $error')));
    }
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = session.user;
    final displayName = user?.displayName?.trim();
    final title = user == null
        ? 'Not signed in'
        : displayName != null && displayName.isNotEmpty
        ? displayName
        : user.email;
    final subtitle = user == null
        ? 'Robot Mode can run locally. Personal Mode sign-in is local-only for now.'
        : user.email;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Text(_avatarLabel(user)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(label: _providerLabel(user)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _avatarLabel(AuthUser? user) {
    if (user == null) return 'D';
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.characters.first.toUpperCase();
    }
    return user.email.characters.first.toUpperCase();
  }

  static String _providerLabel(AuthUser? user) {
    return switch (user?.provider) {
      AuthProvider.google => 'Google account',
      AuthProvider.apple => 'Apple account',
      null => 'Local prototype',
    };
  }
}

class _DeviceModeCard extends StatelessWidget {
  const _DeviceModeCard({required this.platform});

  final AppDevicePlatform platform;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.settings.watchDeviceRole(),
      builder: (context, snapshot) {
        final allowedRoles = AppDeviceRole.allowedFor(platform);
        final fallbackRole = AppDeviceRole.defaultFor(platform);
        final storedRole = snapshot.data;
        final role = storedRole != null && allowedRoles.contains(storedRole)
            ? storedRole
            : fallbackRole;

        return _SettingsSectionCard(
          icon: Icons.phone_android_outlined,
          title: 'Device mode',
          children: [
            DropdownButtonFormField<AppDeviceRole>(
              key: ValueKey('${platform.name}:${role.storageValue}'),
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: allowedRoles
                  .map(
                    (role) =>
                        DropdownMenuItem(value: role, child: Text(role.label)),
                  )
                  .toList(),
              onChanged: (newRole) async {
                if (newRole == null) return;
                try {
                  await dependencies.settings.setDeviceRole(newRole);
                } on Object catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Device role update failed: $error'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              role.canHostRobot
                  ? 'Robot Mode is for the mounted Android phone that controls Dosey hardware.'
                  : 'Personal Mode is for reminders, history, and caregiver-facing features.',
            ),
            if (platform == AppDevicePlatform.ios) ...[
              const SizedBox(height: 8),
              const Text('iOS can only be a personal phone.'),
            ],
          ],
        );
      },
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<bool>(
      stream: dependencies.settings.watchSafetyAcknowledged(),
      builder: (context, snapshot) {
        final acknowledged = snapshot.data ?? false;

        return _SettingsSectionCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Prototype safety',
          children: [
            const Text(
              'Servo movement and reminders do not prove a dose was taken. Confirm doses manually after checking the cup.',
            ),
            const SizedBox(height: 8),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              child: CheckboxListTile(
                value: acknowledged,
                onChanged: (value) async {
                  try {
                    await dependencies.settings.setSafetyAcknowledged(
                      value ?? false,
                    );
                  } on Object catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Safety acknowledgement failed: $error'),
                      ),
                    );
                  }
                },
                title: const Text('I understand prototype safety rules'),
                subtitle: const Text(
                  'Test only with fake pills, candy, beads, dry beans, or vitamins.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
