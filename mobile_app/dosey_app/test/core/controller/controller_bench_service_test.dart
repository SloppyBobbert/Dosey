import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_bench_service.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:dosey_app/core/controller/local_controller_command_repository.dart';
import 'package:dosey_app/core/controller/simulated_controller_gateway.dart';
import 'package:dosey_app/core/logging/dose_log_repository.dart';
import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bench status, heartbeat, PIR, and LED commands persist results',
    () async {
      final fixture = await _BenchFixture.create();
      addTearDown(fixture.close);

      await fixture.service.run(ControllerBenchCommand.status);
      await fixture.service.run(ControllerBenchCommand.heartbeat);
      await fixture.service.run(ControllerBenchCommand.pirStatus);
      await fixture.service.run(ControllerBenchCommand.ledTest);

      final history = await fixture.repository.watchRecentHistory().first;
      expect(history.map((entry) => entry.session.commandType), [
        ControllerCommandType.ledTest,
        ControllerCommandType.pirStatus,
        ControllerCommandType.heartbeat,
        ControllerCommandType.status,
      ]);
      expect(history[0].events.last.details, 'LED test complete');
      expect(history[1].events.last.details, 'PIR idle');
      expect(
        history[2].events.last.eventType,
        ControllerCommandEventType.heartbeatOk,
      );
      expect(history[3].events.last.details, 'Simulator connected');
    },
  );

  test(
    'manual servo and dispense tests never write clinical dose logs',
    () async {
      final fixture = await _BenchFixture.create();
      addTearDown(fixture.close);

      await fixture.service.run(ControllerBenchCommand.servoTest);
      await fixture.service.run(ControllerBenchCommand.dispenseTest);

      final sessions = await fixture.database
          .select(fixture.database.controllerCommandSessions)
          .get();
      expect(sessions.map((row) => row.commandType), [
        ControllerCommandType.servoTest.name,
        ControllerCommandType.dispenseTest.name,
      ]);
      expect(
        await fixture.database.select(fixture.database.doseLogEvents).get(),
        isEmpty,
      );
    },
  );

  test('heartbeat history records offline and subsequent reconnect', () async {
    final fixture = await _BenchFixture.create();
    addTearDown(fixture.close);
    await fixture.gateway.disconnect();

    await expectLater(
      fixture.service.run(ControllerBenchCommand.heartbeat),
      throwsA(isA<ControllerTransportOfflineException>()),
    );
    await fixture.gateway.connect();
    await fixture.service.run(ControllerBenchCommand.heartbeat);

    final history = await fixture.repository.watchRecentHistory().first;
    expect(history[1].events.map((event) => event.eventType), [
      ControllerCommandEventType.commandSent,
      ControllerCommandEventType.heartbeatMissed,
      ControllerCommandEventType.offline,
    ]);
    expect(history[0].events.map((event) => event.eventType), [
      ControllerCommandEventType.commandSent,
      ControllerCommandEventType.heartbeatOk,
      ControllerCommandEventType.reconnected,
    ]);
  });
}

class _BenchFixture {
  _BenchFixture({
    required this.database,
    required this.gateway,
    required this.repository,
    required this.service,
  });

  final DoseyDatabase database;
  final SimulatedControllerGateway gateway;
  final LocalControllerCommandRepository repository;
  final ControllerBenchService service;

  static Future<_BenchFixture> create() async {
    final database = DoseyDatabase.inMemory();
    final gateway = SimulatedControllerGateway(
      canHostRobot: () => true,
      delay: (_) async {},
    );
    await gateway.connect();
    var id = 0;
    final repository = LocalControllerCommandRepository(
      database,
      sessionIdGenerator: (_, _) => 'bench:${id++}',
    );
    final lifecycle = ControllerLifecycleService(
      controller: gateway,
      commandRepository: repository,
      doseLog: DriftDoseLogRepository(database),
      carouselSlots: LocalCarouselSlotRepository(database),
      now: () => DateTime.utc(2026, 7, 10, 12, 0, id),
    );
    return _BenchFixture(
      database: database,
      gateway: gateway,
      repository: repository,
      service: ControllerBenchService(
        controller: gateway,
        lifecycle: lifecycle,
        commandRepository: repository,
        now: () => DateTime.utc(2026, 7, 10, 12, 0, id),
      ),
    );
  }

  Future<void> close() async {
    await gateway.close();
    await database.close();
  }
}
