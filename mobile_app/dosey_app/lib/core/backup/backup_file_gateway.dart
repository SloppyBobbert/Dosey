import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum BackupShareResult { completed, dismissed, unavailable }

abstract interface class BackupFileGateway {
  Future<Uint8List?> pickImportBytes();
  Future<BackupShareResult> shareExport({
    required Uint8List bytes,
    required String filename,
  });
  Future<void> writeRecovery(Uint8List bytes);
  Future<Uint8List?> readRecovery();
  Future<bool> hasRecovery();
}

class PluginBackupFileGateway implements BackupFileGateway {
  const PluginBackupFileGateway({
    this.applicationSupportDirectory,
    this.temporaryDirectory,
  });

  final Future<Directory> Function()? applicationSupportDirectory;
  final Future<Directory> Function()? temporaryDirectory;

  static const recoveryFilename = 'pre_restore_recovery.json';

  @override
  Future<Uint8List?> pickImportBytes() async {
    final file = await file_selector.openFile(
      acceptedTypeGroups: const [
        file_selector.XTypeGroup(
          label: 'Dosey backup',
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    return file?.readAsBytes();
  }

  @override
  Future<BackupShareResult> shareExport({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!filename.endsWith('.json') ||
        filename.contains('/') ||
        filename.contains('\\')) {
      throw ArgumentError.value(
        filename,
        'filename',
        'Unsafe backup filename.',
      );
    }
    final directory =
        await (temporaryDirectory?.call() ?? getTemporaryDirectory());
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
    return switch (result.status) {
      ShareResultStatus.success => BackupShareResult.completed,
      ShareResultStatus.dismissed => BackupShareResult.dismissed,
      ShareResultStatus.unavailable => BackupShareResult.unavailable,
    };
  }

  @override
  Future<void> writeRecovery(Uint8List bytes) async {
    final directory =
        await (applicationSupportDirectory?.call() ??
            getApplicationSupportDirectory());
    final target = File('${directory.path}/$recoveryFilename');
    final temporary = File('${target.path}.tmp');
    final previous = File('${target.path}.previous');
    await temporary.writeAsBytes(bytes, flush: true);
    if (!listEquals(await temporary.readAsBytes(), bytes)) {
      await temporary.delete();
      throw const FileSystemException('Recovery backup verification failed.');
    }
    if (await previous.exists()) await previous.delete();
    try {
      if (await target.exists()) await target.rename(previous.path);
      await temporary.rename(target.path);
      if (await previous.exists()) await previous.delete();
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      if (!await target.exists() && await previous.exists()) {
        await previous.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> readRecovery() async {
    final file = await _recoveryFile();
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<bool> hasRecovery() async => (await _recoveryFile()).exists();

  Future<File> _recoveryFile() async {
    final directory =
        await (applicationSupportDirectory?.call() ??
            getApplicationSupportDirectory());
    return File('${directory.path}/$recoveryFilename');
  }
}
