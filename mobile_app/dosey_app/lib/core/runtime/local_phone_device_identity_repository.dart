import 'dart:math';

import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:drift/drift.dart';

class LocalPhoneDeviceIdentityRepository {
  LocalPhoneDeviceIdentityRepository(
    this._database, {
    String Function()? createId,
  }) : _createId = createId ?? _newId;

  static const _key = 'phone_device_id_v1';
  static final _validId = RegExp(r'^phone-[a-f0-9]{16,48}$');

  final DoseyDatabase _database;
  final String Function() _createId;

  Future<String> getOrCreate() {
    return _database.transaction(() async {
      final existing = await _read();
      if (existing != null) return _validate(existing);

      final created = _validate(_createId());
      await _database
          .into(_database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: _key,
              value: created,
              updatedAt: DateTime.now().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      return _validate((await _read())!);
    });
  }

  Future<String?> _read() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((setting) => setting.key.equals(_key))).getSingleOrNull();
    return row?.value;
  }

  static String _validate(String value) {
    if (!_validId.hasMatch(value)) {
      throw StateError('Stored phone device identity is malformed.');
    }
    return value;
  }

  static String _newId() {
    final random = Random.secure();
    final hex = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'phone-$hex';
  }
}
