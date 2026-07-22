import 'package:dosey_app/core/household/household_account_state.dart';
import 'package:dosey_app/core/household/local_household_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('household repository returns default local-only state', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdRepository(database);

    expect(
      await repository.watchState().first,
      isA<HouseholdAccountState>()
          .having(
            (state) => state.householdDisplayName,
            'householdDisplayName',
            'Dosey household',
          )
          .having(
            (state) => state.robotHubDisplayName,
            'robotHubDisplayName',
            'Dosey robot phone',
          )
          .having(
            (state) => state.connectionState,
            'connectionState',
            HouseholdConnectionState.localOnly,
          )
          .having(
            (state) => state.cloudHouseholdId,
            'cloudHouseholdId',
            isNull,
          ),
    );
  });

  test('household repository persists local display names', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdRepository(database);

    await repository.saveLocalNames(
      householdDisplayName: 'Tran family',
      robotHubDisplayName: 'Kitchen Dosey',
    );

    expect(
      await repository.watchState().first,
      isA<HouseholdAccountState>()
          .having(
            (state) => state.householdDisplayName,
            'householdDisplayName',
            'Tran family',
          )
          .having(
            (state) => state.robotHubDisplayName,
            'robotHubDisplayName',
            'Kitchen Dosey',
          ),
    );
  });

  test('household repository trims persisted display names', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdRepository(database);

    await repository.saveLocalNames(
      householdDisplayName: '  Tran family  ',
      robotHubDisplayName: '  Kitchen Dosey ',
    );

    final state = await repository.watchState().first;
    expect(state.householdDisplayName, 'Tran family');
    expect(state.robotHubDisplayName, 'Kitchen Dosey');
  });

  test('household repository rejects blank display names', () async {
    final database = DoseyDatabase.inMemory();
    addTearDown(database.close);
    final repository = LocalHouseholdRepository(database);

    await expectLater(
      () => repository.saveLocalNames(householdDisplayName: '   '),
      throwsArgumentError,
    );
  });

  test(
    'household repository stays local-only even if cloud id exists',
    () async {
      final database = DoseyDatabase.inMemory();
      addTearDown(database.close);
      final repository = LocalHouseholdRepository(database);

      await database.setAppSetting('cloud_household_id', 'cloud-123');

      final state = await repository.watchState().first;
      expect(state.connectionState, HouseholdConnectionState.localOnly);
      expect(state.cloudHouseholdId, isNull);
    },
  );
}
