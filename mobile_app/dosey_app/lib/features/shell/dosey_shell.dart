import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';

class DoseyShell extends StatefulWidget {
  const DoseyShell({super.key});

  @override
  State<DoseyShell> createState() => _DoseyShellState();
}

class _DoseyShellState extends State<DoseyShell> {
  int _selectedIndex = 0;

  static const _screens = [
    TodayScreen(),
    PrescriptionsScreen(),
    RemindersScreen(),
    CarouselScreen(),
    ControllerScreen(),
    DoseLogScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final platform = currentAppDevicePlatform();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosey'),
        actions: [
          StreamBuilder<AuthSession>(
            stream: dependencies.auth.watchSession(),
            builder: (context, authSnapshot) {
              final session =
                  authSnapshot.data ?? const AuthSession.signedOut();

              return StreamBuilder<AppDeviceRole>(
                stream: dependencies.settings.watchDeviceRole(),
                builder: (context, roleSnapshot) {
                  final role = _resolvedRole(roleSnapshot.data, platform);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      tooltip: 'Open profile menu',
                      onPressed: () {
                        _showProfileMenu(session: session, role: role);
                      },
                      icon: CircleAvatar(
                        radius: 16,
                        child: Text(_avatarLabel(session.user)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_carousel_outlined),
            selectedIcon: Icon(Icons.view_carousel),
            label: 'Carousel',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Controller',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  static AppDeviceRole _resolvedRole(
    AppDeviceRole? storedRole,
    AppDevicePlatform platform,
  ) {
    final allowedRoles = AppDeviceRole.allowedFor(platform);
    if (storedRole != null && allowedRoles.contains(storedRole)) {
      return storedRole;
    }
    return AppDeviceRole.defaultFor(platform);
  }

  Future<void> _showProfileMenu({
    required AuthSession session,
    required AppDeviceRole role,
  }) {
    final dependencies = DoseyAppScope.of(context);
    final platform = currentAppDevicePlatform();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _ProfileMenuSheet(
          session: session,
          role: role,
          onOpenSettings: () {
            Navigator.of(sheetContext).pop();
            _selectTab(_settingsTabIndex);
          },
          onOpenSafety: () {
            Navigator.of(sheetContext).pop();
            _selectTab(_settingsTabIndex);
          },
          onResetSetup: () async {
            Navigator.of(sheetContext).pop();
            try {
              await dependencies.settings.resetSetupState();
            } on Object catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Setup reset failed: $error')),
              );
            }
          },
          onSignIn: () async {
            Navigator.of(sheetContext).pop();
            final providerName = platform == AppDevicePlatform.ios
                ? 'Apple'
                : 'Google';
            try {
              if (platform == AppDevicePlatform.ios) {
                await dependencies.auth.signInWithApple();
              } else {
                await dependencies.auth.signInWithGoogle();
              }
            } on Object catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$providerName sign-in is not configured yet: $error',
                  ),
                ),
              );
            }
          },
          onSignOut: () async {
            Navigator.of(sheetContext).pop();
            try {
              await dependencies.auth.signOut();
            } on Object catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sign out failed: $error')),
              );
            }
          },
        );
      },
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static String _avatarLabel(AuthUser? user) {
    if (user == null) return 'D';
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name.characters.first.toUpperCase();
    }
    return user.email.characters.first.toUpperCase();
  }
}

const _settingsTabIndex = 6;

class _ProfileMenuSheet extends StatelessWidget {
  const _ProfileMenuSheet({
    required this.session,
    required this.role,
    required this.onOpenSettings,
    required this.onOpenSafety,
    required this.onResetSetup,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthSession session;
  final AppDeviceRole role;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSafety;
  final Future<void> Function() onResetSetup;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onSignOut;

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
    final subtitle = user == null ? 'Local prototype mode' : user.email;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(
          'Profile menu',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(_DoseyShellState._avatarLabel(user)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MenuChip(label: _providerLabel(user)),
                          _MenuChip(label: role.label),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          subtitle: const Text('Account, device mode, and setup'),
          onTap: onOpenSettings,
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('Safety'),
          subtitle: const Text('Prototype rules and manual confirmation'),
          onTap: onOpenSafety,
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Start over setup'),
          subtitle: const Text('Show first-run setup again'),
          onTap: onResetSetup,
        ),
        const Divider(),
        ListTile(
          leading: Icon(session.isSignedIn ? Icons.logout : Icons.login),
          title: Text(session.isSignedIn ? 'Sign out' : 'Sign in'),
          subtitle: Text(
            session.isSignedIn
                ? 'Return this phone to local signed-out mode'
                : 'Use the configured local prototype provider',
          ),
          onTap: session.isSignedIn ? onSignOut : onSignIn,
        ),
      ],
    );
  }

  static String _providerLabel(AuthUser? user) {
    return switch (user?.provider) {
      AuthProvider.google => 'Google account',
      AuthProvider.apple => 'Apple account',
      null => 'Local prototype',
    };
  }
}

class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.label});

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
