import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/household/paired_robot_readiness_gateway.dart';
import 'package:dosey_app/core/household/robot_pairing_gateway.dart';
import 'package:dosey_app/core/permissions/app_permission_gateway.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/robot_onboarding_step.dart';
import 'package:flutter/material.dart';

enum _OnboardingStep {
  medicalNotice,
  roleSelection,
  signInGate,
  robotSetup,
  notificationSetup,
  robotOrientation,
  pairing,
}

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.signInRole});

  final AppDeviceRole? signInRole;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _setupSaveErrorMessage = 'Setup could not be saved. Try again.';

  late _OnboardingStep _step;
  var _noticeAcknowledged = false;
  var _initialized = false;
  AppDeviceRole? _selectedRole;
  String? _claimedRobotId;
  String? _notificationStatus;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.signInRole;
    _step = widget.signInRole == null
        ? _OnboardingStep.medicalNotice
        : _OnboardingStep.signInGate;
    _initialized = widget.signInRole != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _restoreSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final minimumActionSize = WidgetStateProperty.all(
      const Size.fromHeight(48),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(minimumSize: minimumActionSize),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(minimumSize: minimumActionSize),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(minimumSize: minimumActionSize),
        ),
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.34),
                colorScheme.surface,
                colorScheme.secondaryContainer.withValues(alpha: 0.26),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: switch (_step) {
                    _OnboardingStep.medicalNotice => _MedicalNoticePage(
                      acknowledged: _noticeAcknowledged,
                      onAcknowledgedChanged: (value) {
                        setState(() => _noticeAcknowledged = value);
                      },
                      onContinue: _noticeAcknowledged
                          ? _continueFromNotice
                          : null,
                    ),
                    _OnboardingStep.signInGate => _SignInGatePage(
                      selectedRole: _selectedRole,
                      onBack: () =>
                          setState(() => _step = _OnboardingStep.medicalNotice),
                      onSignedIn: _completePersonalOnboarding,
                    ),
                    _OnboardingStep.roleSelection => _RoleSelectionPage(
                      allowedRoles: DoseyAppScope.of(
                        context,
                      ).effectiveRole.capabilities.allowedRoles,
                      selectedRole: _selectedRole,
                      onSelected: (role) =>
                          setState(() => _selectedRole = role),
                      onContinue: _selectedRole == null
                          ? null
                          : _continueFromRoleSelection,
                    ),
                    _OnboardingStep.robotSetup => _RobotSetupPage(
                      onLocal: _startLocalRobotSetup,
                      onPair: _startPairedRobotSetup,
                    ),
                    _OnboardingStep.notificationSetup => _NotificationSetupPage(
                      onRequest: _requestNotifications,
                      status: _notificationStatus,
                      onContinue: _continueWithoutNotifications,
                    ),
                    _OnboardingStep.robotOrientation => _RobotOrientationPage(
                      onComplete: _completeOnboarding,
                    ),
                    _OnboardingStep.pairing => _PairingPendingPage(
                      initialClaimedRobotId: _claimedRobotId,
                      onClaimed: _saveClaimedRobotId,
                      onBack: _returnToRobotSetup,
                      onUseLocal: _startLocalRobotSetup,
                      onComplete: _completeOnboarding,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreSetup() async {
    try {
      final dependencies = DoseyAppScope.of(context);
      final settings = dependencies.settings;
      final safetyAcknowledged = await settings.getSafetyAcknowledged();
      final role = await dependencies.effectiveRole.getDeviceRole();
      if (!mounted) return;
      if (!safetyAcknowledged) {
        setState(() => _step = _OnboardingStep.medicalNotice);
        return;
      }
      _selectedRole = role;
      if (!role.canHostRobot) {
        setState(() => _step = _OnboardingStep.signInGate);
        return;
      }
      final robotStep = await settings.getRobotOnboardingStep();
      final claimedRobotId = await settings.getClaimedRobotId();
      if (!mounted) return;
      setState(() {
        _claimedRobotId = claimedRobotId;
        _step = switch (robotStep) {
          RobotOnboardingStep.chooseMode => _OnboardingStep.robotSetup,
          RobotOnboardingStep.notificationSetup =>
            _OnboardingStep.notificationSetup,
          RobotOnboardingStep.orientation => _OnboardingStep.robotOrientation,
          RobotOnboardingStep.pairing => _OnboardingStep.pairing,
        };
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_setupSaveErrorMessage)));
      }
    }
  }

  Future<void> _continueFromNotice() async {
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(context).settings.setSafetyAcknowledged(true),
    );
    if (!saved) return;
    if (!mounted) return;
    final dependencies = DoseyAppScope.of(context);
    final role = await dependencies.effectiveRole.getDeviceRole();
    if (!mounted) return;
    _selectedRole = role;
    final capabilities = dependencies.effectiveRole.capabilities;
    if (capabilities.allowedRoles.length > 1 ||
        capabilities.allowedRoles.single.canHostRobot) {
      setState(() => _step = _OnboardingStep.roleSelection);
      return;
    }
    _selectedRole = capabilities.allowedRoles.single;
    await dependencies.settings.setDeviceRole(_selectedRole!);
    setState(() => _step = _OnboardingStep.signInGate);
  }

  Future<void> _continueFromRoleSelection() async {
    final role = _selectedRole!;
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(context).settings.setDeviceRole(role),
    );
    if (!saved || !mounted) return;
    setState(() {
      _step = role.canHostRobot
          ? _OnboardingStep.robotSetup
          : _OnboardingStep.signInGate;
    });
  }

  Future<void> _startLocalRobotSetup() async {
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(
        context,
      ).settings.setRobotOnboardingStep(RobotOnboardingStep.notificationSetup),
    );
    if (saved && mounted) {
      setState(() => _step = _OnboardingStep.notificationSetup);
    }
  }

  Future<void> _startPairedRobotSetup() async {
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(
        context,
      ).settings.setRobotOnboardingStep(RobotOnboardingStep.pairing),
    );
    if (saved && mounted) setState(() => _step = _OnboardingStep.pairing);
  }

  Future<void> _requestNotifications() async {
    final status = await DoseyAppScope.of(
      context,
    ).notificationPermissions.request();
    if (!mounted) return;
    if (status == AppPermissionState.granted) {
      await _advanceToRobotOrientation();
      return;
    }
    setState(() {
      _notificationStatus =
          'Notifications were not allowed. You can continue and enable them later in Settings.';
    });
  }

  Future<void> _continueWithoutNotifications() => _advanceToRobotOrientation();

  Future<void> _advanceToRobotOrientation() async {
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(
        context,
      ).settings.setRobotOnboardingStep(RobotOnboardingStep.orientation),
    );
    if (saved && mounted) {
      setState(() => _step = _OnboardingStep.robotOrientation);
    }
  }

  Future<void> _saveClaimedRobotId(String robotId) async {
    await DoseyAppScope.of(context).settings.setClaimedRobotId(robotId);
    if (mounted) setState(() => _claimedRobotId = robotId);
  }

  Future<void> _returnToRobotSetup() async {
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(
        context,
      ).settings.setRobotOnboardingStep(RobotOnboardingStep.chooseMode),
    );
    if (saved && mounted) setState(() => _step = _OnboardingStep.robotSetup);
  }

  Future<bool> _completeOnboarding() {
    return _saveSetupChange(
      () => DoseyAppScope.of(context).settings.setOnboardingCompleted(true),
    );
  }

  Future<bool> _completePersonalOnboarding() {
    return _saveSetupChange(
      () => DoseyAppScope.of(context).settings.beginPersonalSetup(),
    );
  }

  Future<bool> _saveSetupChange(Future<void> Function() save) async {
    try {
      await save();
      return true;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(_setupSaveErrorMessage)));
      }
      return false;
    }
  }
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    required this.pageKey,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final Key pageKey;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      key: pageKey,
      padding: const EdgeInsets.all(20),
      shrinkWrap: true,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  eyebrow.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MedicalNoticePage extends StatelessWidget {
  const _MedicalNoticePage({
    required this.acknowledged,
    required this.onAcknowledgedChanged,
    required this.onContinue,
  });

  final bool acknowledged;
  final ValueChanged<bool> onAcknowledgedChanged;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _OnboardingFrame(
      pageKey: const ValueKey('medical-notice'),
      icon: Icons.health_and_safety_outlined,
      eyebrow: 'Safety first',
      title: 'Dosey is not a medical device',
      subtitle:
          'Dosey helps with reminders and dispensing routines. It does not provide medical advice, verify prescriptions, or replace a caregiver, pharmacist, or doctor.',
      children: [
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: CheckboxListTile(
            value: acknowledged,
            onChanged: (value) => onAcknowledgedChanged(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I understand I am responsible for following my prescription instructions.',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
      ],
    );
  }
}

class _RoleSelectionPage extends StatelessWidget {
  const _RoleSelectionPage({
    required this.allowedRoles,
    required this.selectedRole,
    required this.onSelected,
    required this.onContinue,
  });

  final List<AppDeviceRole> allowedRoles;
  final AppDeviceRole? selectedRole;
  final ValueChanged<AppDeviceRole> onSelected;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return _OnboardingFrame(
      pageKey: const ValueKey('role-selection'),
      icon: Icons.devices_outlined,
      eyebrow: 'Choose this phone’s role',
      title: 'How will you use this phone?',
      subtitle:
          'This choice controls the Dosey experience. It does not enable Bluetooth or hardware by itself.',
      children: [
        RadioGroup<AppDeviceRole>(
          groupValue: selectedRole,
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
          child: Column(
            children: [
              for (final role in allowedRoles)
                Semantics(
                  selected: selectedRole == role,
                  inMutuallyExclusiveGroup: true,
                  child: RadioListTile<AppDeviceRole>(
                    key: ValueKey(
                      role.canHostRobot
                          ? 'robot-role-option'
                          : 'personal-role-option',
                    ),
                    value: role,
                    title: Text(role.canHostRobot ? 'Robot' : 'Personal'),
                    subtitle: Text(
                      role.canHostRobot
                          ? 'Run Dosey on the mounted Robot phone.'
                          : 'Manage routines for yourself or someone you support.',
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
      ],
    );
  }
}

class _RobotSetupPage extends StatelessWidget {
  const _RobotSetupPage({required this.onLocal, required this.onPair});

  final VoidCallback onLocal;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return _OnboardingFrame(
      pageKey: const ValueKey('robot-setup-choice'),
      icon: Icons.smartphone_outlined,
      eyebrow: 'Robot setup',
      title: 'Set up this Robot phone',
      subtitle:
          'Use reminders on this phone only, or connect it to a Personal Dosey account.',
      children: [
        FilledButton(
          onPressed: onLocal,
          child: const Text('Use local reminders'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onPair,
          child: const Text('Pair with Personal'),
        ),
      ],
    );
  }
}

class _NotificationSetupPage extends StatelessWidget {
  const _NotificationSetupPage({
    required this.onRequest,
    required this.status,
    required this.onContinue,
  });

  final Future<void> Function() onRequest;
  final String? status;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return _OnboardingFrame(
      pageKey: const ValueKey('notification-setup'),
      icon: Icons.notifications_active_outlined,
      eyebrow: 'Local reminders',
      title: 'Allow reminder notifications',
      subtitle:
          'Dosey can remind you locally. Denying notifications does not infer that a dose was taken.',
      children: [
        FilledButton(
          onPressed: onRequest,
          child: const Text('Allow notifications'),
        ),
        if (status != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(status!)),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: onContinue,
          child: const Text('Continue without notifications'),
        ),
      ],
    );
  }
}

class _RobotOrientationPage extends StatelessWidget {
  const _RobotOrientationPage({required this.onComplete});

  final Future<bool> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    return _OnboardingFrame(
      pageKey: const ValueKey('robot-orientation'),
      icon: Icons.today_outlined,
      eyebrow: 'Ready',
      title: 'Your Robot phone is ready',
      subtitle:
          'Today shows scheduled doses. Record Taken only after confirmation; Snooze, Skip, Help, and History remain available offline.',
      children: [
        FilledButton(onPressed: onComplete, child: const Text('Open Today')),
      ],
    );
  }
}

class _PairingPendingPage extends StatefulWidget {
  const _PairingPendingPage({
    required this.initialClaimedRobotId,
    required this.onClaimed,
    required this.onBack,
    required this.onUseLocal,
    required this.onComplete,
  });

  final String? initialClaimedRobotId;
  final Future<void> Function(String robotId) onClaimed;
  final Future<void> Function() onBack;
  final Future<void> Function() onUseLocal;
  final Future<bool> Function() onComplete;

  @override
  State<_PairingPendingPage> createState() => _PairingPendingPageState();
}

class _PairingPendingPageState extends State<_PairingPendingPage> {
  final _controller = TextEditingController();
  String? _status;
  late String? _claimedRobotId;
  var _claiming = false;

  @override
  void initState() {
    super.initState();
    _claimedRobotId = widget.initialClaimedRobotId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateway = DoseyAppScope.of(context).robotPairing;
    final readinessAvailable = DoseyAppScope.of(
      context,
    ).pairedRobotReadiness.isAvailable;
    final unavailable = !gateway.isAvailable || !readinessAvailable;
    return _OnboardingFrame(
      pageKey: const ValueKey('robot-pairing'),
      icon: Icons.link_outlined,
      eyebrow: 'Pair with Personal',
      title: 'Enter the code from the Personal phone',
      subtitle:
          'Setup completes only after this exact phone identity and medication sync are verified.',
      children: [
        TextField(
          controller: _controller,
          enabled: gateway.isAvailable && !_claiming,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Pairing code'),
        ),
        if (unavailable && _status == null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              'Pairing verification is unavailable. This Robot cannot finish paired setup yet.',
            ),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(_status!)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: gateway.isAvailable && !_claiming
              ? (_claimedRobotId == null ? _claim : _verifyReadiness)
              : null,
          child: Text(
            _claiming
                ? 'Checking…'
                : _claimedRobotId == null
                ? 'Pair this phone'
                : 'Check again',
          ),
        ),
        if (unavailable) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onUseLocal,
            child: const Text('Use local reminders'),
          ),
        ],
        TextButton(onPressed: widget.onBack, child: const Text('Back')),
      ],
    );
  }

  Future<void> _claim() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _status = 'Enter the pairing code.');
      return;
    }
    setState(() {
      _claiming = true;
      _status = null;
    });
    try {
      _claimedRobotId = await DoseyAppScope.of(
        context,
      ).robotPairing.claimRobot(code: code);
      await widget.onClaimed(_claimedRobotId!);
      await _verifyReadiness();
    } on RobotPairingException catch (error) {
      if (mounted) setState(() => _status = _pairingErrorMessage(error.reason));
    } on Object {
      if (mounted) {
        setState(() => _status = 'Pairing service failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  String _pairingErrorMessage(RobotPairingFailureReason reason) {
    return switch (reason) {
      RobotPairingFailureReason.invalidCode =>
        'That pairing code is invalid. Check it and try again.',
      RobotPairingFailureReason.missingSession =>
        'This Robot phone is not ready to pair. Restart setup and try again.',
      RobotPairingFailureReason.consumedCode =>
        'That pairing code was already used. Generate a new code.',
      RobotPairingFailureReason.expiredCode =>
        'That pairing code expired. Generate a new code.',
      RobotPairingFailureReason.blockedDevice =>
        'This Robot phone is blocked from pairing.',
      RobotPairingFailureReason.functionFailure =>
        'Pairing service failed. Try again.',
    };
  }

  Future<void> _verifyReadiness() async {
    final robotId = _claimedRobotId;
    if (robotId == null) return;
    setState(() {
      _claiming = true;
      _status = null;
    });
    try {
      final dependencies = DoseyAppScope.of(context);
      if (!dependencies.pairedRobotReadiness.isAvailable) {
        setState(
          () => _status =
              'Code accepted. Waiting for this phone identity and sync to be verified.',
        );
        return;
      }
      final localDeviceId = await dependencies.phoneDeviceIdentity
          .getOrCreate();
      final readiness = await dependencies.pairedRobotReadiness.verify(
        robotId: robotId,
        localDeviceId: localDeviceId,
      );
      if (!mounted) return;
      switch (readiness.status) {
        case PairedRobotReadinessStatus.ready:
          if (readiness.mountedDeviceId != localDeviceId) {
            setState(
              () => _status = 'This phone does not match the paired Robot.',
            );
            return;
          }
          await widget.onComplete();
        case PairedRobotReadinessStatus.identityMismatch:
          setState(
            () => _status = 'This phone does not match the paired Robot.',
          );
        case PairedRobotReadinessStatus.waitingForIdentity:
          setState(
            () => _status = 'Waiting for this phone identity to be verified.',
          );
        case PairedRobotReadinessStatus.waitingForSync:
          setState(() => _status = 'This phone matches. Waiting for sync.');
      }
    } on Object {
      if (mounted) setState(() => _status = 'Verification failed. Try again.');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }
}

class _SignInGatePage extends StatefulWidget {
  const _SignInGatePage({
    required this.selectedRole,
    required this.onBack,
    required this.onSignedIn,
  });

  final AppDeviceRole? selectedRole;
  final VoidCallback onBack;
  final Future<bool> Function() onSignedIn;

  @override
  State<_SignInGatePage> createState() => _SignInGatePageState();
}

class _SignInGatePageState extends State<_SignInGatePage> {
  var _isSigningIn = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final role = widget.selectedRole;
    final isAndroidPersonal = role == AppDeviceRole.androidPersonal;
    final isIosPersonal = role == AppDeviceRole.iosPersonal;

    return _OnboardingFrame(
      pageKey: const ValueKey('sign-in-gate'),
      icon: isIosPersonal ? Icons.apple : Icons.account_circle_outlined,
      eyebrow: 'Account needed',
      title: 'Sign in to continue',
      subtitle: isAndroidPersonal
          ? 'Personal Mode requires Google sign-in for now.'
          : 'Personal Mode requires an account.',
      children: [
        if (_errorMessage != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _isSigningIn
              ? null
              : () async {
                  setState(() {
                    _isSigningIn = true;
                    _errorMessage = null;
                  });
                  try {
                    if (isIosPersonal) {
                      // Native Apple sign-in is only offered for iOS Personal Mode.
                      await dependencies.auth.signInWithApple();
                    } else {
                      await dependencies.auth.signInWithGoogle();
                    }
                    await widget.onSignedIn();
                  } on Object {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _errorMessage = isIosPersonal
                          ? 'Apple sign-in failed. Check your connection and try again.'
                          : 'Google sign-in failed. Check your connection and try again.';
                    });
                  } finally {
                    if (mounted) {
                      setState(() => _isSigningIn = false);
                    }
                  }
                },
          child: Text(
            _isSigningIn
                ? 'Signing in...'
                : isIosPersonal
                ? 'Continue with Apple'
                : 'Continue with Google',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isSigningIn ? null : widget.onBack,
          child: const Text('Back'),
        ),
      ],
    );
  }
}
