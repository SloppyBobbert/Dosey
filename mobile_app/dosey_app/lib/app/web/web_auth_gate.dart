import 'dart:async';

import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:flutter/material.dart';

import 'dosey_web_dependencies.dart';
import 'dosey_web_app.dart';
import 'web_auth_configuration.dart';

class WebAuthGate extends StatefulWidget {
  const WebAuthGate({super.key, required this.dependencies});

  final DoseyWebDependencies dependencies;

  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  int _restorationAttempt = 0;

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    if (!dependencies.config.enabled) {
      return const _DisabledPreview();
    }
    return StreamBuilder<CloudIdentity>(
      key: ValueKey(_restorationAttempt),
      stream: dependencies.identity.watchIdentity(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _RestorationError(onRetry: _restart);
        }
        if (!snapshot.hasData) return const _Restoring();
        if (!snapshot.data!.isSignedIn) {
          return _SignedOut(
            identity: dependencies.identity,
            config: dependencies.config,
          );
        }
        return DoseyPersonalHome(
          identity: snapshot.data!,
          isStaging: dependencies.config.isStaging,
          onSignOut: dependencies.identity.signOut,
        );
      },
    );
  }

  void _restart() {
    setState(() => _restorationAttempt++);
  }
}

class _Restoring extends StatelessWidget {
  const _Restoring();
  @override
  Widget build(BuildContext context) =>
      const _AuthScaffold(child: CircularProgressIndicatorSemantics());
}

class CircularProgressIndicatorSemantics extends StatelessWidget {
  const CircularProgressIndicatorSemantics({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(),
      SizedBox(height: 18),
      Text('Restoring your account…'),
    ],
  );
}

class _RestorationError extends StatelessWidget {
  const _RestorationError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _AuthScaffold(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('We could not restore your account.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _DisabledPreview extends StatelessWidget {
  const _DisabledPreview();
  @override
  Widget build(BuildContext context) => const _AuthScaffold(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Dosey Personal',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'Account access is available on stable staging and production builds.',
        ),
      ],
    ),
  );
}

class _SignedOut extends StatefulWidget {
  const _SignedOut({required this.identity, required this.config});
  final CloudIdentityGateway identity;
  final WebAuthConfiguration config;
  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _userId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    await _run(
      () => widget.identity.signInWithGoogle(
        scopes: const [],
        successUrl: widget.config.oauthSuccess.toString(),
        failureUrl: widget.config.oauthFailure.toString(),
      ),
    );
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _run(() async {
      _userId = await widget.identity.requestEmailOtp(email);
    });
  }

  Future<void> _completeCode() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d+$').hasMatch(code)) {
      setState(() => _error = 'Enter the numeric code from your email.');
      return;
    }
    await _run(
      () => widget.identity.completeEmailOtp(userId: _userId!, secret: code),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'That did not work. Check your details and try again.',
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DoseyMark(),
          const SizedBox(height: 44),
          Text(
            'Dosey Personal',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF174C4F),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'A calmer place to keep your personal Dosey account close.',
          ),
          const SizedBox(height: 28),
          if (_userId == null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _google,
              icon: const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 22),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _requestCode,
              child: const Text('Email me a code'),
            ),
          ] else ...[
            Text('We sent a code to ${_email.text.trim()}.'),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Numeric code'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _completeCode,
              child: const Text('Complete sign in'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _userId = null;
                      _code.clear();
                    }),
              child: const Text('Use a different email'),
            ),
            TextButton(
              onPressed: _busy ? null : _requestCode,
              child: const Text('Resend code'),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: child,
        ),
      ),
    ),
  );
}
