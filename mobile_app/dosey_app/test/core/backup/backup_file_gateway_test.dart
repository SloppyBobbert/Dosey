import 'dart:io';
import 'dart:typed_data';

import 'package:dosey_app/core/backup/backup_file_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('private recovery write is replaceable and readable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dosey-recovery-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final gateway = PluginBackupFileGateway(
      applicationSupportDirectory: () async => directory,
    );
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([4, 5, 6]);

    expect(await gateway.hasRecovery(), isFalse);
    await gateway.writeRecovery(first);
    expect(await gateway.readRecovery(), first);

    await gateway.writeRecovery(second);
    expect(await gateway.readRecovery(), second);
    expect(
      await File('${directory.path}/pre_restore_recovery.json.tmp').exists(),
      isFalse,
    );
    expect(
      await File(
        '${directory.path}/pre_restore_recovery.json.previous',
      ).exists(),
      isFalse,
    );
  });
}
