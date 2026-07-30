import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:dosey_app/core/sync/appwrite_medication_sync_gateway.dart';
import 'package:dosey_app/core/sync/domain_contracts.dart';
import 'package:dosey_app/core/sync/medication_sync_pull_repository.dart';
import 'package:dosey_app/core/sync/medication_sync_pull_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DoseyDatabase database;
  const scope = AuthorizedCachedSyncScope(
    accountId: 'account-1',
    robotId: 'robot-1',
  );

  setUp(() async {
    database = DoseyDatabase.inMemory();
    await database
        .into(database.cachedRobotInstallations)
        .insert(
          CachedRobotInstallationsCompanion.insert(
            accountId: scope.accountId,
            robotId: scope.robotId,
            displayName: 'Kitchen Robot',
            ownerAccountId: scope.accountId,
            currentRole: 'owner',
            confirmedAt: DateTime.utc(2040),
          ),
        );
    await database
        .into(database.cachedHouseholdMembers)
        .insert(
          CachedHouseholdMembersCompanion.insert(
            accountId: scope.accountId,
            memberAccountId: scope.accountId,
            label: 'Owner',
            role: 'owner',
            position: 0,
          ),
        );
  });

  tearDown(() => database.close());

  test('persists each page before requesting the next page', () async {
    final gateway = _RecordingPullGateway([
      _page(cursor: null, nextCursor: '1', checkpoint: '2'),
      _page(cursor: '1', nextCursor: '2', checkpoint: '2'),
    ]);
    final repository = DriftMedicationSyncPullRepository(database);
    final service = MedicationSyncPullService(
      repository: repository,
      gateway: gateway,
    );

    final result = await service.pull(scope);

    expect(result.pagesApplied, 2);
    expect(gateway.requests.map((request) => request.toJson()), [
      const MedicationSyncPullRequest(
        robotId: 'robot-1',
        cursor: null,
        checkpoint: null,
        limit: 100,
      ).toJson(),
      const MedicationSyncPullRequest(
        robotId: 'robot-1',
        cursor: '1',
        checkpoint: '2',
        limit: 100,
      ).toJson(),
    ]);
    expect((await repository.readState(scope))!.isTerminal, isTrue);
  });

  test(
    'a reconstructed service does not restart a terminal checkpoint',
    () async {
      final firstGateway = _RecordingPullGateway([
        _page(cursor: null, nextCursor: '1', checkpoint: '1'),
      ]);
      await MedicationSyncPullService(
        repository: DriftMedicationSyncPullRepository(database),
        gateway: firstGateway,
      ).pull(scope);
      final restartedGateway = _RecordingPullGateway([]);

      final result = await MedicationSyncPullService(
        repository: DriftMedicationSyncPullRepository(database),
        gateway: restartedGateway,
      ).pull(scope);

      expect(result.pagesApplied, 0);
      expect(restartedGateway.requests, isEmpty);
    },
  );
}

PullPageContract _page({
  required String? cursor,
  required String nextCursor,
  required String checkpoint,
}) => PullPageContract.fromJson({
  'contractVersion': medicationSyncContractVersion,
  'robotId': 'robot-1',
  'cursor': cursor,
  'checkpoint': checkpoint,
  'nextCursor': nextCursor,
  'hasMore': nextCursor != checkpoint,
  'changes': <Object?>[],
});

final class _RecordingPullGateway implements MedicationSyncPullGateway {
  _RecordingPullGateway(this._pages);

  final List<PullPageContract> _pages;
  final List<MedicationSyncPullRequest> requests = [];

  @override
  Future<PullPageContract> pull(MedicationSyncPullRequest request) async {
    requests.add(request);
    return _pages.removeAt(0);
  }
}
