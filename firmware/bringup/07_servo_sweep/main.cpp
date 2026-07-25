#include <Arduino.h>
#include <ESP32Servo.h>

#include "controller_state.h"
#include "hardware_config.h"
#include "safety_limits.h"

namespace {

enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

Servo servo;
dosey::ControllerState controller;
ServoPhase phase = ServoPhase::idle;
std::uint32_t phaseDeadlineMs = 0;

void stopServo() {
  servo.detach();
  phase = ServoPhase::idle;
}

void startTest() {
  if (controller.acceptMovement("local-servo-test", millis(),
                                dosey::safety::kMovementTimeoutMs) !=
      dosey::AcceptResult::accepted) {
    Serial.println("NACK BUSY");
    return;
  }

  servo.setPeriodHertz(50);
  servo.attach(dosey::hardware::kServoPin, dosey::safety::kServoMinimumPulseUs,
               dosey::safety::kServoMaximumPulseUs);
  if (!servo.attached()) {
    controller.cancelMovement();
    stopServo();
    Serial.println("ERROR SERVO_ATTACH_FAILED");
    return;
  }
  servo.write(dosey::safety::kServoHomeDegrees);
  phase = ServoPhase::homeSettling;
  phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  Serial.println("MOVEMENT_STARTED");
}

} // namespace

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 07 SERVO_SWEEP");
  Serial.println("SERVO_DETACHED_AT_BOOT");

  if constexpr (!dosey::hardware::kServoEnabled) {
    Serial.println("CONFIGURATION_REQUIRED SERVO");
    return;
  }
  Serial.println("TYPE RUN TO MOVE OR CANCEL TO DETACH");
}

void loop() {
  if constexpr (!dosey::hardware::kServoEnabled) {
    delay(1000);
    return;
  }

  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input == "CANCEL") {
      if (controller.cancelMovement() == dosey::MovementResult::cancelled) {
        stopServo();
        Serial.println("MOVEMENT_CANCELLED_UNRESOLVED");
      } else {
        Serial.println("NACK NOT_MOVING");
      }
    } else if (input == "RUN") {
      startTest();
    }
  }

  if (controller.update(millis()) == dosey::MovementResult::timedOut) {
    stopServo();
    Serial.println("ERROR MOVEMENT_TIMEOUT");
    return;
  }

  if (phase == ServoPhase::idle ||
      static_cast<std::int32_t>(millis() - phaseDeadlineMs) < 0) {
    return;
  }

  if (phase == ServoPhase::homeSettling) {
    servo.write(dosey::safety::kServoTestDegrees);
    phase = ServoPhase::testSettling;
    phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  } else if (phase == ServoPhase::testSettling) {
    servo.write(dosey::safety::kServoHomeDegrees);
    phase = ServoPhase::returnSettling;
    phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  } else {
    stopServo();
    controller.completeMovement();
    Serial.println("SERVO_DONE MOVEMENT_ONLY");
  }
}
