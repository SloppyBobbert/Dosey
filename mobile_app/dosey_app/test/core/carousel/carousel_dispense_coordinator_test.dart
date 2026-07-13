import 'package:dosey_app/core/carousel/carousel_dispense_coordinator.dart';
import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'coordinator delegates loaded-slot dispense to lifecycle service',
    () async {
      final lifecycle = _FakeControllerLifecycleService();
      final coordinator = CarouselDispenseCoordinator(
        controllerLifecycle: lifecycle,
      );

      await coordinator.dispenseLoadedSlot(
        slotId: 'slot-1',
        doseId: 'dose-1',
        scheduleId: 'schedule-1',
      );

      expect(lifecycle.requests, [
        const _DoseDispenseRequest(
          doseId: 'dose-1',
          slotId: 'slot-1',
          scheduleId: 'schedule-1',
        ),
      ]);
    },
  );
}

class _FakeControllerLifecycleService implements ControllerLifecycleService {
  final List<_DoseDispenseRequest> requests = <_DoseDispenseRequest>[];

  @override
  Future<void> requestDoseDispense({
    required String doseId,
    String? slotId,
    String? scheduleId,
  }) async {
    requests.add(
      _DoseDispenseRequest(
        doseId: doseId,
        slotId: slotId,
        scheduleId: scheduleId,
      ),
    );
  }

  @override
  Future<void> requestManualDispenseTest() async {}
}

class _DoseDispenseRequest {
  const _DoseDispenseRequest({
    required this.doseId,
    this.slotId,
    this.scheduleId,
  });

  final String doseId;
  final String? slotId;
  final String? scheduleId;

  @override
  bool operator ==(Object other) {
    return other is _DoseDispenseRequest &&
        other.doseId == doseId &&
        other.slotId == slotId &&
        other.scheduleId == scheduleId;
  }

  @override
  int get hashCode => Object.hash(doseId, slotId, scheduleId);
}
