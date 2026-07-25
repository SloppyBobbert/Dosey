#include <Arduino.h>
#include <ESP32Servo.h>

#include "hardware_config.h"
#include "line_accumulator.h"
#include "protocol_engine.h"
#include "safety_limits.h"

namespace {

enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

int inactiveLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? HIGH : LOW;
}

int activeLedLevel() {
  return dosey::hardware::kOnboardLedActiveLow ? LOW : HIGH;
}

class SerialProtocolOutput final : public dosey::ProtocolOutput {
public:
  void writeLine(const char *line) override { Serial.println(line); }
};

class ArduinoProtocolHardware final : public dosey::ProtocolHardware {
public:
  bool servoConfigured() const override {
    return dosey::hardware::kServoEnabled;
  }

  bool pirConfigured() const override {
    return dosey::hardware::kPirConfigured;
  }

  bool pirMotion() const override {
    if constexpr (!dosey::hardware::kPirConfigured) {
      return false;
    }
    return digitalRead(dosey::hardware::kPirPin);
  }

  void setLedActive(bool active) override {
    digitalWrite(dosey::hardware::kOnboardLedPin,
                 active ? activeLedLevel() : inactiveLedLevel());
  }

  bool startMovement(std::uint32_t nowMs) override {
    if constexpr (!dosey::hardware::kServoEnabled) {
      return false;
    }

    servo_.setPeriodHertz(50);
    servo_.attach(dosey::hardware::kServoPin,
                  dosey::safety::kServoMinimumPulseUs,
                  dosey::safety::kServoMaximumPulseUs);
    if (!servo_.attached()) {
      return false;
    }
    servo_.write(dosey::safety::kServoHomeDegrees);
    phase_ = ServoPhase::homeSettling;
    phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
    return true;
  }

  void stopMovement() override {
    servo_.detach();
    phase_ = ServoPhase::idle;
  }

  dosey::HardwareMovementUpdate updateMovement(std::uint32_t nowMs) override {
    if constexpr (!dosey::hardware::kServoEnabled) {
      return dosey::HardwareMovementUpdate::none;
    }

    if (phase_ == ServoPhase::idle ||
        static_cast<std::int32_t>(nowMs - phaseDeadlineMs_) < 0) {
      return dosey::HardwareMovementUpdate::none;
    }

    if (phase_ == ServoPhase::homeSettling) {
      servo_.write(dosey::safety::kServoTestDegrees);
      phase_ = ServoPhase::testSettling;
      phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
      return dosey::HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::testSettling) {
      servo_.write(dosey::safety::kServoHomeDegrees);
      phase_ = ServoPhase::returnSettling;
      phaseDeadlineMs_ = nowMs + dosey::safety::kServoStepSettleMs;
      return dosey::HardwareMovementUpdate::none;
    }
    return dosey::HardwareMovementUpdate::completed;
  }

private:
  Servo servo_;
  ServoPhase phase_ = ServoPhase::idle;
  std::uint32_t phaseDeadlineMs_ = 0;
};

dosey::LineAccumulator input;
SerialProtocolOutput output;
ArduinoProtocolHardware hardware;
dosey::ProtocolEngine protocol(hardware, output);

void readSerial() {
  while (Serial.available()) {
    const dosey::LineResult result =
        input.push(static_cast<char>(Serial.read()));
    if (result == dosey::LineResult::lineReady) {
      protocol.handleLine(input.line(), millis());
    } else if (result == dosey::LineResult::lineTooLong) {
      protocol.handleLineTooLong();
    }
  }
}

} // namespace

void setup() {
  digitalWrite(dosey::hardware::kOnboardLedPin, inactiveLedLevel());
  pinMode(dosey::hardware::kOnboardLedPin, OUTPUT);
  if constexpr (dosey::hardware::kPirConfigured) {
    pinMode(dosey::hardware::kPirPin, INPUT);
  }

  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("D1 EVT boot READY");
  if constexpr (!dosey::hardware::kServoEnabled) {
    Serial.println("D1 EVT boot SERVO_UNCONFIGURED");
  }
  if constexpr (!dosey::hardware::kPirConfigured) {
    Serial.println("D1 EVT boot PIR_UNCONFIGURED");
  }
}

void loop() {
  readSerial();
  protocol.update(millis());
}
