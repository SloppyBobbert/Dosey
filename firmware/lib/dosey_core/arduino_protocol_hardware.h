#pragma once

#include <Arduino.h>
#include <ESP32Servo.h>

#include <cstdint>

#include "hardware_config.h"
#include "protocol_engine.h"
#include "safety_limits.h"

namespace dosey {

inline int inactiveLedLevel() {
  return hardware::kOnboardLedActiveLow ? HIGH : LOW;
}

inline int activeLedLevel() {
  return hardware::kOnboardLedActiveLow ? LOW : HIGH;
}

class ArduinoProtocolHardware final : public ProtocolHardware {
public:
  bool servoConfigured() const override { return hardware::kServoEnabled; }

  bool pirConfigured() const override { return hardware::kPirConfigured; }

  bool pirMotion() const override {
    if constexpr (!hardware::kPirConfigured) {
      return false;
    }
    return digitalRead(hardware::kPirPin);
  }

  void setLedActive(bool active) override {
    digitalWrite(hardware::kOnboardLedPin,
                 active ? activeLedLevel() : inactiveLedLevel());
  }

  bool startMovement(std::uint32_t nowMs) override {
    if constexpr (!hardware::kServoEnabled) {
      return false;
    }

    servo_.setPeriodHertz(50);
    servo_.attach(hardware::kServoPin, safety::kServoMinimumPulseUs,
                  safety::kServoMaximumPulseUs);
    if (!servo_.attached()) {
      return false;
    }
    servo_.write(safety::kServoHomeDegrees);
    phase_ = ServoPhase::homeSettling;
    phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
    return true;
  }

  void stopMovement() override {
    servo_.detach();
    phase_ = ServoPhase::idle;
  }

  HardwareMovementUpdate updateMovement(std::uint32_t nowMs) override {
    if constexpr (!hardware::kServoEnabled) {
      return HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::idle ||
        static_cast<std::int32_t>(nowMs - phaseDeadlineMs_) < 0) {
      return HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::homeSettling) {
      servo_.write(safety::kServoTestDegrees);
      phase_ = ServoPhase::testSettling;
      phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
      return HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::testSettling) {
      servo_.write(safety::kServoHomeDegrees);
      phase_ = ServoPhase::returnSettling;
      phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
      return HardwareMovementUpdate::none;
    }
    return HardwareMovementUpdate::completed;
  }

private:
  enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

  Servo servo_;
  ServoPhase phase_ = ServoPhase::idle;
  std::uint32_t phaseDeadlineMs_ = 0;
};

} // namespace dosey
