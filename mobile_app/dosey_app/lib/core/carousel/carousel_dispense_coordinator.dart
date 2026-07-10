import 'package:dosey_app/core/controller/controller_lifecycle_service.dart';

class CarouselDispenseCoordinator {
  const CarouselDispenseCoordinator({required this.controllerLifecycle});

  final ControllerLifecycleService controllerLifecycle;

  Future<void> dispenseLoadedSlot({
    required String slotId,
    required String doseId,
    String? scheduleId,
  }) async {
    await controllerLifecycle.requestDoseDispense(
      doseId: doseId,
      slotId: slotId,
      scheduleId: scheduleId,
    );
  }
}
