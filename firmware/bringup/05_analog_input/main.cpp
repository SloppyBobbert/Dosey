#include <Arduino.h>

#include "hardware_config.h"
#include "safety_limits.h"

namespace {

std::uint32_t nextReportMs = 0;

} // namespace

void setup() {
  Serial.begin(dosey::safety::kSerialBaud);
  delay(dosey::safety::kSerialStartupWaitMs);
  Serial.println("DOSEY BRINGUP 05 ANALOG_INPUT");

  if constexpr (!dosey::hardware::kAnalogInputConfigured) {
    Serial.println("CONFIGURATION_REQUIRED ANALOG_INPUT");
  }
}

void loop() {
  if constexpr (!dosey::hardware::kAnalogInputConfigured) {
    delay(1000);
    return;
  }

  if (static_cast<std::int32_t>(millis() - nextReportMs) >= 0) {
    Serial.printf("ANALOG_RAW %d\n",
                  analogRead(dosey::hardware::kAnalogInputPin));
    nextReportMs = millis() + dosey::safety::kInputReportIntervalMs;
  }
}
