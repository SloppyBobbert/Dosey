#include <Arduino.h>

#include "arduino_servo_pwm.h"
#include "controller_state.h"
#include "hardware_config.h"
#include "line_accumulator.h"
#include "safety_limits.h"
#include "servo_pwm_driver.h"

namespace {

enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

dosey::hardware::ArduinoServoPwm servoPwm;
dosey::hardware::ServoPwmDriver<dosey::hardware::ArduinoServoPwm> servo(
    servoPwm);
dosey::ControllerState controller;
ServoPhase phase = ServoPhase::idle;
std::uint32_t phaseDeadlineMs = 0;
dosey::LineAccumulator serialInput;

bool stopServo() {
  const bool detached = servo.detach();
  phase = ServoPhase::idle;
  return detached;
}

void failMovement(const char *errorCode) {
  controller.cancelMovement();
  const bool detached = stopServo();
  Serial.print("ERROR ");
  Serial.println(errorCode);
  if (!detached) {
    Serial.println("ERROR SERVO_DETACH_FAILED");
  }
}

void startTest() {
  if (controller.acceptMovement("local-servo-test", millis(),
                                dosey::safety::kMovementTimeoutMs) !=
      dosey::AcceptResult::accepted) {
    Serial.println("NACK BUSY");
    return;
  }

  if (!servo.attach(dosey::hardware::kServoPin)) {
    failMovement("SERVO_ATTACH_FAILED");
    return;
  }
  if (!servo.writeDegrees(dosey::safety::kServoHomeDegrees,
                          dosey::safety::kServoMinimumPulseUs,
                          dosey::safety::kServoMaximumPulseUs)) {
    failMovement("SERVO_WRITE_FAILED");
    return;
  }
  phase = ServoPhase::homeSettling;
  phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  Serial.println("MOVEMENT_STARTED");
}

void handleSerialInput() {
  while (Serial.available()) {
    const dosey::LineResult result =
        serialInput.push(static_cast<char>(Serial.read()));
    if (result == dosey::LineResult::lineReady) {
      String input(serialInput.line());
      input.trim();
      if (input == "CANCEL") {
        if (controller.cancelMovement() == dosey::MovementResult::cancelled) {
          const bool detached = stopServo();
          Serial.println("MOVEMENT_CANCELLED_UNRESOLVED");
          if (!detached) {
            Serial.println("ERROR SERVO_DETACH_FAILED");
          }
        } else {
          Serial.println("NACK NOT_MOVING");
        }
      } else if (input == "RUN") {
        startTest();
      }
    } else if (result == dosey::LineResult::lineTooLong ||
               result == dosey::LineResult::lineInvalid) {
      Serial.println("NACK MALFORMED_COMMAND");
    }
  }
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

  handleSerialInput();

  if (controller.update(millis()) == dosey::MovementResult::timedOut) {
    const bool detached = stopServo();
    Serial.println("ERROR MOVEMENT_TIMEOUT");
    if (!detached) {
      Serial.println("ERROR SERVO_DETACH_FAILED");
    }
    return;
  }

  if (phase == ServoPhase::idle ||
      static_cast<std::int32_t>(millis() - phaseDeadlineMs) < 0) {
    return;
  }

  if (phase == ServoPhase::homeSettling) {
    if (!servo.writeDegrees(dosey::safety::kServoTestDegrees,
                            dosey::safety::kServoMinimumPulseUs,
                            dosey::safety::kServoMaximumPulseUs)) {
      failMovement("SERVO_WRITE_FAILED");
      return;
    }
    phase = ServoPhase::testSettling;
    phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  } else if (phase == ServoPhase::testSettling) {
    if (!servo.writeDegrees(dosey::safety::kServoHomeDegrees,
                            dosey::safety::kServoMinimumPulseUs,
                            dosey::safety::kServoMaximumPulseUs)) {
      failMovement("SERVO_WRITE_FAILED");
      return;
    }
    phase = ServoPhase::returnSettling;
    phaseDeadlineMs = millis() + dosey::safety::kServoStepSettleMs;
  } else {
    if (!stopServo()) {
      controller.cancelMovement();
      Serial.println("ERROR SERVO_DETACH_FAILED");
      return;
    }
    controller.completeMovement();
    Serial.println("SERVO_DONE MOVEMENT_ONLY");
  }
}
