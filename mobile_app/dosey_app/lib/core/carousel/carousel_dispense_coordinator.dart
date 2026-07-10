import 'package:dosey_app/core/carousel/local_carousel_slot_repository.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';

class CarouselDispenseCoordinator {
  const CarouselDispenseCoordinator({
    required this.carouselSlots,
    required this.controller,
  });

  final CarouselSlotRepository carouselSlots;
  final ControllerGateway controller;

  Future<void> dispenseLoadedSlot({
    required String slotId,
    required String doseId,
  }) async {
    var slotMarkedDispensed = false;
    try {
      // Mark the slot before movement so stale duplicate taps cannot command
      // the same loaded slot twice.
      await carouselSlots.markDispensed(slotId);
      slotMarkedDispensed = true;
      await controller.requestDispense(doseId: doseId);
    } catch (_) {
      if (slotMarkedDispensed) {
        // If the controller command fails, restore the local slot so the user
        // can retry instead of losing track of the loaded dose.
        await carouselSlots.markLoaded(slotId);
      }
      rethrow;
    }
  }
}
