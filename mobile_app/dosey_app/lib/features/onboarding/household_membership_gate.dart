import 'dart:async';

import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_membership_notifier.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/local_household_cache_repository.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter/material.dart';

typedef HouseholdProtectedMutationRunner =
    Future<RobotInstallation?> Function(
      Future<RobotInstallation> Function(AdminAuditActorIdentity actor) action,
    );

class HouseholdMembershipGate extends StatefulWidget {
  const HouseholdMembershipGate({
    super.key,
    required this.accountId,
    required this.sync,
    required this.management,
    required this.membership,
    required this.cache,
    required this.runProtectedMutation,
    required this.child,
    this.onHouseholdCreated,
    this.now = DateTime.now,
  });

  final String accountId;
  final HouseholdSyncGateway sync;
  final HouseholdManagementGateway management;
  final HouseholdMembershipNotifier membership;
  final LocalHouseholdCacheRepository cache;
  final HouseholdProtectedMutationRunner runProtectedMutation;
  final Widget child;
  final Future<void> Function(
    RobotInstallation robot,
    AdminAuditActorIdentity actor,
  )?
  onHouseholdCreated;
  final DateTime Function() now;

  @override
  State<HouseholdMembershipGate> createState() =>
      _HouseholdMembershipGateState();
}

enum _MembershipGateState { loading, linked, cachedOffline, unlinked, error }

class _HouseholdMembershipGateState extends State<HouseholdMembershipGate> {
  final _householdNameController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  _MembershipGateState _state = _MembershipGateState.loading;
  bool _submitting = false;
  String? _actionError;
  StreamSubscription<RobotInstallation?>? _syncSubscription;
  var _membershipChange = 0;

  @override
  void initState() {
    super.initState();
    widget.membership.addListener(_handlePublishedMembership);
    _subscribeToSync();
    _refresh();
  }

  @override
  void didUpdateWidget(HouseholdMembershipGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership != widget.membership) {
      oldWidget.membership.removeListener(_handlePublishedMembership);
      widget.membership.addListener(_handlePublishedMembership);
    }
    if (oldWidget.sync != widget.sync) {
      unawaited(_syncSubscription?.cancel());
      _subscribeToSync();
    }
    if (oldWidget.accountId != widget.accountId) {
      _state = _MembershipGateState.loading;
      _refresh();
    }
  }

  @override
  void dispose() {
    widget.membership.removeListener(_handlePublishedMembership);
    unawaited(_syncSubscription?.cancel());
    _householdNameController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.management.isAvailable) return widget.child;
    return switch (_state) {
      _MembershipGateState.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _MembershipGateState.linked => widget.child,
      _MembershipGateState.cachedOffline => Stack(
        children: [
          widget.child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined),
                    SizedBox(width: 10),
                    Expanded(child: Text('Household status is offline')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      _MembershipGateState.unlinked => _buildUnlinked(context),
      _MembershipGateState.error => _buildLoadError(context),
    };
  }

  Widget _buildUnlinked(BuildContext context) {
    final enabled = widget.management.isAvailable && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your Dosey household')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Connect this personal account to one Dosey robot household.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('household-name-field'),
            controller: _householdNameController,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Robot display name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: enabled ? _createHousehold : null,
            child: const Text('Create a household'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          TextField(
            key: const ValueKey('household-invitation-code-field'),
            controller: _invitationCodeController,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invitation code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: enabled ? _acceptInvitation : null,
            child: const Text('Join with a code'),
          ),
          if (!widget.management.isAvailable) ...[
            const SizedBox(height: 16),
            const Text('Cloud household management is not configured.'),
          ],
          if (_actionError case final error?) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _submitting ? null : _refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                'Household could not load',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Reconnect and retry. This account has no confirmed offline household cache.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _state = _MembershipGateState.loading;
        _actionError = null;
      });
    }
    try {
      final robot = await widget.sync.refreshRobot();
      await _applyConfirmedMembership(robot);
    } on Object {
      final cached = await widget.cache.readForAccount(widget.accountId);
      if (!mounted) return;
      setState(
        () => _state = cached == null
            ? _MembershipGateState.error
            : _MembershipGateState.cachedOffline,
      );
    }
  }

  Future<void> _createHousehold() async {
    final displayName = _householdNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _actionError = 'Enter a robot display name.');
      return;
    }
    await _runMutation(
      (actor) => widget.management.createRobot(displayName),
      afterSuccess: widget.onHouseholdCreated,
    );
  }

  Future<void> _acceptInvitation() async {
    final code = _invitationCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _actionError = 'Enter an invitation code.');
      return;
    }
    await _runMutation((actor) => widget.management.acceptInvitation(code));
  }

  Future<void> _runMutation(
    Future<RobotInstallation> Function(AdminAuditActorIdentity actor) action, {
    Future<void> Function(
      RobotInstallation robot,
      AdminAuditActorIdentity actor,
    )?
    afterSuccess,
  }) async {
    setState(() {
      _submitting = true;
      _actionError = null;
    });
    try {
      final robot = await widget.runProtectedMutation((actor) async {
        final updated = await action(actor);
        if (afterSuccess != null) {
          try {
            await afterSuccess(updated, actor);
          } on Object {
            // The cloud mutation cannot be undone if local audit persistence fails.
          }
        }
        return updated;
      });
      if (robot == null) return;
      widget.membership.update(robot);
      if (mounted) setState(() => _state = _MembershipGateState.linked);
      try {
        await _cache(robot);
      } on Object {
        // The server result is authoritative; cache repair can happen on refresh.
      }
    } on HouseholdManagementException catch (error) {
      if (mounted) setState(() => _actionError = _messageFor(error.reason));
    } on Object {
      if (mounted) {
        setState(
          () => _actionError = 'Household setup is temporarily unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cache(RobotInstallation robot) {
    return widget.cache.replaceForAccount(
      widget.accountId,
      robot,
      confirmedAt: widget.now().toUtc(),
    );
  }

  void _subscribeToSync() {
    _syncSubscription = widget.sync.watchRobot().listen(
      (robot) => unawaited(_applyConfirmedMembership(robot)),
      onError: (_) {},
    );
  }

  void _handlePublishedMembership() {
    unawaited(_applyConfirmedMembership(widget.membership.robot));
  }

  Future<void> _applyConfirmedMembership(RobotInstallation? robot) async {
    final change = ++_membershipChange;
    try {
      if (robot == null) {
        await widget.cache.clearForAccount(widget.accountId);
      } else {
        await _cache(robot);
      }
    } on Object {
      // Live server and mutation results remain authoritative if local cache fails.
    }
    if (!mounted || change != _membershipChange) return;
    setState(
      () => _state = robot == null
          ? _MembershipGateState.unlinked
          : _MembershipGateState.linked,
    );
  }

  String _messageFor(HouseholdManagementFailureReason reason) {
    return switch (reason) {
      HouseholdManagementFailureReason.alreadyLinked =>
        'This account is already linked to a Dosey household.',
      HouseholdManagementFailureReason.householdFull =>
        'That household already has seven people.',
      HouseholdManagementFailureReason.invalidInvitation =>
        'That invitation code is invalid.',
      HouseholdManagementFailureReason.invitationExpired =>
        'That invitation code has expired.',
      HouseholdManagementFailureReason.emailMismatch =>
        'Sign in with the email address that was invited.',
      HouseholdManagementFailureReason.authenticationRequired =>
        'Sign in with a verified Google account and retry.',
      _ => 'Household setup is temporarily unavailable.',
    };
  }
}
