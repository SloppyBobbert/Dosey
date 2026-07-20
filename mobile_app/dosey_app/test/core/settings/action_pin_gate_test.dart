import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/core/settings/local_app_settings_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'action gate allows action without prompting when PIN is disabled',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final gate = _newGate(database);
      var prompted = false;

      final allowed = await gate.authorize(
        requestPin: () async {
          prompted = true;
          return '1234';
        },
      );

      expect(allowed, isTrue);
      expect(prompted, isFalse);
    },
  );

  test('action gate allows a single action after correct PIN', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = _newRepository(database);
    await repository.setActionPin('1234');
    final gate = ActionPinGate(repository);

    final allowed = await gate.authorize(requestPin: () async => '1234');

    expect(allowed, isTrue);
  });

  test('action gate blocks action after wrong PIN', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = _newRepository(database);
    await repository.setActionPin('1234');
    final gate = ActionPinGate(repository);

    final allowed = await gate.authorize(requestPin: () async => '4321');

    expect(allowed, isFalse);
  });

  test('action gate blocks action when PIN prompt is canceled', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = _newRepository(database);
    await repository.setActionPin('1234');
    final gate = ActionPinGate(repository);

    final allowed = await gate.authorize(requestPin: () async => null);

    expect(allowed, isFalse);
  });
}

ActionPinGate _newGate(DoseyDatabase database) {
  return ActionPinGate(_newRepository(database));
}

LocalAppSettingsRepository _newRepository(DoseyDatabase database) {
  return LocalAppSettingsRepository(
    database,
    defaultRole: AppDeviceRole.androidPersonal,
  );
}
