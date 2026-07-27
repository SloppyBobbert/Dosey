import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:flutter/material.dart';

enum _OnboardingStep { medicalNotice, signInGate }

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
  AppDeviceRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.signInRole;
    _step = widget.signInRole == null
        ? _OnboardingStep.medicalNotice
        : _OnboardingStep.signInGate;
  }

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
                  _OnboardingStep.signInGate => _SignInGatePage(
                    selectedRole: _selectedRole,
                    onBack: () =>
                        setState(() => _step = _OnboardingStep.medicalNotice),
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
    final saved = await _saveSetupChange(
      () => DoseyAppScope.of(context).settings.setSafetyAcknowledged(true),
    );
    if (!saved) return;
    if (!mounted) return;
    final dependencies = DoseyAppScope.of(context);
    final role = await dependencies.effectiveRole.getDeviceRole();
    if (!mounted) return;
    _selectedRole = role;
    if (dependencies.effectiveRole.capabilities.requiresSignIn) {
      setState(() => _step = _OnboardingStep.signInGate);
      return;
    }
    await _completeOnboarding();
  }

  Future<bool> _completeOnboarding() {
    return _saveSetupChange(
      () => DoseyAppScope.of(context).settings.setOnboardingCompleted(true),
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
