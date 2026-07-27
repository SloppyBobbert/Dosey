part of 'settings_screen.dart';

class _BackupDatabaseCard extends StatefulWidget {
  const _BackupDatabaseCard();

  @override
  State<_BackupDatabaseCard> createState() => _BackupDatabaseCardState();
}

class _BackupDatabaseCardState extends State<_BackupDatabaseCard> {
  bool _isBusy = false;
  bool _hasRecovery = false;
  String? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!DoseyAppScope.of(context).isDemo) {
      _refreshRecoveryAvailability();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = DoseyAppScope.of(context).isDemo;
    return _SettingsSectionCard(
      icon: Icons.storage_outlined,
      title: 'Backup and database',
      children: [
        const Text(
          'Backups are local JSON files. They contain sensitive medication, schedule, history, and profile data and are not encrypted.',
        ),
        if (isDemo) ...[
          const SizedBox(height: 8),
          const Text(
            'Backup and restore are unavailable while FAKE DATA is active.',
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _isBusy || isDemo ? null : _exportBackup,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Export backup'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isBusy || isDemo ? null : _pickAndRestore,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restore backup'),
            ),
            if (_hasRecovery && !isDemo)
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _restoreRecovery,
                icon: const Icon(Icons.history_outlined),
                label: const Text('Restore previous data'),
              ),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _checkHealth,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Check database'),
            ),
          ],
        ),
        if (_isBusy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (_status != null) ...[const SizedBox(height: 12), Text(_status!)],
      ],
    );
  }

  Future<void> _refreshRecoveryAvailability() async {
    final available = await DoseyAppScope.of(context).backups.hasRecovery();
    if (mounted && available != _hasRecovery) {
      setState(() => _hasRecovery = available);
    }
  }

  Future<void> _exportBackup() async {
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export unencrypted backup?'),
        content: const Text(
          'Anyone who can open the JSON file can read its sensitive medication, schedule, history, and profile data. Choose a trusted destination.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (acknowledged != true || !mounted) return;
    await _runProtected(
      () =>
          _runExternalAction(() => DoseyAppScope.of(context).backups.export()),
      successMessage: 'Backup ready to share.',
    );
  }

  Future<void> _pickAndRestore() async {
    await _runProtectedPreview(
      () => _runExternalAction(
        () => DoseyAppScope.of(context).backups.pickBackupForRestore(),
      ),
    );
  }

  Future<T> _runExternalAction<T>(Future<T> Function() action) async {
    final lease = DoseyAppScope.of(
      context,
    ).externalActionResumeGuard.begin('settings');
    try {
      return await action();
    } finally {
      lease.complete();
    }
  }

  Future<void> _restoreRecovery() async {
    await _runProtectedPreview(
      () => DoseyAppScope.of(context).backups.previewRecovery(),
    );
  }

  Future<void> _runProtectedPreview(
    Future<BackupOperationResult> Function() loadPreview,
  ) async {
    _setBusy(true);
    try {
      final protected = await runProtectedAdminAction<BackupOperationResult>(
        context,
        action: (_) => loadPreview(),
      );
      if (!protected.isSuccess || !mounted) return;
      final result = protected.value!;
      if (result.status == BackupOperationStatus.cancelled) {
        _setStatus('Restore cancelled.');
        return;
      }
      final preview = result.preview;
      if (result.status != BackupOperationStatus.success || preview == null) {
        _setStatus(
          _messageFor(result, fallback: 'Backup could not be opened.'),
        );
        return;
      }
      final confirmed = await _confirmRestore(preview);
      if (confirmed != true || !mounted) return;
      final restoreResult = await DoseyAppScope.of(
        context,
      ).backups.restore(preview);
      _setStatus(
        _messageFor(restoreResult, fallback: 'Restore could not be completed.'),
      );
      await _refreshRecoveryAvailability();
    } finally {
      _setBusy(false);
    }
  }

  Future<bool?> _confirmRestore(BackupPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace local backup data?'),
        content: Text(
          'This validated backup contains ${preview.summary.totalRecords} records. Included local data will be replaced. Sign-in, Action PIN, device mode, safety acknowledgement, and other device-only settings will stay on this phone. A private recovery backup is created first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace data'),
          ),
        ],
      ),
    );
  }

  Future<void> _runProtected(
    Future<BackupOperationResult> Function() operation, {
    required String successMessage,
  }) async {
    _setBusy(true);
    try {
      final protected = await runProtectedAdminAction<BackupOperationResult>(
        context,
        action: (_) => operation(),
      );
      if (!protected.isSuccess || !mounted) return;
      final result = protected.value!;
      _setStatus(
        result.status == BackupOperationStatus.success
            ? successMessage
            : _messageFor(result, fallback: 'Backup operation failed.'),
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _checkHealth() async {
    _setBusy(true);
    try {
      final result = await DoseyAppScope.of(context).backups.checkHealth();
      _setStatus(switch (result.status) {
        DatabaseHealthStatus.healthy => 'Database check passed.',
        DatabaseHealthStatus.physicalFailure =>
          'SQLite integrity check failed. Do not restore over this data without a verified recovery path.',
        DatabaseHealthStatus.logicalFailure =>
          'Database records failed Dosey consistency checks.',
        DatabaseHealthStatus.unreadable => 'Database could not be checked.',
      });
    } finally {
      _setBusy(false);
    }
  }

  String _messageFor(BackupOperationResult result, {required String fallback}) {
    if (result.message != null) return result.message!;
    return switch (result.status) {
      BackupOperationStatus.success => 'Restore completed.',
      BackupOperationStatus.successWithNotificationWarning =>
        'Data was restored, but future reminder notifications could not be refreshed.',
      BackupOperationStatus.cancelled => 'Operation cancelled.',
      BackupOperationStatus.invalidBackup => 'The selected backup is invalid.',
      BackupOperationStatus.unhealthyDatabase =>
        'Current data is not healthy enough to create a verified recovery backup.',
      BackupOperationStatus.recoveryFailure =>
        'A verified recovery backup could not be created. No data was replaced.',
      BackupOperationStatus.restoreRolledBack =>
        'Restore failed and all database changes were rolled back.',
      BackupOperationStatus.busy =>
        'Another backup operation is still running.',
      BackupOperationStatus.failed => fallback,
    };
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _isBusy = value);
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }
}
