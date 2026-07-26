#pragma once

#include <Arduino.h>
#include <Wire.h>

#include <cstdint>

#include "arduino_servo_pwm.h"
#include "grove_base_pins.h"
#include "hardware_config.h"
#include "protocol_engine.h"
#include "safety_limits.h"
#include "servo_pwm_driver.h"

namespace dosey {

inline int inactiveLedLevel() {
  return hardware::kOnboardLedActiveLow ? HIGH : LOW;
}

inline int activeLedLevel() {
  return hardware::kOnboardLedActiveLow ? LOW : HIGH;
}

class ArduinoProtocolHardware final : public ProtocolHardware {
public:
  void begin() {
    if constexpr (hardware::kPirConfigured) {
      pinMode(hardware::kPirPin, INPUT);
    }
    if constexpr (hardware::kGroveDiagnosticsEnabled) {
      pinMode(hardware::grove_base::kMiniPirPin, INPUT);
      for (const int pin : hardware::grove_base::kDiagnosticButtonPins) {
        pinMode(pin, INPUT);
      }
      Wire.begin(hardware::grove_base::kI2cSdaPin,
                 hardware::grove_base::kI2cSclPin);
    } else if constexpr (hardware::kI2cConfigured) {
      Wire.begin(hardware::kI2cSdaPin, hardware::kI2cSclPin);
    }
  }

  bool servoConfigured() const override { return hardware::kServoEnabled; }

  bool pirConfigured() const override { return hardware::kPirConfigured; }

  bool pirMotion() const override {
    if constexpr (!hardware::kPirConfigured) {
      return false;
    }
    return digitalRead(hardware::kPirPin) ==
           (hardware::kPirActiveHigh ? HIGH : LOW);
  }

  bool pirWakeConfigured() const override {
    return hardware::kPirWakeEnabled;
  }

  bool pirWakeActive() const override { return pirMotion(); }

  bool groveDiagnosticsConfigured() const override {
    return hardware::kGroveDiagnosticsEnabled;
  }

  int grovePirRaw() const override {
    if constexpr (!hardware::kGroveDiagnosticsEnabled) {
      return 0;
    }
    return digitalRead(hardware::grove_base::kMiniPirPin);
  }

  int groveLightRaw() const override {
    if constexpr (!hardware::kGroveDiagnosticsEnabled) {
      return 0;
    }
    return analogRead(hardware::grove_base::kLightSensorPin);
  }

  int groveButtonRaw(std::uint8_t index) const override {
    if constexpr (!hardware::kGroveDiagnosticsEnabled) {
      return 0;
    }
    if (index >= 4) {
      return 0;
    }
    return digitalRead(hardware::grove_base::kDiagnosticButtonPins[index]);
  }

  bool groveDht20Present() override {
    if constexpr (!hardware::kGroveDiagnosticsEnabled) {
      return false;
    }
    Wire.beginTransmission(hardware::grove_base::kDht20Address);
    return Wire.endTransmission() == 0;
  }

  void setLedActive(bool active) override {
    digitalWrite(hardware::kOnboardLedPin,
                 active ? activeLedLevel() : inactiveLedLevel());
  }

  HardwareMovementStartResult startMovement(std::uint32_t nowMs) override {
    if constexpr (!hardware::kServoEnabled) {
      return HardwareMovementStartResult::attachFailed;
    }

    if (!servo_.attach(hardware::kServoPin)) {
      return HardwareMovementStartResult::attachFailed;
    }
    if (!servo_.writeDegrees(safety::kServoHomeDegrees,
                             safety::kServoMinimumPulseUs,
                             safety::kServoMaximumPulseUs)) {
      return HardwareMovementStartResult::writeFailed;
    }
    phase_ = ServoPhase::homeSettling;
    phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
    return HardwareMovementStartResult::started;
  }

  HardwareMovementStopResult stopMovement() override {
    const bool detached = servo_.detach();
    phase_ = ServoPhase::idle;
    return detached ? HardwareMovementStopResult::stopped
                    : HardwareMovementStopResult::detachFailed;
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
      if (!servo_.writeDegrees(safety::kServoTestDegrees,
                               safety::kServoMinimumPulseUs,
                               safety::kServoMaximumPulseUs)) {
        phase_ = ServoPhase::idle;
        return HardwareMovementUpdate::writeFailed;
      }
      phase_ = ServoPhase::testSettling;
      phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
      return HardwareMovementUpdate::none;
    }
    if (phase_ == ServoPhase::testSettling) {
      if (!servo_.writeDegrees(safety::kServoHomeDegrees,
                               safety::kServoMinimumPulseUs,
                               safety::kServoMaximumPulseUs)) {
        phase_ = ServoPhase::idle;
        return HardwareMovementUpdate::writeFailed;
      }
      phase_ = ServoPhase::returnSettling;
      phaseDeadlineMs_ = nowMs + safety::kServoStepSettleMs;
      return HardwareMovementUpdate::none;
    }
    return HardwareMovementUpdate::completed;
  }

private:
  enum class ServoPhase { idle, homeSettling, testSettling, returnSettling };

  hardware::ArduinoServoPwm servoPwm_;
  hardware::ServoPwmDriver<hardware::ArduinoServoPwm> servo_{servoPwm_};
  ServoPhase phase_ = ServoPhase::idle;
  std::uint32_t phaseDeadlineMs_ = 0;
};

} // namespace dosey
