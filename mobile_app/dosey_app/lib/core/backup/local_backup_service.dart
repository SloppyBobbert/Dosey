import 'package:flutter/foundation.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

import 'backup_codec.dart';
import 'backup_document.dart';
import 'backup_file_gateway.dart';
import 'local_backup_store.dart';

enum BackupOperationStatus {
  success,
  successWithNotificationWarning,
  cancelled,
  invalidBackup,
  unhealthyDatabase,
  recoveryFailure,
  restoreRolledBack,
  busy,
  failed,
}

class BackupPreview {
  const BackupPreview(this.document, this.bytes);

  final BackupDocument document;
  final Uint8List bytes;
  BackupSummary get summary => document.summary;
}

class BackupOperationResult {
  const BackupOperationResult(this.status, {this.preview, this.message});

  final BackupOperationStatus status;
  final BackupPreview? preview;
  final String? message;
}

class LocalBackupService {
  LocalBackupService({
    required this.database,
    required this.store,
    required this.gateway,
    this.codec = const BackupCodec(),
    this.syncNotifications,
  });

  final DoseyDatabase database;
  final LocalBackupStore store;
  final BackupFileGateway gateway;
  final BackupCodec codec;
  final Future<void> Function()? syncNotifications;
  bool _busy = false;

  Future<BackupOperationResult> export() => _run(() async {
    final document = await database.transaction(store.readSnapshot);
    codec.validator.validateOrThrow(document);
    final bytes = codec.encode(document);
    final now = DateTime.now().toUtc();
    final filename =
        'dosey-backup-${now.toIso8601String().replaceAll(':', '-')}.json';
    final share = await gateway.shareExport(bytes: bytes, filename: filename);
    return BackupOperationResult(
      share == BackupShareResult.dismissed
          ? BackupOperationStatus.cancelled
          : share == BackupShareResult.completed
          ? BackupOperationStatus.success
          : BackupOperationStatus.failed,
    );
  });

  Future<BackupOperationResult> pickBackupForRestore() => _run(() async {
    final bytes = await gateway.pickImportBytes();
    if (bytes == null) {
      return const BackupOperationResult(BackupOperationStatus.cancelled);
    }
    return _preview(bytes);
  });

  Future<BackupOperationResult> previewRecovery() => _run(() async {
    final bytes = await gateway.readRecovery();
    if (bytes == null) {
      return const BackupOperationResult(BackupOperationStatus.cancelled);
    }
    return _preview(bytes);
  });

  BackupOperationResult _preview(Uint8List bytes) {
    try {
      final document = codec.decode(bytes);
      return BackupOperationResult(
        BackupOperationStatus.success,
        preview: BackupPreview(document, codec.encode(document)),
      );
    } on BackupFormatException catch (error) {
      return BackupOperationResult(
        BackupOperationStatus.invalidBackup,
        message: error.message,
      );
    }
  }

  Future<BackupOperationResult> restore(
    BackupPreview preview,
  ) => _run(() async {
    late final BackupDocument document;
    late final Uint8List documentBytes;
    try {
      document = codec.decode(preview.bytes);
      documentBytes = codec.encode(document);
    } on BackupFormatException catch (error) {
      return BackupOperationResult(
        BackupOperationStatus.invalidBackup,
        message: error.message,
      );
    }
    final health = await store.checkHealth();
    if (!health.healthy) {
      return const BackupOperationResult(
        BackupOperationStatus.unhealthyDatabase,
        message:
            'Current data is not healthy enough to create a recovery backup.',
      );
    }
    try {
      late final Uint8List recoveryBytes;
      try {
        final current = await database.transaction(store.readSnapshot);
        codec.validator.validateOrThrow(current);
        recoveryBytes = codec.encode(current);
        await gateway.writeRecovery(recoveryBytes);
        final verifiedBytes = await gateway.readRecovery();
        if (verifiedBytes == null ||
            !listEquals(verifiedBytes, recoveryBytes)) {
          throw const _RecoveryException();
        }
        codec.decode(verifiedBytes);
      } on Object {
        throw const _RecoveryException();
      }
      await database.transaction(() async {
        final latestBytes = codec.encode(await store.readSnapshot());
        if (!listEquals(latestBytes, recoveryBytes)) {
          throw const _RestoreVerificationException();
        }
        await store.replaceSnapshot(document);
        final restoredBytes = codec.encode(await store.readSnapshot());
        if (!listEquals(restoredBytes, documentBytes) ||
            !await store.integrityIsOk()) {
          throw const _RestoreVerificationException();
        }
      });
    } on _RecoveryException {
      return const BackupOperationResult(BackupOperationStatus.recoveryFailure);
    } on Object {
      return const BackupOperationResult(
        BackupOperationStatus.restoreRolledBack,
      );
    }
    try {
      await syncNotifications?.call();
      return const BackupOperationResult(BackupOperationStatus.success);
    } on Object {
      return const BackupOperationResult(
        BackupOperationStatus.successWithNotificationWarning,
        message:
            'Data was restored, but future reminder notifications could not be refreshed.',
      );
    }
  });

  Future<DatabaseHealthResult> checkHealth() => store.checkHealth();
  Future<bool> hasRecovery() => gateway.hasRecovery();

  Future<BackupOperationResult> _run(
    Future<BackupOperationResult> Function() operation,
  ) async {
    if (_busy) return const BackupOperationResult(BackupOperationStatus.busy);
    _busy = true;
    try {
      return await operation();
    } on Object {
      return const BackupOperationResult(BackupOperationStatus.failed);
    } finally {
      _busy = false;
    }
  }
}

class _RecoveryException implements Exception {
  const _RecoveryException();
}

class _RestoreVerificationException implements Exception {
  const _RestoreVerificationException();
}
