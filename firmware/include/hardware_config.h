#pragma once

#include <cstddef>

#include "grove_base_pins.h"

#if __has_include("hardware_config.local.h")
#include "hardware_config.local.h"
#endif

#ifndef DOSEY_DIGITAL_OUTPUT_CONFIGURED
#define DOSEY_DIGITAL_OUTPUT_CONFIGURED 0
#endif
#ifndef DOSEY_DIGITAL_OUTPUT_PIN
#define DOSEY_DIGITAL_OUTPUT_PIN -1
#endif
#ifndef DOSEY_DIGITAL_OUTPUT_ACTIVE_HIGH
#define DOSEY_DIGITAL_OUTPUT_ACTIVE_HIGH 1
#endif
#ifndef DOSEY_BUTTON_CONFIGURED
#define DOSEY_BUTTON_CONFIGURED 0
#endif
#ifndef DOSEY_BUTTON_PIN
#define DOSEY_BUTTON_PIN -1
#endif
#ifndef DOSEY_BUTTON_USE_INTERNAL_PULLUP
#define DOSEY_BUTTON_USE_INTERNAL_PULLUP 0
#endif
#ifndef DOSEY_PIR_CONFIGURED
#define DOSEY_PIR_CONFIGURED 0
#endif
#ifndef DOSEY_PIR_PIN
#define DOSEY_PIR_PIN -1
#endif
#ifndef DOSEY_PIR_WAKE_ENABLED
#define DOSEY_PIR_WAKE_ENABLED 0
#endif
#ifndef DOSEY_PIR_ACTIVE_HIGH
#define DOSEY_PIR_ACTIVE_HIGH 1
#endif
#ifndef DOSEY_ANALOG_INPUT_CONFIGURED
#define DOSEY_ANALOG_INPUT_CONFIGURED 0
#endif
#ifndef DOSEY_ANALOG_INPUT_PIN
#define DOSEY_ANALOG_INPUT_PIN -1
#endif
#ifndef DOSEY_I2C_CONFIGURED
#define DOSEY_I2C_CONFIGURED 0
#endif
#ifndef DOSEY_I2C_SDA_PIN
#define DOSEY_I2C_SDA_PIN -1
#endif
#ifndef DOSEY_I2C_SCL_PIN
#define DOSEY_I2C_SCL_PIN -1
#endif
#ifndef DOSEY_GROVE_DIAGNOSTICS_ENABLED
#define DOSEY_GROVE_DIAGNOSTICS_ENABLED 0
#endif
#ifndef DOSEY_SERVO_ENABLED
#define DOSEY_SERVO_ENABLED 0
#endif
#ifndef DOSEY_SERVO_PIN
#define DOSEY_SERVO_PIN -1
#endif

namespace dosey::hardware {

inline constexpr int kUnconfiguredPin = -1;

constexpr bool enabledPinsConflict(bool firstEnabled, int firstPin,
                                   bool secondEnabled, int secondPin) {
  return firstEnabled && secondEnabled && firstPin == secondPin;
}

struct EnabledPin {
  bool enabled;
  int pin;
};

template <std::size_t N>
constexpr bool enabledPinsAreUnique(const EnabledPin (&pins)[N]) {
  for (std::size_t first = 0; first < N; ++first) {
    for (std::size_t second = first + 1; second < N; ++second) {
      if (enabledPinsConflict(pins[first].enabled, pins[first].pin,
                              pins[second].enabled, pins[second].pin)) {
        return false;
      }
    }
  }
  return true;
}

// XIAO ESP32-C6 user LED. Seeed's board definition uses active-low output.
inline constexpr int kOnboardLedPin = 15;
inline constexpr bool kOnboardLedActiveLow = true;

// Every external path defaults to disabled. Local overrides are allowed only
// after checking the exact module, Grove port, signal pin, and power path.
inline constexpr bool kDigitalOutputConfigured =
    DOSEY_DIGITAL_OUTPUT_CONFIGURED;
inline constexpr int kDigitalOutputPin = DOSEY_DIGITAL_OUTPUT_PIN;
inline constexpr bool kDigitalOutputActiveHigh =
    DOSEY_DIGITAL_OUTPUT_ACTIVE_HIGH;

inline constexpr bool kButtonConfigured = DOSEY_BUTTON_CONFIGURED;
inline constexpr int kButtonPin = DOSEY_BUTTON_PIN;
inline constexpr bool kButtonUseInternalPullup =
    DOSEY_BUTTON_USE_INTERNAL_PULLUP;

inline constexpr bool kPirConfigured = DOSEY_PIR_CONFIGURED;
inline constexpr int kPirPin = DOSEY_PIR_PIN;
inline constexpr bool kPirWakeEnabled = DOSEY_PIR_WAKE_ENABLED;
inline constexpr bool kPirActiveHigh = DOSEY_PIR_ACTIVE_HIGH;

inline constexpr bool kAnalogInputConfigured = DOSEY_ANALOG_INPUT_CONFIGURED;
inline constexpr int kAnalogInputPin = DOSEY_ANALOG_INPUT_PIN;

inline constexpr bool kI2cConfigured = DOSEY_I2C_CONFIGURED;
inline constexpr int kI2cSdaPin = DOSEY_I2C_SDA_PIN;
inline constexpr int kI2cSclPin = DOSEY_I2C_SCL_PIN;

// Enables a read-only snapshot of the fixed Grove Base input layout. Sensor
// meaning stays unclassified until the physical active levels are observed.
inline constexpr bool kGroveDiagnosticsEnabled =
    DOSEY_GROVE_DIAGNOSTICS_ENABLED;

inline constexpr bool kServoEnabled = DOSEY_SERVO_ENABLED;
inline constexpr int kServoPin = DOSEY_SERVO_PIN;

inline constexpr EnabledPin kExternalSignalPins[] = {
    {kDigitalOutputConfigured, kDigitalOutputPin},
    {kButtonConfigured, kButtonPin},
    {kPirConfigured, kPirPin},
    {kAnalogInputConfigured, kAnalogInputPin},
    {kI2cConfigured && !kGroveDiagnosticsEnabled, kI2cSdaPin},
    {kI2cConfigured && !kGroveDiagnosticsEnabled, kI2cSclPin},
    {kServoEnabled, kServoPin},
    {kGroveDiagnosticsEnabled, grove_base::kMiniPirPin},
    {kGroveDiagnosticsEnabled, grove_base::kLightSensorPin},
    {kGroveDiagnosticsEnabled, grove_base::kFirstButtonFirstPin},
    {kGroveDiagnosticsEnabled, grove_base::kFirstButtonSecondPin},
    {kGroveDiagnosticsEnabled, grove_base::kSecondButtonFirstPin},
    {kGroveDiagnosticsEnabled, grove_base::kSecondButtonSecondPin},
    {kGroveDiagnosticsEnabled, grove_base::kI2cSdaPin},
    {kGroveDiagnosticsEnabled, grove_base::kI2cSclPin},
};

static_assert(!kDigitalOutputConfigured ||
                  kDigitalOutputPin != kUnconfiguredPin,
              "Digital output cannot be enabled without a verified pin");
static_assert(!kDigitalOutputConfigured || kDigitalOutputActiveHigh,
              "Configured digital output must be active-high until verified");
static_assert(!kButtonConfigured || kButtonPin != kUnconfiguredPin,
              "Button input cannot be enabled without a verified pin");
static_assert(!kPirConfigured || kPirPin != kUnconfiguredPin,
              "PIR input cannot be enabled without a verified pin");
static_assert(!kPirWakeEnabled || kPirConfigured,
              "PIR wake cannot be enabled before PIR input is configured");
static_assert(!kAnalogInputConfigured || kAnalogInputPin != kUnconfiguredPin,
              "Analog input cannot be enabled without a verified pin");
static_assert(!kI2cConfigured || (kI2cSdaPin != kUnconfiguredPin &&
                                  kI2cSclPin != kUnconfiguredPin),
              "I2C cannot be enabled without verified SDA and SCL pins");
static_assert(!kGroveDiagnosticsEnabled || !kI2cConfigured ||
                  (kI2cSdaPin == grove_base::kI2cSdaPin &&
                   kI2cSclPin == grove_base::kI2cSclPin),
              "Configured I2C must use the Grove diagnostics bus pins");
static_assert(!kServoEnabled || kServoPin != kUnconfiguredPin,
              "Servo cannot be enabled without a verified pin");
static_assert(enabledPinsAreUnique(kExternalSignalPins),
              "Enabled external hardware paths cannot share signal pins");

} // namespace dosey::hardware

#undef DOSEY_DIGITAL_OUTPUT_CONFIGURED
#undef DOSEY_DIGITAL_OUTPUT_PIN
#undef DOSEY_DIGITAL_OUTPUT_ACTIVE_HIGH
#undef DOSEY_BUTTON_CONFIGURED
#undef DOSEY_BUTTON_PIN
#undef DOSEY_BUTTON_USE_INTERNAL_PULLUP
#undef DOSEY_PIR_CONFIGURED
#undef DOSEY_PIR_PIN
#undef DOSEY_PIR_WAKE_ENABLED
#undef DOSEY_PIR_ACTIVE_HIGH
#undef DOSEY_ANALOG_INPUT_CONFIGURED
#undef DOSEY_ANALOG_INPUT_PIN
#undef DOSEY_I2C_CONFIGURED
#undef DOSEY_I2C_SDA_PIN
#undef DOSEY_I2C_SCL_PIN
#undef DOSEY_GROVE_DIAGNOSTICS_ENABLED
#undef DOSEY_SERVO_ENABLED
#undef DOSEY_SERVO_PIN
