import 'dart:async';

import 'package:dosey_app/app/web/dosey_web_app.dart';
import 'package:dosey_app/app/web/dosey_web_dependencies.dart';
import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:dosey_app/app/web/web_routes.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot.dart';
import 'package:dosey_app/core/caregiver/caregiver_snapshot_controller.dart';
import 'package:dosey_app/core/cloud/cloud_identity_gateway.dart';
import 'package:dosey_app/core/household/household_management_gateway.dart';
import 'package:dosey_app/core/household/household_sync_gateway.dart';
import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('account without a household can create one', (tester) async {
    final household = _HouseholdGateway(null);
    final management = _ManagementGateway(_robot(HouseholdRole.owner));
    await tester.pumpWidget(
      _app(WebRoutes.household, household: household, management: management),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create a household'), findsOneWidget);
    expect(find.text('Join with a code'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Household name'),
      'Mom’s Dosey',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create a household'));
    await tester.pumpAndSettle();

    expect(management.createdName, 'Mom’s Dosey');
    expect(household.refreshCount, 1);
  });

  testWidgets('owner sees dose actions and medication editing', (tester) async {
    final caregiver = _CaregiverGateway(_snapshot());
    await tester.pumpWidget(
      _app(
        WebRoutes.today,
        household: _HouseholdGateway(_robot(HouseholdRole.owner)),
        management: _ManagementGateway(_robot(HouseholdRole.owner)),
        caregiver: caregiver,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning medicine'), findsOneWidget);
    expect(find.text('Confirm taken'), findsOneWidget);
    expect(find.text('Skip dose'), findsOneWidget);
    expect(find.text('Request help'), findsOneWidget);

    await tester.tap(find.text('Medications'));
    await tester.pumpAndSettle();
    expect(find.text('Add medication'), findsOneWidget);
  });

  testWidgets('household member has read-only medication settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WebRoutes.medications,
        household: _HouseholdGateway(_robot(HouseholdRole.member)),
        management: _ManagementGateway(_robot(HouseholdRole.member)),
        caregiver: _CaregiverGateway(_snapshot()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning medicine'), findsOneWidget);
    expect(
      find.text('Only the household owner can edit medications.'),
      findsOneWidget,
    );
    expect(find.text('Add medication'), findsNothing);
  });

  testWidgets('dose action is only pushed after explicit confirmation', (
    tester,
  ) async {
    final caregiver = _CaregiverGateway(_snapshot());
    await tester.pumpWidget(
      _app(
        WebRoutes.today,
        household: _HouseholdGateway(_robot(HouseholdRole.member)),
        management: _ManagementGateway(_robot(HouseholdRole.member)),
        caregiver: caregiver,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm taken'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm this dose was taken?'), findsOneWidget);
    expect(caregiver.operations, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(caregiver.operations, isEmpty);

    await tester.tap(find.text('Confirm taken'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(caregiver.operations, hasLength(1));
    expect(caregiver.operations.single.kind, CaregiverMutationKind.recordDose);
    expect(
      caregiver.operations.single.values['occurrence'],
      isA<CaregiverOccurrence>(),
    );
    expect(caregiver.operations.single.values['action'], 'taken');
  });

  testWidgets(
    'pending terminal confirmation hides terminal controls but keeps help available',
    (tester) async {
      final refresh = Completer<CaregiverSnapshot>();
      final caregiver = _CaregiverGateway(_snapshot());
      await tester.pumpWidget(
        _app(
          WebRoutes.today,
          household: _HouseholdGateway(_robot(HouseholdRole.member)),
          management: _ManagementGateway(_robot(HouseholdRole.member)),
          caregiver: caregiver,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      caregiver.pulls.add(refresh.future);

      await tester.tap(find.text('Confirm taken'));
      await tester.pump();

      expect(find.text('Confirm this dose was taken?'), findsOneWidget);
      expect(find.text('Confirm taken'), findsNothing);
      expect(find.text('Skip dose'), findsNothing);
      expect(find.text('Request help'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      expect(find.text('Confirm taken'), findsNothing);
      expect(find.text('Skip dose'), findsNothing);
      expect(find.text('Request help'), findsOneWidget);

      refresh.complete(_snapshot());
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets('terminal dose states retain help but hide terminal actions', (
    tester,
  ) async {
    for (final action in [
      CaregiverDoseAction.taken,
      CaregiverDoseAction.skipped,
    ]) {
      await tester.pumpWidget(
        _app(
          WebRoutes.today,
          household: _HouseholdGateway(_robot(HouseholdRole.member)),
          management: _ManagementGateway(_robot(HouseholdRole.member)),
          caregiver: _CaregiverGateway(_snapshot(events: [_doseEvent(action)])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm taken'), findsNothing);
      expect(find.text('Skip dose'), findsNothing);
      expect(find.text('Request help'), findsOneWidget);
    }
  });

  testWidgets('a derived missed dose sends no mutation', (tester) async {
    final caregiver = _CaregiverGateway(_snapshot());
    await tester.pumpWidget(
      _app(
        WebRoutes.today,
        household: _HouseholdGateway(_robot(HouseholdRole.member)),
        management: _ManagementGateway(_robot(HouseholdRole.member)),
        caregiver: caregiver,
        now: () => DateTime(2026, 7, 29, 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Missed'), findsOneWidget);
    expect(caregiver.operations, isEmpty);
  });

  testWidgets(
    'stale dose view keeps help available but hides terminal actions',
    (tester) async {
      final caregiver = _CaregiverGateway(_snapshot());
      await tester.pumpWidget(
        _app(
          WebRoutes.today,
          household: _HouseholdGateway(_robot(HouseholdRole.member)),
          management: _ManagementGateway(_robot(HouseholdRole.member)),
          caregiver: caregiver,
        ),
      );
      await tester.pumpAndSettle();
      caregiver.pullError = const CaregiverSyncException('Offline');

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm taken'), findsNothing);
      expect(find.text('Skip dose'), findsNothing);
      expect(find.text('Request help'), findsOneWidget);
    },
  );

  testWidgets(
    'refreshing dose view keeps help available but hides terminal actions',
    (tester) async {
      final refresh = Completer<CaregiverSnapshot>();
      final caregiver = _CaregiverGateway(_snapshot());
      await tester.pumpWidget(
        _app(
          WebRoutes.today,
          household: _HouseholdGateway(_robot(HouseholdRole.member)),
          management: _ManagementGateway(_robot(HouseholdRole.member)),
          caregiver: caregiver,
        ),
      );
      await tester.pumpAndSettle();
      caregiver.pulls.add(refresh.future);

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();

      expect(find.text('Confirm taken'), findsNothing);
      expect(find.text('Skip dose'), findsNothing);
      expect(find.text('Request help'), findsOneWidget);
      refresh.complete(_snapshot());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('owner can add a medication', (tester) async {
    final caregiver = _CaregiverGateway(_snapshot());
    final household = _HouseholdGateway(_robot(HouseholdRole.owner));
    final management = _ManagementGateway(_robot(HouseholdRole.owner));
    await tester.pumpWidget(
      _app(
        WebRoutes.medications,
        household: household,
        management: management,
        caregiver: caregiver,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Medication name'),
      'Evening medicine',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Instructions'),
      'Take with water',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      caregiver.operations.single.kind,
      CaregiverMutationKind.upsertMedication,
    );
  });

  testWidgets('editing a medication preserves its pill type', (tester) async {
    final caregiver = _CaregiverGateway(
      _snapshot(pillType: CaregiverPillType.capsule),
    );
    final household = _HouseholdGateway(_robot(HouseholdRole.owner));
    final management = _ManagementGateway(_robot(HouseholdRole.owner));
    await tester.pumpWidget(
      _app(
        WebRoutes.medications,
        household: household,
        management: management,
        caregiver: caregiver,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Morning medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(caregiver.operations.single.values['pillType'], 'capsule');
  });

  testWidgets('owner can add a timed schedule', (tester) async {
    final caregiver = _CaregiverGateway(_snapshot());
    final household = _HouseholdGateway(_robot(HouseholdRole.owner));
    final management = _ManagementGateway(_robot(HouseholdRole.owner));
    await tester.pumpWidget(
      _app(
        WebRoutes.schedules,
        household: household,
        management: management,
        caregiver: caregiver,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Times use UTC.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Schedule label'),
      'Bedtime',
    );
    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    expect(find.text('Select time'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final schedule = caregiver.operations.last;
    expect(schedule.kind, CaregiverMutationKind.upsertSchedule);
    expect(schedule.values['hour'], 9);
    expect(schedule.values['minute'], 0);
    expect(schedule.values['timezoneId'], 'UTC');
  });
}

Widget _app(
  String route, {
  required HouseholdSyncGateway household,
  required HouseholdManagementGateway management,
  CaregiverSyncGateway? caregiver,
  DateTime Function()? now,
}) => DoseyWebApp(
  initialRoute: route,
  dependencies: DoseyWebDependencies(
    identity: const _Identity(),
    config: WebAuthConfiguration.fromValues(
      enabled: true,
      appOrigin: 'https://dosey.dev',
      endpoint: 'https://cloud.example/v1',
      projectId: 'project',
    ),
    household: household,
    householdManagement: management,
    caregiver: caregiver ?? _CaregiverGateway(_snapshot()),
    now: now ?? () => DateTime(2026, 7, 29, 9),
  ),
);

class _Identity implements CloudIdentityGateway {
  const _Identity();

  @override
  Stream<CloudIdentity> watchIdentity() => Stream.value(
    const CloudIdentity.signedIn(
      accountId: 'account-1',
      email: 'caregiver@example.com',
    ),
  );

  @override
  Future<CloudIdentity> signInWithGoogle({
    List<String> scopes = const [],
    String? successUrl,
    String? failureUrl,
  }) async => const CloudIdentity.signedOut();

  @override
  Future<String> requestEmailOtp(String email) => throw UnimplementedError();

  @override
  Future<CloudIdentity> completeEmailOtp({
    required String userId,
    required String secret,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

class _HouseholdGateway implements HouseholdSyncGateway {
  _HouseholdGateway(this.robot);
  RobotInstallation? robot;
  int refreshCount = 0;

  @override
  Stream<RobotInstallation?> watchRobot() => Stream.value(robot);

  @override
  Future<RobotInstallation?> refreshRobot() async {
    refreshCount += 1;
    return robot;
  }
}

class _ManagementGateway implements HouseholdManagementGateway {
  _ManagementGateway(this.robot);
  final RobotInstallation robot;
  String? createdName;

  @override
  bool get isAvailable => true;

  @override
  Future<RobotInstallation> createRobot(String displayName) async {
    createdName = displayName;
    return robot;
  }

  @override
  Future<RobotInstallation> acceptInvitation(String code) async => robot;

  @override
  Future<HouseholdInvitationCredential> createInvitation(
    String robotId,
    String email,
  ) => throw UnimplementedError();

  @override
  Future<void> leaveRobot(String robotId) => throw UnimplementedError();

  @override
  Future<RobotInstallation> removeMember(String robotId, String accountId) =>
      throw UnimplementedError();
}

class _CaregiverGateway implements CaregiverSyncGateway {
  _CaregiverGateway(this.snapshot);
  CaregiverSnapshot snapshot;
  final operations = <CaregiverMutation>[];
  final pulls = <Future<CaregiverSnapshot>>[];
  Object? pullError;

  @override
  Future<CaregiverPullResult> pull(
    String robotId, {
    String? cursor,
    String? checkpoint,
    int limit = 100,
  }) async {
    if (pulls.isNotEmpty) {
      return CaregiverPullResult(
        snapshot: await pulls.removeAt(0),
        cursor: null,
        checkpoint: 'checkpoint-1',
      );
    }
    if (pullError case final error?) throw error;
    return CaregiverPullResult(
      snapshot: snapshot,
      cursor: null,
      checkpoint: 'checkpoint-1',
    );
  }

  @override
  Future<void> push(String robotId, List<CaregiverMutation> operations) async =>
      this.operations.addAll(operations);
}

RobotInstallation _robot(HouseholdRole role) => RobotInstallation(
  id: 'robot-1',
  displayName: 'Mom’s Dosey',
  ownerAccountId: 'owner-1',
  currentRole: role,
  mountedDeviceId: null,
  members: const [
    HouseholdMember(
      accountId: 'owner-1',
      label: 'Owner',
      role: HouseholdRole.owner,
    ),
  ],
);

CaregiverSnapshot _snapshot({
  CaregiverPillType pillType = CaregiverPillType.pill,
  List<CaregiverDoseEvent> events = const [],
}) => CaregiverSnapshot(
  householdId: 'household-1',
  revision: 'revision-1',
  generatedAt: DateTime(2026, 7, 29, 9),
  medications: [
    CaregiverMedication(
      id: 'medication-1',
      name: 'Morning medicine',
      pillType: pillType,
      instructions: 'Take with breakfast',
      active: true,
      version: 1,
    ),
  ],
  schedules: [
    CaregiverSchedule(
      id: 'schedule-1',
      medicationId: 'medication-1',
      label: 'Breakfast',
      hour: 9,
      minute: 0,
      enabled: true,
      version: 1,
    ),
  ],
  events: events,
);

CaregiverDoseEvent _doseEvent(CaregiverDoseAction action) => CaregiverDoseEvent(
  id: 'event-${action.name}',
  occurrenceId: 'schedule-1:1:2026-07-29T09:00:00.000Z',
  scheduleId: 'schedule-1',
  scheduleRevision: 1,
  scheduledFor: DateTime.utc(2026, 7, 29, 9),
  timezoneId: 'UTC',
  localDate: '2026-07-29',
  occurredAt: DateTime.utc(2026, 7, 29, 9, 5),
  action: action,
);
