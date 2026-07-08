import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
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
            _ProfileSummaryCard(session: session, platform: platform),
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
            const _RobotFaceSettingsSection(),
            const SizedBox(height: 12),
            const _ReminderNotificationCard(),
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
  const _ProfileSummaryCard({required this.session, required this.platform});

  final AuthSession session;
  final AppDevicePlatform platform;

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
        ? platform == AppDevicePlatform.ios
              ? 'iOS uses Personal Mode only. Sign-in stays local-only for now.'
              : 'Robot Mode can run locally. Personal Mode sign-in is local-only for now.'
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
            _DeviceModeDropdown(
              key: ValueKey('${platform.name}:${role.storageValue}'),
              role: role,
              allowedRoles: allowedRoles,
              onChanged: dependencies.settings.setDeviceRole,
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

class _DeviceModeDropdown extends StatefulWidget {
  const _DeviceModeDropdown({
    super.key,
    required this.role,
    required this.allowedRoles,
    required this.onChanged,
  });

  final AppDeviceRole role;
  final List<AppDeviceRole> allowedRoles;
  final Future<void> Function(AppDeviceRole role) onChanged;

  @override
  State<_DeviceModeDropdown> createState() => _DeviceModeDropdownState();
}

class _DeviceModeDropdownState extends State<_DeviceModeDropdown> {
  final _fieldKey = GlobalKey<FormFieldState<AppDeviceRole>>();

  @override
  void didUpdateWidget(_DeviceModeDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _fieldKey.currentState?.didChange(widget.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AppDeviceRole>(
      key: _fieldKey,
      initialValue: widget.role,
      decoration: const InputDecoration(labelText: 'Mode'),
      items: widget.allowedRoles
          .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
          .toList(),
      onChanged: (newRole) async {
        if (newRole == null) return;
        try {
          await widget.onChanged(newRole);
        } on Object catch (error) {
          _fieldKey.currentState?.didChange(widget.role);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Device role update failed: $error')),
          );
        }
      },
    );
  }
}

class _ReminderNotificationCard extends StatefulWidget {
  const _ReminderNotificationCard();

  @override
  State<_ReminderNotificationCard> createState() =>
      _ReminderNotificationCardState();
}

class _RobotFaceSettingsCard extends StatefulWidget {
  const _RobotFaceSettingsCard();

  @override
  State<_RobotFaceSettingsCard> createState() => _RobotFaceSettingsCardState();
}

class _RobotFaceSettingsSection extends StatelessWidget {
  const _RobotFaceSettingsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppDeviceRole>(
      stream: DoseyAppScope.of(context).settings.watchDeviceRole(),
      builder: (context, roleSnapshot) {
        final platform = currentAppDevicePlatform();
        final fallbackRole = AppDeviceRole.defaultFor(platform);
        final storedRole = roleSnapshot.data;
        final role = storedRole != null && storedRole.isAllowedOn(platform)
            ? storedRole
            : fallbackRole;

        if (!role.canHostRobot) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            const SizedBox(height: 12),
            const _RobotFaceSettingsCard(),
          ],
        );
      },
    );
  }
}

class _RobotFaceSettingsCardState extends State<_RobotFaceSettingsCard> {
  static const List<int> _timingOptions = [0, 5, 10, 15, 30, 60];
  static const int _defaultWakeBeforeDoseMinutes =
      RobotFaceSettings.defaultWakeBeforeDoseMinutes;
  static const int _defaultStayAwakeAfterDoseMinutes =
      RobotFaceSettings.defaultStayAwakeAfterDoseMinutes;

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.settings.watchDeviceRole(),
      builder: (context, roleSnapshot) {
        final platform = currentAppDevicePlatform();
        final fallbackRole = AppDeviceRole.defaultFor(platform);
        final storedRole = roleSnapshot.data;
        final role = storedRole != null && storedRole.isAllowedOn(platform)
            ? storedRole
            : fallbackRole;
        if (!role.canHostRobot) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<RobotFaceSettings>(
          stream: dependencies.robotFaceSettings.watchSettings(),
          builder: (context, settingsSnapshot) {
            final settings = settingsSnapshot.data ?? const RobotFaceSettings();

            return _SettingsSectionCard(
              icon: Icons.face_retouching_natural_outlined,
              title: 'Robot Face',
              children: [
                const Text(
                  'Keep the face horizontal and match your phone mount.',
                ),
                const SizedBox(height: 12),
                _SettingsSwitchTile(
                  value: settings.isFlipped,
                  enabled: !_isSaving,
                  title: 'Flip face 180°',
                  subtitle: 'Use this if the phone is mounted upside down.',
                  onChanged: (value) =>
                      _saveSettings(settings.copyWith(isFlipped: value)),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.dimAfterInactivity,
                  enabled: !_isSaving,
                  title: 'Dim after inactivity',
                  subtitle: 'Lets the screen dim or sleep when idle.',
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(dimAfterInactivity: value),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RobotFaceTimingDropdown(
                        label: 'Wake before dose',
                        value: settings.wakeBeforeDoseMinutes,
                        fallbackValue: _defaultWakeBeforeDoseMinutes,
                        enabled: !_isSaving,
                        options: _timingOptions,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(wakeBeforeDoseMinutes: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RobotFaceTimingDropdown(
                        label: 'Stay awake after dose',
                        value: settings.stayAwakeAfterDoseMinutes,
                        fallbackValue: _defaultStayAwakeAfterDoseMinutes,
                        enabled: !_isSaving,
                        options: _timingOptions,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(stayAwakeAfterDoseMinutes: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSettings(RobotFaceSettings settings) async {
    setState(() => _isSaving = true);
    try {
      await DoseyAppScope.of(context).robotFaceSettings.saveSettings(settings);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Robot Face settings failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _RobotFaceTimingDropdown extends StatelessWidget {
  const _RobotFaceTimingDropdown({
    required this.label,
    required this.value,
    required this.fallbackValue,
    required this.enabled,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int fallbackValue;
  final bool enabled;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = options.contains(value) ? value : fallbackValue;
    final theme = Theme.of(context);
    final decoration = InputDecoration(
      labelText: label,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );

    return InputDecorator(
      key: ValueKey('$label:$selectedValue'),
      decoration: decoration,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedValue,
          isExpanded: true,
          items: options
              .map(
                (minutes) => DropdownMenuItem<int>(
                  value: minutes,
                  child: Text(_robotFaceTimingLabel(minutes)),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (newValue) {
                  if (newValue != null) {
                    onChanged(newValue);
                  }
                }
              : null,
        ),
      ),
    );
  }
}

String _robotFaceTimingLabel(int minutes) {
  if (minutes == 0) {
    return 'Off';
  }

  if (minutes == 1) {
    return '1 minute';
  }

  return '$minutes minutes';
}

class _ReminderNotificationCardState extends State<_ReminderNotificationCard>
    with WidgetsBindingObserver {
  AppPermissionState _status = AppPermissionState.unknown;
  bool _isChecking = true;
  bool _hasCheckedPermission = false;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedPermission && TickerMode.valuesOf(context).enabled) {
      _hasCheckedPermission = true;
      _checkPermission();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (TickerMode.valuesOf(context).enabled) {
      _hasCheckedPermission = true;
      _checkPermission();
      return;
    }
    _hasCheckedPermission = false;
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      icon: Icons.notifications_active_outlined,
      title: 'Reminder notifications',
      children: [
        Text(_statusLabel),
        const SizedBox(height: 8),
        const Text(
          'Dose reminders are scheduled locally on this phone. If notifications are blocked, Dosey can still show schedules in the app but system alerts may not appear.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isChecking ? null : _requestPermission,
              icon: const Icon(Icons.notifications_none_outlined),
              label: Text(_isChecking ? 'Checking...' : 'Check permissions'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isSendingTest ? null : _sendTestNotification,
              icon: const Icon(Icons.notification_add_outlined),
              label: Text(
                _isSendingTest ? 'Scheduling...' : 'Send test notification',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String get _statusLabel {
    return switch (_status) {
      AppPermissionState.granted => 'Notifications allowed',
      AppPermissionState.denied => 'Notifications blocked',
      AppPermissionState.unknown => 'Notification status unknown',
    };
  }

  Future<void> _checkPermission() async {
    try {
      final permissions = DoseyAppScope.of(context).permissions;
      final status = await permissions.check(AppPermission.notifications);
      if (!mounted) return;
      setState(() {
        _status = status;
        _isChecking = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = AppPermissionState.unknown;
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification permission check failed: $error')),
      );
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isChecking = true);
    final permissions = DoseyAppScope.of(context).permissions;
    try {
      final status = await permissions.request(AppPermission.notifications);
      if (!mounted) return;
      setState(() {
        _status = status;
        _isChecking = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification permission check failed: $error')),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isSendingTest = true);
    try {
      final status = await DoseyAppScope.of(
        context,
      ).permissions.request(AppPermission.notifications);
      if (!mounted) return;
      setState(() => _status = status);
      if (status != AppPermissionState.granted) {
        setState(() => _isSendingTest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications are still blocked. Allow notifications before using the test alert.',
            ),
          ),
        );
        return;
      }
      final result = await DoseyAppScope.of(
        context,
      ).reminderSchedules.sendTestNotification();
      if (!mounted) return;
      setState(() => _isSendingTest = false);
      if (result.hasNotificationWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test notification failed: ${result.notificationError}',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification scheduled.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _isSendingTest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test notification failed: $error')),
      );
    }
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

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.value,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: Text(title),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
