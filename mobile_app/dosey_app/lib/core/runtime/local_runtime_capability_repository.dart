import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';

class LocalRuntimeCapabilityRepository {
  LocalRuntimeCapabilityRepository(this._database);

  static const storageKey = 'runtime_capability_v1';

  final DoseyDatabase _database;

  Future<RuntimeCapability?> read() async {
    final settings = await _database.getAppSettings({storageKey});
    if (settings.isEmpty) return null;
    return RuntimeCapability.fromStorageValue(settings.single.value);
  }

  Future<void> ensureConfigured(RuntimeCapability configured) async {
    final persisted = await read();
    if (persisted == null) {
      await _database.setAppSetting(storageKey, configured.storageValue);
      return;
    }
    if (persisted != configured) {
      throw StateError(
        'Configured runtime capability ${configured.configuredValue} conflicts '
        'with persisted capability ${persisted.configuredValue}.',
      );
    }
  }
}
