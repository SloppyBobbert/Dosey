import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/material.dart';

enum _OnboardingStep { medicalNotice, modeSelection, signInGate }

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  var _step = _OnboardingStep.medicalNotice;
  var _noticeAcknowledged = false;
  var _isSelectingRole = false;
  AppDeviceRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
                  _OnboardingStep.modeSelection => _ModeSelectionPage(
                    onSelected: _selectRole,
                  ),
                  _OnboardingStep.signInGate => _SignInGatePage(
                    selectedRole: _selectedRole,
                    onBack: () => setState(() {
                      _isSelectingRole = false;
                      _step = _OnboardingStep.modeSelection;
                    }),
                    onSignedIn: _completeOnboarding,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueFromNotice() async {
    await DoseyAppScope.of(context).settings.setSafetyAcknowledged(true);
    if (!mounted) return;
    setState(() => _step = _OnboardingStep.modeSelection);
  }

  Future<void> _selectRole(AppDeviceRole role) async {
    if (_isSelectingRole) {
      return;
    }

    setState(() {
      _isSelectingRole = true;
      _selectedRole = role;
    });

    try {
      await DoseyAppScope.of(context).settings.setDeviceRole(role);
      if (!mounted) return;

      if (role == AppDeviceRole.androidRobot) {
        await _completeOnboarding();
        return;
      }

      setState(() => _step = _OnboardingStep.signInGate);
    } on Object {
      if (mounted) {
        setState(() => _isSelectingRole = false);
      }
      rethrow;
    }
  }

  Future<void> _completeOnboarding() {
    return DoseyAppScope.of(context).settings.setOnboardingCompleted(true);
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

class _ModeSelectionPage extends StatelessWidget {
  const _ModeSelectionPage({required this.onSelected});

  final ValueChanged<AppDeviceRole> onSelected;

  @override
  Widget build(BuildContext context) {
    final platform = currentAppDevicePlatform();
    final allowedRoles = AppDeviceRole.allowedFor(platform);

    return _OnboardingFrame(
      pageKey: const ValueKey('mode-selection'),
      icon: Icons.phone_android_outlined,
      eyebrow: 'Choose mode',
      title: 'How will you use this phone?',
      subtitle:
          'Pick the role for this device. You can change this later from Settings.',
      children: [
        for (final role in allowedRoles) ...[
          _RoleCard(role: role, onSelected: () => onSelected(role)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onSelected});

  final AppDeviceRole role;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: Icon(_iconFor(role)),
        ),
        title: Text(_titleFor(role)),
        subtitle: Text(_subtitleFor(role)),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onSelected,
      ),
    );
  }

  static IconData _iconFor(AppDeviceRole role) {
    return switch (role) {
      AppDeviceRole.androidRobot => Icons.smart_toy_outlined,
      AppDeviceRole.androidPersonal => Icons.person_outline,
      AppDeviceRole.iosPersonal => Icons.person_outline,
    };
  }

  static String _titleFor(AppDeviceRole role) {
    return switch (role) {
      AppDeviceRole.androidRobot => 'Robot Mode',
      AppDeviceRole.androidPersonal => 'Personal Mode',
      AppDeviceRole.iosPersonal => 'Personal Mode',
    };
  }

  static String _subtitleFor(AppDeviceRole role) {
    return switch (role) {
      AppDeviceRole.androidRobot =>
        'Mounted Dosey face and controller controls. Local-only setup available.',
      AppDeviceRole.androidPersonal =>
        'Your personal reminders and dose history. Requires Google sign-in.',
      AppDeviceRole.iosPersonal =>
        'Your personal reminders and dose history. Requires an account.',
    };
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
  final Future<void> Function() onSignedIn;

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
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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
