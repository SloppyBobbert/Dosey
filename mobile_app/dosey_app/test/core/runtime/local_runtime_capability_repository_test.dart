import 'package:dosey_app/core/runtime/local_runtime_capability_repository.dart';
import 'package:dosey_app/core/runtime/runtime_capability.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;
  late LocalRuntimeCapabilityRepository repository;

  setUp(() {
    database = DoseyDatabase.inMemory();
    repository = LocalRuntimeCapabilityRepository(database);
  });

  tearDown(() => database.close());

  test('persists the configured runtime capability on first launch', () async {
    await repository.ensureConfigured(RuntimeCapability.phoneOnly);

    expect(await repository.read(), RuntimeCapability.phoneOnly);
  });

  test('accepts the same persisted capability after restart', () async {
    await repository.ensureConfigured(RuntimeCapability.phoneOnly);

    await repository.ensureConfigured(RuntimeCapability.phoneOnly);

    expect(await repository.read(), RuntimeCapability.phoneOnly);
  });

  test('fails closed when launch configuration changes', () async {
    await repository.ensureConfigured(RuntimeCapability.phoneOnly);

    await expectLater(
      repository.ensureConfigured(RuntimeCapability.hardwareAssisted),
      throwsStateError,
    );
    expect(await repository.read(), RuntimeCapability.phoneOnly);
  });

  test('fails closed for a malformed persisted capability', () async {
    await database.setAppSetting('runtime_capability_v1', 'unknown');

    await expectLater(repository.read(), throwsFormatException);
    await expectLater(
      repository.ensureConfigured(RuntimeCapability.phoneOnly),
      throwsFormatException,
    );
  });
}
