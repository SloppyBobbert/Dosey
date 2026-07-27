import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/backup/local_backup_service.dart';
import 'package:dosey_app/core/backup/local_backup_store.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/household_account_state.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/demo/demo_mode_host.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:dosey_app/core/settings/app_theme_preference.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/voice/fixed_phrase_catalog.dart';
import 'package:dosey_app/core/voice/voice_player.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:dosey_app/features/settings/settings_accordion.dart';
import 'package:dosey_app/features/settings/robot_phone_setup_screen.dart';
import 'package:dosey_app/features/shared/protected_admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'settings_backup_card.dart';

enum SettingsSection {
  account,
  deviceMode,
  actionPin,
  householdAccount,
  adminHistory,
  backupDatabase,
  robotFace,
  notifications,
  safety,
  helpAbout,
  guidedTrial,
  setup,
}

enum _SettingsGroup {
  profile,
  household,
  history,
  actionPin,
  notifications,
  appearance,
  robotFace,
  help,
  safety,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.sectionTarget,
    this.previewVoicePlayer,
  });

  final SettingsSection? sectionTarget;
  final DoseyVoicePlayer? previewVoicePlayer;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<SettingsSection, GlobalKey> _sectionKeys = {
    for (final section in SettingsSection.values) section: GlobalKey(),
  };

  late final ScrollController _scrollController;
  late final DoseyVoicePlayer _previewVoicePlayer;
  late Future<GuidedTrialCompletion?> _guidedTrialCompletion;
  LocalAppSettingsRepository? _guidedTrialSettings;
  bool? _guidedTrialWasDemo;
  bool _showsRobotFaceGroup = false;
  bool _isSigningIn = false;
  String? _authMessage;
  final Set<_SettingsGroup> _expandedGroups = {
    _SettingsGroup.profile,
    _SettingsGroup.notifications,
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _previewVoicePlayer =
        widget.previewVoicePlayer ??
        DoseyVoicePlayer(playbackGateway: JustAudioVoicePlaybackGateway());
    final target = widget.sectionTarget;
    if (target != null) _expandedGroups.add(_groupFor(target));
    _scrollToTargetAfterBuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = DoseyAppScope.of(context);
    final settings =
        DemoModeHost.maybeOf(context)?.productionSettings ??
        dependencies.settings;
    if (!identical(_guidedTrialSettings, settings) ||
        _guidedTrialWasDemo != dependencies.isDemo) {
      _guidedTrialSettings = settings;
      _guidedTrialWasDemo = dependencies.isDemo;
      _guidedTrialCompletion = settings.getGuidedTrialCompletion();
    }
  }

  @override
  void dispose() {
    if (widget.previewVoicePlayer == null) {
      _previewVoicePlayer.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionTarget != widget.sectionTarget) {
      final target = widget.sectionTarget;
      if (target != null) {
        setState(() => _expandedGroups.add(_groupFor(target)));
      }
      _scrollToTargetAfterBuild();
    }
  }

  void _scrollToTargetAfterBuild() {
    final target = widget.sectionTarget;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _sectionKeys[target]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: Duration.zero,
          alignment: 0.25,
        );
      } else if (_scrollController.hasClients) {
        // Some sections may not have built yet; use stable estimates so deep
        // links still land near the requested card.
        final position = _scrollController.position;
        final offset = _estimatedSectionOffset(
          target,
        ).clamp(position.minScrollExtent, position.maxScrollExtent);
        _scrollController.jumpTo(offset);
      }
    });
  }

  double _estimatedSectionOffset(SettingsSection section) {
    const listHeaderExtent = 52.0;
    const collapsedAccordionExtent = 84.0;
    final visibleGroups = _SettingsGroup.values
        .where(
          (group) => group != _SettingsGroup.robotFace || _showsRobotFaceGroup,
        )
        .toList();
    final groupIndex = visibleGroups.indexOf(_groupFor(section));
    return listHeaderExtent + groupIndex * collapsedAccordionExtent;
  }

  _SettingsGroup _groupFor(SettingsSection section) {
    return switch (section) {
      SettingsSection.account ||
      SettingsSection.deviceMode => _SettingsGroup.profile,
      SettingsSection.householdAccount => _SettingsGroup.household,
      SettingsSection.adminHistory ||
      SettingsSection.backupDatabase => _SettingsGroup.history,
      SettingsSection.actionPin => _SettingsGroup.actionPin,
      SettingsSection.notifications => _SettingsGroup.notifications,
      SettingsSection.robotFace => _SettingsGroup.robotFace,
      SettingsSection.helpAbout ||
      SettingsSection.guidedTrial ||
      SettingsSection.setup => _SettingsGroup.help,
      SettingsSection.safety => _SettingsGroup.safety,
    };
  }

  Widget _accordion({
    required _SettingsGroup group,
    required String title,
    required Widget child,
  }) {
    return SettingsAccordion(
      title: title,
      expanded: _expandedGroups.contains(group),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedGroups.add(group);
          } else {
            _expandedGroups.remove(group);
          }
        });
      },
      child: child,
    );
  }

  Widget _targeted(SettingsSection section, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(key: _sectionKeys[section]),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final platform = currentAppDevicePlatform();
    final usesAppleSignIn = platform == AppDevicePlatform.ios;
    final providerName = usesAppleSignIn ? 'Apple' : 'Google';

    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.effectiveRole.watchDeviceRole(),
      builder: (context, roleSnapshot) {
        final allowedRoles = AppDeviceRole.allowedFor(platform);
        final storedRole = roleSnapshot.data;
        final role = storedRole != null && allowedRoles.contains(storedRole)
            ? storedRole
            : AppDeviceRole.defaultFor(platform);
        _showsRobotFaceGroup = role.canHostRobot;

        return StreamBuilder<AuthSession>(
          stream: dependencies.auth.watchSession(),
          builder: (context, authSnapshot) {
            final session = authSnapshot.data ?? const AuthSession.signedOut();

            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.profile,
                  title: 'Profile, account & device',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileSummaryCard(session: session, platform: platform),
                      if (!role.canHostRobot) ...[
                        const SizedBox(height: 12),
                        _targeted(
                          SettingsSection.account,
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
                                  icon: Icon(
                                    usesAppleSignIn ? Icons.apple : Icons.login,
                                  ),
                                  label: Text(
                                    _isSigningIn
                                        ? 'Signing in...'
                                        : 'Sign in with $providerName',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _targeted(
                        SettingsSection.deviceMode,
                        _DeviceModeCard(platform: platform),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.household,
                  title: 'Household & robot profile',
                  child: _targeted(
                    SettingsSection.householdAccount,
                    _HouseholdAccountCard(platform: platform),
                  ),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.history,
                  title: 'History & data',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DoseHistoryCard(),
                      const SizedBox(height: 12),
                      _targeted(
                        SettingsSection.adminHistory,
                        _AdminHistoryCard(),
                      ),
                      const SizedBox(height: 12),
                      _targeted(
                        SettingsSection.backupDatabase,
                        _BackupDatabaseCard(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.actionPin,
                  title: 'Action PIN',
                  child: _targeted(SettingsSection.actionPin, _ActionPinCard()),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.notifications,
                  title: 'Reminder notifications',
                  child: _targeted(
                    SettingsSection.notifications,
                    _ReminderNotificationCard(),
                  ),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.appearance,
                  title: 'Appearance',
                  child: const _AppearanceCard(),
                ),
                if (role.canHostRobot) ...[
                  const SizedBox(height: 12),
                  _accordion(
                    group: _SettingsGroup.robotFace,
                    title: 'Robot Face options',
                    child: _targeted(
                      SettingsSection.robotFace,
                      _RobotFaceSettingsCard(
                        previewVoicePlayer: _previewVoicePlayer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.help,
                  title: 'Help, guided trial & setup',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _targeted(SettingsSection.helpAbout, _HelpAboutCard()),
                      const SizedBox(height: 12),
                      _targeted(
                        SettingsSection.guidedTrial,
                        _GuidedTrialSettingsCard(
                          completion: _guidedTrialCompletion,
                          onStart: DemoModeHost.maybeOf(
                            context,
                          )?.startGuidedTrial,
                          isActive: dependencies.isDemo,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _targeted(
                        SettingsSection.setup,
                        _SettingsSectionCard(
                          icon: Icons.restart_alt,
                          title: 'Setup',
                          children: [
                            const Text(
                              'Show the first-run safety notice and setup steps again.',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _resetSetup,
                              icon: const Icon(Icons.replay_outlined),
                              label: const Text('Start over setup'),
                            ),
                          ],
                        ),
                      ),
                      if (dependencies
                          .effectiveRole
                          .capabilities
                          .showsRobotPhoneSetup) ...[
                        const SizedBox(height: 12),
                        _RobotPhoneSetupCard(
                          onOpen: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => RobotPhoneSetupScreen(
                                gateway: dependencies.robotPhoneSetup,
                                externalActionResumeGuard:
                                    dependencies.externalActionResumeGuard,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _accordion(
                  group: _SettingsGroup.safety,
                  title: 'Safety & limitations',
                  child: _targeted(SettingsSection.safety, _SafetyCard()),
                ),
              ],
            );
          },
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

class _GuidedTrialSettingsCard extends StatelessWidget {
  const _GuidedTrialSettingsCard({
    required this.completion,
    required this.onStart,
    required this.isActive,
  });

  final Future<GuidedTrialCompletion?> completion;
  final Future<void> Function()? onStart;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      icon: Icons.fact_check_outlined,
      title: 'Guided Trial Run',
      children: [
        const Text(
          'Practice reminders, simulated dispensing, dose confirmation, missed-dose handling, and reconnect recovery. Real medication data is not changed.',
        ),
        const SizedBox(height: 8),
        FutureBuilder<GuidedTrialCompletion?>(
          future: completion,
          builder: (context, snapshot) {
            final value = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Checking trial status...'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start guided trial'),
                  ),
                ],
              );
            }
            final status = value == null
                ? 'Not completed yet'
                : 'Last completed ${value.completedAt.toUtc().toIso8601String().split('T').first} UTC with app ${value.appVersion}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: isActive ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    isActive
                        ? 'Trial in progress'
                        : value == null
                        ? 'Start guided trial'
                        : 'Run guided trial again',
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
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
    final capabilities = dependencies.effectiveRole.capabilities;
    final isRobot = capabilities.canHostRobot;
    return _SettingsSectionCard(
      icon: Icons.phone_android_outlined,
      title: 'Device mode',
      children: [
        Text(
          isRobot ? 'Robot distribution' : 'Personal distribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Text(
          isRobot
              ? 'This app is fixed as the mounted Android robot phone and can control Dosey hardware.'
              : 'This app is fixed for personal reminders, history, and management features.',
        ),
        if (platform == AppDevicePlatform.ios) ...[
          const SizedBox(height: 8),
          const Text('iOS always uses the Personal distribution.'),
        ],
        const SizedBox(height: 8),
        const Text('Install the other Dosey app to change this phone’s role.'),
      ],
    );
  }
}

class _RobotPhoneSetupCard extends StatelessWidget {
  const _RobotPhoneSetupCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      icon: Icons.phonelink_setup_outlined,
      title: 'Robot phone setup',
      children: [
        const Text(
          'Review Bluetooth, Wi-Fi, notifications, battery optimization, and secure lock status.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open robot phone setup'),
        ),
      ],
    );
  }
}

class _ActionPinCard extends StatelessWidget {
  const _ActionPinCard();

  @override
  Widget build(BuildContext context) {
    final settings = DoseyAppScope.of(context).settings;

    return StreamBuilder<bool>(
      stream: settings.watchActionPinEnabled(),
      builder: (context, snapshot) {
        final pinEnabled = snapshot.data ?? false;

        return _SettingsSectionCard(
          icon: Icons.pin_outlined,
          title: 'Action PIN',
          children: [
            Text(pinEnabled ? 'PIN is on' : 'PIN is off'),
            const SizedBox(height: 8),
            const Text(
              'Require a local PIN before protected meds, schedules, carousel changes, dose actions, and other local admin changes.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      pinEnabled ? _changePin(context) : _enablePin(context),
                  icon: Icon(
                    pinEnabled ? Icons.edit_outlined : Icons.lock_outline,
                  ),
                  label: Text(pinEnabled ? 'Change PIN' : 'Enable PIN'),
                ),
                if (pinEnabled)
                  OutlinedButton.icon(
                    onPressed: () => _disablePin(context),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Disable PIN'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _enablePin(BuildContext context) async {
    final newPin = await showActionPinSetupDialog(context);
    if (newPin == null || !context.mounted) return;
    await _savePin(context, newPin);
  }

  Future<void> _changePin(BuildContext context) async {
    final currentPin = await _requestVerifiedCurrentPin(context);
    if (currentPin == null || !context.mounted) return;
    final newPin = await showActionPinSetupDialog(context, title: 'Change PIN');
    if (newPin == null || !context.mounted) return;
    await _savePin(context, newPin);
  }

  Future<void> _disablePin(BuildContext context) async {
    final dependencies = DoseyAppScope.of(context);
    final currentPin = await _requestVerifiedCurrentPin(context);
    if (currentPin == null || !context.mounted) return;
    final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
    if (!context.mounted) return;
    final actor = await ProtectedAdminActionRunner(
      pinGate: dependencies.actionPinGate,
      localAuth: dependencies.localAuth,
    ).resolveActor();
    await dependencies.settings.clearActionPin(
      auditEvent: const AdminAuditEventFactory().pinDisabled(
        actor: actor,
        sourceDeviceRole: sourceDeviceRole,
        summary: 'Disabled the local action PIN.',
      ),
    );
  }

  Future<String?> _requestVerifiedCurrentPin(BuildContext context) async {
    final settings = DoseyAppScope.of(context).settings;
    while (context.mounted) {
      final pin = await showActionPinPromptDialog(context);
      if (pin == null || !context.mounted) return null;
      if (await settings.verifyActionPin(pin)) {
        return pin;
      }
      if (!context.mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
    }
    return null;
  }

  Future<void> _savePin(BuildContext context, String pin) async {
    try {
      final dependencies = DoseyAppScope.of(context);
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!context.mounted) return;
      final actor = await ProtectedAdminActionRunner(
        pinGate: dependencies.actionPinGate,
        localAuth: dependencies.localAuth,
      ).resolveActor();
      final pinEnabled = await dependencies.settings.isActionPinEnabled();
      await dependencies.settings.setActionPin(
        pin,
        auditEvent: pinEnabled
            ? const AdminAuditEventFactory().pinChanged(
                actor: actor,
                sourceDeviceRole: sourceDeviceRole,
                summary: 'Changed the local action PIN.',
              )
            : const AdminAuditEventFactory().pinEnabled(
                actor: actor,
                sourceDeviceRole: sourceDeviceRole,
                summary: 'Enabled the local action PIN.',
              ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action PIN update failed: $error')),
      );
    }
  }
}

class _ReminderNotificationCard extends StatefulWidget {
  const _ReminderNotificationCard();

  @override
  State<_ReminderNotificationCard> createState() =>
      _ReminderNotificationCardState();
}

class _HouseholdAccountCard extends StatefulWidget {
  const _HouseholdAccountCard({required this.platform});

  final AppDevicePlatform platform;

  @override
  State<_HouseholdAccountCard> createState() => _HouseholdAccountCardState();
}

class _HouseholdAccountCardState extends State<_HouseholdAccountCard> {
  RobotPairingCredential? _pairingCredential;
  HouseholdInvitationCredential? _householdInvitation;
  bool _pairingBusy = false;
  bool _householdBusy = false;
  DoseyAppDependencies? _householdDependencies;
  StreamSubscription<RobotInstallation?>? _robotSubscription;
  RobotInstallation? _visibleRobot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = DoseyAppScope.of(context);
    if (identical(_householdDependencies, dependencies)) return;
    unawaited(_robotSubscription?.cancel());
    _householdDependencies?.householdMembership.removeListener(
      _handlePublishedMembership,
    );
    _householdDependencies = dependencies;
    dependencies.householdMembership.addListener(_handlePublishedMembership);
    _robotSubscription = dependencies.householdSync.watchRobot().listen((
      robot,
    ) {
      if (mounted) setState(() => _visibleRobot = robot);
    });
  }

  @override
  void dispose() {
    unawaited(_robotSubscription?.cancel());
    _householdDependencies?.householdMembership.removeListener(
      _handlePublishedMembership,
    );
    super.dispose();
  }

  void _handlePublishedMembership() {
    if (!mounted) return;
    setState(() {
      _visibleRobot = _householdDependencies?.householdMembership.robot;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.effectiveRole.watchDeviceRole(),
      builder: (context, roleSnapshot) {
        final allowedRoles = AppDeviceRole.allowedFor(widget.platform);
        final fallbackRole = AppDeviceRole.defaultFor(widget.platform);
        final storedRole = roleSnapshot.data;
        final role = storedRole != null && allowedRoles.contains(storedRole)
            ? storedRole
            : fallbackRole;

        final robot = _visibleRobot;
        return StreamBuilder<CloudIdentity>(
          stream: dependencies.cloudIdentity.watchIdentity(),
          builder: (context, identitySnapshot) {
            final identity = identitySnapshot.data;
            return StreamBuilder<HouseholdAccountState>(
              stream: dependencies.household.watchState(),
              builder: (context, snapshot) {
                final state = snapshot.data ?? const HouseholdAccountState();
                return _SettingsSectionCard(
                  icon: Icons.home_outlined,
                  title: 'Household & robot profile',
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text('Profile & device'),
                      children: [
                        _HouseholdMetadataRow(
                          label: 'Household',
                          value: state.householdDisplayName,
                        ),
                        _HouseholdMetadataRow(
                          label: 'Robot',
                          value: state.robotHubDisplayName,
                        ),
                        _HouseholdMetadataRow(
                          label: 'This device',
                          value: _deviceLabel(role),
                        ),
                        _HouseholdMetadataRow(
                          label: 'Person',
                          value: state.profileDisplayName ?? 'Not set',
                        ),
                        _HouseholdMetadataRow(
                          label: 'Relationship',
                          value: state.relationshipLabel ?? 'Not set',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showHouseholdEditSheet(context, state),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit household & robot profile'),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: const Text('Robot linking'),
                      children: [
                        _HouseholdMetadataRow(
                          label: 'Cloud sync',
                          value: robot == null ? 'Not linked' : 'Linked',
                        ),
                        if (robot != null) ...[
                          _HouseholdMetadataRow(
                            label: 'Cloud robot',
                            value: robot.displayName,
                          ),
                          _HouseholdMetadataRow(
                            label: 'People',
                            value:
                                '${robot.humanAccountCount} of ${RobotInstallation.maxHumanAccounts}',
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          robot == null
                              ? 'Local profile data remains available. Link this device to enable cloud robot membership.'
                              : 'This device is linked to the robot household. Local medication data remains on this device.',
                        ),
                        if (robot != null && !role.canHostRobot) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Household members',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final member in robot.members)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${member.label} (${member.role == HouseholdRole.owner ? 'Owner' : 'Member'})',
                                  ),
                                ),
                                if (robot.currentRole == HouseholdRole.owner &&
                                    member.role != HouseholdRole.owner)
                                  TextButton(
                                    onPressed:
                                        _householdBusy ||
                                            !dependencies
                                                .householdManagement
                                                .isAvailable ||
                                            identity?.accountId == null
                                        ? null
                                        : () => _confirmRemoveMember(
                                            robot,
                                            member,
                                            identity?.accountId,
                                          ),
                                    child: Text('Remove ${member.label}'),
                                  ),
                              ],
                            ),
                          if (!dependencies
                              .householdManagement
                              .isAvailable) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Cloud household management is not configured.',
                            ),
                          ] else if (robot.currentRole ==
                              HouseholdRole.owner) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  _householdBusy || identity?.accountId == null
                                  ? null
                                  : () => _showInvitationDialog(robot),
                              icon: const Icon(Icons.person_add_outlined),
                              label: const Text('Generate member invitation'),
                            ),
                            if (_householdInvitation
                                case final invitation?) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                'Invitation code: ${invitation.code}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Code expires ${_formatExpiry(context, invitation.expiresAt)}.',
                              ),
                            ],
                          ] else ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  _householdBusy || identity?.accountId == null
                                  ? null
                                  : () => _confirmLeaveHousehold(
                                      robot,
                                      identity?.accountId,
                                    ),
                              icon: const Icon(Icons.logout),
                              label: const Text('Leave household'),
                            ),
                          ],
                        ],
                        if (!dependencies.robotPairing.isAvailable) ...[
                          const SizedBox(height: 12),
                          const Text('Robot pairing is not configured.'),
                        ] else if (role.canHostRobot) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _pairingBusy ? null : _showClaimDialog,
                            icon: const Icon(Icons.link),
                            label: const Text('Pair this robot phone'),
                          ),
                        ] else if (robot != null &&
                            identity?.accountId == robot.ownerAccountId) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _pairingBusy
                                ? null
                                : () => _createPairingCode(robot),
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Generate robot pairing code'),
                          ),
                          if (_pairingCredential case final credential?) ...[
                            const SizedBox(height: 12),
                            SelectableText(
                              'Pairing code: ${credential.code}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Code expires ${_formatExpiry(context, credential.expiresAt)}.',
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _createPairingCode(RobotInstallation robot) async {
    setState(() => _pairingBusy = true);
    try {
      final dependencies = DoseyAppScope.of(context);
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!mounted) return;
      final result = await runProtectedAdminAction<RobotPairingCredential>(
        context,
        action: (actor) async {
          final credential = await dependencies.robotPairing.createPairingCode(
            robotId: robot.id,
          );
          await dependencies.adminAudit.addEvent(
            const AdminAuditEventFactory().pairingCodeGenerated(
              actor: actor,
              sourceDeviceRole: sourceDeviceRole,
              targetId: robot.id,
              summary: 'Generated a temporary mounted-device pairing code.',
              details: {
                'expiresAt': credential.expiresAt.toUtc().toIso8601String(),
              },
            ),
          );
          return credential;
        },
      );
      if (!mounted || !result.isSuccess) return;
      setState(() => _pairingCredential = result.value);
    } on RobotPairingException catch (error) {
      if (mounted) {
        _showPairingError(context, error.reason, creatingCode: true);
      }
    } on Object {
      if (mounted) {
        _showPairingError(context, RobotPairingFailureReason.functionFailure);
      }
    } finally {
      if (mounted) setState(() => _pairingBusy = false);
    }
  }

  Future<void> _showInvitationDialog(RobotInstallation robot) async {
    var email = '';
    String? validationMessage;
    final invitedEmail = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite a household member'),
          content: TextField(
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) {
              email = value;
              if (validationMessage != null && value.trim().isNotEmpty) {
                setDialogState(() => validationMessage = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Invited Google account email',
              errorText: validationMessage,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = email.trim().toLowerCase();
                if (normalized.isEmpty || !normalized.contains('@')) {
                  setDialogState(
                    () => validationMessage = 'Enter a valid email address.',
                  );
                  return;
                }
                Navigator.pop(context, normalized);
              },
              child: const Text('Generate invitation'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || invitedEmail == null) return;
    await _createHouseholdInvitation(robot, invitedEmail);
  }

  Future<void> _createHouseholdInvitation(
    RobotInstallation robot,
    String invitedEmail,
  ) async {
    setState(() => _householdBusy = true);
    try {
      final dependencies = DoseyAppScope.of(context);
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!mounted) return;
      final result = await runProtectedAdminAction<HouseholdInvitationCredential>(
        context,
        action: (actor) async {
          final credential = await dependencies.householdManagement
              .createInvitation(robot.id, invitedEmail);
          try {
            await dependencies.adminAudit.addEvent(
              const AdminAuditEventFactory().householdInvitationGenerated(
                actor: actor,
                sourceDeviceRole: sourceDeviceRole,
                targetId: robot.id,
                summary: 'Generated an email-bound household invitation.',
                invitedEmail: invitedEmail,
                expiresAt: credential.expiresAt,
              ),
            );
          } on Object {
            // The one-time server credential cannot be recreated for audit repair.
          }
          return credential;
        },
      );
      if (!mounted || !result.isSuccess) return;
      setState(() => _householdInvitation = result.value);
    } on HouseholdManagementException catch (error) {
      if (mounted) _showHouseholdManagementError(error.reason);
    } on Object {
      if (mounted) {
        _showHouseholdManagementError(
          HouseholdManagementFailureReason.functionFailure,
        );
      }
    } finally {
      if (mounted) setState(() => _householdBusy = false);
    }
  }

  Future<void> _confirmRemoveMember(
    RobotInstallation robot,
    HouseholdMember member,
    String? accountId,
  ) async {
    if (accountId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove household member?'),
        content: Text('${member.label} will lose access to this household.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove member'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _removeMember(robot, member, accountId);
  }

  Future<void> _removeMember(
    RobotInstallation robot,
    HouseholdMember member,
    String accountId,
  ) async {
    setState(() => _householdBusy = true);
    try {
      final dependencies = DoseyAppScope.of(context);
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!mounted) return;
      final result = await runProtectedAdminAction<RobotInstallation>(
        context,
        action: (actor) => dependencies.householdManagement.removeMember(
          robot.id,
          member.accountId,
        ),
      );
      if (!mounted || !result.isSuccess) return;
      final updated = result.value!;
      dependencies.householdMembership.update(updated);
      try {
        await dependencies.householdCache.replaceForAccount(
          accountId,
          updated,
          confirmedAt: dependencies.appClock.now().toUtc(),
        );
      } on Object {
        // The server result remains authoritative if local cache repair fails.
      }
      try {
        await dependencies.adminAudit.addEvent(
          const AdminAuditEventFactory().householdMemberRemoved(
            actor: result.actor!,
            sourceDeviceRole: sourceDeviceRole,
            targetId: robot.id,
            summary: 'Removed a member from the household.',
            removedAccountId: member.accountId,
            removedLabel: member.label,
          ),
        );
      } on Object {
        // The completed server removal cannot be undone for local audit failure.
      }
    } on HouseholdManagementException catch (error) {
      if (mounted) _showHouseholdManagementError(error.reason);
    } on Object {
      if (mounted) {
        _showHouseholdManagementError(
          HouseholdManagementFailureReason.functionFailure,
        );
      }
    } finally {
      if (mounted) setState(() => _householdBusy = false);
    }
  }

  Future<void> _confirmLeaveHousehold(
    RobotInstallation robot,
    String? accountId,
  ) async {
    if (accountId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this household?'),
        content: const Text(
          'This account will lose access to the robot household.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _leaveHousehold(robot, accountId);
  }

  Future<void> _leaveHousehold(
    RobotInstallation robot,
    String accountId,
  ) async {
    setState(() => _householdBusy = true);
    try {
      final dependencies = DoseyAppScope.of(context);
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) =>
            dependencies.householdManagement.leaveRobot(robot.id),
      );
      if (!mounted || !result.isSuccess) return;
      dependencies.householdMembership.update(null);
      try {
        await dependencies.householdCache.clearForAccount(accountId);
      } on Object {
        // The server result remains authoritative if local cache cleanup fails.
      }
      try {
        await dependencies.adminAudit.addEvent(
          const AdminAuditEventFactory().householdLeft(
            actor: result.actor!,
            sourceDeviceRole: sourceDeviceRole,
            targetId: robot.id,
            summary: 'Left the household.',
          ),
        );
      } on Object {
        // The completed server leave cannot be undone for local audit failure.
      }
    } on HouseholdManagementException catch (error) {
      if (mounted) _showHouseholdManagementError(error.reason);
    } on Object {
      if (mounted) {
        _showHouseholdManagementError(
          HouseholdManagementFailureReason.functionFailure,
        );
      }
    } finally {
      if (mounted) setState(() => _householdBusy = false);
    }
  }

  void _showHouseholdManagementError(HouseholdManagementFailureReason reason) {
    final message = switch (reason) {
      HouseholdManagementFailureReason.householdFull =>
        'This household already has seven people.',
      HouseholdManagementFailureReason.ownerCannotLeave =>
        'The household owner cannot leave.',
      HouseholdManagementFailureReason.ownerRequired =>
        'Only the household owner can do that.',
      HouseholdManagementFailureReason.memberNotFound =>
        'That household member no longer exists.',
      HouseholdManagementFailureReason.authenticationRequired =>
        'Sign in with your verified Google account and retry.',
      _ => 'Household management is temporarily unavailable.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showClaimDialog() async {
    var enteredCode = '';
    String? validationMessage;
    final code = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pair this robot phone'),
          content: TextField(
            onChanged: (value) {
              enteredCode = value;
              if (validationMessage != null && value.trim().isNotEmpty) {
                setDialogState(() => validationMessage = null);
              }
            },
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: '10-character pairing code',
              errorText: validationMessage,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = enteredCode.trim();
                if (normalized.isEmpty) {
                  setDialogState(
                    () => validationMessage = 'Enter a pairing code.',
                  );
                  return;
                }
                Navigator.pop(context, normalized);
              },
              child: const Text('Pair robot'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || code == null) return;
    setState(() => _pairingBusy = true);
    try {
      final claimedRobotId = await DoseyAppScope.of(
        context,
      ).robotPairing.claimRobot(code: code);
      if (!mounted) return;
      var refreshedClaim = false;
      try {
        final robot = await DoseyAppScope.of(
          context,
        ).householdSync.refreshRobot();
        refreshedClaim = robot?.id == claimedRobotId;
      } on Object {
        // The server-side claim succeeded; a display refresh cannot undo it.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refreshedClaim
                ? 'Robot phone paired.'
                : 'Robot phone paired, but linked status could not refresh.',
          ),
        ),
      );
    } on RobotPairingException catch (error) {
      if (mounted) _showPairingError(context, error.reason);
    } on Object {
      if (mounted) {
        _showPairingError(context, RobotPairingFailureReason.functionFailure);
      }
    } finally {
      if (mounted) setState(() => _pairingBusy = false);
    }
  }

  String _formatExpiry(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final formatted = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return 'at $formatted';
  }

  void _showPairingError(
    BuildContext context,
    RobotPairingFailureReason reason, {
    bool creatingCode = false,
  }) {
    final message = switch (reason) {
      RobotPairingFailureReason.invalidCode => 'That pairing code is invalid.',
      RobotPairingFailureReason.missingSession =>
        creatingCode
            ? 'Sign in again to generate a pairing code.'
            : 'Could not create the restricted robot session.',
      RobotPairingFailureReason.consumedCode =>
        'That pairing code has already been used.',
      RobotPairingFailureReason.expiredCode => 'That pairing code has expired.',
      RobotPairingFailureReason.blockedDevice =>
        'Too many attempts. Wait 15 minutes and try again.',
      RobotPairingFailureReason.functionFailure =>
        'Robot pairing is temporarily unavailable.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deviceLabel(AppDeviceRole role) {
    return switch (role) {
      AppDeviceRole.androidRobot =>
        'Android Robot Mode mounted robot phone / robot hub. This device can host the face and control the XIAO controller.',
      AppDeviceRole.androidPersonal =>
        'Android personal phone. This device does not control the XIAO controller.',
      AppDeviceRole.iosPersonal =>
        'iOS personal phone. This device does not control the XIAO controller.',
    };
  }

  Future<void> _showHouseholdEditSheet(
    BuildContext context,
    HouseholdAccountState state,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _HouseholdNamesSheet(state: state),
    );
  }
}

class _HouseholdNamesSheet extends StatefulWidget {
  const _HouseholdNamesSheet({required this.state});

  final HouseholdAccountState state;

  @override
  State<_HouseholdNamesSheet> createState() => _HouseholdNamesSheetState();
}

class _HouseholdNamesSheetState extends State<_HouseholdNamesSheet> {
  static const List<String> _relationshipOptions = <String>[
    'Self',
    'Parent',
    'Grandparent',
    'Child',
    'Caregiver',
    'Other',
  ];

  late final TextEditingController _householdController;
  late final TextEditingController _hubController;
  late final TextEditingController _profileController;
  late final TextEditingController _relationshipController;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _householdController = TextEditingController(
      text: widget.state.householdDisplayName,
    );
    _hubController = TextEditingController(
      text: widget.state.robotHubDisplayName,
    );
    _profileController = TextEditingController(
      text: widget.state.profileDisplayName ?? '',
    );
    _relationshipController = TextEditingController(
      text: widget.state.relationshipLabel ?? '',
    );
  }

  @override
  void dispose() {
    _householdController.dispose();
    _hubController.dispose();
    _profileController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit household & robot profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Local-only metadata for this device. Saving stays behind the protected admin flow.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _householdController,
            decoration: const InputDecoration(
              labelText: 'Household name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hubController,
            decoration: const InputDecoration(
              labelText: 'Robot name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _profileController,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(
              labelText: 'Person/profile name',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue:
                _relationshipOptions.contains(
                  _relationshipController.text.trim(),
                )
                ? _relationshipController.text.trim()
                : null,
            items: _relationshipOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              _relationshipController.text = value ?? '';
            },
            decoration: const InputDecoration(
              labelText: 'Relationship',
              hintText: 'Optional',
              border: OutlineInputBorder(),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final household = DoseyAppScope.of(context).household;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final sourceDeviceRole = await currentAdminSourceDeviceRole(context);
      if (!mounted) return;
      final result = await runProtectedAdminAction<void>(
        context,
        action: (actor) async {
          final currentState = await household.watchState().first;
          final newHouseholdName = _householdController.text.trim();
          final newRobotName = _hubController.text.trim();
          final newProfileName = _normalizeOptionalField(
            _profileController.text,
          );
          final newRelationship = _normalizeOptionalField(
            _relationshipController.text,
          );
          await household.saveLocalNames(
            householdDisplayName: newHouseholdName,
            robotHubDisplayName: newRobotName,
            profileDisplayName: newProfileName,
            relationshipLabel: newRelationship,
            auditEvents: [
              const AdminAuditEventFactory().householdProfileUpdated(
                actor: actor,
                sourceDeviceRole: sourceDeviceRole,
                summary: 'Updated local household and robot profile metadata.',
                details: {
                  'householdDisplayName': {
                    'old': currentState.householdDisplayName,
                    'new': newHouseholdName,
                  },
                  'robotHubDisplayName': {
                    'old': currentState.robotHubDisplayName,
                    'new': newRobotName,
                  },
                  'profileDisplayName': {
                    'old': currentState.profileDisplayName,
                    'new': newProfileName,
                  },
                  'relationshipLabel': {
                    'old': currentState.relationshipLabel,
                    'new': newRelationship,
                  },
                },
              ),
            ],
          );
        },
      );
      if (!result.isSuccess) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Household update failed: $error';
        _isSaving = false;
      });
    }
  }

  String? _normalizeOptionalField(String value) {
    final normalizedValue = value.trim();
    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}

class _HouseholdMetadataRow extends StatelessWidget {
  const _HouseholdMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DoseHistoryCard extends StatelessWidget {
  const _DoseHistoryCard();

  @override
  Widget build(BuildContext context) {
    return _SettingsSectionCard(
      icon: Icons.medication_outlined,
      title: 'Dose history',
      children: [
        const Text(
          'Review taken, skipped, missed, and controller-related dose events.',
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DoseLogScreen()),
          ),
          icon: const Icon(Icons.history_outlined),
          label: const Text('Open dose history'),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final settings = DoseyAppScope.of(context).settings;
    return StreamBuilder<AppThemePreference>(
      stream: settings.watchThemePreference(),
      builder: (context, snapshot) {
        final preference = snapshot.data ?? AppThemePreference.dark;
        return _SettingsSectionCard(
          icon: Icons.palette_outlined,
          title: 'Theme',
          children: [
            const Text('Choose how Dosey appears on this phone.'),
            const SizedBox(height: 12),
            SegmentedButton<AppThemePreference>(
              segments: const [
                ButtonSegment(
                  value: AppThemePreference.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemePreference.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: AppThemePreference.system,
                  label: Text('System'),
                  icon: Icon(Icons.settings_brightness_outlined),
                ),
              ],
              selected: {preference},
              onSelectionChanged: (selection) async {
                try {
                  await settings.setThemePreference(selection.single);
                } on Object catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Theme update failed: $error')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _AdminHistoryCard extends StatelessWidget {
  const _AdminHistoryCard();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminAuditEvent>>(
      stream: DoseyAppScope.of(context).adminAudit.watchRecentEvents(limit: 8),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <AdminAuditEvent>[];
        return _SettingsSectionCard(
          icon: Icons.history_outlined,
          title: 'Admin history',
          children: [
            if (events.isEmpty)
              const Text('No local admin changes recorded yet.')
            else
              for (final event in events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.summary),
                  subtitle: Text(
                    '${event.actorLabel} · ${event.occurredAt.toLocal()}',
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _RobotFaceSettingsCard extends StatefulWidget {
  const _RobotFaceSettingsCard({required this.previewVoicePlayer});

  final DoseyVoicePlayer previewVoicePlayer;

  @override
  State<_RobotFaceSettingsCard> createState() => _RobotFaceSettingsCardState();
}

class _RobotFaceSettingsCardState extends State<_RobotFaceSettingsCard> {
  static const List<int> _timingOptions = [0, 5, 10, 15, 30, 60];
  static const List<int> _idleChatterCooldownOptions = [0, 5, 10, 15, 30];
  static const List<int> _reminderRepeatCooldownOptions = [0, 2, 5, 10, 15];
  static final List<int> _quietHourOptions = <int>[
    for (var hour = 0; hour < 24; hour++) hour * 60,
  ];
  static const int _defaultWakeBeforeDoseMinutes =
      RobotFaceSettings.defaultWakeBeforeDoseMinutes;
  static const int _defaultStayAwakeAfterDoseMinutes =
      RobotFaceSettings.defaultStayAwakeAfterDoseMinutes;
  static const int _defaultIdleChatterCooldownMinutes =
      RobotFaceSettings.defaultIdleChatterCooldownMinutes;
  static const int _defaultReminderRepeatCooldownMinutes =
      RobotFaceSettings.defaultReminderRepeatCooldownMinutes;
  static const int _defaultReturnToFaceAfterInactivityMinutes =
      RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes;

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);

    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.effectiveRole.watchDeviceRole(),
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
                  'Keep the mounted phone face readable while Dosey is resting or waiting for a dose.',
                ),
                const SizedBox(height: 12),
                _SettingsSwitchTile(
                  value: settings.isFlipped,
                  enabled: !_isSaving,
                  title: 'Flip face 180°',
                  subtitle: 'For upside-down mounts.',
                  onChanged: (value) =>
                      _saveSettings(settings.copyWith(isFlipped: value)),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.dimAfterInactivity,
                  enabled: !_isSaving,
                  title: 'Dim after inactivity',
                  subtitle:
                      'After quiet time, show a darker resting face. Dose alerts still stay bright.',
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(dimAfterInactivity: value),
                  ),
                ),
                const SizedBox(height: 12),
                _RobotFaceTimingDropdown(
                  label: 'Return to Robot Face',
                  helperText:
                      'When Robot Mode is open on another tab, return to the face after this much inactivity.',
                  value: settings.returnToFaceAfterInactivityMinutes,
                  fallbackValue: _defaultReturnToFaceAfterInactivityMinutes,
                  enabled: !_isSaving,
                  options: RobotFaceSettings
                      .returnToFaceAfterInactivityMinuteOptions,
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(
                      returnToFaceAfterInactivityMinutes: value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RobotFaceEnumDropdown<int>(
                  label: 'PIR wake duration',
                  helperText:
                      'Motion or touch keeps Robot Face awake for this long. Android controls when the display turns off afterward.',
                  value: settings.pirWakeDurationSeconds,
                  enabled: !_isSaving,
                  options: RobotFaceSettings.pirWakeDurationSecondOptions,
                  labelBuilder: _pirWakeDurationLabel,
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(pirWakeDurationSeconds: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.voiceEnabled,
                  enabled: !_isSaving,
                  title: 'Robot voice',
                  subtitle:
                      'Play short Robot Face voice prompts in Robot Mode.',
                  onChanged: (value) =>
                      _saveSettings(settings.copyWith(voiceEnabled: value)),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.voiceVarietyEnabled,
                  enabled: !_isSaving,
                  title: 'Voice variety',
                  subtitle:
                      'Use alternate safe phrases when Robot voice is on.',
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(voiceVarietyEnabled: value),
                  ),
                ),
                const SizedBox(height: 12),
                _RobotFaceEnumDropdown<RobotVoiceVolumePreset>(
                  label: 'Voice volume',
                  helperText: 'Choose how loud Robot voice should play.',
                  value: settings.voiceVolumePreset,
                  enabled: !_isSaving,
                  options: RobotVoiceVolumePreset.values,
                  labelBuilder: _robotVoiceVolumePresetLabel,
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(voiceVolumePreset: value),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RobotFaceTimingDropdown(
                        label: 'Idle chatter cooldown',
                        helperText:
                            'Wait this long before optional idle chatter can repeat.',
                        value: settings.idleChatterCooldownMinutes,
                        fallbackValue: _defaultIdleChatterCooldownMinutes,
                        enabled: !_isSaving,
                        options: _idleChatterCooldownOptions,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(idleChatterCooldownMinutes: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RobotFaceTimingDropdown(
                        label: 'Reminder repeat cooldown',
                        helperText:
                            'Wait this long before allowed reminder repeats can speak again.',
                        value: settings.reminderRepeatCooldownMinutes,
                        fallbackValue: _defaultReminderRepeatCooldownMinutes,
                        enabled: !_isSaving,
                        options: _reminderRepeatCooldownOptions,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(
                            reminderRepeatCooldownMinutes: value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RobotFaceEnumDropdown<RobotReminderRepeatPolicy>(
                  label: 'Reminder repeat policy',
                  helperText:
                      'Choose whether normal reminder voice can replay after the reminder cooldown.',
                  value: settings.reminderRepeatPolicy,
                  enabled: !_isSaving,
                  options: RobotReminderRepeatPolicy.values,
                  labelBuilder: _robotReminderRepeatPolicyLabel,
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(reminderRepeatPolicy: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.voiceQuietHoursEnabled,
                  enabled: !_isSaving,
                  title: 'Quiet hours',
                  subtitle: 'Mute Robot voice during your chosen quiet window.',
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(voiceQuietHoursEnabled: value),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RobotFaceEnumDropdown<int>(
                        label: 'Quiet hours start',
                        helperText:
                            'When Robot voice should start staying quiet.',
                        value: settings.voiceQuietHoursStartMinutes,
                        enabled: !_isSaving,
                        options: _quietHourOptions,
                        labelBuilder: _clockTimeLabel,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(voiceQuietHoursStartMinutes: value),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RobotFaceEnumDropdown<int>(
                        label: 'Quiet hours end',
                        helperText: 'When Robot voice can resume normally.',
                        value: settings.voiceQuietHoursEndMinutes,
                        enabled: !_isSaving,
                        options: _quietHourOptions,
                        labelBuilder: _clockTimeLabel,
                        onChanged: (value) => _saveSettings(
                          settings.copyWith(voiceQuietHoursEndMinutes: value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.voiceSafetyDuringQuietHoursEnabled,
                  enabled: !_isSaving,
                  title: 'Allow safety voice during quiet hours',
                  subtitle:
                      'Let missed-dose, controller, and safety/check prompts still speak.',
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(
                      voiceSafetyDuringQuietHoursEnabled: value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Voice types',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.reminderVoiceEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Reminder voice',
                  subtitle: 'Upcoming, ready, and normal cup-check reminders.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Reminder voice',
                    phrase: DoseyVoicePhrase.doseSoon,
                    enabled:
                        settings.voiceEnabled && settings.reminderVoiceEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(reminderVoiceEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.dispenseNarrationEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Dispense narration',
                  subtitle: 'Preparing, dispensing, and movement phrases.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Dispense narration',
                    phrase: DoseyVoicePhrase.movingCarousel,
                    enabled:
                        settings.voiceEnabled &&
                        settings.dispenseNarrationEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(dispenseNarrationEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.safetyConfirmationVoiceEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Safety/confirmation voice',
                  subtitle: 'Check-cup and confirm-only-after-taken prompts.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Safety/confirmation voice',
                    phrase: DoseyVoicePhrase.confirmAfterTaken,
                    enabled:
                        settings.voiceEnabled &&
                        settings.safetyConfirmationVoiceEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(safetyConfirmationVoiceEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.missedDoseVoiceEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Missed dose voice',
                  subtitle: 'Missed-dose and review phrases.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Missed dose voice',
                    phrase: DoseyVoicePhrase.missedWarning,
                    enabled:
                        settings.voiceEnabled &&
                        settings.missedDoseVoiceEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(missedDoseVoiceEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.controllerAlertVoiceEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Controller alert voice',
                  subtitle: 'Offline, error, attention, and recovery prompts.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Controller alert voice',
                    phrase: DoseyVoicePhrase.controllerOffline,
                    enabled:
                        settings.voiceEnabled &&
                        settings.controllerAlertVoiceEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(controllerAlertVoiceEnabled: value),
                  ),
                ),
                const SizedBox(height: 8),
                _SettingsSwitchTile(
                  value: settings.idleChatterVoiceEnabled,
                  enabled: !_isSaving && settings.voiceEnabled,
                  title: 'Idle chatter voice',
                  subtitle: 'Optional idle chatter when voice variety is on.',
                  action: _buildVoicePreviewButton(
                    settings: settings,
                    title: 'Idle chatter voice',
                    phrase: DoseyVoicePhrase.standingBy,
                    enabled:
                        settings.voiceEnabled &&
                        settings.idleChatterVoiceEnabled,
                  ),
                  onChanged: (value) => _saveSettings(
                    settings.copyWith(idleChatterVoiceEnabled: value),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: !_isSaving && settings.voiceEnabled
                      ? () => _testVoice(settings)
                      : null,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Test voice'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RobotFaceTimingDropdown(
                        label: 'Wake before dose',
                        helperText:
                            'Brighten the face before a scheduled dose.',
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
                        helperText:
                            'Keep the face awake while someone confirms, skips, or asks for help.',
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

  Future<void> _testVoice(RobotFaceSettings settings) async {
    try {
      await widget.previewVoicePlayer.speak(
        DoseyVoicePhrase.ready,
        volume: settings.voiceVolumePreset.volume,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Robot voice test failed: $error')),
      );
    }
  }

  Widget _buildVoicePreviewButton({
    required RobotFaceSettings settings,
    required String title,
    required DoseyVoicePhrase phrase,
    required bool enabled,
  }) {
    return IconButton(
      key: ValueKey<String>('voice-preview:$title'),
      tooltip: 'Preview $title',
      onPressed: enabled ? () => _previewVoice(settings, phrase) : null,
      icon: const Icon(Icons.play_arrow_rounded),
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _previewVoice(
    RobotFaceSettings settings,
    DoseyVoicePhrase phrase,
  ) async {
    try {
      await widget.previewVoicePlayer.speak(
        phrase,
        volume: settings.voiceVolumePreset.volume,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Robot voice preview failed: $error')),
      );
    }
  }
}

class _RobotFaceTimingDropdown extends StatelessWidget {
  const _RobotFaceTimingDropdown({
    required this.label,
    required this.helperText,
    required this.value,
    required this.fallbackValue,
    required this.enabled,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String helperText;
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
      helperText: helperText,
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

class _RobotFaceEnumDropdown<T> extends StatelessWidget {
  const _RobotFaceEnumDropdown({
    required this.label,
    required this.helperText,
    required this.value,
    required this.enabled,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final String helperText;
  final T value;
  final bool enabled;
  final List<T> options;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
      key: ValueKey('$label:$value'),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: options
              .map(
                (option) => DropdownMenuItem<T>(
                  value: option,
                  child: Text(labelBuilder(option)),
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

String _pirWakeDurationLabel(int seconds) {
  if (seconds < 60) {
    return '$seconds seconds';
  }

  final minutes = seconds ~/ 60;
  return minutes == 1 ? '1 minute' : '$minutes minutes';
}

String _robotVoiceVolumePresetLabel(RobotVoiceVolumePreset preset) {
  return switch (preset) {
    RobotVoiceVolumePreset.quiet => 'Quiet',
    RobotVoiceVolumePreset.normal => 'Normal',
    RobotVoiceVolumePreset.loud => 'Loud',
  };
}

String _robotReminderRepeatPolicyLabel(RobotReminderRepeatPolicy policy) {
  return switch (policy) {
    RobotReminderRepeatPolicy.noRepeats => 'No repeats',
    RobotReminderRepeatPolicy.repeatRemindersOnly => 'Repeat reminders only',
    RobotReminderRepeatPolicy.repeatRemindersAndReady =>
      'Repeat reminders and dose ready',
  };
}

String _clockTimeLabel(int minutes) {
  final normalizedMinutes = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
  final hour = normalizedMinutes ~/ 60;
  final minute = normalizedMinutes % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final paddedMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$paddedMinute $suffix';
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
      // Request permission before scheduling the test so the result reflects
      // the user's current system setting.
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

class _HelpAboutCard extends StatelessWidget {
  const _HelpAboutCard();

  static const _appVersion = String.fromEnvironment(
    'DOSEY_APP_VERSION',
    defaultValue: '1.0.0+1',
  );
  static const _githubUrl = 'https://github.com/SloppyBobbert/Dosey';

  @override
  Widget build(BuildContext context) {
    return const _SettingsSectionCard(
      icon: Icons.help_outline,
      title: 'Help & About',
      children: [
        Text('Dosey $_appVersion'),
        SizedBox(height: 8),
        Text(
          'This prototype is not a medical-grade device. Test only with fake pills, candy, beads, dry beans, or vitamins.',
        ),
        SizedBox(height: 8),
        Text(
          'If a dose was missed, follow your prescription instructions or ask your caregiver, pharmacist, or doctor. Do not double dose unless your prescription instructions say to.',
        ),
        SizedBox(height: 8),
        Text('Caregiver sharing and cloud sync are not active yet.'),
        SizedBox(height: 8),
        Text('GitHub: $_githubUrl'),
        SizedBox(height: 4),
        SelectableText(_githubUrl),
      ],
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
    this.action,
  });

  final bool value;
  final bool enabled;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;
  final Widget? action;

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
        secondary: action,
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
