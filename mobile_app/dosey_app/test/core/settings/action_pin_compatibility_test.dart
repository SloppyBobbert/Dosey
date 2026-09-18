import 'dart:io';

import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PIN repository avoids JavaScript-inexact hexadecimal literals', () {
    // Focused source guard for the dart2js failure; HOST still builds the app.
    final source = File(
      'lib/core/settings/local_app_settings_repository.dart',
    ).readAsStringSync();
    final maxExactInteger = BigInt.from(9007199254740991);
    for (final literal in RegExp(r'\b0x[0-9a-fA-F]+\b').allMatches(source)) {
      expect(
        BigInt.parse(literal[0]!) <= maxExactInteger,
        isTrue,
        reason: 'JavaScript-inexact integer literal ${literal[0]}',
      );
    }
  });

  test(
    'persisted native PIN hashes retain exact code-unit verification',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );
      // Captured from the original signed-int VM implementation before repair.
      // Non-digit/empty inputs are accepted by verification, not PIN creation.
      const fixtures = [
        ('00000000000000000000000000000000', '1234', '3dd8d9842dbd6645'),
        ('0123456789abcdef0123456789abcdef', '0000', '05b074f897e5792d'),
        (
          'ffffffffffffffffffffffffffffffff',
          '98765432109876543210',
          '4d8d91e96d220655',
        ),
        ('salt', '', '3b1fee0d8ee4fcc1'),
        ('é😀', '12é😀34', '191e73ba94127367'),
        ('\u0000\uffff', 'a\u0000z', '16251cbd64e1b9c7'),
      ];
      for (final (salt, pin, hash) in fixtures) {
        for (final (key, value) in [
          ('action_pin_salt', salt),
          ('action_pin_hash', hash),
        ]) {
          await database
              .into(database.appSettings)
              .insertOnConflictUpdate(
                AppSettingsCompanion.insert(
                  key: key,
                  value: value,
                  updatedAt: DateTime.utc(2026),
                ),
              );
        }
        final before = await database.getAppSettings({
          'action_pin_salt',
          'action_pin_hash',
        });
        expect(await repository.isActionPinEnabled(), isTrue);
        expect(await repository.verifyActionPin(pin), isTrue, reason: hash);
        expect(
          await repository.verifyActionPin(' \t$pin\n'),
          isTrue,
          reason: hash,
        );
        expect(
          await repository.verifyActionPin('${pin}9'),
          isFalse,
          reason: hash,
        );
        expect(
          await database.getAppSettings({'action_pin_salt', 'action_pin_hash'}),
          before,
        );
      }
    },
  );

  test(
    'PIN creation retains normalization and rejects invalid changes',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalAppSettingsRepository(
        database,
        defaultRole: AppDeviceRole.androidPersonal,
      );
      await repository.setActionPin(' \t001234\n');
      final before = await database.getAppSettings({
        'action_pin_salt',
        'action_pin_hash',
      });
      expect(await repository.verifyActionPin('001234'), isTrue);
      expect(await repository.verifyActionPin(' \t001234\n'), isTrue);
      expect(await repository.verifyActionPin('1234'), isFalse);
      expect(
        before.singleWhere((row) => row.key == 'action_pin_hash').value,
        matches(RegExp(r'^[0-7][0-9a-f]{15}$')),
      );
      expect(
        before.singleWhere((row) => row.key == 'action_pin_salt').value,
        matches(RegExp(r'^[0-9a-f]{32}$')),
      );
      for (final pin in ['123', '12é4', '12 34', '😀1234']) {
        await expectLater(repository.setActionPin(pin), throwsArgumentError);
      }
      expect(
        await database.getAppSettings({'action_pin_salt', 'action_pin_hash'}),
        before,
      );
    },
  );
}
